import 'package:flutter/material.dart';

import '../app_info.dart';
import '../state/state_scope.dart';
import 'widgets/async_card.dart';
import 'widgets/cpu_card.dart';
import 'widgets/greeting_card.dart';
import 'widgets/platform_card.dart';
import 'widgets/stream_card.dart';

/// The home page: one panel per round-trip between Dart and Rust.
///
/// The page itself holds no state. It reads [HomeState] from the scope above it
/// and rebuilds when that notifier fires, which keeps the layout declarative and
/// makes the whole page testable with fake repositories.
class HomePage extends StatelessWidget {
  /// Creates the page.
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(kAppName),
        actions: <Widget>[
          IconButton(
            tooltip: 'Re-read host facts from Rust',
            onPressed: () => HomeStateScope.read(context).loadSummary(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            // Long lines are hard to read, and a phone-sized column keeps the
            // desktop window from stretching the panels across the screen.
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
