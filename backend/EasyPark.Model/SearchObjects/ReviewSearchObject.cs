namespace EasyPark.Model.SearchObjects
{
    public class ReviewSearchObject : BaseSearchObject
    {
        public int? UserId { get; set; }
        public int? ParkingLocationId { get; set; }
        public int? Rating { get; set; }
        public int? MinRating { get; set; }
        public int? MaxRating { get; set; }
    }
}

