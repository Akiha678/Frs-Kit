//! Dart 被允许调用的一切。
//!
//! # 与 Dart 的对应关系
//!
//! `flutter_rust_bridge.yaml` 让 codegen 指向 `crate::api`，因此这里的布局决定
//! 生成的 Dart 布局，一个模块一个文件：
//!
//! | Rust               | Dart                                |
//! | ------------------ | ----------------------------------- |
//! | `api::hello`       | `lib/src/rust/api/hello.dart`       |
//! | `api::async_demo`  | `lib/src/rust/api/async_demo.dart`  |
//! | `api::stream_demo` | `lib/src/rust/api/stream_demo.dart` |
//! | `api::platform`    | `lib/src/rust/api/platform.dart`    |
//!
//! # 四种往返形式
//!
//! * [`hello`] — 值、struct 与 enum，外加唯一一个 `#[frb(sync)]` 调用。
//! * [`async_demo`] — `Future`，以及 CPU 密集型工作必须跑在哪里。
//! * [`stream_demo`] — 由 Rust 推入 Dart 的 `Stream`。
//! * [`platform`] — 廉价地一次性读取宿主信息。
//!
//! # 新增一个函数
//!
//! 1. 在这些模块之一（或你自己新建的 `pub mod`）里加一个 `pub fn`。
//! 2. 运行 `just gen`，它包装了 `flutter_rust_bridge_codegen generate`。
//! 3. 从 `lib/src/data/` 调用它，再从那里进入 UI。
//!
//! 除非标了 `#[flutter_rust_bridge::frb(sync)]`，函数在 Dart 侧都是异步的；标了
//! 的话函数直接运行在当前调用的 isolate 上，必须保持廉价：不做 I/O、不 sleep、
//! 不等待锁。

pub mod async_demo;
pub mod hello;
pub mod platform;
pub mod stream_demo;
