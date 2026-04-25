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
    [Authorize]
    public class ReservationController : BaseCRUDController<Reservation, ReservationSearchObject, ReservationInsertRequest, ReservationUpdateRequest>
    {
        protected new IReservationService _service;

        public ReservationController(IReservationService service) : base(service)
        {
            _service = service;
        }

        [HttpGet]
        public override PagedResult<Reservation> GetList([FromQuery] ReservationSearchObject searchObject)
        {
            return _service.GetPaged(searchObject);
        }

        [HttpGet("{id}")]
        public override Reservation GetById(int id)
        {
            return _service.GetById(id);
        }

        [HttpPost]
        public override Reservation Insert(ReservationInsertRequest request)
        {
            return _service.Insert(request);
        }

        [HttpPut("{id}")]
        public override Reservation Update(int id, ReservationUpdateRequest request)
        {
            return _service.Update(id, request);
        }

        [HttpPut("{id}/cancel")]
        public Reservation Cancel(int id)
        {
            var request = new ReservationUpdateRequest { Status = "Cancelled" };
            return _service.Update(id, request);
        }

        [Authorize(Roles = "Admin")]
        [HttpPut("{id}/confirm")]
        public Reservation Confirm(int id)
        {
            return _service.ConfirmReservation(id);
        }
    }
}

