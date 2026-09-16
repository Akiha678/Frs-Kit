import 'package:flutter/material.dart';

import '../app_info.dart';
import 'theme.dart';

/// 原生库加载失败时用它替代应用显示。
///
/// 另一种做法是白窗口加上控制台里的堆栈 —— 对没写过脚手架的人来说，缺一次
/// `cargo build` 看起来就是这样。这里把这个失败变成读者需要的两件事：出了什么问题，
/// 以及修好它的命令。
///
/// 它刻意不依赖任何东西：即使关于 bridge 的一切都还不可知，它也必须能渲染出来。
class RustUnavailableApp extends StatelessWidget {
  /// 为 [error] 创建失败界面。
  const RustUnavailableApp({required this.error, this.stackTrace, super.key});

  /// `RustLib.init()` 抛出的东西。
  final Object error;

  /// 抛出位置，折叠显示在信息下方。
  final StackTrace? stackTrace;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: frsKitTheme(Brightness.light),
      darkTheme: frsKitTheme(Brightness.dark),
      home: Scaffold(
        appBar: AppBar(title: const Text('$kAppName — native library missing')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(24),
              shrinkWrap: true,
              children: <Widget>[
                Text(
                  'The Rust library could not be loaded',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const Text(
                  'This app is half Rust, and that half is built separately from '
                  'the Dart code. Build it, then restart:',
                ),
                const SizedBox(height: 12),
                const SelectableText(
                  'just build\n# or, equivalently:\n'
                  'cargo build --release --manifest-path rust/Cargo.toml',
                  style: kValueTextStyle,
                ),
                const SizedBox(height: 24),
                Text(
                  'Reported by the loader',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                SelectableText('$error', style: kValueTextStyle),
                if (stackTrace case final StackTrace stack) ...<Widget>[
                  const SizedBox(height: 16),
                  ExpansionTile(
                    title: const Text('Stack trace'),
                    childrenPadding: const EdgeInsets.all(8),
                    children: <Widget>[
                      SelectableText('$stack', style: kValueTextStyle),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
