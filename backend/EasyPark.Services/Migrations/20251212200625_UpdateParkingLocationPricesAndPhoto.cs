using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace EasyPark.Services.Migrations
{
    /// <inheritdoc />
    public partial class UpdateParkingLocationPricesAndPhoto : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<byte[]>(
                name: "Photo",
                table: "ParkingLocations",
                type: "varbinary(max)",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "PriceCovered",
                table: "ParkingLocations",
                type: "decimal(18,2)",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "PriceDisabled",
                table: "ParkingLocations",
                type: "decimal(18,2)",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "PriceElectric",
                table: "ParkingLocations",
                type: "decimal(18,2)",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "PriceRegular",
                table: "ParkingLocations",
                type: "decimal(18,2)",
                nullable: false,
                defaultValue: 0m);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Photo",
                table: "ParkingLocations");

            migrationBuilder.DropColumn(
                name: "PriceCovered",
                table: "ParkingLocations");

            migrationBuilder.DropColumn(
                name: "PriceDisabled",
                table: "ParkingLocations");

            migrationBuilder.DropColumn(
                name: "PriceElectric",
                table: "ParkingLocations");

            migrationBuilder.DropColumn(
                name: "PriceRegular",
                table: "ParkingLocations");
        }
    }
}
