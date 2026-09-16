import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../rust/bridge.dart';
import '../../state/home_state.dart';
import 'demo_card.dart';

/// 往返之一：greeting 调用，两种形态并排展示。
///
/// 把同步和异步调用并排展示是有意为之：同步的那个在名字变化时重新计算，异步的那个
/// 只在按下按钮时执行。打字时看着两者分道扬镳，是体会 `#[frb(sync)]` 与 `Future`
/// 之间差别的最清楚方式。
///
/// 之所以是 Stateful，只因为那个输入框。它的 controller 必须比一次构建活得久 ——
/// 在 `build` 里创建的 controller 会随着每次按键被重建，光标也会被重置到开头 ——
/// 而输入框自己保存文本，所以 `HomeState` 不必去持有一个 widget。
class GreetingCard extends StatefulWidget {
  /// 创建面板。
  const GreetingCard({super.key});

  @override
  State<GreetingCard> createState() => _GreetingCardState();
}

class _GreetingCardState extends State<GreetingCard> {
  late final TextEditingController _name = TextEditingController(
    // 不涉及 `context`：`Get.find` 在任何地方都能用，包括字段初始化表达式里。
    text: Get.find<HomeState>().name.value,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final HomeState state = Get.find<HomeState>();

    return Obx(() {
      final Greeting? greeting = state.greeting.value;
      final String? error = state.greetingError.value;

      return DemoCard(
        title: 'hello / greet',
        explanation:
            'hello() is #[frb(sync)] and returns a String directly. greet() '
            'returns a Future, and is validated in Rust: a blank name comes back '
            'as an error.',
        trailing: state.isGreeting.value
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Name',
                helperText:
                    'Up to 64 characters. Rust trims it before validating.',
              ),
              // 直接写入 Rx 是 GetX 的习惯用法。值没变时 `RxString` 会跳过通知，
              // 所以不需要 setter 里那种相等性判断。
              onChanged: (String value) => state.name.value = value,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: <Widget>[
                for (final GreetingStyle style in GreetingStyle.values)
                  ChoiceChip(
                    label: Text(style.name),
                    selected: state.style.value == style,
                    onSelected: (_) => state.style.value = style,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // `instantHello` 读取 `state.name`，所以每次按键重建的就是这一行 ——
            // chips 和按钮不会。
            ValueLine(label: 'sync', value: state.instantHello),
            const SizedBox(height: 4),
            ValueLine(
              label: 'async',
              value: greeting?.message ?? 'press “Greet” to call Rust',
            ),
            if (error case final String message) ...<Widget>[
              const SizedBox(height: 8),
              _ErrorText(message),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: state.isGreeting.value ? null : state.submitGreeting,
              icon: const Icon(Icons.send),
              label: const Text('Greet'),
            ),
          ],
        ),
      );
    });
  }
}

/// 用主题错误色显示的错误文本，配有对应的图标。
class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Row(
      children: <Widget>[
        Icon(Icons.error_outline, size: 16, color: scheme.error),
        const SizedBox(width: 6),
        Expanded(child: Text(message, style: TextStyle(color: scheme.error))),
      ],
    );
  }
}
