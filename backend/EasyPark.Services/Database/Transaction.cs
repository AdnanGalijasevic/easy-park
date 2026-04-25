using System;

namespace EasyPark.Services.Database
{
    public partial class Transaction
    {
        public int Id { get; set; }
        public int UserId { get; set; }
        public int? ReservationId { get; set; }
        public decimal Amount { get; set; }
        public string Currency { get; set; } = "BAM";
        public string PaymentMethod { get; set; } = null!;
        public string Status { get; set; } = null!;
        public string? StripeTransactionId { get; set; }
        public string? StripePaymentIntentId { get; set; }
        public DateTime? PaymentDate { get; set; }
        public DateTime CreatedAt { get; set; }

        public virtual User User { get; set; } = null!;
        public virtual Reservation? Reservation { get; set; }
    }
}

