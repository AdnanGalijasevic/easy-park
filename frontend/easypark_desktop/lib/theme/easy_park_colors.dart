import 'package:flutter/material.dart';

/// EasyPark brand palette — keep in sync with `easypark_mobile/lib/theme/easy_park_colors.dart`.
abstract final class EasyParkColors {
  static const Color background = Color(0xFF1A1C20);
  static const Color surface = Color(0xFF252830);
  static const Color surfaceElevated = Color(0xFF2E3238);
  static const Color accent = Color(0xFFF47920);
  /// Secondary action green (e.g. mobile profile save)
  static const Color primaryGreen = Color(0xFF86B94E);
  static const Color onAccent = Color(0xFFFFFFFF);
  static const Color muted = Color(0xFF616368);
  static const Color onBackground = Color(0xFFE8E8EA);
  static const Color onBackgroundMuted = Color(0xFF9CA3AF);
  static const Color outline = Color(0xFF3D424B);
  static const Color error = Color(0xFFDC2626);
  static const Color success = Color(0xFF22C55E);
  static const Color successLight = Color(0xFF86EFAC);
  static const Color errorLight = Color(0xFFF87171);
  static const Color info = Color(0xFF5B8DEF);
  static const Color highlightBorder = Color(0xFFFFD700);
  static const Color chartSecondary = Color(0xFF94A3B8);
  static const Color chartTertiary = Color(0xFFA855F7);
  /// Stacked bar / multi-series (occupancy by spot type)
  static const Color chartRegular = Color(0xFF6366F1);
  static const Color chartDisabled = Color(0xFF0EA5E9);
  static const Color chartElectric = Color(0xFF10B981);
  static const Color chartCovered = Color(0xFFF59E0B);
  /// Star ratings (distinct from accent orange)
  static const Color ratingStar = Color(0xFFFBBF24);
  /// Map marker “optimal match” outline (amber)
  static const Color mapMarkerOptimalBorder = Color(0xFFFFC107);

  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textOnLightPrimary = Color(0xFF111827);
  static const Color textOnLightSecondary = Color(0xFF4B5563);

  static const Color borderLight = Color(0xFFD1D5DB);
  static const Color dividerLight = Color(0xFFE5E7EB);
  static const Color surfaceWash = Color(0xFFF9FAFB);

  static const Color scrim = Color(0x8A000000);
  static const Color shadowSubtle = Color(0x1A000000);
  static const Color overlaySubtle = Color(0x1F000000);

  static const Color inverseSurface = Color(0xFFFFFFFF);
  static const Color onInverseSurface = Color(0xFF111111);

  static const Color successContainer = Color(0xFFDCFCE7);
  static const Color errorContainer = Color(0xFFFEE2E2);
  static const Color successOnContainer = Color(0xFF14532D);
  static const Color errorOnContainer = Color(0xFF991B1B);

  static const Color infoContainer = Color(0xFF1E2A3D);
  static const Color infoLight = Color(0xFFEFF6FF);

  static const Color disabled = Color(0xFF9CA3AF);

  static const Color onError = Color(0xFFFFFFFF);
  static const Color onAccentMuted = Color(0xB3FFFFFF);

  static const Color transparent = Color(0x00000000);
}
