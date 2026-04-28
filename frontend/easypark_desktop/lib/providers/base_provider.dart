import 'dart:convert';

import 'package:easypark_desktop/models/search_result.dart';
import 'package:easypark_desktop/providers/auth_provider.dart';
import 'package:easypark_desktop/utils/api_error_parser.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';

abstract class BaseProvider<T> with ChangeNotifier {
  static String? _baseUrl;
  String _endpoint = '';

  BaseProvider(String endpoint) {
    _endpoint = endpoint;
    _baseUrl = const String.fromEnvironment(
      'API_BASE',
      defaultValue: 'http://localhost:8080/',
    );
  }

  static String get baseUrl {
    if (_baseUrl == null) {
      throw Exception('Base URL is not set');
    }
    return _baseUrl!;
  }

  Future<SearchResult<T>> get({
    dynamic filter,
    int? page,
    int? pageSize,
  }) async {
    var url = '$_baseUrl$_endpoint';

    Map<String, dynamic> queryParams = {};

    if (filter != null) {
      queryParams.addAll(Map<String, dynamic>.from(filter));
    }

    if (page != null) {
      queryParams['page'] = page;
    }
    if (pageSize != null) {
      queryParams['pageSize'] = pageSize;
    }
    if (queryParams.isNotEmpty) {
      var queryString = getQueryString(queryParams);
      url = '$url?$queryString';
    }
    var uri = Uri.parse(url);
    var response = await executeWithAuthRetry(
      (refreshedHeaders) => http.get(uri, headers: refreshedHeaders),
    );

    if (isValidResponse(response)) {
      var data = jsonDecode(response.body);

      var result = SearchResult<T>();

      result.count = data['count'] ?? 0;

      final resultList = data['resultList'];
      if (resultList != null) {
        for (var item in resultList) {
          result.result.add(fromJson(item));
        }
      }

      return result;
    } else {
      throw Exception('Unknown error');
    }
  }

  Future<T> getById(int id) async {
    var url = '$_baseUrl$_endpoint/$id';

    var uri = Uri.parse(url);
    var response = await executeWithAuthRetry(
      (refreshedHeaders) => http.get(uri, headers: refreshedHeaders),
    );
    if (isValidResponse(response)) {
      var data = jsonDecode(response.body);

      return fromJson(data);
    } else {
      throw Exception('Unknown error');
    }
  }

  Future<T> insert(dynamic request) async {
    var url = '$_baseUrl$_endpoint';
    var uri = Uri.parse(url);
    var jsonRequest = jsonEncode(request);
    var response = await executeWithAuthRetry(
      (refreshedHeaders) =>
          http.post(uri, headers: refreshedHeaders, body: jsonRequest),
    );

    if (isValidResponse(response)) {
      var data = jsonDecode(response.body);
      return fromJson(data);
    } else {
      throw Exception('Unknown error');
    }
  }

  Future delete(int id) async {
    var url = '$_baseUrl$_endpoint/$id';
    var uri = Uri.parse(url);
    var response = await executeWithAuthRetry(
      (refreshedHeaders) => http.delete(uri, headers: refreshedHeaders),
    );
    if (isValidResponse(response)) {
      return;
    } else {
      throw Exception('Unknown error');
    }
  }

  Future<T> update(int id, [dynamic request]) async {
    var url = '$_baseUrl$_endpoint/$id';
    var uri = Uri.parse(url);
    var jsonRequest = jsonEncode(request);
    var response = await executeWithAuthRetry(
      (refreshedHeaders) =>
          http.put(uri, headers: refreshedHeaders, body: jsonRequest),
    );

    try {
      if (isValidResponse(response)) {
        var data = jsonDecode(response.body);
        return fromJson(data);
      }
      throw Exception('Unknown error');
    } catch (_) {
      _debugLogHttpFailure(
        method: 'PUT',
        url: url,
        requestBody: jsonRequest,
        response: response,
      );
      rethrow;
    }
  }

  T fromJson(data) {
    throw Exception('Method not implemented');
  }

  bool isValidResponse(Response response) {
    try {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      }

      final errorMessage = extractApiErrorMessage(response.body);

      if (response.statusCode == 400) {
        throw UserFriendlyException(errorMessage ?? 'Bad request');
      } else if (response.statusCode == 401) {
        throw UserFriendlyException(errorMessage ?? 'Unauthorized');
      } else if (response.statusCode == 403) {
        throw UserFriendlyException(errorMessage ?? 'Access denied');
      } else if (response.statusCode == 404) {
        throw UserFriendlyException(errorMessage ?? 'Not found');
      } else if (response.statusCode >= 500) {
        throw UserFriendlyException(errorMessage ?? 'Internal server error');
      }

      throw UserFriendlyException(errorMessage ?? 'Unexpected error occurred');
    } catch (e) {
      if (e is UserFriendlyException) {
        rethrow;
      }
      throw UserFriendlyException(
        'Failed to process response. Please check your connection and try again.',
      );
    }
  }

  void _debugLogHttpFailure({
    required String method,
    required String url,
    required String requestBody,
    required Response response,
  }) {
    debugPrint('[$method] $url failed with ${response.statusCode}');
    debugPrint('[$method] request body: $requestBody');
    debugPrint('[$method] response body: ${response.body}');
  }

  Map<String, String> createHeaders() {
    final accessToken = AuthProvider.accessToken ?? '';

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
      'X-Client-Type': 'desktop',
    };
  }

  Future<http.Response> executeWithAuthRetry(
    Future<http.Response> Function(Map<String, String> headers) requestBuilder,
  ) async {
    var response = await requestBuilder(createHeaders());

    if (response.statusCode != 401) {
      return response;
    }

    final refreshed = await _tryRefreshToken();
    if (!refreshed) {
      return response;
    }

    return requestBuilder(createHeaders());
  }

  Future<bool> _tryRefreshToken() async {
    final refreshToken = AuthProvider.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }

    final refreshUri = Uri.parse('${BaseProvider.baseUrl}User/refresh');
    final refreshResponse = await http.post(
      refreshUri,
      headers: {
        'Content-Type': 'application/json',
        'X-Client-Type': 'desktop',
      },
      body: jsonEncode({'refreshToken': refreshToken}),
    );

    if (refreshResponse.statusCode < 200 || refreshResponse.statusCode >= 300) {
      return false;
    }

    final payload = jsonDecode(refreshResponse.body);
    if (payload is! Map<String, dynamic>) {
      return false;
    }

    final newAccessToken = payload['accessToken'] as String?;
    final newRefreshToken = payload['refreshToken'] as String?;
    final refreshedUsername =
        (payload['user'] as Map<String, dynamic>?)?['username'] as String?;
    final username = refreshedUsername ?? AuthProvider.username;

    if (username == null ||
        username.isEmpty ||
        newAccessToken == null ||
        newRefreshToken == null) {
      return false;
    }

    await AuthProvider.persistSession(username, newAccessToken, newRefreshToken);
    return true;
  }

  String getQueryString(
    Map params, {
    String prefix = '&',
    bool inRecursion = false,
  }) {
    String query = '';
    params.forEach((key, value) {
      if (inRecursion) {
        if (key is int) {
          key = '[$key]';
        } else if (value is List || value is Map) {
          key = '.$key';
        } else {
          key = '.$key';
        }
      }
      if (value is String || value is int || value is double || value is bool) {
        var encoded = value;
        if (value is String) {
          encoded = Uri.encodeComponent(value);
        }
        query += '$prefix$key=$encoded';
      } else if (value is DateTime) {
        query += '$prefix$key=${value.toIso8601String()}';
      } else if (value is List || value is Map) {
        if (value is List) value = value.asMap();
        value.forEach((k, v) {
          query += getQueryString(
            {k: v},
            prefix: '$prefix$key',
            inRecursion: true,
          );
        });
      }
    });
    return query;
  }
}

class UserFriendlyException implements Exception {
  final String message;

  UserFriendlyException(this.message);

  @override
  String toString() => message;
}
