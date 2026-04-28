using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using EasyPark.Model.Models;
using EasyPark.Model.Requests;
using EasyPark.Model.SearchObjects;

namespace EasyPark.Services.Interfaces
{
    public interface IUserService : ICRUDService<User, UserSearchObject, UserInsertRequest, UserUpdateRequest>
    {
        Task<List<Role>> GetUserRolesAsync(int id);
        User Login(string username, string password, string? clientType);
        User GetForAuth(int id);
        User ToggleActiveStatus(int userId, UserToggleActiveRequest request);
        void ForgotPassword(string emailOrUsername);
        void ResetPassword(string token, string newPassword, string confirmPassword);
    }
}
