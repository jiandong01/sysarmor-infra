# SysArmor Infrastructure Services

SysArmor EDR/XDR平台的完整基础设施服务，采用模块化设计，每个服务独立管理，灵活部署。

## 项目概述

本项目提供SysArmor平台所需的所有基础服务：
- 🚀 **NATS集群**: 3节点高可用消息队列，支持JetStream持久化
- 🗄️ **ClickHouse**: 高性能时序数据库，用于事件数据存储和分析
- 🔍 **OpenSearch**: 开源搜索和分析引擎，替代Elasticsearch，支持全文搜索和实时分析
- 📊 **OpenSearch Dashboards**: 可视化分析平台，替代Kibana，提供丰富的数据可视化功能
- 🐘 **PostgreSQL**: 关系型数据库，用于元数据和配置管理
- 🔴 **Redis**: 内存缓存，用于会话和临时数据存储
- 📊 **监控面板**: 内置服务监控和健康检查
- 🛠️ **管理工具**: 完整的部署、维护和备份工具

## 🎯 核心特性

### **模块化架构**
- 每个服务都有独立的docker-compose.yml文件
- 可以单独启动、停止、管理任意服务
- 支持灵活的服务组合部署

### **灵活部署**
```bash
# 启动所有服务
make up

# 只启动NATS和ClickHouse
make up SERVICES='nats clickhouse'

# 只启动PostgreSQL
make up-postgres

# 查看特定服务日志
make logs SERVICES='nats postgres'
```

### **独立部署**
- 每个服务使用默认Docker网络
- 适合Terraform在不同ECS实例上分别部署
- 服务间通过外部IP地址通信

## 目录结构

```
sysarmor-infra/
├── README.md                           # 本文档
├── Makefile                           # 统一管理命令
├── .gitignore                         # Git忽略文件
└── services/                          # 所有服务配置
    ├── nats/                          # NATS集群服务
    │   ├── docker-compose.yml         # NATS服务编排
    │   └── configs/                   # NATS配置文件
    │       ├── nats-1.conf
    │       ├── nats-2.conf
    │       └── nats-3.conf
    ├── clickhouse/                    # ClickHouse服务
    │   ├── docker-compose.yml         # ClickHouse服务编排
    │   ├── config/                    # 配置文件
    │   │   ├── clickhouse-config.xml
    │   │   └── users.xml
    │   └── init/                      # 初始化脚本
    │       └── 01-create-database.sql
    ├── opensearch/                    # OpenSearch服务
    │   ├── docker-compose.yml         # OpenSearch服务编排
    │   ├── config/                    # 配置文件
    │   │   ├── opensearch.yml
    │   │   ├── opensearch_dashboards.yml
    │   │   └── internal_users.yml
    │   └── templates/                 # 索引模板
    │       ├── sysarmor-events-template.json
    │       └── create-index-pattern.sh
    ├── elasticsearch/                 # Elasticsearch服务 (兼容性保留)
    │   ├── docker-compose.yml         # Elasticsearch服务编排
    │   ├── config/                    # 配置文件
    │   └── templates/                 # 索引模板
    ├── postgres/                      # PostgreSQL服务
    │   ├── docker-compose.yml         # PostgreSQL服务编排
    │   ├── config/                    # 配置文件
    │   │   └── postgresql.conf
    │   └── init/                      # 初始化脚本
    │       └── 01-create-database.sql
    └── redis/                         # Redis服务
        └── docker-compose.yml         # Redis服务编排
```

## 快速开始

### 1. 系统要求

- **操作系统**: Linux (Ubuntu 20.04+, CentOS 8+) 或 macOS
- **内存**: 最少8GB，推荐16GB+
- **存储**: 最少50GB可用空间
- **网络**: 稳定的网络连接

### 2. 一键部署

```bash
# 克隆项目
git clone <repository-url>
cd sysarmor-nats-server

# 初始化开发环境 (自动安装依赖并启动所有服务)
make dev-init

# 或者手动步骤
make install-deps  # 安装Docker等依赖
make up            # 启动所有服务
make health        # 检查服务健康状态
```

### 3. JetStream配置 (消息持久化)

NATS集群已启用JetStream，提供消息持久化、重放和高级处理能力：

```bash
# 启动NATS集群后，设置JetStream Streams
make jetstream-setup     # 一键设置sysdig事件Stream (推荐)

# 查看JetStream状态
make jetstream-info      # 查看Stream和Consumer信息

# 测试消息发布
make jetstream-test      # 验证JetStream功能

# 交互式管理
make jetstream-manage    # 进入交互式JetStream管理
```

**JetStream优势**:
- ✅ **消息持久化**: 消息不会因consumer离线而丢失
- ✅ **向后兼容**: Collector端无需修改，自动捕获 `events.sysdig.*` 消息
- ✅ **高可用**: 3副本确保数据安全
- ✅ **消息重放**: 支持历史数据分析和故障恢复

### 4. 灵活部署示例

```bash
# 只启动消息队列和数据库
make up SERVICES='nats clickhouse postgres'

# 只启动NATS集群
make up-nats

# 停止特定服务
make down SERVICES='redis'

# 查看特定服务状态
make status

# 查看特定服务日志
make logs SERVICES='clickhouse postgres'
```

## 服务管理

### 服务启动

```bash
# 启动所有服务
make up

# 启动特定服务组合
make up SERVICES='nats clickhouse'

# 单独启动服务
make up-nats          # 启动NATS集群
make up-clickhouse    # 启动ClickHouse
make up-opensearch    # 启动OpenSearch和Dashboards
make up-elasticsearch # 启动Elasticsearch和Kibana (兼容性)
make up-postgres      # 启动PostgreSQL
make up-redis         # 启动Redis
```

### 服务停止

```bash
# 停止所有服务
make down

# 停止特定服务组合
make down SERVICES='redis postgres'

# 单独停止服务
make down-nats        # 停止NATS集群
make down-clickhouse  # 停止ClickHouse
make down-postgres    # 停止PostgreSQL
make down-redis       # 停止Redis
```

### 服务监控

```bash
# 查看所有服务状态
make status

# 健康检查
make health

# 查看日志
make logs                              # 所有服务日志
make logs SERVICES='nats clickhouse'   # 特定服务日志
make logs-nats                         # NATS日志
make logs-clickhouse                   # ClickHouse日志
make logs-postgres                     # PostgreSQL日志
make logs-redis                        # Redis日志

# 实时跟踪日志
make logs-follow
```

## 服务架构

### 整体架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                    SysArmor Infrastructure                     │
│                      (独立部署模式)                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │   NATS-1    │  │   NATS-2    │  │   NATS-3    │             │
│  │ :4222/:8222 │◄─┤ :4223/:8223 ├─►│ :4224/:8224 │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
│         ▲                 ▲                 ▲                   │
│         └─────────────────┼─────────────────┘                   │
│                           │                                     │
│                  ┌─────────────┐                                │
│                  │ NATS Survey │                                │
│                  │   :7777     │                                │
│                  └─────────────┘                                │
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │ ClickHouse  │  │ PostgreSQL  │  │   Redis     │             │
│  │   :8123     │  │   :5432     │  │   :6379     │             │
│  │ (事件数据)   │  │ (元数据)     │  │  (缓存)      │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
│                                                                 │
│  💡 每个服务可独立部署到不同的ECS实例                            │
└─────────────────────────────────────────────────────────────────┘
```

### 服务详情

| 服务 | 端口 | 用途 | Docker Compose | 数据持久化 |
|------|------|------|---------------|-----------|
| **NATS集群** | 4222-4224 | 消息队列和事件流 | services/nats/ | JetStream |
| **NATS监控** | 8222-8224 | 集群状态监控 | services/nats/ | - |
| **NATS Surveyor** | 7777 | 集群可视化监控 | services/nats/ | - |
| **ClickHouse** | 8123, 9000 | 事件数据存储和分析 | services/clickhouse/ | 本地存储 |
| **OpenSearch** | 9201, 9301 | 搜索和分析引擎 | services/opensearch/ | 本地存储 |
| **OpenSearch Dashboards** | 5602 | 数据可视化平台 | services/opensearch/ | - |
| **Elasticsearch** | 9200, 9300 | 搜索引擎 (兼容性) | services/elasticsearch/ | 本地存储 |
| **Kibana** | 5601 | 数据可视化 (兼容性) | services/elasticsearch/ | - |
| **PostgreSQL** | 5432 | 元数据和配置管理 | services/postgres/ | 本地存储 |
| **Redis** | 6379 | 缓存和会话存储 | services/redis/ | AOF持久化 |

## 高级用法

### 自定义服务组合

```bash
# 开发环境：只需要NATS和PostgreSQL
make up SERVICES='nats postgres'

# 测试环境：需要所有服务
make up

# 生产环境：分阶段启动
make up-postgres      # 先启动数据库
make up-clickhouse    # 再启动分析数据库
make up-nats          # 最后启动消息队列
```

### 服务依赖管理

每个服务独立运行，适合分布式部署：

```bash
# 服务间通过外部IP地址通信
# NATS集群: 通过配置文件指定集群节点
# 应用连接: 通过环境变量或配置文件指定服务地址
# 适合Terraform在不同ECS实例上部署
```

### 数据库操作

```bash
# 连接数据库客户端
make clickhouse-client
make postgres-client
make redis-client

# 进入容器shell
make shell-clickhouse
make shell-postgres
make shell-redis
```

### 备份和恢复

```bash
# 备份所有数据
make backup

# 恢复PostgreSQL数据
make restore-postgres FILE=backups/postgres_meta_20241201_120000.sql

# 查看备份文件
ls -la backups/
```

## 服务访问信息

### 开发环境默认访问地址

| 服务 | 地址 | 认证信息 |
|------|------|----------|
| **NATS集群** | nats://localhost:4222,4223,4224 | 无需认证 |
| **NATS监控** | http://localhost:8222 (节点1) | 无需认证 |
| **NATS Surveyor** | http://localhost:7777 | 无需认证 |
| **ClickHouse** | http://localhost:8123 | sysarmor/sysarmor123 |
| **OpenSearch** | http://localhost:9201 | admin/admin |
| **OpenSearch Dashboards** | http://localhost:5602 | admin/admin |
| **Elasticsearch** | http://localhost:9200 | elastic/elastic123 |
| **Kibana** | http://localhost:5601 | elastic/elastic123 |
| **PostgreSQL** | localhost:5432 | sysarmor/sysarmor123 |
| **Redis** | localhost:6379 | 无需认证 |

### 数据库信息

| 数据库 | 数据库名 | 用途 |
|--------|----------|------|
| **ClickHouse** | sysarmor_events | 事件数据存储 |
| **OpenSearch** | sysarmor-events-* | 搜索和分析索引 |
| **Elasticsearch** | sysarmor-events-* | 搜索索引 (兼容性) |
| **PostgreSQL** | sysarmor_meta | 元数据管理 |

## 部署场景

### 场景1: 开发环境

```bash
# 只需要基础服务
make up SERVICES='nats postgres'

# 需要时再启动其他服务
make up-clickhouse
make up-redis
```

### 场景2: 测试环境

```bash
# 启动所有服务进行完整测试
make up

# 运行健康检查
make health

# 查看服务状态
make status
```

### 场景3: 生产环境

```bash
# 生产环境检查
make prod-check

# 分步骤启动
make up-postgres      # 核心数据库
make up-clickhouse    # 分析数据库
make up-redis         # 缓存服务
make up-nats          # 消息队列

# 验证部署
make health
make test-connection
```

### 场景4: 故障恢复

```bash
# 只重启有问题的服务
make down-clickhouse
make up-clickhouse

# 或者重启特定服务组合
make restart SERVICES='clickhouse postgres'
```

## 监控和维护

### 资源监控

```bash
# 查看资源使用统计
make stats

# 打开监控面板
make monitor
```

### 日志管理

```bash
# 查看所有服务日志
make logs

# 查看特定服务日志
make logs SERVICES='nats clickhouse'

# 实时跟踪日志
make logs-follow

# 查看单个服务日志
make logs-nats
make logs-clickhouse
make logs-postgres
make logs-redis
```

### 维护操作

```bash
# 清理未使用资源
make clean

# 完全重置 (危险操作)
make reset

# 备份数据
make backup
```

## 故障排除

### 常见问题

1. **服务启动失败**
   ```bash
   # 检查特定服务状态
   make status
   
   # 查看错误日志
   make logs SERVICES='服务名'
   
   # 重启服务
   make down-服务名
   make up-服务名
   ```

3. **端口冲突**
   ```bash
   # 检查端口占用
   netstat -tlnp | grep :4222
   
   # 修改端口配置
   vim services/nats/docker-compose.yml
   ```

4. **数据库连接失败**
   ```bash
   # 测试连接
   make test-connection
   
   # 检查数据库状态
   make health-postgres
   make health-clickhouse
   ```

## 扩展和集成

### 添加新服务

1. 在services/目录下创建新服务目录
2. 添加docker-compose.yml文件
3. 更新Makefile中的SERVICES变量
4. 添加相应的健康检查和日志命令

### 与Collector集成

```bash
# 在collector配置中设置NATS地址
export NATS_URLS="nats://localhost:4222,nats://localhost:4223,nats://localhost:4224"
```

### 与Terraform集成

```hcl
# 示例Terraform配置
resource "aws_instance" "sysarmor_infrastructure" {
  ami           = "ami-12345678"
  instance_type = "t3.large"
  
  user_data = <<-EOF
    #!/bin/bash
    git clone <repository-url>
    cd sysarmor-nats-server
    make prod-deploy
  EOF
}
```

## 性能调优

### 资源配置建议

| 组件 | CPU | 内存 | 存储 | 网络 |
|------|-----|------|------|------|
| **NATS集群** | 2-4 cores | 4-8GB | 100GB SSD | 100Mbps |
| **ClickHouse** | 8-16 cores | 32-64GB | 1TB+ HDD | 1Gbps |
| **PostgreSQL** | 4-8 cores | 16-32GB | 500GB SSD | 100Mbps |
| **Redis** | 2-4 cores | 8-16GB | 100GB SSD | 100Mbps |

### 处理能力

| 规模 | 推荐服务组合 | 事件处理能力 | 查询响应时间 |
|------|-------------|-------------|-------------|
| 小型 (10-50台) | nats + postgres | 5K events/sec | <100ms |
| 中型 (50-200台) | nats + clickhouse + postgres | 25K events/sec | <200ms |
| 大型 (200-1000台) | 全部服务 | 100K+ events/sec | <500ms |

## 版本信息

- **NATS Server**: 2.10.7
- **ClickHouse**: 23.8
- **PostgreSQL**: 15
- **Redis**: 7
- **Docker Compose**: 3.8

## 许可证

本项目采用MIT许可证。

## 支持和贡献

### 获取帮助

1. **查看文档**: 首先查看本README和相关配置文件
2. **检查日志**: 使用 `make logs` 查看详细错误信息
3. **健康检查**: 使用 `make health` 检查服务状态
4. **社区支持**: 提交Issue或参与讨论

### 贡献指南

1. Fork本项目
2. 创建功能分支
3. 提交更改
4. 创建Pull Request

### 开发环境

```bash
# 设置开发环境
make dev-init

# 运行测试
make test-connection

# 查看服务状态
make status
```

---

**注意**: 这是一个模块化的基础设施项目，每个服务都可以独立管理。在生产环境使用前，请务必完成安全配置和性能调优。
