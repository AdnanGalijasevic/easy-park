import 'package:flutter/material.dart';
import 'package:easypark_mobile/widgets/stripe_payment_dialog_stub.dart'
    if (dart.library.html) 'package:easypark_mobile/widgets/stripe_payment_dialog_web.dart';

export 'package:easypark_mobile/widgets/stripe_payment_dialog_stub.dart'
    if (dart.library.html) 'package:easypark_mobile/widgets/stripe_payment_dialog_web.dart'
    show showStripePaymentDialog;

/// Shows the embedded Stripe payment form dialog.
/// [token] — JWT access token to pass to backend.
/// [amount] — coins amount to purchase.
/// Returns true if payment was confirmed.
Future<bool> openStripePaymentDialog(
  BuildContext context, {
  required String token,
  required int amount,
}) {
  return showStripePaymentDialog(context, token: token, amount: amount);
}
