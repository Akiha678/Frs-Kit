/// 本应用的身份信息。集中在一处，因为多个层都必须对它保持一致。
library;

/// 反向 DNS 格式的应用 id，用于给各应用数据划分命名空间。
///
/// `rust/src/api/platform.rs` 用它算出数据目录，例如
/// `~/Library/Application Support/com.example.frs_kit`。
///
/// 它目前与 Android 的 `applicationId` 一致，但要注意 iOS 和 macOS 在自己
/// 的 Xcode 工程里还带着各自的 `PRODUCT_BUNDLE_IDENTIFIER`（默认是
/// `com.example.frsKit`）。没有任何机制强制它们一致 —— 发布前请一起改名，否则
/// 应用会去一个以这个常量内容命名的目录里找数据。
const String kAppId = 'com.example.frs_kit';

/// 窗口标题和 app bar 使用的名称。
const String kAppName = 'frs_kit';
