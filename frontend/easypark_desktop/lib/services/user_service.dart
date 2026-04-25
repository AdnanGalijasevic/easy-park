import 'dart:convert';
import 'package:easypark_desktop/models/user_model.dart';
import 'package:easypark_desktop/providers/auth_provider.dart';
import 'package:easypark_desktop/services/base_service.dart';
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
      throw Exception(_parseLoginError(response));
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

  String _parseLoginError(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        final errors = data['errors'];
        if (errors is Map<String, dynamic>) {
          final userErrors = errors['userError'];
          if (userErrors is List && userErrors.isNotEmpty) return userErrors.first.toString();
        }
        final msg = data['message'] ?? data['error'];
        if (msg != null) return msg.toString();
      }
    } catch (_) {}
    return 'Login failed. Check credentials.';
  }
}
