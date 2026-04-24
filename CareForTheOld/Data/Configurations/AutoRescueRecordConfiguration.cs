using CareForTheOld.Models.Entities;
using CareForTheOld.Models.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CareForTheOld.Data.Configurations;

public class AutoRescueRecordConfiguration : IEntityTypeConfiguration<AutoRescueRecord>
{
    public void Configure(EntityTypeBuilder<AutoRescueRecord> builder)
    {
        builder.ToTable("AutoRescueRecords");
        builder.HasKey(a => a.Id);

        // 按状态+触发时间索引，便于查询待处理记录
        builder.HasIndex(a => new { a.Status, a.TriggeredAt });

        // 枚举存储为字符串，便于阅读和调试
        builder.Property(a => a.TriggerType)
            .HasConversion<string>()
            .HasMaxLength(30);
        builder.Property(a => a.Status)
            .HasConversion<string>()
            .HasMaxLength(30);

        builder.HasOne(a => a.Elder)
            .WithMany()
            .HasForeignKey(a => a.ElderId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
