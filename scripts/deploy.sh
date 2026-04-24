#!/bin/bash
# 生产环境部署脚本
# 前提条件：
#   - 服务器已安装 Docker + Docker Compose
#   - .env 文件已配置（参照 .env.example）
#   - SSL 证书已放入 nginx/ssl/ 目录
#
# 用法：
#   ./scripts/deploy.sh              # 完整部署（迁移 + 重启 + 健康检查）
#   ./scripts/deploy.sh migrate-only # 仅执行数据库迁移

set -euo pipefail

COMPOSE_FILES="-f docker-compose.yml -f docker-compose.prod.yml"
HEALTH_URL="http://localhost:5001/health"
MAX_RETRIES=30
RETRY_INTERVAL=5

echo "===== CareForTheOld 生产部署 ====="
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# 检查 .env 文件
if [ ! -f .env ]; then
    echo "错误: 未找到 .env 文件"
    echo "请复制 .env.example 为 .env 并填入实际配置值"
    exit 1
fi

# 检查必要环境变量
source .env
if [ -z "${POSTGRES_PASSWORD:-}" ]; then
    echo "错误: POSTGRES_PASSWORD 未配置"
    exit 1
fi
if [ -z "${JWT_SECRET_KEY:-}" ]; then
    echo "错误: JWT_SECRET_KEY 未配置"
    exit 1
fi

# Step 1: 拉取最新镜像
echo "[1/5] 拉取最新镜像..."
docker compose $COMPOSE_FILES pull api 2>/dev/null || echo "（本地构建模式）"

# Step 2: 执行数据库迁移
echo "[2/5] 执行数据库迁移..."
docker compose $COMPOSE_FILES run --rm api \
    dotnet CareForTheOld.dll --migrate || {
    echo "警告: 迁移执行失败，尝试直接启动（应用启动时会自动迁移）"
}

if [ "${1:-}" = "migrate-only" ]; then
    echo "仅迁移模式，跳过部署"
    exit 0
fi

# Step 3: 构建并重启服务
echo "[3/5] 构建并重启服务..."
docker compose $COMPOSE_FILES up -d --build --remove-orphans

# Step 4: 等待健康检查通过
echo "[4/5] 等待服务就绪..."
retry=0
while [ $retry -lt $MAX_RETRIES ]; do
    if curl -sf "$HEALTH_URL" > /dev/null 2>&1; then
        echo "服务已就绪！"
        break
    fi
    retry=$((retry + 1))
    echo "  等待中... ($retry/$MAX_RETRIES)"
    sleep $RETRY_INTERVAL
done

if [ $retry -eq $MAX_RETRIES ]; then
    echo "错误: 服务未能在预期时间内就绪"
    echo "请检查日志: docker compose $COMPOSE_FILES logs api"
    exit 1
fi

# Step 5: 清理旧镜像
echo "[5/5] 清理旧镜像..."
docker image prune -f 2>/dev/null || true

echo ""
echo "===== 部署完成 ====="
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "健康检查: $HEALTH_URL"
echo "详细状态: http://localhost:5001/health/detail"
echo "Prometheus: http://localhost:5001/metrics"
echo ""
echo "常用命令："
echo "  查看日志: docker compose $COMPOSE_FILES logs -f api"
echo "  查看状态: docker compose $COMPOSE_FILES ps"
echo "  回滚部署: docker compose $COMPOSE_FILES down"
