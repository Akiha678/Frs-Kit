import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frs_kit/src/data/failure.dart';
import 'package:frs_kit/src/data/platform_repository.dart';
import 'package:frs_kit/src/rust/bridge.dart';
import 'package:frs_kit/src/state/home_state.dart';

import '../../fakes/fake_repositories.dart';

/// [HomeState] 的单元测试，完全由假实现 repository 驱动。
///
/// 这些测试毫秒级就能跑完，单独证明状态机本身是对的 —— 包括对着真实 Rust 库
/// 很难触发的路径，比如流跑到一半失败，或者一次永远不返回的调用。
void main() {
  late FakeGreetingRepository greetings;

  setUp(() => greetings = FakeGreetingRepository());
  tearDown(() => greetings.dispose());

  HomeState buildState() =>
      HomeState(greetings: greetings, platform: const FakePlatformRepository());

  group('host facts', () {
    test('are read synchronously on demand', () {
      final HomeState state = buildState();
      addTearDown(() => disposeState(state));

      expect(state.summary.value, isNull);
      state.loadSummary();

      expect(state.summary.value?.name, 'fakeos');
      expect(state.summary.value?.isDesktop, isTrue);
      expect(state.summaryError.value, isNull);
    });

    test(
      'record the failure instead of throwing when the bridge is not ready',
      () {
        final HomeState state = HomeState(
          greetings: greetings,
          platform: _ThrowingPlatformRepository(),
        );
        addTearDown(() => disposeState(state));

        expect(state.loadSummary, returnsNormally);
        expect(state.summary.value, isNull);
        expect(state.summaryError.value, isNotNull);
      },
    );
  });

  group('greeting', () {
    test('the synchronous call is recomputed from the current name', () {
      final HomeState state = buildState();
      addTearDown(() => disposeState(state));

      expect(state.instantHello, 'Hello, Flutter!');

      state.name.value = 'Ada';
      expect(state.instantHello, 'Hello, Ada!');
    });

    test('submitting stores the rendered greeting', () async {
      final HomeState state = buildState();
      addTearDown(() => disposeState(state));

      state.name.value = 'Ada';
      state.style.value = GreetingStyle.formal;
      await state.submitGreeting();

      expect(state.greeting.value?.recipient, 'Ada');
      expect(state.greeting.value?.message, 'formal: Ada');
      expect(state.greetingError.value, isNull);
      expect(state.isGreeting.value, isFalse);
    });

    test('reports Rust validation failures without throwing', () async {
      final HomeState state = buildState();
      addTearDown(() => disposeState(state));

      state.name.value = '   ';
      await state.submitGreeting();

      expect(state.greeting.value, isNull);
      expect(state.greetingError.value, 'invalid input: name must not be empty');
    });

    test('a second submit is ignored while one is in flight', () async {
      final HomeState state = buildState();
      addTearDown(() => disposeState(state));

      final Completer<String> gate = Completer<String>();
      greetings.delayedGate = gate;

      final Future<void> first = state.submitGreeting();
      final Future<void> second = state.submitGreeting();

      expect(greetings.calls.length, 1, reason: 'the second call is dropped');
      await first;
      await second;
    });

    test('clears a previous error on the next attempt', () async {
      final HomeState state = buildState();
      addTearDown(() => disposeState(state));

      state.name.value = '';
      await state.submitGreeting();
      expect(state.greetingError.value, isNotNull);

      state.name.value = 'Ada';
      await state.submitGreeting();
      expect(state.greetingError.value, isNull);
    });

    test('an Rx notifies on change and skips repeats after the first write', () {
      final HomeState state = buildState();
      addTearDown(() => disposeState(state));

      int notifications = 0;
      state.name.listen((_) => notifications++);

      // GetX 对第一次赋值一定会通知，即使赋的值和字段初值相同：
      // `_RxImpl.firstRebuild` 把它当作「公布初始值」来处理。换成手写的
      // setter，这一次通知就会被吞掉。
      state.name.value = 'Flutter';
      expect(notifications, 1);

      // 之后每次写入相同的值都是空操作，而这正是过去那个手写的
      // `if (value == _name) return;` 守卫负责的事。
      state.name.value = 'Flutter';
      expect(notifications, 1);

      state.name.value = 'Ada';
      expect(notifications, 2);
    });
  });

  group('async call', () {
    test(
      'counts UI ticks while the call is pending, then records the result',
      () async {
        final HomeState state = buildState();
        addTearDown(() => disposeState(state));

        final Completer<String> gate = Completer<String>();
        greetings.delayedGate = gate;

        state.name.value = 'Ada';
        final Future<void> pending = state.runDelayedHello();

        expect(state.isDelayedRunning.value, isTrue);
        expect(state.busyTicks.value, 0);

        // 用真实时间，而不是被 pump 的时间：证明 isolate 一直能响应靠的就是这个
        // ticker，所以它必须是真正的定时器。
        await Future<void>.delayed(HomeState.busyTickInterval * 3);
        expect(
          state.busyTicks.value,
          greaterThanOrEqualTo(2),
          reason: 'the isolate kept running timer callbacks while Rust worked',
        );

        gate.complete('Hello, Ada!');
        await pending;

        expect(state.isDelayedRunning.value, isFalse);
        expect(state.delayedMessage.value, 'Hello, Ada!');
        expect(state.delayedError.value, isNull);
      },
    );

    test('stops the ticker when the call fails', () async {
      final HomeState state = buildState();
      addTearDown(() => disposeState(state));

      final Completer<String> gate = Completer<String>();
      greetings.delayedGate = gate;

      final Future<void> pending = state.runDelayedHello();
      gate.completeError(const BridgeFailure('boom'));
      await pending;

      expect(state.isDelayedRunning.value, isFalse);
      expect(state.delayedError.value, 'boom');

      final int ticks = state.busyTicks.value;
      await Future<void>.delayed(HomeState.busyTickInterval * 2);
      expect(state.busyTicks.value, ticks, reason: 'the ticker was cancelled');
    });
  });

  group('countdown stream', () {
    test('collects values and finishes when the stream closes', () async {
      final HomeState state = buildState();
      addTearDown(() => disposeState(state));

      state.startCountdown();
      expect(state.isCounting.value, isTrue);

      greetings.emitCountdown(3);
      greetings.emitCountdown(2);
      await pumpEventQueue();

      expect(state.countdownValues, <int>[3, 2]);

      await greetings.closeCountdown();
      await pumpEventQueue();

      expect(state.isCounting.value, isFalse);
    });

    test('records a stream error and stops listening', () async {
      final HomeState state = buildState();
      addTearDown(() => disposeState(state));

      state.startCountdown();
      greetings.failCountdown(const BridgeFailure('stream broke'));
      await pumpEventQueue();

      expect(state.countdownError.value, 'stream broke');
      expect(state.isCounting.value, isFalse);
    });

    test('stopCountdown cancels the subscription', () async {
      final HomeState state = buildState();
      addTearDown(() => disposeState(state));

      state.startCountdown();
      await pumpEventQueue();
      expect(greetings.isCountdownListened, isTrue);

      await state.stopCountdown();

      expect(state.isCounting.value, isFalse);
      expect(greetings.countdownCancelled, isTrue);
    });

    test('starting twice does not open a second subscription', () async {
      final HomeState state = buildState();
      addTearDown(() => disposeState(state));

      state.startCountdown();
      state.startCountdown();
      await pumpEventQueue();

      greetings.emitCountdown(1);
      await pumpEventQueue();

      expect(state.countdownValues, <int>[1]);
    });
  });

  group('cpu call', () {
    test('records the result and how long it took', () async {
      final HomeState state = buildState();
      addTearDown(() => disposeState(state));

      state.fibonacciInput.value = 20;
      await state.computeFibonacci();

      expect(state.fibonacciResult.value, BigInt.from(20));
      expect(state.fibonacciElapsed.value, isNotNull);
      expect(state.fibonacciError.value, isNull);
    });

    test('records a failure and clears the previous result', () async {
      final HomeState state = buildState();
      addTearDown(() => disposeState(state));

      await state.computeFibonacci();
      expect(state.fibonacciResult.value, isNotNull);

      greetings.fibonacciFailure = const BridgeFailure('n must be at most 93');
      await state.computeFibonacci();

      expect(state.fibonacciResult.value, isNull);
      expect(state.fibonacciElapsed.value, isNull);
      expect(state.fibonacciError.value, 'n must be at most 93');
    });
  });

  group('lifecycle', () {
    test('onClose cancels the countdown subscription', () async {
      final HomeState state = buildState();

      state.startCountdown();
      await pumpEventQueue();

      state.onDelete();

      expect(greetings.countdownCancelled, isTrue);
    });

    test('stream events arriving after dispose do not throw', () async {
      final HomeState state = buildState();

      state.startCountdown();
      await pumpEventQueue();
      state.onDelete();

      // broadcast controller 有自己的生命周期：在这里发出事件到不了任何
      // 监听者，而 `_closed` 守卫防的正是这种情况。
      greetings.emitCountdown(1);
      await pumpEventQueue();
    });
  });
}

/// 为测试里直接构造出来的 [HomeState] 跑一遍 controller 的 teardown。
///
/// `GetxController` 没有 `dispose()`：在应用里是容器调用 `onDelete()`，
/// 再由它调用 `onClose()`。这些测试自己构造 controller —— 没有容器，也没有
/// Flutter binding —— 所以只能直接调这个钩子。取消 busy ticker 和倒数订阅
/// 都是它做的，因此凡是启动了这两者之一的测试都必须走到它。
void disposeState(HomeState state) => state.onDelete();

/// 一个每次调用都抛异常的 platform repository，用来顶替从未初始化过的
/// bridge。
class _ThrowingPlatformRepository implements PlatformRepository {
  @override
  PlatformSummary summary(String appId) => throw StateError('bridge not ready');

  @override
  String name() => throw StateError('bridge not ready');

  @override
  PlatformFamily family() => throw StateError('bridge not ready');

  @override
  bool isDesktop() => throw StateError('bridge not ready');

  @override
  String? dataDir(String appId) => throw StateError('bridge not ready');
}
