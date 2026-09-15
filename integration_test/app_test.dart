import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frs_kit/src/app.dart';
import 'package:frs_kit/src/data/greeting_repository.dart';
import 'package:frs_kit/src/rust/bridge.dart';
import 'package:integration_test/integration_test.dart';

/// The whole app, running the real widgets against the real Rust library.
///
/// `test/app_test.dart` proves the same interactions with fakes. This file exists
/// for the gap between them: a fake cannot tell you whether the shared library on
/// disk matches the generated bindings, whether the loader finds it inside the app
/// bundle, or whether a domain error still reads the same after crossing FFI. Run
/// it on each target you ship:
///
/// ```sh
/// flutter test integration_test/app_test.dart -d macos
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initRustBridge);

  /// Pumps the real app on a surface tall enough to hold every panel.
  ///
  /// A phone-sized window is shorter than this page, and a `ListView` neither
  /// builds nor hit-tests what is below the fold. Scrolling between measuring a
  /// widget and tapping it is a reliable source of flakiness, so the tests simply
  /// give themselves the room the page needs. `setSurfaceSize(null)` in the
  /// teardown restores the device's own window.
  Future<void> pumpRealApp(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const FrsKitApp());
    await tester.pumpAndSettle();
  }

  /// Brings [finder] on screen, scrolling the panel list if it is below the fold.
  ///
  /// Kept as a safety net for smaller surfaces. `pumpAndSettle` is avoided here:
  /// several panels animate a spinner while a call is pending, and settling would
  /// never finish.
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

  /// Pumps real frames until [finder] matches, or fails after [timeout].
  ///
  /// A live binding cannot `pumpAndSettle` its way through work that schedules no
  /// frames, so waiting for a visible outcome is the reliable way to await a real
  /// Rust call.
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

    // The value comes from `rust/src/api/platform.rs`, so finding it on screen
    // means the library loaded, answered, and agreed with Dart about the platform.
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

    // Each control is revealed before it is tapped: on a real window the cards
    // below the fold are neither built nor hit-testable.
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

    // The panel's tick counter only moves if the isolate stayed free while Rust
    // slept, which is the claim this test exists to check.
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
    // countdown(count: 5, intervalMs: 300) starts at 5.
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

    // F(40) = 102334155, rendered through BigInt.toString().
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
