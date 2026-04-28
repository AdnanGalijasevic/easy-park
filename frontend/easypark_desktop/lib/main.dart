import 'package:flutter/material.dart';
import 'package:easypark_desktop/screens/forgot_password_screen.dart';
import 'package:easypark_desktop/screens/master_screen.dart';
import 'package:easypark_desktop/utils/utils.dart';
import 'package:easypark_desktop/providers/auth_provider.dart';
import 'package:easypark_desktop/providers/user_provider.dart';
import 'package:easypark_desktop/theme/easy_park_colors.dart';
import 'package:easypark_desktop/theme/easy_park_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EasyPark',
      theme: EasyParkTheme.dark,
      themeMode: ThemeMode.dark,
      debugShowCheckedModeBanner: false,
      home: const _AuthBootstrap(),
    );
  }
}

class _AuthBootstrap extends StatefulWidget {
  const _AuthBootstrap();

  @override
  State<_AuthBootstrap> createState() => _AuthBootstrapState();
}

class _AuthBootstrapState extends State<_AuthBootstrap> {
  late final Future<bool> _bootstrapFuture;

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = _tryAutoLogin();
  }

  Future<bool> _tryAutoLogin() async {
    final hasSavedCredentials = await AuthProvider.tryRestoreCredentials();
    if (!hasSavedCredentials) return false;

    final user = AuthProvider.username;
    if (user == null || AuthProvider.accessToken == null) return false;
    if (!AuthProvider.hasAdminRoleInAccessToken()) {
      await AuthProvider.clearCredentials();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final loggedIn = snapshot.data == true;
        return loggedIn
            ? MasterScreen(key: masterScreenKey)
            : const LoginScreen();
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? usernameError;
  String? passwordError;
  bool _isLoading = false;
  final UserProvider _userProvider = UserProvider();

  void _login() async {
    if (!_validateInputs()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final loggedUser = await _userProvider.login(
        _usernameController.text.trim(),
        _passwordController.text.trim(),
      );

      final isAdmin =
          loggedUser.roles.any((r) => r.toLowerCase() == 'admin') ||
          AuthProvider.hasAdminRoleInAccessToken();
      if (!isAdmin) {
        await AuthProvider.clearCredentials();
        throw Exception('Access denied. Desktop app is available to admins only.');
      }

      if (!mounted) return;

      _usernameController.clear();
      _passwordController.clear();

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => MasterScreen(key: masterScreenKey),
        ),
      );
    } on Exception catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '');
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Ok'),
            ),
          ],
          content: Text(message),
        ),
      );
    }
    setState(() {
      _isLoading = false;
    });
  }

  bool _validateInputs() {
    final usernameVal = _usernameController.text;
    final passwordVal = _passwordController.text;

    final usernameValidation =
        inputRequired(usernameVal) ??
        noSpecialCharacters(usernameVal) ??
        minLength(usernameVal, 3) ??
        maxLength(usernameVal, 20);

    final passwordValidation =
        inputRequired(passwordVal) ?? password(passwordVal);

    setState(() {
      usernameError = usernameValidation;
      passwordError = passwordValidation;
    });

    return usernameError == null && passwordError == null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EasyParkColors.background,
      body: Row(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              color: EasyParkColors.surface,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/easypark_logo.png',
                        height: 160,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'EasyPark',
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: EasyParkColors.accent,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Parking management',
                        style: TextStyle(
                          fontSize: 18,
                          color: EasyParkColors.onBackground.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              color: EasyParkColors.background,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 64.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Welcome back',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: EasyParkColors.onBackground,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Sign in to the admin console',
                        style: TextStyle(
                          fontSize: 16,
                          color: EasyParkColors.onBackgroundMuted,
                        ),
                      ),
                    const SizedBox(height: 20),

                    TextField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.person),
                        labelText: 'Username',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        errorText: usernameError,
                      ),
                      onChanged: (value) {
                        if (usernameError != null) {
                          setState(() {
                            usernameError = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock),
                        labelText: 'Password',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        errorText: passwordError,
                        errorMaxLines: 3,
                      ),
                      onChanged: (value) {
                        if (passwordError != null) {
                          setState(() {
                            passwordError = null;
                          });
                        }
                      },
                      onSubmitted: (_) {
                        _login();
                      },
                    ),

                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: EasyParkColors.accent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 32,
                                width: 32,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 4,
                                    color: EasyParkColors.onAccent,
                                  ),
                                ),
                              )
                            : const Text(
                                'Log In',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: EasyParkColors.onAccent,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const ForgotPasswordScreen(),
                                  ),
                                );
                              },
                        child: const Text('Forgot password?'),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            ),
          ),
        ],
      ),
    );
  }
}
