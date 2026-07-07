import 'package:flutter/material.dart';

/// MD3E (Material 3 Expressive) Tokens 实现层。
///
/// 文档指定使用 `m3e_design` 包提供标准化 Tokens（spacing / typography / shapes），
/// 告别硬编码像素值。由于该包可能不在 pub.dev 上，这里按文档描述的 API 形态
/// 自行实现等价 Tokens，使业务代码与文档完全一致：
///   - `withM3ETheme(ThemeData)` 返回 `ThemeData`（匹配文档 `theme:` 用法）
///   - `M3ETheme.of(context).spacing / .typography / .shapes` 任意处访问
///
/// 实现策略：Tokens 为常量规范（spacing/shapes 固定，typography 取自当前 TextTheme），
/// 由 `M3ETheme.of(context)` 实时从 `Theme.of(context)` 构造，无需注入 ThemeExtension，
/// 彻底避免泛型约束问题。接入官方 m3e_design 时仅需替换本文件实现。

/// 间距 Tokens（M3 Expressive 间距阶梯）
class M3ESpacing {
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  const M3ESpacing({this.xs = 4, this.sm = 8, this.md = 16, this.lg = 24, this.xl = 32});
}

/// 形状 Tokens（MD3E 圆角族：标准 + expressive largeIncreased）
class M3EShapes {
  final ShapeBorder extraSmall;
  final ShapeBorder small;
  final ShapeBorder medium;
  final ShapeBorder large;
  final ShapeBorder extraLarge;
  final ShapeBorder largeIncreased;
  const M3EShapes({
    this.extraSmall = const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(4))),
    this.small = const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8))),
    this.medium = const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12))),
    this.large = const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16))),
    this.extraLarge = const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(24))),
    this.largeIncreased = const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(36))),
  });
}

/// 排版 Tokens（基于当前 TextTheme 的 MD3 规范）
class M3ETypography {
  final TextStyle displaySmall;
  final TextStyle headlineLarge;
  final TextStyle headlineSmall;
  final TextStyle titleLarge;
  final TextStyle titleMedium;
  final TextStyle titleSmall;
  final TextStyle bodyLarge;
  final TextStyle bodyMedium;
  final TextStyle bodySmall;
  final TextStyle labelLarge;
  final TextStyle labelMedium;
  final TextStyle labelSmall;
  const M3ETypography({
    required this.displaySmall,
    required this.headlineLarge,
    required this.headlineSmall,
    required this.titleLarge,
    required this.titleMedium,
    required this.titleSmall,
    required this.bodyLarge,
    required this.bodyMedium,
    required this.bodySmall,
    required this.labelLarge,
    required this.labelMedium,
    required this.labelSmall,
  });

  factory M3ETypography.from(TextTheme tt) => M3ETypography(
        displaySmall: tt.displaySmall ?? const TextStyle(),
        headlineLarge: tt.headlineLarge ?? const TextStyle(),
        headlineSmall: tt.headlineSmall ?? const TextStyle(),
        titleLarge: tt.titleLarge ?? const TextStyle(),
        titleMedium: tt.titleMedium ?? const TextStyle(),
        titleSmall: tt.titleSmall ?? const TextStyle(),
        bodyLarge: tt.bodyLarge ?? const TextStyle(),
        bodyMedium: tt.bodyMedium ?? const TextStyle(),
        bodySmall: tt.bodySmall ?? const TextStyle(),
        labelLarge: tt.labelLarge ?? const TextStyle(),
        labelMedium: tt.labelMedium ?? const TextStyle(),
        labelSmall: tt.labelSmall ?? const TextStyle(),
      );
}

/// 聚合的 MD3E Tokens
class M3EThemeData {
  final M3ESpacing spacing;
  final M3EShapes shapes;
  final M3ETypography typography;

  const M3EThemeData({
    required this.spacing,
    required this.shapes,
    required this.typography,
  });

  factory M3EThemeData.from(ThemeData theme) => M3EThemeData(
        spacing: const M3ESpacing(),
        shapes: const M3EShapes(),
        typography: M3ETypography.from(theme.textTheme),
      );
}

/// withM3ETheme：标记 ThemeData 启用 MD3E。
/// 用法（与文档一致）：`theme: withM3ETheme(ThemeData(colorScheme: ..., useMaterial3: true))`
///
/// Tokens 通过 [M3ETheme.of] 实时从主题获取，此处直接返回传入的 ThemeData。
ThemeData withM3ETheme(ThemeData theme) => theme;

/// 扩展方法：themeData.toM3EThemeData()
extension M3EThemeExtension on ThemeData {
  ThemeData toM3EThemeData() => withM3ETheme(this);
}

/// 访问入口：M3ETheme.of(context).spacing / .typography / .shapes
class M3ETheme {
  static M3EThemeData of(BuildContext context) =>
      M3EThemeData.from(Theme.of(context));
}
