//! Domain types and rules.
//!
//! Modules in here are private and re-exported by name, so the public surface of
//! the crate is explicit and refactoring the file layout never breaks callers.

mod greeting;

pub use greeting::{Greeting, GreetingStyle, MAX_RECIPIENT_LEN, greet};
