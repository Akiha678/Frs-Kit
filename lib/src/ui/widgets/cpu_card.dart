import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../state/home_state.dart';
import '../theme.dart';
import 'demo_card.dart';

/// 往返之二的下半场：CPU 密集型工作，绝不能阻塞 runtime。
///
/// `fibonacci` 跑在 blocking pool 上而不是异步 runtime 上，这就是「一次慢调用」
/// 与「所有 bridge 调用都堵在它后面」的区别。上报的耗时让代价变得具体，而
/// `n = 93` 是 Rust 的 `u64` 刚好装不下的边界——再多一个，调用会失败而不是溢出。
class CpuCard extends StatelessWidget {
  /// 创建面板。
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
