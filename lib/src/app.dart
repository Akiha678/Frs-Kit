import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app_info.dart';
import 'data/greeting_repository.dart';
import 'data/platform_repository.dart';
import 'state/home_binding.dart';
import 'ui/home_page.dart';
import 'ui/theme.dart';

/// 应用根节点。
///
/// 这里刻意用 [StatelessWidget]。在 GetX 里 controller 的生命周期属于容器，
/// 而不属于某个 widget：[HomeBinding] 注册 repository 和 `HomeState`，
/// `GetMaterialApp` 在首次构建之前跑完这个 binding。于是没有东西需要在
/// `initState` 里创建、在 `dispose` 里释放，或者沿 widget 树往下传递。
///
/// repository 保持可注入只有一个原因：widget 测试加载不了原生库，于是测试可以
/// 传入假实现，同时仍然跑真实的 widget、真实的状态机和真实的错误处理。
class FrsKitApp extends StatelessWidget {
  /// 创建应用。
  ///
  /// 两个 repository 都默认使用由 bridge 支撑的真实实现。
  const FrsKitApp({
    this.greetings,
    this.platform,
    this.appId = kAppId,
    super.key,
  });

  /// 覆盖 greeting repository，供测试使用。
  final GreetingRepository? greetings;

  /// 覆盖 platform repository，供测试使用。
  final PlatformRepository? platform;

  /// 用于给各应用数据划分命名空间的应用 id。
  final String appId;

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: frsKitTheme(Brightness.light),
      darkTheme: frsKitTheme(Brightness.dark),
      // `initialBinding` 在第一条路由构建之前运行，下面每个面板里的
      // `Get.find<HomeState>()` 之所以安全，靠的就是它。
      initialBinding: HomeBinding(
        greetings: greetings,
        platform: platform,
        appId: appId,
      ),
      home: const HomePage(),
    );
  }
}
