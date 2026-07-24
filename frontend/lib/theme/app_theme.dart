import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Pastel storybook-adventure theme for young learners.
///
/// Every colour, font, radius and shadow the app uses lives here, so the whole
/// look can be retuned from this one file. The palette is bright pastel
/// (playful purple, sky blue, leaf green, sunshine orange/yellow) on a clean
/// white background, rather than the cool greys of a typical dashboard, and
/// corners are rounder and taps larger than an adult app would use.
class AppTheme {
  // ── Palette ───────────────────────────────────────────────────────────────
  // Playful purple leads, with sky blue, leaf green and sunshine orange/yellow
  // as the adventure accents. Error is a soft coral rather than a hard red —
  // a wrong answer should feel gentle to a child, not alarming.
  static const Color primary    = Color(0xFF8E6BFF);
  static const Color secondary  = Color(0xFF4DA8FF);
  static const Color success    = Color(0xFF5CCB5F);
  static const Color error      = Color(0xFFFF6B6B);
  static const Color warning    = Color(0xFFFFB703);
  static const Color background = Color(0xFFFAFBFF);
  static const Color surface    = Color(0xFFFFFFFF);
  static const Color textDark   = Color(0xFF2D2352);
  static const Color textLight  = Color(0xFF7A6E9B);

  // ── Semantic light tints ──────────────────────────────────────────────────
  static const Color primaryLight   = Color(0xFFEFE9FF);
  static const Color secondaryLight = Color(0xFFE3F1FF);
  static const Color successLight   = Color(0xFFE1F7E2);
  static const Color errorLight     = Color(0xFFFFE6E6);
  static const Color warningLight   = Color(0xFFFFF2D6);

  // ── Adventure accents ─────────────────────────────────────────────────────
  // Extra hues for playful surfaces (badges, level bars, celebration states).
  static const Color adventure      = Color(0xFFFF9F43); // sunshine orange
  static const Color adventureLight = Color(0xFFFFF0E0);
  static const Color treasure       = Color(0xFFFFD54A); // gold star
  static const Color blossom        = Color(0xFFF06BA8); // pink

  /// Soft gradient for screens that want the "white background with light
  /// gradients" look instead of a flat [background] fill.
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF3F0FF), Color(0xFFFFFFFF), Color(0xFFF0F9FF)],
  );

  /// Warm-tinted card shadow. Const so `const BoxShadow` sites can use it.
  static const Color shadowColor = Color(0x1A6C5CE7);

  /// Frosted-glass card look: translucent tint + blur (applied via
  /// `BackdropFilter` by the caller) + a soft light border.
  static BoxDecoration glassDecoration(Color tint, {double radius = radiusLg}) {
    return BoxDecoration(
      color: tint.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
      boxShadow: [
        BoxShadow(
          color: tint.withValues(alpha: 0.25),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  // ── Spacing ───────────────────────────────────────────────────────────────
  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 12;
  static const double lg  = 16;
  static const double xl  = 24;
  static const double xxl = 32;

  // ── Radii ─────────────────────────────────────────────────────────────────
  // Rounder than a standard Material app: soft shapes read as friendly and
  // toy-like to young children.
  static const double radiusSm = 16;
  static const double radiusMd = 24;
  static const double radiusLg = 32;

  // Minimum tap target — generous, because small fingers are imprecise.
  static const Size _tapTarget = Size(200, 54);

  // ── TextStyles ────────────────────────────────────────────────────────────
  // Baloo 2 (chunky and bubbly) for headings and buttons; Nunito for body
  // copy, which stays the most legible at small sizes.
  static TextStyle get heading => GoogleFonts.baloo2(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: textDark,
      );

  static TextStyle get subheading => GoogleFonts.baloo2(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textDark,
      );

  static TextStyle get body => GoogleFonts.nunito(
        fontSize: 16,
        color: textDark,
      );

  static TextStyle get caption => GoogleFonts.nunito(
        fontSize: 13,
        color: textLight,
      );

  static TextStyle get buttonText => GoogleFonts.baloo2(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: surface,
      );

  // ── ButtonStyles ──────────────────────────────────────────────────────────
  static ButtonStyle get primaryButton => FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: surface,
        minimumSize: _tapTarget,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        textStyle:
            GoogleFonts.baloo2(fontSize: 16, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      );

  static ButtonStyle get secondaryButton => OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: const BorderSide(color: primary, width: 2),
        minimumSize: _tapTarget,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        textStyle:
            GoogleFonts.baloo2(fontSize: 16, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      );

  static ButtonStyle get smallButton => FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        textStyle:
            GoogleFonts.baloo2(fontSize: 14, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      );

  static ButtonStyle get backButtonStyle => TextButton.styleFrom(
        backgroundColor: surface,
        foregroundColor: textDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      );

  // ── Decorations ───────────────────────────────────────────────────────────
  // Shadow is warm-tinted rather than neutral black, so cards sit on the
  // parchment background instead of looking cut out of it.
  static BoxDecoration get cardDecoration => BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(radiusLg),
        boxShadow: const [
          BoxShadow(
            color: shadowColor,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      );

  // ── ThemeData ─────────────────────────────────────────────────────────────
  static ThemeData get themeData => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          primary: primary,
          secondary: secondary,
          error: error,
          surface: surface,
        ),
        scaffoldBackgroundColor: background,
        textTheme: GoogleFonts.nunitoTextTheme(),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: textDark,
          contentTextStyle: GoogleFonts.nunito(fontSize: 15, color: surface),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
        ),
        useMaterial3: true,
      );
}
