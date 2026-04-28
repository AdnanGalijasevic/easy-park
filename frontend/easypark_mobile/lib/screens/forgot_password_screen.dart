import 'package:easypark_mobile/providers/auth_provider.dart';
import 'package:easypark_mobile/screens/reset_password_screen.dart';
import 'package:easypark_mobile/utils/app_feedback.dart';
import 'package:easypark_mobile/utils/input_validators.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailOrUsernameController = TextEditingController();

  @override
  void dispose() {
    _emailOrUsernameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await context.read<AuthProvider>().requestPasswordReset(
        _emailOrUsernameController.text.trim(),
      );

      if (!mounted) return;
      AppFeedback.success(
        'If account exists, reset instructions have been sent.',
      );
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
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
                    final required = InputValidators.requiredText(
                      input,
                      'Email or username',
                    );
                    if (required != null) return required;
                    if (input.length < 3) {
                      return 'Enter at least 3 characters.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  child: isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Send Reset Instructions'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
