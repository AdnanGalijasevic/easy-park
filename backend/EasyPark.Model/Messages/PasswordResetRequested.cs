namespace EasyPark.Model.Messages
{
    public class PasswordResetRequested
    {
        public string Email { get; set; } = string.Empty;
        public string Name { get; set; } = string.Empty;
        public string ResetToken { get; set; } = string.Empty;
    }
}
