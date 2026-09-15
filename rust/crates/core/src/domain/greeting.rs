//! The one piece of "business logic" this scaffold ships, kept deliberately small.
//!
//! It exists to show where validation belongs: the domain rejects bad input, and
//! the bridge layer only translates. Swapping `greet` for a real use case (a
//! search index, a parser, a solver) does not change anything else in the tree.

use crate::error::{CoreError, CoreResult};

/// Longest recipient name the domain accepts, counted in characters.
pub const MAX_RECIPIENT_LEN: usize = 64;

/// Tone used when composing a greeting.
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
    /// Every style, in presentation order.
    ///
    /// Handy for a Dart-side picker and for exhaustiveness in tests, without
    /// making the enum's variant order part of the public contract.
    pub const ALL: [Self; 3] = [Self::Plain, Self::Enthusiastic, Self::Formal];

    /// Stable, lower-case identifier suitable for logs, JSON and Dart.
    #[must_use]
    pub const fn as_str(self) -> &'static str {
        match self {
            Self::Plain => "plain",
            Self::Enthusiastic => "enthusiastic",
            Self::Formal => "formal",
        }
    }

    /// Renders the greeting sentence for `recipient`.
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

/// A greeting that has already passed validation.
///
/// Fields are private and exposed through getters: once constructed, a
/// `Greeting` cannot become invalid, and the rendered message can never drift
/// out of sync with `style`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Greeting {
    recipient: String,
    message: String,
    style: GreetingStyle,
}

impl Greeting {
    /// Validates `recipient` and renders `style`.
    ///
    /// Leading and trailing whitespace is trimmed rather than rejected, so a
    /// stray space from a text field is not an error.
    ///
    /// # Errors
    ///
    /// Returns [`CoreError::InvalidInput`] when the trimmed name is empty or
    /// longer than [`MAX_RECIPIENT_LEN`].
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

    /// The validated, trimmed recipient name.
    #[must_use]
    pub fn recipient(&self) -> &str {
        &self.recipient
    }

    /// The rendered sentence.
    #[must_use]
    pub fn message(&self) -> &str {
        &self.message
    }

    /// The tone this greeting was rendered in.
    #[must_use]
    pub fn style(&self) -> GreetingStyle {
        self.style
    }

    /// Consumes the greeting, yielding the rendered sentence.
    #[must_use]
    pub fn into_message(self) -> String {
        self.message
    }
}

/// Convenience wrapper around [`Greeting::new`], mirroring the bridge API name.
///
/// # Errors
///
/// See [`Greeting::new`].
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
        // 64 multi-byte characters are fine even though they are 128 bytes.
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
