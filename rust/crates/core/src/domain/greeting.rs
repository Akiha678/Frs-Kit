//! 这个脚手架附带的唯一一段「业务逻辑」，有意做得很小。
//!
//! 它的存在是为了说明校验该放在哪一层：领域层拒绝坏输入，bridge 层只做转换。
//! 把 `greet` 换成真正的用例（搜索索引、解析器、求解器）不会改变依赖树里的其他
//! 任何东西。

use crate::error::{CoreError, CoreResult};

/// 领域接受的最长收件人名字，按字符计数。
pub const MAX_RECIPIENT_LEN: usize = 64;

/// 组合问候语时使用的语气。
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum GreetingStyle {
    /// `Hello, Ada!`
    #[default]
    Plain,
    /// `Hey Ada, great to see you!`
    Enthusiastic,
    /// `Good day, Ada.`
    Formal,
}

impl GreetingStyle {
    /// 所有语气，按展示顺序排列。
    ///
    /// 方便 Dart 侧做选择器，也方便测试里做穷尽检查，同时不必让 enum 的变体顺序
    /// 成为公开契约的一部分。
    pub const ALL: [Self; 3] = [Self::Plain, Self::Enthusiastic, Self::Formal];

    /// 稳定的小写标识符，适合日志、JSON 和 Dart。
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Plain => "plain",
            Self::Enthusiastic => "enthusiastic",
            Self::Formal => "formal",
        }
    }

    /// 为 `recipient` 渲染问候语句子。
    fn render(self, recipient: &str) -> String {
        match self {
            Self::Plain => format!("Hello, {recipient}!"),
            Self::Enthusiastic => format!("Hey {recipient}, great to see you!"),
            Self::Formal => format!("Good day, {recipient}."),
        }
    }
}

impl std::fmt::Display for GreetingStyle {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(self.as_str())
    }
}

/// 一条已经通过校验的问候语。
///
/// 字段私有，通过 getter 暴露：一旦构造出来，`Greeting` 就不可能变成非法的，
/// 渲染出的消息也永远不会和 `style` 脱节。
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Greeting {
    recipient: String,
    message: String,
    style: GreetingStyle,
}

impl Greeting {
    /// 校验 `recipient` 并渲染 `style`。
    ///
    /// 首尾空白会被 trim 而不是拒绝，这样文本框里多出的一个空格不会变成错误。
    ///
    /// # 错误
    ///
    /// trim 后的名字为空、或长于 [`MAX_RECIPIENT_LEN`] 时返回
    /// [`CoreError::InvalidInput`]。
    pub fn new(recipient: &str, style: GreetingStyle) -> CoreResult<Self> {
        let recipient = recipient.trim();

        if recipient.is_empty() {
            return Err(CoreError::InvalidInput("name must not be empty".to_owned()));
        }

        if recipient.chars().count() > MAX_RECIPIENT_LEN {
            return Err(CoreError::InvalidInput(format!(
                "name must be at most {MAX_RECIPIENT_LEN} characters"
            )));
        }

        Ok(Self {
            recipient: recipient.to_owned(),
            message: style.render(recipient),
            style,
        })
    }

    /// 已校验并 trim 过的收件人名字。
    #[must_use]
    pub fn recipient(&self) -> &str {
        &self.recipient
    }

    /// 渲染出的句子。
    #[must_use]
    pub fn message(&self) -> &str {
        &self.message
    }

    /// 这条问候语所用的语气。
    #[must_use]
    pub fn style(&self) -> GreetingStyle {
        self.style
    }

    /// 消费这条问候语，产出渲染好的句子。
    #[must_use]
    pub fn into_message(self) -> String {
        self.message
    }
}

/// [`Greeting::new`] 的便捷包装，名字与 bridge API 对齐。
///
/// # 错误
///
/// 见 [`Greeting::new`]。
pub fn greet(recipient: &str, style: GreetingStyle) -> CoreResult<Greeting> {
    Greeting::new(recipient, style)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn plain_style_renders_the_expected_sentence() {
        let greeting = Greeting::new("Ada", GreetingStyle::Plain).unwrap();
        assert_eq!(greeting.message(), "Hello, Ada!");
    }

    #[test]
    fn every_style_mentions_the_recipient() {
        for style in GreetingStyle::ALL {
            let greeting = Greeting::new("Ada", style).unwrap();
            assert!(
                greeting.message().contains("Ada"),
                "{style} lost the recipient: {}",
                greeting.message()
            );
            assert_eq!(greeting.style(), style);
        }
    }

    #[test]
    fn surrounding_whitespace_is_trimmed_not_rejected() {
        let greeting = Greeting::new("  Ada  ", GreetingStyle::Plain).unwrap();
        assert_eq!(greeting.recipient(), "Ada");
        assert_eq!(greeting.message(), "Hello, Ada!");
    }

    #[test]
    fn blank_names_are_rejected() {
        for blank in ["", "   ", "\t\n"] {
            let error = Greeting::new(blank, GreetingStyle::Plain).unwrap_err();
            assert_eq!(
                error,
                CoreError::InvalidInput("name must not be empty".to_owned())
            );
        }
    }

    #[test]
    fn names_at_the_length_limit_are_accepted() {
        let name = "a".repeat(MAX_RECIPIENT_LEN);
        assert!(Greeting::new(&name, GreetingStyle::Plain).is_ok());
    }

    #[test]
    fn names_beyond_the_length_limit_are_rejected() {
        let name = "a".repeat(MAX_RECIPIENT_LEN + 1);
        let error = Greeting::new(&name, GreetingStyle::Plain).unwrap_err();
        assert!(matches!(error, CoreError::InvalidInput(_)));
    }

    #[test]
    fn length_is_counted_in_characters_not_bytes() {
        // 64 个多字节字符没问题，尽管它们占 128 字节。
        let name = "é".repeat(MAX_RECIPIENT_LEN);
        assert!(Greeting::new(&name, GreetingStyle::Plain).is_ok());
    }

    #[test]
    fn greet_delegates_to_the_constructor() {
        assert_eq!(
            greet("Ada", GreetingStyle::Formal).unwrap(),
            Greeting::new("Ada", GreetingStyle::Formal).unwrap()
        );
    }

    #[test]
    fn style_identifiers_are_stable() {
        assert_eq!(GreetingStyle::default(), GreetingStyle::Plain);
        assert_eq!(GreetingStyle::Plain.as_str(), "plain");
        assert_eq!(GreetingStyle::Enthusiastic.to_string(), "enthusiastic");
        assert_eq!(GreetingStyle::Formal.as_str(), "formal");
    }

    #[test]
    fn into_message_matches_the_borrowed_message() {
        let greeting = Greeting::new("Ada", GreetingStyle::Plain).unwrap();
        let message = greeting.message().to_owned();
        assert_eq!(greeting.into_message(), message);
    }
}
