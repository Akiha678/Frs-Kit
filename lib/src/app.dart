import 'package:flutter/material.dart';

import 'app_info.dart';
import 'data/greeting_repository.dart';
import 'data/platform_repository.dart';
import 'state/home_state.dart';
import 'state/state_scope.dart';
import 'ui/home_page.dart';
import 'ui/theme.dart';

/// The application root.
///
/// It owns exactly one thing — the [HomeState] and its lifetime — and hands it to
/// the rest of the tree through a [HomeStateScope]. Everything below reads that
/// scope, so no widget needs a constructor parameter threaded through it.
///
/// The repositories are injectable for one reason: a widget test cannot load a
/// native library, so tests pass fakes and still exercise the real widgets, the
/// real state machine and the real error handling.
class FrsKitApp extends StatefulWidget {
  /// Creates the app.
  ///
  /// Both repositories default to the real, bridge-backed implementations.
  const FrsKitApp({
    this.greetings,
    this.platform,
    this.appId = kAppId,
    super.key,
  });

  /// Overrides the greeting repository, for tests.
  final GreetingRepository? greetings;

  /// Overrides the platform repository, for tests.
  final PlatformRepository? platform;

  /// Application id used to namespace per-app data.
  final String appId;

  @override
  State<FrsKitApp> createState() => _FrsKitAppState();
}

class _FrsKitAppState extends State<FrsKitApp> {
  late final HomeState _state = HomeState(
    greetings: widget.greetings,
    platform: widget.platform,
    appId: widget.appId,
  );

  @override
  void initState() {
    super.initState();
    // Synchronous and cheap, so it can run before the first frame: doing it here
    // rather than in a post-frame callback means the first build already shows the
    // host facts.
    _state.loadSummary();
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HomeStateScope(
      notifier: _state,
      child: MaterialApp(
        title: kAppName,
        debugShowCheckedModeBanner: false,
        theme: frsKitTheme(Brightness.light),
        darkTheme: frsKitTheme(Brightness.dark),
        home: const HomePage(),
      ),
    );
  }
}
