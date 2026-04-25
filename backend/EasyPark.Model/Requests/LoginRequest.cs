using System;

namespace EasyPark.Model.Requests
{
    public class LoginRequest
    {
        public string username { get; set; } = null!;
        public string password { get; set; } = null!;
    }
}
