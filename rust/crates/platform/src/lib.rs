//! 平台差异，按操作系统隔离在每个小模块里。
//!
//! 下面这些模块只会编译其中一个，并别名成 `imp`（"implementation" 的缩写），
//! 因此本文件可以暴露一套扁平的、在任何平台上都有效的 API，调用点一个 `#[cfg]`
//! 都不需要：
//!
//! ```
//! let family = rust_flutter_platform::FAMILY;
//! assert!(matches!(family.as_str(), "desktop" | "mobile" | "other"));
//!
//! // `None` simply means "this crate has no answer; ask the platform".
//! let _data_dir = rust_flutter_platform::default_data_dir("frs_kit");
//! ```
//!
//! # 新增一个平台
//!
//! 1. 在其他模块旁边加一个 `foo.rs`，内含 `NAME`、`FAMILY` 和
//!    `default_data_dir`。
//! 2. 为它的 `mod` 和 `use ... as imp` 加上 `#[cfg(target_os = "foo")]` 行，
//!    并把 `target_os = "foo"` 加进 `unsupported` 的 `any(...)` 列表。
//!
//! 某个模块漏掉常量时，本文件里的单元测试会大声失败。

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

/// 应用要区分的那些操作系统的粗略分组。
///
/// 当行为（而不是报告）取决于平台时，优先用它而不是比较字符串。
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum PlatformFamily {
    /// Linux、macOS 与 Windows。
    Desktop,
    /// Android 与 iOS。
    Mobile,
    /// 其他一切，包括 web 构建和各类 BSD。
    Other,
}

impl PlatformFamily {
    /// 稳定的小写标识符，适合日志、JSON 和 Dart。
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

/// 这个二进制编译时针对的操作系统的规范小写名字。
///
/// 在每个受支持目标上都与 [`std::env::consts::OS`] 一致。
pub const NAME: &str = imp::NAME;

/// [`NAME`] 的粗略分组。
pub const FAMILY: PlatformFamily = imp::FAMILY;

/// 应用运行在 Linux、macOS 或 Windows 上时为 true。
#[must_use]
pub const fn is_desktop() -> bool {
    matches!(FAMILY, PlatformFamily::Desktop)
}

/// `app_id` 可以用来存放数据的、尽力而为的每用户目录。
///
/// 这里有意做到无依赖：读取有文档记载的环境变量，而不是链接一个平台支持
/// crate。把结果当作提示而非保证 —— 需要 *沙盒正确* 位置的 Flutter 应用应在
/// Dart 侧优先使用 `path_provider`，在 Android 和 iOS 上尤其如此。`None` 表示
/// 「去问平台，别问这个 crate」。
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
            // 在本 crate 没有答案的平台上这是合法的，例如 unsupported 回退，
            // 或者没有 home 目录的 macOS/Windows。
            return;
        };
        assert!(dir.is_absolute(), "{dir:?} should be absolute");
        assert!(
            dir.ends_with("frs_kit"),
            "{dir:?} should end with the app id so two apps cannot collide"
        );
    }
}
