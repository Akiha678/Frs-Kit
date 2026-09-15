import 'dart:async';

import 'package:frs_kit/src/data/failure.dart';
import 'package:frs_kit/src/data/greeting_repository.dart';
import 'package:frs_kit/src/data/platform_repository.dart';
import 'package:frs_kit/src/rust/bridge.dart';

/// A [GreetingRepository] that never touches the native library.
///
/// Widget tests cannot load a `.dylib`/`.so`/`.dll`, and they should not need to:
/// what they verify is that the widgets react correctly to the answers the
/// repository gives. This fake gives those answers on demand, including the ones
/// that are hard to provoke against the real Rust code — a slow call that has not
/// finished yet, or an error.
///
/// It mimics the *contract* of the real repository rather than its implementation:
/// blank names are rejected exactly as `rust_flutter_core::domain` rejects them.
class FakeGreetingRepository implements GreetingRepository {
  /// Creates a fake.
  FakeGreetingRepository({this.helloPrefix = 'Hello'}) {
    _countdown = StreamController<int>.broadcast(
      // Mirrors the real contract: cancelling the Dart subscription is what stops
      // the Rust loop, so the fake records the cancellation too.
      onCancel: () => countdownCancelled = true,
    );
  }

  /// Prefix used by [hello], so a test can tell the fake's output apart.
  final String helloPrefix;

  /// Every name [hello] or [greet] was called with, in order.
  final List<String> calls = <String>[];

  /// When set, [delayedHello] returns this future instead of finishing at once.
  ///
  /// Assign a [Completer] and complete it later to hold a call "in flight" while
  /// the test inspects the UI.
  Completer<String>? delayedGate;

  /// When set, [greet] fails with this failure.
  BridgeFailure? greetFailure;

  /// When set, [fibonacci] fails with this failure.
  BridgeFailure? fibonacciFailure;

  late final StreamController<int> _countdown;

  /// Whether [countdown] has an active listener.
  bool get isCountdownListened => _countdown.hasListener;

  /// Whether [countdown]'s subscription has been cancelled.
  bool countdownCancelled = false;

  /// Emits [value] on the countdown stream.
  void emitCountdown(int value) => _countdown.add(value);

  /// Closes the countdown stream, as Rust does when the countdown reaches 1.
  Future<void> closeCountdown() => _countdown.close();

  /// Fails the countdown stream.
  void failCountdown(Object error) => _countdown.addError(error);

  @override
  String hello(String name) {
    calls.add(name);
    return '$helloPrefix, $name!';
  }

  @override
  Future<Greeting> greet({
    required String name,
    required GreetingStyle style,
  }) async {
    calls.add(name);

    if (greetFailure case final BridgeFailure failure) {
      throw failure;
    }

    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const BridgeFailure('invalid input: name must not be empty');
    }

    return Greeting(
      recipient: trimmed,
      message: '${style.name}: $trimmed',
      style: style,
    );
  }

  @override
  Future<String> delayedHello({required String name, required int delayMs}) {
    calls.add(name);

    if (delayedGate case final Completer<String> gate) {
      return gate.future;
    }
    return Future<String>.value('$helloPrefix, $name!');
  }

  @override
  Future<BigInt> fibonacci(int n) async {
    if (fibonacciFailure case final BridgeFailure failure) {
      throw failure;
    }
    return BigInt.from(n);
  }

  @override
  Stream<int> countdown({required int count, required int intervalMs}) =>
      _countdown.stream;

  /// Releases every resource the fake owns.
  Future<void> dispose() => _countdown.close();
}

/// A [PlatformRepository] that reports a fixed platform.
class FakePlatformRepository implements PlatformRepository {
  /// Creates a fake reporting [summaryValue].
  const FakePlatformRepository({
    this.summaryValue = const PlatformSummary(
      name: 'fakeos',
      family: PlatformFamily.desktop,
      isDesktop: true,
      dataDir: '/tmp/fakeos/frs_kit',
    ),
  });

  /// What [summary] returns.
  final PlatformSummary summaryValue;

  @override
  PlatformSummary summary(String appId) => summaryValue;

  @override
  String name() => summaryValue.name;

  @override
  PlatformFamily family() => summaryValue.family;

  @override
  bool isDesktop() => summaryValue.isDesktop;

  @override
  String? dataDir(String appId) => summaryValue.dataDir;
}
