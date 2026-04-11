using CareForTheOld.Models.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CareForTheOld.Data.Configurations;

public class HealthRecordConfiguration : IEntityTypeConfiguration<HealthRecord>
{
    public void Configure(EntityTypeBuilder<HealthRecord> builder)
    {
        builder.ToTable("HealthRecords");
        builder.HasKey(h => h.Id);

        builder.Property(h => h.BloodSugar).HasPrecision(5, 2);
        builder.Property(h => h.Temperature).HasPrecision(4, 1);
        builder.Property(h => h.Note).HasMaxLength(500);

        builder.HasIndex(h => new { h.UserId, h.Type, h.RecordedAt });

        builder.HasOne(h => h.User)
            .WithMany(u => u.HealthRecords)
            .HasForeignKey(h => h.UserId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}