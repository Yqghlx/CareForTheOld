using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using CareForTheOld.Common.Constants;
using CareForTheOld.Data;
using CareForTheOld.Models.DTOs.Requests.Auth;
using CareForTheOld.Models.DTOs.Responses;
using CareForTheOld.Models.Entities;
using CareForTheOld.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Serilog;

namespace CareForTheOld.Services.Implementations;

/// <summary>
/// 认证服务实现
/// </summary>
public class AuthService : IAuthService
{
    private readonly AppDbContext _context;
    private readonly IConfiguration _configuration;
    private readonly ICacheService _cacheService;

    public AuthService(AppDbContext context, IConfiguration configuration, ICacheService cacheService)
    {
        _context = context;
        _configuration = configuration;
        _cacheService = cacheService;
    }

    /// <summary>
    /// 用户注册：检查手机号是否重复，使用 BCrypt 哈希密码后创建用户并返回令牌
    /// </summary>
    public async Task<AuthResponse> RegisterAsync(RegisterRequest request, CancellationToken cancellationToken = default)
    {
        // 检查手机号是否已注册
        if (await _context.Users.AnyAsync(u => u.PhoneNumber == request.PhoneNumber, cancellationToken))
            throw new ArgumentException(ErrorMessages.Auth.PhoneAlreadyRegistered);

        var user = new User
        {
            Id = Guid.NewGuid(),
            PhoneNumber = request.PhoneNumber,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.Password),
            RealName = request.RealName,
            BirthDate = request.BirthDate,
            Role = request.Role,
        };
        user.CreatedAt = user.UpdatedAt = DateTime.UtcNow;

        _context.Users.Add(user);
        await _context.SaveChangesAsync(cancellationToken);

        Log.Information("用户注册成功：{MaskedPhone}，角色：{Role}", MaskPhoneNumber(request.PhoneNumber), request.Role);

        return await GenerateAuthResponse(user, cancellationToken);
    }

    /// <summary>
    /// 用户登录：验证手机号和密码，成功后返回访问令牌和刷新令牌
    /// </summary>
    public async Task<AuthResponse> LoginAsync(LoginRequest request, CancellationToken cancellationToken = default)
    {
        var user = await _context.Users.FirstOrDefaultAsync(u => u.PhoneNumber == request.PhoneNumber, cancellationToken);

        if (user == null || !BCrypt.Net.BCrypt.Verify(request.Password, user.PasswordHash))
        {
            Log.Warning("登录失败：{MaskedPhone}，手机号或密码错误", MaskPhoneNumber(request.PhoneNumber));
            throw new ArgumentException(ErrorMessages.Auth.InvalidCredentials);
        }

        Log.Information("用户登录成功：{MaskedPhone}，角色：{Role}", MaskPhoneNumber(request.PhoneNumber), user.Role);
        return await GenerateAuthResponse(user, cancellationToken);
    }

    /// <summary>
    /// 刷新令牌：验证刷新令牌有效性，支持 Token 轮换机制并检测重放攻击
    /// </summary>
    public async Task<AuthResponse> RefreshTokenAsync(string token, CancellationToken cancellationToken = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(token, nameof(token));

        var refreshToken = await _context.RefreshTokens
            .AsTracking()
            .Include(rt => rt.User)
            .FirstOrDefaultAsync(rt => rt.Token == token, cancellationToken);

        if (refreshToken == null)
        {
            Log.Warning("刷新令牌无效：Token 不存在");
            throw new ArgumentException(ErrorMessages.Auth.InvalidRefreshToken);
        }

        // 检测 Token 重放攻击：已使用过的 Token 再次出现，说明可能被盗用
        if (refreshToken.IsUsed)
        {
            Log.Warning("检测到 Token 重放攻击，撤销用户 {UserId} 的所有令牌", refreshToken.UserId);
            // 撤销该用户所有刷新令牌（强制重新登录）
            var allTokens = await _context.RefreshTokens
                .AsTracking()
                .Where(rt => rt.UserId == refreshToken.UserId && !rt.IsRevoked)
                .ToListAsync(cancellationToken);
            foreach (var t in allTokens)
            {
                t.IsRevoked = true;
            }
            await _context.SaveChangesAsync(cancellationToken);
            throw new ArgumentException(ErrorMessages.Auth.SecurityAnomaly);
        }

        if (refreshToken.IsRevoked || refreshToken.ExpiresAt < DateTime.UtcNow)
        {
            Log.Warning("刷新令牌已过期或已撤销，用户：{UserId}", refreshToken.UserId);
            throw new ArgumentException(ErrorMessages.Auth.RefreshTokenExpired);
        }

        // 标记旧令牌为已使用（轮换）
        refreshToken.IsUsed = true;
        refreshToken.IsRevoked = true;

        // 清理该用户已过期的旧刷新令牌，防止数据库膨胀
        var expiredTokens = await _context.RefreshTokens
            .Where(rt => rt.UserId == refreshToken.UserId && rt.ExpiresAt < DateTime.UtcNow)
            .ToListAsync(cancellationToken);
        if (expiredTokens.Any())
        {
            _context.RefreshTokens.RemoveRange(expiredTokens);
        }

        Log.Information("令牌刷新成功，用户：{UserId}", refreshToken.UserId);
        return await GenerateAuthResponse(refreshToken.User, cancellationToken);
    }

    /// <summary>生成访问令牌和刷新令牌</summary>
    private async Task<AuthResponse> GenerateAuthResponse(User user, CancellationToken cancellationToken)
    {
        var accessToken = GenerateAccessToken(user);
        var refreshToken = GenerateRefreshToken();

        var expirationMinutes = int.Parse(_configuration[ConfigurationKeys.Jwt.AccessTokenExpirationMinutes] ?? AppConstants.Security.JwtAccessTokenExpirationMinutes.ToString());

        // 保存刷新令牌
        _context.RefreshTokens.Add(new RefreshToken
        {
            Id = Guid.NewGuid(),
            UserId = user.Id,
            Token = refreshToken,
            ExpiresAt = DateTime.UtcNow.AddDays(
                int.Parse(_configuration[ConfigurationKeys.Jwt.RefreshTokenExpirationDays] ?? AppConstants.Security.JwtRefreshTokenExpirationDays.ToString())),
            CreatedAt = DateTime.UtcNow
        });

        await _context.SaveChangesAsync(cancellationToken);

        return new AuthResponse
        {
            AccessToken = accessToken,
            RefreshToken = refreshToken,
            ExpiresAt = DateTime.UtcNow.AddMinutes(expirationMinutes),
            User = new UserResponse
            {
                Id = user.Id,
                PhoneNumber = user.PhoneNumber,
                RealName = user.RealName,
                BirthDate = user.BirthDate,
                Role = user.Role,
                AvatarUrl = user.AvatarUrl,
            }
        };
    }

    private string GenerateAccessToken(User user)
    {
        var key = new SymmetricSecurityKey(
            Encoding.UTF8.GetBytes(_configuration[ConfigurationKeys.Jwt.Key]!));
        var credentials = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var expirationMinutes = int.Parse(_configuration[ConfigurationKeys.Jwt.AccessTokenExpirationMinutes] ?? AppConstants.Security.JwtAccessTokenExpirationMinutes.ToString());

        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new Claim(ClaimTypes.Name, user.RealName),
            new Claim(ClaimTypes.Role, user.Role.ToString()),
            new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
        };

        var token = new JwtSecurityToken(
            issuer: _configuration[ConfigurationKeys.Jwt.Issuer] ?? "CareForTheOld",
            audience: _configuration[ConfigurationKeys.Jwt.Audience] ?? "CareForTheOld",
            claims: claims,
            expires: DateTime.UtcNow.AddMinutes(expirationMinutes),
            signingCredentials: credentials
        );

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    /// <summary>
    /// 登出：将 AccessToken 加入黑名单（TTL 为剩余有效期），吊销 RefreshToken
    /// </summary>
    public async Task LogoutAsync(string accessToken, string? refreshToken, CancellationToken cancellationToken = default)
    {
        // 解析 JWT 获取 jti 和过期时间
        var handler = new JwtSecurityTokenHandler();
        var jwt = handler.ReadJwtToken(accessToken);
        var jti = jwt.Claims.FirstOrDefault(c => c.Type == JwtRegisteredClaimNames.Jti)?.Value;
        var expClaim = jwt.Claims.FirstOrDefault(c => c.Type == JwtRegisteredClaimNames.Exp)?.Value;

        if (!string.IsNullOrEmpty(jti) && !string.IsNullOrEmpty(expClaim))
        {
            var exp = DateTimeOffset.FromUnixTimeSeconds(long.Parse(expClaim));
            var remaining = exp - DateTimeOffset.UtcNow;

            // 仅当 Token 未过期时加入黑名单（已过期的无需处理）
            if (remaining > TimeSpan.Zero)
            {
                await _cacheService.SetAsync(
                    $"{AppConstants.Cache.TokenBlacklistPrefix}{jti}",
                    "revoked",
                    remaining,
                    cancellationToken);
            }
        }

        // 吊销 RefreshToken
        if (!string.IsNullOrWhiteSpace(refreshToken))
        {
            var tokenEntity = await _context.RefreshTokens
                .AsTracking()
                .FirstOrDefaultAsync(rt => rt.Token == refreshToken, cancellationToken);

            if (tokenEntity != null && !tokenEntity.IsRevoked)
            {
                tokenEntity.IsRevoked = true;
                await _context.SaveChangesAsync(cancellationToken);
            }
        }

        Log.Information("用户登出成功");
    }

    /// <summary>
    /// 吊销用户所有令牌（密码修改、安全事件时调用）
    /// 同时吊销所有 RefreshToken 并将用户所有有效 AccessToken 加入黑名单
    /// </summary>
    public async Task RevokeAllUserTokensAsync(Guid userId, CancellationToken cancellationToken = default)
    {
        // 吊销所有未撤销的 RefreshToken
        var refreshTokens = await _context.RefreshTokens
            .AsTracking()
            .Where(rt => rt.UserId == userId && !rt.IsRevoked)
            .ToListAsync(cancellationToken);

        foreach (var rt in refreshTokens)
        {
            rt.IsRevoked = true;
        }

        if (refreshTokens.Any())
        {
            await _context.SaveChangesAsync(cancellationToken);
        }

        // 标记密码已更改，使该用户所有在此时间之前签发的 AccessToken 失效
        var expirationMinutes = int.Parse(_configuration[ConfigurationKeys.Jwt.AccessTokenExpirationMinutes] ?? AppConstants.Security.JwtAccessTokenExpirationMinutes.ToString());
        await _cacheService.SetAsync(
            $"{AppConstants.Cache.PasswordChangedPrefix}{userId}",
            DateTime.UtcNow.ToString("o"),
            TimeSpan.FromMinutes(expirationMinutes + AppConstants.Security.JwtClockSkewMinutes),
            cancellationToken);

        Log.Information("已吊销用户 {UserId} 的所有令牌并标记密码已更改", userId);
    }

    /// <summary>
    /// 检查 AccessToken 是否在黑名单中
    /// </summary>
    public static async Task<bool> IsTokenRevokedAsync(ICacheService cacheService, string jti, CancellationToken cancellationToken = default)
    {
        var value = await cacheService.GetAsync<string>($"{AppConstants.Cache.TokenBlacklistPrefix}{jti}", cancellationToken);
        return value != null;
    }

    private static string GenerateRefreshToken()
        => Convert.ToBase64String(RandomNumberGenerator.GetBytes(AppConstants.SecurityToken.RefreshTokenBytes));

    /// <summary>
    /// 手机号脱敏：138****1234
    /// </summary>
    private static string MaskPhoneNumber(string phone)
    {
        if (phone.Length >= 7)
            return string.Concat(phone.AsSpan(0, 3), "****", phone.AsSpan(phone.Length - 4));
        return "***";
    }
}
