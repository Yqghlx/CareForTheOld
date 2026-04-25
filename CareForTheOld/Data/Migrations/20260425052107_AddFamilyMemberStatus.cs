using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CareForTheOld.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddFamilyMemberStatus : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "Status",
                table: "FamilyMembers",
                type: "text",
                nullable: false,
                defaultValue: "Approved");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Status",
                table: "FamilyMembers");
        }
    }
}
