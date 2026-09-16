# Development

The everyday guide: what to install, the order to edit the two halves in, and the commands
that check the result. Every command named here exists in `justfile` or `scripts/`.

## Prerequisites

Required: the Flutter SDK (`.fvmrc` pins 3.47.0 for fvm users), Rust through rustup
(`rust-toolchain.toml` pins `stable` with `rustfmt` and `clippy`, which rustup installs
on first use inside `rust/`), `just`, and the code generator at exactly the version the
runtime uses:

```sh
cargo install flutter_rust_bridge_codegen --version 2.13.0 --locked
```

Optional: `fvm` (skipped automatically when absent) and `wasm-pack` for the web build;
`scripts/setup.sh` reports all of them.

## First run

```sh
just setup          # flutter pub get + cargo build --release
just doctor         # report the toolchain and the four bridge versions; changes nothing
just check          # bridge versions, rustfmt, clippy, flutter analyze
```

`just doctor` runs `scripts/setup.sh --check`, which is safe to re-run and prints what is
installed. Drop the `--check` to have the same script do the two setup steps as well.

## The daily loop

```sh
# 1. edit rust/src/api/** (or rust/crates/**)
just gen            # regenerate the Dart bindings
# 2. edit lib/src/data/**, then lib/src/state/**, then lib/src/ui/**
just test           # fast: fakes, no native library, no device
just run            # builds the release library, then flutter run -d macos
```

`just gen-watch` re-runs the generator continuously while you edit the Rust API, and
`just rust-test` runs the Rust tests on their own. The order matters: nothing but
`just gen` regenerates the Dart bindings.

## Adding an API function, end to end

A worked example: a synchronous `shout` next to `hello`.

**1. Add the function** to `rust/src/api/hello.rs`:

```rust
/// Uppercases the greeting `hello` renders.
/// `#[frb(sync)]` for the same reason as [`hello`]: a `format!` is cheap enough
/// to run on the calling isolate.
#[frb(sync)]
pub fn shout(name: String) -> String {
    rust_flutter_core::hello(&name).to_uppercase()
}
```

**2. Regenerate** with `just gen`. `lib/src/rust/api/hello.dart` gains
`String shout({required String name})`; never edit that file, as the next run overwrites
it.

**3. Wrap it in the data layer.** `FakeGreetingRepository` implements `GreetingRepository`,
so a new repository method needs an entry in the fake too, or `flutter test` will not
compile:

```dart
// lib/src/data/greeting_repository.dart
/// The same synchronous round-trip, louder.
String shout(String name) => rust.shout(name: name);

// test/fakes/fake_repositories.dart
@override
String shout(String name) {
  calls.add(name);
  return '$helloPrefix, $name!'.toUpperCase();
}
```

**4. Expose it to the UI**: add a getter to `HomeState` next to `instantHello` —
`String get instantShout => greetings.shout(name.value);` — then read it from a widget
inside an `Obx`, e.g. `ValueLine(label: 'shout', value: state.instantShout)`. The `Obx` is
what subscribes that widget to whichever `Rx` the getter reads.

**5. Check it**: `just check`, `just rust-test`, `just test`, then `just run`. Two rules
hold throughout: never edit `lib/src/rust/**` by hand, and never add
`flutter_rust_bridge` to `rust/crates/**`.

## When to use `#[frb(sync)]`

Use it when the call is cheap by construction: formatting a string, reading a constant,
copying a small value. It runs on the calling Dart isolate, so file and network I/O,
sleeping and lock waiting are all forbidden there, and a slow call stutters the UI.
Everything else is asynchronous on the Dart side.

Work that blocks or burns CPU belongs behind a `Future` and, on the Rust side, on the
blocking pool — see `run_blocking` in `rust/src/api/async_demo.rs`, which wraps
`flutter_rust_bridge::spawn_blocking_with`.

## `just test` versus `just test-e2e`

| | `just test` | `just test-e2e` |
| --- | --- | --- |
| runs | `flutter test` | `just build`, then each file under `integration_test/` in its own `flutter test <file> -d <device>` run |
| needs | only the Dart SDK | a device, and the native library |
| covers | `test/app_test.dart`, `test/src/state/home_state_test.dart` | `integration_test/*_test.dart` |
| against | `test/fakes/fake_repositories.dart` | the real Rust library |

Both exist because they answer different questions. The fakes prove that the widgets and
the state machine react correctly to the answers a repository gives, in milliseconds.
They cannot tell you whether the `.dylib` on disk matches the generated bindings,
whether the loader finds it, or whether a message Rust produces still reads the same
after crossing FFI. `just test-all` runs `check`, `rust-test`, `test` and `test-e2e`.

## Writing a test

Unit tests for the state go in `test/src/state/home_state_test.dart`:

```dart
final HomeState state = buildState();       // HomeState built on the fakes
addTearDown(() => disposeState(state));     // GetxController has no `dispose()`
state.name.value = 'Ada';
expect(state.instantHello, 'Hello, Ada!');  // the fake's helloPrefix is 'Hello'
```

These tests build the controller directly, with no Get container and no Flutter binding,
which is why they pass the fakes to the constructor and call `onDelete()` themselves
(`disposeState` wraps it). Tests that go through the app instead register everything via
`HomeBinding` and must call `Get.reset()` in `tearDown`, because the Get container is
global and would otherwise hand the next test the previous test's controller.

Widget tests go in `test/app_test.dart` and pump
`FrsKitApp(greetings: greetings, platform: const FakePlatformRepository())`; its
`pumpApp` helper resizes the test surface first, because a `ListView` does not build what
is below the default window. `FakeGreetingRepository` also offers `delayedGate` (a
`Completer` that holds a call in flight), `greetFailure`, `fibonacciFailure`,
`emitCountdown`, `closeCountdown` and `countdownCancelled` for the awkward cases. The
real bridge is tested from `integration_test/`, where `setUpAll(initRustBridge)` loads
the library.

## Bumping flutter_rust_bridge

The version lives in four places, and the generated glue asserts at startup that the
runtime and codegen versions match, so all four move together:

```sh
cargo install flutter_rust_bridge_codegen --version 2.13.0 --locked   # 1. the binary
# 2. pubspec.yaml:    flutter_rust_bridge: 2.13.0
# 3. rust/Cargo.toml: flutter_rust_bridge = "=2.13.0"
just gen                                       # 4. lib/src/rust/frb_generated.dart
just bridge-versions                           # all four agree, or exit 1
```

`just versions` prints the four values without failing, which is the quickest way to see
which one is behind. The generator never edits `pubspec.yaml` itself
(`auto_upgrade_dependency: false`).

## Formatting and linting

- Rust: `just rust-fmt` rewrites, `just rust-fmt-check` fails on a diff. Settings live in
  `rust/rustfmt.toml` and deliberately use stable-only options.
- `just rust-clippy` runs `cargo clippy --all-targets -- -D warnings`. The workspace
  lints in `rust/Cargo.toml` (`unsafe_code = "forbid"`, `dbg_macro`, `todo`) apply only
  to crates that opt in with `[lints] workspace = true`; the bridge package does not,
  because `frb_generated.rs` is machine-written FFI glue.
- `just analyze` runs `flutter analyze` with `analysis_options.yaml`: `flutter_lints` plus
  strict casts, inference and raw types, and the rules that catch a forgotten `await`.
  `lib/src/rust/**` and `rust_builder/cargokit/**` are excluded from analysis but still
  compiled, so a real error there still fails `just test`.
- `just check` is `bridge-versions`, `rust-fmt-check`, `rust-clippy` and `analyze`: the
  fast gate that needs no native build.

## Running on a device

`just run` builds the native library and then runs on `device`, which defaults to
`macos`:

```sh
just run device=chrome
just run device=<device-id>     # see flutter devices
```

The first build on any target is slow: on Android and iOS, cargokit compiles the Rust
crate as part of the platform build and installs the Rust target through rustup the first
time. On iOS the platform panel reports `family other` and no data directory, because
`rust/crates/platform/src/unsupported.rs` has no iOS module and refuses to guess a path.

The web build needs something extra: `wasm-pack`, plus
`flutter_rust_bridge_codegen build-web` to produce the wasm artifacts the loader looks
for (its `webPrefix` is `pkg/`). Nothing in `justfile` wraps that, and it is unverified
here.
