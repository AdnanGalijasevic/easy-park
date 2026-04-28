using System.Net;

namespace EasyPark.Model
{
    public class NotFoundException : UserException
    {
        public NotFoundException(string message)
            : base(message, HttpStatusCode.NotFound)
        {
        }
    }
}
