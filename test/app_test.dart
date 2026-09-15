import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frs_kit/src/app.dart';
import 'package:frs_kit/src/data/failure.dart';
import 'package:frs_kit/src/rust/bridge.dart';

import 'fakes/fake_repositories.dart';

/// Widget tests for the whole app, with fake repositories standing in for Rust.
///
/// These are the tests to run on every save: they need no native library, no
/// device and no code generation, yet they exercise the real widget tree, the real
/// `HomeState` and the real error handling. `integration_test/` covers what they
/// deliberately cannot: the actual bridge.
void main() {
  late FakeGreetingRepository greetings;

  setUp(() => greetings = FakeGreetingRepository());
  tearDown(() => greetings.dispose());

  /// Pumps the app on a surface tall enough to hold every panel.
  ///
  /// The default 800x600 test window is shorter than the page, and a `ListView`
  /// does not build what is below the fold — so a tap on a lower panel would fail
  /// with "found 0 widgets" and, after scrolling, with "would not hit test". A tall
  /// window keeps the test about behaviour instead of about scrolling. Scrolling
  /// itself is covered by the layout tests in `integration_test/`.
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

  /// What the app compares Rust's answer against, computed the same way the
  /// platform panel does.
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

    // The fake claims to be `fakeos`, which cannot match the platform this test
    // runs on, so the panel must say so: that comparison is the app's only way to
    // notice a native library built for the wrong target.
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

    // Pumped time drives the state's periodic ticker: the same timer a real run
    // uses to show that the isolate stayed free.
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.text('0'),
      findsNothing,
      reason: 'the tick counter must move while the call is in flight',
    );
    expect(find.text('Waiting…'), findsOneWidget);

    gate.complete('Hello, Flutter!');
    await tester.pumpAndSettle();

    // Two lines now carry it: the synchronous one always did, the async one just
    // arrived.
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

    // The fake echoes its input, so an input of 40 renders as 40, and the panel
    // also reports how long the call took.
    expect(find.text('40'), findsWidgets);
    // Several sliders render a duration, so match the shape of the value rather
    // than the word: the panel must report a measured time, not a placeholder.
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
