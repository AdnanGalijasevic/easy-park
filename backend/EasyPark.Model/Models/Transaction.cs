using System;

namespace EasyPark.Model.Models
{
    public class Transaction
    {
        public int Id { get; set; }
        public int UserId { get; set; }
        public string UserFullName { get; set; } = null!;
        public int? ReservationId { get; set; }
        public decimal Amount { get; set; }
        public string Currency { get; set; } = null!;
        public string PaymentMethod { get; set; } = null!;
        public string Status { get; set; } = null!;
        public string Type { get; set; } = "Debit"; // Default to Debit
        public string? StripeTransactionId { get; set; }
        public string? StripePaymentIntentId { get; set; }
        public DateTime? PaymentDate { get; set; }
        public DateTime CreatedAt { get; set; }
    }
}

