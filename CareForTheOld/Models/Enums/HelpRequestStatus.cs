namespace CareForTheOld.Models.Enums;

/// <summary>
/// 邻里求助请求状态
/// </summary>
public enum HelpRequestStatus
{
    /// <summary>待响应</summary>
    Pending = 0,

    /// <summary>已接受（邻居正在赶来）</summary>
    Accepted = 1,

    /// <summary>已取消（老人或子女取消）</summary>
    Cancelled = 2,

    /// <summary>已解决（事后确认）</summary>
    Resolved = 3,

    /// <summary>已过期（超时无人响应）</summary>
    Expired = 4,
}
