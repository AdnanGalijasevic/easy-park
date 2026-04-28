namespace EasyPark.Model.Models
{
    public class StripePaymentResult
    {
        public string Id { get; set; } = null!;
        public string ClientSecret { get; set; } = null!;
        public int CoinsAmount { get; set; }
        public bool IsPaid { get; set; }
    }
}
