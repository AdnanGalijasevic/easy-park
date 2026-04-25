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
    public class ReviewController : BaseCRUDController<Review, ReviewSearchObject, ReviewInsertRequest, ReviewUpdateRequest>
    {
        protected new IReviewService _service;

        public ReviewController(IReviewService service) : base(service)
        {
            _service = service;
        }

        [HttpGet]
        public override PagedResult<Review> GetList([FromQuery] ReviewSearchObject searchObject)
        {
            return _service.GetPaged(searchObject);
        }

        [HttpGet("{id}")]
        public override Review GetById(int id)
        {
            return _service.GetById(id);
        }

        [HttpPost]
        public override Review Insert(ReviewInsertRequest request)
        {
            return _service.Insert(request);
        }

        [HttpPut("{id}")]
        public override Review Update(int id, ReviewUpdateRequest request)
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


