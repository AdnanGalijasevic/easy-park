import 'package:easypark_desktop/models/user_model.dart';
import 'package:easypark_desktop/providers/auth_provider.dart';
import 'package:easypark_desktop/providers/user_provider.dart';
import 'package:easypark_desktop/screens/master_screen.dart';
import 'package:easypark_desktop/screens/parking_locations_screen.dart';
import 'package:easypark_desktop/theme/easy_park_colors.dart';
import 'package:easypark_desktop/utils/error_message.dart';
import 'package:easypark_desktop/utils/utils.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserProvider _userProvider = UserProvider();
  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  User? _currentUser;
  bool _isLoading = true;
  bool _isSavingProfile = false;
  bool _isChangingPassword = false;
  bool _didAttemptProfileSave = false;

  List<String> _resolvedRoles = const [];

  @override
  void initState() {
    super.initState();
    _firstNameController.addListener(_onProfileFieldChanged);
    _lastNameController.addListener(_onProfileFieldChanged);
    _usernameController.addListener(_onProfileFieldChanged);
    _emailController.addListener(_onProfileFieldChanged);
    _phoneController.addListener(_onProfileFieldChanged);
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _firstNameController.removeListener(_onProfileFieldChanged);
    _lastNameController.removeListener(_onProfileFieldChanged);
    _usernameController.removeListener(_onProfileFieldChanged);
    _emailController.removeListener(_onProfileFieldChanged);
    _phoneController.removeListener(_onProfileFieldChanged);
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onProfileFieldChanged() {
    if (!mounted) return;
    setState(() {});
  }

  bool get _isFirstNameValid =>
      inputRequired(
        _firstNameController.text.trim(),
        'First name is required.',
      ) ==
      null;

  bool get _isLastNameValid =>
      inputRequired(_lastNameController.text.trim(), 'Last name is required.') ==
      null;

  bool get _isUsernameValid =>
      inputRequired(_usernameController.text.trim(), 'Username is required.') ==
          null &&
      noSpecialCharacters(
            _usernameController.text.trim(),
            'Use letters, numbers, or underscore only.',
          ) ==
          null &&
      minLength(
            _usernameController.text.trim(),
            3,
            'Username must have at least 3 characters.',
          ) ==
          null &&
      maxLength(
            _usernameController.text.trim(),
            20,
            'Username can have at most 20 characters.',
          ) ==
          null;

  bool get _isProfileEmailValid =>
      email(
        _emailController.text.trim(),
        'Enter a valid email address (example@domain.com).',
      ) ==
      null;

  bool get _isProfilePhoneValid =>
      _validatePhoneForBackend(_phoneController.text.trim()) == null;

  bool get _canSaveProfile =>
      !_isSavingProfile &&
      !_isLoading &&
      _isFirstNameValid &&
      _isLastNameValid &&
      _isUsernameValid &&
      _isProfileEmailValid &&
      _isProfilePhoneValid;

  Future<void> _loadCurrentUser() async {
    setState(() => _isLoading = true);
    try {
      final user = await _userProvider.getCurrentUser();
      final hasAdminRoleFromUser = user.roles.any(
        (r) => r.toLowerCase() == 'admin',
      );
      final hasAdminRoleFromToken = AuthProvider.hasAdminRoleInAccessToken();
      final isAdmin = hasAdminRoleFromUser || hasAdminRoleFromToken;
      if (!isAdmin) {
        throw Exception('Access denied. Desktop app is available to admins only.');
      }
      if (!mounted) return;
      _currentUser = user;
      _resolvedRoles = hasAdminRoleFromUser
          ? user.roles
          : const ['Admin'];
      _firstNameController.text = user.firstName;
      _lastNameController.text = user.lastName;
      _usernameController.text = user.username;
      _emailController.text = user.email;
      _phoneController.text = user.phone ?? '';
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Unable to load your profile: ${normalizeErrorMessage(e)}');
    }
  }

  Future<void> _saveProfile() async {
    _didAttemptProfileSave = true;
    if (_currentUser == null || !_profileFormKey.currentState!.validate()) return;

    setState(() => _isSavingProfile = true);
    try {
      final normalizedPhone = _normalizePhoneForBackend(
        _phoneController.text.trim(),
      );
      final formattedBirthDate = _formatBirthDateForBackend(
        _currentUser!.birthDate,
      );
      final updated = await _userProvider.update(
        _currentUser!.id,
        {
          'firstName': _firstNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'username': _usernameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': normalizedPhone,
          'birthDate': formattedBirthDate,
        },
      );
      if (!mounted) return;
      _currentUser = updated;
      _showSuccess('Your profile details were updated successfully.');
    } catch (e) {
      if (!mounted) return;
      _showError('Could not save profile changes: ${normalizeErrorMessage(e)}');
    } finally {
      if (mounted) setState(() => _isSavingProfile = false);
    }
  }

  Future<void> _changePassword() async {
    if (_currentUser == null || !_passwordFormKey.currentState!.validate()) return;

    setState(() => _isChangingPassword = true);
    try {
      final normalizedPhone = _normalizePhoneForBackend(
        (_currentUser!.phone ?? '').trim(),
      );
      final formattedBirthDate = _formatBirthDateForBackend(
        _currentUser!.birthDate,
      );
      await _userProvider.update(
        _currentUser!.id,
        {
          'firstName': _currentUser!.firstName,
          'lastName': _currentUser!.lastName,
          'username': _currentUser!.username,
          'email': _currentUser!.email,
          'phone': normalizedPhone,
          'birthDate': formattedBirthDate,
          'currentPassword': _currentPasswordController.text,
          'newPassword': _newPasswordController.text,
          'newPasswordConfirm': _confirmPasswordController.text,
        },
      );
      if (!mounted) return;
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _showSuccess('Your account password was changed successfully.');
    } catch (e) {
      if (!mounted) return;
      _showError(
        'Could not change password. ${normalizeErrorMessage(e)}',
      );
    } finally {
      if (mounted) setState(() => _isChangingPassword = false);
    }
  }

  String? _validateNewPasswordConfirm(String? value) {
    final required = inputRequired(value, 'Confirm your new password.');
    if (required != null) return required;
    if (value != _newPasswordController.text) {
      return 'Password confirmation does not match.';
    }
    return null;
  }

  String _normalizePhoneForBackend(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String _formatBirthDateForBackend(DateTime value) {
    final yyyy = value.year.toString().padLeft(4, '0');
    final mm = value.month.toString().padLeft(2, '0');
    final dd = value.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }

  String? _validatePhoneForBackend(String value) {
    final required = inputRequired(value, 'Phone number is required.');
    if (required != null) return required;

    final normalized = _normalizePhoneForBackend(value);
    if (normalized.length < 9 || normalized.length > 10) {
      return 'Phone number must have 9-10 digits.';
    }
    return null;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: EasyParkColors.error),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: EasyParkColors.success),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back to parking locations',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => masterScreenKey.currentState?.navigateTo(
            const ParkingLocationsScreen(),
          ),
        ),
        automaticallyImplyLeading: false,
        title: const Text('My Profile'),
        actions: [
          Tooltip(
            message: _isLoading
                ? 'Profile load already in progress.'
                : 'Reload profile',
            child: IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reload profile',
              onPressed: _isLoading ? null : _loadCurrentUser,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentUser == null
          ? const Center(child: Text('Profile not available.'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _profileFormKey,
                        autovalidateMode: _didAttemptProfileSave
                            ? AutovalidateMode.always
                            : AutovalidateMode.onUserInteraction,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Account Details',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              initialValue: _resolvedRoles.join(', '),
                              decoration: const InputDecoration(
                                labelText: 'Role',
                              ),
                              readOnly: true,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _firstNameController,
                                    decoration: const InputDecoration(
                                      labelText: 'First name',
                                    ),
                                    validator: (v) => inputRequired(
                                      v,
                                      'First name is required.',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _lastNameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Last name',
                                    ),
                                    validator: (v) => inputRequired(
                                      v,
                                      'Last name is required.',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _usernameController,
                              decoration: const InputDecoration(
                                labelText: 'Username',
                              ),
                              validator: (v) =>
                                  inputRequired(v, 'Username is required.') ??
                                  noSpecialCharacters(
                                    v,
                                    'Use letters, numbers, or underscore only.',
                                  ) ??
                                  minLength(v, 3, 'Username must have at least 3 characters.') ??
                                  maxLength(v, 20, 'Username can have at most 20 characters.'),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                              ),
                              validator: (v) =>
                                  inputRequired(v, 'Email is required.') ??
                                  email(v, 'Enter a valid email address (example@domain.com).'),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _phoneController,
                              decoration: const InputDecoration(
                                labelText: 'Phone',
                                helperText: 'Use 9-10 digits (numbers only).',
                              ),
                              validator: (v) =>
                                  _validatePhoneForBackend((v ?? '').trim()),
                            ),
                            const SizedBox(height: 16),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Tooltip(
                                message: _isSavingProfile
                                    ? 'Profile save already in progress.'
                                    : 'Save profile changes',
                                child: FilledButton.icon(
                                  onPressed: _canSaveProfile ? _saveProfile : null,
                                  icon: _isSavingProfile
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.save),
                                  label: Text(
                                    _isSavingProfile ? 'Saving...' : 'Save profile',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _passwordFormKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Change Password',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Enter current password and new password.',
                              style: TextStyle(color: EasyParkColors.textSecondary),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _currentPasswordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Current password',
                              ),
                              validator: (v) =>
                                  inputRequired(v, 'Current password is required.'),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _newPasswordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'New password',
                                helperText: 'At least 4 characters.',
                              ),
                              validator: (v) =>
                                  inputRequired(v, 'New password is required.') ??
                                  password(v, 'New password must be at least 4 characters.'),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Confirm new password',
                              ),
                              validator: _validateNewPasswordConfirm,
                            ),
                            const SizedBox(height: 16),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Tooltip(
                                message: _isChangingPassword
                                    ? 'Password change already in progress.'
                                    : 'Change account password',
                                child: FilledButton.icon(
                                  onPressed: _isChangingPassword ? null : _changePassword,
                                  icon: _isChangingPassword
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.lock_reset),
                                  label: Text(
                                    _isChangingPassword
                                        ? 'Changing...'
                                        : 'Change password',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
