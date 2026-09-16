import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frs_kit/src/data/failure.dart';
import 'package:frs_kit/src/data/greeting_repository.dart';
import 'package:frs_kit/src/data/platform_repository.dart';
import 'package:frs_kit/src/rust/bridge.dart';
import 'package:integration_test/integration_test.dart';

/// 对着真实 Rust 库跑的端到端测试。
///
/// 这里没有任何东西被换成假实现：`initRustBridge` 会加载
/// `rust/target/release/librust_lib_frs_kit.*`，下面每一条期望都由
/// `rust/src/api/**` 给出答案。正因如此，只有这些测试才抓得到陈旧的库、Rust
/// 里改过的 domain 规则，或者一句已经走不完全程的错误消息。
///
/// 它们要求原生库已经存在，所以先构建：
///
/// ```sh
/// just build      # cargo build --release --manifest-path rust/Cargo.toml
/// just test-e2e   # flutter test integration_test
/// ```
///
/// 凡是不需要 Rust 就能检查的东西，都放在 `test/` 里，那里每次保存只跑几毫秒。
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
      // 唯一保证有答案的目标平台。在移动端和 web 上，这个 crate 故意返回
      // null，所以这条断言是有条件的。
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

      // Rust 里 MAX_DELAY_MS 是 5000 ms。
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
