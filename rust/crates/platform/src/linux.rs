//! Linux 实现。
//!
//! 仅在 `target_os = "linux"` 时编译。

use std::path::PathBuf;

use crate::PlatformFamily;

/// 见 [`crate::NAME`]。
pub const NAME: &str = "linux";

/// 见 [`crate::FAMILY`]。
pub const FAMILY: PlatformFamily = PlatformFamily::Desktop;

/// `$XDG_DATA_HOME/<app_id>`，回退到 `~/.local/share/<app_id>`。
///
/// 遵循 XDG Base Directory 规范。按规范要求，空的 `XDG_DATA_HOME` 视为未设置：
/// “若 $XDG_DATA_HOME 未设置或为空，则应使用等于 $HOME/.local/share 的默认
/// 值。”
pub fn default_data_dir(app_id: &str) -> Option<PathBuf> {
    if let Some(xdg_data_home) = non_empty_env("XDG_DATA_HOME") {
        return Some(PathBuf::from(xdg_data_home).join(app_id));
    }

    let home = non_empty_env("HOME")?;
    Some(
        PathBuf::from(home)
            .join(".local")
            .join("share")
            .join(app_id),
    )
}

/// 仅当变量已设置 *且* 非空时返回它。
fn non_empty_env(key: &str) -> Option<std::ffi::OsString> {
    std::env::var_os(key).filter(|value| !value.is_empty())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reports_linux() {
        assert_eq!(NAME, "linux");
        assert_eq!(FAMILY, PlatformFamily::Desktop);
        assert!(crate::is_desktop());
    }

    #[test]
    fn data_dir_follows_the_xdg_layout() {
        let Some(dir) = default_data_dir("frs_kit") else {
            return; // XDG_DATA_HOME 和 HOME 都没有设置。
        };
        let expected_suffix = if non_empty_env("XDG_DATA_HOME").is_some() {
            "frs_kit"
        } else {
            ".local/share/frs_kit"
        };
        assert!(dir.ends_with(expected_suffix), "unexpected {dir:?}");
    }

    #[test]
    fn empty_environment_variables_are_treated_as_unset() {
        assert!(non_empty_env("FRS_KIT_DEFINITELY_NOT_SET").is_none());
    }
}
