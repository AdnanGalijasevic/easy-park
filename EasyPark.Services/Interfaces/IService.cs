using System;
using EasyPark.Model;
using EasyPark.Model.SearchObjects;

namespace EasyPark.Services.Interfaces
{
    public interface IService<TModel, TSearch> where TSearch : BaseSearchObject
    {
        public PagedResult<TModel> GetPaged(TSearch search);
        public TModel GetById(int id);
    }
}
