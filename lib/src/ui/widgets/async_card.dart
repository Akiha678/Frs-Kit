import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../state/home_state.dart';
import '../theme.dart';
import 'demo_card.dart';

class AsyncCard extends StatelessWidget {
  const AsyncCard({super.key});

  @override
  Widget build(BuildContext context) {
    final HomeState state = Get.find<HomeState>();

    return Obx(() {
      final int delay = state.delayMs.value;
      final bool isRunning = state.isDelayedRunning.value;
      final String? error = state.delayedError.value;

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
                    value: delay.toDouble(),
                    min: 100,
                    max: 3000,
                    divisions: 29,
                    label: '$delay ms',
                    onChanged: isRunning
                        ? null
                        : (double value) => state.delayMs.value = value.round(),
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: Text(
                    '$delay ms',
                    textAlign: TextAlign.end,
                    style: kValueTextStyle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ValueLine(label: 'ticks', value: '${state.busyTicks.value}'),
            const SizedBox(height: 4),
            ValueLine(
              label: 'result',
              value: state.delayedMessage.value ?? '—',
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
              onPressed: isRunning ? null : state.runDelayedHello,
              icon: isRunning
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.hourglass_bottom),
              label: Text(isRunning ? 'Waiting…' : 'Run delayed call'),
            ),
          ],
        ),
      );
    });
  }
}
