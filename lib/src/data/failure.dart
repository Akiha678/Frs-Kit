import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';

final class BridgeFailure implements Exception {
  const BridgeFailure(this.message, {this.isPanic = false});

  factory BridgeFailure.from(Object error) => switch (error) {
    BridgeFailure() => error,
    AnyhowException(:final message) => BridgeFailure(message),
    PanicException(:final message) => BridgeFailure(message, isPanic: true),
    _ => BridgeFailure('$error'),
  };

  final String message;
  final bool isPanic;

  @override
  String toString() => 'BridgeFailure($message)';
}
