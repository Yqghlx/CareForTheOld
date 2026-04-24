using CareForTheOld.Models.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CareForTheOld.Data.Configurations;

public class TrustScoreConfiguration : IEntityTypeConfiguration<TrustScore>
{
    public void Configure(EntityTypeBuilder<TrustScore> builder)
    {
        builder.ToTable("TrustScores");
        builder.HasKey(t => t.Id);

        // 每个用户在每个圈只有一个评分记录
        builder.HasIndex(t => new { t.UserId, t.CircleId }).IsUnique();

        builder.Property(t => t.AvgRating).HasPrecision(5, 2).HasDefaultValue(0m);
        builder.Property(t => t.ResponseRate).HasPrecision(5, 4).HasDefaultValue(0m);
        builder.Property(t => t.Score).HasPrecision(6, 2).HasDefaultValue(0m);

        builder.HasOne(t => t.User)
            .WithMany()
            .HasForeignKey(t => t.UserId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(t => t.Circle)
            .WithMany()
            .HasForeignKey(t => t.CircleId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
