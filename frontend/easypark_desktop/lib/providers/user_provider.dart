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

  static Future<void> logout() => AuthProvider.clearCredentials();
}
