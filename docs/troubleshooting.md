# Troubleshooting

Every entry below is a symptom, the cause behind it, and the fix. Commands run from the
repository root.

## The app shows the "native library missing" screen

**Symptom** — instead of the home page, the window shows `RustUnavailableApp`: "The Rust
library could not be loaded", the loader's own message, and a collapsed stack trace.

**Cause** — `initRustBridge()` threw, and `lib/main.dart` catches that on purpose. The
usual reasons, in order of likelihood:

- the library was never built on this checkout;
- only a *debug* build was run. The loader's `ioDirectory` is baked in as
  `rust/target/release/`, so `cargo build` alone leaves it looking in an empty place;
- something removed `rust/target/` — `cargo clean`, which `just clean` runs.

**Fix** — `just build`, which is `cargo build --release` with the right manifest path, then
restart (`just run` rebuilds first, as part of the recipe). If the screen comes back, read
the message on it: the next two entries cover the other reasons it can appear.

## A panic about the codegen/runtime version at startup

**Symptom** — the app fails during `RustLib.init()`, or the failure screen quotes a
version mismatch between the generator and the runtime.

**Cause** — the generated glue asserts at startup that the codegen version equals the
runtime version, and one of the four places that carry it was moved alone: `pubspec.yaml`,
`rust/Cargo.toml`, the `flutter_rust_bridge_codegen` binary, or
`lib/src/rust/frb_generated.dart`.

**Fix** — `just versions` prints all four without failing; `just bridge-versions` exits
non-zero on any disagreement, which is why it is the first step of `just check`. Then
bring the odd one out into line, using `pubspec.yaml` as the target version:

```sh
just gen                                                             # regenerate the Dart
cargo install flutter_rust_bridge_codegen --version 2.13.0 --locked # or the binary
```

## The platform panel shows "stale library?"

**Symptom** — the platform card ends with a warning chip reading `stale library?`, and the
`rust` line differs from the `dart` line.

**Cause** — Rust reports the operating system *its own library* was compiled for, Dart
reports the one the app runs on. They agree in a correctly built app, so a mismatch means
the loaded library was built for a different target than the app running it. Note that
`ios` and `web` are legitimate values — `rust/crates/platform/src/unsupported.rs` reports
the real target, and `"web"` on wasm.

**Fix** — rebuild for the target you are actually running: `just build` for desktop, then
restart. Until then every other panel is exercising that wrong binary.

## Errors reported inside `lib/src/rust/**`

**Symptom** — the editor underlines generated Dart: unknown names, wrong argument counts,
"the method isn't defined".

**Cause** — those files are machine-written, and `analysis_options.yaml` excludes
`lib/src/rust/**` from analysis, so what you are seeing is not a lint: the generated code
no longer matches the Rust API it came from, either because the Rust changed or because the
file was edited by hand.

**Fix** — `just gen`, then reload the editor. Never repair generated code by hand: the next
run overwrites it. If the errors survive regeneration, they are really in the hand-written
caller in `lib/src/data/**`.

## A changed Rust signature is not visible in Dart

**Symptom** — you renamed a parameter or changed a return type in `rust/src/api/**`, and
Dart still compiles against the old shape.

**Cause** — the Dart bindings are generated artifacts. Editing the Rust API does not
update them; only the generator does. Neither `just check` nor `just test` regenerates.

**Fix** — `just gen` (run `just gen-watch` while editing the API), then update
`lib/src/data/**` to the new signature. The fake in `test/fakes/fake_repositories.dart`
implements the repository, so it needs the same change or `flutter test` will not compile.

## `just check` fails because Rust is unformatted

**Symptom** — `rust-fmt-check` fails and prints a diff of a file you just wrote.

**Cause** — `just check` runs `cargo fmt --all -- --check`, so any deviation from
`rust/rustfmt.toml` is an error rather than a rewrite.

**Fix** — `just rust-fmt`, then re-run `just check`. Do not weaken `rust/rustfmt.toml` to
make the diff go away; it deliberately lists only stable options so stable and nightly
agree.

## `flutter test integration_test` refuses to run

**Symptom** — the command complains that several devices are attached, or asks for `-d`.

**Cause** — `flutter test integration_test` will not guess which device to drive. The
integration tests load the real native library, so they must run on a real target rather
than in the headless Dart VM.

**Fix** — name the device: `just test-e2e device=<device-id>`, where the recipe defaults to
`macos`. List the candidates with `flutter devices`. The recipe also builds the native
library first, so a stale `.dylib` is not a separate thing to remember.

Passing `--no-device` or relying on the default of a bare `flutter test integration_test`
also fails for a different reason: that form drives *every* file in one run, and on desktop
targets only the first launch succeeds (`Unable to start the app on the device` for the
rest). `just test-e2e` therefore runs one file per invocation, which is reliable.

## A warning that `rust_lib_frs_kit` does not support Swift Package Manager

**Symptom** — a macOS or iOS build prints `The following plugins do not support Swift
Package Manager for macos: rust_lib_frs_kit`, adding that this will become an error in a
future Flutter version.

**Cause** — cargokit, vendored under `rust_builder/`, integrates through CocoaPods only.
The build still succeeds: Flutter warns about every plugin that has not moved to Swift
Package Manager yet.

**Fix** — none required today; the library is bundled through the Podfile that `integrate`
added. If a future release turns the warning into an error, the fix belongs in cargokit (or
in changing the integration backend), not in this project's own code.

## A blank name, or a very long one, shows an error in the UI

**Symptom** — pressing **Greet** with an empty field puts
`invalid input: name must not be empty` under the field; more than 64 characters gives
`invalid input: name must be at most 64 characters`.

**Cause** — expected behaviour, not a bug. `greet` in `rust/src/api/hello.rs` calls
`rust_flutter_core::domain::greet`, which trims the name and rejects what is left if it is
empty or longer than `MAX_RECIPIENT_LEN`. The `CoreError::InvalidInput` message travels
through `anyhow` into a `BridgeFailure`, which `HomeState` keeps in `greetingError` (an
`RxnString`) for the UI to render rather than throwing.

**Fix** — none: type a name, or pick a shorter one. The integration test asserts these
messages and the widget test asserts `tester.takeException()` is null, so an error on
screen *and* a passing test is the designed outcome.

## The web build cannot find `wasm-pack`

**Symptom** — `scripts/setup.sh` prints `absent wasm-pack`, and the web build produces no
wasm artifacts for the loader (`webPrefix` `pkg/`) to find.

**Cause** — the web target needs a wasm build of the crate, and `wasm-pack` is what
produces it. No `just` recipe wraps that step in this checkout.

**Fix** — install `wasm-pack`, then run the generator's web build
(`flutter_rust_bridge_codegen build-web`). The web path is not verified in this checkout:
treat desktop and mobile as the supported targets.

## Android and iOS: the first build is slow, or fails before Dart is compiled

**Symptom** — the first `flutter run` for a mobile target takes minutes, or errors out in
Gradle or CocoaPods with a Rust-related message.

**Cause** — `rust_builder/` is a Flutter FFI plugin that vendors cargokit. During the
platform build it compiles the Rust crate for each target architecture, installing the
Rust target through rustup the first time; that runs before any Dart code is compiled, so
a Rust toolchain problem surfaces as a build failure rather than a Dart error.

**Fix** — let the first build finish; later builds reuse the artifacts. Make sure rustup
and the pinned toolchain are available, and that CocoaPods is installed on macOS and iOS
(`ios/Podfile` and `macos/Podfile` were added by the `integrate` step). Two values on the
platform panel are expected on iOS: `family` shows `other` and the data directory shows
"not guessed on this platform", because `rust/crates/platform` has no iOS module.

## `cargo test` reports tests for the bridge crate only

**Symptom** — `just rust-test` lists tests for `rust_lib_frs_kit` but none for
`rust_flutter_core` or `rust_flutter_platform`.

**Cause** — `rust/Cargo.toml` is both a package and a workspace root. In that situation
cargo operates on the root package alone, so the sub-crates are skipped silently.

**Fix** — nothing to do: `default-members = [".", "crates/core", "crates/platform"]` in
`rust/Cargo.toml` already makes the plain commands cover the whole workspace, and the
symptom returns only if that line is deleted. Expected totals: 15 tests in
`rust_flutter_core`, 7 in `rust_flutter_platform`, 8 in `rust_lib_frs_kit`, plus 2
doc-tests.

A missing required tool is the other half of that story: `scripts/setup.sh` prints
`MISSING` and exits 1 when Flutter, `cargo`, `rustc` or `flutter_rust_bridge_codegen` is
not on `PATH`. Install what it names; the generator must match the runtime version exactly
(`cargo install flutter_rust_bridge_codegen --version 2.13.0 --locked`). An *optional*
tool (`fvm`, `just`, `wasm-pack`) is reported as `absent` and does not fail the script.
