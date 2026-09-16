import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app_info.dart';
import '../state/home_state.dart';
import 'widgets/async_card.dart';
import 'widgets/cpu_card.dart';
import 'widgets/greeting_card.dart';
import 'widgets/platform_card.dart';
import 'widgets/stream_card.dart';

/// 首页：Dart 与 Rust 之间的每一次往返对应一个面板。
///
/// 页面本身不持有状态，也不订阅任何东西。每个面板自己从 Get 容器取出 controller，
/// 并用 `Obx` 包住会变化的部分，因此某个面板的状态变化不会重建另外三个。
class HomePage extends StatelessWidget {
  /// 创建页面。
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(kAppName),
        actions: <Widget>[
          IconButton(
            tooltip: 'Re-read host facts from Rust',
            // 不需要 `BuildContext`：controller 是通过容器拿到的，这也是这类回调
            // 比用 InheritedWidget 时更短的原因。
            onPressed: () => Get.find<HomeState>().loadSummary(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            // 行太长不好读，而手机宽度的栏位可以避免桌面窗口把面板拉得横跨全屏。
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: const <Widget>[
                PlatformCard(),
                SizedBox(height: 12),
                GreetingCard(),
                SizedBox(height: 12),
                AsyncCard(),
                SizedBox(height: 12),
                StreamCard(),
                SizedBox(height: 12),
                CpuCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
