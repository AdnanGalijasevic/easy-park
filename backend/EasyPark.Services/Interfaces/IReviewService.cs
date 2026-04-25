using EasyPark.Model.Models;
using EasyPark.Model.Requests;
using EasyPark.Model.SearchObjects;

namespace EasyPark.Services.Interfaces
{
    public interface IReviewService : ICRUDService<Review, ReviewSearchObject, ReviewInsertRequest, ReviewUpdateRequest>
    {
    }
}

