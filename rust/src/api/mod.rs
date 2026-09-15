//! Everything Dart is allowed to call.
//!
//! # How this maps to Dart
//!
//! `flutter_rust_bridge.yaml` points the code generator at `crate::api`, so the
//! layout here decides the generated Dart layout, one file per module:
//!
//! | Rust               | Dart                                |
//! | ------------------ | ----------------------------------- |
//! | `api::hello`       | `lib/src/rust/api/hello.dart`       |
//! | `api::async_demo`  | `lib/src/rust/api/async_demo.dart`  |
//! | `api::stream_demo` | `lib/src/rust/api/stream_demo.dart` |
//! | `api::platform`    | `lib/src/rust/api/platform.dart`    |
//!
//! # The four round-trips
//!
//! * [`hello`] — values, structs and enums, plus the one `#[frb(sync)]` call.
//! * [`async_demo`] — `Future`s, and where CPU-bound work must run.
//! * [`stream_demo`] — `Stream`s pushed from Rust into Dart.
//! * [`platform`] — reading host facts once, cheaply.
//!
//! # Adding a function
//!
//! 1. Add a `pub fn` to one of these modules (or a new `pub mod` of your own).
//! 2. Run `just gen`, which wraps `flutter_rust_bridge_codegen generate`.
//! 3. Call it from `lib/src/data/`, and from there into the UI.
//!
//! Functions are asynchronous on the Dart side unless marked
//! `#[flutter_rust_bridge::frb(sync)]`, in which case they run directly on the
//! calling isolate and must stay cheap: no I/O, no sleeping, no waiting on locks.

pub mod async_demo;
pub mod hello;
pub mod platform;
pub mod stream_demo;
