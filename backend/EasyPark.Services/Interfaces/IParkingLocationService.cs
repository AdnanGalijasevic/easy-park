using System;
using System.Collections.Generic;
using EasyPark.Model.Models;
using EasyPark.Model.Requests;
using EasyPark.Model.SearchObjects;

namespace EasyPark.Services.Interfaces
{
    public interface IParkingLocationService : ICRUDService<ParkingLocation, ParkingLocationSearchObject, ParkingLocationInsertRequest, ParkingLocationUpdateRequest>
    {
        void UpdateCalculatedFields(int parkingLocationId);
        List<EasyPark.Model.Models.ParkingLocation> GetRecommendationScores(int userId, int? cityId = null);

        /// <summary>
        /// Returns busy/free time windows per spot type for a given day range.
        /// A window is "busy" (AvailableSpots == 0) when ALL spots of that type are occupied.
        /// </summary>
        List<SpotTypeAvailability> GetAvailability(int locationId, DateTime from, DateTime to);
        List<CityCoordinate> GetCityCoordinates();
        List<ParkingLocationName> GetParkingLocationNames();
    }
}
