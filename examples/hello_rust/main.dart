/// The smallest complete example: one synchronous call and one asynchronous call.
///
/// Run it with:
///
/// ```sh
/// flutter run -t examples/hello_rust/main.dart -d macos
/// ```
///
/// It reaches `rust/src/api/hello.rs` through the same data layer the app uses
/// (`lib/src/data/greeting_repository.dart`), so the only thing this file adds is a
/// UI. Compare the two lines at the bottom of the screen: the first is recomputed
/// on every keystroke because `hello` is `#[frb(sync)]`, the second only changes
/// when the button is pressed because `greet` returns a `Future`.
library;

import 'package:flutter/material.dart';
import 'package:frs_kit/src/data/failure.dart';
import 'package:frs_kit/src/data/greeting_repository.dart';
import 'package:frs_kit/src/rust/bridge.dart';
import 'package:frs_kit/src/ui/theme.dart';

/// Loads the native library before the first frame.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initRustBridge();
  runApp(const HelloRustExample());
}

/// A one-screen example app.
class HelloRustExample extends StatefulWidget {
  /// Creates the example.
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
      // Expected for a blank or over-long name: the domain layer in Rust rejects
      // it, and the message travels back unchanged.
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
                  // Rebuilds the synchronous line as you type.
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
                // No Future, no await: the value is already there.
                SelectableText(_greetings.hello(_name.text), style: kValueTextStyle),
                const SizedBox(height: 16),
                Text('async', style: theme.textTheme.labelMedium),
                SelectableText(
                  _greeting?.message ?? 'not called yet',
                  style: kValueTextStyle,
                ),
                if (_error case final String message) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(message, style: TextStyle(color: theme.colorScheme.error)),
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
