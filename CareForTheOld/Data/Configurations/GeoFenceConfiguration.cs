using CareForTheOld.Models.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CareForTheOld.Data.Configurations;

/// <summary>
/// GeoFence 实体配置
/// </summary>
public class GeoFenceConfiguration : IEntityTypeConfiguration<GeoFence>
{
    public void Configure(EntityTypeBuilder<GeoFence> builder)
    {
        builder.ToTable("GeoFences");
        builder.HasKey(g => g.Id);

        // 每个老人只能有一个围栏（防止并发创建多个围栏）
        builder.HasIndex(g => g.ElderId).IsUnique();

        builder.HasOne(g => g.Elder)
            .WithMany()
            .HasForeignKey(g => g.ElderId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(g => g.Creator)
            .WithMany()
            .HasForeignKey(g => g.CreatedBy)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
