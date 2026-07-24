import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Storybook-adventure theme for young learners.
///
/// Every colour, font, radius and shadow the app uses lives here, so the whole
/// look can be retuned from this one file. The palette leans warm (parchment
/// background, treasure gold, magic violet) rather than the cool greys of a
/// typical dashboard, and corners are rounder and taps larger than an adult
/// app would use.
class AppTheme {
  // ── Palette ───────────────────────────────────────────────────────────────
  // Magic violet leads, with sky blue and treasure gold as the adventure
  // accents. Error is a soft coral rather than a hard red — a wrong answer
  // should feel gentle to a child, not alarming.
  static const Color primary    = Color(0xFF6C5CE7);
  static const Color secondary  = Color(0xFF00B4D8);
  static const Color success    = Color(0xFF2BC26B);
  static const Color error      = Color(0xFFFF6B6B);
  static const Color warning    = Color(0xFFFFB703);
  static const Color background = Color(0xFFFFF8F0);
  static const Color surface    = Color(0xFFFFFFFF);
  static const Color textDark   = Color(0xFF2D2352);
  static const Color textLight  = Color(0xFF7A6E9B);

  // ── Semantic light tints ──────────────────────────────────────────────────
  static const Color primaryLight = Color(0xFFEFE9FF);
  static const Color successLight = Color(0xFFDCF7E6);
  static const Color errorLight   = Color(0xFFFFE6E6);
  static const Color warningLight = Color(0xFFFFF2D6);

  // ── Adventure accents ─────────────────────────────────────────────────────
  // Extra hues for playful surfaces (badges, level bars, celebration states).
  static const Color adventure     = Color(0xFFFF8A3D); // sunset orange
  static const Color adventureLight = Color(0xFFFFE9DA);
  static const Color treasure      = Color(0xFFFFC93C); // gold star

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
  static const double radiusSm = 14;
  static const double radiusMd = 18;
  static const double radiusLg = 22;

  // Minimum tap target — generous, because small fingers are imprecise.
  static const Size _tapTarget = Size(200, 54);

  // ── TextStyles ────────────────────────────────────────────────────────────
  // Fredoka (chunky and rounded) for headings and buttons; Nunito for body
  // copy, which stays the most legible at small sizes.
  static TextStyle get heading => GoogleFonts.fredoka(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: textDark,
      );

  static TextStyle get subheading => GoogleFonts.fredoka(
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

  static TextStyle get buttonText => GoogleFonts.fredoka(
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
            GoogleFonts.fredoka(fontSize: 16, fontWeight: FontWeight.w600),
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
            GoogleFonts.fredoka(fontSize: 16, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      );

  static ButtonStyle get smallButton => FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        textStyle:
            GoogleFonts.fredoka(fontSize: 14, fontWeight: FontWeight.w600),
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
            color: Color(0x1A6C5CE7),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      );

  /// Banner/hero fill for celebratory surfaces (session headers, level cards).
  static LinearGradient get heroGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primary, secondary],
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
