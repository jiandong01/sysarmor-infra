# Kafka Service

Apache Kafka 消息队列服务，为 SysArmor 平台提供高吞吐量、分布式的消息流处理能力。

## 服务组件

### 核心服务
- **Zookeeper**: 集群协调服务 (端口: 2181)
- **Kafka Broker**: 消息代理服务 (端口: 9092, JMX: 9101)
- **Kafka UI**: Web 管理界面 (端口: 8081)

### 数据持久化
- **Zookeeper 数据**: `/var/lib/zookeeper/data` 和 `/var/lib/zookeeper/log`
- **Kafka 数据**: `/var/lib/kafka/data` 和 `/var/lib/kafka/logs`
- **数据保留**: 7天 (168小时) 或 1GB 大小限制

## 配置特性

### 基础配置
- **分区数**: 3个默认分区
- **副本因子**: 1 (单节点部署)
- **自动创建主题**: 启用
- **消息保留**: 7天或1GB

### 性能优化
- **网络线程**: 3个
- **IO线程**: 8个
- **发送缓冲区**: 100KB
- **接收缓冲区**: 100KB
- **最大请求大小**: 100MB

## 快速使用

### 启动服务
```bash
# 在 sysarmor-infra 根目录下
make up-kafka
```

### 访问服务
- **Kafka Broker**: `localhost:9092`
- **Kafka UI**: http://localhost:8081
- **Zookeeper**: `localhost:2181`

### 基本操作
```bash
# 查看服务状态
make status

# 查看日志
make logs-kafka

# 健康检查
make health-kafka

# 停止服务
make down-kafka
```

## 主题管理

### 创建主题
```bash
# 进入 Kafka 容器
docker exec -it sysarmor-kafka bash

# 创建主题
kafka-topics --create \
  --bootstrap-server localhost:9092 \
  --topic sysarmor-events \
  --partitions 3 \
  --replication-factor 1
```

### 查看主题
```bash
# 列出所有主题
kafka-topics --list --bootstrap-server localhost:9092

# 查看主题详情
kafka-topics --describe \
  --bootstrap-server localhost:9092 \
  --topic sysarmor-events
```

## 生产者和消费者

### 测试生产者
```bash
# 发送测试消息
kafka-console-producer \
  --bootstrap-server localhost:9092 \
  --topic sysarmor-events
```

### 测试消费者
```bash
# 消费消息
kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic sysarmor-events \
  --from-beginning
```

## 监控和管理

### Kafka UI 功能
- 主题管理和监控
- 消费者组状态查看
- 消息浏览和搜索
- 集群健康状态监控

### JMX 监控
- **JMX 端口**: 9101
- **监控指标**: 吞吐量、延迟、分区状态等

### 日志位置
- **Kafka 日志**: `/var/lib/kafka/logs`
- **Zookeeper 日志**: `/var/lib/zookeeper/log`

## 与 SysArmor 集成

### 事件主题建议
```bash
# 系统事件主题
sysarmor-events-system     # 系统级事件
sysarmor-events-process    # 进程事件
sysarmor-events-network    # 网络事件
sysarmor-events-file       # 文件操作事件
```

### 配置示例
```yaml
# Vector 配置示例
sources:
  nats_source:
    type: nats
    url: "nats://localhost:4222"
    subject: "events.sysdig.>"

sinks:
  kafka_sink:
    type: kafka
    inputs: ["nats_source"]
    bootstrap_servers: "localhost:9092"
    topic: "sysarmor-events-{{ .event_type }}"
```

## 故障排除

### 常见问题

1. **Kafka 启动失败**
   ```bash
   # 检查 Zookeeper 状态
   docker logs sysarmor-zookeeper
   
   # 检查端口占用
   netstat -tlnp | grep :9092
   ```

2. **连接超时**
   ```bash
   # 测试连接
   kafka-broker-api-versions --bootstrap-server localhost:9092
   ```

3. **磁盘空间不足**
   ```bash
   # 清理旧日志
   kafka-log-dirs --bootstrap-server localhost:9092 --describe
   ```

### 性能调优

1. **增加分区数**
   ```bash
   kafka-topics --alter \
     --bootstrap-server localhost:9092 \
     --topic sysarmor-events \
     --partitions 6
   ```

2. **调整保留策略**
   ```bash
   kafka-configs --alter \
     --bootstrap-server localhost:9092 \
     --entity-type topics \
     --entity-name sysarmor-events \
     --add-config retention.ms=604800000
   ```

## 安全配置

### 生产环境建议
- 启用 SASL/SSL 认证
- 配置访问控制列表 (ACL)
- 设置网络隔离
- 定期备份配置和数据

### 基础安全配置
```yaml
# 在生产环境中添加到 docker-compose.yml
environment:
  KAFKA_SECURITY_INTER_BROKER_PROTOCOL: SASL_SSL
  KAFKA_SASL_MECHANISM_INTER_BROKER_PROTOCOL: PLAIN
  KAFKA_SASL_ENABLED_MECHANISMS: PLAIN
```

## 备份和恢复

### 数据备份
```bash
# 备份主题数据
kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic sysarmor-events \
  --from-beginning \
  --max-messages 1000000 > backup.json
```

### 配置备份
```bash
# 备份主题配置
kafka-topics --describe \
  --bootstrap-server localhost:9092 > topics-backup.txt
```

## 版本信息

- **Kafka**: 7.4.0 (Confluent Platform)
- **Zookeeper**: 7.4.0 (Confluent Platform)
- **Kafka UI**: latest
- **Docker Compose**: 3.8

## 相关链接

- [Apache Kafka 官方文档](https://kafka.apache.org/documentation/)
- [Confluent Platform 文档](https://docs.confluent.io/)
- [Kafka UI 项目](https://github.com/provectus/kafka-ui)
