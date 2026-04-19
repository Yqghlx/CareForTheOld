using Asp.Versioning;
using Asp.Versioning.ApiExplorer;
using CareForTheOld.Common.Extensions;
using CareForTheOld.Common.Middleware;
using CareForTheOld.Data;
using CareForTheOld.Services.Background;
using CareForTheOld.Services.Hubs;
using CareForTheOld.Services.Implementations;
using CareForTheOld.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using Serilog;
using System.Threading.RateLimiting;

var builder = WebApplication.CreateBuilder(args);

// 配置 Serilog
Log.Logger = new LoggerConfiguration()
    .ReadFrom.Configuration(builder.Configuration)
    .Enrich.FromLogContext()
    .WriteTo.Console()
    .WriteTo.File("logs/carefortheold-.log", rollingInterval: RollingInterval.Day)
    .CreateLogger();

builder.Host.UseSerilog();

// JWT 密钥配置：优先从环境变量读取，开发/测试环境回退到默认值
var jwtSecretKey = Environment.GetEnvironmentVariable("JWT_SECRET_KEY")
    ?? builder.Configuration["Jwt:Key"];
if (string.IsNullOrWhiteSpace(jwtSecretKey))
{
    if (builder.Environment.IsDevelopment() || builder.Environment.IsEnvironment("Testing"))
    {
        // 开发/测试环境使用固定密钥
        jwtSecretKey = "CareForTheOld_DevSecretKey_2026_MustBe32Chars!";
        builder.Configuration["Jwt:Key"] = jwtSecretKey;
    }
    else
    {
        // 生产环境必须通过环境变量 JWT_SECRET_KEY 配置，否则拒绝启动
        throw new InvalidOperationException(
            "生产环境必须通过环境变量 JWT_SECRET_KEY 配置 JWT 密钥。" +
            "密钥长度至少 32 个字符。");
    }
}
else
{
    builder.Configuration["Jwt:Key"] = jwtSecretKey;
}

// 注册服务
builder.Services.AddControllers();
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
builder.Services.AddJwtAuthentication(builder.Configuration);
builder.Services.AddSwaggerServices();
builder.Services.AddHealthCheckServices(builder.Configuration);
builder.Services.AddSignalR();

// 注册业务服务
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<IUserService, UserService>();
builder.Services.AddScoped<IFamilyService, FamilyService>();
builder.Services.AddScoped<IHealthService, HealthService>();
builder.Services.AddScoped<IHealthAlertService, HealthAlertService>();
builder.Services.AddScoped<IMedicationService, MedicationService>();
builder.Services.AddScoped<INotificationService, NotificationService>();
builder.Services.AddScoped<IEmergencyService, EmergencyService>();
builder.Services.AddScoped<ILocationService, LocationService>();
builder.Services.AddScoped<IGeoFenceService, GeoFenceService>();
builder.Services.AddScoped<IHealthReportService, HealthReportService>();
builder.Services.AddScoped<ICacheService, CacheService>();

// 注册分布式缓存：优先使用 Redis，未配置时回退到内存缓存
var redisConnection = builder.Configuration.GetConnectionString("Redis");
if (!string.IsNullOrEmpty(redisConnection))
{
    builder.Services.AddStackExchangeRedisCache(options => options.Configuration = redisConnection);
}
else
{
    builder.Services.AddDistributedMemoryCache();
}

// 注册后台服务
builder.Services.AddHostedService<MedicationReminderService>();

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
builder.Services.AddRateLimiter(options =>
{
    // 认证接口限流：每 IP 每分钟 10 次
    options.AddPolicy("AuthPolicy", context =>
        RateLimitPartition.GetSlidingWindowLimiter(
            partitionKey: context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
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
            partitionKey: context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
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
            partitionKey: context.User?.FindFirst("sub")?.Value ?? context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            factory: _ => new SlidingWindowRateLimiterOptions
            {
                PermitLimit = 5,
                Window = TimeSpan.FromMinutes(5),
                SegmentsPerWindow = 2,
                QueueProcessingOrder = QueueProcessingOrder.OldestFirst,
                QueueLimit = 0
            }));

    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
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

app.MapControllers();
app.MapHub<NotificationHub>("/hubs/notification");

app.Run();

// 使 Program 类可被测试项目访问
public partial class Program { }
