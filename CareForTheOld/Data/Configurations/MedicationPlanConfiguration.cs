using CareForTheOld.Models.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CareForTheOld.Data.Configurations;

public class MedicationPlanConfiguration : IEntityTypeConfiguration<MedicationPlan>
{
    public void Configure(EntityTypeBuilder<MedicationPlan> builder)
    {
        builder.ToTable("MedicationPlans");
        builder.HasKey(m => m.Id);

        builder.Property(m => m.MedicineName).HasMaxLength(200).IsRequired();
        builder.Property(m => m.Dosage).HasMaxLength(100).IsRequired();
        builder.Property(m => m.ReminderTimes).HasColumnType("jsonb").IsRequired();

        builder.HasOne(m => m.Elder)
            .WithMany(u => u.MedicationPlans)
            .HasForeignKey(m => m.ElderId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}