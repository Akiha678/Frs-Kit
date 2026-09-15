//! Android implementation.
//!
//! Compiled only when `target_os = "android"`.
//!
//! Android is the one platform where guessing is genuinely unsafe: the real
//! location is the *app's own* data directory, which depends on the user id the
//! package was installed under and on whether the app is in a work profile. The
//! value below is the documented default for the primary user and is good enough
//! for logging, but the Dart side should call `path_provider` when it needs a
//! writable directory.

use std::path::PathBuf;

use crate::PlatformFamily;

/// See [`crate::NAME`].
pub const NAME: &str = "android";

/// See [`crate::FAMILY`].
pub const FAMILY: PlatformFamily = PlatformFamily::Mobile;

/// `/data/data/<app_id>/files`, the default app-private directory for the
/// primary Android user.
///
/// `/data/data` is the traditional symlink to `/data/user/0`; both resolve to
/// the same place on a normal device. Where `app_id` is not a valid package name
/// (`com.example.app`), the caller gets a path that does not exist, which is the
/// intended signal to fall back to `path_provider`.
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
