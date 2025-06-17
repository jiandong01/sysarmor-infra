#!/bin/bash

# SysArmor JetStream Stream 管理脚本
# 用于创建和管理处理sysdig事件的Stream

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置变量
NATS_URLS="nats://localhost:4222,nats://localhost:4223,nats://localhost:4224"
STREAM_NAME="SYSDIG_EVENTS"
SUBJECTS="events.sysdig.*"
RETENTION_POLICY="limits"  # limits, interest, workqueue
MAX_AGE="24h"              # 消息保留时间
MAX_MSGS=1000000           # 最大消息数量
MAX_BYTES="10GB"           # 最大存储大小
REPLICAS=3                 # 副本数量（高可用）

echo -e "${BLUE}🚀 SysArmor JetStream Stream 管理${NC}"
echo "=================================="

# 检查nats CLI工具
check_nats_cli() {
    if ! command -v nats &> /dev/null; then
        echo -e "${YELLOW}⚠️  NATS CLI工具未安装，正在安装...${NC}"
        
        # 检测操作系统
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            # Linux
            curl -sf https://binaries.nats.dev/nats-io/natscli/nats@latest | sh
            sudo mv nats /usr/local/bin/
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            if command -v brew &> /dev/null; then
                brew install nats-io/nats-tools/nats
            else
                curl -sf https://binaries.nats.dev/nats-io/natscli/nats@latest | sh
                sudo mv nats /usr/local/bin/
            fi
        else
            echo -e "${RED}❌ 不支持的操作系统，请手动安装NATS CLI${NC}"
            echo "访问: https://github.com/nats-io/natscli"
            exit 1
        fi
        
        echo -e "${GREEN}✅ NATS CLI安装完成${NC}"
    else
        echo -e "${GREEN}✅ NATS CLI已安装${NC}"
    fi
}

# 检查NATS连接
check_nats_connection() {
    echo -e "${BLUE}🔍 检查NATS集群连接...${NC}"
    
    local connection_failed=0
    for url in $(echo $NATS_URLS | tr "," "\n"); do
        # 使用简单的发布测试来验证连接，而不是server ping
        if echo "test" | nats --server="$url" pub "test.connection" &>/dev/null; then
            echo -e "${GREEN}✅ $url 连接成功${NC}"
        else
            echo -e "${RED}❌ $url 连接失败${NC}"
            connection_failed=1
        fi
    done
    
    if [ $connection_failed -eq 1 ]; then
        echo -e "${YELLOW}⚠️  NATS集群连接失败！${NC}"
        echo -e "${BLUE}💡 请先启动NATS集群:${NC}"
        echo "   cd sysarmor-infra-nats"
        echo "   make up-nats"
        echo "   make health-nats"
        echo ""
        echo -e "${BLUE}然后重新运行此脚本${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ NATS集群连接正常${NC}"
}

# 检查JetStream状态
check_jetstream_status() {
    echo -e "${BLUE}🔍 检查JetStream状态...${NC}"
    
    # 获取JetStream信息
    js_info=$(nats --server="$NATS_URLS" stream ls 2>/dev/null || echo "")
    
    echo -e "${GREEN}✅ JetStream已启用${NC}"
    echo "当前Streams:"
    if [ -n "$js_info" ]; then
        echo "$js_info"
    else
        echo "  (无现有Streams)"
    fi
}

# 创建Stream
create_stream() {
    echo -e "${BLUE}📦 创建SysArmor事件Stream...${NC}"
    
    # 检查Stream是否已存在
    if nats --server="$NATS_URLS" stream info "$STREAM_NAME" &>/dev/null; then
        echo -e "${YELLOW}⚠️  Stream '$STREAM_NAME' 已存在${NC}"
        read -p "是否要删除并重新创建? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}🗑️  删除现有Stream...${NC}"
            nats --server="$NATS_URLS" stream delete "$STREAM_NAME" --force
        else
            echo -e "${BLUE}ℹ️  保持现有Stream配置${NC}"
            return 0
        fi
    fi
    
    # 创建新Stream
    echo -e "${GREEN}🔨 创建新Stream: $STREAM_NAME${NC}"
    nats --server="$NATS_URLS" stream create "$STREAM_NAME" \
        --subjects="$SUBJECTS" \
        --retention="$RETENTION_POLICY" \
        --max-age="$MAX_AGE" \
        --max-msgs="$MAX_MSGS" \
        --max-bytes="$MAX_BYTES" \
        --replicas="$REPLICAS" \
        --storage=file \
        --discard=old \
        --dupe-window=2m
    
    echo -e "${GREEN}✅ Stream创建成功${NC}"
}

# 创建Consumer示例
create_consumer_example() {
    echo -e "${BLUE}👥 创建Consumer示例...${NC}"
    
    # 创建持久Consumer
    CONSUMER_NAME="sysdig-processor"
    
    if nats --server="$NATS_URLS" consumer info "$STREAM_NAME" "$CONSUMER_NAME" &>/dev/null; then
        echo -e "${YELLOW}⚠️  Consumer '$CONSUMER_NAME' 已存在${NC}"
    else
        echo -e "${GREEN}🔨 创建Consumer: $CONSUMER_NAME${NC}"
        nats --server="$NATS_URLS" consumer create "$STREAM_NAME" "$CONSUMER_NAME" \
            --filter="events.sysdig.*" \
            --ack=explicit \
            --pull \
            --deliver=all \
            --max-deliver=3 \
            --wait=30s \
            --replay=instant
        
        echo -e "${GREEN}✅ Consumer创建成功${NC}"
    fi
}

# 显示Stream信息
show_stream_info() {
    echo -e "${BLUE}📊 Stream信息:${NC}"
    echo "=============="
    nats --server="$NATS_URLS" stream info "$STREAM_NAME"
    
    echo -e "\n${BLUE}👥 Consumers:${NC}"
    echo "============"
    nats --server="$NATS_URLS" consumer ls "$STREAM_NAME"
}

# 测试消息发布
test_publish() {
    echo -e "${BLUE}🧪 测试消息发布...${NC}"
    
    # 发布测试消息
    test_message='{"timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)'","agent_id":"test-agent-001","event_type":"process_start","data":{"pid":1234,"command":"test-process","user":"root"}}'
    
    echo "发布测试消息到: events.sysdig.test-agent-001"
    echo "消息内容: $test_message"
    
    echo "$test_message" | nats --server="$NATS_URLS" pub "events.sysdig.test-agent-001"
    
    echo -e "${GREEN}✅ 测试消息发布成功${NC}"
    
    # 显示Stream统计
    echo -e "\n${BLUE}📈 Stream统计:${NC}"
    nats --server="$NATS_URLS" stream info "$STREAM_NAME" --json | jq '.state'
}

# 清理Stream
cleanup_stream() {
    echo -e "${YELLOW}🧹 清理Stream...${NC}"
    
    read -p "确认删除Stream '$STREAM_NAME' 及所有数据? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        nats --server="$NATS_URLS" stream delete "$STREAM_NAME" --force
        echo -e "${GREEN}✅ Stream已删除${NC}"
    else
        echo -e "${BLUE}ℹ️  操作已取消${NC}"
    fi
}

# 主菜单
show_menu() {
    echo -e "\n${BLUE}📋 选择操作:${NC}"
    echo "1) 完整设置 (推荐)"
    echo "2) 仅创建Stream"
    echo "3) 创建Consumer"
    echo "4) 查看Stream信息"
    echo "5) 测试消息发布"
    echo "6) 清理Stream"
    echo "7) 退出"
    echo
}

# 主函数
main() {
    # 检查依赖
    check_nats_cli
    check_nats_connection
    check_jetstream_status
    
    if [ $# -eq 0 ]; then
        # 交互模式
        while true; do
            show_menu
            read -p "请选择 (1-7): " choice
            case $choice in
                1)
                    create_stream
                    create_consumer_example
                    show_stream_info
                    test_publish
                    ;;
                2)
                    create_stream
                    ;;
                3)
                    create_consumer_example
                    ;;
                4)
                    show_stream_info
                    ;;
                5)
                    test_publish
                    ;;
                6)
                    cleanup_stream
                    ;;
                7)
                    echo -e "${GREEN}👋 再见!${NC}"
                    exit 0
                    ;;
                *)
                    echo -e "${RED}❌ 无效选择${NC}"
                    ;;
            esac
            echo
        done
    else
        # 命令行模式
        case $1 in
            "setup")
                create_stream
                create_consumer_example
                show_stream_info
                ;;
            "create-stream")
                create_stream
                ;;
            "create-consumer")
                create_consumer_example
                ;;
            "info")
                show_stream_info
                ;;
            "test")
                test_publish
                ;;
            "cleanup")
                cleanup_stream
                ;;
            *)
                echo "用法: $0 [setup|create-stream|create-consumer|info|test|cleanup]"
                echo "或直接运行 $0 进入交互模式"
                exit 1
                ;;
        esac
    fi
}

# 运行主函数
main "$@"
