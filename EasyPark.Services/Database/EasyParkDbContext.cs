using System;
using Microsoft.EntityFrameworkCore;

namespace EasyPark.Services.Database
{
    public partial class EasyParkDbContext : DbContext
    {
        public EasyParkDbContext()
        {
        }

        public EasyParkDbContext(DbContextOptions<EasyParkDbContext> options)
            : base(options)
        {
        }

        public virtual DbSet<User> Users { get; set; }
        public virtual DbSet<Role> Roles { get; set; }
        public virtual DbSet<UserRole> UserRoles { get; set; }
        public virtual DbSet<ParkingLocation> ParkingLocations { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<User>(entity =>
            {
                entity.HasKey(e => e.Id).HasName("PK__Users__3214EC072EFF9310");

                entity.HasIndex(e => e.Email, "UQ__Users__A9D105340E77BC21").IsUnique();

                entity.Property(e => e.CreatedAt)
                    .HasDefaultValueSql("(getdate())")
                    .HasColumnType("datetime");
                entity.Property(e => e.Email).HasMaxLength(100);
                entity.Property(e => e.FirstName).HasMaxLength(50);
                entity.Property(e => e.LastName).HasMaxLength(50);
                entity.Property(e => e.Phone).HasMaxLength(20);
            });

            modelBuilder.Entity<Role>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Name).HasMaxLength(50).IsRequired();
            });

            modelBuilder.Entity<UserRole>(entity =>
            {
                entity.HasKey(e => e.Id);

                entity.HasOne(d => d.User)
                    .WithMany(p => p.UserRoles)
                    .HasForeignKey(d => d.UserId)
                    .OnDelete(DeleteBehavior.Cascade)
                    .HasConstraintName("FK_UserRoles_User");

                entity.HasOne(d => d.Role)
                    .WithMany(p => p.UserRoles)
                    .HasForeignKey(d => d.RoleId)
                    .OnDelete(DeleteBehavior.Cascade)
                    .HasConstraintName("FK_UserRoles_Role");
            });

            modelBuilder.Entity<ParkingLocation>(entity =>
            {
                entity.HasKey(e => e.Id).HasName("PK_ParkingLocations");

                entity.Property(e => e.Name).HasMaxLength(200).IsRequired();
                entity.Property(e => e.Address).HasMaxLength(300).IsRequired();
                entity.Property(e => e.City).HasMaxLength(100).IsRequired();
                entity.Property(e => e.PostalCode).HasMaxLength(20);
                entity.Property(e => e.Latitude).HasColumnType("decimal(10, 8)").IsRequired();
                entity.Property(e => e.Longitude).HasColumnType("decimal(11, 8)").IsRequired();
                entity.Property(e => e.Description).HasMaxLength(1000);
                entity.Property(e => e.TotalSpots).IsRequired();
                entity.Property(e => e.PricePerHour).HasColumnType("decimal(10, 2)").IsRequired();
                entity.Property(e => e.PricePerDay).HasColumnType("decimal(10, 2)");
                entity.Property(e => e.CreatedAt)
                    .HasDefaultValueSql("(getdate())")
                    .HasColumnType("datetime");
                entity.Property(e => e.UpdatedAt).HasColumnType("datetime");
                entity.Property(e => e.IsActive).HasDefaultValue(true);
                entity.Property(e => e.AverageRating).HasColumnType("decimal(3, 2)").HasDefaultValue(0);
                entity.Property(e => e.TotalReviews).HasDefaultValue(0);
                entity.Property(e => e.MaxVehicleHeight).HasColumnType("decimal(5, 2)");
                entity.Property(e => e.DistanceFromCenter).HasColumnType("decimal(10, 2)");
                entity.Property(e => e.ParkingType).HasMaxLength(50);
                entity.Property(e => e.OperatingHours).HasMaxLength(50);
                entity.Property(e => e.SafetyRating).HasColumnType("decimal(3, 2)");
                entity.Property(e => e.CleanlinessRating).HasColumnType("decimal(3, 2)");
                entity.Property(e => e.AccessibilityRating).HasColumnType("decimal(3, 2)");
                entity.Property(e => e.PopularityScore).HasColumnType("decimal(10, 2)");
                entity.Property(e => e.LastMaintenanceDate).HasColumnType("datetime");
                entity.Property(e => e.PaymentOptions).HasMaxLength(200);

                entity.HasOne(d => d.CreatedByUser)
                    .WithMany()
                    .HasForeignKey(d => d.CreatedBy)
                    .OnDelete(DeleteBehavior.Restrict)
                    .HasConstraintName("FK_ParkingLocations_User");
            });

            OnModelCreatingPartial(modelBuilder);
        }

        partial void OnModelCreatingPartial(ModelBuilder modelBuilder);
    }
}
