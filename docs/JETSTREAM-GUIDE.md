# SysArmor JetStream 配置指南

## 概述

SysArmor NATS集群已经启用了JetStream，为EDR/XDR数据采集系统提供持久化、重放和高级消息处理能力。

## 🎯 JetStream优势

### **数据持久化**
- 消息不会因为consumer离线而丢失
- 支持消息重放和历史数据分析
- 自动故障恢复

### **高级消息处理**
- 消息去重
- 消息顺序保证
- 消费者负载均衡
- At-least-once 和 exactly-once 语义

### **监控和管理**
- 详细的流量统计
- 消费者状态监控
- 消息积压告警

## 🔧 当前配置

### **JetStream配置**
```conf
jetstream {
    store_dir: "/data/jetstream"
    max_memory_store: 4GB      # 每节点内存存储限制
    max_file_store: 100GB      # 每节点文件存储限制
}
```

### **集群配置**
- **3节点高可用集群**
- **副本数量**: 3 (确保高可用)
- **存储类型**: 文件存储 (持久化)
- **数据目录**: `/data/jetstream` (Docker卷持久化)

## 🚀 快速开始

### 1. 启动NATS集群
```bash
# 启动NATS集群 (JetStream已自动启用)
make up-nats

# 检查集群健康状态
make health-nats
```

### 2. 设置JetStream Streams
```bash
# 一键设置 (推荐)
make jetstream-setup

# 或者交互式管理
make jetstream-manage
```

### 3. 查看JetStream状态
```bash
# 查看Stream和Consumer信息
make jetstream-info

# 测试消息发布
make jetstream-test
```

## 📋 Stream配置详情

### **SYSDIG_EVENTS Stream**
```yaml
Name: SYSDIG_EVENTS
Subjects: events.sysdig.*
Retention: limits
Max Age: 24h
Max Messages: 1,000,000
Max Bytes: 10GB
Replicas: 3
Storage: file
Discard Policy: old
Duplicate Window: 2m
```

### **Consumer配置**
```yaml
Name: sysdig-processor
Filter: events.sysdig.*
Ack Policy: explicit
Delivery: pull
Max Deliver: 3
Wait: 30s
Replay: instant
```

## 🔄 Collector集成

### **向后兼容性**
Collector端**无需修改**！JetStream会自动捕获发送到指定subject的消息：

```go
// Collector继续正常发布消息
nc.Publish("events.sysdig.agent-001", eventData)
```

### **消息流程**
```
Collector → NATS Core → JetStream Stream → Consumer
```

## 📊 监控和管理

### **Web监控面板**
```bash
# 打开NATS监控面板
make monitor

# 访问地址:
# - 节点1: http://localhost:8222
# - 节点2: http://localhost:8223  
# - 节点3: http://localhost:8224
# - Surveyor: http://localhost:7777
```

### **命令行管理**
```bash
# 查看所有Streams
nats stream ls

# 查看Stream详情
nats stream info SYSDIG_EVENTS

# 查看Consumers
nats consumer ls SYSDIG_EVENTS

# 查看消息统计
nats stream info SYSDIG_EVENTS --json | jq '.state'
```

## 🧪 测试和验证

### **发布测试消息**
```bash
# 使用管理脚本测试
make jetstream-test

# 手动发布消息
echo '{"agent_id":"test-001","event":"process_start"}' | \
  nats pub events.sysdig.test-001
```

### **消费消息**
```bash
# 拉取消息
nats consumer next SYSDIG_EVENTS sysdig-processor

# 订阅实时消息
nats sub events.sysdig.* --queue=processors
```

## 🔧 高级配置

### **自定义Stream**
```bash
# 创建自定义Stream
nats stream create MY_STREAM \
  --subjects="events.custom.*" \
  --retention=limits \
  --max-age=48h \
  --max-msgs=2000000 \
  --replicas=3
```

### **Consumer组管理**
```bash
# 创建Consumer组
nats consumer create SYSDIG_EVENTS processor-group-1 \
  --filter="events.sysdig.*" \
  --ack=explicit \
  --pull \
  --max-deliver=5
```

### **消息重放**
```bash
# 从特定时间重放
nats consumer create SYSDIG_EVENTS replay-consumer \
  --deliver=by_start_time \
  --opt-start-time="2024-12-01T10:00:00Z"

# 从特定序列号重放
nats consumer create SYSDIG_EVENTS replay-consumer \
  --deliver=by_start_sequence \
  --opt-start-seq=1000
```

## 📈 性能优化

### **存储配置**
```conf
# 针对高吞吐量优化
jetstream {
    store_dir: "/data/jetstream"
    max_memory_store: 8GB      # 增加内存缓存
    max_file_store: 500GB      # 增加存储空间
    sync_interval: "2s"        # 同步间隔
}
```

### **Stream优化**
```bash
# 高性能Stream配置
nats stream create HIGH_PERF_STREAM \
  --subjects="events.high.*" \
  --retention=limits \
  --max-age=12h \
  --max-msgs=5000000 \
  --max-bytes=50GB \
  --replicas=3 \
  --discard=old \
  --max-msg-size=1MB
```

## 🚨 故障排除

### **常见问题**

1. **Stream创建失败**
   ```bash
   # 检查JetStream状态
   nats server info
   
   # 检查存储空间
   df -h /data/jetstream
   ```

2. **消息丢失**
   ```bash
   # 检查Stream配置
   nats stream info SYSDIG_EVENTS
   
   # 检查Consumer状态
   nats consumer info SYSDIG_EVENTS sysdig-processor
   ```

3. **性能问题**
   ```bash
   # 查看Stream统计
   nats stream report
   
   # 监控资源使用
   make stats
   ```

### **日志分析**
```bash
# 查看NATS日志
make logs-nats

# 查看JetStream相关日志
docker logs sysarmor-nats-1 | grep -i jetstream
```

## 🔄 备份和恢复

### **数据备份**
```bash
# 备份Stream数据
nats stream backup SYSDIG_EVENTS ./backups/

# 备份所有数据
make backup
```

### **数据恢复**
```bash
# 恢复Stream数据
nats stream restore SYSDIG_EVENTS ./backups/SYSDIG_EVENTS.tar.gz
```

## 📚 最佳实践

### **Subject命名规范**
```
events.sysdig.{collector_id}           # 特定agent事件
events.sysdig.{collector_id}.{type}    # 特定类型事件
events.osquery.{collector_id}          # OSQuery事件
events.system.{hostname}           # 系统事件
```

### **Consumer策略**
- **Pull Consumer**: 适合批处理和负载均衡
- **Push Consumer**: 适合实时处理
- **Queue Groups**: 适合水平扩展

### **保留策略**
- **limits**: 基于时间/大小/数量限制
- **interest**: 基于Consumer兴趣
- **workqueue**: 工作队列模式

## 🔗 相关链接

- [NATS JetStream文档](https://docs.nats.io/jetstream)
- [NATS CLI工具](https://github.com/nats-io/natscli)
- [SysArmor架构文档](./README.md)

## 💡 使用示例

### **完整工作流程**
```bash
# 1. 启动服务
make up-nats

# 2. 设置JetStream
make jetstream-setup

# 3. 启动collector (无需修改)
cd ../sysarmor-collector
make run

# 4. 监控消息流
make jetstream-info

# 5. 查看监控面板
make monitor
```

### **开发环境快速验证**
```bash
# 一键验证JetStream功能
make jetstream-test

# 查看消息统计
nats stream info SYSDIG_EVENTS --json | jq '.state.messages'
```

---

**注意**: JetStream已在所有NATS节点启用，collector端无需任何修改即可享受持久化和高级消息处理功能。
