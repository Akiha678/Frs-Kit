//! frs_kit 的领域逻辑，完全不知道 Dart，也不知道 `flutter_rust_bridge`。
//!
//! 这里的一切都是普通 Rust，可以被单元测试、benchmark，也可以被 CLI 复用。FFI
//! 边界在 bridge crate（`rust/src/api`）里，由它把这些类型转换成 Dart 能携带的
//! 形状。
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

/// 穿过整条栈的最小往返。
///
/// `examples/hello_rust` 和 bridge 冒烟测试都用它，因此它是验证 Dart、bridge 与
/// Rust 已经连通的最快方式。
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
        // `hello` 有意不做校验；`domain::greet` 才是执行领域规则的那个函数。
        assert_eq!(hello(""), "Hello, !");
    }
}
