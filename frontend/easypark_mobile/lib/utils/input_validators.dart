class InputValidators {
  static final RegExp _emailRegex = RegExp(
    r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$",
  );
  static final RegExp _phoneRegex = RegExp(r'^\+?[0-9][0-9\s\-/]{7,19}$');
  static final RegExp _hasUpper = RegExp(r'[A-Z]');
  static final RegExp _hasLower = RegExp(r'[a-z]');
  static final RegExp _hasDigit = RegExp(r'[0-9]');

  static String? requiredText(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required.';
    }
    return null;
  }

  static String? email(String? value) {
    final required = requiredText(value, 'Email');
    if (required != null) return required;
    final v = value!.trim();
    if (!_emailRegex.hasMatch(v)) {
      return 'Enter valid email format (example: name@example.com).';
    }
    return null;
  }

  static String? phoneRequired(String? value) {
    final required = requiredText(value, 'Phone number');
    if (required != null) return required;
    final v = value!.trim();
    if (!_phoneRegex.hasMatch(v)) {
      return 'Enter valid phone format: +38761111222 (7-20 digits, spaces/- allowed).';
    }
    return null;
  }

  static String? phoneOptional(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    if (!_phoneRegex.hasMatch(v)) {
      return 'Enter valid phone format: +38761111222 (7-20 digits, spaces/- allowed).';
    }
    return null;
  }

  static String? passwordStrong(String? value, {String fieldName = 'Password'}) {
    if (value == null || value.isEmpty) return '$fieldName is required.';
    if (value.length < 8) {
      return '$fieldName must be at least 8 characters.';
    }
    if (!_hasUpper.hasMatch(value) ||
        !_hasLower.hasMatch(value) ||
        !_hasDigit.hasMatch(value)) {
      return '$fieldName must include uppercase, lowercase, and number.';
    }
    return null;
  }
}

