//! 往返之二：`Future`，以及两种慢工作。
//!
//! 每个 *不是* `#[frb(sync)]` 的函数都会变成 Dart 的 `Future`。Rust 侧在这个
//! future 里做什么，决定应用是否流畅：
//!
//! * **I/O 密集** 的工作应当 `.await` 一个非阻塞原语（HTTP 客户端、由 reactor
//!   驱动的定时器……）。这样才不会有人去抢 worker 线程。
//! * **CPU 密集** 的工作必须搬离 async runtime，否则它会饿死所有其他在途调用。
//!   [`fibonacci`] 演示了为此准备的 helper。
//!
//! 在 `pub async fn` 里写 `std::thread::sleep` 能编译，也不会阻塞 Dart ——
//! flutter_rust_bridge 在自己的线程上跑 runtime —— 但它仍然占着一个 runtime
//! worker。因此 [`delayed_hello`] 改为在 blocking pool 上等待。

use std::time::Duration;

use anyhow::{Result, bail};

/// [`delayed_hello`] 会遵守的最长延迟，单位毫秒。
const MAX_DELAY_MS: u32 = 5_000;

/// [`fibonacci`] 接受的最大输入。
///
/// `F(93) = 12_200_160_415_121_876_738` 是能放进 `u64` 的最大斐波那契数；
/// `F(94)` 会溢出它。下面的循环永远不会算出超过 `F(n)` 的项，所以这个上界是
/// 精确的，而不是保守的。
const MAX_FIBONACCI_N: u32 = 93;

/// 等待 `delay_ms` 毫秒后向 `name` 问好。
///
/// Dart 签名：`Future<String> delayedHello({required String name, required
/// int delayMs})`。超过 [`MAX_DELAY_MS`] 的值会被 clamp 而不是拒绝，这样 UI 上
/// 的滑块不会变成一个错误弹窗。
///
/// # 错误
///
/// 目前不会失败。这里的 `Result` 是有意保留在脚手架里的：把 sleep 换成真正的
/// 网络调用不会改变 Dart 签名。
pub async fn delayed_hello(name: String, delay_ms: u32) -> Result<String> {
    let delay_ms = clamp_delay(delay_ms);
    run_blocking(move || std::thread::sleep(Duration::from_millis(delay_ms))).await?;
    Ok(rust_flutter_core::hello(&name))
}

/// 把请求的延迟 clamp 到 [`delayed_hello`] 会遵守的范围。
///
/// 从函数里抽出来是为了能直接测试这条规则：`delayed_hello` 本身需要 bridge 的
/// runtime，而单元测试没有。
fn clamp_delay(delay_ms: u32) -> u64 {
    u64::from(delay_ms.min(MAX_DELAY_MS))
}

/// 第 `n` 个斐波那契数，其中 `F(0) = 0`、`F(1) = 1`。
///
/// 代表任何 CPU 密集的计算：算术跑在 blocking 线程上，所以并行的 N 次调用会各
/// 占 blocking pool 的一个线程，而不是在 async runtime 上互相排队。
///
/// # 错误
///
/// 当 `n > MAX_FIBONACCI_N`、结果放不进 `u64` 时返回错误。
pub async fn fibonacci(n: u32) -> Result<u64> {
    if n > MAX_FIBONACCI_N {
        bail!("n must be at most {MAX_FIBONACCI_N}, otherwise the result overflows a u64");
    }

    run_blocking(move || fibonacci_blocking(n)).await
}

/// 在一个允许阻塞的线程上运行 `work`，并等待它的结果。
///
/// 这是 bridge 感知版的 `tokio::task::spawn_blocking`：web 目标上没有可以 spawn
/// 的线程池，所以这个 helper 还要接收 flutter_rust_bridge 已经持有的那个池。在
/// 每个平台都传入它，能让这段代码无需 `#[cfg]` 就为 web 编译。
///
/// await 这个 handle 让顺序符合直觉：工作真正完成时，Dart 的 `Future` 才完成。
async fn run_blocking<F, R>(work: F) -> Result<R>
where
    F: FnOnce() -> R + Send + 'static,
    R: Send + 'static,
{
    let handle = flutter_rust_bridge::spawn_blocking_with(
        work,
        crate::frb_generated::FLUTTER_RUST_BRIDGE_HANDLER.thread_pool(),
    );
    Ok(handle.await?)
}

/// 迭代版斐波那契：`O(n)` 时间、`O(1)` 空间，没有递归深度限制。
///
/// 循环停在 `F(n)` —— 走 `n - 1` 步 —— 而不是多算一个 `F(n + 1)`，这正是
/// `n = 93` 在 debug 构建里也安全的原因。
fn fibonacci_blocking(n: u32) -> u64 {
    if n == 0 {
        return 0;
    }

    let (mut previous, mut current) = (0_u64, 1_u64); // F(0), F(1)
    for _ in 1..n {
        (previous, current) = (current, previous + current);
    }
    current // F(n)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn fibonacci_matches_the_sequence() {
        let expected = [0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55];
        for (n, value) in expected.iter().enumerate() {
            assert_eq!(fibonacci_blocking(n as u32), *value, "F({n})");
        }
    }

    #[test]
    fn fibonacci_at_the_limit_does_not_overflow() {
        // 在 debug 构建里也会运行，那里溢出会 panic。
        assert_eq!(
            fibonacci_blocking(MAX_FIBONACCI_N),
            12_200_160_415_121_876_738
        );
    }

    #[test]
    fn delays_below_the_maximum_pass_through() {
        assert_eq!(clamp_delay(0), 0);
        assert_eq!(clamp_delay(250), 250);
        assert_eq!(clamp_delay(MAX_DELAY_MS), u64::from(MAX_DELAY_MS));
    }

    #[test]
    fn delays_above_the_maximum_are_clamped_not_rejected() {
        // UI 滑块不能变成错误弹窗。
        assert_eq!(clamp_delay(MAX_DELAY_MS + 1), u64::from(MAX_DELAY_MS));
        assert_eq!(clamp_delay(u32::MAX), u64::from(MAX_DELAY_MS));
    }
}
