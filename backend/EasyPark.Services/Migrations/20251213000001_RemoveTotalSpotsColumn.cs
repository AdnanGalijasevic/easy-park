using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace EasyPark.Services.Migrations
{
    /// <inheritdoc />
    public partial class RemoveTotalSpotsColumn : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Remove TotalSpots column from ParkingLocations table
            migrationBuilder.DropColumn(
                name: "TotalSpots",
                table: "ParkingLocations");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Restore TotalSpots column if migration is rolled back
            migrationBuilder.AddColumn<int>(
                name: "TotalSpots",
                table: "ParkingLocations",
                type: "int",
                nullable: false,
                defaultValue: 0);
        }
    }
}

