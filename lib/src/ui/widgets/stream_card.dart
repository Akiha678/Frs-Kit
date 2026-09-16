import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../state/home_state.dart';
import '../theme.dart';
import 'demo_card.dart';

/// 往返之三：Rust 的 `StreamSink` 以 Dart `Stream` 的形式出现。
///
/// 有意思的是 Start/Stop 这一对。停止并不是「把值藏起来」：它取消订阅，于是
/// Rust 下一次 `sink.add` 失败，worker 线程直接返回，而不是对着空气倒数。在
/// 倒数中途按 Stop，就是检验取消是否真的落到实处的办法。
class StreamCard extends StatelessWidget {
  /// 创建面板。
  const StreamCard({super.key});

  @override
  Widget build(BuildContext context) {
    final HomeState state = Get.find<HomeState>();

    return Obx(() {
      final bool isCounting = state.isCounting.value;
      final int from = state.countdownFrom.value;
      final int interval = state.intervalMs.value;
      final String? error = state.countdownError.value;
      // 在这里读取 RxList 会让这张卡片订阅 `add` 和 `clear`，所以 chips 会一个
      // 一个地出现，完全不需要手动刷新。
      final List<int> values = state.countdownValues;

      return DemoCard(
        title: 'countdown',
        explanation:
            'A Rust function that takes a StreamSink becomes a Dart Stream. Values '
            'are pushed from a worker thread; cancelling the subscription stops the '
            'Rust loop.',
        trailing: isCounting
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
                    value: from.toDouble(),
                    min: 1,
                    max: 20,
                    divisions: 19,
                    label: '$from',
                    onChanged: isCounting
                        ? null
                        : (double value) =>
                              state.countdownFrom.value = value.round(),
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: Text(
                    '$from',
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
                    value: interval.toDouble(),
                    min: 50,
                    max: 1000,
                    divisions: 19,
                    label: '$interval ms',
                    onChanged: isCounting
                        ? null
                        : (double value) =>
                              state.intervalMs.value = value.round(),
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: Text(
                    '$interval ms',
                    textAlign: TextAlign.end,
                    style: kValueTextStyle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: values.isEmpty
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
                          for (final int value in values)
                            Chip(
                              label: Text('$value'),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    ),
            ),
            if (error case final String message) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                message,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                FilledButton.tonalIcon(
                  onPressed: isCounting ? null : state.startCountdown,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: isCounting ? state.stopCountdown : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }
}
