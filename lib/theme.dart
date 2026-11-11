import 'package:flutter/material.dart';

/// Colours from the approved Stitch "Field Precision System".
class AppColors {
  static const primary = Color(0xFF2264E5);
  static const primaryDark = Color(0xFF004CBF);
  static const primarySoft = Color(0xFFE5EEFF);
  static const navy = Color(0xFF0F172A);
  static const navyCard = Color(0xFF1E293B);
  static const canvas = Color(0xFFF5F7FB);
  static const border = Color(0xFFE2E8F0);
  static const body = Color(0xFF334155);
  static const muted = Color(0xFF64748B);
  static const success = Color(0xFF16A34A);
  static const successSoft = Color(0xFFDCFCE7);
  static const warning = Color(0xFFD97706);
  static const warningSoft = Color(0xFFFEF3C7);
  static const danger = Color(0xFFDC2626);
  static const dangerSoft = Color(0xFFFEE2E2);
  static const purple = Color(0xFF7C3AED);
  static const purpleSoft = Color(0xFFEDE9FE);
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    surface: Colors.white,
    error: AppColors.danger,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.canvas,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.navy,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      titleTextStyle: TextStyle(color: AppColors.navy, fontSize: 20, fontWeight: FontWeight.w700),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: AppColors.primarySoft,
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    ),
  );
}
