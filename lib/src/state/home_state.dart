import 'dart:async';

import 'package:get/get.dart';

import '../app_info.dart';
import '../data/failure.dart';
import '../data/greeting_repository.dart';
import '../data/platform_repository.dart';
import '../rust/bridge.dart';

class HomeState extends GetxController {
  HomeState({
    GreetingRepository? greetings,
    PlatformRepository? platform,
    this.appId = kAppId,
  }) : greetings = greetings ?? Get.find<GreetingRepository>(),
       platform = platform ?? Get.find<PlatformRepository>();

  static const Duration busyTickInterval = Duration(milliseconds: 50);

  final GreetingRepository greetings;

  final PlatformRepository platform;

  final String appId;

  bool _closed = false;

  final Rxn<PlatformSummary> summary = Rxn<PlatformSummary>();

  final RxnString summaryError = RxnString();

  void loadSummary() {
    try {
      summary.value = platform.summary(appId);
      summaryError.value = null;
    } catch (error) {
      summary.value = null;
      summaryError.value = BridgeFailure.from(error).message;
    }
  }

  final RxString name = 'Flutter'.obs;

  final Rx<GreetingStyle> style = GreetingStyle.plain.obs;

  final Rxn<Greeting> greeting = Rxn<Greeting>();

  final RxBool isGreeting = false.obs;

  final RxnString greetingError = RxnString();

  String get instantHello => greetings.hello(name.value);

  Future<void> submitGreeting() async {
    if (isGreeting.value) return;
    isGreeting.value = true;
    greetingError.value = null;

    try {
      greeting.value = await greetings.greet(
        name: name.value,
        style: style.value,
      );
    } on BridgeFailure catch (failure) {
      greeting.value = null;
      greetingError.value = failure.message;
    } finally {
      isGreeting.value = false;
    }
  }

  final RxInt delayMs = 800.obs;

  final RxnString delayedMessage = RxnString();

  final RxBool isDelayedRunning = false.obs;

  final RxnString delayedError = RxnString();

  final RxInt busyTicks = 0.obs;

  Timer? _busyTicker;

  Future<void> runDelayedHello() async {
    if (isDelayedRunning.value) return;
    isDelayedRunning.value = true;
    delayedError.value = null;
    busyTicks.value = 0;
    _startBusyTicker();

    try {
      delayedMessage.value = await greetings.delayedHello(
        name: name.value,
        delayMs: delayMs.value,
      );
    } on BridgeFailure catch (failure) {
      delayedMessage.value = null;
      delayedError.value = failure.message;
    } finally {
      _stopBusyTicker();
      isDelayedRunning.value = false;
    }
  }

  void _startBusyTicker() {
    _busyTicker?.cancel();
    _busyTicker = Timer.periodic(busyTickInterval, (_) {
      if (_closed) return;
      busyTicks.value++;
    });
  }

  void _stopBusyTicker() {
    _busyTicker?.cancel();
    _busyTicker = null;
  }

  final RxInt countdownFrom = 5.obs;

  final RxInt intervalMs = 300.obs;

  final RxList<int> countdownValues = <int>[].obs;

  final RxBool isCounting = false.obs;

  final RxnString countdownError = RxnString();

  StreamSubscription<int>? _countdownSubscription;

  void startCountdown() {
    if (isCounting.value) return;

    countdownValues.clear();
    countdownError.value = null;
    isCounting.value = true;

    _countdownSubscription = greetings
        .countdown(count: countdownFrom.value, intervalMs: intervalMs.value)
        .listen(
          (int value) {
            if (_closed) return;
            countdownValues.add(value);
          },
          onError: (Object error) {
            if (_closed) return;
            countdownError.value = BridgeFailure.from(error).message;
            isCounting.value = false;
            _countdownSubscription = null;
          },
          onDone: () {
            if (_closed) return;
            isCounting.value = false;
            _countdownSubscription = null;
          },
          cancelOnError: true,
        );
  }

  Future<void> stopCountdown() async {
    final StreamSubscription<int>? subscription = _countdownSubscription;
    _countdownSubscription = null;
    isCounting.value = false;
    await subscription?.cancel();
  }

  final RxInt fibonacciInput = 40.obs;

  final Rxn<BigInt> fibonacciResult = Rxn<BigInt>();

  final Rxn<Duration> fibonacciElapsed = Rxn<Duration>();

  final RxBool isComputing = false.obs;

  final RxnString fibonacciError = RxnString();

  Future<void> computeFibonacci() async {
    if (isComputing.value) return;
    isComputing.value = true;
    fibonacciError.value = null;

    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      fibonacciResult.value = await greetings.fibonacci(fibonacciInput.value);
      fibonacciElapsed.value = stopwatch.elapsed;
    } on BridgeFailure catch (failure) {
      fibonacciResult.value = null;
      fibonacciElapsed.value = null;
      fibonacciError.value = failure.message;
    } finally {
      stopwatch.stop();
      isComputing.value = false;
    }
  }

  @override
  void onInit() {
    super.onInit();
    loadSummary();
  }

  @override
  void onClose() {
    _closed = true;
    _stopBusyTicker();
    unawaited(_countdownSubscription?.cancel());
    _countdownSubscription = null;
    super.onClose();
  }
}
