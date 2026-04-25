namespace EasyPark.Model.Requests
{
    public class ReviewInsertRequest
    {
        public int ParkingLocationId { get; set; }
        public int Rating { get; set; } // 1-5
        public string? Comment { get; set; }
    }
}

