# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

CareForTheOld（关爱老人）是一个全栈应用，包含 ASP.NET Core 10 后端 API 和 Flutter 前端客户端。核心功能：老人健康数据记录与趋势分析、用药提醒与管理、紧急呼叫（含 SMS 多通道告警）、GPS 位置追踪与电子围栏、实时通知推送、OCR 拍照识别健康数据、AI 异常检测趋势预警。

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
Services/Interfaces/  → 业务接口定义（含 IFileStorageService、IKeyProvider、IHealthQueryService、ISmsService）
Services/Implementations/ → 业务逻辑实现（含 Dapper 查询、Outbox 投递、文件存储、短信服务、异常检测）
Data/Configurations/  → EF Core FluentAPI 实体配置（自动加载，无需手动注册）
Models/DTOs/Requests/ → 按子目录分组（Auth/、Health/、Medication/ 等）
Models/DTOs/Responses/→ 扁平存放
Models/Entities/      → 数据库实体（含 NotificationOutbox、SmsRecord）
Models/Enums/         → 枚举定义
Common/Middleware/    → 三个中间件：异常处理、安全头、审计日志
Common/Helpers/       → 工具类（ApiResponse、GeoHelper 距离计算）
Common/Filters/       → Action 过滤器（CacheControlAttribute 缓存控制头）
Common/Extensions/    → 扩展方法（ServiceCollection、Controller、String 脱敏）
Services/Hubs/        → SignalR NotificationHub（含心跳检测）
Services/Background/  → 后台服务（用药提醒、Outbox 投递、心跳监控）
```

### 关键后端模式

- **查询跟踪**：全局 `QueryTrackingBehavior.NoTracking`。写操作必须显式使用 `AsTracking()`，否则 `SaveChangesAsync` 不会更新实体。
  - ⚠️ **易踩坑**：`FindAsync()` 在 NoTracking 模式下返回的实体不被跟踪，修改后调用 `SaveChangesAsync` 不会生效！
  - 正确做法：用 `_context.Users.AsTracking().FirstOrDefaultAsync(u => u.Id == userId)` 替代 `_context.Users.FindAsync(userId)`。
  - 已修复的 Bug：`UserService.ChangePasswordAsync` 密码修改返回成功但实际未更新、`FamilyService.RefreshInviteCodeAsync` 邀请码刷新失效。
- **CQRS 读写分离**：高频只读查询使用 Dapper（`DapperHealthQueryService`），写操作保留 EF Core 强类型保障。`IHealthQueryService` 为查询端接口。
- **Outbox Pattern**：`NotificationService.SendToUserAsync` 在同一事务中写入 `NotificationRecord` 和 `NotificationOutbox`，`OutboxDispatchService` 后台 Job（每 10 秒）异步投递 SignalR 消息，确保最终一致性。
- **认证**：JWT Bearer Token。通过 `IKeyProvider` 抽象获取密钥，开发环境 `ConfigurationKeyProvider`，生产环境 `EnvironmentKeyProvider`。
- **角色**：`UserRole.Elder`（老人）和 `UserRole.Child`（子女），控制器用 `[Authorize(Roles = "Child")]` 控制权限。
- **数据库**：开发环境 SQLite（`EnsureCreated`），生产环境 PostgreSQL（`Migrate`），测试 InMemory。新增实体后需删除旧 SQLite 文件重建。
- **唯一约束防竞态**：`FamilyMember.UserId` 有唯一索引（一人只能加入一个家庭），`MedicationLog.PlanId+ScheduledAt` 有唯一索引（防并发重复记录）。Service 层统一使用 `IsUniqueConstraintViolation(ex)` 判断异常（兼容 PostgreSQL 23505 和 SQLite UNIQUE constraint failed），在 `FamilyService`、`MedicationService`、`NeighborCircleService`、`NeighborHelpService` 中使用。
- **GeoHelper 距离计算**：`Common/Helpers/GeoHelper.HaversineDistance()` 统一提供球面距离计算，被 `GeoFenceService`、`NeighborCircleService`、`NeighborHelpService` 引用。新增地理位置相关功能时使用此类，不要重新实现。
- **CacheControlAttribute**：`Common/Filters/CacheControlFilter.cs`，为 GET 接口添加 `Cache-Control` 响应头。用法：`[CacheControl(MaxAgeSeconds = 300)]`。健康统计/异常检测 300 秒，位置/通知 30 秒。
- **家庭成员验证**：`IFamilyService.EnsureFamilyMemberAsync` 公共方法统一验证操作者权限，`MedicationService`、`GeoFenceService` 等通过依赖注入复用。
- **手机号脱敏**：`StringExtensions.MaskPhoneNumber()` 扩展方法，所有非本人手机号在响应中脱敏为 `138****8000`。
- **DTO 校验**：Request DTO 使用 DataAnnotations `[Required]`、`[MaxLength]` 等，不使用 FluentValidation。
- **API 响应格式统一**：通过 `ControllerExtensions.ToApiResponse()` 封装为 `ApiResponse<T>` 格式。
- **文件存储抽象**：`IFileStorageService` 接口（UploadAsync/GetUrlAsync/DeleteAsync），当前 `LocalFileStorageService` 实现，生产环境可替换为 OSS/S3。
- **GeoFence 缓存热点化**：围栏数据缓存至 Redis（key: `geofence:{elderId}`，10 分钟过期），`GetOrCreateAsync` 防击穿，写操作后自动刷新缓存。
- **心跳检测**：前端每 60 秒发送 `Heartbeat`，后端 `HeartbeatMonitorService`（每分钟）检测超 5 分钟无心跳的老人并通知子女。
- **Hangfire 后台调度**：用药提醒（每分钟）、Outbox 投递（每 10 秒）、心跳监控（每分钟）、信任评分重算（每日凌晨 3:00）、自动救援检查（每分钟）。开发环境 InMemory 存储，生产 PostgreSQL 持久化。
- **SMS 多通道告警**：`ISmsService` 接口抽象，`AliyunSmsService`（国内阿里云）、`TwilioSmsService`（国际备用），通过 `Sms:Provider` 配置切换。紧急呼叫时异步发送 SMS 给子女，`SmsRecord` 记录审计追溯。开发环境模拟发送。
- **OCR 健康录入**：`OcrParserService` 使用 `google_mlkit_text_recognition` 本地识别图片文字，正则匹配血压/血糖/心率/体温数值。抛出 `OcrException`（含 `OcrErrorType`：权限拒绝/格式不支持/识别失败等）。
- **健康异常检测**：`HealthAnomalyDetector` 基于个人 30 天基线检测四种异常：峰值（>30%）、持续偏高/偏低（>20% 连续 3 天）、波动性（标准差 >2 倍）。严重度 0-100 评分，血压/血糖权重 1.5 倍。API 端点：`GET /me/anomaly-detection`。
- **信任评分系统**：`ITrustScoreService` / `TrustScoreService`，基于互助历史数据量化邻居可信度。算法：AvgRating×8×0.4 + Min(TotalHelps/20,1)×100×0.3 + ResponseRate×100×0.3。`HelpNotificationLog` 记录每次广播通知的邻居响应情况，`TrustScore` 保存综合评分。广播时按评分降序排序，高信用邻居优先推送。API：`GET /neighbor-circles/{id}/trust/ranking`、`GET /neighbor-circles/{id}/trust/me`。
- **自动救援联动**：`IAutoRescueService` / `AutoRescueService`，围栏越界或心跳超时 → 通知子女 → 等待 N 分钟（默认 5 分钟）→ 子女未响应 → 自动触发邻里圈广播。`AutoRescueRecord` 记录救援流程各阶段时间戳。配置：`AutoRescue:Enabled`、`AutoRescue:DelayMinutes`。子女主动响应 API：`POST /auto-rescue/{id}/respond`。

### 前端分层

```
lib/
├── core/           → API 客户端、路由、主题、配置、验证器
│                   → extensions/ 含 snackbar_extension、api_error_extension（DioException.toDisplayMessage）
│                   → services/ 含离线队列（OfflineQueueService）、OCR 解析（OcrParserService）
├── features/
│   ├── auth/       → 登录注册
│   ├── elder/      → 老人端（健康录入含 OCR 拍照、用药、首页、位置上报）
│   ├── child/      → 子女端（老人健康查看含异常检测、用药管理、围栏管理、紧急呼叫）
│   └── shared/     → 两端共用（通知、设置、SignalR 服务）
└── shared/         → 全局共享组件、模型、Provider（含 anomaly_detection.dart）
                    → widgets/ 含 confirm_dialog（showConfirmDialog 通用确认对话框）
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
- **Sentry 错误监控**：DSN 非空时启用。全局 FlutterError/PlatformDispatcher 错误上报，API 4xx/5xx 上报，登录时绑定用户上下文。生产环境 tracesSampleRate 0.2。
- **字体缩放限制**：全局 `textScaler` 上限 1.5x，防止老人设置过大系统字体导致布局溢出。

### 中间件管道顺序（不可调换）

```
Swagger → ExceptionHandlingMiddleware → SecurityHeadersMiddleware → AuditLogMiddleware
→ HSTS/HTTPS → CORS → RateLimiter → Authentication → Authorization → Controllers
```

### 限流策略

认证接口 10次/IP/分钟，通用 API 60次/IP/分钟，加入家庭 5次/用户/5分钟，紧急呼叫 3次/用户/1分钟。

## 测试

后端 303 个 xUnit 单元测试（196 Service + 68 Controller + 20 HealthAnomalyDetector + 19 其他），覆盖全部 Service 和全部 11 个 Controller。集成测试 12 个（需 Docker/Testcontainers）。测试项目：`CareForTheOld.Tests/`。
前端 411 个 Flutter 测试（表单验证、全模型序列化覆盖、AuthState 测试、OCR 解析器 27 个、VoiceParser 34 个、全部 18 个 Service 层 100% 覆盖、Provider 层 31 个、通用状态组件 21 个、烟雾测试），使用 mocktail mock Dio。测试目录：`flutter_client/test/`。

- 使用 InMemory 数据库 + Moq + FluentAssertions
- 每个 Service 测试文件中的 `CreateTestDataAsync()` 辅助方法创建完整家庭关系数据
- 测试中涉及 `GeoFenceService`、`MedicationService` 等需要家庭关系的操作时，必须先调用 `CreateTestFamilyAsync()` 建立家庭成员关系
- EF Core 全局 NoTracking 后，涉及 `Update`/`Delete` 的测试需确保 Service 内部使用了 `AsTracking()`
- `GeoFenceService` 构造函数需要 `ICacheService` 参数，测试中需 mock 并让 `GetOrCreateAsync` 直接执行 factory
- 集成测试使用 Testcontainers PostgreSQL（`PostgreSqlFixture`），标记 `[Collection("PostgreSql")]`

## 环境配置

后端通过 `.env` 文件注入（见 `.env.example`），必需变量：`POSTGRES_PASSWORD`、`JWT_SECRET_KEY`。
开发环境 JWT 密钥配置在 `appsettings.Development.json` 的 `Jwt:Key` 中（仅开发使用，生产用 `EnvironmentKeyProvider`）。
SMS 配置：`Sms:Provider`（aliyun/twilio）、`Sms:Aliyun:*` 或 `Sms:Twilio:*`（见 `.env.example`）。
前端 Sentry DSN 通过编译参数注入：`--dart-define=SENTRY_DSN=<value>`。

**端口说明**：后端 API 默认使用端口 **5001**（而非 5000），因为 macOS Monterey+ 的 AirPlay Receiver 占用了 5000 端口。
Docker 容器内应用监听 5000，通过 `docker-compose.yml` 映射到宿主机 5001（`5001:5000`）。
前端开发环境配置（`AppConfig.dev`）指向 `http://10.0.2.2:5001`，Android 模拟器通过该地址访问宿主机。
