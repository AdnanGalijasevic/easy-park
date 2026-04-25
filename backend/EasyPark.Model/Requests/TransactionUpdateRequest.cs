using System;

namespace EasyPark.Model.Requests
{
    public class TransactionUpdateRequest
    {
        public string? Status { get; set; }
        public string? StripeTransactionId { get; set; }
        public string? StripePaymentIntentId { get; set; }
        public DateTime? PaymentDate { get; set; }
    }
}

