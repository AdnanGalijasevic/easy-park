import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:easypark_mobile/utils/constants.dart';
import 'package:easypark_mobile/services/auth_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:easypark_mobile/utils/session_events.dart';
import 'package:easypark_mobile/utils/client_type.dart';

abstract class BaseService<T> {
  final String _endpoint;
  final _storage = const FlutterSecureStorage();

  BaseService(this._endpoint);

  Future<Map<String, String>> _getHeaders() async {
    String? accessToken = await _storage.read(key: 'accessToken');
    accessToken ??= AuthService.currentAccessToken;
    final clientType = resolveClientType();

    if (accessToken == null) {
      return {'Content-Type': 'application/json', 'X-Client-Type': clientType};
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
      'X-Client-Type': clientType,
    };
  }

  Future<Map<String, String>> getHeaders() => _getHeaders();

  Future<T> fromJson(Map<String, dynamic> json);

  Exception _buildApiException(http.Response response, String fallbackMessage) {
    if (response.statusCode == 401) {
      SessionEvents.emitUnauthorized();
      return Exception('Session expired. Please log in again.');
    }
    try {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        final errors = data['errors'];
        if (errors is Map<String, dynamic>) {
          final userErrors = errors['userError'];
          if (userErrors is List && userErrors.isNotEmpty) {
            return Exception(userErrors.first.toString());
          }
          for (final value in errors.values) {
            if (value is List && value.isNotEmpty) {
              return Exception(value.first.toString());
            }
            if (value is String && value.trim().isNotEmpty) {
              return Exception(value.trim());
            }
          }
        }
        final message = data['message'] ?? data['userError'] ?? data['error'];
        if (message != null && message.toString().trim().isNotEmpty) {
          return Exception(message.toString().trim());
        }
      }
    } catch (_) {}
    return Exception(fallbackMessage);
  }

  Future<List<T>> get({Map<String, dynamic>? search}) async {
    var uri = Uri.parse('${AppConstants.baseUrl}/$_endpoint');

    if (search != null) {
      String queryString = Uri(
        queryParameters: search.map(
          (key, value) => MapEntry(key, value.toString()),
        ),
      ).query;
      uri = Uri.parse('${AppConstants.baseUrl}/$_endpoint?$queryString');
    }

    final headers = await _getHeaders();
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      List<dynamic> list;

      if (data is Map<String, dynamic> && data.containsKey('resultList')) {
        list = (data['resultList'] as List<dynamic>?) ?? [];
      } else if (data is List) {
        list = data;
      } else {
        throw Exception('Unexpected response format: ${data.runtimeType}');
      }

      return await Future.wait(
        list.map((e) => fromJson(e as Map<String, dynamic>)),
      );
    }
    throw _buildApiException(
      response,
      'Failed to load data (${response.statusCode}).',
    );
  }

  Future<T> getById(int id) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/$_endpoint/$id');
    final headers = await _getHeaders();
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      return fromJson(jsonDecode(response.body));
    }
    throw _buildApiException(
      response,
      'Failed to load item (${response.statusCode}).',
    );
  }

  Future<void> put(int id, Map<String, dynamic> body) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/$_endpoint/$id');
    final headers = await _getHeaders();
    final response =
        await http.put(uri, headers: headers, body: jsonEncode(body));

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw _buildApiException(
        response,
        'Failed to update item (${response.statusCode}).',
      );
    }
  }

  Future<void> post(Map<String, dynamic> body) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/$_endpoint');
    final headers = await _getHeaders();
    final response =
        await http.post(uri, headers: headers, body: jsonEncode(body));

    if (response.statusCode != 200 &&
        response.statusCode != 201 &&
        response.statusCode != 204) {
      throw _buildApiException(
        response,
        'Failed to create item (${response.statusCode}).',
      );
    }
  }

  Future<http.Response> postAction(String action, Map<String, dynamic> body) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/$_endpoint/$action');
    final headers = await _getHeaders();
    final response = await http.put(uri, headers: headers, body: jsonEncode(body));
    if (response.statusCode == 401) {
      throw _buildApiException(response, 'Session expired. Please log in again.');
    }
    return response;
  }
}
