import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frs_kit/src/app.dart';
import 'package:frs_kit/src/data/failure.dart';
import 'package:frs_kit/src/rust/bridge.dart';
import 'package:get/get.dart';

import 'fakes/fake_repositories.dart';

/// 整个应用的 widget 测试，用假实现 repository 顶替 Rust。
///
/// 这些是每次保存都要跑的测试：不需要原生库、不需要设备、也不需要代码
/// 生成，但走的是真实的 widget 树、真实的 `HomeState` 和真实的错误处理。
/// `integration_test/` 负责它们刻意覆盖不到的那部分：真正的 bridge。
void main() {
  late FakeGreetingRepository greetings;

  setUp(() {
    // GetX 把所有东西都放在一个全局容器里。`testMode` 则让
    // GetMaterialApp 不在测试环境里真的去驱动路由。
    Get.testMode = true;
    greetings = FakeGreetingRepository();
  });

  tearDown(() async {
    // 少了这一步，上一个测试的 controller 仍然注册着 —— 而且仍然攥着
    // *它自己*那套假实现 —— 于是下一次 `Get.find<HomeState>()` 会拿到陈旧实例。
    // 这就是 GetX 里对应「widget 树被拆掉」的那件事。
    Get.reset();
    await greetings.dispose();
  });

  /// 在一块高到放得下所有面板的画布上 pump 出应用。
  ///
  /// 默认的 800x600 测试窗口比页面矮，而 `ListView` 不会构建折叠线以下的
  /// 内容 —— 于是点靠下的面板会先报 "found 0 widgets"，滚动之后又报
  /// "would not hit test"。给一个高窗口，测试关心的就是行为而不是滚动；
  /// 滚动本身由 `integration_test/` 里的布局测试覆盖。
  Future<void> pumpApp(WidgetTester tester, {Widget? app}) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      app ??
          FrsKitApp(
            greetings: greetings,
            platform: const FakePlatformRepository(),
          ),
    );
    await tester.pumpAndSettle();
  }

  /// 应用拿 Rust 的答案与之比较的基准值，算法与平台面板相同。
  String dartPlatform() =>
      kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase();

  testWidgets('shows one panel per round-trip', (WidgetTester tester) async {
    await pumpApp(tester);

    expect(find.text('platform'), findsOneWidget);
    expect(find.text('hello / greet'), findsOneWidget);
    expect(find.text('delayed_hello'), findsOneWidget);
    expect(find.text('countdown'), findsOneWidget);
    expect(find.text('fibonacci'), findsOneWidget);
  });

  testWidgets('renders the host facts Rust reported', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('fakeos'), findsOneWidget);
    expect(find.text('/tmp/fakeos/frs_kit'), findsOneWidget);

    // 假实现自称 `fakeos`，不可能和跑测试的平台对上，所以面板必须指出来：
    // 这个比较是应用察觉「原生库编译目标不对」的唯一途径。
    expect(find.text('stale library?'), findsOneWidget);
  });

  testWidgets('a library matching the running platform is called current', (
    WidgetTester tester,
  ) async {
    await pumpApp(
      tester,
      app: FrsKitApp(
        greetings: greetings,
        platform: FakePlatformRepository(
          summaryValue: PlatformSummary(
            name: dartPlatform(),
            family: PlatformFamily.desktop,
            isDesktop: true,
          ),
        ),
      ),
    );

    expect(find.text('library is current'), findsOneWidget);
    expect(
      find.text('not guessed on this platform — use path_provider'),
      findsOneWidget,
    );
  });

  testWidgets('the synchronous call follows the text field immediately', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('Hello, Flutter!'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Ada');
    await tester.pump();

    expect(find.text('Hello, Ada!'), findsOneWidget);
    expect(greetings.calls, contains('Ada'));
  });

  testWidgets('pressing Greet shows the greeting Rust rendered', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.enterText(find.byType(TextField), 'Ada');
    await tester.tap(find.text('Greet'));
    await tester.pumpAndSettle();

    expect(find.text('plain: Ada'), findsOneWidget);
  });

  testWidgets('picking another style changes the rendered greeting', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.enterText(find.byType(TextField), 'Ada');
    await tester.tap(find.text('formal'));
    await tester.pump();
    await tester.tap(find.text('Greet'));
    await tester.pumpAndSettle();

    expect(find.text('formal: Ada'), findsOneWidget);
  });

  testWidgets('a rejected name is shown next to the field, not thrown', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('Greet'));
    await tester.pumpAndSettle();

    expect(find.text('invalid input: name must not be empty'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a repository failure is displayed, not thrown', (
    WidgetTester tester,
  ) async {
    greetings.greetFailure = const BridgeFailure('Rust panicked: kaboom');
    await pumpApp(tester);

    await tester.tap(find.text('Greet'));
    await tester.pumpAndSettle();

    expect(find.text('Rust panicked: kaboom'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the tick counter advances while a Rust call is pending', (
    WidgetTester tester,
  ) async {
    final Completer<String> gate = Completer<String>();
    greetings.delayedGate = gate;

    await pumpApp(tester);
    expect(find.text('0'), findsOneWidget);

    await tester.tap(find.text('Run delayed call'));
    await tester.pump();

    // 被 pump 的时间会驱动状态里的周期 ticker：真实运行时用的就是同一个
    // 定时器，用来证明 isolate 一直空闲。
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.text('0'),
      findsNothing,
      reason: 'the tick counter must move while the call is in flight',
    );
    expect(find.text('Waiting…'), findsOneWidget);

    gate.complete('Hello, Flutter!');
    await tester.pumpAndSettle();

    // 现在有两行同时显示它：同步那行一直都有，异步那行刚回来。
    expect(find.text('Hello, Flutter!'), findsNWidgets(2));
    expect(find.text('Waiting…'), findsNothing);
  });

  testWidgets('starting the countdown renders the values Rust pushed', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Start'));
    await tester.pump();

    greetings.emitCountdown(3);
    greetings.emitCountdown(2);
    await tester.pump();

    expect(find.widgetWithText(Chip, '3'), findsOneWidget);
    expect(find.widgetWithText(Chip, '2'), findsOneWidget);
  });

  testWidgets('stopping the countdown cancels the subscription', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Start'));
    await tester.pump();
    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();

    expect(greetings.countdownCancelled, isTrue);
    expect(find.text('Start'), findsOneWidget);
  });

  testWidgets('the countdown stream can fail without crashing the app', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Start'));
    await tester.pump();

    greetings.failCountdown(const BridgeFailure('stream broke'));
    await tester.pumpAndSettle();

    expect(find.text('stream broke'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('computing a Fibonacci number shows the value Rust returned', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Compute in Rust'));
    await tester.pumpAndSettle();

    // 假实现把输入原样返回，所以输入 40 就渲染成 40；面板同时上报这次
    // 调用花了多久。
    expect(find.text('40'), findsWidgets);
    // 页面上有好几处都会渲染耗时，所以匹配值的形状而不是那个词：
    // 面板上报的必须是实测时间，不能是占位符。
    expect(find.textContaining(RegExp(r'^\d+ ms$')), findsWidgets);
  });

  testWidgets('a Fibonacci failure is shown instead of a value', (
    WidgetTester tester,
  ) async {
    greetings.fibonacciFailure = const BridgeFailure('n must be at most 93');
    await pumpApp(tester);

    await tester.tap(find.text('Compute in Rust'));
    await tester.pumpAndSettle();

    expect(find.text('n must be at most 93'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
