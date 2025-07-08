#!/bin/bash

# SysArmor OpenSearch Dashboards 索引模式创建脚本

DASHBOARDS_URL="http://localhost:${DASHBOARDS_PORT:-5602}"
OPENSEARCH_URL="http://localhost:${OPENSEARCH_PORT:-9201}"
INDEX_PATTERN="${INDEX_PATTERN:-sysarmor-events-*}"
USERNAME="${OPENSEARCH_USERNAME:-admin}"
PASSWORD="${OPENSEARCH_PASSWORD:-admin}"

echo "🔍 等待 OpenSearch Dashboards 启动..."

# 等待 OpenSearch Dashboards 启动
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if curl -s -u "$USERNAME:$PASSWORD" "$DASHBOARDS_URL/api/status" >/dev/null 2>&1; then
        echo "✅ OpenSearch Dashboards 已启动"
        break
    fi
    echo "等待中... ($((attempt + 1))/$max_attempts)"
    sleep 5
    attempt=$((attempt + 1))
done

if [ $attempt -eq $max_attempts ]; then
    echo "❌ OpenSearch Dashboards 启动超时"
    exit 1
fi

echo "📋 创建索引模式: $INDEX_PATTERN"

# 首先创建一个空索引以确保字段映射存在（不插入数据）
echo "🔧 创建空索引以初始化字段映射..."
sample_index="sysarmor-events-$(date +%Y.%m.%d)"
curl -s -X PUT "$OPENSEARCH_URL/$sample_index" \
    -u "$USERNAME:$PASSWORD" \
    -H "Content-Type: application/json" \
    -d '{
        "mappings": {
            "properties": {
                "@timestamp": {
                    "type": "date"
                },
                "event_id": {
                    "type": "keyword"
                },
                "collector_id": {
                    "type": "keyword"
                },
                "data_source": {
                    "type": "keyword"
                },
                "ingestion_timestamp": {
                    "type": "date"
                },
                "pipeline": {
                    "type": "keyword"
                },
                "pipeline_version": {
                    "type": "keyword"
                },
                "nats_subject": {
                    "type": "keyword"
                }
            }
        }
    }' >/dev/null

echo "✅ 空索引创建完成，字段映射已初始化"

# 等待索引就绪
sleep 1

# 创建索引模式 (OpenSearch Dashboards 使用不同的 API)
response=$(curl -s -X POST "$DASHBOARDS_URL/api/saved_objects/index-pattern" \
    -u "$USERNAME:$PASSWORD" \
    -H "Content-Type: application/json" \
    -H "osd-xsrf: true" \
    -d "{
        \"attributes\": {
            \"title\": \"$INDEX_PATTERN\",
            \"timeFieldName\": \"@timestamp\"
        }
    }")

if echo "$response" | grep -q '"id"'; then
    index_pattern_id=$(echo "$response" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
    echo "✅ 索引模式创建成功，ID: $index_pattern_id"
    
    # 设置为默认索引模式
    echo "🔧 设置为默认索引模式..."
    curl -s -X POST "$DASHBOARDS_URL/api/saved_objects/config/2.11.0" \
        -u "$USERNAME:$PASSWORD" \
        -H "Content-Type: application/json" \
        -H "osd-xsrf: true" \
        -d "{
            \"attributes\": {
                \"defaultIndex\": \"$index_pattern_id\"
            }
        }" >/dev/null
    
    echo "✅ 默认索引模式设置完成"
else
    echo "⚠️  索引模式创建失败或已存在"
    echo "响应: $response"
fi

echo "🎯 索引模式配置完成！"
echo "💡 现在可以在 OpenSearch Dashboards 中查看 $INDEX_PATTERN 数据"
