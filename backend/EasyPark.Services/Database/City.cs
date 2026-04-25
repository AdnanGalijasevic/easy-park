using System.Collections.Generic;

namespace EasyPark.Services.Database
{
    public class City
    {
        public int Id { get; set; }
        public string Name { get; set; } = null!;
        public virtual ICollection<ParkingLocation> ParkingLocations { get; set; } = new List<ParkingLocation>();
    }
}
