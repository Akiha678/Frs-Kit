/// 生成绑定的手写配套文件。
///
/// `lib/src/rust/` 下的其他文件全部由
/// `flutter_rust_bridge_codegen generate`（即 `just gen`）机器生成，绝不要
/// 编辑：下一次生成会无声地覆盖它们。
///
/// 这个文件存在的理由有两条：
///
/// * 应用其余部分只导入一个稳定路径 `package:frs_kit/src/rust/
///   bridge.dart`，不必伸手进生成目录 —— 重新生成永远不会逼着别处改名；
/// * “原生库加载好了吗？”这个问题只在一个地方回答。
library;

import 'frb_generated.dart';

export 'api/async_demo.dart';
export 'api/hello.dart';
export 'api/platform.dart';
export 'api/stream_demo.dart';
export 'frb_generated.dart' show RustLib;

/// 加载原生库并运行 Rust 初始化代码。
///
/// 只调用一次，且要在 `WidgetsFlutterBinding.ensureInitialized()` 之后，因为从
/// Dart 的角度看加载是异步的：
///
/// ```dart
/// WidgetsFlutterBinding.ensureInitialized();
/// await initRustBridge();
/// runApp(const FrsKitApp());
/// ```
///
/// 库从 `rust/target/release/` 查找 —— 这个路径写死在生成的
/// `kDefaultExternalLibraryLoaderConfig` 里 —— 所以只跑 debug 的 `cargo build`
/// 不够，要用 `just build`，它构建的正是加载器所期望的 release profile。
///
/// 库缺失、由不同源码构建、或 codegen/runtime 版本不匹配时都会抛出。`main`
/// 捕获它并显示原因，而不是留下一片空白窗口。
Future<void> initRustBridge() => RustLib.init();
