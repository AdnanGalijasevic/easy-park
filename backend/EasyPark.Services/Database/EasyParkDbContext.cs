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
        public virtual DbSet<ParkingSpot> ParkingSpots { get; set; }
        public virtual DbSet<Reservation> Reservations { get; set; }
        public virtual DbSet<Review> Reviews { get; set; }
        public virtual DbSet<Bookmark> Bookmarks { get; set; }
        public virtual DbSet<Transaction> Transactions { get; set; }
        public virtual DbSet<Report> Reports { get; set; }
        public virtual DbSet<ReservationHistory> ReservationHistories { get; set; }
        public virtual DbSet<Notification> Notifications { get; set; }
        public virtual DbSet<CityCoordinate> CityCoordinates { get; set; }
        public virtual DbSet<City> Cities { get; set; }

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
                entity.Property(e => e.PasswordResetToken).HasMaxLength(64);
                entity.Property(e => e.PasswordResetTokenExpiry).HasColumnType("datetime");
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
                entity.Property(e => e.CityId).IsRequired();
                entity.Property(e => e.PostalCode).HasMaxLength(20);
                entity.Property(e => e.Latitude).HasColumnType("decimal(10, 8)").IsRequired();
                entity.Property(e => e.Longitude).HasColumnType("decimal(11, 8)").IsRequired();
                entity.Property(e => e.Description).HasMaxLength(1000);
                // TotalSpots removed from DB - calculated dynamically from ParkingSpots.Count
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

                entity.HasOne(d => d.City)
                    .WithMany(c => c.ParkingLocations)
                    .HasForeignKey(d => d.CityId)
                    .OnDelete(DeleteBehavior.Restrict)
                    .HasConstraintName("FK_ParkingLocations_City");
            });

            modelBuilder.Entity<City>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Name).HasMaxLength(100).IsRequired();
                entity.HasIndex(e => e.Name).IsUnique();
            });

            modelBuilder.Entity<ParkingSpot>(entity =>
            {
                entity.HasKey(e => e.Id).HasName("PK_ParkingSpots");

                entity.Property(e => e.SpotNumber).HasMaxLength(50).IsRequired();
                entity.Property(e => e.SpotType).HasMaxLength(50).IsRequired();
                entity.Property(e => e.CreatedAt)
                    .HasDefaultValueSql("(getdate())")
                    .HasColumnType("datetime");
                entity.Property(e => e.IsActive).HasDefaultValue(true);

                entity.HasOne(d => d.ParkingLocation)
                    .WithMany(p => p.ParkingSpots)
                    .HasForeignKey(d => d.ParkingLocationId)
                    .OnDelete(DeleteBehavior.Restrict)
                    .HasConstraintName("FK_ParkingSpots_ParkingLocation");

                // Unique constraint: SpotNumber must be unique within a ParkingLocation
                entity.HasIndex(e => new { e.ParkingLocationId, e.SpotNumber })
                    .IsUnique()
                    .HasDatabaseName("UQ_ParkingSpots_Location_SpotNumber");
            });

            modelBuilder.Entity<Reservation>(entity =>
            {
                entity.HasKey(e => e.Id).HasName("PK_Reservations");

                entity.Property(e => e.Status).HasMaxLength(50).IsRequired();
                entity.Property(e => e.QRCode).HasMaxLength(200);
                entity.Property(e => e.CancellationReason).HasMaxLength(500);
                entity.Property(e => e.TotalPrice).HasColumnType("decimal(10, 2)").IsRequired();
                entity.Property(e => e.StartTime).HasColumnType("datetime").IsRequired();
                entity.Property(e => e.EndTime).HasColumnType("datetime").IsRequired();
                entity.Property(e => e.ExpectedDuration).HasColumnType("time");
                entity.Property(e => e.CreatedAt)
                    .HasDefaultValueSql("(getdate())")
                    .HasColumnType("datetime");
                entity.Property(e => e.UpdatedAt).HasColumnType("datetime");
                entity.Property(e => e.CancellationAllowed).HasDefaultValue(true);

                entity.HasOne(d => d.User)
                    .WithMany()
                    .HasForeignKey(d => d.UserId)
                    .OnDelete(DeleteBehavior.Restrict)
                    .HasConstraintName("FK_Reservations_User");

                entity.HasOne(d => d.ParkingSpot)
                    .WithMany(p => p.Reservations)
                    .HasForeignKey(d => d.ParkingSpotId)
                    .OnDelete(DeleteBehavior.Restrict)
                    .HasConstraintName("FK_Reservations_ParkingSpot");
            });

            modelBuilder.Entity<Review>(entity =>
            {
                entity.HasKey(e => e.Id).HasName("PK_Reviews");

                entity.Property(e => e.Rating).IsRequired();
                entity.Property(e => e.Comment).HasMaxLength(1000);
                entity.Property(e => e.CreatedAt)
                    .HasDefaultValueSql("(getdate())")
                    .HasColumnType("datetime");
                entity.Property(e => e.UpdatedAt).HasColumnType("datetime");

                entity.HasOne(d => d.User)
                    .WithMany()
                    .HasForeignKey(d => d.UserId)
                    .OnDelete(DeleteBehavior.Restrict)
                    .HasConstraintName("FK_Reviews_User");

                entity.HasOne(d => d.ParkingLocation)
                    .WithMany()
                    .HasForeignKey(d => d.ParkingLocationId)
                    .OnDelete(DeleteBehavior.Restrict)
                    .HasConstraintName("FK_Reviews_ParkingLocation");

                // Unique constraint: User can only have one review per parking location
                entity.HasIndex(e => new { e.UserId, e.ParkingLocationId })
                    .IsUnique()
                    .HasDatabaseName("UQ_Reviews_User_ParkingLocation");
            });

            modelBuilder.Entity<Bookmark>(entity =>
            {
                entity.HasKey(e => e.Id).HasName("PK_Bookmarks");

                entity.Property(e => e.CreatedAt)
                    .HasDefaultValueSql("(getdate())")
                    .HasColumnType("datetime");

                entity.HasOne(d => d.User)
                    .WithMany()
                    .HasForeignKey(d => d.UserId)
                    .OnDelete(DeleteBehavior.Restrict)
                    .HasConstraintName("FK_Bookmarks_User");

                entity.HasOne(d => d.ParkingLocation)
                    .WithMany()
                    .HasForeignKey(d => d.ParkingLocationId)
                    .OnDelete(DeleteBehavior.Restrict)
                    .HasConstraintName("FK_Bookmarks_ParkingLocation");

                // Unique constraint: User can bookmark a location only once
                entity.HasIndex(e => new { e.UserId, e.ParkingLocationId })
                    .IsUnique()
                    .HasDatabaseName("UQ_Bookmarks_User_ParkingLocation");
            });

            modelBuilder.Entity<Transaction>(entity =>
            {
                entity.HasKey(e => e.Id).HasName("PK_Transactions");

                entity.Property(e => e.Amount).HasColumnType("decimal(10, 2)").IsRequired();
                entity.Property(e => e.Currency).HasMaxLength(10).IsRequired();
                entity.Property(e => e.PaymentMethod).HasMaxLength(50).IsRequired();
                entity.Property(e => e.Status).HasMaxLength(50).IsRequired();
                entity.Property(e => e.StripeTransactionId).HasMaxLength(200);
                entity.Property(e => e.StripePaymentIntentId).HasMaxLength(200);
                entity.Property(e => e.PaymentDate).HasColumnType("datetime");
                entity.Property(e => e.CreatedAt)
                    .HasDefaultValueSql("(getdate())")
                    .HasColumnType("datetime");

                entity.HasOne(d => d.User)
                    .WithMany()
                    .HasForeignKey(d => d.UserId)
                    .OnDelete(DeleteBehavior.Restrict)
                    .HasConstraintName("FK_Transactions_User");

                entity.HasOne(d => d.Reservation)
                    .WithOne(r => r.Transaction)
                    .HasForeignKey<Transaction>(d => d.ReservationId)
                    .OnDelete(DeleteBehavior.SetNull)
                    .HasConstraintName("FK_Transactions_Reservation");
            });



            modelBuilder.Entity<Report>(entity =>
            {
                entity.HasKey(e => e.Id).HasName("PK_Reports");

                entity.Property(e => e.ReportType).HasMaxLength(50).IsRequired();
                entity.Property(e => e.PeriodStart).HasColumnType("datetime").IsRequired();
                entity.Property(e => e.PeriodEnd).HasColumnType("datetime").IsRequired();
                entity.Property(e => e.TotalRevenue).HasColumnType("decimal(10, 2)").IsRequired();
                entity.Property(e => e.TotalReservations).IsRequired();
                entity.Property(e => e.AverageRating).HasColumnType("decimal(3, 2)");
                entity.Property(e => e.CreatedAt)
                    .HasDefaultValueSql("(getdate())")
                    .HasColumnType("datetime");

                entity.HasOne(d => d.ParkingLocation)
                    .WithMany()
                    .HasForeignKey(d => d.ParkingLocationId)
                    .OnDelete(DeleteBehavior.SetNull)
                    .HasConstraintName("FK_Reports_ParkingLocation");

                entity.HasOne(d => d.User)
                    .WithMany()
                    .HasForeignKey(d => d.UserId)
                    .OnDelete(DeleteBehavior.Restrict)
                    .HasConstraintName("FK_Reports_User");
            });

            modelBuilder.Entity<ReservationHistory>(entity =>
            {
                entity.HasKey(e => e.Id).HasName("PK_ReservationHistories");

                entity.Property(e => e.OldStatus).HasMaxLength(50);
                entity.Property(e => e.NewStatus).HasMaxLength(50);
                entity.Property(e => e.ChangeReason).HasMaxLength(500);
                entity.Property(e => e.Notes).HasMaxLength(1000);
                entity.Property(e => e.ChangedAt)
                    .HasDefaultValueSql("(getdate())")
                    .HasColumnType("datetime");

                entity.HasOne(d => d.Reservation)
                    .WithMany(r => r.ReservationHistories)
                    .HasForeignKey(d => d.ReservationId)
                    .OnDelete(DeleteBehavior.Restrict)
                    .HasConstraintName("FK_ReservationHistories_Reservation");

                entity.HasOne(d => d.User)
                    .WithMany()
                    .HasForeignKey(d => d.UserId)
                    .OnDelete(DeleteBehavior.Restrict)
                    .HasConstraintName("FK_ReservationHistories_User");
            });

            modelBuilder.Entity<Notification>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.Property(e => e.Title).HasMaxLength(200).IsRequired();
                entity.Property(e => e.Message).HasMaxLength(1000).IsRequired();
                entity.Property(e => e.Type).HasMaxLength(50).IsRequired();
                entity.Property(e => e.IsRead).HasDefaultValue(false);
                entity.Property(e => e.CreatedAt)
                    .HasDefaultValueSql("(getdate())")
                    .HasColumnType("datetime");

                entity.HasOne(d => d.User)
                    .WithMany()
                    .HasForeignKey(d => d.UserId)
                    .OnDelete(DeleteBehavior.Cascade)
                    .HasConstraintName("FK_Notifications_User");
            });

            modelBuilder.Entity<CityCoordinate>(entity =>
            {
                entity.HasKey(e => e.Id);
                entity.Property(e => e.City).HasMaxLength(100).IsRequired();
                entity.Property(e => e.Latitude).HasColumnType("decimal(10, 8)").IsRequired();
                entity.Property(e => e.Longitude).HasColumnType("decimal(11, 8)").IsRequired();
                entity.HasIndex(e => e.City).IsUnique();
            });

            OnModelCreatingPartial(modelBuilder);
        }

        partial void OnModelCreatingPartial(ModelBuilder modelBuilder);
    }
}
