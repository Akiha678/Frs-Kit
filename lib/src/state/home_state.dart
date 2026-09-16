import 'dart:async';

import 'package:get/get.dart';

import '../app_info.dart';
import '../data/failure.dart';
import '../data/greeting_repository.dart';
import '../data/platform_repository.dart';
import '../rust/bridge.dart';

/// 首页渲染所需的一切，以 GetX controller 的形式提供。
///
/// 状态放在 `Rx` 值里而不是普通字段里。这样 widget 只在真正*读取*某个 `Rx`
/// 的地方（也就是 `Obx` 内部）重建，而不是任何变化都让整页重建。比如在名字输入
/// 框里打字，只会重建那个同步预览：倒数面板和 CPU 面板不会因此重跑。
///
/// 改动这个文件之前，有两点值得知道：
///
/// * 直接赋值（`state.delayMs.value = 400`），不要写 setter；新值等于旧值时
///   `Rx` 会跳过通知，所以不需要手动加判断；
/// * 生命周期钩子是 GetX 的，不是 `ChangeNotifier` 的：实例构建时跑
///   [onInit]，实例被删除时跑 [onClose]。这里没有一处调用
///   `notifyListeners`，也没有 `dispose`。
///
/// repository 要么通过构造函数传入（单元测试），要么从 Get 容器取得（由
/// `HomeBinding` 注册）。
class HomeState extends GetxController {
  /// 创建 controller。
  ///
  /// [greetings] 和 [platform] 是可选的，这样测试可以完全不依赖 Get 容器来驱动
  /// controller。当它们为 `null` 时 —— `HomeBinding` 就是这么构造的 —— 会从 Get
  /// 解析，而那时 Get 已经把这两个注册好了。
  HomeState({
    GreetingRepository? greetings,
    PlatformRepository? platform,
    this.appId = kAppId,
  }) : greetings = greetings ?? Get.find<GreetingRepository>(),
       platform = platform ?? Get.find<PlatformRepository>();

  /// 调用进行期间 [busyTicks] 递增的间隔。
  static const Duration busyTickInterval = Duration(milliseconds: 50);

  /// 这个 controller 驱动的、由 bridge 支撑的 repository。
  final GreetingRepository greetings;

  /// 由 bridge 支撑的宿主机信息 repository。
  final PlatformRepository platform;

  /// 用于给数据目录划分命名空间的应用 id。
  final String appId;

  /// [onClose] 跑过之后置位，好让迟到的回调直接退出。
  bool _closed = false;

  // ------------------------------------------------------------- 宿主信息 --

  /// 宿主机信息；在 [loadSummary] 运行之前（或它失败时）为 `null`。
  final Rxn<PlatformSummary> summary = Rxn<PlatformSummary>();

  /// [summary] 为 `null` 时的原因。
  final RxnString summaryError = RxnString();

  /// 读取宿主机信息。同步且廉价，所以在 [onInit] 里跑一次；首次构建时这些值
  /// 就已经就绪。
  void loadSummary() {
    try {
      summary.value = platform.summary(appId);
      summaryError.value = null;
    } catch (error) {
      summary.value = null;
      summaryError.value = BridgeFailure.from(error).message;
    }
  }

  // ------------------------------------------------------------- greeting --

  /// 输入框当前的值。
  final RxString name = 'Flutter'.obs;

  /// 选中的语气。
  final Rx<GreetingStyle> style = GreetingStyle.plain.obs;

  /// Rust 最近渲染出的 greeting；还没有成功过则为 `null`。
  final Rxn<Greeting> greeting = Rxn<Greeting>();

  /// 是否有一次 [submitGreeting] 调用正在进行。
  final RxBool isGreeting = false.obs;

  /// 上一次 [submitGreeting] 失败的原因（如果失败了）。
  final RxnString greetingError = RxnString();

  /// 同步往返，每次读取这个 getter 都会重新求值。
  ///
  /// 这就是 `#[frb(sync)]` 换来的好处：没有 `Future` 要等，因为值已经在
  /// 那里了。在 `Obx` 里读取它还会让那个 `Obx` 订阅 [name]，实时预览能随
  /// 输入更新，靠的就是这一点。
  ///
  /// 这类 getter 要保持廉价：它们在 UI isolate 上、每次重建都会跑。
  String get instantHello => greetings.hello(name.value);

  /// 让 Rust 为当前输入校验并渲染一条 greeting。
  ///
  /// 失败保存在 [greetingError] 里而不是抛出：UI 把它们显示在输入框旁边；
  /// 名字为空是预期内的失误，不是崩溃。
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

  // ------------------------------------------------------------- 异步演示 --

  /// [runDelayedHello] 请求的延迟，单位毫秒。
  final RxInt delayMs = 800.obs;

  /// 上一次成功的 [runDelayedHello] 的结果。
  final RxnString delayedMessage = RxnString();

  /// [runDelayedHello] 是否正在进行。
  final RxBool isDelayedRunning = false.obs;

  /// 上一次 [runDelayedHello] 失败的原因（如果失败了）。
  final RxnString delayedError = RxnString();

  /// UI isolate 空闲期间持续递增的计数器。
  ///
  /// 它是「慢速 Rust 调用不会阻塞 Flutter」的可见证据：如果 isolate 被阻塞，
  /// 这些定时器回调就跑不起来，数字会停住。把它和请求的延迟对照着看。
  final RxInt busyTicks = 0.obs;

  Timer? _busyTicker;

  /// 执行异步往返，并在等待期间统计 UI tick。
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

  // --------------------------------------------------------------- 流演示 --

  /// 下一次倒数起始的那个值。
  final RxInt countdownFrom = 5.obs;

  /// 两个值之间的间隔，单位毫秒。
  final RxInt intervalMs = 300.obs;

  /// 到目前为止收到的值，最早的在最前。
  ///
  /// 它是 `RxList`，所以 `add` 自身就会发出通知。UI 侧请当作只读：什么时候
  /// 清空由 controller 决定。
  final RxList<int> countdownValues = <int>[].obs;

  /// 倒数流是否仍然开着。
  final RxBool isCounting = false.obs;

  /// 倒数失败的原因（如果失败了）。
  final RxnString countdownError = RxnString();

  StreamSubscription<int>? _countdownSubscription;

  /// 订阅一个全新的倒数流，丢弃之前的那些值。
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

  /// 取消订阅，Rust 侧的循环会在下一次发送时停下。
  ///
  /// 值得把它接到一个看得见的按钮上：用同一条代码路径去处理「用户改主意
  /// 了」，才能看出取消是否真的传到了 Rust。
  Future<void> stopCountdown() async {
    final StreamSubscription<int>? subscription = _countdownSubscription;
    _countdownSubscription = null;
    isCounting.value = false;
    await subscription?.cancel();
  }

  // ------------------------------------------------------------- CPU 演示 --

  /// 下一次 [computeFibonacci] 调用的输入。
  final RxInt fibonacciInput = 40.obs;

  /// 上一次成功的 [computeFibonacci] 的结果。
  final Rxn<BigInt> fibonacciResult = Rxn<BigInt>();

  /// 上一次 [computeFibonacci] 耗费的挂钟时间。
  final Rxn<Duration> fibonacciElapsed = Rxn<Duration>();

  /// [computeFibonacci] 是否正在进行。
  final RxBool isComputing = false.obs;

  /// 上一次 [computeFibonacci] 失败的原因（如果失败了）。
  final RxnString fibonacciError = RxnString();

  /// 在 Rust 里执行 CPU 密集型工作，并测量耗时。
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

  // ------------------------------------------------------------- 生命周期 --

  /// 实例构建时 GetX 会调用它。
  ///
  /// 在这里（而不是在某个 widget 的 `initState` 里）读取宿主机信息，首次构建
  /// 才能直接显示平台事实，同时也把这个副作用挡在 widget 树之外。
  @override
  void onInit() {
    super.onInit();
    loadSummary();
  }

  /// 实例被删除（或调用了 `dispose()`）时 GetX 会调用它。
  ///
  /// 之后流事件和定时器 tick 仍可能到达，而给已销毁的 `Rx` 赋值会报错，所以用
  /// [_closed] 把它们挡在外面。
  @override
  void onClose() {
    _closed = true;
    _stopBusyTicker();
    // `onClose` 是同步的，所以这个取消操作没法 await。Rust 会在下一次发送时
    // 察觉，这正是可以放心地发出即忘的原因。
    unawaited(_countdownSubscription?.cancel());
    _countdownSubscription = null;
    super.onClose();
  }
}
