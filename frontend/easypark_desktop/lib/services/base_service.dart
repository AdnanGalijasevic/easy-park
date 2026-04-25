import 'dart:convert';
import 'package:easypark_desktop/models/search_result.dart';
import 'package:easypark_desktop/providers/auth_provider.dart';
import 'package:http/http.dart' as http;

/// Base service class — handles all raw HTTP communication.
/// Providers depend on this; they hold state and call service methods.
abstract class BaseService<T> {
  static String get baseUrl {
    final url = const String.fromEnvironment(
      'baseUrl',
      defaultValue: 'http://localhost:8080/',
    );
    return url;
  }

  final String _endpoint;

  BaseService(this._endpoint);

  T fromJson(Map<String, dynamic> data) {
    throw UnimplementedError('fromJson() must be overridden in subclasses');
  }

  Map<String, String> _buildHeaders({bool desktop = true}) {
    final accessToken = AuthProvider.accessToken ?? '';
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
      'X-Client-Type': desktop ? 'desktop' : 'mobile',
    };
  }

  /// Parse error message from ExceptionFilter response format.
  String _parseError(http.Response response, String fallback) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        final errors = data['errors'];
        if (errors is Map<String, dynamic>) {
          final userErrors = errors['userError'];
          if (userErrors is List && userErrors.isNotEmpty) {
            return userErrors.first.toString();
          }
        }
        final msg = data['message'] ?? data['error'];
        if (msg != null) return msg.toString();
      }
    } catch (_) {}
    return fallback;
  }

  Future<http.Response> _executeWithAuthRetry(
    Future<http.Response> Function(Map<String, String> headers) request,
  ) async {
    var response = await request(_buildHeaders());
    if (response.statusCode != 401) return response;

    final refreshed = await _tryRefreshToken();
    if (!refreshed) return response;

    return request(_buildHeaders());
  }

  Future<bool> _tryRefreshToken() async {
    final refreshToken = AuthProvider.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) return false;

    final uri = Uri.parse('${baseUrl}User/refresh');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json', 'X-Client-Type': 'desktop'},
      body: jsonEncode({'refreshToken': refreshToken}),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) return false;

    final payload = jsonDecode(res.body);
    if (payload is! Map<String, dynamic>) return false;

    final newAccess = payload['accessToken'] as String?;
    final newRefresh = payload['refreshToken'] as String?;
    final username = (payload['user'] as Map<String, dynamic>?)?['username'] as String?
        ?? AuthProvider.username;

    if (username == null || newAccess == null || newRefresh == null) return false;

    await AuthProvider.persistSession(username, newAccess, newRefresh);
    return true;
  }

  void _assertSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    final msg = _parseError(response, 'Unexpected error (${response.statusCode})');
    throw Exception(msg);
  }

  Future<SearchResult<T>> getList({
    Map<String, dynamic>? filter,
    int? page,
    int? pageSize,
  }) async {
    var url = '$baseUrl$_endpoint';
    final params = <String, dynamic>{};
    if (filter != null) params.addAll(filter);
    if (page != null) params['page'] = page;
    if (pageSize != null) params['pageSize'] = pageSize;

    if (params.isNotEmpty) {
      final qs = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}').join('&');
      url = '$url?$qs';
    }

    final uri = Uri.parse(url);
    final response = await _executeWithAuthRetry((h) => http.get(uri, headers: h));
    _assertSuccess(response);

    final data = jsonDecode(response.body);
    final result = SearchResult<T>();
    result.count = data['count'] ?? 0;
    for (var item in (data['resultList'] as List? ?? [])) {
      result.result.add(fromJson(item as Map<String, dynamic>));
    }
    return result;
  }

  Future<T> getById(int id) async {
    final uri = Uri.parse('$baseUrl$_endpoint/$id');
    final response = await _executeWithAuthRetry((h) => http.get(uri, headers: h));
    _assertSuccess(response);
    return fromJson(jsonDecode(response.body));
  }

  Future<T> create(Map<String, dynamic> request) async {
    final uri = Uri.parse('$baseUrl$_endpoint');
    final response = await _executeWithAuthRetry(
      (h) => http.post(uri, headers: h, body: jsonEncode(request)),
    );
    _assertSuccess(response);
    return fromJson(jsonDecode(response.body));
  }

  Future<T> update(int id, Map<String, dynamic> request) async {
    final uri = Uri.parse('$baseUrl$_endpoint/$id');
    final response = await _executeWithAuthRetry(
      (h) => http.put(uri, headers: h, body: jsonEncode(request)),
    );
    _assertSuccess(response);
    return fromJson(jsonDecode(response.body));
  }

  Future<void> delete(int id) async {
    final uri = Uri.parse('$baseUrl$_endpoint/$id');
    final response = await _executeWithAuthRetry((h) => http.delete(uri, headers: h));
    _assertSuccess(response);
  }

  Future<T> patch(int id, String action, Map<String, dynamic> request) async {
    final uri = Uri.parse('$baseUrl$_endpoint/$id/$action');
    final response = await _executeWithAuthRetry(
      (h) => http.patch(uri, headers: h, body: jsonEncode(request)),
    );
    _assertSuccess(response);
    return fromJson(jsonDecode(response.body));
  }

  Map<String, String> get headers => _buildHeaders();
}
