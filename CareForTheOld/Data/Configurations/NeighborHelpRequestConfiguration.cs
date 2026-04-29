using CareForTheOld.Models.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CareForTheOld.Data.Configurations;

public class NeighborHelpRequestConfiguration : IEntityTypeConfiguration<NeighborHelpRequest>
{
    public void Configure(EntityTypeBuilder<NeighborHelpRequest> builder)
    {
        builder.ToTable("NeighborHelpRequests");
        builder.HasKey(r => r.Id);

        // 一条紧急呼叫只创建一条邻里求助请求
        builder.HasIndex(r => r.EmergencyCallId).IsUnique();

        // 定时清理过期请求的复合索引
        builder.HasIndex(r => new { r.Status, r.ExpiresAt });

        builder.HasIndex(r => r.RequesterId);

        // 按圈子查询求助请求（查询某圈子所有待处理/历史请求）
        builder.HasIndex(r => r.CircleId);

        // 按响应者查询（查询某邻居的互助响应记录，信任评分统计）
        builder.HasIndex(r => r.ResponderId);

        builder.HasOne(r => r.EmergencyCall)
            .WithMany()
            .HasForeignKey(r => r.EmergencyCallId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(r => r.Circle)
            .WithMany()
            .HasForeignKey(r => r.CircleId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(r => r.Requester)
            .WithMany()
            .HasForeignKey(r => r.RequesterId)
            .OnDelete(DeleteBehavior.Restrict);

        builder.HasOne(r => r.Responder)
            .WithMany()
            .HasForeignKey(r => r.ResponderId)
            .OnDelete(DeleteBehavior.SetNull);
    }
}
