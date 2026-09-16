<div align="center">

<img src="docs/images/logo/frs_kit_logo.png" width="120" alt="Frs_Kit Logo"/>

# Frs_Kit

_A Flutter + Rust project scaffold: four runnable bridge round-trips, backed by two layers of tests_

<!-- Language switch button -->
<div align="center">
  <a href="README.md">🌍 中文</a>
</div>

[![Flutter](https://img.shields.io/badge/Flutter-3.47.0-02569B?style=flat-square&logo=flutter)](https://flutter.dev)
[![Rust](https://img.shields.io/badge/Rust-1.98-000000?style=flat-square&logo=rust)](https://www.rust-lang.org)
[![flutter_rust_bridge](https://img.shields.io/badge/flutter__rust__bridge-2.13.0-blue?style=flat-square)](https://cjycode.com/flutter_rust_bridge/)
![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20iOS%20%7C%20Android%20%7C%20Windows%20%7C%20Linux-4c8bf5?style=flat-square)
![Tests](https://img.shields.io/badge/tests-64%20fast%20%2B%2022%20e2e-success?style=flat-square)

</div>

## 📖 Project overview

Frs_Kit is a cross-platform project scaffold built with **Flutter / Dart / Rust / flutter_rust_bridge**. It turns the parts of a "Flutter on top, Rust underneath" app that actually go wrong into runnable examples: where the FFI boundary sits, which calls occupy the UI isolate, how a Rust error keeps its message on the way to Dart, and why a stream nobody listens to should stop.

It is not "hello world with a native library bolted on". The scaffold is built around the four things a real app needs from Rust — a **synchronous call, an asynchronous call, a stream, and host facts** — each one implemented, tested at two levels, and documented where the decisions are made. The goal is **clone → `just setup` → `just run` → build your feature**.

macOS desktop is verified end to end, including on-device tests. The native projects and build integration for Android, iOS, Windows and Linux are in place; the web target is not wired up yet.

> If this scaffold helps you, a Star ⭐ is appreciated.

## 🧩 Built-in capabilities

- **Four bridge round-trips**: synchronous call, `Future`, `Stream`, and host facts, each with its own module and demo panel
- **A single FFI seam**: only `rust/src/api/**` may mention `flutter_rust_bridge`, and only `lib/src/data/**` may call the generated bindings
- **An explicit threading model**: `#[frb(sync)]` runs on the calling isolate, everything else on FRB's multi-threaded runtime, and blocking or CPU-bound work is moved to the blocking pool on purpose
- **One error translation**: Rust `anyhow::Error` / panics become `AnyhowException` / `PanicException`, converted in exactly one place into a `BridgeFailure`, idempotently
- **Cancellable streams**: a cancelled subscription makes Rust's next `add` fail, so the loop returns instead of running for nobody
- **Two layers of tests**: fast unit and widget tests against fakes, plus end-to-end tests that load the real native library on a device
- **Version consistency checks**: the `flutter_rust_bridge` version lives in four places, and `just check` fails if they disagree — a mismatch is a startup crash
- **Native bundling that works out of the box**: cargokit compiles and bundles the Rust library during the platform build, with no hand-written Podfile/CMake/Gradle glue
- **GetX state management and DI**: `GetxController` + `Rx` + `Obx`, so only the widgets that read a value rebuild;
- **One entry point for tasks**: 18 `just` recipes covering generation, build, check, test and run
- **Documentation that explains the trade-offs**: architecture, daily development, and a symptom-to-fix troubleshooting guide

## 🛠️ Tech stack

| Category | Choice | Notes |
| --- | --- | --- |
| Languages | Dart + Rust | UI and state in Dart, domain logic and platform differences in Rust |
| UI framework | Flutter | One codebase for desktop and mobile |
| Bridge | flutter_rust_bridge 2.13 | Generates the Dart bindings from the Rust API; no hand-written FFI |
| Native bundling | cargokit (`rust_builder/`) | Compiles Rust during the platform build and bundles it (macOS / iOS / Android / Windows / Linux) |
| Rust async | tokio (runtime provided by flutter_rust_bridge) | Non-`sync` functions run on the multi-threaded runtime FRB creates |
| Rust errors | anyhow + thiserror | `thiserror` for domain errors, `anyhow` at the boundary |
| Domain layering | Separate crates (`crates/core`, `crates/platform`) | No FFI, unit-testable on their own, reusable from a CLI |
| State management | GetX 4.7 | `GetxController` + `Rx`/`Obx` for fine-grained rebuilds, `Bindings` for dependency injection |
| Testing | cargo test + flutter_test + integration_test | Fast layer against fakes, end-to-end layer against the real library |
| Code quality | cargo fmt / clippy / flutter_lints + strict lints | All in `just check`; clippy warnings are errors |
| Toolchain pinning | rustup + fvm (optional) | `rust-toolchain.toml` and `.fvmrc` pin each side |

## 🔁 The four round-trips

| Round-trip | Rust | Dart | Demonstrates |
| --- | --- | --- | --- |
| Values, structs, enums | `rust/src/api/hello.rs` | `Future<Greeting> greet(...)` | `#[frb(sync)]` vs a `Future`, wire DTOs, domain validation |
| Async work | `rust/src/api/async_demo.rs` | `Future<String>`, `Future<BigInt>` | staying off the UI isolate, moving CPU-bound work to the blocking pool |
| Streams | `rust/src/api/stream_demo.rs` | `Stream<int> countdown(...)` | pushing values from Rust, cancellation that reaches back |
| Host facts | `rust/src/api/platform.rs` | `PlatformSummary platformSummary(...)` | cheap synchronous calls, catching a stale native library |

The home page is those four panels, and the tests are the evidence:

- `cargo test` — 30 unit tests (15 in the domain crate, 7 in the platform crate, 8 in the bridge crate) plus 2 doc-tests
- `flutter test` — 32 tests: unit tests for the state machine and widget tests for the whole UI, all against fakes, in about two seconds
- `just test-e2e` — 22 tests: the real native library on a real device, covering real validation messages, real timings, the `u64` boundary and stream cancellation

## 📁 Architecture

The path from the UI to Rust runs one way only:

```text
ui -> state -> data -> rust/ (generated) -> rust/src/api -> crates/core, crates/platform
```

`rust/src/api/**` is the seam. Below it is ordinary Rust that knows nothing about Dart; above it is ordinary Flutter that knows nothing about FFI. `docs/architecture.md` explains why, and what breaks when you ignore it.

```text
lib/
├── main.dart                  # load the native library, then run the app
├── src/
│   ├── app.dart               # app root: owns HomeState, injects the repositories
│   ├── app_info.dart          # application id and name, in one place
│   ├── rust/                  # the FFI boundary
│   │   ├── bridge.dart        # hand-written: re-exports + initRustBridge()
│   │   ├── frb_generated*.dart# generated: loader, codecs, wire functions
│   │   └── api/               # generated: one file per Rust api module
│   ├── data/                  # the only layer that calls the generated bindings
│   ├── state/                 # HomeState (GetxController) + HomeBinding registration
│   └── ui/                    # home page, four panels, theme
rust/
├── Cargo.toml                 # workspace root AND the bridge crate
├── src/
│   ├── lib.rs                 # crate docs + the two layering rules
│   ├── api/                   # the only Rust that may mention flutter_rust_bridge
│   └── frb_generated.rs       # generated glue
└── crates/
    ├── core/                  # domain logic; no FFI, unit-testable on its own
    └── platform/              # one small module per operating system
rust_builder/                  # cargokit: builds and bundles the native library
test/                          # fakes + unit and widget tests (fast)
integration_test/              # the real bridge, on a real device
examples/                      # three focused entrypoints: hello_rust / async_demo / stream_demo
docs/                          # architecture, development, troubleshooting
scripts/                       # toolchain check, version consistency check
justfile                       # every command in one list: just
```

## 🚀 Quick start

### Requirements

- **Flutter** 3.47.0 (pinned in `.fvmrc`; `fvm` is optional and skipped automatically when absent)
- **Rust** via rustup — `rust-toolchain.toml` pins stable with `rustfmt` and `clippy`, which rustup installs on first use inside `rust/`
- **flutter_rust_bridge_codegen**, at exactly the version in `pubspec.yaml`:

  ```bash
  cargo install flutter_rust_bridge_codegen --version 2.13.0 --locked
  ```

- **just** ([installation](https://github.com/casey/just#installation)) — optional; read the `justfile` and run the commands yourself if you prefer

`scripts/setup.sh --check` (that is `just doctor`) reports what is present and what is missing. A mismatch between the code generator, the Dart package and the Rust crate is a startup crash, which is why `just check` verifies all four places agree.

### Install and run

```bash
just setup     # flutter pub get + cargo build --release
just run       # build, then launch on macOS; use just run device=chrome for another target
```

Without `just`, the same thing by hand:

```bash
flutter pub get
cargo build --release --manifest-path rust/Cargo.toml
flutter run -d macos
```

### Common commands

| Command | What it does |
| --- | --- |
| `just` | list every recipe |
| `just setup` | `pub get` + release build of the native library |
| `just doctor` | report toolchain and version consistency |
| `just gen` | regenerate the Dart bindings after changing the Rust API |
| `just gen-watch` | the same, continuously while you edit |
| `just build` | `cargo build --release` — the profile the loader looks for |
| `just run` | build, then `flutter run -d macos` (`device=chrome` to override) |
| `just check` | versions, `cargo fmt --check`, `cargo clippy -D warnings`, `flutter analyze` |
| `just test` | Dart unit and widget tests (fast, no native library) |
| `just test-e2e` | the real bridge on a real device, one file per run |
| `just test-all` | all of the above |
| `just versions` | print the flutter_rust_bridge version everywhere it appears |

`just build` is not optional decoration: the generated Dart has `rust/target/release/` baked in as its load path, so a debug-only `cargo build` is invisible to it. When the library is missing, the app says so on screen instead of showing a blank window.

### Code generation

After every change to `rust/src/api/**` the Dart bindings must be regenerated, or Dart keeps compiling against the old signature:

```bash
just gen          # equivalent to flutter_rust_bridge_codegen generate
just gen-watch    # keep regenerating while you edit
```

`rust/src/frb_generated.rs` and `lib/src/rust/**` are generated, and are **committed on purpose** so a change to the boundary shows up in review — but never edit them by hand: the next run overwrites them.

### Quality checks and tests

```bash
just check      # versions + cargo fmt --check + clippy (-D warnings) + flutter analyze
just rust-test  # Rust unit and doc tests
just test       # Dart unit and widget tests (fakes)
just test-e2e   # end-to-end tests on a device (builds the native library first)
just test-all   # everything
```

The two test layers are separate for a reason: `just test` uses fakes to prove that the widgets and the state machine react correctly to what a repository returns — two seconds, no native library. `just test-e2e` proves what fakes cannot: that the library on disk matches the generated bindings, that the loader finds it, and that a Rust error message still reads the same after crossing FFI.

### Run the examples

Three small apps, one idea each:

```bash
just build
flutter run -t examples/hello_rust/main.dart  -d macos   # sync vs async
flutter run -t examples/async_demo/main.dart  -d macos   # waiting without freezing
flutter run -t examples/stream_demo/main.dart -d macos   # streams and cancellation
```

## ➕ Adding an API function

1. Write it in `rust/src/api/` (or a new module there) as a `pub fn`
2. `just gen` — the Dart bindings appear under `lib/src/rust/api/`
3. Call it from `lib/src/data/`, convert failures to `BridgeFailure`, and let the state layer own it
4. `just test` for the fast loop, `just test-e2e` for the truth

Functions are asynchronous on the Dart side unless marked `#[frb(sync)]`. That attribute runs the call on the calling isolate, so it only suits work that is cheap enough not to stutter the UI (formatting a string, reading a constant); file and network I/O, sleeping and lock waiting are all out. `docs/development.md` walks through a complete example, including how to test it.

## 📦 Release builds

cargokit in `rust_builder/` compiles and bundles the Rust library during the platform build, so the plain Flutter commands are enough — no manual `cargo build` first:

```bash
# macOS
flutter build macos --release

# iOS
flutter build ios --release

# Android: arm64 APK / AAB for the store
flutter build apk --release --split-per-abi
flutter build appbundle --release

# Windows / Linux
flutter build windows --release
flutter build linux --release
```

Things worth knowing:

- **The first build is slow**: cargokit compiles Rust for every target architecture and installs missing targets through rustup
- **Platform limits**: Windows and Linux apps must be built on those systems; iOS and macOS need macOS with Xcode
- **The web target is not wired up**: it still needs `wasm-pack` and `flutter_rust_bridge_codegen build-web`, which no recipe wraps and which is unverified here
- **Outside an app bundle** (a plain Dart VM run), the loader looks for `rust/target/release/librust_lib_frs_kit.{dylib,so,dll}`, which `just build` produces

## 📚 Documentation

- **Architecture**: [`docs/architecture.md`](docs/architecture.md)
  - Layering rules, the trade-offs behind each round-trip, the threading model, how errors cross the bridge, why generated code is committed
- **Development**: [`docs/development.md`](docs/development.md)
  - The full loop from editing Rust to shipping, with an end-to-end example and how to test it
- **Troubleshooting**: [`docs/troubleshooting.md`](docs/troubleshooting.md)
  - Symptom → cause → fix, starting with the two everyone hits: a missing native library and a version mismatch
- **flutter_rust_bridge documentation**: [read online](https://cjycode.com/flutter_rust_bridge/)
  - Generation config, type mapping, async and streams
- **Flutter documentation**: [read online](https://docs.flutter.dev)
  - Cross-platform development, builds and releases

## 🤝 Contributing

Issues and pull requests are welcome.

- **Bug reports**: reproducible bugs, platform compatibility problems, feature suggestions
- **Code**: finish a feature, fix a problem, add an example
- **Documentation**: improve the guides, the architecture notes or the troubleshooting entries
- **Testing**: verify behaviour on macOS / Windows / Linux / Android / iOS, especially first builds

Before opening a pull request, make sure `just check` and `just test` are green. If you changed the Rust API, run `just gen` and update both the fakes in `test/` and the end-to-end cases in `integration_test/`. Do not hand-edit generated code (`rust/src/frb_generated.rs`, `lib/src/rust/**`).
