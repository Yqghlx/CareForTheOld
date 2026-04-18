# 关爱老人 App — 安全与代码质量优化设计

## 背景

项目代码评审发现 12 个问题（4 严重、4 中等、4 一般）。本设计采用分层渐进方案，按风险优先级逐层修复。

## 第一层：安全漏洞修复（严重）

### 1.1 CORS 限制
- **现状**: `Program.cs` 使用 `AllowAnyOrigin()` 策略
- **方案**: 新增 `Cors:AllowedOrigins` 配置项，从 appsettings + 环境变量读取
- **修改文件**: `Program.cs`, `appsettings.json`
- **默认值**: 开发环境允许 `localhost:*`，生产环境需显式配置

### 1.2 JWT 密钥环境变量化
- **现状**: `appsettings.json` 硬编码密钥 `CareForTheOld_SecretKey_2026_MustBeAtLeast32Chars!`
- **方案**: 优先从环境变量 `Jwt__Key` 读取，移除 appsettings 默认值
- **修改文件**: `appsettings.json`, `ServiceCollectionExtensions.cs`
- **启动校验**: 密钥为空或 < 32 字符时抛出异常拒绝启动

### 1.3 登录限流
- **现状**: 认证接口无限流保护
- **方案**: 使用 ASP.NET Core `AddRateLimiter` 内置中间件
- **规则**: 登录/注册 10次/IP/分钟，通用 API 60次/IP/分钟
- **修改文件**: `Program.cs`

### 1.4 角色授权
- **现状**: 有 `[Authorize]` 但无角色区分
- **方案**: 各 Controller 按业务添加角色限制
  - `EmergencyController.Create` → `[Authorize(Roles = "Elder")]`
  - `EmergencyController.Respond` → `[Authorize(Roles = "Child")]`
  - `GeoFenceController` 全部 → `[Authorize(Roles = "Child")]`
  - `HealthController.Create` → `[Authorize(Roles = "Elder")]`
  - `HealthController.GetFamilyMember*` → `[Authorize(Roles = "Child")]`
  - `HealthController.Report` → `[Authorize(Roles = "Elder")]`
  - `MedicationController.CreatePlan` → `[Authorize(Roles = "Child")]`
  - `MedicationController.Log` → `[Authorize(Roles = "Elder")]`
- **修改文件**: 各 Controller 文件

## 第二层：代码规范（中等）

### 2.1 响应格式统一
- **现状**: `LocationController` 部分返回匿名对象 `new { success = true, data = ... }`
- **方案**: 统一使用 `ApiResponse<T>` 包装
- **修改文件**: `LocationController.cs`

### 2.2 输入校验
- **现状**: `ReportLocationRequest` 经纬度无范围验证
- **方案**: Latitude [-90, 90]，Longitude [-180, 180]，添加 `[Required]` + `[Range]`
- **修改文件**: `ReportLocationRequest.cs`

### 2.3 CurrentUserId 统一获取
- **现状**: 各 Controller 各自解析 Claim，使用 null-forgiving `!` 操作符
- **方案**: 创建 `ControllerBase` 扩展方法 `GetUserId()`，解析失败返回 401
- **修改文件**: 新建 `Common/Extensions/ControllerExtensions.cs`，修改各 Controller

### 2.4 密码策略加强
- **现状**: 最低 6 位，无复杂度要求
- **方案**: 最低 8 位，必须包含数字 + 字母；新增 `PasswordValidator`
- **修改文件**: 新建 `Common/Validators/PasswordValidator.cs`

## 第三层：功能增强（一般）

### 3.1 Refresh Token 轮换
- **现状**: 刷新 token 不作废旧 token
- **方案**: 刷新时标记旧 token 为已使用，签发新 access + refresh token
- **检测重放**: 已使用的 token 再次使用时，撤销该用户所有 token（安全退出）
- **修改文件**: `AuthService.cs`, `RefreshToken` 实体添加 `IsUsed` 字段

### 3.2 安全事件日志
- **现状**: 缺少登录失败、权限异常等审计日志
- **方案**: 在关键节点添加 Serilog 结构化日志
  - 登录成功/失败（含 IP）
  - 限流触发
  - 权限校验失败
  - Token 刷新异常
- **修改文件**: `AuthService.cs`, `Program.cs`

## 文件变更清单

| 操作 | 文件 |
|------|------|
| 修改 | `Program.cs` |
| 修改 | `appsettings.json` |
| 修改 | `Common/Extensions/ServiceCollectionExtensions.cs` |
| 新建 | `Common/Extensions/ControllerExtensions.cs` |
| 新建 | `Common/Validators/PasswordValidator.cs` |
| 修改 | `Controllers/AuthController.cs` |
| 修改 | `Controllers/EmergencyController.cs` |
| 修改 | `Controllers/GeoFenceController.cs` |
| 修改 | `Controllers/HealthController.cs` |
| 修改 | `Controllers/LocationController.cs` |
| 修改 | `Controllers/MedicationController.cs` |
| 修改 | `Services/Implementations/AuthService.cs` |
| 修改 | `Models/DTOs/Requests/Location/ReportLocationRequest.cs` |
| 修改 | `Models/Entities/RefreshToken.cs` |

## 验证方式

每层完成后：
1. `dotnet build` 编译通过
2. `dotnet test` 全部测试通过
3. Docker 部署验证
