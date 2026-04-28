import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:easypark_mobile/utils/constants.dart';
import 'package:easypark_mobile/models/user.dart';
import 'package:easypark_mobile/utils/session_events.dart';
import 'package:easypark_mobile/utils/client_type.dart';

class AuthService {
  final _storage = const FlutterSecureStorage();
  static String? _sessionAccessToken;

  String? _accessToken;
  String? _refreshToken;
  String? _username;
  int? _userId;

  String? get username => _username;
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  int? get userId => _userId;
  static String? get currentAccessToken => _sessionAccessToken;

  Exception _buildApiException(http.Response response, String fallbackMessage) {
    if (response.statusCode == 401) {
      SessionEvents.emitUnauthorized();
      return Exception('Session expired. Please log in again.');
    }
    try {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        final errors = data['errors'];
        if (errors is Map<String, dynamic>) {
          final userErrors = errors['userError'];
          if (userErrors is List && userErrors.isNotEmpty) {
            return Exception(userErrors.first.toString());
          }
        }
        final message = data['message'] ?? data['userError'] ?? data['error'];
        if (message != null && message.toString().trim().isNotEmpty) {
          return Exception(message.toString().trim());
        }
      }
    } catch (_) {}
    return Exception(fallbackMessage);
  }

  Future<User?> login(String username, String password) async {
    final url = Uri.parse('${AppConstants.baseUrl}/User/login');
    final clientType = resolveClientType();

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Client-Type': clientType,
        },
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        _username = username;
        _accessToken = data['accessToken'] as String?;
        _refreshToken = data['refreshToken'] as String?;
        _sessionAccessToken = _accessToken;

        final user = User.fromJson(data['user'] as Map<String, dynamic>);
        _userId = user.id;

        await _storage.write(key: 'username', value: username);
        await _storage.write(key: 'accessToken', value: _accessToken);
        await _storage.write(key: 'refreshToken', value: _refreshToken);
        await _storage.write(key: 'userId', value: _userId.toString());
        return user;
      } else if (response.statusCode == 401) {
        throw Exception('Wrong email or password.');
      } else {
        debugPrint('Login failed: ${response.statusCode} body=${response.body}');
        throw _buildApiException(
          response,
          'Login failed. Check username/password and try again.',
        );
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Connection error: $e');
    }
  }

  Future<User?> register({
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirm,
    required DateTime birthDate,
  }) async {
    final url = Uri.parse('${AppConstants.baseUrl}/User');
    final clientType = resolveClientType();

    final body = jsonEncode({
      'firstName': firstName,
      'lastName': lastName,
      'username': username,
      'email': email,
      'phone': phone,
      'password': password,
      'passwordConfirm': passwordConfirm,
      'birthDate':
          '${birthDate.year.toString().padLeft(4, '0')}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}',
    });

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Client-Type': clientType,
        },
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return await login(username, password);
      } else {
        final err = jsonDecode(response.body);
        final msg = err['userError'] ?? err['message'] ?? 'Registration failed';
        throw Exception(msg);
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Connection error: $e');
    }
  }

  Future<void> requestPasswordReset(String emailOrUsername) async {
    final url = Uri.parse('${AppConstants.baseUrl}/User/forgot-password');
    final clientType = resolveClientType();

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'X-Client-Type': clientType,
      },
      body: jsonEncode({'emailOrUsername': emailOrUsername.trim()}),
    );

    if (response.statusCode != 200 &&
        response.statusCode != 201 &&
        response.statusCode != 204) {
      throw _buildApiException(
        response,
        'Unable to send reset instructions. Verify input and try again.',
      );
    }
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final url = Uri.parse('${AppConstants.baseUrl}/User/reset-password');
    final clientType = resolveClientType();

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'X-Client-Type': clientType,
      },
      body: jsonEncode({
        'token': token.trim(),
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      }),
    );

    if (response.statusCode != 200 &&
        response.statusCode != 201 &&
        response.statusCode != 204) {
      throw _buildApiException(
        response,
        'Password reset failed. Check token validity and password format.',
      );
    }
  }

  Future<void> tryAutoLogin() async {
    final u = await _storage.read(key: 'username');
    final access = await _storage.read(key: 'accessToken');
    final refresh = await _storage.read(key: 'refreshToken');
    final userId = await _storage.read(key: 'userId');
    if (u != null && access != null && refresh != null) {
      _username = u;
      _accessToken = access;
      _refreshToken = refresh;
      _sessionAccessToken = access;
      _userId = int.tryParse(userId ?? '');
    }
  }

  Future<void> logout() async {
    if (_accessToken != null) {
      final logoutUrl = Uri.parse('${AppConstants.baseUrl}/User/logout');
      final clientType = resolveClientType();
      await http.post(
        logoutUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
          'X-Client-Type': clientType,
        },
        body: jsonEncode({'refreshToken': _refreshToken}),
      );
    }

    _username = null;
    _accessToken = null;
    _refreshToken = null;
    _sessionAccessToken = null;
    _userId = null;
    await _storage.deleteAll();
  }

  Future<User> getCurrentUser(int id) async {
    final url = Uri.parse('${AppConstants.baseUrl}/User/$id');
    try {
      final response = await http.get(url, headers: getHeaders());
      if (response.statusCode == 200) {
        return User.fromJson(jsonDecode(response.body));
      } else {
        throw _buildApiException(
          response,
          'Failed to load user (${response.statusCode}).',
        );
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Connection error: $e');
    }
  }

  Future<User> update(int id, Map<String, dynamic> request) async {
    final url = Uri.parse('${AppConstants.baseUrl}/User/$id');
    try {
      final response = await http.put(
        url,
        headers: getHeaders(),
        body: jsonEncode(request),
      );
      if (response.statusCode == 200) {
        return User.fromJson(jsonDecode(response.body));
      } else {
        throw _buildApiException(
          response,
          'Update failed (${response.statusCode}).',
        );
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Connection error: $e');
    }
  }

  Map<String, String> getHeaders() {
    final clientType = resolveClientType();
    if (_accessToken == null) {
      return {
        'Content-Type': 'application/json',
        'X-Client-Type': clientType,
      };
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_accessToken',
      'X-Client-Type': clientType,
    };
  }
}
