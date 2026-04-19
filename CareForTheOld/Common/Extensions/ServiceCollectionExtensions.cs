using CareForTheOld.Common.Options;
using CareForTheOld.Data;
using CareForTheOld.Services.Implementations;
using CareForTheOld.Services.Interfaces;
using Hangfire;
using Hangfire.PostgreSql;
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
                    .UseQueryTrackingBehavior(QueryTrackingBehavior.NoTracking)
                    .ConfigureWarnings(w => w.Log(RelationalEventId.PendingModelChangesWarning)));
        }
        else
        {
            // SQLite 开发环境
            services.AddDbContext<AppDbContext>(options =>
                options.UseSqlite(connectionString)
                    .UseQueryTrackingBehavior(QueryTrackingBehavior.NoTracking));
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
    /// 通过 IKeyProvider 抽象获取签名密钥，支持多种密钥来源
    /// </summary>
    public static IServiceCollection AddJwtAuthentication(
        this IServiceCollection services, IConfiguration configuration,
        IWebHostEnvironment environment)
    {
        // 根据环境选择密钥提供者实现
        if (environment.IsDevelopment() || environment.IsEnvironment("Testing"))
        {
            services.AddSingleton<IKeyProvider, ConfigurationKeyProvider>();
        }
        else
        {
            services.AddSingleton<IKeyProvider, EnvironmentKeyProvider>();
        }

        // 从 IKeyProvider 获取密钥（启动时立即校验）
        var keyProvider = services.BuildServiceProvider().GetRequiredService<IKeyProvider>();
        var key = keyProvider.GetSigningKeyAsync().GetAwaiter().GetResult();

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
                ClockSkew = TimeSpan.FromMinutes(5),
                // SignalR 的 Context.UserIdentifier 依赖此配置
                NameClaimType = System.Security.Claims.ClaimTypes.NameIdentifier
            };

            // 支持 SignalR 通过查询字符串传递 JWT Token（WebSocket 不支持 Header）
            options.Events = new JwtBearerEvents
            {
                OnMessageReceived = context =>
                {
                    var accessToken = context.Request.Query["access_token"];
                    var path = context.HttpContext.Request.Path;
                    if (!string.IsNullOrEmpty(accessToken) && path.StartsWithSegments("/hubs"))
                    {
                        context.Token = accessToken;
                    }
                    return Task.CompletedTask;
                }
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

    /// <summary>
    /// 注册 Hangfire 后台任务调度（生产环境使用 PostgreSQL 持久化存储）
    /// </summary>
    public static IServiceCollection AddHangfireServices(
        this IServiceCollection services, IConfiguration configuration, IWebHostEnvironment environment)
    {
        var connectionString = configuration.GetConnectionString("DefaultConnection");

        if (!string.IsNullOrEmpty(connectionString) && connectionString.Contains("Host="))
        {
            // 生产环境：PostgreSQL 持久化存储
            services.AddHangfire(config => config
                .UsePostgreSqlStorage(options => options.UseNpgsqlConnection(connectionString))
                .UseSimpleAssemblyNameTypeSerializer()
                .UseRecommendedSerializerSettings());
        }
        else
        {
            // 开发/测试环境：内存存储（应用重启后任务状态丢失，仅开发使用）
            services.AddHangfire(config => config
                .UseInMemoryStorage()
                .UseSimpleAssemblyNameTypeSerializer()
                .UseRecommendedSerializerSettings());
        }

        services.AddHangfireServer();

        return services;
    }
}
