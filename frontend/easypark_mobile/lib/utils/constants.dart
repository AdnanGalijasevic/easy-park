import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  static String get baseUrl {
    const fromBuild = String.fromEnvironment('API_BASE');
    if (fromBuild.isNotEmpty) return fromBuild;

    final fromEnv = dotenv.env['API_BASE']?.trim();
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;

    if (kIsWeb) {
      // Use IPv4 loopback: on Windows, "localhost" may resolve to ::1 while Docker
      // publishes the API on IPv4 only, causing ERR_CONNECTION_RESET in Chrome.
      return "http://127.0.0.1:8080";
    } else if (Platform.isAndroid) {
      // Emulator → host loopback. Real phone needs API_BASE
      return "http://10.0.2.2:8080";
    } else {
      return "http://localhost:8080";
    }
  }

  static const String appName = "EasyPark";
}
