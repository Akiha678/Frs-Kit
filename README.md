<div align="center">

<img src="docs/images/logo/frs_kit_logo.png" width="120" alt="Frs_Kit Logo"/>

# Frs_Kit

_基于 Flutter + Rust 的工程脚手架：四种可运行的桥接往返，两层测试兜底_

<!-- 语言切换按钮 -->
<div align="center">
  <a href="README_EN.md">🌍 English</a>
</div>

[![Flutter](https://img.shields.io/badge/Flutter-3.47.0-02569B?style=flat-square&logo=flutter)](https://flutter.dev)
[![Rust](https://img.shields.io/badge/Rust-1.98-000000?style=flat-square&logo=rust)](https://www.rust-lang.org)
[![flutter_rust_bridge](https://img.shields.io/badge/flutter__rust__bridge-2.13.0-blue?style=flat-square)](https://cjycode.com/flutter_rust_bridge/)
![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20iOS%20%7C%20Android%20%7C%20Windows%20%7C%20Linux-4c8bf5?style=flat-square)
![Tests](https://img.shields.io/badge/tests-64%20fast%20%2B%2022%20e2e-success?style=flat-square)

</div>

## 📖 项目介绍

Frs_Kit 是一个基于 **Flutter / Dart / Rust / flutter_rust_bridge** 的跨平台项目脚手架，把「Flutter 上层 + Rust 下层」这种组合里真正会踩坑的地方做成了可运行的范例：FFI 边界切在哪、哪些调用会占住 UI isolate、Rust 的错误怎么原样传到 Dart、没人监听的流为什么要主动停下。

它不是「hello world 外面套一层原生库」。整套脚手架围绕一个真实应用真正需要从 Rust 拿到的四件事来搭——**同步调用、异步调用、流、宿主信息**——每一件都实现了、都有两个层次的测试，并且在需要做取舍的地方写清了原因。目标是 **clone → `just setup` → `just run` → 填业务**。

macOS 桌面端已实测跑通（含真机端到端测试）；Android、iOS、Windows、Linux 的原生工程与构建集成均已就位，Web 暂未接通。

> 如果这个脚手架对你有帮助，欢迎点个 Star ⭐

## 🧩 内置能力

- **四种桥接往返**：同步调用、`Future`、`Stream`、宿主信息，各有独立模块与示例页面
- **一条 FFI 边界**：只有 `rust/src/api/**` 允许提到 `flutter_rust_bridge`，只有 `lib/src/data/**` 允许调用生成的绑定
- **线程模型明确**：`#[frb(sync)]` 跑在调用方 isolate；其余跑在 FRB 的多线程 runtime；CPU 密集或阻塞任务显式挪到 blocking pool
- **错误统一翻译**：Rust 的 `anyhow::Error` / panic → `AnyhowException` / `PanicException` → 统一转成 `BridgeFailure`，只在一处转换且幂等
- **流可取消**：取消订阅后 Rust 侧的下一次 `add` 会失败并退出循环，不会留下空转的线程
- **两层测试**：假实现驱动的快速单测/组件测试 + 真机加载真实原生库的端到端测试
- **版本一致性校验**：`flutter_rust_bridge` 的版本出现在四处，`just check` 会校验它们是否一致（不一致会导致启动崩溃）
- **原生打包开箱可用**：cargokit 在平台构建期自动编译并打包 Rust 库，无需手写 Podfile/CMake/Gradle 胶水
- **GetX 状态管理与依赖注入**：`GetxController` + `Rx` + `Obx`，只有读到该 `Rx` 的组件才重建；
- **一键任务编排**：`just` 提供 18 个配方，覆盖生成、构建、检查、测试、运行
- **文档到位**：架构、日常开发、排错三份文档，说明每处取舍与每种报错的修法

## 🛠️ 技术栈

| 类别 | 技术选型 | 说明 |
| --- | --- | --- |
| 编程语言 | Dart + Rust | 上层 UI 与状态用 Dart，下层领域逻辑与平台差异用 Rust |
| UI 框架 | Flutter | 一套代码覆盖桌面与移动 |
| 桥接方案 | flutter_rust_bridge 2.13 | 由 Rust 侧 API 生成 Dart 绑定，不手写 FFI |
| 原生打包 | cargokit（`rust_builder/`） | 构建期编译 Rust 并打进各平台应用（macOS / iOS / Android / Windows / Linux） |
| Rust 异步 | tokio（由 flutter_rust_bridge 提供运行时） | 非 `sync` 函数跑在 FRB 创建的多线程 runtime 上 |
| Rust 错误处理 | anyhow + thiserror | 领域层用 `thiserror` 定义错误，边界层用 `anyhow` 透出 |
| 领域分层 | 独立 crate（`crates/core`、`crates/platform`） | 不含 FFI，可独立单测，也能被 CLI 复用 |
| 状态管理 | GetX 4.7 | `GetxController` + `Rx`/`Obx` 细粒度重建，`Bindings` 负责依赖注入 |
| 测试 | cargo test + flutter_test + integration_test | 快速层跑假实现，端到端层跑真实原生库 |
| 代码规范 | cargo fmt / clippy / flutter_lints + 严格 lint | `just check` 一次跑完，clippy 警告即错误 |
| 版本锁定 | rustup + fvm（可选） | `rust-toolchain.toml` 与 `.fvmrc` 分别锁定两侧工具链 |

## 📁 项目架构

```text
lib/
├── main.dart                  # 加载原生库，然后启动应用
├── src/
│   ├── app.dart               # 应用根：持有 HomeState，注入两个 repository
│   ├── app_info.dart          # 应用 id 与名称，只此一处
│   ├── rust/                  # FFI 边界
│   │   ├── bridge.dart        # 手写：re-export + initRustBridge()
│   │   ├── frb_generated*.dart# 生成：加载器、编解码器、wire 函数
│   │   └── api/               # 生成：每个 Rust api 模块一个文件
│   ├── data/                  # 唯一调用生成绑定的层
│   ├── state/                 # HomeState（GetxController）+ HomeBinding 依赖注册
│   └── ui/                    # 首页、四个面板、主题
rust/
├── Cargo.toml                 # workspace 根，同时是桥接 crate
├── src/
│   ├── lib.rs                 # crate 文档 + 两条分层铁律
│   ├── api/                   # 唯一允许提到 flutter_rust_bridge 的 Rust 代码
│   └── frb_generated.rs       # 生成的胶水代码
└── crates/
    ├── core/                  # 领域逻辑；不含 FFI，可独立单测
    └── platform/              # 每个操作系统一个小模块
rust_builder/                  # cargokit：构建期编译并打包原生库
test/                          # 假实现 + 单元/组件测试（快）
integration_test/              # 真实桥接，跑在真机上
examples/                      # 三个聚焦入口：hello_rust / async_demo / stream_demo
docs/                          # 架构、开发、排错三份文档
scripts/                       # 工具链检查、版本一致性检查
justfile                       # 所有命令一张表：just
```

## 🚀 快速开始

### 安装与运行

```bash
just setup
just run
```

不想装 `just` 的话，等价于：

```bash
flutter pub get
cargo build --release --manifest-path rust/Cargo.toml
flutter run
```

### 常用命令

| 命令 | 作用 |
| --- | --- |
| `just` | 列出全部命令 |
| `just setup` | `pub get` + 以 release 构建原生库 |
| `just doctor` | 报告工具链与版本一致性 |
| `just gen` | 改完 Rust API 后重新生成 Dart 绑定 |
| `just gen-watch` | 同上，但持续监听自动重跑 |
| `just build` | `cargo build --release` |
| `just run` | `flutter run` |
| `just check` | 版本一致性、`cargo fmt --check`、`cargo clippy -D warnings`、`flutter analyze` |
| `just test` | Dart 单元与组件测试 |
| `just test-e2e` | 真机上的真实桥接测试，每个文件单独跑一次 |
| `just test-all` | 以上全部 |
| `just versions` | 打印 flutter_rust_bridge 版本在各处的取值 |

### 代码生成

改完 `rust/src/api/**` 之后必须重新生成 Dart 绑定，否则 Dart 侧仍是旧签名：

```bash
just gen          # 等价于 flutter_rust_bridge_codegen generate
just gen-watch    # 持续监听，边改边生成
```

`rust/src/frb_generated.rs`、`lib/src/rust/**` 都是生成产物

### 质量检查与测试

```bash
just check      # 版本一致性 + cargo fmt --check + clippy(-D warnings) + flutter analyze
just rust-test  # Rust 单元与文档测试
just test       # Dart 单元与组件测试（假实现）
just test-e2e   # 真机上的端到端测试（需先构建原生库）
just test-all   # 以上全部
```

两层测试是刻意分开的：`just test` 用假实现验证「组件和状态机对 repository 的返回是否反应正确」，两秒出结果、不需要原生库；`just test-e2e` 验证「磁盘上的原生库是否与生成绑定匹配、加载器能否找到它、Rust 的错误消息过完 FFI 是否还是原样」。

### 运行示例

## ➕ 新增接口

1. 在 `rust/src/api/`（或该目录下的新模块）里写一个 `pub fn`
2. `just gen` —— Dart 绑定会出现在 `lib/src/rust/api/` 下
3. 在 `lib/src/data/` 里调用它，把失败转成 `BridgeFailure`，再由状态层持有
4. 快速回路用 `just test`，要真话就用 `just test-e2e`

## 📦 打包构建

`rust_builder/` 里的 cargokit 会在平台构建期自动编译并打包 Rust 库，所以直接用 Flutter 的构建命令即可，不需要先手动 `cargo build`：

```bash
# macOS
flutter build macos --release

# iOS
flutter build ios --release

# Android：arm64 APK / 上架用 AAB
flutter build apk --release --split-per-abi
flutter build appbundle --release

# Windows / Linux
flutter build windows --release
flutter build linux --release
```

## 📚 说明文档

- **架构说明**：[`docs/architecture.md`](docs/architecture.md)
  - 分层规则、四种往返的设计取舍、线程模型、错误如何过桥、生成代码为什么入库
- **日常开发**：[`docs/development.md`](docs/development.md)
  - 从改 Rust 到发布的完整回路，含新增接口的端到端示例与测试写法
- **问题排查**：[`docs/troubleshooting.md`](docs/troubleshooting.md)
  - 症状 → 原因 → 修法，开头就是人人都会撞上的两个：原生库缺失、版本不一致
- **flutter_rust_bridge 官方文档**：[在线查看](https://cjycode.com/flutter_rust_bridge/)
  - 生成配置、类型映射、异步与流的官方说明
- **Flutter 官方文档**：[在线查看](https://docs.flutter.dev)
  - 跨平台开发、构建与发布说明

## 🤝 参与贡献

欢迎提交 Issue 和 Pull Request。

- **问题反馈**：提交可复现的 Bug、平台兼容性问题或功能建议
- **代码贡献**：完善功能实现、补充示例或修复问题
- **文档优化**：完善使用说明、架构说明与排错条目
- **测试协助**：在 macOS / Windows / Linux / Android / iOS 上验证行为，尤其是首次构建