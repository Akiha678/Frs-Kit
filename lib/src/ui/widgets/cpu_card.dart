import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../state/home_state.dart';
import '../theme.dart';
import 'demo_card.dart';

class CpuCard extends StatelessWidget {
  const CpuCard({super.key});

  @override
  Widget build(BuildContext context) {
    final HomeState state = Get.find<HomeState>();

    return Obx(() {
      final int input = state.fibonacciInput.value;
      final BigInt? result = state.fibonacciResult.value;
      final Duration? elapsed = state.fibonacciElapsed.value;
      final bool isComputing = state.isComputing.value;
      final String? error = state.fibonacciError.value;

      return DemoCard(
        title: 'fibonacci',
        explanation:
            'CPU-bound work is pushed to the blocking pool, so it cannot starve '
            'other bridge calls. Results above F(93) overflow a u64 and are '
            'rejected in Rust.',
        trailing: isComputing
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
                    value: input.toDouble(),
                    min: 1,
                    max: 93,
                    divisions: 92,
                    label: '$input',
                    onChanged: isComputing
                        ? null
                        : (double value) =>
                              state.fibonacciInput.value = value.round(),
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: Text(
                    '$input',
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
              value: elapsed == null ? '—' : '${elapsed.inMilliseconds} ms',
            ),
            if (error case final String message) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: isComputing ? null : state.computeFibonacci,
              icon: const Icon(Icons.memory),
              label: const Text('Compute in Rust'),
            ),
          ],
        ),
      );
    });
  }
}
