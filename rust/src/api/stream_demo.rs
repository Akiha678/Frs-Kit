//! 往返之三：一个由 Rust 主动推入的 `Stream`。
//!
//! 接受 [`StreamSink`] 参数的函数会返回 Dart 的 `Stream` 而不是 `Future`。
//! flutter_rust_bridge 在 worker 线程上运行函数体（`FfiCallMode::Normal` 会
//! spawn；只有 `#[frb(sync)]` 才内联执行），所以下面的 sleep 不会卡住 UI。

use std::time::Duration;

use anyhow::Result;

use crate::frb_generated::StreamSink;

/// 两次发送之间的最长间隔，单位毫秒。
const MAX_INTERVAL_MS: u32 = 2_000;

/// 从 `count` 倒数到 `1`，每 `interval_ms` 发一个值，然后关闭。
///
/// Dart 签名：`Stream<int> countdown({required int count, required int
/// intervalMs})`。超过 [`MAX_INTERVAL_MS`] 的值会被 clamp，所以 UI 滑块无法让
/// 这个流慢到几分钟才发一次。
///
/// 返回 `Ok(())` 会正常关闭流。要让它失败，可以发 `sink.add_error(...)` 之后
/// 仍然返回 `Ok(())`，或者直接返回 `Err(...)` —— 两种方式 Dart 看到的都是错误
/// 事件，而不是静默停止。
///
/// # 取消
///
/// 当 Dart 取消订阅（widget 被 dispose、带新 key 的 `FutureBuilder` 重建）后，
/// 下一次 `add` 会失败。在这个失败上跳出循环，才能让已取消的 `Stream` 不再占着
/// worker 线程直到它自己跑完。
pub fn countdown(count: u32, interval_ms: u32, sink: StreamSink<u32>) -> Result<()> {
    let interval = clamp_interval(interval_ms);

    for remaining in (1..=count).rev() {
        if sink.add(remaining).is_err() {
            break; // Dart 侧已停止监听。
        }
        std::thread::sleep(interval);
    }

    Ok(())
}

/// 把请求的间隔 clamp 到 [`countdown`] 会遵守的范围。
///
/// 从函数里抽出来是为了能直接测试这条规则：`countdown` 需要一个 `StreamSink`，
/// 而只有 bridge 能构造它。
fn clamp_interval(interval_ms: u32) -> Duration {
    Duration::from_millis(u64::from(interval_ms.min(MAX_INTERVAL_MS)))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn intervals_below_the_maximum_pass_through() {
        assert_eq!(clamp_interval(0), Duration::ZERO);
        assert_eq!(clamp_interval(80), Duration::from_millis(80));
        assert_eq!(
            clamp_interval(MAX_INTERVAL_MS),
            Duration::from_millis(u64::from(MAX_INTERVAL_MS))
        );
    }

    #[test]
    fn intervals_above_the_maximum_are_clamped() {
        assert_eq!(
            clamp_interval(u32::MAX),
            Duration::from_millis(u64::from(MAX_INTERVAL_MS))
        );
    }
}
