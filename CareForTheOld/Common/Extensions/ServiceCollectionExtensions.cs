using CareForTheOld.Common.Constants;
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
            // PostgreSQL 生产环境（启用连接失败自动重试，应对短暂网络抖动）
            services.AddDbContext<AppDbContext>(options =>
                options.UseNpgsql(connectionString, npgsqlOptions =>
                    npgsqlOptions.EnableRetryOnFailure(
                        maxRetryCount: 3,
                        maxRetryDelay: TimeSpan.FromSeconds(5),
                        errorCodesToAdd: null))
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

        // 数据库初始化策略：
        // - PostgreSQL（生产）：使用 Migrate()，支持增量迁移和版本管理
        // - SQLite（开发）：使用 EnsureCreated()，避免迁移文件跨提供商类型不兼容
        //   （SQLite 迁移中 bool 为 INTEGER，PostgreSQL 要求严格的 boolean 类型）
        if (isPostgres)
        {
            context.Database.Migrate();
        }
        else
        {
            context.Database.EnsureCreated();
        }

        return services;
    }

    /// <summary>
    /// 注册 JWT 认证服务
    /// 通过 IKeyProvider 抽象获取签名密钥，支持多种密钥来源
    /// </summary>
    /// <param name="services">服务集合</param>
    /// <param name="configuration">配置</param>
    /// <param name="environment">环境信息</param>
    /// <param name="signingKey">JWT 签名密钥（预先异步获取，避免启动时同步阻塞）</param>
    public static IServiceCollection AddJwtAuthentication(
        this IServiceCollection services, IConfiguration configuration,
        IWebHostEnvironment environment, byte[] signingKey)
    {
        // 根据环境选择密钥提供者实现（用于后续 Token 签发）
        if (environment.IsDevelopment() || environment.IsEnvironment("Testing"))
        {
            services.AddSingleton<IKeyProvider, ConfigurationKeyProvider>();
        }
        else
        {
            services.AddSingleton<IKeyProvider, EnvironmentKeyProvider>();
        }

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
                ValidIssuer = configuration[ConfigurationKeys.Jwt.Issuer] ?? "CareForTheOld",
                ValidAudience = configuration[ConfigurationKeys.Jwt.Audience] ?? "CareForTheOld",
                IssuerSigningKey = new SymmetricSecurityKey(signingKey),
                ClockSkew = TimeSpan.FromMinutes(AppConstants.Security.JwtClockSkewMinutes),
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
    /// 注册健康检查服务（数据库 + Redis）
    /// </summary>
    public static IServiceCollection AddHealthCheckServices(
        this IServiceCollection services, IConfiguration configuration)
    {
        var connectionString = configuration.GetConnectionString("DefaultConnection")
            ?? "Data Source=carefortheold.db";

        var healthChecksBuilder = services.AddHealthChecks();

        // 数据库健康检查
        if (connectionString.Contains("Host=") || connectionString.Contains("Server="))
        {
            healthChecksBuilder.AddNpgSql(connectionString, name: "postgresql");
        }
        else
        {
            healthChecksBuilder.AddSqlite(connectionString, name: "sqlite");
        }

        // Redis 健康检查（生产环境必需）
        var redisConnection = configuration.GetConnectionString("Redis");
        if (!string.IsNullOrWhiteSpace(redisConnection))
        {
            healthChecksBuilder.AddRedis(redisConnection, name: "redis");
        }

        // Hangfire 后台任务健康检查
        healthChecksBuilder.AddCheck<HealthChecks.HangfireHealthCheck>("hangfire", tags: ["ready"]);

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
