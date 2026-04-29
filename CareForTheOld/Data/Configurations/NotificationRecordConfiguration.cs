using CareForTheOld.Models.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CareForTheOld.Data.Configurations;

/// <summary>
/// NotificationRecord 实体配置
/// </summary>
public class NotificationRecordConfiguration : IEntityTypeConfiguration<NotificationRecord>
{
    public void Configure(EntityTypeBuilder<NotificationRecord> builder)
    {
        builder.ToTable("NotificationRecords");

        builder.HasKey(n => n.Id);

        // 按用户索引，查询某用户的通知列表
        builder.HasIndex(n => n.UserId);

        // 按创建时间索引，支持分页排序
        builder.HasIndex(n => n.CreatedAt);

        // 按用户+已读状态索引，查询未读通知数量
        builder.HasIndex(n => new { n.UserId, n.IsRead });

        // 按用户+创建时间复合索引，优化分页查询性能
        builder.HasIndex(n => new { n.UserId, n.CreatedAt });

        builder.HasOne(n => n.User)
            .WithMany()
            .HasForeignKey(n => n.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.Property(n => n.Type).HasMaxLength(50).IsRequired();
        builder.Property(n => n.Title).HasMaxLength(200).IsRequired();
        builder.Property(n => n.Content).HasMaxLength(1000).IsRequired();
    }
}
