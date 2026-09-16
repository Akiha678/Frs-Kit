/// 一个往 Dart 里推值的 Rust 函数。
///
/// 这样运行：
///
/// ```sh
/// flutter run -t examples/stream_demo/main.dart -d macos
/// ```
///
/// `rust/src/api/stream_demo.rs` 里的 `countdown` 接收一个 `StreamSink<u32>`，
/// 变成一个普通的 Dart `Stream<int>`。倒数中途按 Stop：那会取消订阅，Rust
/// 下一次 send 就会失败，于是循环直接返回，而不是为一个没人听的倒数继续数
/// 下去。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:frs_kit/src/data/failure.dart';
import 'package:frs_kit/src/data/greeting_repository.dart';
import 'package:frs_kit/src/rust/bridge.dart';
import 'package:frs_kit/src/ui/theme.dart';

/// 在第一帧之前加载原生库。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initRustBridge();
  runApp(const StreamDemoExample());
}

/// 单屏的示例应用。
class StreamDemoExample extends StatefulWidget {
  /// 创建这个示例。
  const StreamDemoExample({super.key});

  @override
  State<StreamDemoExample> createState() => _StreamDemoExampleState();
}

class _StreamDemoExampleState extends State<StreamDemoExample> {
  static const GreetingRepository _greetings = GreetingRepository();

  final List<int> _values = <int>[];
  StreamSubscription<int>? _subscription;
  String? _error;

  /// 流是否仍然开着。
  bool get _isRunning => _subscription != null;

  void _start() {
    setState(() {
      _values.clear();
      _error = null;
    });

    _subscription = _greetings
        .countdown(count: 8, intervalMs: 400)
        .listen(
          (int value) => setState(() => _values.add(value)),
          onError: (Object error) => setState(() {
            _error = BridgeFailure.from(error).message;
            _subscription = null;
          }),
          onDone: () => setState(() => _subscription = null),
          cancelOnError: true,
        );
    setState(() {});
  }

  Future<void> _stop() async {
    final StreamSubscription<int>? subscription = _subscription;
    setState(() => _subscription = null);
    // 正是「取消」这一步在告诉 Rust 别再推了。
    await subscription?.cancel();
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return MaterialApp(
      title: 'stream_demo',
      theme: frsKitTheme(Brightness.light),
      home: Scaffold(
        appBar: AppBar(title: const Text('stream_demo')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: <Widget>[
                Text(
                  'countdown(count: 8, intervalMs: 400)',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                if (_error case final String message)
                  Text(message, style: TextStyle(color: theme.colorScheme.error))
                else if (_values.isEmpty)
                  const Text('no values yet')
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final int value in _values)
                        Chip(
                          label: Text('$value', style: kValueTextStyle),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                const SizedBox(height: 24),
                Row(
                  children: <Widget>[
                    FilledButton(
                      onPressed: _isRunning ? null : _start,
                      child: const Text('Start'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: _isRunning ? _stop : null,
                      child: const Text('Stop'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  _isRunning
                      ? 'Stream open. Stop cancels the subscription; Rust notices '
                            'on its next send and returns.'
                      : 'Stream closed. Start again to open a new one.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
