using CareForTheOld.Models.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CareForTheOld.Data.Configurations;

/// <summary>
/// SmsRecord 实体配置
/// </summary>
public class SmsRecordConfiguration : IEntityTypeConfiguration<SmsRecord>
{
    public void Configure(EntityTypeBuilder<SmsRecord> builder)
    {
        builder.ToTable("SmsRecords");

        builder.HasKey(s => s.Id);

        // 按时间索引，便于查询发送历史
        builder.HasIndex(s => s.CreatedAt);

        // 按关联紧急呼叫索引，便于追溯告警发送情况
        builder.HasIndex(s => s.RelatedEmergencyCallId);

        builder.Property(s => s.PhoneNumber).HasMaxLength(20).IsRequired();
        builder.Property(s => s.Content).HasMaxLength(500).IsRequired();
        builder.Property(s => s.ServiceName).HasMaxLength(50).IsRequired();
        builder.Property(s => s.ErrorMessage).HasMaxLength(500);
    }
}