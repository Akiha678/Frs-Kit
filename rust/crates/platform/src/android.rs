//! Android 实现。
//!
//! 仅在 `target_os = "android"` 时编译。
//!
//! Android 是唯一一个靠猜真的不安全的平台：真正的位置是 *应用自己的* 数据目录，
//! 它取决于包安装时的用户 id，以及应用是否在工作资料（work profile）里。下面的
//! 值是主用户、有文档记载的默认值，写日志够用，但 Dart 侧需要可写目录时应当调用
//! `path_provider`。

use std::path::PathBuf;

use crate::PlatformFamily;

/// 见 [`crate::NAME`]。
pub const NAME: &str = "android";

/// 见 [`crate::FAMILY`]。
pub const FAMILY: PlatformFamily = PlatformFamily::Mobile;

/// `/data/data/<app_id>/files`，Android 主用户默认的应用私有目录。
///
/// `/data/data` 是指向 `/data/user/0` 的传统符号链接；在正常设备上两者解析到同
/// 一位置。当 `app_id` 不是合法包名（`com.example.app`）时，调用方拿到的是一个
/// 并不存在的路径，这正是要回退到 `path_provider` 的预期信号。
pub fn default_data_dir(app_id: &str) -> Option<PathBuf> {
    if app_id.is_empty() {
        return None;
    }
    Some(PathBuf::from("/data/data").join(app_id).join("files"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reports_android() {
        assert_eq!(NAME, "android");
        assert_eq!(FAMILY, PlatformFamily::Mobile);
        assert!(!crate::is_desktop());
    }

    #[test]
    fn data_dir_is_the_app_private_files_directory() {
        let dir = default_data_dir("com.example.frs_kit").unwrap();
        assert_eq!(dir, PathBuf::from("/data/data/com.example.frs_kit/files"));
    }

    #[test]
    fn an_empty_app_id_has_no_guess() {
        assert!(default_data_dir("").is_none());
    }
}
