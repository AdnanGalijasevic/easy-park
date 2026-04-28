namespace EasyPark.Services.Interfaces
{
    public interface ITokenRevocationStore
    {
        void Revoke(string jti, DateTime expiresAt);
        bool IsRevoked(string jti);
        void DeleteExpired();
    }
}
