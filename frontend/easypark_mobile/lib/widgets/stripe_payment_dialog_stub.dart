import 'package:flutter/material.dart';
import 'package:easypark_mobile/utils/app_feedback.dart';
import 'package:easypark_mobile/widgets/payment_dialog_result.dart';

Future<StripePaymentResult> showStripePaymentDialog(
  BuildContext context, {
  required String token,
  required int amount,
}) async {
  AppFeedback.info(
    'Embedded payment unavailable on this platform. Use Android, iOS, or Web checkout.',
  );
  return const StripePaymentResult(
    status: StripePaymentStatus.failed,
    message:
        'Embedded payment is unavailable on this platform. Use Android, iOS, or Web checkout.',
  );
}
