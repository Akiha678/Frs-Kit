//! Linux implementation.
//!
//! Compiled only when `target_os = "linux"`.

use std::path::PathBuf;

use crate::PlatformFamily;

/// See [`crate::NAME`].
pub const NAME: &str = "linux";

/// See [`crate::FAMILY`].
pub const FAMILY: PlatformFamily = PlatformFamily::Desktop;

/// `$XDG_DATA_HOME/<app_id>`, falling back to `~/.local/share/<app_id>`.
///
/// Follows the XDG Base Directory specification. An empty `XDG_DATA_HOME` is
/// treated as unset, as the specification requires: "If $XDG_DATA_HOME is either
/// not set or empty, a default equal to $HOME/.local/share should be used."
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

/// Returns the variable only when it is set *and* non-empty.
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
            return; // Neither XDG_DATA_HOME nor HOME is set.
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
