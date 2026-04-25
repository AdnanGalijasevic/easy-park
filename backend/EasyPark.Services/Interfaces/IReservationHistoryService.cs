using EasyPark.Model.Models;
using EasyPark.Model.SearchObjects;

namespace EasyPark.Services.Interfaces
{
    public interface IReservationHistoryService : IService<ReservationHistory, ReservationHistorySearchObject>
    {
        void LogStatusChange(int reservationId, string? oldStatus, string newStatus, string? changeReason = null, string? notes = null);
    }
}

