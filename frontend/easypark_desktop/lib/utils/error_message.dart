String normalizeErrorMessage(Object error) {
  return error.toString().replaceFirst('Exception: ', '').trim();
}

String httpFailureMessage({
  required String action,
  required int statusCode,
  String? body,
}) {
  final text = (body ?? '').trim();
  if (text.isEmpty) {
    return '$action failed (HTTP $statusCode).';
  }
  return '$action failed (HTTP $statusCode): $text';
}
