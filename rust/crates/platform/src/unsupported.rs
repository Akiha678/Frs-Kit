//! 所有没有专属模块的操作系统的回退实现 —— 包括 iOS、web 构建和各类 BSD。
//!
//! 仅在没有其他模块匹配时编译。它让这个 crate 保持诚实：API 在每个目标上都是
//! 完备的，调用方是在 *运行时*（通过 [`crate::FAMILY`] 或一个 `None` 数据目录）
//! 发现该平台没有特殊处理，而不是让 crate 编译失败。

use std::path::PathBuf;

use crate::PlatformFamily;

/// 见 [`crate::NAME`]。
///
/// web 构建是唯一一个操作系统真正不存在的目标，对于
/// `wasm32-unknown-unknown`，`std::env::consts::OS` 报告的是 `"unknown"`。把它
/// 命名为 `"web"` 能让该值与 Dart 侧的 `kIsWeb` 相比较。
#[cfg(target_family = "wasm")]
pub const NAME: &str = "web";

/// 见 [`crate::NAME`]。
///
/// 报告真实目标，因此 iOS 记录为 `ios` 而不是 `unsupported`。
#[cfg(not(target_family = "wasm"))]
pub const NAME: &str = std::env::consts::OS;

/// 见 [`crate::FAMILY`]。
///
/// 恒为 [`PlatformFamily::Other`]：目前还没有针对非 Android 的移动端目标
/// （尤其是 iOS）的模块，而在这里声称 `Mobile` 会让 `is_desktop` 朝另一个方向
/// 说谎。
pub const FAMILY: PlatformFamily = PlatformFamily::Other;

/// 恒为 `None`。
///
/// 猜错比没有答案更糟：调用方应该去问平台（例如 Dart 侧的 `path_provider`）。
pub fn default_data_dir(_app_id: &str) -> Option<PathBuf> {
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reports_the_real_target() {
        // 例如 "ios" 或 "freebsd" —— 绝不会是字面量 "unsupported"。
        #[cfg(target_family = "wasm")]
        assert_eq!(NAME, "web");
        #[cfg(not(target_family = "wasm"))]
        assert_eq!(NAME, std::env::consts::OS);

        assert_ne!(NAME, "unsupported");
    }

    #[test]
    fn no_family_is_claimed() {
        assert_eq!(FAMILY, PlatformFamily::Other);
        assert!(!crate::is_desktop());
    }

    #[test]
    fn no_data_directory_is_guessed() {
        assert!(default_data_dir("frs_kit").is_none());
    }
}
