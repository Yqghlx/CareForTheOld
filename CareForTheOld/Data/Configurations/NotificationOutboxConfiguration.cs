using CareForTheOld.Models.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CareForTheOld.Data.Configurations;

/// <summary>
/// NotificationOutbox 实体配置
/// </summary>
public class NotificationOutboxConfiguration : IEntityTypeConfiguration<NotificationOutbox>
{
    public void Configure(EntityTypeBuilder<NotificationOutbox> builder)
    {
        builder.ToTable("NotificationOutbox");

        builder.HasKey(o => o.Id);

        // 按状态+创建时间索引，后台 Job 高效查询待投递消息
        builder.HasIndex(o => new { o.Status, o.CreatedAt });

        // 按用户索引，查询某用户的通知历史
        builder.HasIndex(o => o.UserId);

        builder.Property(o => o.Type).HasMaxLength(50).IsRequired();
        builder.Property(o => o.Title).HasMaxLength(200).IsRequired();
        builder.Property(o => o.Content).HasMaxLength(1000).IsRequired();
        builder.Property(o => o.Payload).HasColumnType("text");
        builder.Property(o => o.LastError).HasMaxLength(500);
    }
}
