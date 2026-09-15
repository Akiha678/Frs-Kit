import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frs_kit/src/data/failure.dart';
import 'package:frs_kit/src/data/greeting_repository.dart';
import 'package:frs_kit/src/data/platform_repository.dart';
import 'package:frs_kit/src/rust/bridge.dart';
import 'package:integration_test/integration_test.dart';

/// End-to-end tests against the real Rust library.
///
/// Nothing here is faked: `initRustBridge` loads
/// `rust/target/release/librust_lib_frs_kit.*`, and every expectation below is
/// answered by `rust/src/api/**`. That makes these the only tests that can catch a
/// stale library, a domain rule that changed in Rust, or an error message that no
/// longer survives the trip.
///
/// They need the native library to exist, so build it first:
///
/// ```sh
/// just build      # cargo build --release --manifest-path rust/Cargo.toml
/// just test-e2e   # flutter test integration_test
/// ```
///
/// Everything that can be checked without Rust lives in `test/` instead, where it
/// runs in milliseconds on every save.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initRustBridge);

  const GreetingRepository greetings = GreetingRepository();
  const PlatformRepository platform = PlatformRepository();

  group('synchronous round-trip', () {
    test('hello answers without a Future', () {
      expect(hello(name: 'Rust'), 'Hello, Rust!');
    });

    test('platform facts are available immediately', () {
      final PlatformSummary summary = platform.summary('com.example.frs_kit');

      expect(summary.name, isNotEmpty);
      expect(summary.name, platformName());
      expect(summary.family, platformFamily());
      expect(summary.isDesktop, isDesktop());
      expect(summary.dataDir, platform.dataDir('com.example.frs_kit'));
    });

    test('on a desktop target a data directory is guessed', () {
      // The only target guaranteed to have an answer. On mobile and the web this
      // crate returns null on purpose, so the assertion is conditional.
      if (!platform.isDesktop()) return;

      final String? dir = platform.dataDir('com.example.frs_kit');
      expect(dir, isNotNull);
      expect(dir, endsWith('com.example.frs_kit'));
    });
  });

  group('greeting', () {
    test('greet trims the name in the domain layer', () async {
      final Greeting greeting = await greetings.greet(
        name: '  Ada  ',
        style: GreetingStyle.formal,
      );

      expect(greeting.recipient, 'Ada');
      expect(greeting.message, 'Good day, Ada.');
      expect(greeting.style, GreetingStyle.formal);
    });

    test('every style renders something that mentions the name', () async {
      for (final GreetingStyle style in GreetingStyle.values) {
        final Greeting greeting = await greetings.greet(
          name: 'Ada',
          style: style,
        );
        expect(greeting.message, contains('Ada'), reason: '$style');
      }
    });

    test('a blank name fails with the domain message intact', () async {
      await expectLater(
        greetings.greet(name: '   ', style: GreetingStyle.plain),
        throwsA(
          isA<BridgeFailure>()
              .having(
                (BridgeFailure f) => f.message,
                'message',
                'invalid input: name must not be empty',
              )
              .having((BridgeFailure f) => f.isPanic, 'isPanic', isFalse),
        ),
      );
    });

    test('a name beyond the limit is rejected', () async {
      await expectLater(
        greetings.greet(name: 'a' * 65, style: GreetingStyle.plain),
        throwsA(
          isA<BridgeFailure>().having(
            (BridgeFailure f) => f.message,
            'message',
            'invalid input: name must be at most 64 characters',
          ),
        ),
      );
    });
  });

  group('async round-trip', () {
    test(
      'delayedHello actually waits and still returns the greeting',
      () async {
        final Stopwatch stopwatch = Stopwatch()..start();
        final String message = await greetings.delayedHello(
          name: 'Ada',
          delayMs: 120,
        );
        stopwatch.stop();

        expect(message, 'Hello, Ada!');
        expect(
          stopwatch.elapsedMilliseconds,
          greaterThanOrEqualTo(100),
          reason: 'a shorter wait means the delay never reached Rust',
        );
      },
    );

    test('delays beyond the cap are clamped rather than rejected', () async {
      final Stopwatch stopwatch = Stopwatch()..start();
      await greetings.delayedHello(name: 'Ada', delayMs: 100000);
      stopwatch.stop();

      // MAX_DELAY_MS is 5000 ms in Rust.
      expect(stopwatch.elapsedMilliseconds, lessThan(6000));
    });
  });

  group('cpu-bound round-trip', () {
    test('fibonacci matches the sequence', () async {
      expect(await greetings.fibonacci(0), BigInt.zero);
      expect(await greetings.fibonacci(1), BigInt.one);
      expect(await greetings.fibonacci(10), BigInt.from(55));
    });

    test('fibonacci reaches the u64 boundary exactly', () async {
      expect(
        await greetings.fibonacci(93),
        BigInt.parse('12200160415121876738'),
      );
    });

    test('one past the boundary is refused instead of overflowing', () async {
      await expectLater(
        greetings.fibonacci(94),
        throwsA(
          isA<BridgeFailure>().having(
            (BridgeFailure f) => f.message,
            'message',
            contains('u64'),
          ),
        ),
      );
    });
  });

  group('stream round-trip', () {
    test('countdown emits every value and then closes', () async {
      final List<int> values = await greetings
          .countdown(count: 3, intervalMs: 20)
          .toList();

      expect(values, <int>[3, 2, 1]);
    });

    test('cancelling the subscription stops the values', () async {
      final List<int> received = <int>[];
      final StreamSubscription<int> subscription = greetings
          .countdown(count: 100, intervalMs: 10)
          .listen(received.add);

      await Future<void>.delayed(const Duration(milliseconds: 80));
      await subscription.cancel();
      final int atCancel = received.length;

      expect(atCancel, greaterThan(0));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(
        received.length,
        atCancel,
        reason: 'a cancelled subscription must not receive more values',
      );
    });
  });
}
