using System;
using System.Text;
using System.Text.RegularExpressions;

namespace EasyPark.Services.Helpers
{
    public class ValidationHelpers
    {
        public static string CheckPasswordStrength(string password)
        {
            StringBuilder sb = new StringBuilder();

            if (password.Length < 8)
            {
                sb.AppendLine("Password must be at least 8 characters long.");
            }

            if (!(Regex.IsMatch(password, "[a-z]") && Regex.IsMatch(password, "[A-Z]")))
            {
                sb.AppendLine("Password must contain at least one uppercase and one lowercase letter.");
            }

            if (!Regex.IsMatch(password, @"\d"))
            {
                sb.AppendLine("Password must contain at least one number.");
            }

            if (!Regex.IsMatch(password, @"[<>@!#$%^&*+\-=/|~]"))
            {
                sb.AppendLine("Password must contain at least one special character");
            }

            return sb.ToString().Trim();
        }

        public static string CheckPhoneNumber(string phoneNumber)
        {
            if (!Regex.IsMatch(phoneNumber, @"^\d{9,10}$"))
            {
                return "Phone number must contain only digits and be 9 or 10 digits long.";
            }

            return string.Empty;
        }
    }
}
