using System;
using System.Collections.Generic;

namespace PhonebookApp.Models
{
    public class PagedResult<T>
    {
        public IEnumerable<T> Items { get; set; }
        public int TotalCount { get; set; }
        public int CurrentPage { get; set; }
        public int PageSize { get; set; }

        public int TotalPages
        {
            get { return (int)Math.Ceiling(TotalCount / (double)PageSize); }
        }
    }
}
