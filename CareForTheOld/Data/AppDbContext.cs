using CareForTheOld.Models.Entities;
using Microsoft.EntityFrameworkCore;

namespace CareForTheOld.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<User> Users => Set<User>();
    public DbSet<Family> Families => Set<Family>();
    public DbSet<FamilyMember> FamilyMembers => Set<FamilyMember>();
    public DbSet<HealthRecord> HealthRecords => Set<HealthRecord>();
    public DbSet<MedicationPlan> MedicationPlans => Set<MedicationPlan>();
    public DbSet<MedicationLog> MedicationLogs => Set<MedicationLog>();
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();
    public DbSet<EmergencyCall> EmergencyCalls => Set<EmergencyCall>();
    public DbSet<LocationRecord> LocationRecords => Set<LocationRecord>();
    public DbSet<NotificationRecord> NotificationRecords => Set<NotificationRecord>();
    public DbSet<NotificationOutbox> NotificationOutboxes => Set<NotificationOutbox>();
    public DbSet<GeoFence> GeoFences => Set<GeoFence>();
    public DbSet<SmsRecord> SmsRecords => Set<SmsRecord>();
    public DbSet<NeighborCircle> NeighborCircles => Set<NeighborCircle>();
    public DbSet<NeighborCircleMember> NeighborCircleMembers => Set<NeighborCircleMember>();
    public DbSet<NeighborHelpRequest> NeighborHelpRequests => Set<NeighborHelpRequest>();
    public DbSet<NeighborHelpRating> NeighborHelpRatings => Set<NeighborHelpRating>();
    public DbSet<TrustScore> TrustScores => Set<TrustScore>();
    public DbSet<HelpNotificationLog> HelpNotificationLogs => Set<HelpNotificationLog>();
    public DbSet<AutoRescueRecord> AutoRescueRecords => Set<AutoRescueRecord>();
    public DbSet<DeviceToken> DeviceTokens => Set<DeviceToken>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        // 自动加载所有 IEntityTypeConfiguration 实现
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(AppDbContext).Assembly);
    }
}