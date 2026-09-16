import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';

import '../rust/bridge.dart' as rust;
import 'failure.dart';

/// 应用能就 greeting 向 Rust 端询问的一切。
///
/// 这是边界层，负责三件事：
///
/// * 它是唯一调用生成绑定的地方，所以 Rust API 的改动只会在一个文件里激起涟漪；
/// * 把 bridge 异常转换成 [BridgeFailure]；
/// * 把流的生命周期藏在普通的 `Stream` 后面。
///
/// 生成类型（`rust.Greeting`、`rust.GreetingStyle`）被刻意当作应用的模型使用：
/// 它们是不可变、按值相等的数据类，再手写一份拷贝只会多出一堆映射代码。如果哪天 UI
/// 需要比 bridge 的改动活得更久，把映射加在*这里* —— 这一层就是干这个的。
///
/// bridge 的导入带前缀（`rust.`），这样 FFI 边界在每个调用点都看得见，下面那个
/// `hello` 方法也就不会不小心递归进它自己包装的 `hello` 函数。
class GreetingRepository {
  /// 创建 repository。无状态，所以是 `const`。
  const GreetingRepository();

  /// 同步往返：没有 `Future`，也不跳 isolate。
  ///
  /// 足够廉价，可以在 `build` 期间调用 —— UI 正是这么做的，用来在用户输入时给出
  /// 实时预览。
  String hello(String name) => rust.hello(name: name);

  /// 在 Rust 里校验 [name]，并按 [style] 渲染。
  ///
  /// 名字为空或过长时抛出 [BridgeFailure]。
  Future<rust.Greeting> greet({
    required String name,
    required rust.GreetingStyle style,
  }) => _guard(() => rust.greet(name: name, style: style));

  /// 等 [delayMs] 毫秒之后再问候 [name]。
  ///
  /// 等待发生在 Rust 的 worker 线程上，因此这个 future 挂起期间 Flutter UI 仍在持续
  /// 绘制：这次调用不会让任何一帧卡顿。
  Future<String> delayedHello({required String name, required int delayMs}) =>
      _guard(() => rust.delayedHello(name: name, delayMs: delayMs));

  /// 第 [n] 个斐波那契数，在异步 runtime 之外计算。
  ///
  /// 返回 [BigInt]，因为在 web 上 Rust 的 `u64` 装不进 Dart 定长的 `int` —— 那里的
  /// 整数是 double。参见 `docs/architecture.md`。
  Future<BigInt> fibonacci(int n) => _guard(() => rust.fibonacci(n: n));

  /// 从 [count] 倒数到 `1`，每隔 [intervalMs] 产出一个值。
  ///
  /// 倒数结束时流关闭。取消订阅也会一并停掉 Rust 侧的循环，因此被丢弃的流不会让
  /// worker 线程继续活着：参见 `rust/src/api/stream_demo.rs`。
  Stream<int> countdown({required int count, required int intervalMs}) =>
      rust.countdown(count: count, intervalMs: intervalMs);

  /// 执行 [call]，把任何 bridge 异常转换成 [BridgeFailure]。
  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on FrbException catch (error) {
      throw BridgeFailure.from(error);
    }
  }
}
