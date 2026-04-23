using CareForTheOld.Models.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CareForTheOld.Data.Configurations;

public class MedicationPlanConfiguration : IEntityTypeConfiguration<MedicationPlan>
{
    public void Configure(EntityTypeBuilder<MedicationPlan> builder)
    {
        builder.ToTable("MedicationPlans");
        builder.HasKey(m => m.Id);

        builder.Property(m => m.MedicineName).HasMaxLength(200).IsRequired();
        builder.Property(m => m.Dosage).HasMaxLength(100).IsRequired();
        builder.Property(m => m.ReminderTimes).HasColumnType("jsonb").IsRequired();

        builder.HasOne(m => m.Elder)
            .WithMany(u => u.MedicationPlans)
            .HasForeignKey(m => m.ElderId)
            .OnDelete(DeleteBehavior.Cascade);

        // 复合索引：优化"查询某老人活跃用药计划"和"今日待服药"场景
        builder.HasIndex(m => new { m.ElderId, m.IsActive, m.StartDate });
    }
}