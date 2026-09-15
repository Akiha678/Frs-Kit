/// Two kinds of "slow" Rust work, side by side.
///
/// Run it with:
///
/// ```sh
/// flutter run -t examples/async_demo/main.dart -d macos
/// ```
///
/// The left half waits on a worker thread (`delayed_hello`), the right half burns
/// CPU on the blocking pool (`fibonacci`). Start both and watch that neither one
/// stops the other, or the UI: `rust/src/api/async_demo.rs` explains why.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:frs_kit/src/data/failure.dart';
import 'package:frs_kit/src/data/greeting_repository.dart';
import 'package:frs_kit/src/rust/bridge.dart';
import 'package:frs_kit/src/ui/theme.dart';

/// Loads the native library before the first frame.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initRustBridge();
  runApp(const AsyncDemoExample());
}

/// A one-screen example app.
class AsyncDemoExample extends StatefulWidget {
  /// Creates the example.
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

  /// Timer ticks counted while a call is in flight.
  ///
  /// This is the evidence that the isolate stayed free: a blocked isolate cannot
  /// deliver timer callbacks, so the number would freeze. The same trick the app's
  /// async panel uses.
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

/// A titled box, kept local to the example so it stays self-contained.
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
