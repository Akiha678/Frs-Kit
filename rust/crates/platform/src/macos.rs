//! macOS 实现。
//!
//! 仅在 `target_os = "macos"` 时编译。

use std::path::PathBuf;

use crate::PlatformFamily;

/// 见 [`crate::NAME`]。
pub const NAME: &str = "macos";

/// 见 [`crate::FAMILY`]。
pub const FAMILY: PlatformFamily = PlatformFamily::Desktop;

/// `~/Library/Application Support/<app_id>`。
///
/// 这是 Apple 为应用支持数据指定的位置，也是 `path_provider` 的
/// `getApplicationSupportDirectory` 底层返回的内容。注意沙盒化的 App Store
/// 构建拿到的是容器内的相对路径，所以应用要上架 App Store 时，Dart 侧仍应优先
/// 使用 `path_provider`。
pub fn default_data_dir(app_id: &str) -> Option<PathBuf> {
    let home = std::env::var_os("HOME")?;
    Some(
        PathBuf::from(home)
            .join("Library")
            .join("Application Support")
            .join(app_id),
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reports_macos() {
        assert_eq!(NAME, "macos");
        assert_eq!(FAMILY, PlatformFamily::Desktop);
        assert!(crate::is_desktop());
    }

    #[test]
    fn data_dir_lives_under_application_support() {
        let Some(dir) = default_data_dir("frs_kit") else {
            return; // 这个环境里没有 HOME。
        };
        assert!(dir.ends_with("Library/Application Support/frs_kit"));
    }
}
