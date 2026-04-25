import 'package:flutter/material.dart';
import 'package:easypark_mobile/theme/easy_park_colors.dart';

abstract final class EasyParkTheme {
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: EasyParkColors.background,
        colorScheme: ColorScheme.dark(
          primary: EasyParkColors.accent,
          onPrimary: EasyParkColors.onAccent,
          secondary: EasyParkColors.muted,
          onSecondary: EasyParkColors.onAccent,
          surface: EasyParkColors.surface,
          onSurface: EasyParkColors.onBackground,
          error: EasyParkColors.error,
          onError: EasyParkColors.onError,
          outline: EasyParkColors.outline,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: EasyParkColors.surface,
          foregroundColor: EasyParkColors.onBackground,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: EasyParkColors.onBackground),
        ),
        cardTheme: CardThemeData(
          color: EasyParkColors.surfaceElevated,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: EasyParkColors.outline, width: 1),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: EasyParkColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: EasyParkColors.outline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: EasyParkColors.outline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: EasyParkColors.accent, width: 2),
          ),
          labelStyle: const TextStyle(color: EasyParkColors.onBackgroundMuted),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: EasyParkColors.accent,
            foregroundColor: EasyParkColors.onAccent,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: EasyParkColors.accent),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: EasyParkColors.accent,
          foregroundColor: EasyParkColors.onAccent,
        ),
        dividerTheme: const DividerThemeData(color: EasyParkColors.outline),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: EasyParkColors.surface,
          selectedItemColor: EasyParkColors.accent,
          unselectedItemColor: EasyParkColors.onBackgroundMuted,
          type: BottomNavigationBarType.fixed,
        ),
      );
}
