import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/rust/bridge.dart';
import 'src/ui/rust_unavailable_app.dart';

/// 启动应用。
///
/// 两步，顺序不能颠倒：
///
/// 1. `ensureInitialized()` —— 任何插件或 FFI 调用之前都必须执行，因为 Dart
///    可能在引擎就绪之前就跑到这个函数。
/// 2. `initRustBridge()` —— 加载原生库并运行 Rust 初始化代码。对
///    `lib/src/rust/` 的每次调用（包括同步调用）都要求这一步已经完成。
///
/// 第 2 步失败在全新检出的仓库里是预期内的 —— 此时还没人跑过 `just build` ——
/// 所以把原因显示在界面上，而不是留下一片白窗口。
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
