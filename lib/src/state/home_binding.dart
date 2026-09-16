import 'package:get/get.dart';

import '../data/greeting_repository.dart';
import '../data/platform_repository.dart';
import 'home_state.dart';

/// 按依赖顺序注册首页需要的一切。
///
/// GetX 从唯一的全局容器里解析依赖，所以「有什么」由这里说了算。它取代了脚手架
/// 原先一路携带的 `InheritedNotifier` 作用域：widget 不再沿树向上找状态，而是
/// 问 `Get.find` —— 这也意味着回调里不用 `BuildContext` 就能拿到 controller。
///
/// 有两个刻意的选择：
///
/// * 用 `lazyPut` 而不是 `put` —— 没人要就不构造。一条从不渲染这些面板的
///   路由不花任何代价。
/// * `fenix: true` —— 使用懒加载实例的路由出栈时，GetX 会删掉这些实例。
///   没有 `fenix`，再回到这个页面只会拿到一个已删除的 controller；有了
///   它，GetX 会在下一次 `find` 时重建同一份注册。
///
/// [greetings] 和 [platform] 是为测试存在的：传入假实现，注册的就是它们，
/// 而不是真实的、由 bridge 支撑的 repository，于是整棵 widget 树都能在没有
/// 原生库的情况下被跑通。`null` 表示「注册真实实现」。
class HomeBinding extends Bindings {
  /// 创建 binding。
  ///
  /// 不是 `const`：`Bindings` 本身就不能 const 构造，所以这里的参数由 GetX 每次
  /// 启动应用时构建的那个实例捕获。
  HomeBinding({this.greetings, this.platform, this.appId});

  /// 覆盖 greeting repository。
  final GreetingRepository? greetings;

  /// 覆盖 platform repository。
  final PlatformRepository? platform;

  /// 传给 [HomeState] 的应用 id；`null` 则用它的默认值。
  final String? appId;

  @override
  void dependencies() {
    Get.lazyPut<GreetingRepository>(
      () => greetings ?? const GreetingRepository(),
      fenix: true,
    );
    Get.lazyPut<PlatformRepository>(
      () => platform ?? const PlatformRepository(),
      fenix: true,
    );
    Get.lazyPut<HomeState>(
      () => appId == null ? HomeState() : HomeState(appId: appId!),
      fenix: true,
    );
  }
}
