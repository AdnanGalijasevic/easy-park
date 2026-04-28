using EasyPark.Services.Helpers;
using Microsoft.EntityFrameworkCore;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace EasyPark.Services.Database
{
    public static class DbInitializer
    {
        private const string ParkingPhotoBase64 = "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";

        public static void Seed(EasyParkDbContext context)
        {
            SeedCityCoordinates(context);
            SeedCities(context);

            if (!context.Roles.Any())
            {
                var adminRole = new Role { Name = "Admin" };
                var userRole = new Role { Name = "User" };

                context.Roles.AddRange(adminRole, userRole);
                context.SaveChanges();

                var adminSalt = HashGenerator.GenerateSalt();
                var adminUser = new User
                {
                    FirstName = "Admin",
                    LastName = "User",
                    Username = "desktop",
                    Email = "admin@easypark.com",
                    Phone = "123456789",
                    BirthDate = new DateOnly(1990, 1, 1),
                    PasswordHash = HashGenerator.GenerateHash(adminSalt, "Test123!"),
                    PasswordSalt = adminSalt,
                    IsActive = true,
                    CreatedAt = DateTime.UtcNow
                };

                context.Users.Add(adminUser);
                context.SaveChanges();

                context.UserRoles.Add(new UserRole
                {
                    UserId = adminUser.Id,
                    RoleId = adminRole.Id
                });

                var userSalt = HashGenerator.GenerateSalt();
                var regularUser = new User
                {
                    FirstName = "Mobile",
                    LastName = "User",
                    Username = "mobile",
                    Email = "user@easypark.com",
                    Phone = "987654321",
                    BirthDate = new DateOnly(1995, 5, 15),
                    PasswordHash = HashGenerator.GenerateHash(userSalt, "Test123!"),
                    PasswordSalt = userSalt,
                    IsActive = true,
                    CreatedAt = DateTime.UtcNow
                };

                context.Users.Add(regularUser);
                context.SaveChanges();

                context.UserRoles.Add(new UserRole
                {
                    UserId = regularUser.Id,
                    RoleId = userRole.Id
                });

                context.SaveChanges();
            }

            EnsureDefaultUsers(context);
            SeedParkingLocations(context);
            SeedDemoUsers(context);
            SeedMostarReviews(context);
        }

        private static void EnsureDefaultUsers(EasyParkDbContext context)
        {
            const string defaultPassword = "test";

            var adminRoleId = context.Roles.Where(r => r.Name == "Admin").Select(r => (int?)r.Id).FirstOrDefault();
            var userRoleId = context.Roles.Where(r => r.Name == "User").Select(r => (int?)r.Id).FirstOrDefault();
            if (!adminRoleId.HasValue || !userRoleId.HasValue)
                return;

            void UpsertUser(string username, string firstName, string lastName, string email, string phone, DateOnly birthDate, int roleId)
            {
                var user = context.Users.FirstOrDefault(u => u.Username == username);
                if (user == null)
                {
                    var salt = HashGenerator.GenerateSalt();
                    user = new User
                    {
                        FirstName = firstName,
                        LastName = lastName,
                        Username = username,
                        Email = email,
                        Phone = phone,
                        BirthDate = birthDate,
                        PasswordHash = HashGenerator.GenerateHash(salt, defaultPassword),
                        PasswordSalt = salt,
                        IsActive = true,
                        CreatedAt = DateTime.UtcNow
                    };
                    context.Users.Add(user);
                    context.SaveChanges();
                }
                else
                {
                    var salt = HashGenerator.GenerateSalt();
                    user.FirstName = firstName;
                    user.LastName = lastName;
                    user.Email = email;
                    user.Phone = phone;
                    user.IsActive = true;
                    user.PasswordSalt = salt;
                    user.PasswordHash = HashGenerator.GenerateHash(salt, defaultPassword);
                    context.SaveChanges();
                }

                var hasRole = context.UserRoles.Any(ur => ur.UserId == user.Id && ur.RoleId == roleId);
                if (!hasRole)
                {
                    context.UserRoles.Add(new UserRole
                    {
                        UserId = user.Id,
                        RoleId = roleId
                    });
                    context.SaveChanges();
                }
            }

            UpsertUser("desktop", "Admin", "User", "admin@easypark.com", "123456789", new DateOnly(1990, 1, 1), adminRoleId.Value);
            UpsertUser("mobile", "Mobile", "User", "user@easypark.com", "987654321", new DateOnly(1995, 5, 15), userRoleId.Value);
        }

        private static void SeedDemoUsers(EasyParkDbContext context)
        {
            var userRoleId = context.Roles
                .Where(r => r.Name == "User")
                .Select(r => (int?)r.Id)
                .FirstOrDefault();

            if (!userRoleId.HasValue)
                return;

            for (var i = 1; i <= 10; i++)
            {
                var username = $"user{i}";
                var email = $"{username}@easypark.com";
                var password = $"{username}#123";
                var phone = $"061000{i:000}";
                var birthDate = new DateOnly(1990 + (i % 10), ((i - 1) % 12) + 1, ((i - 1) % 28) + 1);

                var user = context.Users.FirstOrDefault(u => u.Username == username);
                if (user == null)
                {
                    var salt = HashGenerator.GenerateSalt();
                    user = new User
                    {
                        FirstName = $"User{i}",
                        LastName = "Demo",
                        Username = username,
                        Email = email,
                        Phone = phone,
                        BirthDate = birthDate,
                        PasswordSalt = salt,
                        PasswordHash = HashGenerator.GenerateHash(salt, password),
                        IsActive = true,
                        CreatedAt = DateTime.UtcNow
                    };
                    context.Users.Add(user);
                    context.SaveChanges();
                }
                else
                {
                    var salt = HashGenerator.GenerateSalt();
                    user.FirstName = $"User{i}";
                    user.LastName = "Demo";
                    user.Email = email;
                    user.Phone = phone;
                    user.BirthDate = birthDate;
                    user.IsActive = true;
                    user.PasswordSalt = salt;
                    user.PasswordHash = HashGenerator.GenerateHash(salt, password);
                    context.SaveChanges();
                }

                var hasRole = context.UserRoles.Any(ur => ur.UserId == user.Id && ur.RoleId == userRoleId.Value);
                if (!hasRole)
                {
                    context.UserRoles.Add(new UserRole
                    {
                        UserId = user.Id,
                        RoleId = userRoleId.Value
                    });
                    context.SaveChanges();
                }
            }
        }

        private static void SeedParkingLocations(EasyParkDbContext context)
        {
            var createdByUserId = context.Users
                .Where(u => u.Username == "desktop")
                .Select(u => (int?)u.Id)
                .FirstOrDefault()
                ?? context.Users.Select(u => (int?)u.Id).FirstOrDefault();

            if (!createdByUserId.HasValue)
                return;

            var now = DateTime.UtcNow;
            var selectedSeedPhoto = GetUserProvidedParkingPhoto();

            void UpsertLocation(
                string name,
                string city,
                string address,
                decimal lat,
                decimal lng,
                decimal regular,
                decimal disabled,
                decimal electric,
                decimal covered,
                bool is24h,
                bool hasVideo,
                bool hasNight,
                bool hasOnlinePayment,
                bool hasSecurity,
                bool hasWifi,
                bool hasRestroom,
                bool hasAttendant,
                string parkingType,
                string operatingHours,
                params (string SpotNumber, string SpotType)[] spots)
            {
                var cityEntity = context.Cities.FirstOrDefault(c => c.Name == city);
                if (cityEntity == null)
                {
                    throw new InvalidOperationException($"City '{city}' must exist before seeding parking locations.");
                }

                var location = context.ParkingLocations
                    .FirstOrDefault(x => x.Name == name && x.CityId == cityEntity.Id);

                if (location == null)
                {
                    location = new ParkingLocation
                    {
                        Name = name,
                        CityId = cityEntity.Id,
                        Address = address,
                        Latitude = lat,
                        Longitude = lng,
                        Description = $"Seeded test location in {city}",
                        PostalCode = null,
                        PricePerHour = regular,
                        PricePerDay = null,
                        PriceRegular = regular,
                        PriceDisabled = disabled,
                        PriceElectric = electric,
                        PriceCovered = covered,
                        CreatedBy = createdByUserId.Value,
                        CreatedAt = now,
                        IsActive = true,
                        HasVideoSurveillance = hasVideo,
                        HasNightSurveillance = hasNight,
                        HasRamp = spots.Any(s => s.SpotType == "Disabled"),
                        Is24Hours = is24h,
                        HasOnlinePayment = hasOnlinePayment,
                        HasSecurityGuard = hasSecurity,
                        MaxVehicleHeight = 2.20m,
                        AverageRating = 0,
                        TotalReviews = 0,
                        ParkingType = parkingType,
                        OperatingHours = operatingHours,
                        HasWifi = hasWifi,
                        HasRestroom = hasRestroom,
                        HasAttendant = hasAttendant,
                        PaymentOptions = "Cash,Card"
                    };
                    if (selectedSeedPhoto != null && ShouldApplyUserPhoto(name))
                    {
                        location.Photo = selectedSeedPhoto;
                    }
                    context.ParkingLocations.Add(location);
                    context.SaveChanges();
                }
                else
                {
                    location.Address = address;
                    location.Latitude = lat;
                    location.Longitude = lng;
                    location.PricePerHour = regular;
                    location.PriceRegular = regular;
                    location.PriceDisabled = disabled;
                    location.PriceElectric = electric;
                    location.PriceCovered = covered;
                    location.Is24Hours = is24h;
                    location.HasVideoSurveillance = hasVideo;
                    location.HasNightSurveillance = hasNight;
                    location.HasOnlinePayment = hasOnlinePayment;
                    location.HasSecurityGuard = hasSecurity;
                    location.HasWifi = hasWifi;
                    location.HasRestroom = hasRestroom;
                    location.HasAttendant = hasAttendant;
                    location.ParkingType = parkingType;
                    location.OperatingHours = operatingHours;
                    location.HasRamp = spots.Any(s => s.SpotType == "Disabled");
                    location.IsActive = true;
                    if (selectedSeedPhoto != null && ShouldApplyUserPhoto(name))
                    {
                        location.Photo = selectedSeedPhoto;
                    }
                    location.UpdatedAt = now;
                    context.SaveChanges();
                }

                foreach (var spot in spots)
                {
                    var existingSpot = context.ParkingSpots.FirstOrDefault(s =>
                        s.ParkingLocationId == location.Id &&
                        s.SpotNumber == spot.SpotNumber);

                    if (existingSpot == null)
                    {
                        context.ParkingSpots.Add(new ParkingSpot
                        {
                            ParkingLocationId = location.Id,
                            SpotNumber = spot.SpotNumber,
                            SpotType = spot.SpotType,
                            IsActive = true,
                            IsOccupied = false,
                            CreatedAt = now
                        });
                    }
                    else
                    {
                        existingSpot.SpotType = spot.SpotType;
                        existingSpot.IsActive = true;
                    }
                }

                context.SaveChanges();
            }

            UpsertLocation("Mostar Old Town Garage", "Mostar", "Maršala Tita 12", 43.3438m, 17.8078m, 3.00m, 2.00m, 4.00m, 5.00m, true, true, true, true, true, true, true, false, "Garage", "00:00-24:00", ("MOT-01", "Regular"), ("MOT-02", "Covered"));
            UpsertLocation("Mostar Riverside Lot", "Mostar", "Kneza Domagoja 8", 43.3481m, 17.8122m, 2.50m, 2.00m, 0.00m, 0.00m, false, true, false, true, false, false, false, false, "OpenLot", "07:00-22:00", ("MRS-01", "Regular"), ("MRS-02", "Disabled"));
            UpsertLocation("Mostar University Parking", "Mostar", "Matice Hrvatske 4", 43.3472m, 17.8015m, 2.00m, 1.50m, 3.50m, 0.00m, false, false, false, true, false, true, false, false, "Street", "06:00-23:00", ("MUP-01", "Regular"), ("MUP-02", "Electric"));
            UpsertLocation("Mostar South Hub", "Mostar", "Biskupa Čule 15", 43.3367m, 17.8044m, 2.80m, 2.20m, 0.00m, 4.20m, true, true, true, true, true, true, true, true, "Garage", "00:00-24:00", ("MSH-01", "Regular"), ("MSH-02", "Covered"));
            UpsertLocation("Mostar East Point", "Mostar", "Dubrovacka 23", 43.3521m, 17.8210m, 2.20m, 0.00m, 3.20m, 0.00m, false, false, false, false, false, false, false, false, "OpenLot", "08:00-20:00", ("MEP-01", "Regular"), ("MEP-02", "Electric"));
            UpsertLocation("Mostar City Mall Parking", "Mostar", "Fra Didaka Buntica 1", 43.3410m, 17.7930m, 3.20m, 2.20m, 3.80m, 4.80m, true, true, true, true, true, true, true, true, "Garage", "00:00-24:00", ("MCM-01", "Regular"), ("MCM-02", "Disabled"));
            UpsertLocation("Mostar West Station Lot", "Mostar", "Ante Starčevića 44", 43.3394m, 17.7899m, 1.80m, 1.50m, 0.00m, 0.00m, false, true, false, false, false, false, false, false, "OpenLot", "07:00-21:00", ("MWS-01", "Regular"));
            UpsertLocation("Mostar Green Zone Parking", "Mostar", "Bleiburskih žrtava 9", 43.3505m, 17.7988m, 2.60m, 1.90m, 3.40m, 0.00m, false, true, true, true, false, true, false, false, "Street", "06:00-22:00", ("MGZ-01", "Regular"), ("MGZ-02", "Electric"));
            UpsertLocation("Mostar Arena Deck", "Mostar", "Kralja Tomislava 2", 43.3459m, 17.8153m, 3.50m, 2.50m, 4.50m, 5.20m, true, true, true, true, true, true, true, true, "Garage", "00:00-24:00", ("MAD-01", "Regular"), ("MAD-02", "Covered"));
            UpsertLocation("Mostar Budget Parking", "Mostar", "Rade Bitange 11", 43.3446m, 17.8023m, 1.50m, 1.20m, 0.00m, 0.00m, false, false, false, false, false, false, false, false, "OpenLot", "08:00-18:00", ("MBP-01", "Regular"), ("MBP-02", "Regular"));

            UpsertLocation("Sarajevo Centar Garage", "Sarajevo", "Zmaja od Bosne 25", 43.8563m, 18.4131m, 3.80m, 2.80m, 4.80m, 5.50m, true, true, true, true, true, true, true, true, "Garage", "00:00-24:00", ("SCG-01", "Regular"), ("SCG-02", "Disabled"));

            UpsertLocation("Velika Kladuša Main Lot", "Velika Kladuša", "Trg Mladih 3", 45.1858m, 15.8053m, 2.10m, 1.60m, 0.00m, 3.80m, false, true, false, true, false, false, false, false, "OpenLot", "07:00-23:00", ("VKM-01", "Regular"), ("VKM-02", "Covered"));
        }

        private static void SeedMostarReviews(EasyParkDbContext context)
        {
            var mostarCityId = context.Cities
                .Where(c => c.Name == "Mostar")
                .Select(c => (int?)c.Id)
                .FirstOrDefault();

            if (!mostarCityId.HasValue)
                return;

            var mostarLocations = context.ParkingLocations
                .Where(pl => pl.CityId == mostarCityId.Value)
                .OrderBy(pl => pl.Id)
                .ToList();

            if (!mostarLocations.Any())
                return;

            var demoUsers = context.Users
                .Where(u => u.Username.StartsWith("user"))
                .OrderBy(u => u.Username)
                .Take(10)
                .ToList();

            if (!demoUsers.Any())
                return;

            var seededComments = new[]
            {
                "Excellent location and easy access.",
                "Clean parking and clear spot markings.",
                "Great value for money in this area.",
                "Good security presence and lighting.",
                "Online payment works smoothly.",
                "Very convenient for city center errands.",
                "Reliable availability at peak hours.",
                "Well maintained and easy to navigate.",
                "Good option for longer stays.",
                "Friendly staff and quick entry."
            };

            var now = DateTime.UtcNow;
            foreach (var location in mostarLocations)
            {
                for (var i = 0; i < demoUsers.Count; i++)
                {
                    var user = demoUsers[i];
                    var rating = 4 + ((location.Id + i) % 2); // 4 or 5 to boost recommendation signal
                    var comment = $"{seededComments[i % seededComments.Length]} (Mostar seed #{i + 1})";

                    var review = context.Reviews.FirstOrDefault(r =>
                        r.UserId == user.Id &&
                        r.ParkingLocationId == location.Id);

                    if (review == null)
                    {
                        context.Reviews.Add(new Review
                        {
                            UserId = user.Id,
                            ParkingLocationId = location.Id,
                            Rating = rating,
                            Comment = comment,
                            CreatedAt = now.AddMinutes(-(location.Id + i))
                        });
                    }
                    else
                    {
                        review.Rating = rating;
                        review.Comment = comment;
                        review.UpdatedAt = now;
                    }
                }
            }

            context.SaveChanges();

            foreach (var location in mostarLocations)
            {
                var locationReviews = context.Reviews.Where(r => r.ParkingLocationId == location.Id).ToList();
                location.TotalReviews = locationReviews.Count;
                location.AverageRating = locationReviews.Any()
                    ? Math.Round((decimal)locationReviews.Average(r => r.Rating), 2)
                    : 0;
                location.UpdatedAt = now;
            }

            context.SaveChanges();
        }

        private static bool ShouldApplyUserPhoto(string parkingLocationName)
        {
            return parkingLocationName is
                "Mostar Old Town Garage" or
                "Mostar City Mall Parking" or
                "Mostar Arena Deck";
        }

        private static byte[]? GetUserProvidedParkingPhoto()
        {
            if (string.IsNullOrWhiteSpace(ParkingPhotoBase64))
            {
                return null;
            }

            try
            {
                return Convert.FromBase64String(ParkingPhotoBase64.Trim());
            }
            catch (FormatException)
            {
                return null;
            }
        }

        private static void SeedCityCoordinates(EasyParkDbContext context)
        {
            var cities = new (string City, decimal Lat, decimal Lng)[]
            {
                ("Banovići", 44.4089m, 18.5292m),
                ("Banja Luka", 44.7725m, 17.1860m),
                ("Bihać", 44.8146m, 15.8691m),
                ("Bijeljina", 44.7569m, 19.2161m),
                ("Bileća", 42.8721m, 18.4285m),
                ("Bosanski Brod", 45.1435m, 18.0067m),
                ("Bosanska Dubica", 45.1767m, 16.8122m),
                ("Bosanska Gradiška", 45.1466m, 17.2551m),
                ("Bosansko Grahovo", 44.1808m, 16.3657m),
                ("Bosanska Krupa", 44.8824m, 16.1577m),
                ("Bosanski Novi", 45.0464m, 16.3761m),
                ("Bosanski Petrovac", 44.5560m, 16.3694m),
                ("Bosanski Šamac", 45.0594m, 18.4678m),
                ("Bratunac", 44.1850m, 19.3322m),
                ("Brčko", 44.8771m, 18.8095m),
                ("Breza", 44.0183m, 18.2608m),
                ("Bugojno", 44.0559m, 17.4509m),
                ("Busovača", 44.0968m, 17.8797m),
                ("Bužim", 45.0625m, 16.0317m),
                ("Cazin", 44.9665m, 15.9422m),
                ("Čajniče", 43.5568m, 19.0715m),
                ("Čapljina", 43.1134m, 17.7051m),
                ("Čelić", 44.7225m, 18.8200m),
                ("Čelinac", 44.7242m, 17.3194m),
                ("Čitluk", 43.2267m, 17.6963m),
                ("Derventa", 44.9767m, 17.9070m),
                ("Doboj", 44.7314m, 18.0847m),
                ("Donji Vakuf", 44.1446m, 17.3985m),
                ("Drvar", 44.3748m, 16.3827m),
                ("Foča", 43.5056m, 18.7781m),
                ("Fojnica", 43.9592m, 17.9031m),
                ("Gacko", 43.1672m, 18.5353m),
                ("Glamoč", 44.0458m, 16.8486m),
                ("Goražde", 43.6675m, 18.9756m),
                ("Gornji Vakuf", 43.9381m, 17.5878m),
                ("Gračanica", 44.7000m, 18.3100m),
                ("Gradačac", 44.8794m, 18.4267m),
                ("Grude", 43.3719m, 17.4147m),
                ("Hadžići", 43.8222m, 18.2014m),
                ("Han-Pijesak", 44.0833m, 18.9500m),
                ("Hlivno", 43.8269m, 17.0078m),
                ("Ilijaš", 43.9508m, 18.2708m),
                ("Jablanica", 43.6603m, 17.7617m),
                ("Jajce", 44.3411m, 17.2703m),
                ("Kakanj", 44.1292m, 18.1222m),
                ("Kalesija", 44.4433m, 18.8714m),
                ("Kalinovik", 43.5019m, 18.4458m),
                ("Kiseljak", 43.9422m, 18.0817m),
                ("Kladanj", 44.2261m, 18.6922m),
                ("Ključ", 44.5325m, 16.7761m),
                ("Konjic", 43.6514m, 17.9608m),
                ("Kotor-Varoš", 44.6194m, 17.3714m),
                ("Kreševo", 43.8656m, 18.0469m),
                ("Kupres", 43.9908m, 17.2789m),
                ("Laktaši", 44.9083m, 17.3014m),
                ("Lopare", 44.6342m, 18.8456m),
                ("Lukavac", 44.5317m, 18.5283m),
                ("Ljubinje", 42.9506m, 18.0872m),
                ("Ljubuški", 43.1969m, 17.5453m),
                ("Maglaj", 44.5456m, 18.1017m),
                ("Modriča", 44.9558m, 18.2972m),
                ("Mostar", 43.3438m, 17.8078m),
                ("Mrkonjić-Grad", 44.4172m, 17.0839m),
                ("Neum", 42.9228m, 17.6156m),
                ("Nevesinje", 43.2586m, 18.1136m),
                ("Novi Travnik", 44.1706m, 17.6583m),
                ("Odžak", 45.0114m, 18.3267m),
                ("Olovo", 44.1283m, 18.5817m),
                ("Orašje", 45.0322m, 18.6317m),
                ("Pale", 43.8172m, 18.5583m),
                ("Posušje", 43.4739m, 17.3325m),
                ("Prijedor", 44.9794m, 16.7139m),
                ("Prnjavor", 44.8703m, 17.6622m),
                ("Prozor", 43.8211m, 17.6083m),
                ("Rogatica", 43.7981m, 19.0031m),
                ("Rudo", 43.6194m, 19.3669m),
                ("Sanski Most", 44.7667m, 16.6667m),
                ("Sarajevo", 43.8563m, 18.4131m),
                ("Skender-Vakuf", 44.4911m, 17.3308m),
                ("Sokolac", 43.9378m, 18.8008m),
                ("Srbac", 45.0969m, 17.5256m),
                ("Srebrenica", 44.1031m, 19.2978m),
                ("Srebrenik", 44.7058m, 18.4878m),
                ("Stolac", 43.0844m, 17.9603m),
                ("Šekovići", 44.2989m, 18.8553m),
                ("Šipovo", 44.2828m, 17.0850m),
                ("Široki Brijeg", 43.3822m, 17.5931m),
                ("Teslić", 44.6067m, 17.8594m),
                ("Tešanj", 44.6125m, 17.9856m),
                ("Tomislav-Grad", 43.7183m, 17.2256m),
                ("Travnik", 44.2264m, 17.6658m),
                ("Trebinje", 42.7119m, 18.3436m),
                ("Trnovo", 43.6667m, 18.4489m),
                ("Tuzla", 44.5375m, 18.6661m),
                ("Ugljevik", 44.6931m, 18.9950m),
                ("Vareš", 44.1644m, 18.3283m),
                ("Velika Kladuša", 45.1858m, 15.8053m),
                ("Visoko", 43.9889m, 18.1781m),
                ("Višegrad", 43.7831m, 19.2928m),
                ("Vitez", 44.1558m, 17.7900m),
                ("Vlasenica", 44.1817m, 18.9408m),
                ("Zavidovići", 44.4447m, 18.1492m),
                ("Zenica", 44.2017m, 17.9047m),
                ("Zvornik", 44.3853m, 19.1028m),
                ("Žepa", 43.9536m, 19.1294m),
                ("Žepče", 44.4267m, 18.0375m),
                ("Živinice", 44.4492m, 18.6497m),
                ("Bijelo Polje", 43.0392m, 19.7476m),
                ("Gusinje", 42.5619m, 19.8336m),
                ("Nova Varoš", 43.4564m, 19.8144m),
                ("Novi Pazar", 43.1367m, 20.5122m),
                ("Plav", 42.5964m, 19.9450m),
                ("Pljevlja", 43.3561m, 19.3583m),
                ("Priboj", 43.5858m, 19.5317m),
                ("Prijepolje", 43.3911m, 19.6483m),
                ("Rožaje", 42.8422m, 20.1669m),
                ("Sjenica", 43.2728m, 19.9989m),
                ("Tutin", 42.9911m, 20.3311m),
            };

            var existing = context.CityCoordinates.ToList();
            var existingByCity = existing.ToDictionary(c => c.City, c => c);

            foreach (var city in cities)
            {
                if (existingByCity.TryGetValue(city.City, out var row))
                {
                    row.Latitude = city.Lat;
                    row.Longitude = city.Lng;
                }
                else
                {
                    context.CityCoordinates.Add(new CityCoordinate
                    {
                        City = city.City,
                        Latitude = city.Lat,
                        Longitude = city.Lng
                    });
                }
            }

            context.SaveChanges();
        }

        private static void SeedCities(EasyParkDbContext context)
        {
            var cityNames = context.CityCoordinates
                .Select(c => c.City)
                .Distinct()
                .ToList();

            var existing = context.Cities
                .Select(c => c.Name)
                .ToHashSet();

            foreach (var cityName in cityNames)
            {
                if (existing.Contains(cityName))
                {
                    continue;
                }

                context.Cities.Add(new City { Name = cityName });
            }

            context.SaveChanges();
        }
    }
}
