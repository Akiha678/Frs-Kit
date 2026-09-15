import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/rust/bridge.dart';
import 'src/ui/rust_unavailable_app.dart';

/// Starts the app.
///
/// Two steps, in this order:
///
/// 1. `ensureInitialized()` — required before any plugin or FFI call, because Dart
///    may run this function before the engine is ready.
/// 2. `initRustBridge()` — loads the native library and runs the Rust
///    initializers. Every call into `lib/src/rust/` needs this to have finished,
///    including the synchronous ones.
///
/// A failure in step 2 is expected on a fresh checkout, where nobody has run
/// `just build` yet, so it is reported on screen instead of ending in a white
/// window.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await initRustBridge();
  } catch (error, stackTrace) {
    runApp(RustUnavailableApp(error: error, stackTrace: stackTrace));
    return;
  }

  runApp(const FrsKitApp());
}
