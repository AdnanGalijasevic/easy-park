using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace EasyPark.Services.Migrations
{
    /// <inheritdoc />
    public partial class AddParkingLocation : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "ParkingLocations",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Name = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: false),
                    Address = table.Column<string>(type: "nvarchar(300)", maxLength: 300, nullable: false),
                    City = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    PostalCode = table.Column<string>(type: "nvarchar(20)", maxLength: 20, nullable: true),
                    Latitude = table.Column<decimal>(type: "decimal(10,8)", nullable: false),
                    Longitude = table.Column<decimal>(type: "decimal(11,8)", nullable: false),
                    Description = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: true),
                    TotalSpots = table.Column<int>(type: "int", nullable: false),
                    PricePerHour = table.Column<decimal>(type: "decimal(10,2)", nullable: false),
                    PricePerDay = table.Column<decimal>(type: "decimal(10,2)", nullable: true),
                    CreatedBy = table.Column<int>(type: "int", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime", nullable: false, defaultValueSql: "(getdate())"),
                    UpdatedAt = table.Column<DateTime>(type: "datetime", nullable: true),
                    IsActive = table.Column<bool>(type: "bit", nullable: false, defaultValue: true),
                    HasVideoSurveillance = table.Column<bool>(type: "bit", nullable: false),
                    HasNightSurveillance = table.Column<bool>(type: "bit", nullable: false),
                    HasDisabledSpots = table.Column<bool>(type: "bit", nullable: false),
                    HasRamp = table.Column<bool>(type: "bit", nullable: false),
                    Is24Hours = table.Column<bool>(type: "bit", nullable: false),
                    HasOnlinePayment = table.Column<bool>(type: "bit", nullable: false),
                    HasElectricCharging = table.Column<bool>(type: "bit", nullable: false),
                    HasCoveredSpots = table.Column<bool>(type: "bit", nullable: false),
                    HasSecurityGuard = table.Column<bool>(type: "bit", nullable: false),
                    MaxVehicleHeight = table.Column<decimal>(type: "decimal(5,2)", nullable: true),
                    AverageRating = table.Column<decimal>(type: "decimal(3,2)", nullable: false, defaultValue: 0m),
                    TotalReviews = table.Column<int>(type: "int", nullable: false, defaultValue: 0),
                    DistanceFromCenter = table.Column<decimal>(type: "decimal(10,2)", nullable: true),
                    ParkingType = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: true),
                    OperatingHours = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: true),
                    SafetyRating = table.Column<decimal>(type: "decimal(3,2)", nullable: true),
                    CleanlinessRating = table.Column<decimal>(type: "decimal(3,2)", nullable: true),
                    AccessibilityRating = table.Column<decimal>(type: "decimal(3,2)", nullable: true),
                    PopularityScore = table.Column<decimal>(type: "decimal(10,2)", nullable: true),
                    LastMaintenanceDate = table.Column<DateTime>(type: "datetime", nullable: true),
                    HasWifi = table.Column<bool>(type: "bit", nullable: false),
                    HasRestroom = table.Column<bool>(type: "bit", nullable: false),
                    HasAttendant = table.Column<bool>(type: "bit", nullable: false),
                    PaymentOptions = table.Column<string>(type: "nvarchar(200)", maxLength: 200, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ParkingLocations", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ParkingLocations_User",
                        column: x => x.CreatedBy,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_ParkingLocations_CreatedBy",
                table: "ParkingLocations",
                column: "CreatedBy");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ParkingLocations");
        }
    }
}
