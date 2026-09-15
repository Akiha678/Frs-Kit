import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';

/// A failed bridge call, translated into something the UI may show.
///
/// Rust errors cross the bridge as [FrbException] subclasses: `AnyhowException`
/// for a returned `anyhow::Error`, `PanicException` for a panic. Those types say
/// nothing useful to a user, and catching them in every widget would spread a
/// dependency on `flutter_rust_bridge` through the whole app. The data layer
/// converts them here, once, so everything above it speaks [BridgeFailure].
final class BridgeFailure implements Exception {
  /// Wraps an already-extracted [message].
  const BridgeFailure(this.message, {this.isPanic = false});

  /// Converts whatever the bridge threw into a [BridgeFailure].
  ///
  /// Idempotent: a [BridgeFailure] is returned unchanged, so a value that was
  /// already translated — a stream error caught by the state layer, say — does not
  /// end up wrapped as `BridgeFailure(BridgeFailure(...))`.
  ///
  /// Anything else is passed through with its `toString()`, so a bug in the data
  /// layer still surfaces with a readable message instead of being swallowed.
  factory BridgeFailure.from(Object error) => switch (error) {
    BridgeFailure() => error,
    AnyhowException(:final message) => BridgeFailure(message),
    PanicException(:final message) => BridgeFailure(message, isPanic: true),
    _ => BridgeFailure('$error'),
  };

  /// Human-readable reason, exactly as Rust wrote it.
  final String message;

  /// Whether Rust panicked instead of returning an error.
  ///
  /// A panic is a bug rather than a rejected input, so the UI is free to present
  /// it differently — and it should be reported, not just displayed.
  final bool isPanic;

  @override
  String toString() => 'BridgeFailure($message)';
}
