using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace CareForTheOld.Data.Migrations
{
    /// <inheritdoc />
    public partial class AddTrustScoreAndAutoRescue : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_MedicationLogs_PlanId_ScheduledAt",
                table: "MedicationLogs");

            migrationBuilder.CreateTable(
                name: "AutoRescueRecords",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    ElderId = table.Column<Guid>(type: "uuid", nullable: false),
                    FamilyId = table.Column<Guid>(type: "uuid", nullable: false),
                    CircleId = table.Column<Guid>(type: "uuid", nullable: false),
                    TriggerType = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false),
                    Status = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false),
                    TriggeredAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    ChildNotifiedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    ChildRespondedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    BroadcastAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true),
                    ResolvedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_AutoRescueRecords", x => x.Id);
                    table.ForeignKey(
                        name: "FK_AutoRescueRecords_Users_ElderId",
                        column: x => x.ElderId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "HelpNotificationLogs",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    HelpRequestId = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    NotifiedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    RespondedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_HelpNotificationLogs", x => x.Id);
                    table.ForeignKey(
                        name: "FK_HelpNotificationLogs_NeighborHelpRequests_HelpRequestId",
                        column: x => x.HelpRequestId,
                        principalTable: "NeighborHelpRequests",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_HelpNotificationLogs_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "TrustScores",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    CircleId = table.Column<Guid>(type: "uuid", nullable: false),
                    TotalHelps = table.Column<int>(type: "integer", nullable: false),
                    AvgRating = table.Column<decimal>(type: "numeric(5,2)", precision: 5, scale: 2, nullable: false, defaultValue: 0m),
                    ResponseRate = table.Column<decimal>(type: "numeric(5,4)", precision: 5, scale: 4, nullable: false, defaultValue: 0m),
                    Score = table.Column<decimal>(type: "numeric(6,2)", precision: 6, scale: 2, nullable: false, defaultValue: 0m),
                    LastCalculatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TrustScores", x => x.Id);
                    table.ForeignKey(
                        name: "FK_TrustScores_NeighborCircles_CircleId",
                        column: x => x.CircleId,
                        principalTable: "NeighborCircles",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_TrustScores_Users_UserId",
                        column: x => x.UserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_NotificationOutbox_UserId",
                table: "NotificationOutbox",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_MedicationLogs_PlanId_ScheduledAt",
                table: "MedicationLogs",
                columns: new[] { "PlanId", "ScheduledAt" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_AutoRescueRecords_ElderId",
                table: "AutoRescueRecords",
                column: "ElderId");

            migrationBuilder.CreateIndex(
                name: "IX_AutoRescueRecords_Status_TriggeredAt",
                table: "AutoRescueRecords",
                columns: new[] { "Status", "TriggeredAt" });

            migrationBuilder.CreateIndex(
                name: "IX_HelpNotificationLogs_HelpRequestId_UserId",
                table: "HelpNotificationLogs",
                columns: new[] { "HelpRequestId", "UserId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_HelpNotificationLogs_UserId",
                table: "HelpNotificationLogs",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_TrustScores_CircleId",
                table: "TrustScores",
                column: "CircleId");

            migrationBuilder.CreateIndex(
                name: "IX_TrustScores_UserId_CircleId",
                table: "TrustScores",
                columns: new[] { "UserId", "CircleId" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "AutoRescueRecords");

            migrationBuilder.DropTable(
                name: "HelpNotificationLogs");

            migrationBuilder.DropTable(
                name: "TrustScores");

            migrationBuilder.DropIndex(
                name: "IX_NotificationOutbox_UserId",
                table: "NotificationOutbox");

            migrationBuilder.DropIndex(
                name: "IX_MedicationLogs_PlanId_ScheduledAt",
                table: "MedicationLogs");

            migrationBuilder.CreateIndex(
                name: "IX_MedicationLogs_PlanId_ScheduledAt",
                table: "MedicationLogs",
                columns: new[] { "PlanId", "ScheduledAt" });
        }
    }
}
