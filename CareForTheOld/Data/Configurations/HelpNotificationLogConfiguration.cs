using CareForTheOld.Models.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CareForTheOld.Data.Configurations;

public class HelpNotificationLogConfiguration : IEntityTypeConfiguration<HelpNotificationLog>
{
    public void Configure(EntityTypeBuilder<HelpNotificationLog> builder)
    {
        builder.ToTable("HelpNotificationLogs");
        builder.HasKey(h => h.Id);

        // 每个求助请求对每个邻居只记录一次通知
        builder.HasIndex(h => new { h.HelpRequestId, h.UserId }).IsUnique();

        builder.HasOne(h => h.HelpRequest)
            .WithMany()
            .HasForeignKey(h => h.HelpRequestId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(h => h.User)
            .WithMany()
            .HasForeignKey(h => h.UserId)
            .OnDelete(DeleteBehavior.Restrict);
    }
}
