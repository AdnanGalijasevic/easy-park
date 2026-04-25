namespace EasyPark.Model.Requests
{
    public class TransactionInsertRequest
    {
        public int? ReservationId { get; set; }
        public decimal Amount { get; set; }
        public string? Currency { get; set; }
        public string PaymentMethod { get; set; } = null!;
        public string? StripeTransactionId { get; set; }
        public string? StripePaymentIntentId { get; set; }
    }
}

