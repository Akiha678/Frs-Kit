import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../rust/bridge.dart';
import '../../state/home_state.dart';
import 'demo_card.dart';

/// 往返之四：同步读取宿主机信息。
///
/// 这里的每个值都不经过 `Future`，因为应用运行期间平台不会变 —— 所以
/// controller 的 `onInit` 跑完时，整张卡片就已经填好了。
///
/// 有用的是 `dart` 那一行。Rust 报告它的库是针对哪个系统编译的，Dart 报告
/// 应用跑在哪个系统上，构建正确的应用里两者一致。不一致时说明原生库过期了：
/// 它是为另一个 target 构建的，而其他每个面板都会因此跑到错误的二进制上。
class PlatformCard extends StatelessWidget {
  /// 创建面板。
  const PlatformCard({super.key});

  /// Dart 认为当前平台是什么。
  ///
  /// 这里用 `defaultTargetPlatform` 而不是 `dart:io` 的 `Platform`，后者在
  /// web 上不存在，会直接把 web 构建弄坏。
  static String get _dartPlatform =>
      kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase();

  @override
  Widget build(BuildContext context) {
    final HomeState state = Get.find<HomeState>();

    return Obx(() {
      // 在下面的分支之前读取，这样失败路径也会被订阅。
      final PlatformSummary? summary = state.summary.value;

      if (summary == null) {
        return DemoCard(
          title: 'platform',
          explanation: 'Host facts, read synchronously from Rust.',
          child: Text(
            state.summaryError.value ?? 'Reading…',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        );
      }

      final bool agrees = summary.name == _dartPlatform;

      return DemoCard(
        title: 'platform',
        explanation:
            'All four calls are #[frb(sync)]: nothing here can change at runtime, '
            'so there is nothing to await.',
        trailing: Chip(
          avatar: Icon(
            agrees ? Icons.check_circle_outline : Icons.report_problem_outlined,
            size: 16,
          ),
          label: Text(agrees ? 'library is current' : 'stale library?'),
          visualDensity: VisualDensity.compact,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ValueLine(label: 'rust', value: summary.name),
            const SizedBox(height: 4),
            ValueLine(label: 'dart', value: _dartPlatform),
            const SizedBox(height: 4),
            ValueLine(label: 'family', value: summary.family.name),
            const SizedBox(height: 4),
            ValueLine(
              label: 'desktop',
              value: summary.isDesktop ? 'yes' : 'no',
            ),
            const SizedBox(height: 4),
            ValueLine(
              label: 'data dir',
              value:
                  summary.dataDir ??
                  'not guessed on this platform — use path_provider',
            ),
            const SizedBox(height: 4),
            ValueLine(label: 'app id', value: state.appId),
          ],
        ),
      );
    });
  }
}
