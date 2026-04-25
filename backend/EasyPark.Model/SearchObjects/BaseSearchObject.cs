using System;

namespace EasyPark.Model.SearchObjects
{
    public class BaseSearchObject
    {
        private const int DefaultPage = 0;
        private const int DefaultPageSize = 20;
        private const int MaxPageSize = 100;

        public int? Page { get; set; } = DefaultPage;
        public int? PageSize { get; set; } = DefaultPageSize;

        public int GetSafePage()
        {
            return Page.GetValueOrDefault(DefaultPage) < 0 ? DefaultPage : Page.GetValueOrDefault(DefaultPage);
        }

        public int GetSafePageSize()
        {
            var requested = PageSize.GetValueOrDefault(DefaultPageSize);
            if (requested <= 0)
            {
                return DefaultPageSize;
            }

            return requested > MaxPageSize ? MaxPageSize : requested;
        }
    }
}
