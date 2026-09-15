//! The single error type the domain speaks.
//!
//! This crate never leaks `anyhow`, `flutter_rust_bridge` or raw OS errors. The
//! bridge layer decides how a [`CoreError`] surfaces to Dart, and the platform
//! crate maps OS failures into [`CoreError::Unsupported`] or
//! [`CoreError::Platform`] before callers ever see them.

use thiserror::Error;

/// Anything the domain can refuse to do.
#[derive(Debug, Clone, Error, PartialEq, Eq)]
#[non_exhaustive]
pub enum CoreError {
    /// The caller passed data the domain cannot accept.
    #[error("invalid input: {0}")]
    InvalidInput(String),

    /// The operation does not exist on the current platform.
    #[error("unsupported: {0}")]
    Unsupported(String),

    /// The platform refused an operation that is otherwise supported.
    #[error("platform error: {0}")]
    Platform(String),
}

/// Convenience alias for domain results.
pub type CoreResult<T> = Result<T, CoreError>;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn invalid_input_keeps_the_reason_in_the_message() {
        let error = CoreError::InvalidInput("name must not be empty".to_owned());
        assert_eq!(error.to_string(), "invalid input: name must not be empty");
    }

    #[test]
    fn errors_are_comparable_and_cloneable() {
        let error = CoreError::Unsupported("web".to_owned());
        assert_eq!(error.clone(), error);
    }

    #[test]
    fn core_error_is_usable_as_a_std_error() {
        fn assert_std_error<E: std::error::Error + Send + Sync + 'static>() {}
        assert_std_error::<CoreError>();
    }
}
