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
    public class NotificationController : BaseCRUDController<Notification, NotificationSearchObject, NotificationInsertRequest, NotificationUpdateRequest>
    {
        protected new INotificationService _service;

        public NotificationController(INotificationService service) : base(service)
        {
            _service = service;
        }

        [HttpGet]
        public override PagedResult<Notification> GetList([FromQuery] NotificationSearchObject searchObject)
        {
            return _service.GetPaged(searchObject);
        }

        [HttpGet("{id}")]
        public override Notification GetById(int id)
        {
            return _service.GetById(id);
        }

        [Authorize(Roles = "Admin")]
        [HttpPost]
        public override Notification Insert(NotificationInsertRequest request)
        {
            return _service.Insert(request);
        }

        [Authorize(Roles = "Admin")]
        [HttpPut("{id}")]
        public override Notification Update(int id, NotificationUpdateRequest request)
        {
            return _service.Update(id, request);
        }

        [Authorize(Roles = "Admin")]
        [HttpDelete("{id}")]
        public override IActionResult Delete(int id)
        {
            return base.Delete(id);
        }

        [HttpPut("{id}/read")]
        public void MarkAsRead(int id)
        {
            _service.MarkAsRead(id);
        }

        [HttpPut("read-all")]
        public void MarkAllAsReadForCurrentUser()
        {
            _service.MarkAllAsReadForCurrentUser();
        }
    }
}
