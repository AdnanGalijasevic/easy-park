using System;

namespace EasyPark.Model.SearchObjects
{
    public class TransactionSearchObject : BaseSearchObject
    {
        public int? UserId { get; set; }
        public int? ReservationId { get; set; }
        public string? Status { get; set; }
        public string? PaymentMethod { get; set; }
        public DateTime? CreatedFrom { get; set; }
        public DateTime? CreatedTo { get; set; }
        public decimal? MinAmount { get; set; }
        public decimal? MaxAmount { get; set; }
    }
}

