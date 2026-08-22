import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF1A1A2E);
  static const Color blue = Color(0xFF369FFF);
  static const Color purple = Color(0xFF5B00DF);
  static const Color background = Color(0xFFA9CADD);
  static const Color white = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color inputFill = Color(0xFFF3F4F6);
  static const Color inputBorder = Color(0xFFE5E7EB);

  // Marketplace / cart / payment palette (migrated from edu-kt EduColors).
  static const Color success = Color(0xFF22C55E);
  static const Color danger = Color(0xFFDC2626);
  static const Color purpleSoft = Color(0xFFEDE0FF);
  static const Color greenSoft = Color(0xFFD1F4DD);
  static const Color greenDark = Color(0xFF15803D);
  static const Color star = Color(0xFFF59E0B);
  static const Color imagePlaceholder = Color(0xFFEFEFEF);
  static const Color cartImageBlue = Color(0xFFCFE3F0);
  static const Color cartImageDark = Color(0xFF1F2A3D);

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFA9CADD),
      Color(0xFFBDD5E5),
      Color(0xFFD1E0EE),
    ],
  );
}
