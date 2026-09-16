//! 往返之四：廉价地读取宿主信息。
//!
//! 四个调用都是 `#[frb(sync)]`。把平台编译进库这件事不是 Rust 函数能在运行时改
//! 变的，所以没有东西可以 await：为了一个常量让 Dart 等一个 microtask 纯属额外
//! 开销。
//!
//! [`platform_summary`] 的存在是为了让 UI 一次调用取回全部信息。一次同步调用
//! 胜过四次，哪怕每一次都很廉价。

use flutter_rust_bridge::frb;

use rust_flutter_platform as platform;

/// 操作系统的粗略分组，对应 [`rust_flutter_platform::PlatformFamily`]。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PlatformFamily {
    /// Linux、macOS 与 Windows。
    Desktop,
    /// Android 与 iOS。
    Mobile,
    /// 其他一切，包括 web 构建和各类 BSD。
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

/// UI 想知道的宿主信息，一次调用全部取回。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PlatformSummary {
    /// 这个原生库编译时针对的操作系统，例如 `"macos"`。
    pub name: String,
    /// `name` 所属的粗略分组。
    pub family: PlatformFamily,
    /// 应用是否运行在桌面操作系统上。
    pub is_desktop: bool,
    /// 尽力而为的每用户数据目录；本 crate 对该平台没有答案时为 `None`。
    pub data_dir: Option<String>,
}

impl PlatformSummary {
    /// 读取宿主信息，可选地用 `app_id` 给 [`Self::data_dir`] 加命名空间。
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

/// 这个原生库编译时针对的操作系统。
///
/// 与 Dart 的 `Platform.operatingSystem` 不同，它报告的是 *Rust* 那一半编译时
/// 针对的目标。在构建正确的应用里两者一致，比较它们是发现原生库过期的最快方式。
#[frb(sync)]
pub fn platform_name() -> String {
    platform::NAME.to_owned()
}

/// [`platform_name`] 所属的粗略分组。
#[frb(sync)]
pub fn platform_family() -> PlatformFamily {
    platform::FAMILY.into()
}

/// 应用是否运行在 Linux、macOS 或 Windows 上。
#[frb(sync)]
pub fn is_desktop() -> bool {
    platform::is_desktop()
}

/// 为 `app_id` 尽力而为地给出应用数据目录。
///
/// `None` 表示「本 crate 对该平台没有答案」—— 最典型的是 iOS 和 web 构建。应用
/// 需要沙盒正确、可写的目录时，Dart 侧应优先用 `path_provider`；这里给的只是一
/// 个无依赖的提示。
#[frb(sync)]
pub fn default_data_dir(app_id: String) -> Option<String> {
    platform::default_data_dir(&app_id).map(|path| path.to_string_lossy().into_owned())
}

/// 读取一次宿主信息，同时返回全部内容。
///
/// [`app_id`](Self::data_dir) 用于给数据目录加命名空间，通常传应用 id
/// （`com.example.frs_kit`）。
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
        // 防止某个平台模块忘记同步更新两者之一。
        let family = platform_family();
        assert_eq!(family == PlatformFamily::Desktop, is_desktop());
    }
}
