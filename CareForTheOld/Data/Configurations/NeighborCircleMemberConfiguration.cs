using CareForTheOld.Models.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CareForTheOld.Data.Configurations;

public class NeighborCircleMemberConfiguration : IEntityTypeConfiguration<NeighborCircleMember>
{
    public void Configure(EntityTypeBuilder<NeighborCircleMember> builder)
    {
        builder.ToTable("NeighborCircleMembers");
        builder.HasKey(m => m.Id);

        // 同一圈内同一用户唯一（一个用户只能加入一个邻里圈）
        builder.HasIndex(m => new { m.CircleId, m.UserId }).IsUnique();

        // 按用户索引（查询用户所在圈）
        builder.HasIndex(m => m.UserId);

        builder.Property(m => m.Nickname).HasMaxLength(50);

        builder.HasOne(m => m.Circle)
            .WithMany(c => c.Members)
            .HasForeignKey(m => m.CircleId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(m => m.User)
            .WithMany(u => u.NeighborCircleMemberships)
            .HasForeignKey(m => m.UserId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
