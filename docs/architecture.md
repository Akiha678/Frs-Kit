# Architecture

frs_kit is a Flutter application whose lower half is Rust. Dart owns the UI and the
screen state; Rust owns the domain rules and the host facts. `flutter_rust_bridge`
(FRB) generates the glue between them, so neither side hand-writes FFI code.

## Layering

| Layer | Path | May depend on |
| --- | --- | --- |
| UI | `lib/src/ui/**` | state, generated types |
| State | `lib/src/state/**` | data, generated types |
| Data | `lib/src/data/**` | rust bindings |
| Bindings | `lib/src/rust/**` | the native library |
| API | `rust/src/api/**` | `crates/core`, `crates/platform` |
| Domain | `rust/crates/core`, `rust/crates/platform` | nothing bridge-related |

Three rules keep the tree healthy; the first two are stated in `rust/src/lib.rs`.

1. `rust/src/api/**` is the only place allowed to mention `flutter_rust_bridge`. The
   domain crates stay ordinary Rust that tests, benchmarks and a CLI can use.
2. Every `pub` item in `rust/src/api/**` — and every `pub` struct or enum it names —
   becomes part of the Dart API. The module path becomes the Dart file name:
   `api/hello.rs` becomes `lib/src/rust/api/hello.dart`.
3. Only `lib/src/data/**` calls the bridge. `lib/src/ui/**` and `lib/src/state/**`
   import the generated types (`Greeting`, `GreetingStyle`, `PlatformSummary`) but
   never a function, so no widget needs a hand-written model class.

`crates/platform` compiles exactly one OS module and aliases it to `imp`, so `NAME`,
`FAMILY`, `is_desktop()` and `default_data_dir()` are total on every target and no
caller needs a `#[cfg]`. Unsupported targets, including iOS and the web build, fall
through to `unsupported.rs`, which reports the real target name
(`std::env::consts::OS`, or `"web"` on wasm) and never guesses a data directory.

## Call path

```text
lib/main.dart
  ├─ initRustBridge()             lib/src/rust/bridge.dart
  └─ FrsKitApp                    lib/src/app.dart      (GetMaterialApp)
       ├─ HomeBinding             lib/src/state/home_binding.dart
       │    └─ registers GreetingRepository, PlatformRepository, HomeState
       └─ HomePage                lib/src/ui/home_page.dart
            └─ panels `Get.find<HomeState>()`, read Rx inside `Obx`
                 └─ HomeState     lib/src/state/home_state.dart  (GetxController)
                      ├─ GreetingRepository / PlatformRepository  lib/src/data/
                      └─ lib/src/rust/**   generated + bridge.dart
                           └─ rust/src/api/**
                                └─ rust/crates/core, rust/crates/platform
```

`lib/main.dart` calls `WidgetsFlutterBinding.ensureInitialized()` and then
`initRustBridge()`. That step is wrapped in a `try`, because failing to load the native
library is the expected outcome on a fresh checkout: the app then shows
`RustUnavailableApp` with the loader's message instead of a blank window.

## The four round-trips

| Rust (under `rust/src/`) | Dart (under `lib/src/rust/`) | Demonstrates |
| --- | --- | --- |
| `api/hello.rs` | `api/hello.dart` | values, a struct and an enum, plus the one `#[frb(sync)]` call |
| `api/async_demo.rs` | `api/async_demo.dart` | `Future`s, and where blocking or CPU-bound work must run |
| `api/stream_demo.rs` | `api/stream_demo.dart` | a `Stream` pushed from Rust, and cancellation |
| `api/platform.rs` | `api/platform.dart` | four cheap synchronous reads, and `platform_summary` to get them at once |

`hello` is the smallest possible call and returns a `String` directly; `greet` validates
through `rust_flutter_core::domain::greet` and returns a `Greeting` struct.

## Why the wire types are duplicated

`rust/src/api/hello.rs` declares its own `Greeting` and `GreetingStyle` instead of
re-exporting the domain types, and converts between them with `From` impls in both
directions. `api/platform.rs` declares its own `PlatformFamily` in the same spirit,
with a single `From` impl because no call takes one as an input, and
`PlatformSummary` is a wire-only struct wrapping the flat consts from
`rust_flutter_platform`.

The duplication is deliberate:

- the domain enum stays free to gain variants (or to become `#[non_exhaustive]`)
  without silently changing the Dart API;
- the generated Dart enum keeps exactly the variant names written in the API layer;
- the `From` impls are the single place where a domain type becomes a wire type.

## Threading model

| Rust | Dart | Runs on |
| --- | --- | --- |
| `#[frb(sync)] pub fn` | plain value, no `Future` | the calling Dart isolate |
| `pub fn` / `pub async fn` | `Future<T>` | a worker of the tokio runtime FRB creates |
| `spawn_blocking_with(work, handler.thread_pool())` | the awaited `Future` | the blocking pool |
| `pub fn(…, sink: StreamSink<T>)` | `Stream<T>` | a worker thread, one per stream |

`#[frb(sync)]` is for work that is cheap by construction: the calls in
`api/platform.rs` read constants compiled into the library, so awaiting them would be
pure overhead. They run on the calling isolate, where I/O and sleeping are forbidden.
Every other function is asynchronous on the Dart side, even when the Rust function is
not `async`. `api/async_demo.rs` shows the split: `delayed_hello` waits on the
blocking pool instead of calling `std::thread::sleep` inside an `async fn`, and
`fibonacci` pushes its arithmetic there too, because a blocking sleep in the async
function would occupy a runtime worker and starve other in-flight calls. `run_blocking`
is the bridge-aware stand-in for `tokio::task::spawn_blocking`, taking the pool FRB
already owns, which is what keeps that module compiling for web without a `#[cfg]`.

A stream runs the other way. `countdown` takes a `StreamSink<u32>` and runs its body on
a worker thread; when Dart cancels the subscription, the next `sink.add` fails and the
loop breaks out on that failure, so an abandoned stream does not hold a thread until
it would have finished on its own.

## How errors travel

Rust errors cross the bridge as `FrbException` subclasses: `AnyhowException` for a
returned `anyhow::Error`, `PanicException` for a panic. In `api/hello.rs` the `?` on
`domain::greet(...)` is the whole translation layer: `CoreError` implements
`std::error::Error`, so `anyhow` picks it up with its `Display` message intact and
Dart reads `invalid input: name must not be empty`.

`lib/src/data/failure.dart` converts both into one `BridgeFailure`, once:
`BridgeFailure.from` is idempotent, returns an already-translated value unchanged, and
falls back to `'$error'` for anything else, so a bug in the data layer still surfaces
with a readable message. `isPanic` distinguishes a bug from a rejected input.
`GreetingRepository._guard` puts every fallible call through that conversion, and
`HomeState` keeps the resulting message for the UI to render next to the control that
failed.

## Generated code, and how the library is found

`flutter_rust_bridge_codegen generate` (run via `just gen`) writes
`rust/src/frb_generated.rs` and `lib/src/rust/{frb_generated.dart,
frb_generated.io.dart, frb_generated.web.dart, api/*.dart}`. Both halves are checked in:
`.gitignore` does not exclude them, and `flutter_rust_bridge.yaml` sets
`auto_upgrade_dependency: false` so bumping FRB is a deliberate commit rather than a
side effect of running the generator. Never hand-edit them: the next run overwrites
them without warning. `lib/src/rust/bridge.dart` is the one hand-written file in that
directory; it re-exports the generated API under a stable path and owns
`initRustBridge()`.

The generated Dart carries the loader configuration:

```dart
static const kDefaultExternalLibraryLoaderConfig =
    ExternalLibraryLoaderConfig(
      stem: 'rust_lib_frs_kit',
      ioDirectory: 'rust/target/release/',
      webPrefix: 'pkg/',
      wasmBindgenName: 'wasm_bindgen',
    );
```

`stem` comes from the `[lib] name` in `rust/Cargo.toml`, which is why the file is
`librust_lib_frs_kit.dylib`. `ioDirectory` is why `just build` runs
`cargo build --release`: a debug build writes to `rust/target/debug/`, where the loader
never looks.

For app builds, `flutter_rust_bridge_codegen integrate` added `rust_builder/`, a Flutter
FFI plugin that vendors cargokit, and `pubspec.yaml` depends on it by path as
`rust_lib_frs_kit`. Cargokit compiles the crate during the platform build, installing the
Rust target through rustup when it is missing, and bundles or links the result into the
macOS, iOS, Android, Windows and Linux app — that is what the `staticlib` crate type is
for. Without it, desktop and mobile app builds have no library to load.

## 64-bit integers

FRB maps Rust `u64` to Dart `BigInt` by default, because Dart's `int` is a fixed-size
64-bit value on native but a double on the web. That is why `fibonacci` returns
`Future<BigInt>` from `GreetingRepository` and why the delay and interval parameters
are `u32`: a `u32` arrives in Dart as an ordinary `int`, which is what a slider and a
`Duration` want. The generator's `type_64bit_int` option would map `u64` to `int`
instead, at the cost of precision on the web; this project leaves it unset.

## Where state lives

State management and dependency injection are GetX. `HomeState extends GetxController`
holds everything the home page renders — host facts, the greeting form, the delayed call
and its tick counter, the countdown buffer, the Fibonacci input and result — as `Rx`
values (`RxString`, `RxBool`, `Rxn<T>`, `RxList<int>`), and the panels wrap the parts
that change in `Obx`.

The reason to prefer `Rx` over a single listenable object is rebuild scope: an `Obx`
subscribes only to the `Rx` values read inside it. Typing in the name field rebuilds the
synchronous preview and nothing else — not the chips, not the countdown panel, not the
CPU panel. That is also why `instantHello` is a plain getter over `state.name`: reading
it inside an `Obx` is what subscribes that `Obx` to the name.

`HomeBinding` replaces the `InheritedNotifier` scope the scaffold used to carry. It is
passed to `GetMaterialApp.initialBinding`, so it runs before the first route is built,
and it `lazyPut`s the two repositories and the controller with `fenix: true` — GetX
deletes lazily-created instances when the route that used them goes away, and `fenix`
rebuilds the registration instead of returning a deleted controller. Widgets and
callbacks reach state with `Get.find<HomeState>()`, which needs no `BuildContext`.

`FrsKitApp` is therefore a `StatelessWidget`: the container owns the controller's
lifetime. `HomeState.onInit()` reads the host facts — synchronous and cheap, so the first
build already shows them — and `onClose()` cancels the busy ticker and the countdown
subscription. `_closed` guards the async callbacks that can still land afterwards,
because assigning to an `Rx` after teardown is an error.

Two GetX behaviours the tests pin down, both easy to trip over:

* the container is **global**, so both test layers call `Get.reset()` in their teardown.
  Without it the next test pumps a fresh app but `Get.find` returns the previous test's
  controller, complete with the name it typed;
* `Rx` always publishes the **first** write, even when it equals the initial value
  (`firstRebuild`). Only later writes are de-duplicated.
