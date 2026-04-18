# 关爱老人 Flutter 客户端

基于 Flutter 3.x 开发的关爱老人 App 客户端，支持老人端和子女端两种模式。

## 功能特性

### 老人端
- 健康数据记录（血压、血糖、心率、体温）
- 用药提醒查看与确认
- 家庭成员查看
- 大字体、大按钮界面设计

### 子女端
- 查看老人健康数据和趋势
- 查看老人用药情况
- 创建和管理用药计划
- 家庭成员管理

## 技术栈

- **Flutter 3.x** - 跨平台移动开发框架
- **Riverpod** - 状态管理
- **GoRouter** - 路由管理
- **Dio** - 网络请求

## 项目结构

```
lib/
├── core/
│   ├── api/           # API 客户端配置
│   ├── models/        # 公共模型
│   ├── router/        # 路由配置
│   └── theme/         # 主题配置
├── features/
│   ├── auth/          # 认证模块（登录/注册）
│   ├── elder/         # 老人端功能
│   └── child/         # 子女端功能
└── shared/
    ├── models/        # 共享模型
    └── providers/     # 全局状态
```

## 运行项目

### 前置条件

1. 安装 Flutter SDK（>= 3.0.0）
   ```bash
   # macOS
   brew install flutter

   # 或从官网下载
   # https://flutter.dev/docs/get-started/install
   ```

2. 安装依赖
   ```bash
   flutter pub get
   ```

### 运行应用

```bash
# 开发模式
flutter run

# 指定平台
flutter run -d ios    # iOS
flutter run -d android # Android
```

### 构建应用

```bash
flutter build ios --release
flutter build apk --release
```

## 配置

修改 `lib/core/api/api_client.dart` 中的 `baseUrl` 以连接后端服务：

```dart
static const String baseUrl = 'http://your-server:5001/api';  // Docker 部署端口为 5001
```

## API 对接

客户端 API 路径对应后端接口：

| 功能 | 客户端路径 | 后端 API |
|------|----------|---------|
| 登录 | `/auth/login` | POST `/api/auth/login` |
| 注册 | `/auth/register` | POST `/api/auth/register` |
| 健康记录 | `/health` | POST `/api/health` |
| 用药计划 | `/medication/plans` | POST `/api/medication/plans` |