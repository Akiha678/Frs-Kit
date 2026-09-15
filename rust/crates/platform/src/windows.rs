//! Windows implementation.
//!
//! Compiled only when `target_os = "windows"`.

use std::path::PathBuf;

use crate::PlatformFamily;

/// See [`crate::NAME`].
pub const NAME: &str = "windows";

/// See [`crate::FAMILY`].
pub const FAMILY: PlatformFamily = PlatformFamily::Desktop;

/// `%APPDATA%\<app_id>`, falling back to `%USERPROFILE%\AppData\Roaming\<app_id>`.
///
/// `%APPDATA%` is the roaming application data folder, which is what
/// `path_provider`'s `getApplicationSupportDirectory` maps to on Windows.
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
            return; // Neither APPDATA nor USERPROFILE is set.
        };
        assert!(
            dir.ends_with("frs_kit") || dir.ends_with(r"Roaming\frs_kit"),
            "unexpected {dir:?}"
        );
    }
}
