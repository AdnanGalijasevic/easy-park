namespace EasyPark.Services.Database
{
    public class CityCoordinate
    {
        public int Id { get; set; }
        public string City { get; set; } = null!;
        public decimal Latitude { get; set; }
        public decimal Longitude { get; set; }
    }
}

