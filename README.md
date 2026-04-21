# 关爱老人 App (CareForTheOld)

一款专为老年人及其子女设计的健康管理应用，帮助子女实时关注老人的健康状况、用药情况，并提供紧急呼叫和位置追踪功能。

## 功能特性

### 老人端
- **健康数据记录** - 血压、血糖、心率、体温录入，支持语音输入
- **用药提醒** - 定时提醒服药，语音确认服药状态
- **紧急呼叫** - 长按 2 秒一键呼叫子女，自动上报位置和电量
- **家庭成员查看** - 查看家庭成员信息
- **设置管理** - 个人信息、密码修改、位置上报开关

### 子女端
- **健康数据查看** - 查看老人健康数据、趋势图表、统计摘要
- **用药计划管理** - 创建/编辑/启用/停用用药计划
- **用药日志查看** - 查看老人用药记录，支持日期筛选
- **紧急呼叫处理** - 实时接收紧急呼叫通知，查看位置和电量
- **位置追踪** - 查看老人位置，设置电子围栏
- **健康报告导出** - 导出老人健康数据 PDF 报告

### 共同功能
- **实时通知** - 用药提醒、紧急呼叫、健康异常、围栏告警实时推送
- **家庭成员管理** - 查看家庭成员，邀请码加入家庭

## 技术架构

### 后端
- **框架**: ASP.NET Core 10
- **数据库**: PostgreSQL (生产) / SQLite (开发) / InMemory (测试)
- **认证**: JWT Bearer Token
- **实时通信**: SignalR (WebSocket)
- **后台任务**: Hangfire (用药提醒、心跳检测、通知投递)
- **查询优化**: Dapper (高频只读查询) + EF Core (写操作)
- **缓存**: Redis (电子围栏缓存)
- **文件存储**: 本地存储 (可替换 OSS/S3)

### 前端
- **框架**: Flutter 3.x
- **状态管理**: Riverpod
- **路由**: GoRouter
- **网络**: Dio + 自动 Token 刷新
- **离线支持**: Hive 本地队列 (断网数据暂存)
- **语音识别**: speech_to_text (语音录入健康数据、确认服药)
- **地图定位**: geolocator (GPS 定位上报)
- **通知**: flutter_local_notifications + SignalR 实时推送

### 测试覆盖
- 后端: 143 个 xUnit 单元测试 + Testcontainers PostgreSQL 集成测试
- 前端: 36 个单元测试（表单验证、模型序列化、烟雾测试）

## 项目结构

```
CareForTheOld/
├── CareForTheOld/                 # 后端 ASP.NET Core
│   ├── Controllers/               # API 控制器
│   ├── Services/                  # 业务逻辑
│   │   ├── Interfaces/            # 接口定义
│   │   ├── Implementations/       # 实现
│   │   ├── Background/            # 后台服务
│   │   └── Hubs/                  # SignalR Hub
│   ├── Models/                    # 数据模型
│   │   ├── Entities/              # 数据库实体
│   │   ├── DTOs/                  # 请求/响应 DTO
│   │   └ Enums/                   # 枚举
│   ├── Data/                      # 数据访问
│   │   ├── Configurations/        # EF Core 配置
│   ├── Common/                    # 公共组件
│   │   ├── Middleware/            # 中间件
│   │   ├── Extensions/            # 扩展方法
│   ├── CareForTheOld.Tests/       # 测试项目
│   └── docs/                      # 设计文档
│
├── flutter_client/                # 前端 Flutter
│   ├── lib/
│   │   ├── core/                  # 核心 (API、路由、主题、配置)
│   │   ├── features/              # 功能模块
│   │   │   ├── auth/              # 认证
│   │   │   ├── elder/             # 老人端
│   │   │   ├── child/             # 子女端
│   │   │   └── shared/            # 共享功能
│   │   └── shared/                # 共享组件和模型
│   └── test/                      # 测试
│
├── docker-compose.yml             # Docker 部署配置
├── .env.example                   # 环境变量示例
├── CLAUDE.md                      # Claude Code 开发指南
└── DEPLOYMENT.md                  # 部署指南
```

## 快速开始

### 环境要求

- .NET SDK 10
- Flutter SDK 3.x
- Docker & Docker Compose (部署用)
- PostgreSQL (或使用 Docker)

### 后端启动

```bash
# 进入后端目录
cd CareForTheOld

# 开发环境启动 (使用 SQLite)
dotnet run

# 或使用 Docker
docker-compose up -d --build
```

后端 API 地址:
- 开发: `http://localhost:5000`
- Docker: `http://localhost:5001`

### 前端启动

```bash
# 进入前端目录
cd flutter_client

# 安装依赖
flutter pub get

# 运行 (开发)
flutter run

# 构建 APK (发布)
flutter build apk --release
```

### 测试运行

```bash
# 后端测试
cd CareForTheOld
dotnet test

# 前端静态分析
cd flutter_client
flutter analyze --no-fatal-infos
```

## 配置说明

### 后端环境变量 (.env)

```bash
# 数据库
POSTGRES_PASSWORD=your_password

# JWT
JWT_SECRET_KEY=Your_Secret_Key_Min_32_Characters!
```

### 前端环境配置

修改 `flutter_client/lib/core/config/app_config.dart`:

```dart
static const devConfig = AppConfig(
  apiBaseUrl: 'http://localhost:5001/api/v1',
  signalrBaseUrl: 'http://localhost:5001/hubs/notification',
);
```

## 安全特性

- **JWT 认证** - 带刷新 Token 轮换
- **角色权限** - 老人/子女角色分离
- **API 限流** - 认证 10次/IP/分钟，通用 API 60次/IP/分钟
- **密码策略** - 8位+字母+数字，修改后强制重登
- **手机号脱敏** - 非本人手机号部分隐藏
- **安全日志** - 审计中间件记录敏感操作
- **HTTPS 支持** - 生产环境配置

## 主要 API 接口

| 模块 | 接口 | 说明 |
|------|------|------|
| 认证 | `/auth/login`, `/auth/register` | 登录注册 |
| 健康 | `/health/me`, `/health/stats` | 健康数据 CRUD、统计 |
| 用药 | `/medication/plans`, `/medication/logs` | 用药计划、日志管理 |
| 紧急 | `/emergency/calls` | 紧急呼叫创建和处理 |
| 位置 | `/location/report`, `/location/me` | 位置上报和查询 |
| 围栏 | `/geofence` | 电子围栏管理 |
| 通知 | `/notification/me` | 通知列表 |
| 家庭 | `/family` | 家庭成员管理 |

## 实时通知类型

| 类型 | 说明 | 接收者 |
|------|------|--------|
| MedicationReminder | 用药提醒 | 老人 |
| MedicationReminderFamily | 用药提醒通知 | 子女 |
| MedicationReminderUrgent | 二次用药提醒 | 老人 |
| MedicationMissed | 未服药告警 | 子女 |
| EmergencyCall | 紧急呼叫 | 子女 |
| EmergencyCallReminder | 紧急呼叫二次提醒 | 子女 |
| GeoFenceAlert | 围栏告警 | 子女 |
| HealthAlert | 健康异常告警 | 子女 |
| HeartbeatAlert | 设备离线告警 | 子女 |

## 部署

详细部署说明请参考 [DEPLOYMENT.md](DEPLOYMENT.md)。

## 开发指南

使用 Claude Code 开发时请参考 [CLAUDE.md](CLAUDE.md)。

## 许可证

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request。