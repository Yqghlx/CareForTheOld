using CareForTheOld.Models.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace CareForTheOld.Data.Configurations;

public class UserConfiguration : IEntityTypeConfiguration<User>
{
    public void Configure(EntityTypeBuilder<User> builder)
    {
        builder.ToTable("Users");
        builder.HasKey(u => u.Id);

        builder.Property(u => u.PhoneNumber).HasMaxLength(20).IsRequired();
        builder.HasIndex(u => u.PhoneNumber).IsUnique();
        builder.Property(u => u.PasswordHash).IsRequired();
        builder.Property(u => u.RealName).HasMaxLength(50).IsRequired();
        builder.Property(u => u.AvatarUrl).HasMaxLength(500);
    }
}