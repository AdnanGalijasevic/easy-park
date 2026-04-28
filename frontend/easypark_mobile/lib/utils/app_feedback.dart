import 'package:flutter/material.dart';
import 'package:easypark_mobile/theme/easy_park_colors.dart';

final GlobalKey<ScaffoldMessengerState> appScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class AppFeedback {
  static void success(String message, {Duration? duration}) {
    _show(
      message: message,
      backgroundColor: EasyParkColors.success,
      duration: duration ?? const Duration(seconds: 3),
    );
  }

  static void error(String message, {Duration? duration}) {
    _show(
      message: message,
      backgroundColor: EasyParkColors.error,
      duration: duration ?? const Duration(seconds: 4),
    );
  }

  static void info(String message, {Duration? duration}) {
    _show(
      message: message,
      backgroundColor: EasyParkColors.info,
      duration: duration ?? const Duration(seconds: 3),
    );
  }

  static void _show({
    required String message,
    required Color backgroundColor,
    required Duration duration,
  }) {
    final messenger = appScaffoldMessengerKey.currentState;
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      ),
    );
  }
}

