import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';

/// 一次失败的 bridge 调用，翻译成 UI 可以展示的东西。
///
/// Rust 的错误以 [FrbException] 子类的形式穿过 bridge：返回 `anyhow::Error`
/// 时是 `AnyhowException`，发生 panic 时是 `PanicException`。这些类型对用户毫无
/// 意义，而在每个 widget 里捕获它们会让整个应用都依赖
/// `flutter_rust_bridge`。数据层在这里一次性完成转换，于是它之上的所有代码
/// 都只说 [BridgeFailure]。
final class BridgeFailure implements Exception {
  /// 包装一个已经提取好的 [message]。
  const BridgeFailure(this.message, {this.isPanic = false});

  /// 把 bridge 抛出的任何东西转换成 [BridgeFailure]。
  ///
  /// 幂等：传入 [BridgeFailure] 时原样返回，因此已经翻译过的值 —— 比如状态层
  /// 捕获的流错误 —— 不会被再包成 `BridgeFailure(BridgeFailure(...))`。
  ///
  /// 其他任何值都带着它的 `toString()` 透传，这样数据层里的 bug 仍会以可读的
  /// 信息暴露出来，而不是被吞掉。
  factory BridgeFailure.from(Object error) => switch (error) {
    BridgeFailure() => error,
    AnyhowException(:final message) => BridgeFailure(message),
    PanicException(:final message) => BridgeFailure(message, isPanic: true),
    _ => BridgeFailure('$error'),
  };

  /// 人类可读的原因，与 Rust 写下的内容完全一致。
  final String message;

  /// Rust 是 panic 了，还是返回了一个错误。
  ///
  /// panic 是 bug，而不是被拒绝的输入，所以 UI 可以另行呈现 —— 而且它应当被
  /// 上报，而不只是显示出来。
  final bool isPanic;

  @override
  String toString() => 'BridgeFailure($message)';
}
