using CareForTheOld.Common.Extensions;
using CareForTheOld.Common.Middleware;
using CareForTheOld.Data;
using CareForTheOld.Services.Background;
using CareForTheOld.Services.Hubs;
using CareForTheOld.Services.Implementations;
using CareForTheOld.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

// 配置 Serilog
Log.Logger = new LoggerConfiguration()
    .ReadFrom.Configuration(builder.Configuration)
    .Enrich.FromLogContext()
    .WriteTo.Console()
    .WriteTo.File("logs/carefortheold-.log", rollingInterval: RollingInterval.Day)
    .CreateLogger();

builder.Host.UseSerilog();

// 注册服务
builder.Services.AddControllers();
builder.Services.AddDatabaseServices(builder.Configuration);
builder.Services.AddJwtAuthentication(builder.Configuration);
builder.Services.AddSwaggerServices();
builder.Services.AddSignalR();

// 注册业务服务
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<IUserService, UserService>();
builder.Services.AddScoped<IFamilyService, FamilyService>();
builder.Services.AddScoped<IHealthService, HealthService>();
builder.Services.AddScoped<IMedicationService, MedicationService>();
builder.Services.AddScoped<INotificationService, NotificationService>();

// 注册后台服务
builder.Services.AddHostedService<MedicationReminderService>();

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

var app = builder.Build();

// 开发环境自动迁移
if (app.Environment.IsDevelopment())
{
    using var scope = app.Services.CreateScope();
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    // 注意：迁移将在后续 Task 中创建，这里暂时注释
    // await db.Database.MigrateAsync();
}

// 中间件管道
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseMiddleware<ExceptionHandlingMiddleware>();
app.UseCors("AllowAll");
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
app.MapHub<NotificationHub>("/hubs/notification");

app.Run();

// 使 Program 类可被测试项目访问
public partial class Program { }