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
    public class BookmarkController : BaseCRUDController<Bookmark, BookmarkSearchObject, BookmarkInsertRequest, BookmarkUpdateRequest>
    {
        protected new IBookmarkService _service;

        public BookmarkController(IBookmarkService service) : base(service)
        {
            _service = service;
        }

        [HttpGet]
        public override PagedResult<Bookmark> GetList([FromQuery] BookmarkSearchObject searchObject)
        {
            return _service.GetPaged(searchObject);
        }

        [HttpGet("{id}")]
        public override Bookmark GetById(int id)
        {
            return _service.GetById(id);
        }

        [HttpPost]
        public override Bookmark Insert(BookmarkInsertRequest request)
        {
            return _service.Insert(request);
        }

        [HttpPut("{id}")]
        public override Bookmark Update(int id, BookmarkUpdateRequest request)
        {
            return _service.Update(id, request);
        }
    }
}

