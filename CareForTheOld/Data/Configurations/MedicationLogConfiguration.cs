using CareForTheOld.Models.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CareForTheOld.Data.Configurations;

public class MedicationLogConfiguration : IEntityTypeConfiguration<MedicationLog>
{
    public void Configure(EntityTypeBuilder<MedicationLog> builder)
    {
        builder.ToTable("MedicationLogs");
        builder.HasKey(ml => ml.Id);

        builder.Property(ml => ml.Note).HasMaxLength(500);

        builder.HasIndex(ml => new { ml.PlanId, ml.ScheduledAt });

        builder.HasOne(ml => ml.Plan)
            .WithMany(p => p.MedicationLogs)
            .HasForeignKey(ml => ml.PlanId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(ml => ml.Elder)
            .WithMany()
            .HasForeignKey(ml => ml.ElderId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}