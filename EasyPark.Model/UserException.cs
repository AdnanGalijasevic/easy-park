using System;

namespace EasyPark.Model
{
    public class UserException : Exception
    {
        public UserException(string message) : base(message)
        {

        }
    }
}
