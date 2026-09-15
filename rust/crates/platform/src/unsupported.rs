//! Fallback for every operating system without a dedicated module — including
//! iOS, the web build, and the BSDs.
//!
//! Compiled only when no other module matches. It keeps the crate honest: the
//! API stays total on every target, and callers find out at *runtime* (through
//! [`crate::FAMILY`] or a `None` data directory) that the platform has no
//! special handling, instead of the crate failing to build.

use std::path::PathBuf;

use crate::PlatformFamily;

/// See [`crate::NAME`].
///
/// The web build is the one target where the operating system genuinely does not
/// exist, and `std::env::consts::OS` reports `"unknown"` for `wasm32-unknown-
/// unknown`. Naming it `"web"` keeps the value comparable with `kIsWeb` on the
/// Dart side.
#[cfg(target_family = "wasm")]
pub const NAME: &str = "web";

/// See [`crate::NAME`].
///
/// Reports the real target, so iOS logs as `ios` rather than `unsupported`.
#[cfg(not(target_family = "wasm"))]
pub const NAME: &str = std::env::consts::OS;

/// See [`crate::FAMILY`].
///
/// Always [`PlatformFamily::Other`]: modules for mobile-only targets that are
/// not Android (notably iOS) do not exist yet, and claiming `Mobile` here would
/// make `is_desktop` lie in the other direction.
pub const FAMILY: PlatformFamily = PlatformFamily::Other;

/// Always `None`.
///
/// A wrong guess is worse than no answer: the caller should ask the platform
/// (for example through `path_provider` on the Dart side) instead.
pub fn default_data_dir(_app_id: &str) -> Option<PathBuf> {
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reports_the_real_target() {
        // For example "ios" or "freebsd" — never the literal "unsupported".
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
