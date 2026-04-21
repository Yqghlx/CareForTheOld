# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

CareForTheOld（关爱老人）是一个全栈应用，包含 ASP.NET Core 10 后端 API 和 Flutter 前端客户端。核心功能：老人健康数据记录与趋势分析、用药提醒与管理、紧急呼叫、GPS 位置追踪与电子围栏、实时通知推送。

## 常用命令

### 后端
```bash
dotnet build                                    # 编译
dotnet build --configuration Release            # Release 编译
dotnet test                                     # 运行全部测试
dotnet test --filter "FullyQualifiedName~AuthServiceTests"  # 运行单个测试类
dotnet run                                      # 启动开发服务器
dotnet ef migrations add <Name>                 # 添加迁移（生产环境用）
```

### 前端
```bash
cd flutter_client
flutter pub get                                 # 安装依赖
flutter analyze --no-fatal-infos                # 静态分析（忽略 info 级别）
flutter run -d <device>                         # 运行
flutter build apk --release --dart-define=APP_ENV=production  # 构建 APK
flutter build apk --release --dart-define=SENTRY_DSN=<dsn>     # 构建 APK（含 Sentry）
```

### Docker
```bash
cp .env.example .env  # 首次需要配置环境变量
docker-compose up -d --build
docker-compose logs -f api
```

## 开发流程

**每完成一个功能后，按顺序执行**：后端编译 → Flutter analyze → git commit → 再做下一个。

## 架构

### 后端分层

```
Controllers/          → 薄层，仅处理 HTTP 请求/响应，权限用 [Authorize(Roles="...")]
Services/Interfaces/  → 业务接口定义（含 IFileStorageService、IKeyProvider、IHealthQueryService）
Services/Implementations/ → 业务逻辑实现（含 Dapper 查询、Outbox 投递、文件存储）
Data/Configurations/  → EF Core FluentAPI 实体配置（自动加载，无需手动注册）
Models/DTOs/Requests/ → 按子目录分组（Auth/、Health/、Medication/ 等）
Models/DTOs/Responses/→ 扁平存放
Models/Entities/      → 数据库实体（含 NotificationOutbox）
Models/Enums/         → 枚举定义
Common/Middleware/    → 三个中间件：异常处理、安全头、审计日志
Common/Extensions/    → 扩展方法（ServiceCollection、Controller、String 脱敏）
Services/Hubs/        → SignalR NotificationHub（含心跳检测）
Services/Background/  → 后台服务（用药提醒、Outbox 投递、心跳监控）
```

### 关键后端模式

- **查询跟踪**：全局 `QueryTrackingBehavior.NoTracking`。写操作必须显式使用 `AsTracking()`，否则 `SaveChangesAsync` 不会更新实体。
- **CQRS 读写分离**：高频只读查询使用 Dapper（`DapperHealthQueryService`），写操作保留 EF Core 强类型保障。`IHealthQueryService` 为查询端接口。
- **Outbox Pattern**：`NotificationService.SendToUserAsync` 在同一事务中写入 `NotificationRecord` 和 `NotificationOutbox`，`OutboxDispatchService` 后台 Job（每 10 秒）异步投递 SignalR 消息，确保最终一致性。
- **认证**：JWT Bearer Token。通过 `IKeyProvider` 抽象获取密钥，开发环境 `ConfigurationKeyProvider`，生产环境 `EnvironmentKeyProvider`。
- **角色**：`UserRole.Elder`（老人）和 `UserRole.Child`（子女），控制器用 `[Authorize(Roles = "Child")]` 控制权限。
- **数据库**：开发环境 SQLite（`EnsureCreated`），生产环境 PostgreSQL（`Migrate`），测试 InMemory。新增实体后需删除旧 SQLite 文件重建。
- **唯一约束防竞态**：`FamilyMember.UserId` 有唯一索引（一人只能加入一个家庭），Service 层捕获 `DbUpdateException` 并转为友好错误。
- **手机号脱敏**：`StringExtensions.MaskPhoneNumber()` 扩展方法，所有非本人手机号在响应中脱敏为 `138****8000`。
- **DTO 校验**：Request DTO 使用 DataAnnotations `[Required]`、`[MaxLength]` 等，不使用 FluentValidation。
- **API 响应格式统一**：通过 `ControllerExtensions.ToApiResponse()` 封装为 `ApiResponse<T>` 格式。
- **文件存储抽象**：`IFileStorageService` 接口（UploadAsync/GetUrlAsync/DeleteAsync），当前 `LocalFileStorageService` 实现，生产环境可替换为 OSS/S3。
- **GeoFence 缓存热点化**：围栏数据缓存至 Redis（key: `geofence:{elderId}`，10 分钟过期），`GetOrCreateAsync` 防击穿，写操作后自动刷新缓存。
- **心跳检测**：前端每 60 秒发送 `Heartbeat`，后端 `HeartbeatMonitorService`（每分钟）检测超 5 分钟无心跳的老人并通知子女。
- **Hangfire 后台调度**：用药提醒（每分钟）、Outbox 投递（每 10 秒）、心跳监控（每分钟）。开发环境 InMemory 存储，生产 PostgreSQL 持久化。

### 前端分层

```
lib/
├── core/           → API 客户端、路由、主题、配置、验证器
│                   → services/ 含离线队列（OfflineQueueService）
├── features/
│   ├── auth/       → 登录注册
│   ├── elder/      → 老人端（健康录入、用药、首页、位置上报）
│   ├── child/      → 子女端（老人健康查看、用药管理、围栏管理、紧急呼叫）
│   └── shared/     → 两端共用（通知、设置、SignalR 服务）
└── shared/         → 全局共享组件、模型、Provider
```

### 关键前端模式

- **状态管理**：Riverpod `StateNotifierProvider`。业务 Provider 按 feature 分目录放置。
- **路由**：GoRouter，`app_router.dart` 中的 `redirect` 守卫根据认证状态和角色重定向。
- **环境切换**：`AppConfig.current` 改一行即可切换 dev/staging/production。
- **Token 刷新**：`ApiClient` 自动检测 401 → 用独立 `_refreshDio` 刷新 → 排队重试，避免递归。
- **适老化设计**：老人端字体偏大（bodyMedium=18, bodyLarge=22），紧急按钮需长按 2 秒触发。
- **网络状态**：离线时 API 拦截器直接拒绝请求并弹出 SnackBar 提示。
- **离线队列**：`OfflineQueueService` 使用 Hive 本地数据库，断网时位置/健康数据存入队列，网络恢复后自动批量上传。
- **心跳发送**：`SignalRService` 连接成功后每 60 秒调用 Hub 的 `Heartbeat` 方法。

### 中间件管道顺序（不可调换）

```
Swagger → ExceptionHandlingMiddleware → SecurityHeadersMiddleware → AuditLogMiddleware
→ HSTS/HTTPS → CORS → RateLimiter → Authentication → Authorization → Controllers
```

### 限流策略

认证接口 10次/IP/分钟，通用 API 60次/IP/分钟，加入家庭 5次/用户/5分钟，紧急呼叫 3次/用户/1分钟。

## 测试

后端 194 个 xUnit 单元测试（143 Service + 51 Controller），覆盖全部 Service 和全部 9 个 Controller。测试项目：`CareForTheOld.Tests/`。
前端 36 个 Flutter 测试（表单验证、模型序列化、烟雾测试），测试目录：`flutter_client/test/`。

- 使用 InMemory 数据库 + Moq + FluentAssertions
- 每个 Service 测试文件中的 `CreateTestDataAsync()` 辅助方法创建完整家庭关系数据
- 测试中涉及 `GeoFenceService`、`MedicationService` 等需要家庭关系的操作时，必须先调用 `CreateTestFamilyAsync()` 建立家庭成员关系
- EF Core 全局 NoTracking 后，涉及 `Update`/`Delete` 的测试需确保 Service 内部使用了 `AsTracking()`
- `GeoFenceService` 构造函数需要 `ICacheService` 参数，测试中需 mock 并让 `GetOrCreateAsync` 直接执行 factory
- 集成测试使用 Testcontainers PostgreSQL（`PostgreSqlFixture`），标记 `[Collection("PostgreSql")]`

## 环境配置

后端通过 `.env` 文件注入（见 `.env.example`），必需变量：`POSTGRES_PASSWORD`、`JWT_SECRET_KEY`。
前端 Sentry DSN 通过编译参数注入：`--dart-define=SENTRY_DSN=<value>`。
