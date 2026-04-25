using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace EasyPark.Services.Migrations
{
    /// <inheritdoc />
    public partial class FixPendingChanges : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Transactions_Reservations_ReservationId1",
                table: "Transactions");

            migrationBuilder.DropIndex(
                name: "IX_Transactions_ReservationId",
                table: "Transactions");

            migrationBuilder.DropIndex(
                name: "IX_Transactions_ReservationId1",
                table: "Transactions");

            migrationBuilder.DropColumn(
                name: "ReservationId1",
                table: "Transactions");

            migrationBuilder.CreateTable(
                name: "ReservationHistories",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    ReservationId = table.Column<int>(type: "int", nullable: false),
                    UserId = table.Column<int>(type: "int", nullable: true),
                    OldStatus = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: true),
                    NewStatus = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: true),
                    ChangeReason = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    ChangedAt = table.Column<DateTime>(type: "datetime", nullable: false, defaultValueSql: "(getdate())"),
                    Notes = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ReservationHistories", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ReservationHistories_Reservation",
                        column: x => x.ReservationId,
                        principalTable: "Reservations",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_ReservationHistories_User",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Transactions_ReservationId",
                table: "Transactions",
                column: "ReservationId",
                unique: true,
                filter: "[ReservationId] IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_ReservationHistories_ReservationId",
                table: "ReservationHistories",
                column: "ReservationId");

            migrationBuilder.CreateIndex(
                name: "IX_ReservationHistories_UserId",
                table: "ReservationHistories",
                column: "UserId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ReservationHistories");

            migrationBuilder.DropIndex(
                name: "IX_Transactions_ReservationId",
                table: "Transactions");

            migrationBuilder.AddColumn<int>(
                name: "ReservationId1",
                table: "Transactions",
                type: "int",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_Transactions_ReservationId",
                table: "Transactions",
                column: "ReservationId");

            migrationBuilder.CreateIndex(
                name: "IX_Transactions_ReservationId1",
                table: "Transactions",
                column: "ReservationId1",
                unique: true,
                filter: "[ReservationId1] IS NOT NULL");

            migrationBuilder.AddForeignKey(
                name: "FK_Transactions_Reservations_ReservationId1",
                table: "Transactions",
                column: "ReservationId1",
                principalTable: "Reservations",
                principalColumn: "Id");
        }
    }
}
