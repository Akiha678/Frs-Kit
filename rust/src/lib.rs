//! bridge crate：Dart 唯一能触达的 Rust 代码。
//!
//! 分层，自上而下：
//!
//! ```text
//! Dart (lib/)                        ->  src/api/            （本 crate）
//!   ui -> state -> data -> rust          hello, async_demo,
//!                                        stream_demo, platform
//!                                            |
//!                                            v
//!                                        crates/core, crates/platform
//!                                        （纯 Rust，无 FFI）
//! ```
//!
//! 两条规则保障这棵依赖树健康：
//!
//! 1. `src/api/**` 是 *唯一* 允许提到 `flutter_rust_bridge` 的地方。领域 crate
//!    因此仍可被测试、benchmark 和 CLI 使用。
//! 2. `src/api/**` 里每个 `pub` 条目，以及它提到的每个 `pub` struct/enum，都会
//!    成为 Dart API 的一部分。宁可多写几个小模块，也不要写一个大模块，因为模块
//!    路径会成为 Dart 文件名：`api/hello.rs` 变成
//!    `lib/src/rust/api/hello.dart`。
//!
//! codegen 通常会把它的胶水模块声明注入到本文件顶部。这里改为手写在文档之后，
//! 好让这些 crate 级文档始终是文件里的第一段内容。

pub mod api;

// 机器生成的 FFI 胶水代码，由 `just gen` 重写。有意声明在文档之后：注入到文档
// 之上的那一行会把文档变成编译错误。
#[allow(clippy::all)]
mod frb_generated;
