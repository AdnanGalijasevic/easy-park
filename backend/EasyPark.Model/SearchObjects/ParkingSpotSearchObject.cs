namespace EasyPark.Model.SearchObjects
{
    public class ParkingSpotSearchObject : BaseSearchObject
    {
        public string? FTS { get; set; }
        public int? ParkingLocationId { get; set; }
        public string? SpotType { get; set; }
        public bool? IsActive { get; set; }
        public bool? IsOccupied { get; set; }
        public int? CityId { get; set; } // Filter by parking location city
    }
}

