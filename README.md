# frs_kit

A Flutter + Rust application scaffold, wired together with
[flutter_rust_bridge](https://cjycode.com/flutter_rust_bridge/) 2.13.

It is not "hello world with a native library bolted on". The scaffold is built
around a working example of the four things a real app needs from Rust — a
synchronous call, an asynchronous call, a stream, and host facts — each one
implemented, tested at two levels, and documented where the decisions are made.

```sh
just setup     # fetch Dart packages, build the native library
just run       # build, then launch on macOS
```

## What works today

| Round-trip | Rust | Dart | Demonstrates |
| --- | --- | --- | --- |
| Values, structs, enums | `rust/src/api/hello.rs` | `Future<Greeting> greet(...)` | `#[frb(sync)]` vs a `Future`, wire DTOs, domain validation |
| Async work | `rust/src/api/async_demo.rs` | `Future<String>`, `Future<BigInt>` | staying off the UI isolate, moving CPU-bound work to the blocking pool |
| Streams | `rust/src/api/stream_demo.rs` | `Stream<int> countdown(...)` | pushing values from Rust, cancellation that reaches back |
| Host facts | `rust/src/api/platform.rs` | `PlatformSummary platformSummary(...)` | cheap synchronous calls, catching a stale native library |

The app is those four panels, and the tests are the evidence:

- `cargo test` in `rust/` — 32 tests across the domain crate, the platform crate
  and the bridge crate.
- `flutter test` — 32 tests: unit tests for the state machine and widget tests for
  the whole UI, all against fakes, in about two seconds, no native library needed.
- `flutter test integration_test -d <device>` — 22 tests against the real library,
  the real widget tree and the real error messages.

## Layout

```
lib/
  main.dart                  load the native library, then run the app
  src/
    app.dart                 app root: owns HomeState, injects the repositories
    app_info.dart            application id and name, in one place
    rust/                    the FFI boundary
      bridge.dart            hand-written: re-exports + initRustBridge()
      frb_generated*.dart    generated: loader, codecs, wire functions
      api/*.dart             generated: one file per Rust api module
    data/                    the only layer that calls the generated bindings
    state/                   HomeState (ChangeNotifier) + its InheritedNotifier scope
    ui/                      home page, panels, theme

rust/
  Cargo.toml                 workspace root AND the bridge crate
  src/
    lib.rs                   crate docs + the two layering rules
    api/                     the only Rust that may mention flutter_rust_bridge
    frb_generated.rs         generated glue
  crates/
    core/                    domain logic; no FFI, unit-testable on its own
    platform/                one small module per operating system
  rustfmt.toml, clippy.toml

rust_builder/                cargokit: builds and bundles the native library
                             into app builds (macOS, iOS, Android, Windows, Linux)
test/                        fakes + unit and widget tests (fast)
integration_test/            the real bridge, on a real device
examples/                    three focused entrypoints, one per topic
docs/                        architecture, development, troubleshooting
scripts/                     toolchain check, version consistency check
justfile                     every command in one list: `just`
```

The path from the UI to Rust is one direction only:

```
ui -> state -> data -> rust/ (generated) -> rust/src/api -> crates/core, crates/platform
```

`rust/src/api/**` is the seam. Everything below it is ordinary Rust that knows
nothing about Dart; everything above it is ordinary Flutter that knows nothing
about FFI. `docs/architecture.md` explains why, and what breaks when you ignore it.

## Requirements

- **Flutter** 3.47.0 (pinned in `.fvmrc`; `fvm` is optional, the toolchain is
  skipped automatically if it is not installed)
- **Rust** via rustup — `rust-toolchain.toml` pins stable with `rustfmt` and
  `clippy`, which rustup installs on first use inside `rust/`
- **flutter_rust_bridge_codegen** at the version in `pubspec.yaml`:

  ```sh
  cargo install flutter_rust_bridge_codegen --version 2.13.0 --locked
  ```

- **just** ([installation](https://github.com/casey/just#installation)) — or read
  the `justfile` and run the commands yourself

`scripts/setup.sh --check` reports what is present and what is missing. A version
mismatch between the code generator, the Dart package and the Rust crate is a
startup crash, so `just check` verifies all four places agree.

## Everyday commands

| Command | What it does |
| --- | --- |
| `just` | list every recipe |
| `just setup` | `pub get` + release build of the native library |
| `just doctor` | report toolchain and version consistency |
| `just gen` | regenerate the Dart bindings after changing the Rust API |
| `just gen-watch` | the same, continuously while you edit |
| `just build` | `cargo build --release` — the profile the loader looks for |
| `just run` | build, then `flutter run -d macos` (`device=chrome` to override) |
| `just check` | bridge versions, `cargo fmt --check`, `cargo clippy -D warnings`, `flutter analyze` |
| `just test` | Dart unit and widget tests (fast, no native library) |
| `just test-e2e` | the real bridge on a real device |
| `just test-all` | all of the above |
| `just versions` | print the flutter_rust_bridge version everywhere it appears |

`just build` is not optional decoration: the generated Dart loads
`rust/target/release/librust_lib_frs_kit.{dylib,so,dll}`, so a debug-only
`cargo build` is invisible to it. If the library is missing, the app says so on
screen instead of showing a blank window.

## Examples

Three small apps, each about one idea, runnable straight from this checkout:

```sh
just build
flutter run -t examples/hello_rust/main.dart  -d macos   # sync vs async
flutter run -t examples/async_demo/main.dart  -d macos   # waiting without freezing
flutter run -t examples/stream_demo/main.dart -d macos   # streams and cancellation
```

## Adding a function

1. Write it in `rust/src/api/` (or a new module there) as a `pub fn`.
2. `just gen` — Dart bindings appear under `lib/src/rust/api/`.
3. Call it from `lib/src/data/`, convert failures to `BridgeFailure`, and let the
   state layer own it.
4. `just test` for the fast loop, `just test-e2e` for the truth.

`docs/development.md` walks through a complete example, including how to test it.
Functions are asynchronous on the Dart side unless marked `#[frb(sync)]`; the
choice matters, and that document explains when to make it.

## Where to read next

- `docs/architecture.md` — the layering, the threading model, and the rules that
  keep generated code from leaking into your app.
- `docs/development.md` — the daily loop, from editing Rust to shipping.
- `docs/troubleshooting.md` — symptom to cause to fix, starting with the two
  failures everyone hits: a missing native library and a version mismatch.
