/// 最小的完整示例：一次同步调用，一次异步调用。
///
/// 这样运行：
///
/// ```sh
/// flutter run -t examples/hello_rust/main.dart -d macos
/// ```
///
/// 它经由应用用的那层数据层（`lib/src/data/greeting_repository.dart`）够到
/// `rust/src/api/hello.rs`，所以这个文件唯一多出来的东西就是一个 UI。对比屏幕
/// 底下那两行：第一行每敲一个键就重算，因为 `hello` 是 `#[frb(sync)]`；第二行
/// 只在按钮被按下时才变，因为 `greet` 返回 `Future`。
library;

import 'package:flutter/material.dart';
import 'package:frs_kit/src/data/failure.dart';
import 'package:frs_kit/src/data/greeting_repository.dart';
import 'package:frs_kit/src/rust/bridge.dart';
import 'package:frs_kit/src/ui/theme.dart';

/// 在第一帧之前加载原生库。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initRustBridge();
  runApp(const HelloRustExample());
}

/// 单屏的示例应用。
class HelloRustExample extends StatefulWidget {
  /// 创建这个示例。
  const HelloRustExample({super.key});

  @override
  State<HelloRustExample> createState() => _HelloRustExampleState();
}

class _HelloRustExampleState extends State<HelloRustExample> {
  static const GreetingRepository _greetings = GreetingRepository();

  final TextEditingController _name = TextEditingController(text: 'Ada');
  GreetingStyle _style = GreetingStyle.plain;
  Greeting? _greeting;
  String? _error;
  bool _isLoading = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _greet() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final Greeting greeting = await _greetings.greet(
        name: _name.text,
        style: _style,
      );
      setState(() => _greeting = greeting);
    } on BridgeFailure catch (failure) {
      // 名字为空或过长时属于预期情况：Rust 里的 domain 层会拒绝它，
      // 而消息会原样传回来。
      setState(() {
        _greeting = null;
        _error = failure.message;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return MaterialApp(
      title: 'hello_rust',
      theme: frsKitTheme(Brightness.light),
      home: Scaffold(
        appBar: AppBar(title: const Text('hello_rust')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: <Widget>[
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Name'),
                  // 输入时重建同步那一行。
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: <Widget>[
                    for (final GreetingStyle style in GreetingStyle.values)
                      ChoiceChip(
                        label: Text(style.name),
                        selected: _style == style,
                        onSelected: (_) => setState(() => _style = style),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Text('sync', style: theme.textTheme.labelMedium),
                // 没有 Future，也不用 await：值已经在这儿了。
                SelectableText(
                  _greetings.hello(_name.text),
                  style: kValueTextStyle,
                ),
                const SizedBox(height: 16),
                Text('async', style: theme.textTheme.labelMedium),
                SelectableText(
                  _greeting?.message ?? 'not called yet',
                  style: kValueTextStyle,
                ),
                if (_error case final String message) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    message,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isLoading ? null : _greet,
                  child: _isLoading
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Call greet() in Rust'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
