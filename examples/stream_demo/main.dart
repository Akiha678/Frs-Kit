/// A Rust function that pushes values into Dart.
///
/// Run it with:
///
/// ```sh
/// flutter run -t examples/stream_demo/main.dart -d macos
/// ```
///
/// `countdown` in `rust/src/api/stream_demo.rs` takes a `StreamSink<u32>` and
/// becomes a plain Dart `Stream<int>`. Press Stop in the middle of a countdown:
/// that cancels the subscription, the next send from Rust fails, and the loop
/// returns instead of counting down for nobody.
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
  runApp(const StreamDemoExample());
}

/// A one-screen example app.
class StreamDemoExample extends StatefulWidget {
  /// Creates the example.
  const StreamDemoExample({super.key});

  @override
  State<StreamDemoExample> createState() => _StreamDemoExampleState();
}

class _StreamDemoExampleState extends State<StreamDemoExample> {
  static const GreetingRepository _greetings = GreetingRepository();

  final List<int> _values = <int>[];
  StreamSubscription<int>? _subscription;
  String? _error;

  /// Whether the stream is still open.
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
    // Cancelling is what tells Rust to stop pushing.
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
