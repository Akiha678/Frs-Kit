# frs_kit — everyday tasks.
#
# Run `just` with no arguments to list everything, or `just <recipe>`.
#
#   just setup      # first run on a fresh checkout
#   just check      # versions, format, lint, analyze (fast, no native build)
#   just test       # Dart unit/widget tests (fast, no native build)
#   just test-all   # everything, including the real bridge
#
# Notes that do not fit in the one-line descriptions below:
#
#   * `build` must be run before the app can start. The generated Dart loads
#     `rust/target/release/`, so a debug-only `cargo build` is invisible to it.
#   * `gen` must be run after every change to the public Rust API, because the Dart
#     bindings are generated, not hand-written.
#   * `run` and `test-e2e` take a device: `just run device=chrome`.
#
# `bash -uc` means an undefined variable or a failing command inside a recipe stops
# it immediately, instead of letting a broken step look like a successful one.
set shell := ["bash", "-uc"]

# Directory holding the Rust workspace, relative to this justfile.
rust_dir := "rust"

# Device used by `run` and `test-e2e`; override per invocation.
device := "macos"

# Show the available recipes.
default:
    @just --list --unsorted

# Prepare a fresh checkout: Dart packages plus the native library.
setup: pub-get build

# Fetch Dart packages.
pub-get:
    flutter pub get

# Report the toolchain and check that the bridge versions agree.
doctor:
    @scripts/setup.sh --check

# Regenerate the Dart bindings from `rust/src/api/**`.
gen:
    flutter_rust_bridge_codegen generate

# Regenerate continuously while you edit the Rust API.
gen-watch:
    flutter_rust_bridge_codegen generate --watch

# Build the native library the app loads at runtime.
build:
    cargo build --release --manifest-path {{rust_dir}}/Cargo.toml

# Build, then run the app on a device.
run: build
    flutter run -d {{device}}

# Everything that can be checked without building the native library.
check: bridge-versions rust-fmt-check rust-clippy analyze

# Fail when the four places carrying the bridge version disagree.
bridge-versions:
    @scripts/check_bridge_versions.sh

# Format the Rust workspace.
rust-fmt:
    cargo fmt --manifest-path {{rust_dir}}/Cargo.toml --all

# Fail if any Rust file is unformatted.
rust-fmt-check:
    cargo fmt --manifest-path {{rust_dir}}/Cargo.toml --all -- --check

# Lint the Rust workspace, with warnings treated as errors.
rust-clippy:
    cargo clippy --manifest-path {{rust_dir}}/Cargo.toml --all-targets -- -D warnings

# Analyze the Dart code with the rules in analysis_options.yaml.
analyze:
    flutter analyze

# Run the Rust unit and doc tests.
rust-test:
    cargo test --manifest-path {{rust_dir}}/Cargo.toml

# Run the Dart unit and widget tests, against fakes.
test:
    flutter test

# Build, then run the end-to-end tests on a device.
#
# Each file gets its own `flutter test` invocation on purpose: on desktop targets,
# asking one run to launch the app several times is unreliable ("Unable to start the
# app on the device"), while a single file per run is not.
test-e2e: build
    #!/usr/bin/env bash
    set -euo pipefail
    for file in integration_test/*_test.dart; do
      echo "==> $file"
      flutter test "$file" -d {{device}}
    done

# Run every check and every test, failing fast.
test-all: check rust-test test test-e2e

# Print the bridge version everywhere it appears.
versions:
    @scripts/check_bridge_versions.sh --print

# Remove build output and re-fetch Dart packages.
clean:
    cargo clean --manifest-path {{rust_dir}}/Cargo.toml
    flutter clean
    flutter pub get
