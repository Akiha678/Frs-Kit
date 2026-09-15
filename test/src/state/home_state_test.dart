import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frs_kit/src/data/failure.dart';
import 'package:frs_kit/src/data/platform_repository.dart';
import 'package:frs_kit/src/rust/bridge.dart';
import 'package:frs_kit/src/state/home_state.dart';

import '../../fakes/fake_repositories.dart';

/// Unit tests for [HomeState], driven entirely by fake repositories.
///
/// These run in milliseconds and prove the state machine on its own — including
/// paths that are awkward to provoke against the real Rust library, such as a
/// stream that fails halfway or a call that never returns.
void main() {
  late FakeGreetingRepository greetings;

  setUp(() => greetings = FakeGreetingRepository());
  tearDown(() => greetings.dispose());

  HomeState buildState() =>
      HomeState(greetings: greetings, platform: const FakePlatformRepository());

  group('host facts', () {
    test('are read synchronously on demand', () {
      final HomeState state = buildState();
      addTearDown(state.dispose);

      expect(state.summary, isNull);
      state.loadSummary();

      expect(state.summary?.name, 'fakeos');
      expect(state.summary?.isDesktop, isTrue);
      expect(state.summaryError, isNull);
    });

    test(
      'record the failure instead of throwing when the bridge is not ready',
      () {
        final HomeState state = HomeState(
          greetings: greetings,
          platform: _ThrowingPlatformRepository(),
        );
        addTearDown(state.dispose);

        expect(state.loadSummary, returnsNormally);
        expect(state.summary, isNull);
        expect(state.summaryError, isNotNull);
      },
    );
  });

  group('greeting', () {
    test('the synchronous call is recomputed from the current name', () {
      final HomeState state = buildState();
      addTearDown(state.dispose);

      expect(state.instantHello, 'Hello, Flutter!');

      state.setName('Ada');
      expect(state.instantHello, 'Hello, Ada!');
    });

    test('submitting stores the rendered greeting', () async {
      final HomeState state = buildState();
      addTearDown(state.dispose);

      state.setName('Ada');
      state.setStyle(GreetingStyle.formal);
      await state.submitGreeting();

      expect(state.greeting?.recipient, 'Ada');
      expect(state.greeting?.message, 'formal: Ada');
      expect(state.greetingError, isNull);
      expect(state.isGreeting, isFalse);
    });

    test('reports Rust validation failures without throwing', () async {
      final HomeState state = buildState();
      addTearDown(state.dispose);

      state.setName('   ');
      await state.submitGreeting();

      expect(state.greeting, isNull);
      expect(state.greetingError, 'invalid input: name must not be empty');
    });

    test('a second submit is ignored while one is in flight', () async {
      final HomeState state = buildState();
      addTearDown(state.dispose);

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
      addTearDown(state.dispose);

      state.setName('');
      await state.submitGreeting();
      expect(state.greetingError, isNotNull);

      state.setName('Ada');
      await state.submitGreeting();
      expect(state.greetingError, isNull);
    });

    test('setName ignores identical values', () {
      final HomeState state = buildState();
      addTearDown(state.dispose);

      int notifications = 0;
      state.addListener(() => notifications++);

      state.setName('Flutter');
      expect(notifications, 0);

      state.setName('Ada');
      expect(notifications, 1);
    });
  });

  group('async call', () {
    test(
      'counts UI ticks while the call is pending, then records the result',
      () async {
        final HomeState state = buildState();
        addTearDown(state.dispose);

        final Completer<String> gate = Completer<String>();
        greetings.delayedGate = gate;

        state.setName('Ada');
        final Future<void> pending = state.runDelayedHello();

        expect(state.isDelayedRunning, isTrue);
        expect(state.busyTicks, 0);

        // Real time, not pumped time: the ticker is what proves the isolate stayed
        // responsive, so it has to be a real timer.
        await Future<void>.delayed(HomeState.busyTickInterval * 3);
        expect(
          state.busyTicks,
          greaterThanOrEqualTo(2),
          reason: 'the isolate kept running timer callbacks while Rust worked',
        );

        gate.complete('Hello, Ada!');
        await pending;

        expect(state.isDelayedRunning, isFalse);
        expect(state.delayedMessage, 'Hello, Ada!');
        expect(state.delayedError, isNull);
      },
    );

    test('stops the ticker when the call fails', () async {
      final HomeState state = buildState();
      addTearDown(state.dispose);

      final Completer<String> gate = Completer<String>();
      greetings.delayedGate = gate;

      final Future<void> pending = state.runDelayedHello();
      gate.completeError(const BridgeFailure('boom'));
      await pending;

      expect(state.isDelayedRunning, isFalse);
      expect(state.delayedError, 'boom');

      final int ticks = state.busyTicks;
      await Future<void>.delayed(HomeState.busyTickInterval * 2);
      expect(state.busyTicks, ticks, reason: 'the ticker was cancelled');
    });
  });

  group('countdown stream', () {
    test('collects values and finishes when the stream closes', () async {
      final HomeState state = buildState();
      addTearDown(state.dispose);

      state.startCountdown();
      expect(state.isCounting, isTrue);

      greetings.emitCountdown(3);
      greetings.emitCountdown(2);
      await pumpEventQueue();

      expect(state.countdownValues, <int>[3, 2]);

      await greetings.closeCountdown();
      await pumpEventQueue();

      expect(state.isCounting, isFalse);
    });

    test('records a stream error and stops listening', () async {
      final HomeState state = buildState();
      addTearDown(state.dispose);

      state.startCountdown();
      greetings.failCountdown(const BridgeFailure('stream broke'));
      await pumpEventQueue();

      expect(state.countdownError, 'stream broke');
      expect(state.isCounting, isFalse);
    });

    test('stopCountdown cancels the subscription', () async {
      final HomeState state = buildState();
      addTearDown(state.dispose);

      state.startCountdown();
      await pumpEventQueue();
      expect(greetings.isCountdownListened, isTrue);

      await state.stopCountdown();

      expect(state.isCounting, isFalse);
      expect(greetings.countdownCancelled, isTrue);
    });

    test('starting twice does not open a second subscription', () async {
      final HomeState state = buildState();
      addTearDown(state.dispose);

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
      addTearDown(state.dispose);

      state.setFibonacciInput(20);
      await state.computeFibonacci();

      expect(state.fibonacciResult, BigInt.from(20));
      expect(state.fibonacciElapsed, isNotNull);
      expect(state.fibonacciError, isNull);
    });

    test('records a failure and clears the previous result', () async {
      final HomeState state = buildState();
      addTearDown(state.dispose);

      await state.computeFibonacci();
      expect(state.fibonacciResult, isNotNull);

      greetings.fibonacciFailure = const BridgeFailure('n must be at most 93');
      await state.computeFibonacci();

      expect(state.fibonacciResult, isNull);
      expect(state.fibonacciElapsed, isNull);
      expect(state.fibonacciError, 'n must be at most 93');
    });
  });

  group('lifecycle', () {
    test('dispose cancels the countdown subscription', () async {
      final HomeState state = buildState();

      state.startCountdown();
      await pumpEventQueue();

      state.dispose();

      expect(greetings.countdownCancelled, isTrue);
    });

    test('stream events arriving after dispose do not throw', () async {
      final HomeState state = buildState();

      state.startCountdown();
      await pumpEventQueue();
      state.dispose();

      // A broadcast controller keeps its own lifetime: emitting here reaches no
      // listener, which is exactly the situation the disposed guard protects.
      greetings.emitCountdown(1);
      await pumpEventQueue();
    });
  });
}

/// A platform repository whose every call throws, standing in for a bridge that
/// was never initialized.
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
