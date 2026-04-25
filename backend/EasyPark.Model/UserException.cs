using System;
using System.Net;

namespace EasyPark.Model
{
    public class UserException : Exception
    {
        public HttpStatusCode StatusCode { get; set; }

        public UserException(string message) : base(message)
        {
            StatusCode = HttpStatusCode.BadRequest; // Default to 400
        }

        public UserException(string message, HttpStatusCode statusCode) : base(message)
        {
            StatusCode = statusCode;
        }
    }
}
