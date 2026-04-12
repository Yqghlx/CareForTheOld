using CareForTheOld.Data;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using System.Text;

namespace CareForTheOld.Common.Extensions;

public static class ServiceCollectionExtensions
{
    /// <summary>
    /// 注册数据库服务
    /// </summary>
    public static IServiceCollection AddDatabaseServices(
        this IServiceCollection services, IConfiguration configuration)
    {
        // 使用 SQLite 数据库（数据持久化到本地文件）
        var connectionString = configuration.GetConnectionString("DefaultConnection")
            ?? "Data Source=carefortheold.db";

        services.AddDbContext<AppDbContext>(options =>
            options.UseSqlite(connectionString));

        // 启动时自动创建数据库和表
        services.BuildServiceProvider().GetRequiredService<AppDbContext>()
            .Database.EnsureCreated();

        return services;
    }

    /// <summary>
    /// 注册 JWT 认证服务
    /// </summary>
    public static IServiceCollection AddJwtAuthentication(
        this IServiceCollection services, IConfiguration configuration)
    {
        var jwtKey = configuration["Jwt:Key"] ?? "CareForTheOld_DefaultSecretKey_2026_MustBe32Chars!";
        var key = Encoding.UTF8.GetBytes(jwtKey);

        services.AddAuthentication(options =>
        {
            options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
            options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
        })
        .AddJwtBearer(options =>
        {
            options.TokenValidationParameters = new TokenValidationParameters
            {
                ValidateIssuer = true,
                ValidateAudience = true,
                ValidateLifetime = true,
                ValidateIssuerSigningKey = true,
                ValidIssuer = configuration["Jwt:Issuer"] ?? "CareForTheOld",
                ValidAudience = configuration["Jwt:Audience"] ?? "CareForTheOld",
                IssuerSigningKey = new SymmetricSecurityKey(key),
                ClockSkew = TimeSpan.FromMinutes(5)
            };
        });

        return services;
    }

    /// <summary>
    /// 注册 Swagger 服务
    /// </summary>
    public static IServiceCollection AddSwaggerServices(this IServiceCollection services)
    {
        services.AddEndpointsApiExplorer();
        services.AddSwaggerGen();
        return services;
    }
}