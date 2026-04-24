using Asp.Versioning;
using Asp.Versioning.ApiExplorer;
using CareForTheOld.Common.Extensions;
using CareForTheOld.Common.Middleware;
using CareForTheOld.Data;
using CareForTheOld.Services.Background;
using Hangfire;
using CareForTheOld.Services.Hubs;
using CareForTheOld.Services.Implementations;
using CareForTheOld.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using Serilog;
using StackExchange.Redis;
using System.Threading.RateLimiting;

var builder = WebApplication.CreateBuilder(args);

// 生产环境启动前强制检查必要配置
if (builder.Environment.IsProduction())
{
    var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");
    if (string.IsNullOrWhiteSpace(connectionString) || !connectionString.Contains("Host="))
    {
        throw new InvalidOperationException(
            "生产环境必须配置 PostgreSQL 连接字符串。" +
            "请通过环境变量或 appsettings.Production.json 设置 ConnectionStrings:DefaultConnection。");
    }

    var redis = builder.Configuration.GetConnectionString("Redis");
    if (string.IsNullOrWhiteSpace(redis))
    {
        throw new InvalidOperationException(
            "生产环境必须配置 Redis 连接字符串。" +
            "请通过环境变量 REDIS_CONNECTION 或 appsettings.Production.json 设置 ConnectionStrings:Redis。");
    }
}

// 配置 Serilog：从 appsettings.json 读取（生产环境在 appsettings.Production.json 中覆盖）
// 开发环境未配置 Serilog 节点时，使用最小默认配置（Console + File）
Log.Logger = new LoggerConfiguration()
    .ReadFrom.Configuration(builder.Configuration)
    .Enrich.FromLogContext()
    .WriteTo.Console()
    .WriteTo.File("logs/carefortheold-.log", rollingInterval: RollingInterval.Day)
    .CreateLogger();

builder.Host.UseSerilog();

// JWT 密钥配置：开发/测试环境确保配置文件中有默认密钥
// 生产环境从环境变量获取，启动时异步加载避免同步阻塞
byte[] jwtSigningKey;
if (builder.Environment.IsDevelopment() || builder.Environment.IsEnvironment("Testing"))
{
    var jwtKey = builder.Configuration["Jwt:Key"];
    if (string.IsNullOrWhiteSpace(jwtKey))
    {
        jwtKey = "CareForTheOld_DevSecretKey_2026_MustBe32Chars!";
    }
    jwtSigningKey = System.Text.Encoding.UTF8.GetBytes(jwtKey);
}
else
{
    // 生产环境从环境变量获取 JWT 密钥
    var jwtKey = builder.Configuration["Jwt:Key"] ?? Environment.GetEnvironmentVariable("JWT_SECRET_KEY");
    if (string.IsNullOrWhiteSpace(jwtKey))
    {
        throw new InvalidOperationException(
            "生产环境必须配置 JWT 密钥。" +
            "请通过环境变量 JWT_SECRET_KEY 设置（至少 32 字符）。");
    }
    jwtSigningKey = System.Text.Encoding.UTF8.GetBytes(jwtKey);
}

// 注册服务
// 配置 JSON 序列化：枚举值序列化为 camelCase 字符串，与前端 Dart 枚举映射一致
builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.PropertyNamingPolicy = System.Text.Json.JsonNamingPolicy.CamelCase;
        // 将枚举序列化为字符串（而非整数），使用 camelCase 命名
        options.JsonSerializerOptions.Converters.Add(new System.Text.Json.Serialization.JsonStringEnumConverter(
            System.Text.Json.JsonNamingPolicy.CamelCase));
    });
builder.Services.AddApiVersioning(options =>
{
    options.DefaultApiVersion = new ApiVersion(1, 0);
    options.AssumeDefaultVersionWhenUnspecified = true;
    options.ReportApiVersions = true;
}).AddApiExplorer(options =>
{
    options.GroupNameFormat = "'v'VVV";
    options.SubstituteApiVersionInUrl = true;
});
builder.Services.AddDatabaseServices(builder.Configuration, builder.Environment);
builder.Services.AddJwtAuthentication(builder.Configuration, builder.Environment, jwtSigningKey);
builder.Services.AddSwaggerServices();
builder.Services.AddHealthCheckServices(builder.Configuration);
builder.Services.AddSignalR();

// 注册业务服务
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<IUserService, UserService>();
builder.Services.AddScoped<IFamilyService, FamilyService>();
builder.Services.AddScoped<IHealthService, HealthService>();
builder.Services.AddScoped<IHealthQueryService, DapperHealthQueryService>();
builder.Services.AddScoped<IHealthAlertService, HealthAlertService>();
builder.Services.AddScoped<IMedicationService, MedicationService>();
builder.Services.AddScoped<INotificationService, NotificationService>();
builder.Services.AddScoped<IEmergencyService, EmergencyService>();
builder.Services.AddScoped<INeighborCircleService, NeighborCircleService>();
builder.Services.AddScoped<ILocationService, LocationService>();
builder.Services.AddScoped<IGeoFenceService, GeoFenceService>();
builder.Services.AddScoped<IHealthReportService, HealthReportService>();
builder.Services.AddScoped<ICacheService, CacheService>();
builder.Services.AddScoped<HealthAnomalyDetector>();
builder.Services.Configure<AnomalyDetectionOptions>(
    builder.Configuration.GetSection("AnomalyDetection"));

// 注册文件存储服务：根据环境变量 OSS_ENABLED 选择实现
var ossEnabled = Environment.GetEnvironmentVariable("OSS_ENABLED")?.ToLower() == "true";
if (ossEnabled)
{
    builder.Services.AddScoped<IFileStorageService, OssFileStorageService>();
}
else
{
    builder.Services.AddScoped<IFileStorageService, LocalFileStorageService>();
}

// 注册短信服务：根据配置 Sms:Provider 选择服务商（Aliyun 国内 / Twilio 国际）
var smsProvider = builder.Configuration["Sms:Provider"]?.ToLower() ?? "aliyun";
if (smsProvider == "twilio")
{
    builder.Services.AddScoped<ISmsService, TwilioSmsService>();
}
else
{
    builder.Services.AddScoped<ISmsService, AliyunSmsService>();
}

// 注册分布式缓存：优先使用 Redis，未配置时回退到内存缓存
var redisConnection = builder.Configuration.GetConnectionString("Redis");
if (!string.IsNullOrEmpty(redisConnection))
{
    builder.Services.AddStackExchangeRedisCache(options => options.Configuration = redisConnection);
    // 注册 Redis 连接复用，供 CacheService 按前缀删除等高级操作使用
    builder.Services.AddSingleton<IConnectionMultiplexer>(ConnectionMultiplexer.Connect(redisConnection));
}
else
{
    builder.Services.AddDistributedMemoryCache();
}

// 注册后台任务调度（Hangfire）
builder.Services.AddHangfireServices(builder.Configuration, builder.Environment);
// 注册用药提醒服务（同时支持 IHostedService 回退模式和 Hangfire 调度）
builder.Services.AddHostedService<MedicationReminderService>();
builder.Services.AddSingleton<MedicationReminderService>();
// 注册 Outbox 投递服务（用于 SignalR 通知的异步投递）
builder.Services.AddSingleton<OutboxDispatchService>();
// 注册心跳监控服务（检测老人端离线并触发告警）
builder.Services.AddSingleton<HeartbeatMonitorService>();

// CORS 配置：从配置读取允许的来源
builder.Services.AddCors(options =>
{
    options.AddPolicy("ConfiguredCors", policy =>
    {
        var allowedOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>()
            ?? Array.Empty<string>();

        if (allowedOrigins.Length == 0)
        {
            // 未配置时：开发环境允许 localhost，生产环境拒绝跨域
            if (builder.Environment.IsDevelopment())
            {
                policy.SetIsOriginAllowed(origin =>
                    new Uri(origin).Host is "localhost" or "127.0.0.1")
                    .AllowAnyMethod()
                    .AllowAnyHeader()
                    .AllowCredentials();
            }
            else
            {
                policy.SetIsOriginAllowed(_ => false)
                    .AllowAnyMethod()
                    .AllowAnyHeader();
            }
        }
        else
        {
            policy.WithOrigins(allowedOrigins)
                  .AllowAnyMethod()
                  .AllowAnyHeader()
                  .AllowCredentials();
        }
    });
});

// 限流配置
// 获取客户端真实 IP（优先从 X-Forwarded-For / X-Real-IP 获取，兼容反向代理）
static string GetClientIp(HttpContext context)
{
    var forwardedFor = context.Request.Headers["X-Forwarded-For"].FirstOrDefault();
    if (!string.IsNullOrEmpty(forwardedFor))
    {
        // X-Forwarded-For 可能包含多个 IP，取第一个（最原始的客户端 IP）
        var ip = forwardedFor.Split(',').First().Trim();
        if (!string.IsNullOrEmpty(ip)) return ip;
    }
    var realIp = context.Request.Headers["X-Real-IP"].FirstOrDefault();
    if (!string.IsNullOrEmpty(realIp)) return realIp;
    return context.Connection.RemoteIpAddress?.ToString() ?? "unknown";
}

builder.Services.AddRateLimiter(options =>
{
    // 认证接口限流：每 IP 每分钟 10 次
    options.AddPolicy("AuthPolicy", context =>
        RateLimitPartition.GetSlidingWindowLimiter(
            partitionKey: GetClientIp(context),
            factory: _ => new SlidingWindowRateLimiterOptions
            {
                PermitLimit = builder.Configuration.GetValue("RateLimit:AuthPermitLimit", 10),
                Window = TimeSpan.FromSeconds(builder.Configuration.GetValue("RateLimit:AuthWindow", 60)),
                SegmentsPerWindow = 2,
                QueueProcessingOrder = QueueProcessingOrder.OldestFirst,
                QueueLimit = 0
            }));

    // 通用 API 限流：每 IP 每分钟 60 次
    options.AddPolicy("GeneralPolicy", context =>
        RateLimitPartition.GetSlidingWindowLimiter(
            partitionKey: GetClientIp(context),
            factory: _ => new SlidingWindowRateLimiterOptions
            {
                PermitLimit = builder.Configuration.GetValue("RateLimit:GeneralPermitLimit", 60),
                Window = TimeSpan.FromSeconds(builder.Configuration.GetValue("RateLimit:GeneralWindow", 60)),
                SegmentsPerWindow = 2,
                QueueProcessingOrder = QueueProcessingOrder.OldestFirst,
                QueueLimit = 0
            }));

    // 加入家庭限流：每用户每5分钟最多5次，防止邀请码暴力破解
    options.AddPolicy("JoinFamilyPolicy", context =>
        RateLimitPartition.GetSlidingWindowLimiter(
            partitionKey: context.User?.FindFirst("sub")?.Value ?? GetClientIp(context),
            factory: _ => new SlidingWindowRateLimiterOptions
            {
                PermitLimit = 5,
                Window = TimeSpan.FromMinutes(5),
                SegmentsPerWindow = 2,
                QueueProcessingOrder = QueueProcessingOrder.OldestFirst,
                QueueLimit = 0
            }));

    // 加入邻里圈限流：每用户每5分钟最多10次，防止邀请码暴力破解
    options.AddPolicy("JoinCirclePolicy", context =>
        RateLimitPartition.GetSlidingWindowLimiter(
            partitionKey: context.User?.FindFirst("sub")?.Value ?? GetClientIp(context),
            factory: _ => new SlidingWindowRateLimiterOptions
            {
                PermitLimit = 10,
                Window = TimeSpan.FromMinutes(5),
                SegmentsPerWindow = 2,
                QueueProcessingOrder = QueueProcessingOrder.OldestFirst,
                QueueLimit = 0
            }));

    // 紧急呼叫限流：每用户每分钟最多3次，防止恶意刷量
    options.AddPolicy("EmergencyPolicy", context =>
        RateLimitPartition.GetSlidingWindowLimiter(
            partitionKey: context.User?.FindFirst("sub")?.Value ?? GetClientIp(context),
            factory: _ => new SlidingWindowRateLimiterOptions
            {
                PermitLimit = 3,
                Window = TimeSpan.FromMinutes(1),
                SegmentsPerWindow = 2,
                QueueProcessingOrder = QueueProcessingOrder.OldestFirst,
                QueueLimit = 0
            }));

    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;

    // 限流触发时记录安全事件日志
    options.OnRejected = async (context, cancellationToken) =>
    {
        var logger = context.HttpContext.RequestServices.GetRequiredService<ILogger<Program>>();
        var clientIp = GetClientIp(context.HttpContext);
        var path = context.HttpContext.Request.Path;
        var method = context.HttpContext.Request.Method;
        var userId = context.HttpContext.User?.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value ?? "匿名";

        logger.LogWarning(
            "限流触发 | IP: {ClientIp} | 用户: {UserId} | 方法: {Method} | 路径: {Path} | 时间: {Timestamp:O}",
            clientIp, userId, method, path, DateTime.UtcNow);

        // 返回 JSON 格式的错误响应
        context.HttpContext.Response.ContentType = "application/json";
        await context.HttpContext.Response.WriteAsync(
            "{\"success\":false,\"message\":\"请求过于频繁，请稍后再试\",\"data\":null}",
            cancellationToken);
    };
});

var app = builder.Build();

// 中间件管道
if (app.Environment.IsDevelopment())
{
    var apiVersionDescriptionProvider = app.Services.GetRequiredService<IApiVersionDescriptionProvider>();
    app.UseSwagger();
    app.UseSwaggerUI(options =>
    {
        // 为每个 API 版本生成独立的 Swagger 端点
        foreach (var description in apiVersionDescriptionProvider.ApiVersionDescriptions)
        {
            options.SwaggerEndpoint($"/swagger/{description.GroupName}/swagger.json",
                $"CareForTheOld API {description.GroupName}");
        }
    });
}

app.UseMiddleware<ExceptionHandlingMiddleware>();
app.UseMiddleware<SecurityHeadersMiddleware>();
app.UseMiddleware<AuditLogMiddleware>();

// 生产环境强制 HTTPS
if (!app.Environment.IsDevelopment() && !app.Environment.IsEnvironment("Testing"))
{
    app.UseHsts();
    app.UseHttpsRedirection();
}

app.UseCors("ConfiguredCors");
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();

// Hangfire Dashboard（仅开发环境，生产环境需额外配置认证）
if (app.Environment.IsDevelopment())
{
    app.UseHangfireDashboard("/hangfire");
}

// 配置 Hangfire 定时任务（非测试环境）
if (!app.Environment.IsEnvironment("Testing"))
{
    RecurringJob.AddOrUpdate<MedicationReminderService>(
        "medication-reminder",
        service => service.ExecuteHangfireJobAsync(),
        Cron.Minutely);

    // Outbox 通知投递：每 10 秒检查一次待投递消息
    RecurringJob.AddOrUpdate<OutboxDispatchService>(
        "outbox-dispatch",
        service => service.DispatchOutboxMessagesAsync(),
        "*/10 * * * * *");

    // 心跳监控：每分钟检查老人端心跳状态
    RecurringJob.AddOrUpdate<HeartbeatMonitorService>(
        "heartbeat-monitor",
        service => service.CheckHeartbeatsAsync(),
        Cron.Minutely);
}

// 提供上传文件的静态访问（头像等）
var uploadsPath = Path.Combine(builder.Environment.ContentRootPath, "uploads");
Directory.CreateDirectory(uploadsPath);
app.UseStaticFiles(new StaticFileOptions
{
    FileProvider = new Microsoft.Extensions.FileProviders.PhysicalFileProvider(uploadsPath),
    RequestPath = "/uploads"
});

// 健康检查端点（无需认证，供容器编排和负载均衡器使用）
app.MapHealthChecks("/health");

// SignalR 连接状态端点（供运维监控使用）
app.MapGet("/health/signalr", (HttpContext _) =>
{
    return Results.Ok(new
    {
        onlineUsers = NotificationHub.OnlineUserCount,
        totalConnections = NotificationHub.TotalConnectionCount,
        timestamp = DateTime.UtcNow
    });
});

app.MapControllers();
app.MapHub<NotificationHub>("/hubs/notification");

app.Run();

// 使 Program 类可被测试项目访问
public partial class Program { }
