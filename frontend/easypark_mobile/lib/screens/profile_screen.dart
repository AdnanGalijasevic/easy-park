import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easypark_mobile/providers/auth_provider.dart';
import 'package:easypark_mobile/theme/easy_park_colors.dart';
import 'package:easypark_mobile/utils/app_feedback.dart';
import 'package:easypark_mobile/utils/input_validators.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _newPasswordConfirmController = TextEditingController();

  bool _isLoading = false;
  bool _didAttemptSubmit = false;
  String? _profileNotice;
  bool _profileNoticeIsError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
    });
  }

  void _loadUserData() {
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user != null) {
      _firstNameController.text = user.firstName;
      _lastNameController.text = user.lastName;
      _usernameController.text = user.username;
      _emailController.text = user.email;
      _phoneController.text = user.phone ?? '';
      _registerFieldListeners();
    }
  }

  void _registerFieldListeners() {
    _firstNameController.addListener(_onFormFieldChanged);
    _lastNameController.addListener(_onFormFieldChanged);
    _usernameController.addListener(_onFormFieldChanged);
    _emailController.addListener(_onFormFieldChanged);
    _phoneController.addListener(_onFormFieldChanged);
    _currentPasswordController.addListener(_onFormFieldChanged);
    _newPasswordController.addListener(_onFormFieldChanged);
    _newPasswordConfirmController.addListener(_onFormFieldChanged);
  }

  void _onFormFieldChanged() {
    if (!mounted) return;
    setState(() {});
  }

  bool get _isFirstNameValid =>
      InputValidators.requiredText(_firstNameController.text, 'First Name') ==
      null;
  bool get _isLastNameValid =>
      InputValidators.requiredText(_lastNameController.text, 'Last Name') ==
      null;
  bool get _isUsernameValid =>
      InputValidators.requiredText(_usernameController.text, 'Username') ==
          null &&
      RegExp(r'^[A-Za-z0-9_]+$').hasMatch(_usernameController.text.trim()) &&
      _usernameController.text.trim().length >= 3 &&
      _usernameController.text.trim().length <= 20;
  bool get _isEmailValid => InputValidators.email(_emailController.text) == null;
  bool get _isPhoneValid =>
      InputValidators.phoneOptional(_phoneController.text) == null;
  bool get _isPasswordSectionValid {
    final hasPasswordIntent = _newPasswordController.text.trim().isNotEmpty ||
        _newPasswordConfirmController.text.trim().isNotEmpty ||
        _currentPasswordController.text.trim().isNotEmpty;
    if (!hasPasswordIntent) return true;

    final currentPasswordValid =
        _currentPasswordController.text.trim().isNotEmpty;
    final newPasswordValid =
        InputValidators.passwordStrong(_newPasswordController.text) == null;
    final confirmPasswordValid = _newPasswordConfirmController.text ==
        _newPasswordController.text;

    return currentPasswordValid && newPasswordValid && confirmPasswordValid;
  }

  bool get _canSaveProfile =>
      !_isLoading &&
      _isFirstNameValid &&
      _isLastNameValid &&
      _isUsernameValid &&
      _isEmailValid &&
      _isPhoneValid &&
      _isPasswordSectionValid;

  @override
  void dispose() {
    _firstNameController.removeListener(_onFormFieldChanged);
    _lastNameController.removeListener(_onFormFieldChanged);
    _usernameController.removeListener(_onFormFieldChanged);
    _emailController.removeListener(_onFormFieldChanged);
    _phoneController.removeListener(_onFormFieldChanged);
    _currentPasswordController.removeListener(_onFormFieldChanged);
    _newPasswordController.removeListener(_onFormFieldChanged);
    _newPasswordConfirmController.removeListener(_onFormFieldChanged);
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _newPasswordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    _didAttemptSubmit = true;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final updateRequest = {
        'firstName': _firstNameController.text,
        'lastName': _lastNameController.text,
        'username': _usernameController.text,
        'email': _emailController.text,
        'phone': _phoneController.text.isNotEmpty
            ? _phoneController.text
            : null,
      };

      if (_newPasswordController.text.isNotEmpty) {
        updateRequest['currentPassword'] = _currentPasswordController.text;
        updateRequest['newPassword'] = _newPasswordController.text;
        updateRequest['newPasswordConfirm'] =
            _newPasswordConfirmController.text;
      }

      await Provider.of<AuthProvider>(
        context,
        listen: false,
      ).update(updateRequest);

      if (mounted) {
        FocusScope.of(context).unfocus();
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _newPasswordConfirmController.clear();
        setState(() {
          _profileNotice = 'Profile updated successfully.';
          _profileNoticeIsError = false;
        });
        AppFeedback.success('Profile updated successfully.');
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString().replaceFirst('Exception: ', '');
        setState(() {
          _profileNotice = errorMessage;
          _profileNoticeIsError = true;
        });
        AppFeedback.error(errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: EasyParkColors.accent.withValues(alpha: 0.06),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            autovalidateMode: _didAttemptSubmit
                ? AutovalidateMode.always
                : AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 50,
                        backgroundColor: EasyParkColors.accent,
                        child: Icon(
                          Icons.person,
                          size: 50,
                          color: EasyParkColors.onAccent,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => Provider.of<AuthProvider>(
                          context,
                          listen: false,
                        ).logout(),
                        icon: const Icon(Icons.logout),
                        label: const Text("Logout"),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: EasyParkColors.error,
                          backgroundColor: EasyParkColors.error.withValues(alpha: 0.1),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                if (_profileNotice != null) ...[
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _profileNoticeIsError
                          ? EasyParkColors.error.withValues(alpha: 0.15)
                          : EasyParkColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _profileNoticeIsError
                            ? EasyParkColors.error
                            : EasyParkColors.success,
                      ),
                    ),
                    child: Text(
                      _profileNotice!,
                      style: TextStyle(
                        color: _profileNoticeIsError
                            ? EasyParkColors.error
                            : EasyParkColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const Text(
                  "Personal Information",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  "First Name",
                  _firstNameController,
                  Icons.person,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  "Last Name",
                  _lastNameController,
                  Icons.person_outline,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  "Username",
                  _usernameController,
                  Icons.account_circle,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  "Email",
                  _emailController,
                  Icons.email,
                  isEmail: true,
                ),
                const SizedBox(height: 16),
                _buildTextField("Phone", _phoneController, Icons.phone),
                const SizedBox(height: 32),
                const Text(
                  "Change Password",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  "Current Password",
                  _currentPasswordController,
                  Icons.lock,
                  isPassword: true,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  "New Password",
                  _newPasswordController,
                  Icons.lock_outline,
                  isPassword: true,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  "Confirm New Password",
                  _newPasswordConfirmController,
                  Icons.lock_outline,
                  isPassword: true,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _canSaveProfile ? _updateProfile : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EasyParkColors.accent,
                      foregroundColor: EasyParkColors.onAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: EasyParkColors.onAccent)
                        : const Text(
                            "Save Changes",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 100), // padding for bottom nav
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool isEmail = false,
    bool isPassword = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: EasyParkColors.textSecondary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: EasyParkColors.borderLight),
        ),
      ),
      validator: (value) {
        if (!isPassword && label == 'Email') {
          return InputValidators.email(value);
        }
        if (!isPassword && label == 'Phone') {
          return InputValidators.phoneOptional(value);
        }
        if (!isPassword) {
          return InputValidators.requiredText(value, label);
        }
        if (isPassword && label == 'Confirm New Password') {
          if (_newPasswordController.text.isNotEmpty &&
              value != _newPasswordController.text) {
            return 'Passwords do not match';
          }
        }
        if (isPassword && label == 'New Password') {
          if ((value ?? '').isNotEmpty) {
            return InputValidators.passwordStrong(
              value,
              fieldName: 'New password',
            );
          }
        }
        if (isPassword && label == 'Current Password') {
          if (_newPasswordController.text.isNotEmpty &&
              (value == null || value.isEmpty)) {
            return 'Required to change password';
          }
        }
        return null;
      },
    );
  }
}
