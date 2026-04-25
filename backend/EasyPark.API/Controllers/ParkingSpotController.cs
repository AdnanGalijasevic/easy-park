using EasyPark.Model;
using EasyPark.Model.Models;
using EasyPark.Model.Requests;
using EasyPark.Model.SearchObjects;
using EasyPark.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace EasyPark.API.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class ParkingSpotController : BaseCRUDController<ParkingSpot, ParkingSpotSearchObject, ParkingSpotInsertRequest, ParkingSpotUpdateRequest>
    {
        protected new IParkingSpotService _service;

        public ParkingSpotController(IParkingSpotService service) : base(service)
        {
            _service = service;
        }

        [Authorize(Roles = "Admin")]
        [HttpGet]
        public override PagedResult<ParkingSpot> GetList([FromQuery] ParkingSpotSearchObject searchObject)
        {
            return _service.GetPaged(searchObject);
        }

        [Authorize(Roles = "Admin")]
        [HttpGet("{id}")]
        public override ParkingSpot GetById(int id)
        {
            return _service.GetById(id);
        }

        [Authorize(Roles = "Admin")]
        [HttpPost]
        public override ParkingSpot Insert(ParkingSpotInsertRequest request)
        {
            return _service.Insert(request);
        }

        [Authorize(Roles = "Admin")]
        [HttpPut("{id}")]
        public override ParkingSpot Update(int id, ParkingSpotUpdateRequest request)
        {
            return _service.Update(id, request);
        }

        [Authorize(Roles = "Admin")]
        [HttpDelete("{id}")]
        public override IActionResult Delete(int id)
        {
            return base.Delete(id);
        }
    }
}

