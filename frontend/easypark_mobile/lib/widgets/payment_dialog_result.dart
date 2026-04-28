enum StripePaymentStatus { paid, alreadyPaid, cancelled, failed }

class StripePaymentResult {
  final StripePaymentStatus status;
  final String? message;

  const StripePaymentResult({required this.status, this.message});

  bool get isSuccess =>
      status == StripePaymentStatus.paid ||
      status == StripePaymentStatus.alreadyPaid;
}
