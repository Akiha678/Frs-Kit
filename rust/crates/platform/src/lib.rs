//! Platform differences, isolated behind one small module per operating system.
//!
//! Exactly one of the modules below is compiled, and it is aliased to `imp`
//! (short for "implementation"), so this file can expose a flat, always-valid
//! API without a single `#[cfg]` at the call site:
//!
//! ```
//! let family = rust_flutter_platform::FAMILY;
//! assert!(matches!(family.as_str(), "desktop" | "mobile" | "other"));
//!
//! // `None` simply means "this crate has no answer; ask the platform".
//! let _data_dir = rust_flutter_platform::default_data_dir("frs_kit");
//! ```
//!
//! # Adding a platform
//!
//! 1. Add `foo.rs` next to the other modules with `NAME`, `FAMILY` and
//!    `default_data_dir`.
//! 2. Add its `#[cfg(target_os = "foo")]` lines for `mod` and `use ... as imp`,
//!    and add `target_os = "foo"` to the `any(...)` list of `unsupported`.
//!
//! The unit tests in this file fail loudly if a module forgets a constant.

use std::path::PathBuf;

#[cfg(target_os = "android")]
mod android;

#[cfg(target_os = "linux")]
mod linux;

#[cfg(target_os = "macos")]
mod macos;

#[cfg(target_os = "windows")]
mod windows;

#[cfg(not(any(
    target_os = "linux",
    target_os = "macos",
    target_os = "windows",
    target_os = "android"
)))]
mod unsupported;

#[cfg(target_os = "android")]
use self::android as imp;

#[cfg(target_os = "linux")]
use self::linux as imp;

#[cfg(target_os = "macos")]
use self::macos as imp;

#[cfg(target_os = "windows")]
use self::windows as imp;

#[cfg(not(any(
    target_os = "linux",
    target_os = "macos",
    target_os = "windows",
    target_os = "android"
)))]
use self::unsupported as imp;

/// Coarse grouping of the operating systems the app distinguishes between.
///
/// Prefer this over string comparisons when behaviour (not reporting) depends on
/// the platform.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum PlatformFamily {
    /// Linux, macOS and Windows.
    Desktop,
    /// Android and iOS.
    Mobile,
    /// Anything else, including the web build and BSDs.
    Other,
}

impl PlatformFamily {
    /// Stable, lower-case identifier suitable for logs, JSON and Dart.
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Desktop => "desktop",
            Self::Mobile => "mobile",
            Self::Other => "other",
        }
    }
}

impl std::fmt::Display for PlatformFamily {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(self.as_str())
    }
}

/// Canonical lower-case name of the operating system this binary was built for.
///
/// Matches [`std::env::consts::OS`] on every supported target.
pub const NAME: &str = imp::NAME;

/// Coarse family of [`NAME`].
pub const FAMILY: PlatformFamily = imp::FAMILY;

/// True when the app is running on Linux, macOS or Windows.
#[must_use]
pub const fn is_desktop() -> bool {
    matches!(FAMILY, PlatformFamily::Desktop)
}

/// Best-effort per-user directory where `app_id` may keep its data.
///
/// This is intentionally dependency-free: it reads documented environment
/// variables instead of linking a platform support crate. Treat the result as a
/// hint, not a guarantee — Flutter apps that need a *sandbox-correct* location
/// should prefer `path_provider` on the Dart side, especially on Android and
/// iOS. `None` means "ask the platform, not this crate".
#[must_use]
pub fn default_data_dir(app_id: &str) -> Option<PathBuf> {
    imp::default_data_dir(app_id)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn name_matches_the_compilation_target() {
        #[cfg(target_family = "wasm")]
        assert_eq!(NAME, "web");
        #[cfg(not(target_family = "wasm"))]
        assert_eq!(NAME, std::env::consts::OS);
    }

    #[test]
    fn family_is_one_of_the_known_groups() {
        assert!(matches!(
            FAMILY,
            PlatformFamily::Desktop | PlatformFamily::Mobile | PlatformFamily::Other
        ));
    }

    #[test]
    fn is_desktop_agrees_with_family() {
        assert_eq!(is_desktop(), FAMILY == PlatformFamily::Desktop);
    }

    #[test]
    fn family_identifiers_are_stable() {
        assert_eq!(PlatformFamily::Desktop.as_str(), "desktop");
        assert_eq!(PlatformFamily::Mobile.to_string(), "mobile");
        assert_eq!(PlatformFamily::Other.as_str(), "other");
    }

    #[test]
    fn data_dir_is_absolute_and_namespaced_by_app_id() {
        let Some(dir) = default_data_dir("frs_kit") else {
            // Legitimate on platforms where this crate has no answer, e.g. the
            // unsupported fallback or macOS/Windows without a home directory.
            return;
        };
        assert!(dir.is_absolute(), "{dir:?} should be absolute");
        assert!(
            dir.ends_with("frs_kit"),
            "{dir:?} should end with the app id so two apps cannot collide"
        );
    }
}
