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

  Future<String> createCheckoutSession(int amount) async {
    final uri =
        Uri.parse('${AppConstants.baseUrl}/Transaction/create-checkout-session')
            .replace(
      queryParameters: {'amount': amount.toString()},
    );
    final headers = await getHeaders();
    final response = await http.post(uri, headers: headers);
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return data['url'] as String; // Stripe Checkout Session URL
    } else {
      throw Exception('Failed to create checkout session');
    }
  }

  Future<Transaction> completePurchase(String paymentIntentId) async {
    final uri = Uri.parse(
      '${AppConstants.baseUrl}/Transaction/complete-purchase?paymentIntentId=$paymentIntentId',
    );
    final headers = await getHeaders();
    final response = await http.post(uri, headers: headers);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Transaction.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to complete purchase');
    }
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
    try {
      final err = jsonDecode(response.body);
      final msg = err['userError'] ?? err['message'] ?? response.body;
      throw Exception(msg.toString());
    } catch (_) {
      throw Exception('Failed to download PDF (${response.statusCode})');
    }
  }
}
