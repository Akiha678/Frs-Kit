//! Round-trip one: plain values, structs and enums — and the only synchronous call.
//!
//! The types in here are the *wire* twins of `rust_flutter_core::domain`. The
//! duplication is deliberate and worth the few lines it costs:
//!
//! * the domain enum stays free to gain variants, to become `#[non_exhaustive]`
//!   or to be reused by a CLI, without silently changing the Dart API;
//! * the generated Dart enum keeps exactly the variant names written here;
//! * the conversion functions are the single place where a domain type becomes a
//!   wire type, so a reviewer can check the mapping in one screen.

use anyhow::Result;
use flutter_rust_bridge::frb;

use rust_flutter_core::domain;

/// Tone used when composing a greeting.
///
/// Mirrors [`rust_flutter_core::domain::GreetingStyle`]; the `From` impls below
/// keep the two in step.
///
/// Note what is *not* derived: `Default`. flutter_rust_bridge bridges every
/// derivable trait it recognises as an extra Dart entry point, so a needless
/// `#[derive(Default)]` here would add a `GreetingStyle.default_()` to the
/// generated API that nothing calls.
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

/// A greeting rendered by Rust and handed to Dart as a plain data class.
///
/// Public fields, no invariants to preserve on the Dart side: the domain already
/// validated the data, so `recipient` is trimmed and `message` matches `style`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Greeting {
    /// The validated, trimmed name the greeting addresses.
    pub recipient: String,
    /// The rendered sentence.
    pub message: String,
    /// The tone `message` was rendered in.
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

/// The smallest possible bridge call.
///
/// `#[frb(sync)]` makes this a plain synchronous `String` in Dart instead of a
/// `Future<String>`: the call runs on the calling isolate, so it must stay cheap.
/// A `format!` qualifies; a file read does not — see [`crate::api::async_demo`].
#[frb(sync)]
pub fn hello(name: String) -> String {
    rust_flutter_core::hello(&name)
}

/// Validates `name` and renders it in `style`, asynchronously.
///
/// Dart signature: `Future<Greeting> greet({required String name, required
/// GreetingStyle style})`.
///
/// # Errors
///
/// Surfaces [`rust_flutter_core::CoreError::InvalidInput`] to Dart as an
/// `AnyhowException` when the name is blank or longer than
/// [`rust_flutter_core::domain::MAX_RECIPIENT_LEN`] characters. The `?` below is
/// the whole translation layer: `CoreError` implements `std::error::Error`, so
/// `anyhow` picks it up with its `Display` message intact.
pub fn greet(name: String, style: GreetingStyle) -> Result<Greeting> {
    let greeting = domain::greet(&name, style.into())?;
    Ok(greeting.into())
}
