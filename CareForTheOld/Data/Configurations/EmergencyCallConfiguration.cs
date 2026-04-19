using CareForTheOld.Models.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CareForTheOld.Data.Configurations;

public class EmergencyCallConfiguration : IEntityTypeConfiguration<EmergencyCall>
{
    public void Configure(EntityTypeBuilder<EmergencyCall> builder)
    {
        builder.ToTable("EmergencyCalls");
        builder.HasKey(e => e.Id);

        // 按状态+时间查询未处理呼叫的复合索引
        builder.HasIndex(e => new { e.Status, e.CalledAt });

        // 按老人查询呼叫记录的索引
        builder.HasIndex(e => e.ElderId);

        builder.HasOne(e => e.Elder)
            .WithMany()
            .HasForeignKey(e => e.ElderId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(e => e.Family)
            .WithMany()
            .HasForeignKey(e => e.FamilyId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
