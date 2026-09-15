/// Hand-written companion to the generated bindings.
///
/// Every other file in `lib/src/rust/` is machine-written by
/// `flutter_rust_bridge_codegen generate` (run `just gen`) and must never be
/// edited: the next run overwrites it without warning.
///
/// This file exists for two reasons:
///
/// * the rest of the app imports one stable path, `package:frs_kit/src/rust/
///   bridge.dart`, instead of reaching into the generated tree — regenerating
///   never forces a rename anywhere else;
/// * "is the native library loaded yet?" is answered in exactly one place.
library;

import 'frb_generated.dart';

export 'api/async_demo.dart';
export 'api/hello.dart';
export 'api/platform.dart';
export 'api/stream_demo.dart';
export 'frb_generated.dart' show RustLib;

/// Loads the native library and runs the Rust initializers.
///
/// Call this exactly once, after `WidgetsFlutterBinding.ensureInitialized()`
/// because loading is asynchronous from Dart's point of view:
///
/// ```dart
/// WidgetsFlutterBinding.ensureInitialized();
/// await initRustBridge();
/// runApp(const FrsKitApp());
/// ```
///
/// The library is looked up in `rust/target/release/` — that path is baked into
/// the generated `kDefaultExternalLibraryLoaderConfig` — so a debug-only
/// `cargo build` is not enough. Use `just build`, which builds the release
/// profile that the loader expects.
///
/// Throws when the library is missing, was built from different sources, or has
/// a codegen/runtime version mismatch. `main` catches that and shows the reason
/// instead of a blank window.
Future<void> initRustBridge() => RustLib.init();
