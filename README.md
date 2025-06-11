# SysArmor NATS Server

高性能NATS集群服务，为SysArmor EDR/XDR数据采集系统提供消息队列服务。

## 项目概述

本项目提供独立的NATS集群部署和管理，支持：
- 🚀 **高可用集群**: 3节点NATS集群，支持故障转移
- 📊 **实时监控**: 内置监控面板和健康检查
- 🔄 **持久化存储**: JetStream支持，确保数据不丢失
- 🛠️ **便捷管理**: Makefile提供完整的运维命令
- 🔧 **性能优化**: 针对高并发场景优化的配置

## 快速开始

### 1. 启动NATS集群

```bash
# 启动集群
make up

# 或者使用docker-compose
docker-compose up -d
```

### 2. 检查集群状态

```bash
# 查看集群状态
make status

# 检查健康状态
make health

# 查看实时日志
make logs-follow
```

### 3. 访问监控面板

- **Node 1**: http://localhost:8222
- **Node 2**: http://localhost:8223  
- **Node 3**: http://localhost:8224
- **Surveyor**: http://localhost:7777

## 架构设计

### 集群拓扑

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   NATS Node 1   │    │   NATS Node 2   │    │   NATS Node 3   │
│   Port: 4222    │◄──►│   Port: 4223    │◄──►│   Port: 4224    │
│   Monitor: 8222 │    │   Monitor: 8223 │    │   Monitor: 8224 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         ▲                       ▲                       ▲
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │  NATS Surveyor  │
                    │   Port: 7777    │
                    └─────────────────┘
```

### 端口分配

| 服务 | 客户端端口 | 监控端口 | 集群端口 |
|------|-----------|----------|----------|
| Node 1 | 4222 | 8222 | 6222 |
| Node 2 | 4223 | 8223 | 6223 |
| Node 3 | 4224 | 8224 | 6224 |
| Surveyor | - | 7777 | - |

## 配置说明

### 集群配置特性

- **高可用**: 3节点集群，任意节点故障不影响服务
- **负载均衡**: 客户端可连接任意节点
- **数据持久化**: JetStream提供消息持久化
- **性能优化**: 针对高并发场景调优

### 关键配置参数

```conf
# 性能优化
max_connections: 64000      # 最大连接数
max_payload: 1048576       # 最大消息大小 (1MB)
max_pending: 67108864      # 最大待处理消息 (64MB)

# JetStream持久化
max_memory_store: 512MB    # 内存存储限制
max_file_store: 2GB        # 文件存储限制
```

## 管理命令

### 基础操作

```bash
# 启动集群
make up

# 停止集群
make down

# 重启集群
make restart

# 查看状态
make status
```

### 监控和诊断

```bash
# 健康检查
make health

# 查看日志
make logs

# 实时日志
make logs-follow

# 集群统计
make stats
```

### 工具安装

```bash
# 安装NATS CLI工具
make install-tools

# 测试连接
make test-connection
```

### 维护操作

```bash
# 清理数据和网络
make clean

# 备份配置
make backup-config

# 开发环境启动
make dev-up
```

## 客户端连接

### Go客户端示例

```go
package main

import (
    "log"
    "github.com/nats-io/nats.go"
)

func main() {
    // 连接NATS集群
    nc, err := nats.Connect(
        "nats://localhost:4222,nats://localhost:4223,nats://localhost:4224",
        nats.ReconnectWait(time.Second*2),
        nats.MaxReconnects(-1),
    )
    if err != nil {
        log.Fatal(err)
    }
    defer nc.Close()

    // 发布消息
    nc.Publish("test.subject", []byte("Hello NATS!"))
    
    // 订阅消息
    nc.Subscribe("test.subject", func(m *nats.Msg) {
        log.Printf("Received: %s", string(m.Data))
    })
    
    select {} // 保持运行
}
```

### 命令行测试

```bash
# 发布消息
nats pub test.subject "Hello World"

# 订阅消息
nats sub test.subject

# 查看服务器信息
nats server info
```

## 性能调优

### 生产环境建议

1. **资源配置**
   ```yaml
   # docker-compose.yaml
   deploy:
     resources:
       limits:
         memory: 2G
         cpus: '1.0'
       reservations:
         memory: 1G
         cpus: '0.5'
   ```

2. **存储优化**
   ```conf
   # 使用SSD存储
   jetstream {
       store_dir: "/fast-storage/jetstream"
       max_file_store: 10GB
   }
   ```

3. **网络优化**
   ```conf
   # 调整网络缓冲区
   write_deadline: "5s"
   max_control_line: 8192
   ```

### 监控指标

关键监控指标：
- **连接数**: `connections`
- **消息吞吐**: `in_msgs`, `out_msgs`
- **数据流量**: `in_bytes`, `out_bytes`
- **内存使用**: `mem`
- **CPU使用**: `cpu`

## 故障排除

### 常见问题

1. **集群节点无法启动**
   ```bash
   # 检查端口占用
   netstat -tlnp | grep :4222
   
   # 查看容器日志
   make logs
   ```

2. **节点间连接失败**
   ```bash
   # 检查集群路由
   curl http://localhost:8222/routez
   
   # 检查网络连通性
   docker network ls
   ```

3. **性能问题**
   ```bash
   # 查看集群统计
   make stats
   
   # 监控资源使用
   docker stats
   ```

### 日志分析

```bash
# 查看错误日志
make logs | grep ERROR

# 查看连接日志
make logs | grep "Client connection"

# 查看集群日志
make logs | grep "Route connection"
```

## 与Collector集成

### 环境变量配置

```bash
# 在collector项目中设置NATS地址
export NATS_URLS="nats://localhost:4222,nats://localhost:4223,nats://localhost:4224"
```

### Docker网络集成

```yaml
# 如果collector也使用Docker，可以共享网络
networks:
  sysarmor-network:
    external: true
```

## 安全配置

### 基础安全

```conf
# 启用TLS (生产环境推荐)
tls {
    cert_file: "/etc/ssl/nats-server.crt"
    key_file: "/etc/ssl/nats-server.key"
}

# 启用认证
authorization {
    users = [
        {user: "collector", password: "secure_password"}
    ]
}
```

### 网络安全

```bash
# 限制访问IP (防火墙规则)
iptables -A INPUT -p tcp --dport 4222 -s 10.0.0.0/8 -j ACCEPT
iptables -A INPUT -p tcp --dport 4222 -j DROP
```

## 备份和恢复

### 数据备份

```bash
# 备份JetStream数据
docker exec nats-1 tar -czf /backup/jetstream-$(date +%Y%m%d).tar.gz /data/jetstream

# 备份配置文件
make backup-config
```

### 灾难恢复

```bash
# 停止集群
make down

# 恢复数据
docker run --rm -v nats-1-data:/data -v $(pwd)/backup:/backup alpine \
  tar -xzf /backup/jetstream-20231201.tar.gz -C /data

# 重启集群
make up
```

## 开发和测试

### 本地开发

```bash
# 启动开发环境
make dev-up

# 运行测试
make test-connection

# 停止开发环境
make dev-down
```

### 性能测试

```bash
# 使用NATS bench工具
nats bench test.subject --pub 10 --sub 10 --msgs 1000
```

## 版本信息

- **NATS Server**: 2.10.7
- **NATS Surveyor**: latest
- **Docker Compose**: 3.8

## 许可证

本项目采用MIT许可证。

## 支持

如有问题，请检查：
1. 集群状态: `make status`
2. 健康检查: `make health`  
3. 日志信息: `make logs`
4. 监控面板: http://localhost:8222
