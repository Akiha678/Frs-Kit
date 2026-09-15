import 'package:flutter/material.dart';

import '../../state/home_state.dart';
import '../../state/state_scope.dart';
import '../theme.dart';
import 'demo_card.dart';

/// Round-trip three: a Rust `StreamSink` surfacing as a Dart `Stream`.
///
/// The Start/Stop pair is the interesting part. Stopping is not "hide the
/// values": it cancels the subscription, Rust's next `sink.add` fails, and the
/// worker thread returns instead of counting down into the void. Pressing Stop
/// mid-countdown is how you check that the cancellation really lands.
class StreamCard extends StatelessWidget {
  /// Creates the panel.
  const StreamCard({super.key});

  @override
  Widget build(BuildContext context) {
    final HomeState state = HomeStateScope.of(context);

    return DemoCard(
      title: 'countdown',
      explanation:
          'A Rust function that takes a StreamSink becomes a Dart Stream. Values '
          'are pushed from a worker thread; cancelling the subscription stops the '
          'Rust loop.',
      trailing: state.isCounting
          ? const Chip(
              avatar: SizedBox.square(
                dimension: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              label: Text('streaming'),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const SizedBox(width: 72, child: Text('count')),
              Expanded(
                child: Slider(
                  value: state.countdownFrom.toDouble(),
                  min: 1,
                  max: 20,
                  divisions: 19,
                  label: '${state.countdownFrom}',
                  onChanged: state.isCounting
                      ? null
                      : (double value) => state.setCountdownFrom(value.round()),
                ),
              ),
              SizedBox(
                width: 64,
                child: Text(
                  '${state.countdownFrom}',
                  textAlign: TextAlign.end,
                  style: kValueTextStyle,
                ),
              ),
            ],
          ),
          Row(
            children: <Widget>[
              const SizedBox(width: 72, child: Text('every')),
              Expanded(
                child: Slider(
                  value: state.intervalMs.toDouble(),
                  min: 50,
                  max: 1000,
                  divisions: 19,
                  label: '${state.intervalMs} ms',
                  onChanged: state.isCounting
                      ? null
                      : (double value) => state.setIntervalMs(value.round()),
                ),
              ),
              SizedBox(
                width: 64,
                child: Text(
                  '${state.intervalMs} ms',
                  textAlign: TextAlign.end,
                  style: kValueTextStyle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: state.countdownValues.isEmpty
                ? const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('no values yet'),
                  )
                : Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        for (final int value in state.countdownValues)
                          Chip(
                            label: Text('$value'),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ),
          ),
          if (state.countdownError case final String error) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              FilledButton.tonalIcon(
                onPressed: state.isCounting ? null : state.startCountdown,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: state.isCounting ? state.stopCountdown : null,
                icon: const Icon(Icons.stop),
                label: const Text('Stop'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
