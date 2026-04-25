using CareForTheOld.Models.Entities;
using CareForTheOld.Models.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CareForTheOld.Data.Configurations;

public class FamilyMemberConfiguration : IEntityTypeConfiguration<FamilyMember>
{
    public void Configure(EntityTypeBuilder<FamilyMember> builder)
    {
        builder.ToTable("FamilyMembers");
        builder.HasKey(fm => fm.Id);

        builder.Property(fm => fm.Relation).HasMaxLength(20).IsRequired();

        // Status 存储为字符串，便于阅读数据库和向后兼容
        builder.Property(fm => fm.Status)
            .HasConversion<string>()
            .IsRequired();

        // 同一家庭组内同一用户只能出现一次
        builder.HasIndex(fm => new { fm.FamilyId, fm.UserId }).IsUnique();

        // 一个用户只能属于一个家庭组（防止并发竞态创建重复关系）
        builder.HasIndex(fm => fm.UserId).IsUnique();

        builder.HasOne(fm => fm.Family)
            .WithMany(f => f.Members)
            .HasForeignKey(fm => fm.FamilyId)
            .OnDelete(DeleteBehavior.Cascade);

        builder.HasOne(fm => fm.User)
            .WithMany(u => u.FamilyMemberships)
            .HasForeignKey(fm => fm.UserId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}