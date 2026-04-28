import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class AuthProvider {
  static const _usernameKey = 'auth_username';
  static const _accessTokenKey = 'auth_access_token';
  static const _refreshTokenKey = 'auth_refresh_token';

  static String? username;
  static String? accessToken;
  static String? refreshToken;

  static Future<void> persistSession(
    String user,
    String jwtAccessToken,
    String jwtRefreshToken,
  ) async {
    username = user;
    accessToken = jwtAccessToken;
    refreshToken = jwtRefreshToken;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usernameKey, user);
    await prefs.setString(_accessTokenKey, jwtAccessToken);
    await prefs.setString(_refreshTokenKey, jwtRefreshToken);
  }

  static Future<bool> tryRestoreCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUser = prefs.getString(_usernameKey);
    final savedAccessToken = prefs.getString(_accessTokenKey);
    final savedRefreshToken = prefs.getString(_refreshTokenKey);

    if (savedUser == null || savedAccessToken == null || savedRefreshToken == null) {
      return false;
    }

    username = savedUser;
    accessToken = savedAccessToken;
    refreshToken = savedRefreshToken;
    return true;
  }

  static Future<void> clearCredentials() async {
    username = null;
    accessToken = null;
    refreshToken = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_usernameKey);
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
  }

  static bool hasAdminRoleInAccessToken() {
    final token = accessToken;
    if (token == null || token.isEmpty) return false;

    final parts = token.split('.');
    if (parts.length < 2) return false;

    try {
      final normalized = base64Url.normalize(parts[1]);
      final payload = utf8.decode(base64Url.decode(normalized));
      final Map<String, dynamic> claims = jsonDecode(payload);

      final roleClaim = claims['role'] ?? claims['roles'];

      if (roleClaim is String) {
        return roleClaim.toLowerCase() == 'admin';
      }

      if (roleClaim is List) {
        return roleClaim.any(
          (entry) => entry.toString().toLowerCase() == 'admin',
        );
      }

      return false;
    } catch (_) {
      return false;
    }
  }
}

