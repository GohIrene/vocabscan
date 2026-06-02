import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Palette ───────────────────────────────────────────────────────────────
  static const Color primary    = Color(0xFF7C3AED);
  static const Color secondary  = Color(0xFF3B82F6);
  static const Color success    = Color(0xFF10B981);
  static const Color error      = Color(0xFFEF4444);
  static const Color warning    = Color(0xFFF59E0B);
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface    = Color(0xFFFFFFFF);
  static const Color textDark   = Color(0xFF1E293B);
  static const Color textLight  = Color(0xFF64748B);

  // ── Semantic light tints ──────────────────────────────────────────────────
  static const Color primaryLight = Color(0xFFEDE9FE);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color errorLight   = Color(0xFFFEE2E2);
  static const Color warningLight = Color(0xFFFEF3C7);

  // ── Spacing ───────────────────────────────────────────────────────────────
  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 12;
  static const double lg  = 16;
  static const double xl  = 24;
  static const double xxl = 32;

  // ── TextStyles ────────────────────────────────────────────────────────────
  static TextStyle get heading => GoogleFonts.nunito(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: textDark,
      );

  static TextStyle get subheading => GoogleFonts.nunito(
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

  static TextStyle get buttonText => GoogleFonts.nunito(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: surface,
      );

  // ── ButtonStyles ──────────────────────────────────────────────────────────
  static ButtonStyle get primaryButton => FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: surface,
        minimumSize: const Size(200, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.bold),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      );

  static ButtonStyle get secondaryButton => OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: const BorderSide(color: primary, width: 2),
        minimumSize: const Size(200, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.bold),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      );

  static ButtonStyle get smallButton => FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      );

  static ButtonStyle get backButtonStyle => TextButton.styleFrom(
        backgroundColor: surface,
        foregroundColor: textDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      );

  // ── CardDecoration ────────────────────────────────────────────────────────
  static BoxDecoration get cardDecoration => BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      );

  // ── ThemeData ─────────────────────────────────────────────────────────────
  static ThemeData get themeData => ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: primary),
        textTheme: GoogleFonts.nunitoTextTheme(),
        useMaterial3: true,
      );
}
