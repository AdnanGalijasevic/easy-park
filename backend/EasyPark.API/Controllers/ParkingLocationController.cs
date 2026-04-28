using System;
using System.Collections.Generic;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using EasyPark.Model;
using EasyPark.Model.Models;
using EasyPark.Model.Requests;
using EasyPark.Model.SearchObjects;
using EasyPark.Services.Interfaces;

namespace EasyPark.API.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class ParkingLocationController : BaseCRUDController<ParkingLocation, ParkingLocationSearchObject, ParkingLocationInsertRequest, ParkingLocationUpdateRequest>
    {
        protected new IParkingLocationService _service;
        
        public ParkingLocationController(IParkingLocationService service) : base(service)
        {
            _service = service;
        }

        public override PagedResult<ParkingLocation> GetList([FromQuery] ParkingLocationSearchObject searchObject)
        {
            return base.GetList(searchObject);
        }

        public override ParkingLocation GetById(int id)
        {
            return base.GetById(id);
        }

        [HttpGet("{id}/availability")]
        public ActionResult<List<SpotTypeAvailability>> GetAvailability(
            int id,
            [FromQuery] DateTime from,
            [FromQuery] DateTime to)
        {
            return Ok(_service.GetAvailability(id, from, to));
        }

        // Public city lookup for unauthenticated clients (map/search bootstrap before login).
        [AllowAnonymous]
        [HttpGet("cities")]
        public ActionResult<List<CityCoordinate>> GetCities()
        {
            return Ok(_service.GetCityCoordinates());
        }

        [Authorize]
        [HttpGet("names")]
        public ActionResult<List<ParkingLocationName>> GetParkingLocationNames()
        {
            return Ok(_service.GetParkingLocationNames());
        }

        [Authorize]
        [HttpGet("recommendations")]
        public ActionResult<List<ParkingLocation>> GetRecommendations(
            [FromQuery] int? cityId = null,
            [FromQuery] double? lat = null,
            [FromQuery] double? lon = null,
            [FromQuery] int count = 3)
        {
            var userIdClaim = User.FindFirst("UserId")?.Value 
                ?? User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            
            if (userIdClaim == null || !int.TryParse(userIdClaim, out int userId))
            {
                return Unauthorized("User not authenticated");
            }

            var recommendations = _service.GetRecommendationScores(userId, cityId, lat, lon, count);
            return Ok(recommendations);
        }

        [Authorize(Roles = "Admin")]
        public override ParkingLocation Insert(ParkingLocationInsertRequest request)
        {
            return base.Insert(request);
        }

        [Authorize(Roles = "Admin")]
        public override ParkingLocation Update(int id, ParkingLocationUpdateRequest request)
        {
            return base.Update(id, request);
        }

        [Authorize(Roles = "Admin")]
        public override IActionResult Delete(int id)
        {
            return base.Delete(id);
        }
    }
}


