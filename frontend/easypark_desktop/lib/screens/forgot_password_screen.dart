import 'package:easypark_desktop/providers/user_provider.dart';
import 'package:easypark_desktop/screens/reset_password_screen.dart';
import 'package:easypark_desktop/theme/easy_park_colors.dart';
import 'package:easypark_desktop/utils/error_message.dart';
import 'package:flutter/material.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailOrUsernameController = TextEditingController();
  final UserProvider _userProvider = UserProvider();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailOrUsernameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await _userProvider.requestPasswordReset(
        _emailOrUsernameController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('If the account exists, reset instructions have been sent.'),
          backgroundColor: EasyParkColors.success,
        ),
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to send password reset instructions: ${normalizeErrorMessage(e)}',
          ),
          backgroundColor: EasyParkColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Enter your username or email to receive reset instructions.',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailOrUsernameController,
                    decoration: const InputDecoration(
                      labelText: 'Email or Username',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.alternate_email),
                    ),
                    validator: (value) {
                      final input = value?.trim() ?? '';
                      if (input.isEmpty) return 'Email or username is required.';
                      if (input.length < 3) return 'Enter at least 3 characters.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  Tooltip(
                    message: _isLoading
                        ? 'Request already in progress.'
                        : 'Send reset instructions',
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Send Reset Instructions'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
