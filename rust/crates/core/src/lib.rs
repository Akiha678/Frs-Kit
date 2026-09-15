//! Domain logic for frs_kit, with no knowledge of Dart or of `flutter_rust_bridge`.
//!
//! Everything here is ordinary Rust that can be unit-tested, benchmarked and
//! reused from a CLI. The FFI surface lives in the bridge crate (`rust/src/api`),
//! which converts these types into shapes Dart can carry.
//!
//! ```
//! use rust_flutter_core::domain::{Greeting, GreetingStyle};
//!
//! let greeting = Greeting::new("Ada", GreetingStyle::Formal)?;
//! assert_eq!(greeting.message(), "Good day, Ada.");
//! # Ok::<(), rust_flutter_core::CoreError>(())
//! ```

pub mod domain;
pub mod error;

pub use domain::{Greeting, GreetingStyle};
pub use error::{CoreError, CoreResult};

/// Smallest possible round-trip through the stack.
///
/// `examples/hello_rust` and the bridge smoke test both use it, which makes it
/// the fastest way to prove that Dart, the bridge and Rust are wired together.
#[must_use]
pub fn hello(name: &str) -> String {
    format!("Hello, {name}!")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn hello_interpolates_the_name() {
        assert_eq!(hello("Rust"), "Hello, Rust!");
    }

    #[test]
    fn hello_accepts_an_empty_name() {
        // `hello` is deliberately validation-free; `domain::greet` is the
        // function that enforces domain rules.
        assert_eq!(hello(""), "Hello, !");
    }
}
