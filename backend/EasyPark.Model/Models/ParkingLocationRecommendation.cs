namespace EasyPark.Model.Models
{
    public class ParkingLocationRecommendation
    {
        public int ParkingLocationId { get; set; }
        public decimal RecommendationScore { get; set; } // 0.0 - 1.0 (0 = no match, 1.0 = perfect match)
    }
}

