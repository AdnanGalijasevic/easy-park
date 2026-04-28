typedef Validator = String? Function(String? value);

String? inputRequired(
  String? value, [
  String message = 'This field is required.',
]) {
  return (value == null || value.trim().isEmpty) ? message : null;
}

String? noSpecialCharacters(
  String? value, [
  String message = 'No special characters allowed.',
]) {
  if (value == null || value.isEmpty) return null;
  final regex = RegExp(r'^[a-zA-Z0-9_]+$');
  return regex.hasMatch(value) ? null : message;
}

String? onlyNumbers(String? value, [String message = 'Only numbers allowed.']) {
  if (value == null || value.isEmpty) return null;
  final regex = RegExp(r'^\d+$');
  return regex.hasMatch(value) ? null : message;
}

String? minLength(String? value, int min, [String? message]) {
  if (value == null) return null;
  return value.length >= min
      ? null
      : (message ?? 'Minimum $min characters required.');
}

String? maxLength(String? value, int max, [String? message]) {
  if (value == null) return null;
  return value.length <= max
      ? null
      : (message ?? 'Maximum $max characters allowed.');
}

String? password(String? value, [String? message]) {
  if (value == null || value.isEmpty) return null;
  return value.length >= 4
      ? null
      : (message ?? 'Password must be at least 4 characters long.');
}

String? email(String? value, [String? message]) {
  if (value == null || value.isEmpty) return null;
  final regex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
  return regex.hasMatch(value) ? null : (message ?? 'Invalid email format.');
}

String? phone(String? value, [String? message]) {
  if (value == null || value.isEmpty) return null;
  final regex = RegExp(r'^\+?[0-9]{8,15}$');
  return regex.hasMatch(value)
      ? null
      : (message ?? 'Invalid phone number format.');
}

String? decimal(String? value, [String? message]) {
  if (value == null || value.isEmpty) return null;
  final regex = RegExp(r'^\d+(\.\d{1,2})?$');
  return regex.hasMatch(value) ? null : (message ?? 'Invalid decimal number.');
}

String? positiveNumber(String? value, [String? message]) {
  if (value == null || value.isEmpty) return null;
  final num = double.tryParse(value);
  if (num == null) return message ?? 'Invalid number.';
  return num > 0 ? null : (message ?? 'Number must be greater than 0.');
}

String? latitude(String? value, [String? message]) {
  if (value == null || value.isEmpty) return null;
  final num = double.tryParse(value);
  if (num == null) return message ?? 'Invalid latitude.';
  return (num >= -90 && num <= 90)
      ? null
      : (message ?? 'Latitude must be between -90 and 90.');
}

String? longitude(String? value, [String? message]) {
  if (value == null || value.isEmpty) return null;
  final num = double.tryParse(value);
  if (num == null) return message ?? 'Invalid longitude.';
  return (num >= -180 && num <= 180)
      ? null
      : (message ?? 'Longitude must be between -180 and 180.');
}
