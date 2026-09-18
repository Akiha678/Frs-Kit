import '../rust/bridge.dart' as rust;

class PlatformRepository {
  const PlatformRepository();

  rust.PlatformSummary summary(String appId) =>
      rust.platformSummary(appId: appId);

  String name() => rust.platformName();

  rust.PlatformFamily family() => rust.platformFamily();

  bool isDesktop() => rust.isDesktop();

  String? dataDir(String appId) => rust.defaultDataDir(appId: appId);
}
