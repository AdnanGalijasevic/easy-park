using EasyPark.Model;
using EasyPark.Model.Models;
using EasyPark.Model.SearchObjects;
using EasyPark.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace EasyPark.API.Controllers
{
    [ApiController]
    [Route("[controller]")]
    [Authorize(Roles = "Admin")]
    public class ReservationHistoryController : BaseController<ReservationHistory, ReservationHistorySearchObject>
    {
        protected new IReservationHistoryService _service;

        public ReservationHistoryController(IReservationHistoryService service) : base(service)
        {
            _service = service;
        }

        [HttpGet]
        public override PagedResult<ReservationHistory> GetList([FromQuery] ReservationHistorySearchObject searchObject)
        {
            return _service.GetPaged(searchObject);
        }

        [HttpGet("{id}")]
        public override ReservationHistory GetById(int id)
        {
            return _service.GetById(id);
        }
    }
}
