using EasyPark.Services.Helpers;
using Microsoft.EntityFrameworkCore;
using System;
using System.Linq;

namespace EasyPark.Services.Database
{
    public static class DbInitializer
    {
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

            // Mostar (10)
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

            // Sarajevo (1)
            UpsertLocation("Sarajevo Centar Garage", "Sarajevo", "Zmaja od Bosne 25", 43.8563m, 18.4131m, 3.80m, 2.80m, 4.80m, 5.50m, true, true, true, true, true, true, true, true, "Garage", "00:00-24:00", ("SCG-01", "Regular"), ("SCG-02", "Disabled"));

            // Velika Kladuša (1)
            UpsertLocation("Velika Kladuša Main Lot", "Velika Kladuša", "Trg Mladih 3", 45.1858m, 15.8053m, 2.10m, 1.60m, 0.00m, 3.80m, false, true, false, true, false, false, false, false, "OpenLot", "07:00-23:00", ("VKM-01", "Regular"), ("VKM-02", "Covered"));
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
