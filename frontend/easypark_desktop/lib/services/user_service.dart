import 'dart:convert';
import 'package:easypark_desktop/models/user_model.dart';
import 'package:easypark_desktop/providers/auth_provider.dart';
import 'package:easypark_desktop/services/base_service.dart';
import 'package:easypark_desktop/utils/api_error_parser.dart';
import 'package:http/http.dart' as http;

class UserService extends BaseService<User> {
  UserService() : super('User');

  @override
  User fromJson(Map<String, dynamic> data) => User.fromJson(data);

  Future<User> login(String username, String password) async {
    final uri = Uri.parse('${BaseService.baseUrl}User/login');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json', 'X-Client-Type': 'desktop'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401) {
        throw Exception('Wrong email or password.');
      }
      throw Exception(
        extractApiErrorMessage(response.body) ?? 'Login failed. Check credentials.',
      );
    }

    final data = jsonDecode(response.body);
    final user = User.fromJson(data['user'] as Map<String, dynamic>);
    await AuthProvider.persistSession(
      username,
      data['accessToken'] as String,
      data['refreshToken'] as String,
    );
    return user;
  }

  Future<void> requestPasswordReset(String emailOrUsername) async {
    final uri = Uri.parse('${BaseService.baseUrl}User/forgot-password');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json', 'X-Client-Type': 'desktop'},
      body: jsonEncode({'emailOrUsername': emailOrUsername.trim()}),
    );

    if (response.statusCode != 200 &&
        response.statusCode != 201 &&
        response.statusCode != 204) {
      throw Exception(
        extractApiErrorMessage(response.body) ??
            'Unable to send reset instructions. Verify input and try again.',
      );
    }
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final uri = Uri.parse('${BaseService.baseUrl}User/reset-password');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json', 'X-Client-Type': 'desktop'},
      body: jsonEncode({
        'token': token.trim(),
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      }),
    );

    if (response.statusCode != 200 &&
        response.statusCode != 201 &&
        response.statusCode != 204) {
      throw Exception(
        extractApiErrorMessage(response.body) ??
            'Password reset failed. Check token and password format.',
      );
    }
  }
}
