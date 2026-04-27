#!/bin/bash
# 数据库迁移一致性检查
# 对比 DbContext 中的 DbSet 声明与最新迁移快照中的表定义
# 如果发现 DbSet 没有对应的迁移，说明开发者忘了执行 dotnet ef migrations add
#
# 用法：
#   ./scripts/check-migrations.sh          # 本地检查
#   （CI 中自动调用）
#
# 退出码：
#   0 — 所有 DbSet 都有对应迁移
#   1 — 发现不一致

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

DBCONTEXT="$PROJECT_DIR/CareForTheOld/Data/AppDbContext.cs"
SNAPSHOT="$PROJECT_DIR/CareForTheOld/Data/Migrations/AppDbContextModelSnapshot.cs"

# 检查文件存在
if [ ! -f "$DBCONTEXT" ]; then
    echo "错误: 找不到 AppDbContext.cs: $DBCONTEXT"
    exit 1
fi

if [ ! -f "$SNAPSHOT" ]; then
    echo "错误: 找不到迁移快照: $SNAPSHOT"
    exit 1
fi

echo "===== 数据库迁移一致性检查 ====="
echo ""

# 从 AppDbContext.cs 提取所有 DbSet<T> 中的实体名称
# 匹配模式：public DbSet<EntityType> EntityNames => Set<EntityType>();
# 例如：public DbSet<User> Users => Set<User>(); → 提取 User
DBSET_ENTITIES=$(grep -o 'public DbSet<[^>]*>' "$DBCONTEXT" 2>/dev/null | sed 's/public DbSet<//;s/>//' || true)

if [ -z "$DBSET_ENTITIES" ]; then
    echo "警告: 未从 AppDbContext.cs 中检测到 DbSet 声明"
    exit 0
fi

echo "DbContext 中声明的实体："
echo "$DBSET_ENTITIES" | sed 's/^/  - /'
echo ""

# 从迁移快照中提取所有表名
# modelBuilder.Entity("CareForTheOld.Models.Entities.XXX", ...) 中的 XXX
SNAPSHOT_ENTITIES=$(grep -o 'modelBuilder\.Entity("CareForTheOld\.Models\.Entities\.[^"]*"' "$SNAPSHOT" 2>/dev/null | sed 's/.*\.//;s/"$//' || true)

echo "迁移快照中的实体："
echo "$SNAPSHOT_ENTITIES" | sed 's/^/  - /'
echo ""

# 对比差异
ERRORS=0

echo "--- 检查结果 ---"

while IFS= read -r entity; do
    if echo "$SNAPSHOT_ENTITIES" | grep -qx "$entity"; then
        echo "  ✓ $entity — 迁移中存在"
    else
        echo "  ✗ $entity — 缺少迁移！请执行: dotnet ef migrations add Add${entity}"
        ERRORS=$((ERRORS + 1))
    fi
done <<< "$DBSET_ENTITIES"

echo ""

if [ "$ERRORS" -gt 0 ]; then
    echo "❌ 发现 $ERRORS 个实体缺少对应的数据库迁移"
    echo ""
    echo "修复方法："
    echo "  1. cd $PROJECT_DIR"
    echo "  2. dotnet ef migrations add <MigrationName> --project CareForTheOld/CareForTheOld.csproj"
    echo "  3. 重新运行本检查"
    exit 1
else
    echo "✅ 所有实体都有对应的数据库迁移"
    exit 0
fi
