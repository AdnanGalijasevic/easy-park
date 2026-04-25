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
    [Authorize(Roles = "Admin")]
    public class ReportController : BaseCRUDController<Report, ReportSearchObject, ReportInsertRequest, ReportUpdateRequest>
    {
        protected new IReportService _service;

        public ReportController(IReportService service) : base(service)
        {
            _service = service;
        }

        [HttpGet]
        public override PagedResult<Report> GetList([FromQuery] ReportSearchObject searchObject)
        {
            return _service.GetPaged(searchObject);
        }

        [HttpGet("{id}")]
        public override Report GetById(int id)
        {
            return _service.GetById(id);
        }

        [HttpPost]
        public override Report Insert(ReportInsertRequest request)
        {
            return _service.Insert(request);
        }

        [HttpPut("{id}")]
        public override Report Update(int id, ReportUpdateRequest request)
        {
            return _service.Update(id, request);
        }

        [HttpDelete("{id}")]
        public override IActionResult Delete(int id)
        {
            return base.Delete(id);
        }

        [HttpGet("monthly-summary-pdf")]
        public IActionResult MonthlySummaryPdf(
            [FromQuery] int year,
            [FromQuery] int month,
            [FromQuery] bool graphsOnly = false)
        {
            try
            {
                var pdf = _service.GenerateMonthlyAdminReportPdf(year, month, graphsOnly);
                return File(pdf, "application/pdf", $"easypark-admin-report-{year:0000}-{month:00}.pdf");
            }
            catch (UserException ex)
            {
                return BadRequest(new { userError = ex.Message });
            }
        }
    }
}
