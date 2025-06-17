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
CONFIG_FILE="configs/jetstream-config.json"

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
        exit 1
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

# 创建Stream (仅使用JSON配置)
create_stream() {
    echo -e "${BLUE}📦 创建SysArmor事件Stream...${NC}"
    
    # 检查配置文件是否存在
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}❌ 配置文件不存在: $CONFIG_FILE${NC}"
        exit 1
    fi
    
    # 检查jq工具
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}❌ jq工具未安装，请先安装jq${NC}"
        echo "Ubuntu/Debian: sudo apt-get install jq"
        echo "CentOS/RHEL: sudo yum install jq"
        echo "macOS: brew install jq"
        exit 1
    fi
    
    # 获取Stream名称
    local stream_name=$(jq -r '.name' "$CONFIG_FILE")
    
    # 检查Stream是否已存在，如果存在则跳过
    if nats --server="$NATS_URLS" stream info "$stream_name" &>/dev/null; then
        echo -e "${YELLOW}⚠️  Stream '$stream_name' 已存在，跳过创建${NC}"
        return 0
    fi
    
    # 使用JSON配置创建Stream
    echo -e "${GREEN}🔨 创建新Stream: $stream_name${NC}"
    
    if nats --server="$NATS_URLS" stream add --config="$CONFIG_FILE"; then
        echo -e "${GREEN}✅ Stream创建成功${NC}"
    else
        echo -e "${RED}❌ Stream创建失败${NC}"
        exit 1
    fi
}

# 显示Stream信息
show_stream_info() {
    local stream_name=$(jq -r '.name' "$CONFIG_FILE")
    
    echo -e "${BLUE}📊 Stream信息:${NC}"
    echo "=============="
    nats --server="$NATS_URLS" stream info "$stream_name"
}

# 测试消息发布
test_publish() {
    local stream_name=$(jq -r '.name' "$CONFIG_FILE")
    
    echo -e "${BLUE}🧪 测试消息发布...${NC}"
    
    # 发布测试消息
    test_message='{"timestamp":"'$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)'","agent_id":"test-agent-001","event_type":"process_start","data":{"pid":1234,"command":"test-process","user":"root"}}'
    
    echo "发布测试消息到: events.sysdig.test-agent-001"
    echo "消息内容: $test_message"
    
    echo "$test_message" | nats --server="$NATS_URLS" pub "events.sysdig.test-agent-001"
    
    echo -e "${GREEN}✅ 测试消息发布成功${NC}"
    
    # 显示Stream统计
    echo -e "\n${BLUE}📈 Stream统计:${NC}"
    nats --server="$NATS_URLS" stream info "$stream_name" --json | jq '.state'
}

# 清理Stream
cleanup_stream() {
    local stream_name=$(jq -r '.name' "$CONFIG_FILE")
    
    echo -e "${YELLOW}🧹 清理Stream...${NC}"
    
    if nats --server="$NATS_URLS" stream info "$stream_name" &>/dev/null; then
        nats --server="$NATS_URLS" stream delete "$stream_name" --force
        echo -e "${GREEN}✅ Stream已删除${NC}"
    else
        echo -e "${BLUE}ℹ️  Stream不存在${NC}"
    fi
}

# 主函数
main() {
    # 检查依赖
    check_nats_cli
    check_nats_connection
    check_jetstream_status
    
    # 根据参数执行不同操作
    case "${1:-setup}" in
        "setup")
            create_stream
            show_stream_info
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
            echo "用法: $0 [setup|info|test|cleanup]"
            echo "  setup   - 创建Stream (默认)"
            echo "  info    - 查看Stream信息"
            echo "  test    - 测试消息发布"
            echo "  cleanup - 清理Stream"
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"
