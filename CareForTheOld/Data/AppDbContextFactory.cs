using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace CareForTheOld.Data;

/// <summary>
/// EF Core 设计时 DbContext 工厂
///
/// 供 dotnet ef migrations 命令使用，避免启动时对 Redis、JWT 等生产配置的依赖检查。
/// 连接字符串通过环境变量 ConnectionStrings__DefaultConnection 注入，
/// 未配置时默认使用 PostgreSQL 本地连接。
/// </summary>
public class AppDbContextFactory : IDesignTimeDbContextFactory<AppDbContext>
{
    public AppDbContext CreateDbContext(string[] args)
    {
        var connectionString = Environment.GetEnvironmentVariable("ConnectionStrings__DefaultConnection")
            ?? "Host=localhost;Port=5432;Database=carefortheold;Username=postgres;Password=postgres";

        var optionsBuilder = new DbContextOptionsBuilder<AppDbContext>();
        optionsBuilder.UseNpgsql(connectionString)
            .UseQueryTrackingBehavior(QueryTrackingBehavior.NoTracking);

        return new AppDbContext(optionsBuilder.Options);
    }
}
