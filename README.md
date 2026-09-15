# frs_kit

[English](README_EN.md) · **英文**

一个 Flutter + Rust 应用脚手架，用
[flutter_rust_bridge](https://cjycode.com/flutter_rust_bridge/) 2.13 把两侧接起来。

它不是「hello world 外面套一层原生库」。这套脚手架围绕一个真实应用真正需要从
Rust 拿到的四件事来搭——**同步调用、异步调用、流、宿主信息**——每一件都实现了、
都有两个层次的测试，并且在需要做取舍的地方写清了原因。

```sh
just setup     # 拉取 Dart 依赖并构建原生库
just run       # 构建后在 macOS 上启动
```

## 现在就能跑通的东西

| 往返类型 | Rust | Dart | 演示了什么 |
| --- | --- | --- | --- |
| 值、结构体、枚举 | `rust/src/api/hello.rs` | `Future<Greeting> greet(...)` | `#[frb(sync)]` 与 `Future` 的区别、传输层 DTO、领域校验 |
| 异步工作 | `rust/src/api/async_demo.rs` | `Future<String>`、`Future<BigInt>` | 不占用 UI isolate、把 CPU 密集任务挪到 blocking pool |
| 流 | `rust/src/api/stream_demo.rs` | `Stream<int> countdown(...)` | 由 Rust 推值，取消订阅能真正传回 Rust |
| 宿主信息 | `rust/src/api/platform.rs` | `PlatformSummary platformSummary(...)` | 廉价的同步调用、识别出「原生库是旧的」 |

应用本体就是这四个面板，而测试就是证据：

- `rust/` 下的 `cargo test` —— 30 个单元测试（领域 crate 15 个、平台 crate 7 个、
  桥接 crate 8 个）加 2 个文档测试。
- `flutter test` —— 32 个测试：状态机单测 + 整套 UI 的组件测试，全部跑在假实现上，
  约两秒完成，不需要原生库。
- `just test-e2e` —— 22 个测试，在真机上打真实原生库、真实组件树与真实错误消息。

## 目录结构

从 UI 到 Rust 只有单向一条路：

```
ui -> state -> data -> rust/（生成代码） -> rust/src/api -> crates/core, crates/platform
```

`rust/src/api/**` 就是那道缝。它下面全是不知道 Dart 存在的普通 Rust；它上面全是
不知道 FFI 存在的普通 Flutter。为什么这么切、不这么切会坏在哪，
`docs/architecture.md` 里有说明。

## 环境要求

- **Flutter** 3.47.0（`.fvmrc` 已锁定；`fvm` 可选，没装的话脚本会自动跳过）
- **Rust**（经 rustup 安装）——`rust-toolchain.toml` 锁定 stable 并带
  `rustfmt`、`clippy`，rustup 会在首次进入 `rust/` 时自动装好
- **flutter_rust_bridge_codegen**，版本必须与 `pubspec.yaml` 完全一致：

  ```sh
  cargo install flutter_rust_bridge_codegen --version 2.13.0 --locked
  ```

- **just**（[安装说明](https://github.com/casey/just#installation)）——不装也行，
  照着 `justfile` 手敲命令即可

`scripts/setup.sh --check` 会报告装了什么、缺什么。代码生成器、Dart 包、Rust crate
三者的版本不一致会导致启动时崩溃，所以 `just check` 会校验四处版本是否一致。

## 常用命令

| 命令 | 作用 |
| --- | --- |
| `just` | 列出全部配方 |
| `just setup` | `pub get` + 以 release 构建原生库 |
| `just doctor` | 报告工具链与版本一致性 |
| `just gen` | 改完 Rust API 后重新生成 Dart 绑定 |
| `just gen-watch` | 同上，但持续监听自动重跑 |
| `just build` | `cargo build --release`——加载器要找的正是这个 profile |
| `just run` | 先构建，再 `flutter run -d macos`（用 `device=chrome` 换设备） |
| `just check` | 版本一致性、`cargo fmt --check`、`cargo clippy -D warnings`、`flutter analyze` |
| `just test` | Dart 单元与组件测试（快，不需要原生库） |
| `just test-e2e` | 真机上的真实桥接测试，每个文件单独跑一次 |
| `just test-all` | 以上全部 |
| `just versions` | 打印 flutter_rust_bridge 版本在各处的取值 |

`just build` 不是可有可无的装饰：生成的 Dart 会去加载
`rust/target/release/librust_lib_frs_kit.{dylib,so,dll}`，只跑 `cargo build`
（debug）它根本看不见。库缺失时应用会在界面上直接说明原因，而不是给你一个白屏。

## 示例

三个小应用，每个只讲一件事，可以在本仓库直接运行：

```sh
just build
flutter run -t examples/hello_rust/main.dart  -d macos   # 同步 vs 异步
flutter run -t examples/async_demo/main.dart  -d macos   # 等待但不卡界面
flutter run -t examples/stream_demo/main.dart -d macos   # 流与取消
```

## 新增一个函数

1. 在 `rust/src/api/`（或该目录下的新模块）里写一个 `pub fn`。
2. `just gen` —— Dart 绑定会出现在 `lib/src/rust/api/` 下。
3. 在 `lib/src/data/` 里调用它，把失败转成 `BridgeFailure`，再由状态层持有。
4. 快速回路用 `just test`，要真话就用 `just test-e2e`。

`docs/development.md` 里有一个完整的端到端示例（含如何为它写测试）。除了标注
`#[frb(sync)]` 的函数，其余函数在 Dart 侧都是异步的——这个选择很重要，那份文档
说明了什么时候该标、什么时候不该标。