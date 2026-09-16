import '../rust/bridge.dart' as rust;

/// 关于宿主机的事实，视角来自应用里 Rust 的那一半。
///
/// 这里每个调用都是同步的。平台在编译期就进了库，函数无法在运行时改变它，所以没有
/// 什么可等待的；为了一个常量让 UI 等一个微任务纯属浪费。这也意味着这些调用不会抛出
/// [FrbException] —— Rust 侧没有会失败的 `Result`。
///
/// 但它们仍然要求 [initRustBridge] 已经完成：在那之前，哪怕是同步调用也无话可谈。
class PlatformRepository {
  /// 创建 repository。无状态，所以是 `const`。
  const PlatformRepository();

  /// UI 想展示的宿主机信息，一次调用全部拿到。
  ///
  /// [appId] 用于给数据目录划分命名空间，通常传入应用 id。
  rust.PlatformSummary summary(String appId) =>
      rust.platformSummary(appId: appId);

  /// *原生库*编译时所针对的操作系统。
  ///
  /// 与 `dart:io` 的 `Platform.operatingSystem` 对比：构建正确的应用里两者一致，
  /// 不一致则是发现原生库过期的最快办法。
  String name() => rust.platformName();

  /// [name] 所属的粗略分类。
  rust.PlatformFamily family() => rust.platformFamily();

  /// 应用是否运行在 Linux、macOS 或 Windows 上。
  bool isDesktop() => rust.isDesktop();

  /// [appId] 的尽力而为的数据目录；Rust 无从作答时为 `null`（最典型的是 iOS 和
  /// web 构建）。
  String? dataDir(String appId) => rust.defaultDataDir(appId: appId);
}
