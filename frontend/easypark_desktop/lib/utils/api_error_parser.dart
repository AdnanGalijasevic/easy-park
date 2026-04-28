import 'dart:convert';

String? extractApiErrorMessage(String responseBody) {
  try {
    final decoded = jsonDecode(responseBody);
    if (decoded is! Map<String, dynamic>) return null;

    final errors = decoded['errors'];
    if (errors is Map<String, dynamic>) {
      final userErrors = errors['userError'];
      if (userErrors is List && userErrors.isNotEmpty) {
        return userErrors.first.toString();
      }
    }

    final message = decoded['message'] ?? decoded['error'] ?? decoded['userError'];
    if (message != null) {
      final text = message.toString().trim();
      if (text.isNotEmpty) return text;
    }
  } catch (_) {
    return null;
  }

  return null;
}
