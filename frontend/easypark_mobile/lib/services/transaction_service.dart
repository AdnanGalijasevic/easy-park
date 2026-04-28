import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:easypark_mobile/models/transaction.dart';
import 'package:easypark_mobile/services/base_service.dart';
import 'package:easypark_mobile/utils/constants.dart';

class TransactionService extends BaseService<Transaction> {
  TransactionService() : super('Transaction');

  @override
  Future<Transaction> fromJson(Map<String, dynamic> json) async {
    return Transaction.fromJson(json);
  }

  String _extractErrorMessage(http.Response response, String fallback) {
    if (response.statusCode == 401) {
      return 'Session expired. Please log in again.';
    }
    if (response.body.isEmpty) {
      return '$fallback (${response.statusCode})';
    }
    try {
      final dynamic data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        final dynamic errors = data['errors'];
        if (errors is Map<String, dynamic>) {
          final dynamic userError = errors['userError'];
          if (userError is List && userError.isNotEmpty) {
            return userError.first.toString();
          }
          for (final dynamic value in errors.values) {
            if (value is List && value.isNotEmpty) return value.first.toString();
            if (value is String && value.trim().isNotEmpty) return value.trim();
          }
        }
        final dynamic message = data['userError'] ?? data['message'] ?? data['error'];
        if (message != null && message.toString().trim().isNotEmpty) {
          return message.toString().trim();
        }
      }
    } catch (_) {}
    return '$fallback (${response.statusCode})';
  }

  Future<Map<String, dynamic>> createPaymentIntent(int amount) async {
    final uri = Uri.parse('${AppConstants.baseUrl}/Transaction/buy-coins').replace(
      queryParameters: {'amount': amount.toString()},
    );
    final headers = await getHeaders();
    final response = await http.post(uri, headers: headers);
    if (response.statusCode == 200 || response.statusCode == 201) {
      final dynamic data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return data;
      }
      throw Exception('Unexpected payment response format.');
    }
    throw Exception(
      _extractErrorMessage(response, 'Failed to initialize payment'),
    );
  }

  Future<String> createCheckoutSession(int amount) async {
    final uri =
        Uri.parse('${AppConstants.baseUrl}/Transaction/create-checkout-session')
            .replace(
      queryParameters: {'amount': amount.toString()},
    );
    final headers = await getHeaders();
    final response = await http.post(uri, headers: headers);
    if (response.statusCode == 200 || response.statusCode == 201) {
      final dynamic data = jsonDecode(response.body);
      if (data is Map<String, dynamic> && data['url'] is String) {
        return data['url'] as String;
      }
      throw Exception('Unexpected checkout response format.');
    }
    throw Exception(
      _extractErrorMessage(response, 'Failed to create checkout session'),
    );
  }

  Future<Transaction> completePurchase(String paymentIntentId) async {
    final uri = Uri.parse(
      '${AppConstants.baseUrl}/Transaction/complete-purchase?paymentIntentId=$paymentIntentId',
    );
    final headers = await getHeaders();
    final response = await http.post(uri, headers: headers);
    if (response.statusCode == 200 || response.statusCode == 201) {
      final dynamic data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return Transaction.fromJson(data);
      }
      throw Exception('Unexpected purchase confirmation format.');
    }
    throw Exception(_extractErrorMessage(response, 'Failed to complete purchase'));
  }

  Future<int> cancelPendingCoinPayments() async {
    final uri = Uri.parse(
      '${AppConstants.baseUrl}/Transaction/cancel-pending-coin-payments',
    );
    final headers = await getHeaders();
    final response = await http.post(uri, headers: headers);
    if (response.statusCode == 200 || response.statusCode == 201) {
      if (response.body.isEmpty) return 0;
      try {
        final dynamic data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          return (data['cancelledCount'] as num?)?.toInt() ?? 0;
        }
      } catch (_) {
        return 0;
      }
      return 0;
    }
    throw Exception(
      _extractErrorMessage(response, 'Failed to cancel pending coin payments'),
    );
  }

  Future<Uint8List> downloadStripePaymentsPdf({
    required bool allTime,
    int? year,
    int? month,
  }) async {
    final qp = <String, String>{
      if (allTime) 'allTime': 'true',
      if (!allTime && year != null && month != null) ...{
        'year': '$year',
        'month': '$month',
      },
    };
    if (!allTime && (year == null || month == null)) {
      throw Exception('Year and month are required');
    }
    final uri = Uri.parse('${AppConstants.baseUrl}/Transaction/stripe-payments-pdf')
        .replace(queryParameters: qp);
    final headers = await getHeaders();
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    throw Exception(_extractErrorMessage(response, 'Failed to download PDF'));
  }
}
