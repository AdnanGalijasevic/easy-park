import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:easypark_mobile/services/transaction_service.dart';
import 'package:easypark_mobile/utils/app_feedback.dart';
import 'package:easypark_mobile/widgets/payment_dialog_result.dart';

Future<StripePaymentResult> showStripePaymentDialog(
  BuildContext context, {
  required String token,
  required int amount,
}) async {
  final service = TransactionService();
  try {
    if (token.trim().isEmpty) {
      return const StripePaymentResult(
        status: StripePaymentStatus.failed,
        message: 'Session expired. Please log in again.',
      );
    }

    final data = await service.createPaymentIntent(amount);

    // Support both camelCase (ASP.NET default) and snake_case (Stripe default)
    final String clientSecret =
        (data['clientSecret'] ?? data['client_secret'] ?? '').toString();
    final String paymentIntentId = (data['id'] ?? '').toString();
    final bool alreadyPaid = data['isPaid'] == true || data['is_paid'] == true;

    if (alreadyPaid) {
      return const StripePaymentResult(
        status: StripePaymentStatus.alreadyPaid,
        message: 'This payment was already completed earlier.',
      );
    }

    if (clientSecret.isEmpty || paymentIntentId.isEmpty) {
      throw Exception(
        'Payment initialization returned an incomplete response. Please try again.',
      );
    }

    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        merchantDisplayName: 'EasyPark',
        style: ThemeMode.dark,
        appearance: const PaymentSheetAppearance(
          colors: PaymentSheetAppearanceColors(primary: Color(0xFFF47920)),
        ),
      ),
    );

    await Stripe.instance.presentPaymentSheet();

    final transaction = await service.completePurchase(paymentIntentId);
    final normalizedType = transaction.type.trim().toLowerCase();
    if (normalizedType != 'credit' && normalizedType != 'refund') {
      AppFeedback.info('Payment confirmed. Balance refresh may take a few seconds.');
    }
    return const StripePaymentResult(status: StripePaymentStatus.paid);
  } catch (e) {
    if (e is StripeException) {
      debugPrint('Stripe error: ${e.error.localizedMessage}');
      final code = e.error.code.name.toLowerCase();
      final isCancelled =
          code.contains('canceled') || code.contains('cancelled');
      final message =
          e.error.localizedMessage ??
          (isCancelled
              ? 'Payment was cancelled before completion.'
              : 'Payment could not be completed.');
      if (context.mounted) {
        _showError(context, message);
      }
      if (isCancelled) {
        await _tryCleanupPendingCoinPayments(service);
      }
      return StripePaymentResult(
        status: isCancelled
            ? StripePaymentStatus.cancelled
            : StripePaymentStatus.failed,
        message: message,
      );
    } else {
      debugPrint('Error in Stripe payment: $e');
      final message = _cleanError(e);
      if (context.mounted) {
        _showError(context, message);
      }
      await _tryCleanupPendingCoinPayments(service);
      return StripePaymentResult(
        status: StripePaymentStatus.failed,
        message: message,
      );
    }
  }
}

String _cleanError(Object error) =>
    error.toString().replaceFirst('Exception: ', '').trim();

void _showError(BuildContext context, String message) {
  AppFeedback.error(message);
}

Future<void> _tryCleanupPendingCoinPayments(TransactionService service) async {
  try {
    await service.cancelPendingCoinPayments();
  } catch (_) {
    // Ignore cleanup errors. Primary payment error is more important for UX.
  }
}
