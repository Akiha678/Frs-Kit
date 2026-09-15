import 'package:flutter/material.dart';

import '../theme.dart';

/// Shared chrome for every demo on the home page.
///
/// Each panel explains one round-trip between Dart and Rust, so they all need the
/// same title/explanation/body layout. Having one shell keeps the panels short
/// enough to read in one screen, which is the point of a scaffold.
class DemoCard extends StatelessWidget {
  /// Creates a panel.
  const DemoCard({
    required this.title,
    required this.explanation,
    required this.child,
    this.trailing,
    super.key,
  });

  /// Panel heading, usually naming the Rust function it demonstrates.
  final String title;

  /// One or two sentences about what the Rust side is doing, shown under the
  /// title.
  final String explanation;

  /// Optional widget aligned to the right of the title, typically a status chip.
  final Widget? trailing;

  /// Panel body.
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

/// A monospaced line showing a value that came back from Rust.
///
/// [label] is fixed-width-ish and dimmed, so a changing value does not shift the
/// layout while it updates.
class ValueLine extends StatelessWidget {
  /// Creates a value line.
  const ValueLine({
    required this.label,
    required this.value,
    this.style,
    super.key,
  });

  /// Short label, e.g. `sync`.
  final String label;

  /// The value itself.
  final String value;

  /// Extra style for the value, e.g. to show an error in the error colour.
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
