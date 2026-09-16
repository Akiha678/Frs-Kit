import 'package:flutter/material.dart';

import '../theme.dart';

class DemoCard extends StatelessWidget {
  /// 创建一个面板。
  const DemoCard({
    required this.title,
    required this.explanation,
    required this.child,
    this.trailing,
    super.key,
  });

  final String title;

  final String explanation;

  /// 可选 widget，对齐到标题右侧，通常是一个状态 chip。
  final Widget? trailing;

  /// 面板主体。
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: text.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        explanation,
                        style: text.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...<Widget>[
                  const SizedBox(width: 12),
                  trailing!,
                ],
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

/// 用来显示从 Rust 返回的值的等宽文本行。
///
/// [label] 大致定宽并被弱化，这样值在变化时不会推动布局。
class ValueLine extends StatelessWidget {
  /// 创建一条值行。
  const ValueLine({
    required this.label,
    required this.value,
    this.style,
    super.key,
  });

  /// 短标签，例如 `sync`。
  final String label;

  /// 值本身。
  final String value;

  /// 值的附加样式，例如用错误色显示一个错误。
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: SelectableText(value, style: style ?? kValueTextStyle)),
      ],
    );
  }
}
