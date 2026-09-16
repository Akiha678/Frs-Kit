# frs_kit — 日常任务。
#
# 不带参数运行 `just` 即可列出全部内容，或运行 `just <recipe>`。
#
#   just setup      # 全新检出后的第一次运行
#   just check      # 版本、格式、lint、analyze（很快，不构建原生库）
#   just test       # Dart 单元/组件测试（很快，不构建原生库）
#   just test-all   # 全部内容，包括真实的 bridge
#
# 下面这些说明放不进后面的一行式描述里：
#
#   * 必须先运行 `build`，应用才能启动。生成的 Dart 加载的是
#     `rust/target/release/`，所以只做 debug 的 `cargo build` 对它不可见。
#   * 每次改动 Rust 公开 API 之后都必须运行 `gen`，因为 Dart 绑定是生成的，
#     而不是手写的。
#   * `run` 和 `test-e2e` 需要指定设备：`just run device=chrome`。
#
# `bash -uc` 表示 recipe 里未定义的变量或失败的命令会立即终止它，
# 而不是让一个已经出错的步骤看起来像成功了一样。
set shell := ["bash", "-uc"]

# 存放 Rust workspace 的目录，相对于这个 justfile。
rust_dir := "rust"

# `run` 和 `test-e2e` 使用的设备；每次调用时可以覆盖。
device := "macos"

# 列出可用的 recipe。
default:
    @just --list --unsorted

# 准备全新检出：Dart 依赖包加原生库。
setup: pub-get build

# 获取 Dart 依赖包。
pub-get:
    flutter pub get

# 报告工具链，并检查 bridge 版本是否一致。
doctor:
    @scripts/setup.sh --check

# 从 `rust/src/api/**` 重新生成 Dart 绑定。
gen:
    flutter_rust_bridge_codegen generate

# 编辑 Rust API 时持续重新生成。
gen-watch:
    flutter_rust_bridge_codegen generate --watch

# 构建应用在运行时加载的原生库。
build:
    cargo build --release --manifest-path {{rust_dir}}/Cargo.toml

# 先构建，然后在设备上运行应用。
run: build
    flutter run -d {{device}}

# 所有无需构建原生库就能完成的检查。
check: bridge-versions rust-fmt-check rust-clippy analyze

# 当承载 bridge 版本的四处不一致时失败。
bridge-versions:
    @scripts/check_bridge_versions.sh

# 格式化 Rust workspace。
rust-fmt:
    cargo fmt --manifest-path {{rust_dir}}/Cargo.toml --all

# 若有任何 Rust 文件未格式化则失败。
rust-fmt-check:
    cargo fmt --manifest-path {{rust_dir}}/Cargo.toml --all -- --check

# 对 Rust workspace 执行 lint，并把警告视为错误。
rust-clippy:
    cargo clippy --manifest-path {{rust_dir}}/Cargo.toml --all-targets -- -D warnings

# 按 analysis_options.yaml 里的规则分析 Dart 代码。
analyze:
    flutter analyze

# 运行 Rust 单元测试和文档测试。
rust-test:
    cargo test --manifest-path {{rust_dir}}/Cargo.toml

# 针对 fake 运行 Dart 单元测试和组件测试。
test:
    flutter test

# 每个文件单独跑一次 `flutter test` 是刻意的：在桌面平台上，让一次运行多次启动
# 应用并不可靠（"Unable to start the app on the device"），而每次只跑一个文件则
# 不会有这个问题。
#
# 先构建，然后在设备上运行端到端测试。
test-e2e: build
    #!/usr/bin/env bash
    set -euo pipefail
    for file in integration_test/*_test.dart; do
      echo "==> $file"
      flutter test "$file" -d {{device}}
    done

# 运行所有检查和所有测试，遇到失败立即停止。
test-all: check rust-test test test-e2e

# 打印 bridge 版本出现过的每一处。
versions:
    @scripts/check_bridge_versions.sh --print

# 清除构建产物并重新获取 Dart 依赖包。
clean:
    cargo clean --manifest-path {{rust_dir}}/Cargo.toml
    flutter clean
    flutter pub get
