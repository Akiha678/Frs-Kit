//! 往返之一：普通值、struct 与 enum —— 以及唯一的同步调用。
//!
//! 这里的类型是 `rust_flutter_core::domain` 的 *wire* 双胞胎。这份重复是有意
//! 为之的，值这几行代价：
//!
//! * 领域 enum 仍可自由地新增变体、变成 `#[non_exhaustive]`，或被 CLI 复用，
//!   而不会悄悄改变 Dart API；
//! * 生成的 Dart enum 会精确保留这里写下的变体名；
//! * 转换函数是领域类型变成 wire 类型的唯一场所，reviewer 一屏之内就能核对映射。

use anyhow::Result;
use flutter_rust_bridge::frb;

use rust_flutter_core::domain;

/// 组合问候语时使用的语气。
///
/// 对应 [`rust_flutter_core::domain::GreetingStyle`]；下面的 `From` 实现让两者
/// 保持一致。
///
/// 注意 *没有* 派生什么：`Default`。flutter_rust_bridge 会把它识别出的每个可
/// 派生 trait 都桥接成额外的 Dart 入口点，所以这里多余的 `#[derive(Default)]`
/// 会在生成的 API 里加一个没人调用的 `GreetingStyle.default_()`。
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum GreetingStyle {
    /// `Hello, Ada!`
    Plain,
    /// `Hey Ada, great to see you!`
    Enthusiastic,
    /// `Good day, Ada.`
    Formal,
}

impl From<GreetingStyle> for domain::GreetingStyle {
    fn from(style: GreetingStyle) -> Self {
        match style {
            GreetingStyle::Plain => Self::Plain,
            GreetingStyle::Enthusiastic => Self::Enthusiastic,
            GreetingStyle::Formal => Self::Formal,
        }
    }
}

impl From<domain::GreetingStyle> for GreetingStyle {
    fn from(style: domain::GreetingStyle) -> Self {
        match style {
            domain::GreetingStyle::Plain => Self::Plain,
            domain::GreetingStyle::Enthusiastic => Self::Enthusiastic,
            domain::GreetingStyle::Formal => Self::Formal,
        }
    }
}

/// 由 Rust 渲染好、以普通数据类交给 Dart 的问候语。
///
/// 公开字段，Dart 侧没有不变量要维护：领域层已经校验过数据，所以 `recipient`
/// 是 trim 过的，`message` 与 `style` 匹配。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Greeting {
    /// 这条问候语称呼的、已校验并 trim 过的名字。
    pub recipient: String,
    /// 渲染出的句子。
    pub message: String,
    /// `message` 所用的语气。
    pub style: GreetingStyle,
}

impl From<domain::Greeting> for Greeting {
    fn from(greeting: domain::Greeting) -> Self {
        Self {
            recipient: greeting.recipient().to_owned(),
            message: greeting.message().to_owned(),
            style: greeting.style().into(),
        }
    }
}

/// 尽可能最小的 bridge 调用。
///
/// `#[frb(sync)]` 让它在 Dart 里是普通的同步 `String` 而不是 `Future<String>`：
/// 调用运行在当前 isolate 上，因此必须保持廉价。`format!` 够格；读文件不够 ——
/// 见 [`crate::api::async_demo`]。
#[frb(sync)]
pub fn hello(name: String) -> String {
    rust_flutter_core::hello(&name)
}

/// 校验 `name` 并按 `style` 渲染，异步完成。
///
/// Dart 签名：`Future<Greeting> greet({required String name, required
/// GreetingStyle style})`。
///
/// # 错误
///
/// 当名字为空、或长于 [`rust_flutter_core::domain::MAX_RECIPIENT_LEN`] 个字符
/// 时，把 [`rust_flutter_core::CoreError::InvalidInput`] 作为
/// `AnyhowException` 暴露给 Dart。下面的 `?` 就是整个转换层：`CoreError` 实现了
/// `std::error::Error`，所以 `anyhow` 会连它的 `Display` 消息一起接住。
pub fn greet(name: String, style: GreetingStyle) -> Result<Greeting> {
    let greeting = domain::greet(&name, style.into())?;
    Ok(greeting.into())
}
