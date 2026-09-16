import 'package:get/get.dart';

import '../data/greeting_repository.dart';
import '../data/platform_repository.dart';
import 'home_state.dart';

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
