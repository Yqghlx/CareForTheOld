#!/bin/bash
# 生产数据库迁移脚本
# 在运行此脚本前，确保已配置以下环境变量：
#   - ConnectionStrings__DefaultConnection（PostgreSQL 连接字符串）
#
# 用法：
#   ./scripts/migrate.sh              # 执行迁移到最新版本
#   ./scripts/migrate.sh rollback 1   # 回滚到指定版本（可选）

set -euo pipefail

PROJECT="CareForTheOld/CareForTheOld.csproj"
STARTUP="CareForTheOld/CareForTheOld.csproj"

echo "===== CareForTheOld 数据库迁移 ====="
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# 检查环境变量
if [ -z "${ConnectionStrings__DefaultConnection:-}" ] && [ -z "${POSTGRES_PASSWORD:-}" ]; then
    echo "警告: 未检测到数据库连接配置"
    echo "请确保通过以下方式之一配置连接字符串："
    echo "  1. 环境变量 ConnectionStrings__DefaultConnection"
    echo "  2. .env 文件（Docker Compose 环境）"
    echo ""
fi

if [ "${1:-}" = "rollback" ]; then
    # 回滚到指定迁移版本
    TARGET="${2:-}"
    if [ -z "$TARGET" ]; then
        echo "错误: 请指定回滚目标迁移版本"
        echo "用法: $0 rollback <MigrationName>"
        echo ""
        echo "可用迁移版本："
        dotnet ef migrations list --project "$PROJECT" --startup-project "$STARTUP" --configuration Production 2>/dev/null || true
        exit 1
    fi
    echo "回滚到迁移版本: $TARGET"
    dotnet ef database update "$TARGET" --project "$PROJECT" --startup-project "$STARTUP" --configuration Production
else
    # 执行迁移到最新版本
    echo "检查待执行的迁移："
    dotnet ef migrations list --project "$PROJECT" --startup-project "$STARTUP" --configuration Production 2>/dev/null | grep -E "Pending|^(20)" || echo "(无待执行迁移)"
    echo ""
    echo "执行迁移..."
    dotnet ef database update --project "$PROJECT" --startup-project "$STARTUP" --configuration Production
fi

echo ""
echo "===== 迁移完成 ====="
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
