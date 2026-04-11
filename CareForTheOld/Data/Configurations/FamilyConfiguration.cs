using CareForTheOld.Models.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CareForTheOld.Data.Configurations;

public class FamilyConfiguration : IEntityTypeConfiguration<Family>
{
    public void Configure(EntityTypeBuilder<Family> builder)
    {
        builder.ToTable("Families");
        builder.HasKey(f => f.Id);

        builder.Property(f => f.FamilyName).HasMaxLength(100).IsRequired();

        builder.HasOne(f => f.Creator)
            .WithMany()
            .HasForeignKey(f => f.CreatorId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}