using EasyPark.Model.Models;
using EasyPark.Model.Requests;
using EasyPark.Model.SearchObjects;

namespace EasyPark.Services.Interfaces
{
    public interface IReportService : ICRUDService<Report, ReportSearchObject, ReportInsertRequest, ReportUpdateRequest>
    {
        byte[] GenerateMonthlyAdminReportPdf(int year, int month, bool graphsOnly = false);
    }
}

