//! macOS implementation.
//!
//! Compiled only when `target_os = "macos"`.

use std::path::PathBuf;

use crate::PlatformFamily;

/// See [`crate::NAME`].
pub const NAME: &str = "macos";

/// See [`crate::FAMILY`].
pub const FAMILY: PlatformFamily = PlatformFamily::Desktop;

/// `~/Library/Application Support/<app_id>`.
///
/// This is the location Apple documents for application support data, and it is
/// what `path_provider`'s `getApplicationSupportDirectory` returns under the
/// hood. Note that a sandboxed App Store build gets a container-relative path
/// instead, which is why the Dart side should still prefer `path_provider` when
/// the app ships to the App Store.
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
            return; // No HOME in this environment.
        };
        assert!(dir.ends_with("Library/Application Support/frs_kit"));
    }
}
