# 紧急呼叫推送通知设计

## 背景与问题

当前紧急呼叫通知仅依赖 SignalR（前台实时）+ SMS（兜底）。当子女 APP 在后台或关闭时，SignalR 连接断开，子女无法收到紧急通知，只能等 SMS。SMS 有延迟且容易被忽略，不适合紧急场景。

**目标**：实现三层通知保障，确保紧急呼叫在任何 APP 状态下都能触达子女。

## 方案：SignalR + FCM 混合（方案 A）

APP 前台用 SignalR（延迟 <1s），后台/关闭用 FCM 推送，SMS 作为最终兜底。

---

## 1. 后端 — Device Token 管理

### 1.1 新增实体 `DeviceToken`

**新增**: `Models/Entities/DeviceToken.cs`

```
Id           Guid         主键
UserId       Guid         关联用户
Token        string(512)  FCM 设备令牌
Platform     string(20)   平台标识（"android"/"ios"）
CreatedAt    DateTime     创建时间
LastActiveAt DateTime     最后活跃时间（登录时刷新）
```

- 一个用户可有多个 DeviceToken（手机、平板）
- `Token` 有唯一索引，FCM token 变化时更新而非重复插入

### 1.2 EF Core 配置

**新增**: `Data/Configurations/DeviceTokenConfiguration.cs`
- `Token` 唯一索引（`HasIndex(t => t.Token).IsUnique()`）
- `UserId` 索引（按用户查询 token 列表）

### 1.3 数据库迁移

```bash
dotnet ef migrations add AddDeviceToken
```

### 1.4 API 端点

**新增**: `Controllers/DeviceController.cs`

```
POST   /api/v1/devices/token   — 注册/刷新 FCM token
DELETE /api/v1/devices/token   — 登出时清除 token
```

- `POST` 接收 `{ token, platform }`
- 若 token 已存在则更新 `UserId` + `LastActiveAt`（同一设备换用户登录）
- 若 token 不存在则新建
- `DELETE` 清除当前用户的所有 token（登出场景）

---

## 2. 后端 — FCM 推送服务

### 2.1 接口定义

**新增**: `Services/Interfaces/IPushNotificationService.cs`

```csharp
Task SendAsync(Guid userId, string title, string body, Dictionary<string, string>? data = null);
Task SendAsync(IEnumerable<Guid> userIds, string title, string body, Dictionary<string, string>? data = null);
```

### 2.2 FCM 实现

**新增**: `Services/Implementations/FcmPushNotificationService.cs`

- 使用 `FirebaseAdmin` SDK（`FirebaseAdmin.Messaging`）
- 从数据库查询目标用户的 DeviceToken 列表
- 使用 `MulticastMessage` 批量发送（单次最多 500 token）
- FCM 消息配置：
  - `priority: high` — 确保后台唤醒
  - `data payload` 包含通知类型和业务数据
  - `android.notification.channel_id: "emergency"` — 紧急通知渠道
  - `android.notification.sound: "emergency_alarm"` — 自定义警报声

### 2.3 初始化

- `Program.cs` 注册 `FirebaseApp.Create()` 加载凭据
- 凭据文件路径通过配置 `Firebase:CredentialsPath` 指定
- 开发环境可配置为空（`NullPushNotificationService` 跳过推送）

### 2.4 通知渠道

FCM data payload 按通知类型区分：

| 类型 | data.type | data 内容 |
|------|-----------|-----------|
| 紧急呼叫 | `emergency_call` | `callId`, `elderName`, `latitude`, `longitude`, `batteryLevel` |
| 紧急呼叫提醒 | `emergency_reminder` | `callId`, `elderName` |
| 其他通知 | 对应类型 | 相关数据 |

---

## 3. 后端 — 紧急通知发送改造

**修改**: `Services/Implementations/EmergencyService.cs`

`SendEmergencyNotificationAsync` 方法改为三通道：

```
原流程：SignalR → SMS
新流程：SignalR → FCM → SMS（并行发送，互不阻塞）
```

- SignalR 和 FCM 同时发送（`Task.WhenAll`）
- SMS 仍然作为最终兜底
- FCM 推送的 title = "紧急呼叫"，body = "{elderName} 发起了紧急呼叫，请立即响应！"
- 错误隔离：任一通道失败不影响其他通道

---

## 4. 前端 — FCM 集成

### 4.1 依赖

**修改**: `flutter_client/pubspec.yaml`

```
firebase_core: ^3.0.0
firebase_messaging: ^15.0.0
audioplayers: ^6.0.0
vibration: ^2.0.0
```

### 4.2 Android 配置

- `google-services.json` 放入 `flutter_client/android/app/`
- `android/app/build.gradle.kts` 添加 `id("com.google.gms.google-services")` 插件
- `android/build.gradle.kts` 添加 `com.google.gms:google-services` classpath

### 4.3 FCM 服务

**新增**: `flutter_client/lib/core/services/fcm_service.dart`

- `initialize()` — 初始化 Firebase，请求通知权限
- `getToken()` — 获取 FCM token，登录后注册到后端
- `onTokenRefresh` — token 刷新时自动更新
- 前台消息处理（`FirebaseMessaging.onMessage`）→ 触发全屏警报
- 后台消息处理（`FirebaseMessaging.onBackgroundMessage`）→ 系统通知
- 统一消息处理入口：根据 `data.type` 分发到对应处理器

### 4.4 权限

Android 13+ 需请求 `POST_NOTIFICATIONS` 权限：
- 在 `AndroidManifest.xml` 声明
- 运行时动态请求

---

## 5. 前端 — 全屏紧急警报

### 5.1 全屏警报页面

**新增**: `flutter_client/lib/features/shared/pages/emergency_alert_page.dart`

- 全屏红色背景，白色文字
- 显示：老人头像、姓名、GPS 位置（可点击打开地图）、电量、呼叫时间
- 强震动（`vibration` 包，循环震动模式）
- 警报铃声（`audioplayers` 包，循环播放直到用户操作）
- 两个操作按钮：
  - "立即响应" — 调用 API 标记已处理，停止震动/铃声，跳转到紧急详情页
  - "拨打电话" — 拨打老人电话
- 无法通过返回键关闭，必须点击按钮

### 5.2 警报触发逻辑

**修改**: `signalr_service.dart`

- 收到 `EmergencyCall` 类型通知时：
  - APP 前台 → 直接弹出全屏警报页面
  - APP 后台 → FCM 处理显示系统通知（已有）
- 收到 `EmergencyCallReminder` 同理

### 5.3 通知渠道

**修改**: `local_notification_service.dart`

- 新增 `emergency` 通知渠道（最高优先级、自定义声音、LED 闪烁）
- 紧急通知使用该渠道

---

## 6. 整体数据流

```
老人长按紧急按钮（2 秒）
    │
    ▼
后端 EmergencyService.CreateCallAsync()
    │
    ├─ SignalR 推送 ──→ 前台子女：全屏红色警报 + 震动 + 警报声
    ├─ FCM 推送 ──────→ 后台子女：系统通知（高优先级，锁屏可见）
    └─ SMS ───────────→ 最终兜底（网络异常时）
    │
    ▼
子女响应（点击"立即响应"或通知打开 APP）
    │
    ▼
全屏警报页面 → API 标记已处理 → 通知老人"子女已响应"
    │
    ▼
3 分钟未响应 → 自动发送第二轮（SignalR + FCM + SMS）
```

---

## 7. 关键文件变更汇总

| 文件 | 操作 |
|------|------|
| `Models/Entities/DeviceToken.cs` | 新增 |
| `Data/Configurations/DeviceTokenConfiguration.cs` | 新增 |
| `Services/Interfaces/IPushNotificationService.cs` | 新增 |
| `Services/Implementations/FcmPushNotificationService.cs` | 新增 |
| `Controllers/DeviceController.cs` | 新增 |
| `Services/Implementations/EmergencyService.cs` | 修改 |
| `Program.cs` | 修改 — 注册 FCM + IPushNotificationService |
| `flutter_client/android/app/google-services.json` | 新增（用户提供） |
| `flutter_client/lib/core/services/fcm_service.dart` | 新增 |
| `flutter_client/lib/features/shared/pages/emergency_alert_page.dart` | 新增 |
| `flutter_client/lib/features/shared/services/signalr_service.dart` | 修改 |
| `flutter_client/lib/features/shared/services/local_notification_service.dart` | 修改 |
| `flutter_client/pubspec.yaml` | 修改 |
| `flutter_client/android/app/build.gradle.kts` | 修改 |
| `flutter_client/android/build.gradle.kts` | 修改 |

## 8. 前置条件（用户手动完成）

1. 在 https://console.firebase.google.com 创建 Firebase 项目
2. 添加 Android 应用，包名 `com.example.care_for_the_old_client`
3. 启用 Cloud Messaging
4. 下载 `google-services.json` 放到 `flutter_client/android/app/`
5. 下载 Firebase Admin SDK 私钥文件（JSON），配置到后端 `Firebase:CredentialsPath`
