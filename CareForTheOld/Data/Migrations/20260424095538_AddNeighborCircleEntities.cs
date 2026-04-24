using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CareForTheOld.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddNeighborCircleEntities : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "NeighborCircles",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    CircleName = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    CenterLatitude = table.Column<double>(type: "double precision", nullable: false),
                    CenterLongitude = table.Column<double>(type: "double precision", nullable: false),
                    RadiusMeters = table.Column<double>(type: "double precision", nullable: false),
                    CreatorId = table.Column<Guid>(type: "uuid", nullable: false),
                    InviteCode = table.Column<string>(type: "character varying(6)", maxLength: 6, nullable: false),
                    InviteCodeExpiresAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    MaxMembers = table.Column<int>(type: "integer", nullable: false),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_NeighborCircles", x => x.Id);
                    table.ForeignKey(
                        name: "FK_NeighborCircles_Users_CreatorId",
                        column: x => x.CreatorId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "NeighborCircleMembers",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    CircleId = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    Role = table.Column<int>(type: "integer", nullable: false),
                    Status = table.Column<int>(type: "integer", nullable: false),
                    Nickname = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                    JoinedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_NeighborCircleMembers", x => x.Id);
                    table.ForeignKey(
                        name: "FK_NeighborCircleMembers_NeighborCircles_CircleId",
                        column: x => x.CircleId,
                        principalTable: "NeighborCircles",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_NeighborCircleMembers_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "NeighborHelpRequests",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    EmergencyCallId = table.Column<Guid>(type: "uuid", nullable: false),
                    CircleId = table.Column<Guid>(type: "uuid", nullable: false),
                    RequesterId = table.Column<Guid>(type: "uuid", nullable: false),
                    ResponderId = table.Column<Guid>(type: "uuid", nullable: true),
                    Status = table.Column<int>(type: "integer", nullable: false),
                    Latitude = table.Column<double>(type: "double precision", nullable: true),
                    Longitude = table.Column<double>(type: "double precision", nullable: true),
                    RequestedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    RespondedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    ExpiresAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    CancelledAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    CancelledBy = table.Column<Guid>(type: "uuid", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_NeighborHelpRequests", x => x.Id);
                    table.ForeignKey(
                        name: "FK_NeighborHelpRequests_EmergencyCalls_EmergencyCallId",
                        column: x => x.EmergencyCallId,
                        principalTable: "EmergencyCalls",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_NeighborHelpRequests_NeighborCircles_CircleId",
                        column: x => x.CircleId,
                        principalTable: "NeighborCircles",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_NeighborHelpRequests_Users_RequesterId",
                        column: x => x.RequesterId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_NeighborHelpRequests_Users_ResponderId",
                        column: x => x.ResponderId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "NeighborHelpRatings",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    HelpRequestId = table.Column<Guid>(type: "uuid", nullable: false),
                    RaterId = table.Column<Guid>(type: "uuid", nullable: false),
                    RateeId = table.Column<Guid>(type: "uuid", nullable: false),
                    Rating = table.Column<int>(type: "integer", nullable: false),
                    Comment = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_NeighborHelpRatings", x => x.Id);
                    table.ForeignKey(
                        name: "FK_NeighborHelpRatings_NeighborHelpRequests_HelpRequestId",
                        column: x => x.HelpRequestId,
                        principalTable: "NeighborHelpRequests",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_NeighborHelpRatings_Users_RateeId",
                        column: x => x.RateeId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_NeighborHelpRatings_Users_RaterId",
                        column: x => x.RaterId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateIndex(
                name: "IX_NeighborCircleMembers_CircleId_UserId",
                table: "NeighborCircleMembers",
                columns: new[] { "CircleId", "UserId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_NeighborCircleMembers_UserId",
                table: "NeighborCircleMembers",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_NeighborCircles_CenterLatitude_CenterLongitude",
                table: "NeighborCircles",
                columns: new[] { "CenterLatitude", "CenterLongitude" });

            migrationBuilder.CreateIndex(
                name: "IX_NeighborCircles_CreatorId",
                table: "NeighborCircles",
                column: "CreatorId");

            migrationBuilder.CreateIndex(
                name: "IX_NeighborHelpRatings_HelpRequestId_RaterId",
                table: "NeighborHelpRatings",
                columns: new[] { "HelpRequestId", "RaterId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_NeighborHelpRatings_RateeId",
                table: "NeighborHelpRatings",
                column: "RateeId");

            migrationBuilder.CreateIndex(
                name: "IX_NeighborHelpRatings_RaterId",
                table: "NeighborHelpRatings",
                column: "RaterId");

            migrationBuilder.CreateIndex(
                name: "IX_NeighborHelpRequests_CircleId",
                table: "NeighborHelpRequests",
                column: "CircleId");

            migrationBuilder.CreateIndex(
                name: "IX_NeighborHelpRequests_EmergencyCallId",
                table: "NeighborHelpRequests",
                column: "EmergencyCallId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_NeighborHelpRequests_RequesterId",
                table: "NeighborHelpRequests",
                column: "RequesterId");

            migrationBuilder.CreateIndex(
                name: "IX_NeighborHelpRequests_ResponderId",
                table: "NeighborHelpRequests",
                column: "ResponderId");

            migrationBuilder.CreateIndex(
                name: "IX_NeighborHelpRequests_Status_ExpiresAt",
                table: "NeighborHelpRequests",
                columns: new[] { "Status", "ExpiresAt" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "NeighborCircleMembers");

            migrationBuilder.DropTable(
                name: "NeighborHelpRatings");

            migrationBuilder.DropTable(
                name: "NeighborHelpRequests");

            migrationBuilder.DropTable(
                name: "NeighborCircles");
        }
    }
}
