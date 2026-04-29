using CareForTheOld.Common.Helpers;
using CareForTheOld.Data;
using CareForTheOld.Models.Entities;
using CareForTheOld.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace CareForTheOld.Services.Implementations;

/// <summary>
/// 设备令牌管理服务实现
/// </summary>
public class DeviceService : IDeviceService
{
    private readonly AppDbContext _context;
    private readonly ILogger<DeviceService> _logger;

    public DeviceService(AppDbContext context, ILogger<DeviceService> logger)
    {
        _context = context;
        _logger = logger;
    }

    /// <inheritdoc />
    public async Task RegisterTokenAsync(Guid userId, string token, string platform, CancellationToken cancellationToken = default)
    {
        var now = DateTime.UtcNow;

        // 查找是否已有相同 token 的记录（同一设备可能换了用户）
        var existingToken = await _context.DeviceTokens
            .AsTracking()
            .FirstOrDefaultAsync(dt => dt.Token == token, cancellationToken);

        if (existingToken != null)
        {
            // 更新关联用户和活跃时间
            existingToken.UserId = userId;
            existingToken.Platform = platform;
            existingToken.LastActiveAt = now;
        }
        else
        {
            // 新设备，创建 token 记录
            _context.DeviceTokens.Add(new DeviceToken
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                Token = token,
                Platform = platform,
                CreatedAt = now,
                LastActiveAt = now,
            });
        }

        try
        {
            await _context.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException ex) when (DbHelper.IsUniqueConstraintViolation(ex))
        {
            // 并发注册同一 token 的唯一约束冲突，回查并更新关联用户
            _logger.LogWarning("设备 token 并发注册冲突，用户 {UserId}，回查更新", userId);
            var conflict = await _context.DeviceTokens
                .AsTracking()
                .FirstOrDefaultAsync(dt => dt.Token == token, cancellationToken);
            if (conflict != null)
            {
                conflict.UserId = userId;
                conflict.Platform = platform;
                conflict.LastActiveAt = now;
                await _context.SaveChangesAsync(cancellationToken);
            }
        }

        _logger.LogInformation("FCM token 已注册: 用户={UserId}, 平台={Platform}", userId, platform);
    }

    /// <inheritdoc />
    public async Task<int> DeleteTokensAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        var tokens = await _context.DeviceTokens
            .Where(dt => dt.UserId == userId)
            .ToListAsync(cancellationToken);

        if (tokens.Count > 0)
        {
            _context.DeviceTokens.RemoveRange(tokens);
            await _context.SaveChangesAsync(cancellationToken);
        }

        _logger.LogInformation("FCM token 已清除: 用户={UserId}, 数量={Count}", userId, tokens.Count);
        return tokens.Count;
    }
}
