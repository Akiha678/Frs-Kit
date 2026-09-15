import 'package:flutter/material.dart';

import '../../state/home_state.dart';
import '../../state/state_scope.dart';
import '../theme.dart';
import 'demo_card.dart';

/// Round-trip two: an `async fn` in Rust behind a Dart `Future`.
///
/// The panel is built to make one claim checkable: while Rust sleeps, Flutter
/// keeps painting. The tick counter advances every
/// [HomeState.busyTickInterval] for exactly as long as the future is pending, so
/// a number close to `delay / 50` is evidence that nothing was blocked.
class AsyncCard extends StatelessWidget {
  /// Creates the panel.
  const AsyncCard({super.key});

  @override
  Widget build(BuildContext context) {
    final HomeState state = HomeStateScope.of(context);

    return DemoCard(
      title: 'delayed_hello',
      explanation:
          'An async Rust fn. The wait happens on a worker thread, so the UI '
          'isolate stays free: the tick counter keeps moving while it runs.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const SizedBox(width: 72, child: Text('delay')),
              Expanded(
                child: Slider(
                  value: state.delayMs.toDouble(),
                  min: 100,
                  max: 3000,
                  divisions: 29,
                  label: '${state.delayMs} ms',
                  onChanged: state.isDelayedRunning
                      ? null
                      : (double value) => state.setDelayMs(value.round()),
                ),
              ),
              SizedBox(
                width: 64,
                child: Text(
                  '${state.delayMs} ms',
                  textAlign: TextAlign.end,
                  style: kValueTextStyle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ValueLine(label: 'ticks', value: '${state.busyTicks}'),
          const SizedBox(height: 4),
          ValueLine(label: 'result', value: state.delayedMessage ?? '—'),
          if (state.delayedError case final String error) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: state.isDelayedRunning ? null : state.runDelayedHello,
            icon: state.isDelayedRunning
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.hourglass_bottom),
            label: Text(
              state.isDelayedRunning ? 'Waiting…' : 'Run delayed call',
            ),
          ),
        ],
      ),
    );
  }
}
