#!/usr/bin/env bash
#
# 报告这个脚手架需要的工具是否都已安装，然后完成全新检出所必需的两件事：
# 获取 Dart 依赖包并构建原生库。
#
# 可以安全地重复运行：每一步都是幂等的，缺少可选工具只会被报告出来，
# 而不是直接失败。
#
# 用法：
#   scripts/setup.sh            # 先检查，然后执行 pub get + cargo build
#   scripts/setup.sh --check    # 只检查，不做任何改动

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

check_only=false
if [[ "${1:-}" == "--check" ]]; then
  check_only=true
fi

missing_required=0

# require <command> <version-args...> — 没有它就无法工作的工具。
require() {
  local cmd="$1"
  shift
  if command -v "$cmd" >/dev/null 2>&1; then
    printf '  ok      %-28s %s\n' "$cmd" "$("$cmd" "$@" 2>&1 | head -n1)"
  else
    printf '  MISSING %-28s required\n' "$cmd"
    missing_required=$((missing_required + 1))
  fi
}

# optional <command> <version-args...> — 有则更好，并说明它在何处起作用。
optional() {
  local cmd="$1" note="$2"
  shift 2
  if command -v "$cmd" >/dev/null 2>&1; then
    printf '  ok      %-28s %s\n' "$cmd" "$("$cmd" "$@" 2>&1 | head -n1)"
  else
    printf '  absent  %-28s %s\n' "$cmd" "$note"
  fi
}

echo "Required toolchain"
require flutter --version
require cargo --version
require rustc --version
require flutter_rust_bridge_codegen --version

echo
echo "Optional"
optional fvm "not needed: .fvmrc is only used when fvm is installed"
optional just "you can run the commands in the justfile by hand" --version

if command -v rustup >/dev/null 2>&1; then
  echo
  echo "Rust toolchain"
  echo "  rust-toolchain.toml pins 'stable' with rustfmt and clippy; rustup installs"
  echo "  them on first use inside rust/."
fi

if ((missing_required > 0)); then
  echo
  echo "$missing_required required tool(s) missing. See docs/development.md." >&2
  exit 1
fi

echo
echo "Bridge versions"
"$repo_root/scripts/check_bridge_versions.sh"

if $check_only; then
  echo
  echo "Check only: nothing was changed."
  exit 0
fi

echo
echo "Dart packages"
flutter pub get

echo
echo "Native library"
cargo build --release --manifest-path rust/Cargo.toml

echo
echo "Ready. Try: just run"
