//! 领域唯一会说的错误类型。
//!
//! 本 crate 从不泄漏 `anyhow`、`flutter_rust_bridge` 或原始 OS 错误。bridge 层
//! 决定 [`CoreError`] 怎么暴露给 Dart，platform crate 则把 OS 失败映射成
//! [`CoreError::Unsupported`] 或 [`CoreError::Platform`]，再让调用方看到。

use thiserror::Error;

/// 领域可以拒绝去做的任何事。
#[derive(Debug, Clone, Error, PartialEq, Eq)]
#[non_exhaustive]
pub enum CoreError {
    /// 调用方传来的数据领域无法接受。
    #[error("invalid input: {0}")]
    InvalidInput(String),

    /// 当前平台上不存在这个操作。
    #[error("unsupported: {0}")]
    Unsupported(String),

    /// 平台拒绝了一个本来受支持的操作。
    #[error("platform error: {0}")]
    Platform(String),
}

/// 领域结果的便捷别名。
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
