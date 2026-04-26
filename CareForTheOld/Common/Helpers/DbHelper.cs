using Microsoft.EntityFrameworkCore;

namespace CareForTheOld.Common.Helpers;

/// <summary>
/// 数据库操作辅助工具
/// </summary>
public static class DbHelper
{
    /// <summary>
    /// 判断是否为唯一约束冲突异常（兼容 PostgreSQL 和 SQLite）
    /// PostgreSQL 返回错误码 "23505"（unique_violation）
    /// SQLite 返回 "UNIQUE constraint failed" 消息
    /// </summary>
    public static bool IsUniqueConstraintViolation(DbUpdateException ex)
    {
        var inner = ex.InnerException;
        if (inner == null) return false;
        var msg = inner.Message.ToUpperInvariant();
        return msg.Contains("UNIQUE") || msg.Contains("23505");
    }
}
