using CareForTheOld.Models.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CareForTheOld.Data.Configurations;

public class MedicationLogConfiguration : IEntityTypeConfiguration<MedicationLog>
{
    public void Configure(EntityTypeBuilder<MedicationLog> builder)
    {
        builder.ToTable("MedicationLogs");
        builder.HasKey(ml => ml.Id);

        builder.Property(ml => ml.Note).HasMaxLength(500);

        // 同一计划同一时间点只允许一条记录，防止并发产生重复用药日志
        builder.HasIndex(ml => new { ml.PlanId, ml.ScheduledAt }).IsUnique();

        // 按老人+时间查询日志（GetLogsAsync 按老人和日期范围查询）
        builder.HasIndex(ml => new { ml.ElderId, ml.ScheduledAt });

        builder.HasOne(ml => ml.Plan)
            .WithMany(p => p.MedicationLogs)
            .HasForeignKey(ml => ml.PlanId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(ml => ml.Elder)
            .WithMany()
            .HasForeignKey(ml => ml.ElderId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}