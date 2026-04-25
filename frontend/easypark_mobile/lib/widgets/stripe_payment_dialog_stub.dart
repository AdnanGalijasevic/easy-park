import 'package:flutter/material.dart';

Future<bool> showStripePaymentDialog(
  BuildContext context, {
  required String token,
  required int amount,
}) async {
  // Non-web fallback: not supported.
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Embedded payment not supported on this platform.')),
  );
  return false;
}
