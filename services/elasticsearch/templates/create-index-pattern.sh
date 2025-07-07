#!/bin/bash

# SysArmor Kibana 索引模式创建脚本

KIBANA_URL="http://localhost:${KIBANA_PORT:-5602}"
INDEX_PATTERN="${INDEX_PATTERN:-sysarmor-events-*}"

echo "🔍 等待 Kibana 启动..."

# 等待 Kibana 启动
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if curl -s "$KIBANA_URL/api/status" >/dev/null 2>&1; then
        echo "✅ Kibana 已启动"
        break
    fi
    echo "等待中... ($((attempt + 1))/$max_attempts)"
    sleep 5
    attempt=$((attempt + 1))
done

if [ $attempt -eq $max_attempts ]; then
    echo "❌ Kibana 启动超时"
    exit 1
fi

echo "📋 创建索引模式: $INDEX_PATTERN"

# 创建索引模式
response=$(curl -s -X POST "$KIBANA_URL/api/data_views/data_view" \
    -H "Content-Type: application/json" \
    -H "kbn-xsrf: true" \
    -d "{
        \"data_view\": {
            \"title\": \"$INDEX_PATTERN\",
            \"timeFieldName\": \"@timestamp\"
        }
    }")

if echo "$response" | grep -q '"id"'; then
    echo "✅ 索引模式创建成功"
    echo "$response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4
else
    echo "⚠️  索引模式创建失败或已存在"
    echo "响应: $response"
fi
