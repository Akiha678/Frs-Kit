import '../rust/bridge.dart' as rust;

/// Facts about the host, as seen from the Rust half of the app.
///
/// Every call here is synchronous. Compiling the platform into the library is
/// not something a function can change at runtime, so there is nothing to await;
/// making the UI wait a microtask for a constant would be pure overhead. That
/// also means these calls cannot throw [FrbException]s — there is no `Result` on
/// the Rust side to fail.
///
/// They do still require [initRustBridge] to have completed: before that, even a
/// synchronous call has nothing to talk to.
class PlatformRepository {
  /// Creates a repository. Stateless, hence `const`.
  const PlatformRepository();

  /// Everything the UI wants to show about the host, in one call.
  ///
  /// [appId] namespaces the data directory, normally with the application id.
  rust.PlatformSummary summary(String appId) =>
      rust.platformSummary(appId: appId);

  /// Operating system the *native library* was compiled for.
  ///
  /// Compare with `Platform.operatingSystem` from `dart:io`: the two agree in a
  /// correctly built app, and a mismatch is the fastest way to spot a stale
  /// native library.
  String name() => rust.platformName();

  /// Coarse group [name] belongs to.
  rust.PlatformFamily family() => rust.platformFamily();

  /// Whether the app runs on Linux, macOS or Windows.
  bool isDesktop() => rust.isDesktop();

  /// Best-effort data directory for [appId], or `null` when Rust has no answer
  /// (iOS and the web build, most notably).
  String? dataDir(String appId) => rust.defaultDataDir(appId: appId);
}
