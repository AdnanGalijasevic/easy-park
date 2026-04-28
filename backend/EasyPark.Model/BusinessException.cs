using System.Net;

namespace EasyPark.Model
{
    public class BusinessException : UserException
    {
        public BusinessException(string message, HttpStatusCode statusCode = HttpStatusCode.BadRequest)
            : base(message, statusCode)
        {
        }
    }
}
