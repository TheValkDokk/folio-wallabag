import 'package:flutter/material.dart';

/// Editorial palette: paper, ink, one deep green accent. No gradients.
class FolioColors extends ThemeExtension<FolioColors> {
  const FolioColors({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.ink,
    required this.muted,
    required this.faint,
    required this.line,
    required this.accent,
    required this.accentInk,
    required this.accentSoft,
    required this.danger,
  });

  final Color bg;
  final Color surface;
  final Color surfaceAlt;
  final Color ink;
  final Color muted;
  final Color faint;
  final Color line;
  final Color accent;
  final Color accentInk;
  final Color accentSoft;
  final Color danger;

  static const light = FolioColors(
    bg: Color(0xFFFAF7F0),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF3EEE3),
    ink: Color(0xFF17140F),
    muted: Color(0xFF6B6357),
    faint: Color(0xFF9A938A),
    line: Color(0xFFE6DFD0),
    accent: Color(0xFF1F4B43),
    accentInk: Color(0xFFF6F2E9),
    accentSoft: Color(0xFFE2EDE7),
    danger: Color(0xFF9B3D2E),
  );

  static const dark = FolioColors(
    bg: Color(0xFF0E0E0F),
    surface: Color(0xFF17171A),
    surfaceAlt: Color(0xFF1D1D20),
    ink: Color(0xFFEDE7DB),
    muted: Color(0xFF9C9488),
    faint: Color(0xFF6E685F),
    line: Color(0xFF26262A),
    accent: Color(0xFFC7A46B),
    accentInk: Color(0xFF14120E),
    accentSoft: Color(0xFF2A2419),
    danger: Color(0xFFD08A78),
  );

  @override
  FolioColors copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? ink,
    Color? muted,
    Color? faint,
    Color? line,
    Color? accent,
    Color? accentInk,
    Color? accentSoft,
    Color? danger,
  }) {
    return FolioColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      faint: faint ?? this.faint,
      line: line ?? this.line,
      accent: accent ?? this.accent,
      accentInk: accentInk ?? this.accentInk,
      accentSoft: accentSoft ?? this.accentSoft,
      danger: danger ?? this.danger,
    );
  }

  @override
  FolioColors lerp(ThemeExtension<FolioColors>? other, double t) {
    if (other is! FolioColors) return this;
    return FolioColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      faint: Color.lerp(faint, other.faint, t)!,
      line: Color.lerp(line, other.line, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentInk: Color.lerp(accentInk, other.accentInk, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

extension Folio on BuildContext {
  FolioColors get c => Theme.of(this).extension<FolioColors>()!;

  /// Serif display/reading face. Georgia ships on iOS, Noto Serif on Android.
  static const serif = 'Georgia';

  TextStyle get display => TextStyle(
        fontFamily: serif,
        fontFamilyFallback: const ['serif', 'Times New Roman'],
        fontSize: 32,
        height: 1.1,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.6,
        color: c.ink,
      );

  TextStyle get headline => TextStyle(
        fontFamily: serif,
        fontFamilyFallback: const ['serif', 'Times New Roman'],
        fontSize: 22,
        height: 1.15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: c.ink,
      );

  TextStyle get title => TextStyle(
        fontFamily: serif,
        fontFamilyFallback: const ['serif', 'Times New Roman'],
        fontSize: 17,
        height: 1.28,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: c.ink,
      );

  TextStyle get body => TextStyle(
        fontSize: 14.5,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: c.ink,
      );

  TextStyle get small => TextStyle(
        fontSize: 12.5,
        height: 1.4,
        fontWeight: FontWeight.w400,
        color: c.muted,
      );

  TextStyle get label => TextStyle(
        fontSize: 10.5,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.1,
        color: c.faint,
      );

  TextStyle get mono => TextStyle(
        fontSize: 12,
        height: 1.3,
        fontWeight: FontWeight.w500,
        color: c.muted,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}

ThemeData folioTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? FolioColors.dark : FolioColors.light;
  final base = ThemeData(
    brightness: brightness,
    useMaterial3: true,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: c.accentInk,
      secondary: c.accent,
      onSecondary: c.accentInk,
      error: c.danger,
      onError: c.accentInk,
      surface: c.surface,
      onSurface: c.ink,
    ),
    scaffoldBackgroundColor: c.bg,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
  return base.copyWith(extensions: [c]);
}
