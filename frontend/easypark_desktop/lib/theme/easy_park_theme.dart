import 'package:flutter/material.dart';
import 'package:easypark_desktop/theme/easy_park_colors.dart';

abstract final class EasyParkTheme {
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: EasyParkColors.background,
        colorScheme: const ColorScheme.dark(
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
          titleTextStyle: TextStyle(
            color: EasyParkColors.onBackground,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: IconThemeData(color: EasyParkColors.onBackground),
        ),
        drawerTheme: const DrawerThemeData(
          backgroundColor: EasyParkColors.surface,
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
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: EasyParkColors.accent,
            foregroundColor: EasyParkColors.onAccent,
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: EasyParkColors.accent),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: EasyParkColors.surfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: EasyParkColors.accent,
          ),
          contentTextStyle: const TextStyle(
            fontSize: 16,
            color: EasyParkColors.onBackground,
          ),
        ),
        listTileTheme: const ListTileThemeData(
          textColor: EasyParkColors.onBackground,
          iconColor: EasyParkColors.onBackgroundMuted,
          selectedColor: EasyParkColors.accent,
          selectedTileColor: EasyParkColors.surfaceElevated,
        ),
        iconTheme: const IconThemeData(color: EasyParkColors.onBackground),
        dividerTheme: const DividerThemeData(color: EasyParkColors.outline),
      );
}
