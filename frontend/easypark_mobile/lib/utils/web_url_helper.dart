import 'package:web/web.dart' as web;

String? getWebQueryParam(String key) {
  final uri = Uri.parse(web.window.location.href);
  return uri.queryParameters[key];
}

void clearWebQueryParams() {
  try {
    final uri = Uri.parse(web.window.location.href);
    if (uri.queryParameters.isEmpty) return;
    final cleaned = uri.removeFragment().replace(queryParameters: {});
    web.window.history.replaceState(null, '', cleaned.toString());
  } catch (_) {}
}
