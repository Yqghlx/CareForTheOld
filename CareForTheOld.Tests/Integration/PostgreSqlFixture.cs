using CareForTheOld.Data;
using DotNet.Testcontainers.Builders;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using Testcontainers.PostgreSql;
using Xunit;

namespace CareForTheOld.Tests.Integration;

/// <summary>
/// PostgreSQL 容器共享 Fixture
/// 所有集成测试类共用同一个容器实例，减少启动开销
/// </summary>
public class PostgreSqlFixture : IAsyncLifetime
{
    private readonly PostgreSqlContainer _container = new PostgreSqlBuilder("postgres:16-alpine")
        .WithDatabase("carefortheold_test")
        .WithUsername("test")
        .WithPassword("test_password_2026")
        .WithCleanUp(true)
        .Build();

    /// <summary>容器启动后的连接字符串</summary>
    public string ConnectionString => _container.GetConnectionString();

    /// <summary>创建连接到真实 PostgreSQL 的 DbContext</summary>
    public AppDbContext CreateDbContext()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseNpgsql(ConnectionString)
            .Options;
        return new AppDbContext(options);
    }

    public async Task InitializeAsync()
    {
        await _container.StartAsync();
        // 使用 Migrate 确保数据库结构完整（与生产环境一致）
        using var context = CreateDbContext();
        await context.Database.EnsureCreatedAsync();
    }

    public async Task DisposeAsync()
    {
        await _container.DisposeAsync();
    }
}

/// <summary>
/// 集成测试集合标记（共享容器实例）
/// 用法：[Collection("PostgreSql")] 加在测试类上
/// </summary>
[CollectionDefinition("PostgreSql", DisableParallelization = true)]
public class PostgreSqlCollection : ICollectionFixture<PostgreSqlFixture>
{
    // 空类，仅用于 xUnit 集合定义
}
