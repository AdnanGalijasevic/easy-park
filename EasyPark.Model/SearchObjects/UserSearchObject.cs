using System;

namespace EasyPark.Model.SearchObjects
{
    public class UserSearchObject : BaseSearchObject
    {
        public string? FTS { get; set; }
        public DateOnly? FromDate { get; set; }
        public DateOnly? ToDate { get; set; }
        public bool? IsActive { get; set; }
    }
}
