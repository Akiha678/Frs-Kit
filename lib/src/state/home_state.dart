import 'dart:async';

import 'package:flutter/foundation.dart';

import '../app_info.dart';
import '../data/failure.dart';
import '../data/greeting_repository.dart';
import '../data/platform_repository.dart';
import '../rust/bridge.dart';

/// Everything the home page renders, in one [ChangeNotifier].
///
/// The scaffold deliberately ships without a state-management package: one
/// notifier plus an `InheritedNotifier` scope is enough at this size, costs no
/// dependency, and is a drop-in target for riverpod or bloc later — swap
/// `HomeStateScope` and the widgets keep working.
///
/// The repositories are injected so widget tests can drive the whole UI without
/// the native library being built.
class HomeState extends ChangeNotifier {
  /// Creates the state, defaulting to the real repositories.
  HomeState({
    GreetingRepository? greetings,
    PlatformRepository? platform,
    this.appId = kAppId,
  }) : greetings = greetings ?? const GreetingRepository(),
       platform = platform ?? const PlatformRepository();

  /// How often [busyTicks] advances while a call is in flight.
  static const Duration busyTickInterval = Duration(milliseconds: 50);

  /// The bridge-backed repositories this state drives.
  final GreetingRepository greetings;

  /// The bridge-backed repository for host facts.
  final PlatformRepository platform;

  /// Application id used to namespace the data directory.
  final String appId;

  bool _disposed = false;

  // ------------------------------------------------------------ host facts --

  PlatformSummary? _summary;
  String? _summaryError;

  /// Host facts, or `null` until [loadSummary] runs (or if it failed).
  PlatformSummary? get summary => _summary;

  /// Why [summary] is `null`, when it is.
  String? get summaryError => _summaryError;

  /// Reads the host. Synchronous and cheap: call it once, from `initState`.
  void loadSummary() {
    try {
      _summary = platform.summary(appId);
      _summaryError = null;
    } catch (error) {
      _summary = null;
      _summaryError = BridgeFailure.from(error).message;
    }
    _notify();
  }

  // -------------------------------------------------------------- greeting --

  String _name = 'Flutter';
  GreetingStyle _style = GreetingStyle.plain;
  Greeting? _greeting;
  bool _isGreeting = false;
  String? _greetingError;

  /// Current text-field value.
  String get name => _name;

  /// Selected tone.
  GreetingStyle get style => _style;

  /// The last greeting Rust rendered, or `null` if none succeeded yet.
  Greeting? get greeting => _greeting;

  /// Whether a [submitGreeting] call is in flight.
  bool get isGreeting => _isGreeting;

  /// Why the last [submitGreeting] failed, when it did.
  String? get greetingError => _greetingError;

  /// The synchronous round-trip, evaluated on every build.
  ///
  /// This is what `#[frb(sync)]` buys: no `Future`, no rebuild needed to see the
  /// result, because the value is already there. Keep such getters cheap — they
  /// run on the UI isolate.
  String get instantHello => greetings.hello(_name);

  /// Updates [name] and rebuilds.
  void setName(String value) {
    if (value == _name) return;
    _name = value;
    _notify();
  }

  /// Updates [style] and rebuilds.
  void setStyle(GreetingStyle value) {
    if (value == _style) return;
    _style = value;
    _notify();
  }

  /// Asks Rust to validate and render a greeting for the current input.
  ///
  /// Failures are kept in [greetingError] rather than thrown: the UI shows them
  /// next to the field, and a blank name is an expected mistake, not a crash.
  Future<void> submitGreeting() async {
    if (_isGreeting) return;
    _isGreeting = true;
    _greetingError = null;
    _notify();

    try {
      _greeting = await greetings.greet(name: _name, style: _style);
    } on BridgeFailure catch (failure) {
      _greeting = null;
      _greetingError = failure.message;
    } finally {
      _isGreeting = false;
      _notify();
    }
  }

  // ----------------------------------------------------------- async demo --

  int _delayMs = 800;
  String? _delayedMessage;
  bool _isDelayedRunning = false;
  String? _delayedError;
  int _busyTicks = 0;
  Timer? _busyTicker;

  /// Requested delay for [runDelayedHello], in milliseconds.
  int get delayMs => _delayMs;

  /// Result of the last successful [runDelayedHello].
  String? get delayedMessage => _delayedMessage;

  /// Whether [runDelayedHello] is in flight.
  bool get isDelayedRunning => _isDelayedRunning;

  /// Why the last [runDelayedHello] failed, when it did.
  String? get delayedError => _delayedError;

  /// Counter that keeps advancing while the UI isolate is idle.
  ///
  /// This is the visible proof that a slow Rust call does not block Flutter: if
  /// the isolate were blocked, these timer callbacks could not run, and the
  /// number would freeze. Compare it with the delay that was requested.
  int get busyTicks => _busyTicks;

  /// Updates [delayMs] and rebuilds.
  void setDelayMs(int value) {
    if (value == _delayMs) return;
    _delayMs = value;
    _notify();
  }

  /// Runs the async round-trip and counts UI ticks while it waits.
  Future<void> runDelayedHello() async {
    if (_isDelayedRunning) return;
    _isDelayedRunning = true;
    _delayedError = null;
    _busyTicks = 0;
    _startBusyTicker();
    _notify();

    try {
      _delayedMessage = await greetings.delayedHello(
        name: _name,
        delayMs: _delayMs,
      );
    } on BridgeFailure catch (failure) {
      _delayedMessage = null;
      _delayedError = failure.message;
    } finally {
      _stopBusyTicker();
      _isDelayedRunning = false;
      _notify();
    }
  }

  void _startBusyTicker() {
    _busyTicker?.cancel();
    _busyTicker = Timer.periodic(busyTickInterval, (_) {
      _busyTicks++;
      _notify();
    });
  }

  void _stopBusyTicker() {
    _busyTicker?.cancel();
    _busyTicker = null;
  }

  // ---------------------------------------------------------- stream demo --

  int _countdownFrom = 5;
  int _intervalMs = 300;
  final List<int> _countdownValues = <int>[];
  bool _isCounting = false;
  String? _countdownError;
  StreamSubscription<int>? _countdownSubscription;

  /// First value the next countdown starts from.
  int get countdownFrom => _countdownFrom;

  /// Interval between two values, in milliseconds.
  int get intervalMs => _intervalMs;

  /// Values received so far, oldest first.
  List<int> get countdownValues => List<int>.unmodifiable(_countdownValues);

  /// Whether the countdown stream is still open.
  bool get isCounting => _isCounting;

  /// Why the countdown failed, when it did.
  String? get countdownError => _countdownError;

  /// Updates [countdownFrom] and rebuilds.
  void setCountdownFrom(int value) {
    if (value == _countdownFrom) return;
    _countdownFrom = value;
    _notify();
  }

  /// Updates [intervalMs] and rebuilds.
  void setIntervalMs(int value) {
    if (value == _intervalMs) return;
    _intervalMs = value;
    _notify();
  }

  /// Subscribes to a fresh countdown stream, discarding earlier values.
  void startCountdown() {
    if (_isCounting) return;

    _countdownValues.clear();
    _countdownError = null;
    _isCounting = true;
    _notify();

    _countdownSubscription = greetings
        .countdown(count: _countdownFrom, intervalMs: _intervalMs)
        .listen(
          (value) {
            _countdownValues.add(value);
            _notify();
          },
          onError: (Object error) {
            _countdownError = BridgeFailure.from(error).message;
            _isCounting = false;
            _countdownSubscription = null;
            _notify();
          },
          onDone: () {
            _isCounting = false;
            _countdownSubscription = null;
            _notify();
          },
          cancelOnError: true,
        );
  }

  /// Cancels the subscription, which stops the Rust loop on its next send.
  ///
  /// Worth wiring to a visible button: seeing the same code path handle "user
  /// changed their mind" is how you find out whether cancellation really reaches
  /// Rust.
  Future<void> stopCountdown() async {
    final subscription = _countdownSubscription;
    _countdownSubscription = null;
    _isCounting = false;
    _notify();
    await subscription?.cancel();
  }

  // ------------------------------------------------------------- cpu demo --

  int _fibonacciInput = 40;
  BigInt? _fibonacciResult;
  Duration? _fibonacciElapsed;
  bool _isComputing = false;
  String? _fibonacciError;

  /// Input for the next [computeFibonacci] call.
  int get fibonacciInput => _fibonacciInput;

  /// Result of the last successful [computeFibonacci].
  BigInt? get fibonacciResult => _fibonacciResult;

  /// Wall-clock time the last [computeFibonacci] took.
  Duration? get fibonacciElapsed => _fibonacciElapsed;

  /// Whether [computeFibonacci] is in flight.
  bool get isComputing => _isComputing;

  /// Why the last [computeFibonacci] failed, when it did.
  String? get fibonacciError => _fibonacciError;

  /// Updates [fibonacciInput] and rebuilds.
  void setFibonacciInput(int value) {
    if (value == _fibonacciInput) return;
    _fibonacciInput = value;
    _notify();
  }

  /// Runs CPU-bound work in Rust and measures how long it took.
  Future<void> computeFibonacci() async {
    if (_isComputing) return;
    _isComputing = true;
    _fibonacciError = null;
    _notify();

    final stopwatch = Stopwatch()..start();
    try {
      _fibonacciResult = await greetings.fibonacci(_fibonacciInput);
      _fibonacciElapsed = stopwatch.elapsed;
    } on BridgeFailure catch (failure) {
      _fibonacciResult = null;
      _fibonacciElapsed = null;
      _fibonacciError = failure.message;
    } finally {
      stopwatch.stop();
      _isComputing = false;
      _notify();
    }
  }

  // --------------------------------------------------------------- lifecyle --

  /// Notifies listeners unless this state has already been disposed.
  ///
  /// Stream events and timer ticks can arrive after `dispose`, and notifying a
  /// disposed [ChangeNotifier] throws. Guarding here keeps that rule in one place
  /// instead of in every callback.
  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _stopBusyTicker();
    // `dispose` is synchronous, so cancellation cannot be awaited here. Rust
    // notices on its next send, which is what makes this safe to fire and forget.
    unawaited(_countdownSubscription?.cancel());
    _countdownSubscription = null;
    super.dispose();
  }
}
