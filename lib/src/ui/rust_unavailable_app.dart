import 'package:flutter/material.dart';

import '../app_info.dart';
import 'theme.dart';

/// Shown instead of the app when the native library could not be loaded.
///
/// The alternative is a blank window and a stack trace in the console — which is
/// what a missing `cargo build` looks like to anyone who did not write the
/// scaffold. This turns that failure into the two things a reader needs: what went
/// wrong, and the command that fixes it.
///
/// It is deliberately dependency-free: it must render even though nothing about
/// the bridge is known to work.
class RustUnavailableApp extends StatelessWidget {
  /// Creates the failure screen for [error].
  const RustUnavailableApp({required this.error, this.stackTrace, super.key});

  /// What `RustLib.init()` threw.
  final Object error;

  /// Where it was thrown, shown collapsed below the message.
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
