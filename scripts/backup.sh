#!/bin/bash
# PostgreSQL 数据库备份脚本
# 使用方式：./scripts/backup.sh
# 恢复方式：gunzip < backups/backup_20260424_120000.sql.gz | docker exec -i carefortheold-postgres psql -U postgres -d carefortheold
set -euo pipefail

BACKUP_DIR="backups"
RETENTION_DAYS=7

# 读取环境变量
if [ -f .env ]; then
    source .env
fi

DB_HOST="${POSTGRES_HOST:-localhost}"
DB_PORT="${POSTGRES_PORT:-5432}"
DB_NAME="${POSTGRES_DB:-carefortheold}"
DB_USER="${POSTGRES_USER:-postgres}"
DB_PASSWORD="${POSTGRES_PASSWORD:-}"

if [ -z "$DB_PASSWORD" ]; then
    echo "错误: POSTGRES_PASSWORD 未配置"
    echo "请在 .env 文件中设置 POSTGRES_PASSWORD"
    exit 1
fi

# 创建备份目录
mkdir -p "$BACKUP_DIR"

TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
BACKUP_FILE="${BACKUP_DIR}/backup_${TIMESTAMP}.sql.gz"

echo "===== 数据库备份 ====="
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "数据库: ${DB_NAME}@${DB_HOST}:${DB_PORT}"
echo ""

# 判断是 Docker 环境还是直接连接
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q 'carefortheold-db'; then
    echo "检测到 Docker PostgreSQL 容器，使用 docker exec 备份..."
    docker exec carefortheold-db pg_dump -U "$DB_USER" -d "$DB_NAME" \
        --no-owner --no-privileges --clean --if-exists | gzip > "$BACKUP_FILE"
else
    echo "使用 pg_dump 直接备份..."
    PGPASSWORD="$DB_PASSWORD" pg_dump \
        -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
        --no-owner --no-privileges --clean --if-exists | gzip > "$BACKUP_FILE"
fi

BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo "备份完成: $BACKUP_FILE ($BACKUP_SIZE)"

# 清理超过保留天数的旧备份
DELETED=$(find "$BACKUP_DIR" -name "backup_*.sql.gz" -mtime +${RETENTION_DAYS} -delete -print | wc -l | tr -d ' ')
if [ "$DELETED" -gt 0 ]; then
    echo "已清理 ${DELETED} 个超过 ${RETENTION_DAYS} 天的旧备份"
fi

echo ""
echo "===== 备份完成 ====="
echo "恢复命令："
echo "  gunzip < $BACKUP_FILE | docker exec -i carefortheold-db psql -U $DB_USER -d $DB_NAME"
