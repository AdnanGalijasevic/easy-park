using EasyPark.Model.Models;
using EasyPark.Model.Requests;
using EasyPark.Model.SearchObjects;

namespace EasyPark.Services.Interfaces
{
    public interface IReservationService : ICRUDService<Reservation, ReservationSearchObject, ReservationInsertRequest, ReservationUpdateRequest>
    {
        Model.Models.Reservation ConfirmReservation(int id);
    }
}

