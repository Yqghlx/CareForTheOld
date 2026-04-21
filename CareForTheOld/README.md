# 关爱老人后端 API

ASP.NET Core 10 后端服务，为关爱老人 App 提供 RESTful API 和 SignalR 实时通信。

## 技术栈

| 类别 | 技术 |
|------|------|
| 框架 | ASP.NET Core 10 |
| 数据库 | PostgreSQL (生产) / SQLite (开发) / InMemory (测试) |
| ORM | EF Core (写操作) + Dapper (高频只读查询) |
| 认证 | JWT Bearer Token |
| 实时通信 | SignalR (WebSocket) |
| 后台任务 | Hangfire (用药提醒、心跳检测、通知投递) |
| 缓存 | Redis (电子围栏缓存) |
| 文件存储 | IFileStorageService (本地/OSS抽象) |
| API 文档 | Swagger |

## 项目结构

```
CareForTheOld/
├── Controllers/               # API 控制器
│   ├── AuthController.cs      # 认证
│   ├── HealthController.cs    # 健康数据
│   ├── MedicationController.cs # 用药管理
│   ├── EmergencyController.cs # 紧急呼叫
│   ├── LocationController.cs  # 位置上报
│   ├── GeoFenceController.cs  # 电子围栏
│   ├── NotificationController.cs # 通知
│   └── FamilyController.cs    # 家庭管理
│
├── Services/
│   ├── Interfaces/            # 接口定义
│   │   ├── IAuthService.cs
│   │   ├── IHealthService.cs
│   │   ├── IMedicationService.cs
│   │   ├── INotificationService.cs
│   │   ├── IFileStorageService.cs
│   │   └── ICacheService.cs
│   │
│   ├── Implementations/       # 实现
│   │   ├── AuthService.cs
│   │   ├── HealthService.cs
│   │   ├── MedicationService.cs
│   │   ├── DapperHealthQueryService.cs  # Dapper 高效查询
│   │   ├── NotificationService.cs       # Outbox Pattern
│   │   └── GeoFenceService.cs           # Redis 缓存
│   │
│   ├── Background/            # 后台服务
│   │   ├── MedicationReminderService.cs # 用药提醒 Job
│   │   ├── OutboxDispatchService.cs     # 通知投递 Job
│   │   └── HeartbeatMonitorService.cs   # 心跳检测 Job
│   │
│   └── Hubs/
│       └── NotificationHub.cs          # SignalR Hub
│
├── Models/
│   ├── Entities/              # 数据库实体
│   │   ├── User.cs
│   │   ├── HealthRecord.cs
│   │   ├── MedicationPlan.cs
│   │   ├── MedicationLog.cs
│   │   ├── EmergencyCall.cs
│   │   ├── LocationRecord.cs
│   │   ├── GeoFence.cs
│   │   ├── NotificationRecord.cs
│   │   ├── NotificationOutbox.cs       # Outbox Pattern
│   │   └── FamilyMember.cs
│   │
│   ├── DTOs/
│   │   ├── Requests/          # 请求 DTO (按模块分组)
│   │   └── Responses/         # 响应 DTO
│   │
│   └ Enums/                   # 枚举
│   │   ├── UserRole.cs
│   │   ├── HealthType.cs
│   │   ├── MedicationStatus.cs
│   │   ├── EmergencyStatus.cs
│   │   └── NotificationType.cs
│
├── Data/
│   ├── AppDbContext.cs        # EF Core 上下文
│   └── Configurations/        # FluentAPI 配置
│
├── Common/
│   ├── Middleware/            # 中间件
│   │   ├── ExceptionHandlingMiddleware.cs
│   │   ├── SecurityHeadersMiddleware.cs
│   │   └── AuditLogMiddleware.cs
│   │
│   └── Extensions/            # 扩展方法
│       ├── ServiceCollectionExtensions.cs
│       ├── ControllerExtensions.cs      # ApiResponse 封装
│       └── StringExtensions.cs          # 手机号脱敏
│
├── CareForTheOld.Tests/       # 测试项目
│   ├── Services/              # Service 测试
│   ├── Concurrency/           # 并发测试
│   └── PostgreSqlFixture.cs   # Testcontainers
│
└── docs/                      # 设计文档
```

## 运行项目

### 开发环境 (SQLite)

```bash
dotnet run
```

API 地址: `http://localhost:5000`

### Docker 环境 (PostgreSQL)

```bash
cd ..
docker-compose up -d --build
```

API 地址: `http://localhost:5001`

## 测试

```bash
# 运行全部测试
dotnet test

# 运行单个测试类
dotnet test --filter "FullyQualifiedName~AuthServiceTests"

# 运行集成测试 (Testcontainers)
dotnet test --filter "FullyQualifiedName~ConcurrencyTests"
```

测试覆盖: **160 个测试通过**

## 数据库迁移

```bash
# 开发环境使用 EnsureCreated，无需迁移
# 生产环境使用 PostgreSQL 迁移
dotnet ef migrations add InitialCreate
dotnet ef database update
```

## API 文档

启动后访问 Swagger: `http://localhost:5000/swagger`

## 主要 API 接口

### 认证 `/auth`
| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/login` | 登录 |
| POST | `/register` | 注册 |
| POST | `/refresh` | 刷新 Token |
| POST | `/logout` | 登出 |

### 健康数据 `/health`
| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/me` | 我的健康记录 |
| GET | `/me/stats` | 我的健康统计 |
| POST | `/` | 创建健康记录 |
| DELETE | `/{id}` | 删除记录 |
| GET | `/me/report` | 导出报告 PDF |
| GET | `/family/{familyId}/member/{memberId}/report` | 子女导出老人报告 |

### 用药管理 `/medication`
| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/plans/me` | 我的用药计划 |
| GET | `/plans/elder/{elderId}` | 老人的用药计划 |
| POST | `/plans` | 创建用药计划 |
| PUT | `/plans/{id}` | 更新用药计划 |
| DELETE | `/plans/{id}` | 删除用药计划 |
| GET | `/today-pending` | 今日待服药 |
| POST | `/logs` | 记录用药日志 |
| GET | `/logs/me` | 我的用药日志 |
| GET | `/logs/elder/{elderId}` | 老人的用药日志 |

### 紧急呼叫 `/emergency`
| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/calls` | 创建紧急呼叫 |
| GET | `/calls/me` | 我的紧急呼叫 |
| GET | `/calls/unread` | 未处理的呼叫 |
| PUT | `/calls/{id}/respond` | 处理呼叫 |

### 位置 `/location`
| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/report` | 上报位置 |
| GET | `/me` | 我的位置记录 |
| GET | `/elder/{elderId}` | 老人位置 |

### 电子围栏 `/geofence`
| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/elder/{elderId}` | 获取围栏 |
| POST | `/` | 创建围栏 |
| PUT | `/` | 更新围栏 |
| DELETE | `/{id}` | 删除围栏 |

### 通知 `/notification`
| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/me` | 我的通知列表 |
| GET | `/me/unread-count` | 未读数量 |
| PUT | `/{id}/read` | 标记已读 |
| PUT | `/me/read-all` | 全部已读 |

### 家庭 `/family`
| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/me` | 我的家庭 |
| POST | `/join` | 加入家庭 |
| POST | `/create` | 创建家庭 |

## SignalR 实时通知

连接地址: `/hubs/notification`

### 接收通知
```javascript
connection.on('ReceiveNotification', (type, data) => {
  // type: 通知类型
  // data: 通知内容
});
```

### 发送心跳
```javascript
connection.invoke('Heartbeat');
```

### 通知类型
| ID | 类型 | 说明 |
|----|------|------|
| 1 | MedicationReminder | 用药提醒 |
| 2 | MedicationReminderFamily | 用药提醒通知 |
| 3 | MedicationMissed | 未服药告警 |
| 4 | EmergencyCall | 紧急呼叫 |
| 5 | EmergencyCallReminder | 紧急呼叫二次提醒 |
| 6 | GeoFenceAlert | 围栏告警 |
| 7 | HealthAlert | 健康异常 |
| 8 | HeartbeatAlert | 设备离线 |

## 安全特性

- **JWT 认证** - Access Token + Refresh Token 轮换
- **角色权限** - `[Authorize(Roles = "Child")]` 控制接口访问
- **API 限流** - 认证 10次/IP/分钟，通用 API 60次/IP/分钟
- **安全头** - XSS、CSRF、点击劫持防护
- **审计日志** - 记录敏感操作
- **密码策略** - 8位+字母+数字
- **手机号脱敏** - 非本人手机号部分隐藏

## 后台任务 (Hangfire)

| 任务 | 间隔 | 说明 |
|------|------|------|
| 用药提醒检查 | 每分钟 | 检查是否需要发送用药提醒 |
| 通知投递 | 每 10 秒 | 投递 Outbox 中的通知 |
| 心跳检测 | 每分钟 | 检查老人设备是否离线 |

Hangfire Dashboard: `http://localhost:5000/hangfire`

## 环境变量

```bash
# 数据库
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_USER=carefortheold
POSTGRES_PASSWORD=your_password
POSTGRES_DB=carefortheold

# JWT
JWT_SECRET_KEY=Your_Secret_Key_Min_32_Characters!
JWT_ISSUER=CareForTheOld
JWT_AUDIENCE=CareForTheOld
JWT_EXPIRY_MINUTES=60

# Redis (可选)
REDIS_HOST=localhost
REDIS_PORT=6379
```

## 相关文档

- [项目 README](../README.md) - 项目整体介绍
- [部署指南](../DEPLOYMENT.md) - Docker 部署说明
- [开发指南](../CLAUDE.md) - Claude Code 开发指南