#!/bin/bash
# 部署后冒烟测试
# 验证服务健康状态、数据库连接、关键 API 端点可用性
#
# 用法：
#   ./scripts/smoke-test.sh                     # 默认检查 localhost:5001
#   ./scripts/smoke-test.sh https://api.example.com  # 指定 URL
#
# 退出码：
#   0 — 所有检查通过
#   1 — 关键检查失败

set -euo pipefail

BASE_URL="${1:-http://localhost:5001}"
PASSED=0
FAILED=0

echo "===== 冒烟测试 ====="
echo "目标: $BASE_URL"
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# 通用检查函数
check() {
    local method="$1"
    local path="$2"
    local expected_status="$3"
    local description="$4"

    local url="${BASE_URL}${path}"
    local status_code

    status_code=$(curl -s -o /dev/null -w "%{http_code}" -X "$method" "$url" --max-time 10 2>/dev/null || echo "000")

    if [ "$status_code" = "$expected_status" ]; then
        echo "  ✓ ${method} ${path} → ${status_code} (${description})"
        PASSED=$((PASSED + 1))
    else
        echo "  ✗ ${method} ${path} → ${status_code}（期望 ${expected_status}）(${description})"
        FAILED=$((FAILED + 1))
    fi
}

# ========================================
# 1. 基础设施检查
# ========================================
echo "--- 基础设施 ---"

# 健康检查（必须 200）
check GET "/health" "200" "健康检查"

# ========================================
# 2. 认证接口检查（不需要 Token）
# ========================================
echo ""
echo "--- 认证接口 ---"

# 注册接口应返回 400（空请求体）而非 500
status_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${BASE_URL}/api/v1/auth/register" -H "Content-Type: application/json" -d '{}' --max-time 10 2>/dev/null || echo "000")
if [ "$status_code" = "400" ]; then
    echo "  ✓ POST /api/v1/auth/register → ${status_code} (注册接口可达)"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ POST /api/v1/auth/register → ${status_code}（期望 400）(注册接口可达)"
    FAILED=$((FAILED + 1))
fi

# 登录接口应返回 400（无效凭据）而非 500
status_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${BASE_URL}/api/v1/auth/login" -H "Content-Type: application/json" -d '{"phoneNumber":"000","password":"000"}' --max-time 10 2>/dev/null || echo "000")
if [ "$status_code" = "400" ] || [ "$status_code" = "401" ]; then
    echo "  ✓ POST /api/v1/auth/login → ${status_code} (登录接口可达)"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ POST /api/v1/auth/login → ${status_code}（期望 400/401）(登录接口可达)"
    FAILED=$((FAILED + 1))
fi

# 刷新令牌接口应返回 400（无效请求体）而非 500
status_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${BASE_URL}/api/v1/auth/refresh" -H "Content-Type: application/json" -d '{"refreshToken":"invalid"}' --max-time 10 2>/dev/null || echo "000")
if [ "$status_code" = "400" ] || [ "$status_code" = "401" ]; then
    echo "  ✓ POST /api/v1/auth/refresh → ${status_code} (刷新令牌接口可达)"
    PASSED=$((PASSED + 1))
else
    echo "  ✗ POST /api/v1/auth/refresh → ${status_code}（期望 400/401）(刷新令牌接口可达)"
    FAILED=$((FAILED + 1))
fi

# ========================================
# 3. 受保护接口检查（需要认证）
# ========================================
echo ""
echo "--- 受保护接口 ---"

# 未带 Token 应返回 401
check GET "/api/v1/user/me" "401" "用户信息需认证"
check GET "/api/v1/family/me" "401" "家庭信息需认证"
check GET "/api/v1/health/me" "401" "健康数据需认证"

# ========================================
# 4. 健康详情检查
# ========================================
echo ""
echo "--- 健康详情 ---"

# 详细健康检查
detail_status=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/health/detail" --max-time 10 2>/dev/null || echo "000")
if [ "$detail_status" = "200" ]; then
    echo "  ✓ GET /health/detail → 200 (详细状态)"
    PASSED=$((PASSED + 1))

    # 检查数据库连接状态
    health_json=$(curl -s "${BASE_URL}/health/detail" --max-time 10 2>/dev/null || echo "{}")
    db_status=$(echo "$health_json" | grep -o '"postgresql"[^}]*status":"[^"]*"' | grep -o 'Healthy\|Degraded\|Unhealthy' || echo "unknown")
    if [ "$db_status" = "Healthy" ]; then
        echo "  ✓ 数据库连接正常"
        PASSED=$((PASSED + 1))
    elif [ "$db_status" = "Degraded" ]; then
        echo "  ⚠ 数据库连接降级"
        PASSED=$((PASSED + 1))
    else
        echo "  ✗ 数据库连接异常: $db_status"
        FAILED=$((FAILED + 1))
    fi
else
    echo "  ✗ GET /health/detail → ${detail_status}（期望 200）(详细状态)"
    FAILED=$((FAILED + 1))
fi

# ========================================
# 汇总
# ========================================
echo ""
echo "===== 测试汇总 ====="
echo "通过: $PASSED"
echo "失败: $FAILED"
echo ""

if [ "$FAILED" -gt 0 ]; then
    echo "❌ 冒烟测试未通过，请检查失败项"
    exit 1
else
    echo "✅ 冒烟测试全部通过"
    exit 0
fi
