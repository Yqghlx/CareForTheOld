#!/bin/bash
# 前后端 API 路径一致性检查
# 解析后端 Controller 路由和前端 api_endpoints.dart，检测路径不匹配
#
# 用法：
#   ./scripts/check-api-paths.sh          # 本地检查
#   （CI 中自动调用）
#
# 退出码：
#   0 — 关键路径一致
#   1 — 发现关键路径不匹配

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

CONTROLLERS_DIR="$PROJECT_DIR/CareForTheOld/Controllers"
ENDPOINTS_FILE="$PROJECT_DIR/flutter_client/lib/core/constants/api_endpoints.dart"

# 检查文件存在
if [ ! -d "$CONTROLLERS_DIR" ]; then
    echo "错误: 找不到 Controllers 目录"
    exit 1
fi

if [ ! -f "$ENDPOINTS_FILE" ]; then
    echo "错误: 找不到 api_endpoints.dart"
    exit 1
fi

echo "===== 前后端 API 路径一致性检查 ====="
echo ""

# ========================================
# 1. 从后端 Controller 提取所有 API 端点
# ========================================
# 输出格式：/auth/login, /family/me 等（相对于 /api/v1 前缀）
BACKEND_PATHS=$(mktemp)

for ctrl_file in "$CONTROLLERS_DIR"/*.cs; do
    # 提取控制器路由前缀
    ctrl_route=$(grep -o '\[Route("api/v[^"]*")]' "$ctrl_file" 2>/dev/null | head -1 | sed 's/\[Route("//;s/")\]//' || true)
    [ -z "$ctrl_route" ] && continue

    # 提取控制器名用于 [controller] 替换
    ctrl_name=$(basename "$ctrl_file" .cs | sed 's/Controller$//' | tr '[:upper:]' '[:lower:]')

    # 将 api/v{version:apiVersion}/xxx 转为 /xxx
    ctrl_prefix=$(echo "$ctrl_route" | sed 's|api/v{version:apiVersion}/||')
    # 处理 [controller] 占位符
    ctrl_prefix=$(echo "$ctrl_prefix" | sed "s/\[controller\]/$ctrl_name/")

    # 提取所有 action 路由
    while IFS= read -r action_line; do
        # 提取路由模板
        route_template=$(echo "$action_line" | grep -o '"[^"]*"' | tr -d '"')

        # 组合路径
        if [ -n "$route_template" ]; then
            full_path="/${ctrl_prefix}/${route_template}"
        else
            full_path="/${ctrl_prefix}"
        fi

        # 清理：去除参数类型约束 {id:guid} → {id}，合并双斜杠
        clean_path=$(echo "$full_path" | sed 's/{\([^}]*\):[^}]*}/{\1}/g' | sed 's|//|/|g' | sed 's|/$||')

        echo "$clean_path" >> "$BACKEND_PATHS"
    done < <(grep '\[Http' "$ctrl_file" 2>/dev/null || true)
done

# 去重排序
sort -u -o "$BACKEND_PATHS" "$BACKEND_PATHS"

# ========================================
# 2. 从前端 api_endpoints.dart 提取所有 API 路径
# ========================================
# 输出格式：/auth/login, /family/me 等
FRONTEND_PATHS=$(mktemp)

# 提取 static const 路径（用 awk 提取单引号中的内容）
grep "static const" "$ENDPOINTS_FILE" | grep -v "apiPathPrefix" | grep -v "//" | while IFS= read -r line; do
    path=$(echo "$line" | awk -F"'" '{print $2}')
    if [ -n "$path" ] && [ "${path:0:1}" = "/" ]; then
        echo "$path" >> "$FRONTEND_PATHS"
    fi
done

# 提取 static String 方法返回的路径
grep "static String" "$ENDPOINTS_FILE" | grep "=>" | while IFS= read -r line; do
    # 提取最后一个单引号对中的路径（去除查询参数）
    path=$(echo "$line" | awk -F"'" '{for(i=NF;i>0;i--) if($i ~ /^\//) {print $i; break}}')
    if [ -n "$path" ]; then
        # 去除查询参数
        clean=$(echo "$path" | cut -d'?' -f1)
        echo "$clean" >> "$FRONTEND_PATHS"
    fi
done

# 去重排序
sort -u -o "$FRONTEND_PATHS" "$FRONTEND_PATHS"

echo "后端注册的路由: $(wc -l < "$BACKEND_PATHS" | tr -d ' ') 个"
echo "前端定义的端点: $(wc -l < "$FRONTEND_PATHS" | tr -d ' ') 个"
echo ""

# ========================================
# 3. 对比前后端路径
# ========================================
echo "--- 检查前端端点是否匹配后端路由 ---"

WARNINGS=0

while IFS= read -r fe_path; do
    [ -z "$fe_path" ] && continue

    # 将参数占位符统一为 {} 进行模糊匹配
    # Dart 用 $variable（在字符串插值中是 $xxx），后端用 {id}
    fe_normalized=$(echo "$fe_path" | sed 's/{[^}]*}/{}/g; s/\$[a-zA-Z_][a-zA-Z0-9_]*/{}/g')

    matched=false
    while IFS= read -r be_path; do
        [ -z "$be_path" ] && continue
        be_normalized=$(echo "$be_path" | sed 's/{[^}]*}/{}/g')

        if [ "$fe_normalized" = "$be_normalized" ]; then
            matched=true
            break
        fi
    done < "$BACKEND_PATHS"

    if $matched; then
        echo "  ✓ ${fe_path}"
    else
        echo "  ✗ ${fe_path} — 后端无对应路由！"
        WARNINGS=$((WARNINGS + 1))
    fi
done < "$FRONTEND_PATHS"

echo ""

# 清理
rm -f "$BACKEND_PATHS" "$FRONTEND_PATHS"

if [ "$WARNINGS" -gt 0 ]; then
    echo "❌ 发现 $WARNINGS 个前端端点在后端无对应路由"
    echo ""
    echo "可能原因："
    echo "  1. 前端拼写错误（如 /devices/token 应为 /device/token）"
    echo "  2. 后端路由已更改但前端未同步"
    echo "  3. 新增前端功能但后端尚未实现"
    exit 1
else
    echo "✅ 所有前端端点与后端路由匹配"
    exit 0
fi
