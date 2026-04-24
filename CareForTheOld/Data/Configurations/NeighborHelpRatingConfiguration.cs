using CareForTheOld.Models.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CareForTheOld.Data.Configurations;

public class NeighborHelpRatingConfiguration : IEntityTypeConfiguration<NeighborHelpRating>
{
    public void Configure(EntityTypeBuilder<NeighborHelpRating> builder)
    {
        builder.ToTable("NeighborHelpRatings");
        builder.HasKey(r => r.Id);

        // 一个求助请求每人最多一条评价
        builder.HasIndex(r => new { r.HelpRequestId, r.RaterId }).IsUnique();

        builder.Property(r => r.Comment).HasMaxLength(500);

        builder.HasOne(r => r.HelpRequest)
            .WithMany()
            .HasForeignKey(r => r.HelpRequestId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(r => r.Rater)
            .WithMany()
            .HasForeignKey(r => r.RaterId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(r => r.Ratee)
            .WithMany()
            .HasForeignKey(r => r.RateeId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
