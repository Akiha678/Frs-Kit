import 'package:flutter/widgets.dart';

import 'home_state.dart';

/// Makes a [HomeState] available to the widgets below it and rebuilds them when
/// it changes.
///
/// An `InheritedNotifier` is the smallest thing that does the job: it subscribes
/// to the notifier once and rebuilds only the widgets that asked for it, so no
/// package is needed at this size.
///
/// Two accessors, mirroring the `watch`/`read` split everyone expects:
///
/// * [HomeStateScope.of] subscribes — use it in `build`;
/// * [HomeStateScope.read] does not — use it in callbacks such as `onPressed`.
class HomeStateScope extends InheritedNotifier<HomeState> {
  /// Wraps [child] with [notifier].
  const HomeStateScope({
    required HomeState super.notifier,
    required super.child,
    super.key,
  });

  /// The state, rebuilding the caller whenever it changes.
  ///
  /// Throws a [FlutterError] when there is no scope above [context], because that
  /// is always a wiring mistake rather than a runtime condition.
  static HomeState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<HomeStateScope>();
    if (scope == null) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('HomeStateScope.of() found no HomeStateScope.'),
        ErrorDescription(
          'The widget calling this is not below a HomeStateScope. Wrap the app '
          '(or the subtree under test) in a HomeStateScope.',
        ),
        context.describeElement('The context used was'),
      ]);
    }
    return scope.notifier!;
  }

  /// The state without subscribing to changes.
  ///
  /// Calling `of` from a callback would subscribe for nothing and can rebuild
  /// widgets that never read the value.
  static HomeState read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<HomeStateScope>();
    assert(scope != null, 'HomeStateScope.read() found no HomeStateScope.');
    return scope!.notifier!;
  }
}
