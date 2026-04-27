using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CareForTheOld.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddNeighborCircleIndexes : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateIndex(
                name: "IX_NeighborCircles_InviteCode_IsActive",
                table: "NeighborCircles",
                columns: new[] { "InviteCode", "IsActive" });

            migrationBuilder.CreateIndex(
                name: "IX_NeighborCircles_IsActive",
                table: "NeighborCircles",
                column: "IsActive");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_NeighborCircles_InviteCode_IsActive",
                table: "NeighborCircles");

            migrationBuilder.DropIndex(
                name: "IX_NeighborCircles_IsActive",
                table: "NeighborCircles");
        }
    }
}
