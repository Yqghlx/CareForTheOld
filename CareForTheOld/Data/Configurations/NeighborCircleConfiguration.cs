using CareForTheOld.Models.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CareForTheOld.Data.Configurations;

public class NeighborCircleConfiguration : IEntityTypeConfiguration<NeighborCircle>
{
    public void Configure(EntityTypeBuilder<NeighborCircle> builder)
    {
        builder.ToTable("NeighborCircles");
        builder.HasKey(c => c.Id);

        builder.Property(c => c.CircleName).HasMaxLength(100).IsRequired();
        builder.Property(c => c.InviteCode).HasMaxLength(6).IsRequired();

        // 经纬度复合索引（用于附近搜索粗筛）
        builder.HasIndex(c => new { c.CenterLatitude, c.CenterLongitude });

        builder.HasOne(c => c.Creator)
            .WithMany()
            .HasForeignKey(c => c.CreatorId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
