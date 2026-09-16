/// 两种「慢」Rust 工作，并排摆在一起。
///
/// 这样运行：
///
/// ```sh
/// flutter run -t examples/async_demo/main.dart -d macos
/// ```
///
/// 左半边在 worker 线程上等（`delayed_hello`），右半边在 blocking pool 里烧
/// CPU（`fibonacci`）。两个都启动，看它们谁都不会挡住对方，也不会挡住 UI：
/// `rust/src/api/async_demo.rs` 解释了其中的原因。
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
  runApp(const AsyncDemoExample());
}

/// 单屏的示例应用。
class AsyncDemoExample extends StatefulWidget {
  /// 创建这个示例。
  const AsyncDemoExample({super.key});

  @override
  State<AsyncDemoExample> createState() => _AsyncDemoExampleState();
}

class _AsyncDemoExampleState extends State<AsyncDemoExample> {
  static const GreetingRepository _greetings = GreetingRepository();

  String? _delayedMessage;
  String? _delayedError;
  bool _isWaiting = false;

  int _n = 60;
  BigInt? _fibonacci;
  String? _fibonacciError;
  bool _isComputing = false;
  Duration? _elapsed;

  /// 调用挂起期间数到的定时器 tick 次数。
  ///
  /// 这就是 isolate 一直空闲的证据：被占住的 isolate 没法派发定时器回调，
  /// 那个数字就会停住。应用的 async 面板用的是同一个手法。
  int _ticks = 0;
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _runDelayed() async {
    setState(() {
      _isWaiting = true;
      _delayedError = null;
      _ticks = 0;
    });

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (mounted) setState(() => _ticks++);
    });

    try {
      final String message = await _greetings.delayedHello(
        name: 'Ada',
        delayMs: 1500,
      );
      if (!mounted) return;
      setState(() => _delayedMessage = message);
    } on BridgeFailure catch (failure) {
      if (!mounted) return;
      setState(() => _delayedError = failure.message);
    } finally {
      _ticker?.cancel();
      _ticker = null;
      if (mounted) setState(() => _isWaiting = false);
    }
  }

  Future<void> _runFibonacci() async {
    setState(() {
      _isComputing = true;
      _fibonacciError = null;
    });

    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      final BigInt value = await _greetings.fibonacci(_n);
      if (!mounted) return;
      setState(() {
        _fibonacci = value;
        _elapsed = stopwatch.elapsed;
      });
    } on BridgeFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _fibonacci = null;
        _fibonacciError = failure.message;
      });
    } finally {
      stopwatch.stop();
      if (mounted) setState(() => _isComputing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'async_demo',
      theme: frsKitTheme(Brightness.light),
      home: Scaffold(
        appBar: AppBar(title: const Text('async_demo')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: <Widget>[
                _Panel(
                  title: 'delayed_hello',
                  subtitle: 'A 1500 ms wait on a worker thread.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SelectableText(
                        _delayedError ?? _delayedMessage ?? 'not called yet',
                        style: _delayedError == null
                            ? kValueTextStyle
                            : kValueTextStyle.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                      ),
                      const SizedBox(height: 8),
                      Text('UI ticks while waiting: $_ticks'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _isWaiting ? null : _runDelayed,
                        child: Text(_isWaiting ? 'Waiting…' : 'Run'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Panel(
                  title: 'fibonacci',
                  subtitle: 'CPU-bound, moved to the blocking pool.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Wrap(
                        spacing: 8,
                        children: <Widget>[
                          for (final int candidate in <int>[30, 60, 93, 94])
                            ChoiceChip(
                              label: Text('n = $candidate'),
                              selected: _n == candidate,
                              onSelected: (_) => setState(() => _n = candidate),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SelectableText(
                        _fibonacciError ??
                            _fibonacci?.toString() ??
                            'not called yet',
                        style: _fibonacciError == null
                            ? kValueTextStyle
                            : kValueTextStyle.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _elapsed == null
                            ? 'n = 94 fails on purpose: it overflows a u64'
                            : 'took ${_elapsed!.inMilliseconds} ms',
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _isComputing ? null : _runFibonacci,
                        child: Text(_isComputing ? 'Computing…' : 'Run'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 带标题的盒子，留在示例内部，好让示例保持自包含。
class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: text.titleMedium),
            Text(subtitle, style: text.bodySmall),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
