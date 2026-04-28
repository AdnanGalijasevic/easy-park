using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace EasyPark.Services.Database
{
    public class EasyParkDbContextFactory : IDesignTimeDbContextFactory<EasyParkDbContext>
    {
        public EasyParkDbContext CreateDbContext(string[] args)
        {
            var optionsBuilder = new DbContextOptionsBuilder<EasyParkDbContext>();
            var connectionString = Environment.GetEnvironmentVariable("_connectionString")
                ?? "Server=localhost,1433;Initial Catalog=220016;User ID=sa;Password=QWEasd123!;TrustServerCertificate=True";
            optionsBuilder.UseSqlServer(connectionString);
            return new EasyParkDbContext(optionsBuilder.Options);
        }
    }
}
