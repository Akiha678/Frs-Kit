import 'package:flutter/material.dart';

/// The seed colour every surface is derived from.
///
/// Changing this one value re-tints the entire app, which is the cheapest way to
/// make a scaffold look like *your* app.
const Color kSeedColor = Color(0xFF4F46E5); // indigo

/// Builds the app theme for [brightness].
///
/// Material 3 derives the whole palette from [kSeedColor]; only the pieces a
/// scaffold tends to override are set explicitly.
ThemeData frsKitTheme(Brightness brightness) {
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: kSeedColor,
    brightness: brightness,
  );

  return ThemeData(
    colorScheme: scheme,
    // A monospaced body would suit a demo of numbers and streams better than a
    // proportional one for the value fields; only those opt in, below.
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surfaceContainer,
      foregroundColor: scheme.onSurface,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      isDense: true,
    ),
  );
}

/// Text style for values echoed back from Rust.
///
/// Values are shown in a monospaced face so that a `BigInt` or a changing
/// counter does not reflow the layout while it updates.
const TextStyle kValueTextStyle = TextStyle(
  fontFamily: 'monospace',
  fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
);
