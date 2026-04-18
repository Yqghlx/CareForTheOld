using CareForTheOld.Common.Options;
using CareForTheOld.Data;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Mvc.ApiExplorer;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Microsoft.IdentityModel.Tokens;
using System.Text;

namespace CareForTheOld.Common.Extensions;

public static class ServiceCollectionExtensions
{
    /// <summary>
    /// 注册数据库服务（支持 PostgreSQL 和 SQLite）
    /// 生产环境使用 Migrate()，开发环境使用 EnsureCreated()
    /// </summary>
    public static IServiceCollection AddDatabaseServices(
        this IServiceCollection services, IConfiguration configuration, IWebHostEnvironment environment)
    {
        // 测试环境完全跳过，由 WebApplicationFactory 自行配置 InMemory 数据库
        if (environment.IsEnvironment("Testing"))
            return services;

        var connectionString = configuration.GetConnectionString("DefaultConnection")
            ?? "Data Source=carefortheold.db";

        bool isPostgres = connectionString.Contains("Host=") || connectionString.Contains("Server=");

        if (isPostgres)
        {
            // PostgreSQL 生产环境
            services.AddDbContext<AppDbContext>(options =>
                options.UseNpgsql(connectionString)
                    .ConfigureWarnings(w => w.Log(RelationalEventId.PendingModelChangesWarning)));
        }
        else
        {
            // SQLite 开发环境
            services.AddDbContext<AppDbContext>(options =>
                options.UseSqlite(connectionString));
        }

        // 启动时初始化数据库
        var serviceProvider = services.BuildServiceProvider();
        using var scope = serviceProvider.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();

        // 迁移文件由 SQLite 提供商生成，其中 bool 列类型为 INTEGER，
        // PostgreSQL 要求严格的 boolean 类型。使用 EnsureCreated() 让各提供商
        // 根据模型自动生成正确的列类型，避免跨提供商类型不兼容问题。
        // 待后续统一生成 PostgreSQL 专属迁移后可切换回 Migrate()
        context.Database.EnsureCreated();

        return services;
    }

    /// <summary>
    /// 注册 JWT 认证服务
    /// 密钥优先从环境变量读取，长度不足 32 字符则拒绝启动
    /// </summary>
    public static IServiceCollection AddJwtAuthentication(
        this IServiceCollection services, IConfiguration configuration)
    {
        var jwtKey = configuration["Jwt:Key"] ?? string.Empty;

        // 启动时校验密钥
        if (string.IsNullOrWhiteSpace(jwtKey) || jwtKey.Length < 32)
        {
            throw new InvalidOperationException(
                "JWT 密钥未配置或长度不足 32 字符。请通过环境变量 Jwt__Key 或 appsettings.json 配置。");
        }

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
    /// 注册健康检查服务
    /// </summary>
    public static IServiceCollection AddHealthCheckServices(
        this IServiceCollection services, IConfiguration configuration)
    {
        var connectionString = configuration.GetConnectionString("DefaultConnection")
            ?? "Data Source=carefortheold.db";

        var healthChecksBuilder = services.AddHealthChecks();

        if (connectionString.Contains("Host=") || connectionString.Contains("Server="))
        {
            healthChecksBuilder.AddNpgSql(connectionString, name: "postgresql");
        }
        else
        {
            healthChecksBuilder.AddSqlite(connectionString, name: "sqlite");
        }

        return services;
    }

    /// <summary>
    /// 注册 Swagger 服务（支持 API 版本控制）
    /// </summary>
    public static IServiceCollection AddSwaggerServices(this IServiceCollection services)
    {
        services.AddEndpointsApiExplorer();
        services.AddSwaggerGen(c =>
        {
            var xmlFile = $"{System.Reflection.Assembly.GetExecutingAssembly().GetName().Name}.xml";
            var xmlPath = System.IO.Path.Combine(AppContext.BaseDirectory, xmlFile);
            c.IncludeXmlComments(xmlPath);
        });

        // 配置版本化 Swagger：为每个 API 版本生成独立的 Swagger 文档
        services.ConfigureOptions<ConfigureSwaggerOptions>();

        return services;
    }
}
