import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frs_kit/src/app.dart';
import 'package:frs_kit/src/data/greeting_repository.dart';
import 'package:frs_kit/src/rust/bridge.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';

/// 整个应用跑在真实 widget 上，对着真实的 Rust 库。
///
/// `test/app_test.dart` 用假实现证明了同样的交互。这个文件是为了填两者之间的
/// 空缺：假实现说不清磁盘上的共享库是否与生成的 binding 匹配，说不清 loader
/// 能否在 app bundle 里找到它，也说不清一个 domain 错误跨过 FFI 之后是否还是
/// 原话。每个要发布的目标上都要跑一遍：
///
/// ```sh
/// flutter test integration_test/app_test.dart -d macos
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initRustBridge);

  setUp(() => Get.testMode = true);

  // Get 容器是全局的，活得比 widget 树还久。不重置的话，下一个测试虽然 pump
  // 出了新应用，`Get.find<HomeState>()` 却会把上一个测试的 controller 交回来 ——
  // 连同它输入过的名字和选中的样式。于是第一个之后的每个测试都在对着陈旧状态
  // 做断言，这一行出现之前，这里有两个测试正是这么挂掉的。
  tearDown(Get.reset);

  /// 在一块高到放得下所有面板的画布上 pump 出真实应用。
  ///
  /// 手机尺寸的窗口比这个页面矮，而 `ListView` 对折叠线以下的内容既不构建
  /// 也不做命中测试。在测量 widget 和点击它之间去滚动，是测试不稳定的可靠
  /// 来源，所以这些测试干脆给自己留出页面需要的空间。teardown 里的
  /// `setSurfaceSize(null)` 会把设备自己的窗口还回来。
  Future<void> pumpRealApp(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const FrsKitApp());
    await tester.pumpAndSettle();
  }

  /// 把 [finder] 带到屏幕上，若在折叠线以下就滚动面板列表。
  ///
  /// 留着它是给更小的画布当保险。这里刻意避开 `pumpAndSettle`：调用挂起时
  /// 有好几个面板在跑 spinner 动画，settle 永远结束不了。
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
        240,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(finder);
    await tester.pump();
  }

  /// 一直 pump 真实帧，直到 [finder] 命中；超过 [timeout] 就失败。
  ///
  /// 活着的 binding 没法靠 `pumpAndSettle` 趟过不调度任何帧的工作，所以要等
  /// 一次真实的 Rust 调用，可靠的办法是等一个看得见的结果出现。
  Future<void> pumpUntilFound(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final DateTime deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) return;
    }
    fail('timed out after $timeout waiting for: $finder');
  }

  testWidgets('the app shows the host its Rust library was built for', (
    WidgetTester tester,
  ) async {
    await pumpRealApp(tester);

    // 这个值来自 `rust/src/api/platform.rs`，所以能在屏幕上找到它，就说明库
    // 加载成功了、答复了，而且和 Dart 对平台的判断一致。
    expect(find.text(platformName()), findsWidgets);
    expect(find.text('library is current'), findsOneWidget);
  });

  testWidgets('typing exercises the synchronous call on the real library', (
    WidgetTester tester,
  ) async {
    await pumpRealApp(tester);
    await reveal(tester, find.byType(TextField));

    await tester.enterText(find.byType(TextField), 'Ada');
    await tester.pump();

    expect(find.text('Hello, Ada!'), findsOneWidget);
  });

  testWidgets('Greet renders what Rust produced, style included', (
    WidgetTester tester,
  ) async {
    await pumpRealApp(tester);
    await reveal(tester, find.byType(TextField));

    await tester.enterText(find.byType(TextField), 'Ada');

    // 每个控件都先 reveal 再点：在真实窗口里，折叠线以下的卡片既不会被构建，
    // 也命中不了。
    await reveal(tester, find.text('formal'));
    await tester.tap(find.text('formal'));
    await tester.pump();

    await reveal(tester, find.text('Greet'));
    await tester.tap(find.text('Greet'));
    await pumpUntilFound(tester, find.text('Good day, Ada.'));

    expect(find.text('Good day, Ada.'), findsOneWidget);
  });

  testWidgets('a blank name is rejected by Rust and shown in the UI', (
    WidgetTester tester,
  ) async {
    await pumpRealApp(tester);
    await reveal(tester, find.byType(TextField));

    await tester.enterText(find.byType(TextField), '   ');
    await reveal(tester, find.text('Greet'));
    await tester.tap(find.text('Greet'));
    await pumpUntilFound(
      tester,
      find.text('invalid input: name must not be empty'),
    );

    expect(find.text('invalid input: name must not be empty'), findsOneWidget);
  });

  testWidgets('a delayed call finishes and leaves the UI responsive', (
    WidgetTester tester,
  ) async {
    await pumpRealApp(tester);
    await reveal(tester, find.text('Run delayed call'));

    await tester.tap(find.text('Run delayed call'));
    await tester.pump();

    // 只有当 Rust 睡着期间 isolate 一直空闲，面板上的 tick 计数才会往前走 ——
    // 这个测试存在的意义就是核对这一点。
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('0'), findsNothing);

    await pumpUntilFound(tester, find.text('Hello, Flutter!'));
  });

  testWidgets('the countdown stream reaches the UI and can be stopped', (
    WidgetTester tester,
  ) async {
    await pumpRealApp(tester);
    await reveal(tester, find.text('Stop'));

    await tester.tap(find.text('Start'));
    // countdown(count: 5, intervalMs: 300) 从 5 开始。
    await pumpUntilFound(tester, find.widgetWithText(Chip, '5'));

    expect(find.widgetWithText(Chip, '5'), findsOneWidget);

    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();

    expect(find.text('Start'), findsOneWidget);
  });

  testWidgets('CPU-bound work runs to completion in Rust', (
    WidgetTester tester,
  ) async {
    await pumpRealApp(tester);
    await reveal(tester, find.text('Compute in Rust'));

    await tester.tap(find.text('Compute in Rust'));

    // F(40) = 102334155，经 BigInt.toString() 渲染出来。
    await pumpUntilFound(tester, find.text('102334155'));
    expect(find.text('102334155'), findsOneWidget);
  });

  testWidgets('the data layer is the one calling the bridge', (
    WidgetTester tester,
  ) async {
    const GreetingRepository repository = GreetingRepository();
    expect(repository.hello('Ada'), 'Hello, Ada!');

    await pumpRealApp(tester);
    expect(find.text('Hello, Flutter!'), findsOneWidget);
  });
}
