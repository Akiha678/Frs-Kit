//! The bridge crate: the only Rust code Dart can reach.
//!
//! Layering, from top to bottom:
//!
//! ```text
//! Dart (lib/)                        ->  src/api/            (this crate)
//!   ui -> state -> data -> rust          hello, async_demo,
//!                                        stream_demo, platform
//!                                            |
//!                                            v
//!                                        crates/core, crates/platform
//!                                        (pure Rust, no FFI)
//! ```
//!
//! Two rules keep the tree healthy:
//!
//! 1. `src/api/**` is the *only* place allowed to mention `flutter_rust_bridge`.
//!    The domain crates stay usable from tests, benchmarks and a CLI.
//! 2. Every `pub` item in `src/api/**`, and every `pub` struct/enum it names,
//!    becomes part of the Dart API. Prefer many small modules over one large one,
//!    because the module path becomes the Dart file name: `api/hello.rs` becomes
//!    `lib/src/rust/api/hello.dart`.
//!
//! The code generator normally injects the declaration of its glue module at the
//! top of this file. It is written out by hand below instead, so that these
//! crate-level docs stay the first thing in the file.

pub mod api;

// Machine-written FFI glue, rewritten by `just gen`. Declared after the docs on
// purpose: an injected line above them would turn them into a compile error.
#[allow(clippy::all)]
mod frb_generated;
