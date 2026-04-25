namespace EasyPark.Model.Requests
{
    public class ParkingSpotInsertRequest
    {
        public int ParkingLocationId { get; set; }
        public string SpotNumber { get; set; } = null!;
        public string SpotType { get; set; } = null!;
        public bool IsActive { get; set; } = true;
        public bool IsOccupied { get; set; } = false;
    }
}

