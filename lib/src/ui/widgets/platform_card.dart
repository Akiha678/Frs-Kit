import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../rust/bridge.dart';
import '../../state/home_state.dart';
import '../../state/state_scope.dart';
import 'demo_card.dart';

/// Round-trip four: host facts read synchronously.
///
/// Every value here arrives without a `Future`, because nothing about the platform
/// can change while the app runs — so the whole card is filled in during the first
/// build.
///
/// The `dart` line is the useful one. Rust reports the OS its library was compiled
/// for, Dart reports the OS the app is running on, and in a correctly built app
/// the two agree. When they do not, the native library is stale: it was built for
/// a different target than the app being run, and every other panel would be
/// exercising the wrong binary.
class PlatformCard extends StatelessWidget {
  /// Creates the panel.
  const PlatformCard({super.key});

  /// What Dart thinks the current platform is.
  ///
  /// `defaultTargetPlatform` is used instead of `dart:io`'s `Platform`, which does
  /// not exist on the web and would break the web build outright.
  static String get _dartPlatform =>
      kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase();

  @override
  Widget build(BuildContext context) {
    final HomeState state = HomeStateScope.of(context);
    final PlatformSummary? summary = state.summary;

    if (summary == null) {
      return DemoCard(
        title: 'platform',
        explanation: 'Host facts, read synchronously from Rust.',
        child: Text(
          state.summaryError ?? 'Reading…',
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
          ValueLine(label: 'desktop', value: summary.isDesktop ? 'yes' : 'no'),
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
  }
}
