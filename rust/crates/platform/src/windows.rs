//! Windows 实现。
//!
//! 仅在 `target_os = "windows"` 时编译。

use std::path::PathBuf;

use crate::PlatformFamily;

/// 见 [`crate::NAME`]。
pub const NAME: &str = "windows";

/// 见 [`crate::FAMILY`]。
pub const FAMILY: PlatformFamily = PlatformFamily::Desktop;

/// `%APPDATA%\<app_id>`，回退到 `%USERPROFILE%\AppData\Roaming\<app_id>`。
///
/// `%APPDATA%` 是漫游应用数据目录，在 Windows 上正是 `path_provider` 的
/// `getApplicationSupportDirectory` 所对应的位置。
pub fn default_data_dir(app_id: &str) -> Option<PathBuf> {
    if let Some(app_data) = std::env::var_os("APPDATA") {
        return Some(PathBuf::from(app_data).join(app_id));
    }

    let user_profile = std::env::var_os("USERPROFILE")?;
    Some(
        PathBuf::from(user_profile)
            .join("AppData")
            .join("Roaming")
            .join(app_id),
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reports_windows() {
        assert_eq!(NAME, "windows");
        assert_eq!(FAMILY, PlatformFamily::Desktop);
        assert!(crate::is_desktop());
    }

    #[test]
    fn data_dir_lives_under_roaming_app_data() {
        let Some(dir) = default_data_dir("frs_kit") else {
            return; // APPDATA 和 USERPROFILE 都没有设置。
        };
        assert!(
            dir.ends_with("frs_kit") || dir.ends_with(r"Roaming\frs_kit"),
            "unexpected {dir:?}"
        );
    }
}
