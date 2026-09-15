import 'package:flutter/material.dart';

import '../../state/home_state.dart';
import '../../state/state_scope.dart';
import '../theme.dart';
import 'demo_card.dart';

/// Round-trip two, part two: CPU-bound work that must not block the runtime.
///
/// `fibonacci` runs on the blocking pool rather than on the async runtime, which
/// is the difference between one slow call and every bridge call stalling behind
/// it. The reported duration makes the cost concrete, and `n = 93` is the boundary
/// where Rust's `u64` stops fitting — try one more and the call fails instead of
/// overflowing.
class CpuCard extends StatelessWidget {
  /// Creates the panel.
  const CpuCard({super.key});

  @override
  Widget build(BuildContext context) {
    final HomeState state = HomeStateScope.of(context);
    final BigInt? result = state.fibonacciResult;

    return DemoCard(
      title: 'fibonacci',
      explanation:
          'CPU-bound work is pushed to the blocking pool, so it cannot starve '
          'other bridge calls. Results above F(93) overflow a u64 and are '
          'rejected in Rust.',
      trailing: state.isComputing
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const SizedBox(width: 72, child: Text('n')),
              Expanded(
                child: Slider(
                  value: state.fibonacciInput.toDouble(),
                  min: 1,
                  max: 93,
                  divisions: 92,
                  label: '${state.fibonacciInput}',
                  onChanged: state.isComputing
                      ? null
                      : (double value) =>
                            state.setFibonacciInput(value.round()),
                ),
              ),
              SizedBox(
                width: 64,
                child: Text(
                  '${state.fibonacciInput}',
                  textAlign: TextAlign.end,
                  style: kValueTextStyle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ValueLine(label: 'F(n)', value: result?.toString() ?? '—'),
          const SizedBox(height: 4),
          ValueLine(
            label: 'took',
            value: state.fibonacciElapsed == null
                ? '—'
                : '${state.fibonacciElapsed!.inMilliseconds} ms',
          ),
          if (state.fibonacciError case final String error) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: state.isComputing ? null : state.computeFibonacci,
            icon: const Icon(Icons.memory),
            label: const Text('Compute in Rust'),
          ),
        ],
      ),
    );
  }
}
