using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using EasyPark.Model;
using EasyPark.Model.Models;
using EasyPark.Model.Requests;
using EasyPark.Model.SearchObjects;
using EasyPark.Services.Interfaces;

namespace backend.Controllers
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

