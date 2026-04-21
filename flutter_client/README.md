# 关爱老人 Flutter 客户端

基于 Flutter 3.x 开发的关爱老人 App 客户端，支持老人端和子女端两种模式。

## 功能特性

### 老人端
- **健康数据记录** - 血压、血糖、心率、体温录入，支持语音输入
- **用药提醒** - 定时提醒服药，语音确认服药状态，脉冲动画提醒
- **紧急呼叫** - 长按 2 秒一键呼叫子女，自动上报 GPS 位置和电量
- **家庭成员查看** - 查看家庭成员信息
- **适老化设计** - 大字体、大按钮、长按防误触

### 子女端
- **健康数据查看** - 查看老人健康数据、7/30天趋势图表、统计摘要
- **用药计划管理** - 创建/编辑/启用/停用用药计划
- **用药日志查看** - 查看老人用药记录，支持日期筛选，显示备注
- **紧急呼叫处理** - 实时接收紧急呼叫通知，查看位置和电量
- **位置追踪** - 查看老人位置，设置电子围栏告警
- **健康报告导出** - 导出老人健康数据 PDF 报告
- **家庭成员管理** - 邀请码加入家庭，查看成员头像

### 共同功能
- **实时通知** - SignalR 推送用药提醒、紧急呼叫、健康异常、围栏告警
- **头像管理** - 上传个人头像，在各页面展示
- **密码修改** - 修改后强制重新登录
- **离线支持** - 断网时位置/健康数据暂存，恢复后自动上传

## 技术栈

| 类别 | 技术 |
|------|------|
| 框架 | Flutter 3.x |
| 状态管理 | Riverpod (StateNotifierProvider) |
| 路由 | GoRouter (角色路由守卫) |
| 网络 | Dio + 自动 Token 刷新 + 离线拦截 |
| 实时通信 | SignalR (WebSocket) |
| 本地存储 | SharedPreferences, Hive (离线队列) |
| 语音识别 | speech_to_text |
| 定位 | geolocator |
| 地图 | flutter_map + OpenStreetMap |
| 通知 | flutter_local_notifications |
| 文件分享 | share_plus |
| 图表 | fl_chart |
| 图片缓存 | cached_network_image |
| 应用信息 | package_info_plus |
| 电量 | battery_plus |

## 项目结构

```
lib/
├── core/
│   ├── api/               # API 客户端 (Dio + Token刷新)
│   ├── config/            # 环境配置 (dev/staging/production)
│   ├── router/            # GoRouter 路由配置
│   ├── services/          # 核心服务 (离线队列、连接检测)
│   ├── theme/             # 主题配置 (老人端大字体主题)
│   └── validators/        # 表单验证器
│
├── features/
│   ├── auth/              # 认证 (登录/注册)
│   ├── elder/             # 老人端
│   │   ├── pages/         # 页面 (首页、健康、用药)
│   │   ├── providers/     # 状态管理
│   │   └── services/      # API 服务
│   ├── child/             # 子女端
│   │   ├── pages/         # 页面 (首页、老人健康、围栏)
│   │   └── providers/     # 状态管理
│   └── shared/            # 共享功能
│       ├── pages/         # 通知、设置
│       ├── providers/     # 用户、紧急呼叫 Provider
│       └── services/      # SignalR、通知服务
│
└── shared/
    ├── models/            # 数据模型
    ├── widgets/           # 共享组件 (按钮、卡片、图表)
    └── providers/         # 全局 Provider (认证)
```

## 运行项目

### 前置条件

1. 安装 Flutter SDK (>= 3.0.0)
   ```bash
   # macOS
   brew install flutter
   ```

2. 安装依赖
   ```bash
   flutter pub get
   ```

### 运行应用

```bash
# 开发模式
flutter run

# 指定设备
flutter run -d emulator-5554
```

### 构建应用

```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release

# Release APK (带 Sentry)
flutter build apk --release --dart-define=SENTRY_DSN=your_dsn
```

APK 输出: `build/app/outputs/flutter-apk/app-release.apk`

## 配置

### 环境配置

修改 `lib/core/config/app_config.dart`:

```dart
class AppConfig {
  final String apiBaseUrl;
  final String signalrBaseUrl;
  
  static const devConfig = AppConfig(
    apiBaseUrl: 'http://localhost:5001/api/v1',
    signalrBaseUrl: 'http://localhost:5001/hubs/notification',
  );
  
  static const productionConfig = AppConfig(
    apiBaseUrl: 'https://your-domain.com/api/v1',
    signalrBaseUrl: 'https://your-domain.com/hubs/notification',
  );
  
  static const current = devConfig;  // 切换环境
}
```

### Android Application ID

修改 `android/app/build.gradle.kts`:

```kotlin
applicationId = "com.yourcompany.carefortheold"  // 替换占位符
```

## 静态分析

```bash
flutter analyze --no-fatal-infos
```

## 主要页面路由

| 路由 | 页面 | 角色 |
|------|------|------|
| `/login` | 登录页 | 公共 |
| `/register` | 注册页 | 公共 |
| `/elder` | 老人端首页 | 老人 |
| `/elder/health/trend` | 健康趋势图 | 老人 |
| `/elder/family` | 家庭成员 | 老人 |
| `/child` | 子女端首页 | 子女 |
| `/child/elder/:id/health` | 老人健康详情 | 子女 |
| `/child/elder/:id/location` | 老人位置 | 子女 |
| `/child/geofence` | 围栏管理 | 子女 |
| `/child/emergency` | 紧急呼叫 | 子女 |
| `/notifications` | 通知中心 | 公共 |
| `/settings` | 设置页 | 公共 |

## 状态管理示例

```dart
// Provider 定义
final healthRecordsProvider = StateNotifierProvider<HealthRecordsNotifier, HealthRecordsState>((ref) {
  final service = ref.watch(healthServiceProvider);
  return HealthRecordsNotifier(service);
});

// 使用
final state = ref.watch(healthRecordsProvider);
ref.read(healthRecordsProvider.notifier).loadRecords();
```

## 相关文档

- [项目 README](../README.md) - 项目整体介绍
- [部署指南](../DEPLOYMENT.md) - Docker 部署说明
- [开发指南](../CLAUDE.md) - Claude Code 开发指南