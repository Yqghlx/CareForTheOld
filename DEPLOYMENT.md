# 关爱老人 App 部署指南

## 部署架构

```
┌─────────────────────────────────────────────────────┐
│                     Docker 环境                      │
│  ┌─────────────────┐    ┌─────────────────────────┐ │
│  │   PostgreSQL    │    │      ASP.NET Core       │ │
│  │   (数据库)       │◄───│      (后端 API)          │ │
│  │   Port: 5432    │    │      Port: 5000         │ │
│  └─────────────────┘    └─────────────────────────┘ │
└─────────────────────────────────────────────────────┘
                           ▲
                           │ HTTP API
                           ▼
              ┌─────────────────────────┐
              │   Flutter Android App   │
              │   (客户端 APK)           │
              └─────────────────────────┘
```

## 快速部署

### 1. 使用 Docker Compose 部署（推荐）

```bash
# 进入项目目录
cd CareForTheOld

# 构建并启动所有服务
docker-compose up -d --build

# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f api
```

服务启动后：
- 后端 API: `http://localhost:5001` (macOS AirPlay 占用 5000，改用 5001)
- PostgreSQL: `localhost:5432`

### 2. 配置修改

#### 数据库配置 (docker-compose.yml)
```yaml
environment:
  POSTGRES_USER: carefortheold        # 数据库用户名
  POSTGRES_PASSWORD: your_password    # 数据库密码（建议修改）
  POSTGRES_DB: carefortheold          # 数据库名
```

#### JWT 配置
```yaml
environment:
  Jwt__Key: "Your_Secret_Key_Min_32_Characters!"  # JWT密钥（建议修改）
  Jwt__Issuer: "CareForTheOld"
  Jwt__Audience: "CareForTheOld"
```

### 3. 客户端 APK 配置

修改 Flutter 客户端 API 地址：

**文件**: `flutter_client/lib/core/api/api_client.dart`

```dart
static const String _baseUrl = 'http://YOUR_SERVER_IP:5000';
```

然后重新构建 APK：
```bash
cd flutter_client
flutter build apk --release
```

APK 输出位置: `build/app/outputs/flutter-apk/app-release.apk`

## 生产环境部署建议

### 1. 安全配置

- 修改默认数据库密码
- 修改 JWT 密钥（至少32字符）
- 使用 HTTPS（见下方 Nginx 配置）
- 配置防火墙规则
- 启用 OSS 文件存储（头像等文件存储到云端）

### 2. 使用 HTTPS + Nginx 反向代理

生产环境推荐使用 Nginx 反向代理，提供 HTTPS 加密和 WebSocket 支持。

```bash
# 准备 SSL 证书
mkdir -p nginx/ssl
# 将 cert.pem 和 key.pem 放入 nginx/ssl/ 目录

# 生产环境部署
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build
```

详细配置见：
- `nginx/nginx.conf` - Nginx 反向代理配置
- `nginx/ssl/README.md` - SSL 证书获取说明
- `docker-compose.prod.yml` - 生产环境 Docker Compose 配置

### 3. OSS 文件存储配置

头像等用户文件默认存储在本地 `uploads/` 目录，生产环境建议切换到阿里云 OSS。

**配置步骤**：

1. 在阿里云 OSS 创建 Bucket，设置为公开读
2. 在 `.env` 文件中配置：

```bash
# 启用 OSS
OSS_ENABLED=true

# OSS 配置
OSS_ENDPOINT=https://oss-cn-hangzhou.aliyuncs.com  # 替换为实际 Endpoint
OSS_ACCESS_KEY_ID=your_access_key_id
OSS_ACCESS_KEY_SECRET=your_access_key_secret
OSS_BUCKET_NAME=your-bucket-name
```

**注意**：Bucket 需设置为公开读，否则头像 URL 无法直接访问。

### 4. 数据持久化

Docker Compose 已配置数据卷：
```yaml
volumes:
  postgres_data:  # PostgreSQL 数据持久化
```

备份命令：
```bash
docker-compose exec postgres pg_dump -U carefortheold carefortheold > backup.sql
```

## 常用命令

```bash
# 启动服务
docker-compose up -d

# 停止服务
docker-compose down

# 重启服务
docker-compose restart

# 查看日志
docker-compose logs -f

# 重新构建
docker-compose up -d --build

# 进入容器
docker-compose exec api bash
docker-compose exec postgres bash
```

## 故障排查

### 1. API 无法启动
```bash
# 查看日志
docker-compose logs api

# 检查数据库连接
docker-compose exec postgres pg_isready -U carefortheold
```

### 2. 数据库连接失败
```bash
# 检查数据库状态
docker-compose ps postgres

# 重启数据库
docker-compose restart postgres
```

### 3. APK 无法连接后端
- 检查 API 地址配置是否正确
- 检查防火墙是否开放端口
- 检查服务器 IP 是否可访问

## 端口说明

| 服务 | 端口 | 说明 |
|------|------|------|
| PostgreSQL | 5432 | 数据库内部端口 |
| API | 5001 | 后端 API 端口 (容器内部5000，外部映射5001) |
| SignalR | 5001/hubs | WebSocket 连接 |

## 系统要求

- Docker 20.x+
- Docker Compose 2.x+
- 服务器内存: 最低 2GB，推荐 4GB
- 存储: 最低 10GB