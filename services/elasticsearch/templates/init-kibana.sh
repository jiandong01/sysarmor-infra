#!/bin/bash

# Kibana 索引模式自动创建脚本
# 用于在 Kibana 启动后自动创建 sysarmor-events-* 索引模式

set -e

KIBANA_URL="http://localhost:5601"
ELASTICSEARCH_URL="http://localhost:9200"
INDEX_PATTERN_FILE="/usr/share/elasticsearch/templates/kibana-index-pattern.json"

echo "🔍 等待 Kibana 启动..."

# 等待 Kibana 启动
max_attempts=60
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if curl -s "$KIBANA_URL/api/status" >/dev/null 2>&1; then
        echo "✅ Kibana 已启动"
        break
    fi
    echo "⏳ 等待 Kibana 启动... ($((attempt + 1))/$max_attempts)"
    sleep 5
    attempt=$((attempt + 1))
done

if [ $attempt -eq $max_attempts ]; then
    echo "❌ Kibana 启动超时"
    exit 1
fi

# 等待 Elasticsearch 中有数据
echo "🔍 检查 Elasticsearch 中是否有 sysarmor-events 索引..."
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if curl -s "$ELASTICSEARCH_URL/_cat/indices/sysarmor-events-*" | grep -q "sysarmor-events"; then
        echo "✅ 发现 sysarmor-events 索引"
        break
    fi
    echo "⏳ 等待数据写入... ($((attempt + 1))/$max_attempts)"
    sleep 10
    attempt=$((attempt + 1))
done

if [ $attempt -eq $max_attempts ]; then
    echo "⚠️  未发现 sysarmor-events 索引，但继续创建索引模式"
fi

# 创建索引模式
echo "📋 创建 Kibana 索引模式..."

# 方法1: 使用 Kibana Saved Objects API
curl -X POST "$KIBANA_URL/api/saved_objects/_import" \
    -H "Content-Type: application/json" \
    -H "kbn-xsrf: true" \
    -d '{
        "version": "8.11.0",
        "objects": [
            {
                "id": "sysarmor-events-*",
                "type": "index-pattern",
                "updated_at": "2024-01-01T00:00:00.000Z",
                "version": "WzEsMV0=",
                "attributes": {
                    "title": "sysarmor-events-*",
                    "timeFieldName": "@timestamp"
                },
                "references": [],
                "migrationVersion": {
                    "index-pattern": "7.11.0"
                }
            }
        ]
    }' 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ 索引模式创建成功"
else
    echo "⚠️  索引模式创建可能失败，请手动检查"
fi

# 设置默认索引模式
echo "🎯 设置默认索引模式..."
curl -X POST "$KIBANA_URL/api/kibana/settings/defaultIndex" \
    -H "Content-Type: application/json" \
    -H "kbn-xsrf: true" \
    -d '{"value": "sysarmor-events-*"}' 2>/dev/null

echo "🎉 Kibana 初始化完成!"
echo "💡 现在可以访问 Kibana: $KIBANA_URL"
echo "📊 索引模式: sysarmor-events-*"
