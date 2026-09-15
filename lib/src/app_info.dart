/// Identity of this application, kept in one place because several layers need
/// to agree on it.
library;

/// Reverse-DNS application id, used to namespace per-app data.
///
/// `rust/src/api/platform.rs` turns this into a data directory such as
/// `~/Library/Application Support/com.example.frs_kit`.
///
/// It currently matches Android's `applicationId`, but note that iOS and macOS
/// carry their own `PRODUCT_BUNDLE_IDENTIFIER` (`com.example.frsKit` by default)
/// in their Xcode projects. Nothing enforces agreement — rename all of them
/// together before shipping, or the app will look for its data in a directory
/// named after whatever this constant says.
const String kAppId = 'com.example.frs_kit';

/// Name used for the window title and the app bar.
const String kAppName = 'frs_kit';
