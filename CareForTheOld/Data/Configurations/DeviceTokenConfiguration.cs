using CareForTheOld.Models.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CareForTheOld.Data.Configurations;

public class DeviceTokenConfiguration : IEntityTypeConfiguration<DeviceToken>
{
    public void Configure(EntityTypeBuilder<DeviceToken> builder)
    {
        builder.ToTable("DeviceTokens");
        builder.HasKey(dt => dt.Id);

        builder.Property(dt => dt.Token)
            .HasMaxLength(512)
            .IsRequired();

        builder.Property(dt => dt.Platform)
            .HasMaxLength(20)
            .IsRequired();

        // FCM token 全局唯一（同一 token 只能绑定一个用户）
        builder.HasIndex(dt => dt.Token).IsUnique();

        // 按用户查询 token 列表
        builder.HasIndex(dt => dt.UserId);

        builder.HasOne(dt => dt.User)
            .WithMany()
            .HasForeignKey(dt => dt.UserId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
