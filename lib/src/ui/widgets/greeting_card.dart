import 'package:flutter/material.dart';

import '../../rust/bridge.dart';
import '../../state/home_state.dart';
import '../../state/state_scope.dart';
import 'demo_card.dart';

/// Round-trip one: the greeting call, in both flavours.
///
/// Shows the synchronous and the asynchronous call side by side on purpose: the
/// synchronous one is recomputed on every build, the asynchronous one only when
/// the button is pressed. Watching them diverge while typing is the clearest way
/// to feel the difference between `#[frb(sync)]` and a `Future`.
///
/// Stateful only because of the text field. Its controller must outlive a build —
/// one created inside `build` would be recreated on every keystroke and reset the
/// cursor to the start — and the field keeps its own text, so the state object
/// does not need to carry a widget.
class GreetingCard extends StatefulWidget {
  /// Creates the panel.
  const GreetingCard({super.key});

  @override
  State<GreetingCard> createState() => _GreetingCardState();
}

class _GreetingCardState extends State<GreetingCard> {
  late final TextEditingController _name = TextEditingController(
    // Safe here: the first access happens during the first build, when this
    // element is mounted and the scope above it is reachable.
    text: HomeStateScope.read(context).name,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final HomeState state = HomeStateScope.of(context);
    final Greeting? greeting = state.greeting;

    return DemoCard(
      title: 'hello / greet',
      explanation:
          'hello() is #[frb(sync)] and returns a String directly. greet() '
          'returns a Future, and is validated in Rust: a blank name comes back '
          'as an error.',
      trailing: state.isGreeting
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
            onChanged: state.setName,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: <Widget>[
              for (final GreetingStyle style in GreetingStyle.values)
                ChoiceChip(
                  label: Text(style.name),
                  selected: state.style == style,
                  onSelected: (_) => state.setStyle(style),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ValueLine(label: 'sync', value: state.instantHello),
          const SizedBox(height: 4),
          ValueLine(
            label: 'async',
            value: greeting?.message ?? 'press “Greet” to call Rust',
          ),
          if (state.greetingError case final String error) ...<Widget>[
            const SizedBox(height: 8),
            _ErrorText(error),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: state.isGreeting ? null : state.submitGreeting,
            icon: const Icon(Icons.send),
            label: const Text('Greet'),
          ),
        ],
      ),
    );
  }
}

/// Error text in the theme's error colour, with a matching icon.
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
        Expanded(
          child: Text(message, style: TextStyle(color: scheme.error)),
        ),
      ],
    );
  }
}
