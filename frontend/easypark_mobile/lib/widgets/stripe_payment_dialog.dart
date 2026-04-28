import 'package:flutter/material.dart';
import 'package:easypark_mobile/widgets/payment_dialog_result.dart';
import 'package:easypark_mobile/widgets/stripe_payment_dialog_mobile.dart'
    if (dart.library.html) 'package:easypark_mobile/widgets/stripe_payment_dialog_web.dart';

export 'package:easypark_mobile/widgets/stripe_payment_dialog_mobile.dart'
    if (dart.library.html) 'package:easypark_mobile/widgets/stripe_payment_dialog_web.dart'
    show showStripePaymentDialog;

/// Shows the embedded Stripe payment form dialog.
/// [token] — JWT access token to pass to backend.
/// [amount] — coins amount to purchase.
Future<StripePaymentResult> openStripePaymentDialog(
  BuildContext context, {
  required String token,
  required int amount,
}) {
  return showStripePaymentDialog(context, token: token, amount: amount);
}
