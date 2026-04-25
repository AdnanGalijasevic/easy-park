import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easypark_mobile/providers/auth_provider.dart';
import 'package:easypark_mobile/theme/easy_park_colors.dart';

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
    }
  }

  @override
  void dispose() {
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: EasyParkColors.success,
          ),
        );
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _newPasswordConfirmController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: EasyParkColors.error),
        );
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
    return Scaffold(
      backgroundColor: EasyParkColors.accent.withValues(alpha: 0.06),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
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
                    onPressed: _isLoading ? null : _updateProfile,
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
        if (!isPassword && (value == null || value.trim().isEmpty)) {
          if (label != 'Phone') {
            return 'Please enter \$label';
          }
        }
        if (isPassword && label == 'Confirm New Password') {
          if (_newPasswordController.text.isNotEmpty &&
              value != _newPasswordController.text) {
            return 'Passwords do not match';
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
