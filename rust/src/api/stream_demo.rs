//! Round-trip three: a `Stream` that Rust pushes into.
//!
//! A function that takes a [`StreamSink`] argument returns a Dart `Stream`
//! instead of a `Future`. flutter_rust_bridge runs the body on a worker thread
//! (`FfiCallMode::Normal` spawns; only `#[frb(sync)]` would run inline), which is
//! why the sleeps below cannot stutter the UI.

use std::time::Duration;

use anyhow::Result;

use crate::frb_generated::StreamSink;

/// Longest interval between two emissions, in milliseconds.
const MAX_INTERVAL_MS: u32 = 2_000;

/// Counts down from `count` to `1`, one value per `interval_ms`, then closes.
///
/// Dart signature: `Stream<int> countdown({required int count, required int
/// intervalMs})`. Values above [`MAX_INTERVAL_MS`] are clamped, so a UI slider
/// cannot make the stream crawl for minutes.
///
/// Returning `Ok(())` closes the stream normally. To fail it instead, send
/// `sink.add_error(...)` and still return `Ok(())`, or return `Err(...)` — either
/// way Dart sees an error event rather than a silent stop.
///
/// # Cancellation
///
/// When Dart cancels the subscription (a disposed widget, a rebuilt `FutureBuilder`
/// with a new key), the next `add` fails. Breaking out of the loop on that failure
/// is what keeps a cancelled `Stream` from holding a worker thread until it would
/// have finished on its own.
pub fn countdown(count: u32, interval_ms: u32, sink: StreamSink<u32>) -> Result<()> {
    let interval = clamp_interval(interval_ms);

    for remaining in (1..=count).rev() {
        if sink.add(remaining).is_err() {
            break; // The Dart side stopped listening.
        }
        std::thread::sleep(interval);
    }

    Ok(())
}

/// Clamps a requested interval to what [`countdown`] will honour.
///
/// Pulled out of the function so the rule can be tested directly: `countdown` needs
/// a `StreamSink`, which only the bridge can build.
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
