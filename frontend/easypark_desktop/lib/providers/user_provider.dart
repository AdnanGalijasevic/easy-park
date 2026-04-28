import 'package:easypark_desktop/models/user_model.dart';
import 'package:easypark_desktop/providers/auth_provider.dart';
import 'package:easypark_desktop/providers/base_provider.dart';
import 'package:easypark_desktop/services/user_service.dart';

class UserProvider extends BaseProvider<User> {
  final UserService _userService = UserService();

  UserProvider() : super('User');

  @override
  User fromJson(data) => User.fromJson(data);

  Future<User> login(String username, String password) =>
      _userService.login(username, password);

  Future<void> requestPasswordReset(String emailOrUsername) =>
      _userService.requestPasswordReset(emailOrUsername);

  Future<void> resetPassword({
    required String token,
    required String newPassword,
    required String confirmPassword,
  }) => _userService.resetPassword(
    token: token,
    newPassword: newPassword,
    confirmPassword: confirmPassword,
  );

  Future<User> getCurrentUser() async {
    final username = AuthProvider.username;
    if (username == null || username.trim().isEmpty) {
      throw Exception('No active session.');
    }

    final result = await get(filter: {'fts': username.trim()}, page: 0, pageSize: 20);
    final candidates = result.result.where((u) => u.username == username).toList();
    if (candidates.isNotEmpty) return candidates.first;

    if (result.result.isNotEmpty) return result.result.first;
    throw Exception('Current user profile not found.');
  }

  static Future<void> logout() => AuthProvider.clearCredentials();
}
