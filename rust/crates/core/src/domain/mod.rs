//! 领域类型与规则。
//!
//! 这里的模块都是私有的，按名字重新导出，因此 crate 的公开表面是显式的，重构
//! 文件布局永远不会破坏调用方。

mod greeting;

pub use greeting::{Greeting, GreetingStyle, MAX_RECIPIENT_LEN, greet};
