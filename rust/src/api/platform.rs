//! Round-trip four: reading host facts, cheaply.
//!
//! All four calls are `#[frb(sync)]`. Compiling the platform into the library is
//! not something a Rust function can change at runtime, so there is nothing to
//! await: making Dart wait a microtask for a constant would be pure overhead.
//!
//! [`platform_summary`] exists so the UI can fetch everything in one call. One
//! synchronous call beats four, even when each of them is cheap.

use flutter_rust_bridge::frb;

use rust_flutter_platform as platform;

/// Coarse grouping of operating systems, mirroring
/// [`rust_flutter_platform::PlatformFamily`].
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PlatformFamily {
    /// Linux, macOS and Windows.
    Desktop,
    /// Android and iOS.
    Mobile,
    /// Anything else, including the web build and BSDs.
    Other,
}

impl From<platform::PlatformFamily> for PlatformFamily {
    fn from(family: platform::PlatformFamily) -> Self {
        match family {
            platform::PlatformFamily::Desktop => Self::Desktop,
            platform::PlatformFamily::Mobile => Self::Mobile,
            platform::PlatformFamily::Other => Self::Other,
        }
    }
}

/// Everything the UI wants to know about the host, in one call.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PlatformSummary {
    /// Operating system this native library was compiled for, e.g. `"macos"`.
    pub name: String,
    /// Coarse group `name` belongs to.
    pub family: PlatformFamily,
    /// Whether the app runs on a desktop OS.
    pub is_desktop: bool,
    /// Best-effort per-user data directory, or `None` when this crate has no
    /// answer for the platform.
    pub data_dir: Option<String>,
}

impl PlatformSummary {
    /// Reads the host, optionally namespacing [`Self::data_dir`] by `app_id`.
    fn read(app_id: &str) -> Self {
        Self {
            name: platform::NAME.to_owned(),
            family: platform::FAMILY.into(),
            is_desktop: platform::is_desktop(),
            data_dir: platform::default_data_dir(app_id)
                .map(|path| path.to_string_lossy().into_owned()),
        }
    }
}

/// Operating system this native library was compiled for.
///
/// Unlike `Platform.operatingSystem` in Dart, this reports the target the *Rust*
/// half was built for. The two agree in a correctly built app, and comparing them
/// is a quick way to spot a stale native library.
#[frb(sync)]
pub fn platform_name() -> String {
    platform::NAME.to_owned()
}

/// Coarse group [`platform_name`] belongs to.
#[frb(sync)]
pub fn platform_family() -> PlatformFamily {
    platform::FAMILY.into()
}

/// Whether the app runs on Linux, macOS or Windows.
#[frb(sync)]
pub fn is_desktop() -> bool {
    platform::is_desktop()
}

/// Best-effort application data directory for `app_id`.
///
/// `None` means "this crate has no answer for the platform" — iOS and the web
/// build, most notably. Prefer `path_provider` on the Dart side when the app needs
/// a sandbox-correct, writable directory; this is a dependency-free hint.
#[frb(sync)]
pub fn default_data_dir(app_id: String) -> Option<String> {
    platform::default_data_dir(&app_id).map(|path| path.to_string_lossy().into_owned())
}

/// Reads the host once and returns everything at the same time.
///
/// [`app_id`](Self::data_dir) is used to namespace the data directory, usually
/// with the application id (`com.example.frs_kit`).
#[frb(sync)]
pub fn platform_summary(app_id: String) -> PlatformSummary {
    PlatformSummary::read(&app_id)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn summary_agrees_with_the_individual_calls() {
        let summary = platform_summary("frs_kit".to_owned());
        assert_eq!(summary.name, platform_name());
        assert_eq!(summary.family, platform_family());
        assert_eq!(summary.is_desktop, is_desktop());
        assert_eq!(summary.data_dir, default_data_dir("frs_kit".to_owned()));
    }

    #[test]
    fn the_reported_family_matches_the_reported_name() {
        // Guards against a platform module forgetting to update one of the two.
        let family = platform_family();
        assert_eq!(family == PlatformFamily::Desktop, is_desktop());
    }
}
