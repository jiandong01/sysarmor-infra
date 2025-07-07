# SysArmor Elasticsearch 服务

统一管理的 Elasticsearch 和 Kibana 服务，支持环境变量配置。

## 配置管理

### 环境变量配置文件 (.env)

所有的端口号、连接信息和配置参数都通过 `.env` 文件统一管理：

```bash
# 服务端口配置
ELASTICSEARCH_HTTP_PORT=9200
ELASTICSEARCH_TRANSPORT_PORT=9300
KIBANA_PORT=5601

# 集群配置
ELASTICSEARCH_CLUSTER_NAME=sysarmor-cluster
ELASTICSEARCH_NODE_NAME=sysarmor-node-1

# 内存配置
ELASTICSEARCH_HEAP_SIZE=512m
KIBANA_MEMORY_LIMIT=1g
```

### 配置文件结构

```
services/elasticsearch/
├── .env                           # 环境变量配置文件
├── docker-compose.yml             # 服务编排文件 (使用环境变量)
├── config/
│   ├── elasticsearch.yml          # ES 配置 (使用环境变量)
│   └── kibana.yml                 # Kibana 配置 (使用环境变量)
└── templates/
    ├── sysarmor-events-template.json  # ES 索引模板
    ├── kibana-index-pattern.json      # Kibana 索引模式
    └── init-kibana.sh                  # Kibana 初始化脚本
```

## 使用方式

### 启动服务

```bash
# 启动 Elasticsearch 和 Kibana
make up-elasticsearch

# 或者启动所有基础设施服务
make up
```

### 自动配置

启动时会自动执行以下配置：

1. **创建 Elasticsearch 索引模板**
   - 自动创建 `sysarmor-events` 索引模板
   - 定义字段映射和索引设置

2. **创建 Kibana 索引模式**
   - 自动创建 `sysarmor-events-*` 索引模式
   - 设置 `@timestamp` 为时间字段
   - 打开 Kibana 即可直接查看数据

### 访问地址

- **Elasticsearch**: http://localhost:9200
- **Kibana**: http://localhost:5601

## 配置自定义

### 修改端口号

编辑 `.env` 文件：

```bash
# 修改 Elasticsearch 端口
ELASTICSEARCH_HTTP_PORT=9201
ELASTICSEARCH_TRANSPORT_PORT=9301

# 修改 Kibana 端口
KIBANA_PORT=5602
```

### 修改内存配置

```bash
# 增加 Elasticsearch 内存
ELASTICSEARCH_HEAP_SIZE=1g

# 增加 Kibana 内存限制
KIBANA_MEMORY_LIMIT=2g
```

### 修改集群配置

```bash
# 修改集群名称
ELASTICSEARCH_CLUSTER_NAME=my-cluster

# 修改节点名称
ELASTICSEARCH_NODE_NAME=my-node-1
```

## 管理命令

### 健康检查

```bash
# 检查服务健康状态
make health-elasticsearch
```

### 索引管理

```bash
# 创建索引模板
make elasticsearch-setup-template

# 创建 Kibana 索引模式
make kibana-setup-index-pattern

# 查看集群信息
make elasticsearch-info

# 测试连接
make elasticsearch-test
```

### 日志查看

```bash
# 查看服务日志
make logs-elasticsearch

# 进入容器
make shell-elasticsearch
make shell-kibana
```

## 故障排除

### 常见问题

1. **端口冲突**
   - 修改 `.env` 文件中的端口配置
   - 重新启动服务

2. **内存不足**
   - 增加 `ELASTICSEARCH_HEAP_SIZE` 配置
   - 确保系统有足够内存

3. **索引模式未创建**
   - 手动运行：`make kibana-setup-index-pattern`
   - 检查 Kibana 日志：`make logs-elasticsearch`

### 调试命令

```bash
# 查看环境变量配置
cat services/elasticsearch/.env

# 查看容器状态
docker ps --filter "name=sysarmor-"

# 查看详细日志
make logs-elasticsearch

# 测试连接
curl http://localhost:9200/_cluster/health
curl http://localhost:5601/api/status
```

## 优势

### 1. 统一配置管理
- 所有配置参数集中在 `.env` 文件中
- 避免配置散落在多个文件中
- 便于维护和修改

### 2. 环境变量支持
- 支持不同环境的配置
- 便于 CI/CD 集成
- 支持容器化部署

### 3. 自动化配置
- 启动时自动创建索引模板
- 自动创建 Kibana 索引模式
- 开箱即用，无需手动配置

### 4. 灵活部署
- 支持独立部署
- 支持端口自定义
- 支持资源配置调整

## 安全建议

### 生产环境配置

1. **启用安全认证**
   ```bash
   XPACK_SECURITY_ENABLED=true
   ```

2. **修改加密密钥**
   ```bash
   KIBANA_ENCRYPTION_KEY=your-32-character-encryption-key
   ```

3. **配置 HTTPS**
   - 配置 SSL 证书
   - 启用 HTTPS 访问

4. **网络安全**
   - 配置防火墙规则
   - 限制访问 IP 范围

## 备份和恢复

### 数据备份

```bash
# 备份索引数据
curl -X GET "localhost:9200/sysarmor-events-*/_search" > backup.json

# 备份索引模板
curl -X GET "localhost:9200/_index_template/sysarmor-events" > template-backup.json
```

### 配置备份

```bash
# 备份配置文件
cp .env .env.backup
cp -r config config.backup
cp -r templates templates.backup
```

## 监控

### 集群监控

```bash
# 查看集群健康状态
curl "http://localhost:9200/_cluster/health?pretty"

# 查看节点信息
curl "http://localhost:9200/_nodes?pretty"

# 查看索引统计
curl "http://localhost:9200/_cat/indices/sysarmor-events-*?v"
```

### 性能监控

```bash
# 查看资源使用
make stats

# 查看容器日志
make logs-elasticsearch
```

这个配置系统提供了灵活、统一的管理方式，让 Elasticsearch 和 Kibana 的部署和维护变得更加简单高效。
