import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';

import '../rust/bridge.dart' as rust;
import 'failure.dart';

/// Everything the app can ask the Rust side about greetings.
///
/// This is the boundary layer. It owns three jobs:
///
/// * it is the only place that calls into the generated bindings, so a change to
///   the Rust API ripples through one file;
/// * it converts bridge exceptions into [BridgeFailure];
/// * it hides streams' lifetimes behind an ordinary `Stream`.
///
/// The generated types (`rust.Greeting`, `rust.GreetingStyle`) are used as the
/// app's models on purpose: they are immutable, value-equal data classes, so a
/// second hand-written copy would only add mapping code. If the UI ever needs to
/// outlive a bridge change, add the mapping *here* — that is what this layer is
/// for.
///
/// The bridge import is prefixed (`rust.`) so that the FFI boundary is visible at
/// every call site, and so the `hello` method below cannot accidentally recurse
/// into the `hello` function it wraps.
class GreetingRepository {
  /// Creates a repository. Stateless, hence `const`.
  const GreetingRepository();

  /// The synchronous round-trip: no `Future`, no isolate hop.
  ///
  /// Cheap enough to call during `build`, which is exactly what the UI does to
  /// show a live preview as the user types.
  String hello(String name) => rust.hello(name: name);

  /// Validates [name] in Rust and renders it in [style].
  ///
  /// Throws [BridgeFailure] when the name is blank or too long.
  Future<rust.Greeting> greet({
    required String name,
    required rust.GreetingStyle style,
  }) => _guard(() => rust.greet(name: name, style: style));

  /// Greets [name] after waiting [delayMs] milliseconds.
  ///
  /// The wait happens on a Rust worker thread, so the Flutter UI keeps painting
  /// while this future is pending: nothing in this call can stutter a frame.
  Future<String> delayedHello({required String name, required int delayMs}) =>
      _guard(() => rust.delayedHello(name: name, delayMs: delayMs));

  /// The [n]-th Fibonacci number, computed off the async runtime.
  ///
  /// Returns a [BigInt] because Rust's `u64` does not fit Dart's fixed-size
  /// `int` on the web, where integers are doubles. See `docs/architecture.md`.
  Future<BigInt> fibonacci(int n) => _guard(() => rust.fibonacci(n: n));

  /// Counts down from [count] to `1`, one value every [intervalMs].
  ///
  /// The stream closes when the countdown finishes. Cancelling the subscription
  /// stops the Rust loop as well, so an abandoned stream does not keep a worker
  /// thread alive: see `rust/src/api/stream_demo.rs`.
  Stream<int> countdown({required int count, required int intervalMs}) =>
      rust.countdown(count: count, intervalMs: intervalMs);

  /// Runs [call], converting any bridge exception into a [BridgeFailure].
  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on FrbException catch (error) {
      throw BridgeFailure.from(error);
    }
  }
}
