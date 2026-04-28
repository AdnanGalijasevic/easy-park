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
    final userId = AuthProvider.getUserIdFromAccessToken();
    if (userId == null || userId <= 0) {
      throw Exception('No active session.');
    }
    return getById(userId);
  }

  static Future<void> logout() => AuthProvider.clearCredentials();
}
