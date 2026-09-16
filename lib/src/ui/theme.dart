import 'package:flutter/material.dart';

/// 所有界面颜色都由它派生而来的种子色。
///
/// 改这一个值就能给整个应用换色，这是让脚手架看起来像*你自己的*应用的最省事
/// 做法。
const Color kSeedColor = Color(0xFF4F46E5); // 靛蓝

/// 为 [brightness] 构建应用主题。
///
/// Material 3 从 [kSeedColor] 派生整套配色；只显式设置脚手架通常会覆盖的
/// 那几项。
ThemeData frsKitTheme(Brightness brightness) {
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: kSeedColor,
    brightness: brightness,
  );

  return ThemeData(
    colorScheme: scheme,
    // 对数值和流的演示来说，等宽字体比比例字体更适合那些数值字段；下面只有这些
    // 字段自己启用它。
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

/// 从 Rust 回显过来的值所用的文本样式。
///
/// 值用等宽字体显示，这样 `BigInt` 或者不断变化的计数器在更新时不会让布局
/// 重新排布。
const TextStyle kValueTextStyle = TextStyle(
  fontFamily: 'monospace',
  fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
);
