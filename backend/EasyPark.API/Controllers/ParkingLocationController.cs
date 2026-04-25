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

        [AllowAnonymous]
        public override PagedResult<ParkingLocation> GetList([FromQuery] ParkingLocationSearchObject searchObject)
        {
            return base.GetList(searchObject);
        }

        [AllowAnonymous]
        public override ParkingLocation GetById(int id)
        {
            return base.GetById(id);
        }

        [AllowAnonymous]
        [HttpGet("{id}/availability")]
        public ActionResult<List<SpotTypeAvailability>> GetAvailability(
            int id,
            [FromQuery] DateTime from,
            [FromQuery] DateTime to)
        {
            if (from == default) from = DateTime.UtcNow.Date;
            if (to == default || to <= from) to = from.AddDays(1);
            return Ok(_service.GetAvailability(id, from, to));
        }

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
        public ActionResult<List<ParkingLocation>> GetRecommendations([FromQuery] int? cityId = null)
        {
            var userIdClaim = User.FindFirst("UserId")?.Value 
                ?? User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            
            if (userIdClaim == null || !int.TryParse(userIdClaim, out int userId))
            {
                return Unauthorized("User not authenticated");
            }

            var recommendations = _service.GetRecommendationScores(userId, cityId);
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
    }
}


