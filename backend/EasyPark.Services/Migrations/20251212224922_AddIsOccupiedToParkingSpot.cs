using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace EasyPark.Services.Migrations
{
    /// <inheritdoc />
    public partial class AddIsOccupiedToParkingSpot : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "IsOccupied",
                table: "ParkingSpots",
                type: "bit",
                nullable: false,
                defaultValue: false);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "IsOccupied",
                table: "ParkingSpots");
        }
    }
}
