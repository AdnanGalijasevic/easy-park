namespace EasyPark.Model.Requests
{
    public class ParkingSpotUpdateRequest
    {
        public int? ParkingLocationId { get; set; }
        public string? SpotNumber { get; set; }
        public string? SpotType { get; set; }
        public bool? IsActive { get; set; }
        public bool? IsOccupied { get; set; }
    }
}

