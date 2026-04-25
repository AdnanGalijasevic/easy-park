using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace EasyPark.Services.Migrations
{
    /// <inheritdoc />
    public partial class RefactorParkingLocationCityToFk : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "City",
                table: "ParkingLocations");

            migrationBuilder.AddColumn<int>(
                name: "CityId",
                table: "ParkingLocations",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.CreateTable(
                name: "Cities",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    Name = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Cities", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_ParkingLocations_CityId",
                table: "ParkingLocations",
                column: "CityId");

            migrationBuilder.CreateIndex(
                name: "IX_Cities_Name",
                table: "Cities",
                column: "Name",
                unique: true);

            migrationBuilder.AddForeignKey(
                name: "FK_ParkingLocations_City",
                table: "ParkingLocations",
                column: "CityId",
                principalTable: "Cities",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_ParkingLocations_City",
                table: "ParkingLocations");

            migrationBuilder.DropTable(
                name: "Cities");

            migrationBuilder.DropIndex(
                name: "IX_ParkingLocations_CityId",
                table: "ParkingLocations");

            migrationBuilder.DropColumn(
                name: "CityId",
                table: "ParkingLocations");

            migrationBuilder.AddColumn<string>(
                name: "City",
                table: "ParkingLocations",
                type: "nvarchar(100)",
                maxLength: 100,
                nullable: false,
                defaultValue: "");
        }
    }
}
