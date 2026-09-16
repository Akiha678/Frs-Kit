import 'dart:async';

import 'package:frs_kit/src/data/failure.dart';
import 'package:frs_kit/src/data/greeting_repository.dart';
import 'package:frs_kit/src/data/platform_repository.dart';
import 'package:frs_kit/src/rust/bridge.dart';

/// 一个永远不去碰原生库的 [GreetingRepository]。
///
/// Widget 测试加载不了 `.dylib`/`.so`/`.dll`，也不该需要加载：它们验证的是
/// widget 对 repository 给出的答案反应是否正确。这个假实现按需给出这些答案，
/// 包括对着真实 Rust 代码很难触发的那几种 —— 还没结束的慢调用，或者一个
/// 错误。
///
/// 它模仿的是真实 repository 的*契约*而不是实现：空名字被拒绝的方式与
/// `rust_flutter_core::domain` 完全一致。
class FakeGreetingRepository implements GreetingRepository {
  /// 创建假实现。
  FakeGreetingRepository({this.helloPrefix = 'Hello'}) {
    _countdown = StreamController<int>.broadcast(
      // 照搬真实契约：停掉 Rust 那个循环靠的就是取消 Dart 侧的订阅，
      // 所以假实现也把这次取消记下来。
      onCancel: () => countdownCancelled = true,
    );
  }

  /// [hello] 使用的前缀，让测试能把假实现的输出区分出来。
  final String helloPrefix;

  /// [hello] 或 [greet] 被调用时传入过的每个名字，按顺序排列。
  final List<String> calls = <String>[];

  /// 一旦赋值，[delayedHello] 就返回这个 future，而不是立刻完成。
  ///
  /// 赋一个 [Completer] 之后再完成它，就能把一次调用「挂住」，
  /// 让测试来得及检查此时的 UI。
  Completer<String>? delayedGate;

  /// 一旦赋值，[greet] 就以这个 failure 失败。
  BridgeFailure? greetFailure;

  /// 一旦赋值，[fibonacci] 就以这个 failure 失败。
  BridgeFailure? fibonacciFailure;

  late final StreamController<int> _countdown;

  /// [countdown] 是否已有活跃的监听者。
  bool get isCountdownListened => _countdown.hasListener;

  /// [countdown] 的订阅是否已被取消。
  bool countdownCancelled = false;

  /// 在倒数流上发出 [value]。
  void emitCountdown(int value) => _countdown.add(value);

  /// 关闭倒数流，正如 Rust 在倒数走到 1 时所做的那样。
  Future<void> closeCountdown() => _countdown.close();

  /// 让倒数流以错误收场。
  void failCountdown(Object error) => _countdown.addError(error);

  @override
  String hello(String name) {
    calls.add(name);
    return '$helloPrefix, $name!';
  }

  @override
  Future<Greeting> greet({
    required String name,
    required GreetingStyle style,
  }) async {
    calls.add(name);

    if (greetFailure case final BridgeFailure failure) {
      throw failure;
    }

    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const BridgeFailure('invalid input: name must not be empty');
    }

    return Greeting(
      recipient: trimmed,
      message: '${style.name}: $trimmed',
      style: style,
    );
  }

  @override
  Future<String> delayedHello({required String name, required int delayMs}) {
    calls.add(name);

    if (delayedGate case final Completer<String> gate) {
      return gate.future;
    }
    return Future<String>.value('$helloPrefix, $name!');
  }

  @override
  Future<BigInt> fibonacci(int n) async {
    if (fibonacciFailure case final BridgeFailure failure) {
      throw failure;
    }
    return BigInt.from(n);
  }

  @override
  Stream<int> countdown({required int count, required int intervalMs}) =>
      _countdown.stream;

  /// 释放假实现占用的所有资源。
  Future<void> dispose() => _countdown.close();
}

/// 一个上报固定平台的 [PlatformRepository]。
class FakePlatformRepository implements PlatformRepository {
  /// 创建假实现，上报 [summaryValue]。
  const FakePlatformRepository({
    this.summaryValue = const PlatformSummary(
      name: 'fakeos',
      family: PlatformFamily.desktop,
      isDesktop: true,
      dataDir: '/tmp/fakeos/frs_kit',
    ),
  });

  /// [summary] 的返回值。
  final PlatformSummary summaryValue;

  @override
  PlatformSummary summary(String appId) => summaryValue;

  @override
  String name() => summaryValue.name;

  @override
  PlatformFamily family() => summaryValue.family;

  @override
  bool isDesktop() => summaryValue.isDesktop;

  @override
  String? dataDir(String appId) => summaryValue.dataDir;
}
