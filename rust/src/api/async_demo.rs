//! Round-trip two: `Future`s, and the two kinds of slow work.
//!
//! Every function that is *not* `#[frb(sync)]` becomes a Dart `Future`. What the
//! Rust side does inside that future decides whether the app stays smooth:
//!
//! * **I/O-bound** work should `.await` a non-blocking primitive (an HTTP client,
//!   a reactor-backed timer, ...). Nothing else competes for a worker thread.
//! * **CPU-bound** work must be moved off the async runtime, or it starves every
//!   other in-flight call. [`fibonacci`] shows the helper for that.
//!
//! A `std::thread::sleep` inside `pub async fn` would compile and would not block
//! Dart — flutter_rust_bridge runs the runtime on its own threads — but it still
//! occupies a runtime worker. [`delayed_hello`] therefore does its waiting on the
//! blocking pool instead.

use std::time::Duration;

use anyhow::{Result, bail};

/// Longest delay [`delayed_hello`] honours, in milliseconds.
const MAX_DELAY_MS: u32 = 5_000;

/// Largest input [`fibonacci`] accepts.
///
/// `F(93) = 12_200_160_415_121_876_738` is the largest Fibonacci number that fits
/// in a `u64`; `F(94)` overflows it. The loop below never forms a term beyond
/// `F(n)`, so this bound is exact rather than conservative.
const MAX_FIBONACCI_N: u32 = 93;

/// Greets `name` after waiting `delay_ms` milliseconds.
///
/// Dart signature: `Future<String> delayedHello({required String name, required
/// int delayMs})`. Values above [`MAX_DELAY_MS`] are clamped instead of rejected,
/// which keeps a slider in the UI from turning into an error dialog.
///
/// # Errors
///
/// Cannot fail today. The `Result` is part of the scaffold on purpose: replacing
/// the sleep with a real network call will not change the Dart signature.
pub async fn delayed_hello(name: String, delay_ms: u32) -> Result<String> {
    let delay_ms = clamp_delay(delay_ms);
    run_blocking(move || std::thread::sleep(Duration::from_millis(delay_ms))).await?;
    Ok(rust_flutter_core::hello(&name))
}

/// Clamps a requested delay to what [`delayed_hello`] will honour.
///
/// Pulled out of the function so the rule can be tested directly: `delayed_hello`
/// itself needs the bridge's runtime, which a unit test does not have.
fn clamp_delay(delay_ms: u32) -> u64 {
    u64::from(delay_ms.min(MAX_DELAY_MS))
}

/// The `n`-th Fibonacci number, with `F(0) = 0` and `F(1) = 1`.
///
/// Stands in for any CPU-bound computation: the arithmetic runs on a blocking
/// thread, so N calls in parallel use N threads of the pool instead of queueing
/// behind each other on the async runtime.
///
/// # Errors
///
/// Returns an error for `n > MAX_FIBONACCI_N`, where the result would not fit in a
/// `u64`.
pub async fn fibonacci(n: u32) -> Result<u64> {
    if n > MAX_FIBONACCI_N {
        bail!("n must be at most {MAX_FIBONACCI_N}, otherwise the result overflows a u64");
    }

    run_blocking(move || fibonacci_blocking(n)).await
}

/// Runs `work` on a thread that is allowed to block and awaits its result.
///
/// This is the bridge-aware stand-in for `tokio::task::spawn_blocking`: on the
/// web target there is no thread pool to spawn onto, so the helper also takes the
/// pool flutter_rust_bridge already owns. Passing it on every platform keeps this
/// code compiling for web without a `#[cfg]`.
///
/// Awaiting the handle keeps the ordering intuitive: the Dart `Future` completes
/// when the work has actually finished.
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

/// Iterative Fibonacci: `O(n)` time, `O(1)` space, no recursion depth limit.
///
/// The loop stops at `F(n)` — after `n - 1` steps — rather than forming the usual
/// extra `F(n + 1)`, which is what makes `n = 93` safe in a debug build.
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
        // Runs in a debug build too, where overflow would panic.
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
        // A UI slider must not be able to turn into an error dialog.
        assert_eq!(clamp_delay(MAX_DELAY_MS + 1), u64::from(MAX_DELAY_MS));
        assert_eq!(clamp_delay(u32::MAX), u64::from(MAX_DELAY_MS));
    }
}
