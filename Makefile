# SysArmor Infrastructure Services Management Makefile
# 灵活管理NATS集群、ClickHouse等基础服务
# 每个服务都有独立的docker-compose.yml文件

# 加载环境变量配置
include .env
export

.PHONY: help install-deps up down restart status health logs clean backup restore

# 环境变量
COMPOSE_PROJECT_NAME ?= sysarmor
BACKUP_DIR ?= ./backups
LOG_LEVEL ?= info

# 服务列表
SERVICES := nats clickhouse elasticsearch
AVAILABLE_SERVICES := $(SERVICES)

# 默认目标
help:
	@echo "SysArmor Infrastructure Services Management"
	@echo "=========================================="
	@echo ""
	@echo "🚀 服务部署 (支持参数 SERVICES='service1 service2'):"
	@echo "  up                  - 启动所有服务"
	@echo "  up-nats             - 启动NATS集群并自动设置JetStream"
	@echo "  up-clickhouse       - 仅启动ClickHouse"
	@echo "  up-elasticsearch    - 仅启动Elasticsearch和Kibana"
	@echo "  down                - 停止所有服务"
	@echo "  down-nats           - 仅停止NATS集群"
	@echo "  down-clickhouse     - 仅停止ClickHouse"
	@echo "  down-elasticsearch  - 仅停止Elasticsearch和Kibana"
	@echo "  restart             - 重启所有服务"
	@echo ""
	@echo "📊 监控和状态:"
	@echo "  status              - 查看所有服务状态"
	@echo "  health              - 健康检查所有服务"
	@echo "  logs                - 查看所有服务日志"
	@echo "  logs-follow         - 实时跟踪日志"
	@echo "  logs-nats           - 查看NATS日志"
	@echo "  logs-clickhouse     - 查看ClickHouse日志"
	@echo "  logs-elasticsearch  - 查看Elasticsearch日志"
	@echo ""
	@echo "🔧 维护操作:"
	@echo "  backup              - 备份所有数据"
	@echo "  clean               - 清理未使用的资源"
	@echo "  clean-all           - 强制清理所有SysArmor相关资源"
	@echo "  reset               - 完全重置 (删除所有数据)"
	@echo "  restart-clean       - 清理后重新启动所有服务"
	@echo ""
	@echo "🛠️  开发工具:"
	@echo "  dev-init            - 初始化开发环境"
	@echo "  test-connection     - 测试所有服务连接"
	@echo "  shell-clickhouse    - 进入ClickHouse容器"
	@echo "  shell-elasticsearch - 进入Elasticsearch容器"
	@echo "  shell-kibana        - 进入Kibana容器"
	@echo ""
	@echo "🚀 JetStream管理:"
	@echo "  jetstream-setup     - 创建JetStream Stream"
	@echo "  jetstream-info      - 查看Stream状态信息"
	@echo "  jetstream-test      - 测试消息发布"
	@echo "  jetstream-cleanup   - 清理Stream"
	@echo ""
	@echo "🔍 Elasticsearch管理:"
	@echo "  elasticsearch-setup-template  - 创建索引模板"
	@echo "  kibana-setup-index-pattern    - 创建Kibana索引模式"
	@echo "  elasticsearch-info            - 查看集群信息"
	@echo "  elasticsearch-test            - 测试连接和功能"
	@echo ""
	@echo "🔍 生产环境:"
	@echo "  prod-check          - 生产环境部署检查"
	@echo "  prod-deploy         - 生产环境部署"
	@echo ""
	@echo "📋 服务访问信息:"
	@echo "  NATS Cluster:   nats://$(EXTERNAL_HOST):$(NATS_PORT_1),$(NATS_PORT_2),$(NATS_PORT_3)"
	@echo "  NATS Monitor:   http://$(EXTERNAL_HOST):$(NATS_MONITOR_PORT_1),$(NATS_MONITOR_PORT_2),$(NATS_MONITOR_PORT_3)"
	@echo "  NATS Surveyor:  http://$(EXTERNAL_HOST):$(NATS_SURVEYOR_PORT)"
	@echo "  ClickHouse:     http://$(EXTERNAL_HOST):$(CLICKHOUSE_HTTP_PORT) ($(CLICKHOUSE_USER)/$(CLICKHOUSE_PASSWORD))"
	@echo "  Elasticsearch:  http://$(EXTERNAL_HOST):$(ELASTICSEARCH_HTTP_PORT)"
	@echo "  Kibana:         http://$(EXTERNAL_HOST):$(KIBANA_PORT)"
	@echo ""
	@echo "💡 使用示例:"
	@echo "  make up SERVICES='nats clickhouse'  # 只启动NATS和ClickHouse"
	@echo "  make down SERVICES='clickhouse'          # 只停止ClickHouse"
	@echo "  make logs SERVICES='nats clickhouse'  # 查看NATS和ClickHouse日志"

# 安装系统依赖
install-deps:
	@echo "🔧 安装系统依赖..."
	@if ! command -v docker >/dev/null 2>&1; then \
		echo "安装Docker..."; \
		curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh; \
		sudo usermod -aG docker $$USER; \
	else \
		echo "✅ Docker已安装"; \
	fi
	@if ! command -v docker-compose >/dev/null 2>&1; then \
		echo "安装Docker Compose..."; \
		sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$$(uname -s)-$$(uname -m)" -o /usr/local/bin/docker-compose; \
		sudo chmod +x /usr/local/bin/docker-compose; \
	else \
		echo "✅ Docker Compose已安装"; \
	fi
	@echo "✅ 系统依赖安装完成"

# 启动服务 (支持SERVICES参数)
up:
	@echo "🚀 启动SysArmor基础服务..."
	@mkdir -p $(BACKUP_DIR)
	@SERVICES_TO_START="$(if $(SERVICES),$(SERVICES),$(AVAILABLE_SERVICES))"; \
	for service in $$SERVICES_TO_START; do \
		if [ -d "services/$$service" ]; then \
			echo "启动 $$service 服务..."; \
			cd services/$$service && docker compose up -d && cd ../..; \
		else \
			echo "⚠️  服务目录 services/$$service 不存在"; \
		fi; \
	done
	@echo "⏳ 等待服务启动..."
	@sleep 10
	@make health
	@echo ""
	@echo "🎉 服务启动完成!"

# 单独启动各个服务
up-nats:
	@echo "🚀 启动NATS集群..."
	@cd services/nats && docker compose up -d
	@echo "⏳ 等待NATS集群启动..."
	@sleep 8
	@make health-nats
	@echo ""
	@echo "🚀 自动设置JetStream..."
	@make jetstream-setup || { \
		echo "⚠️  JetStream设置失败，但NATS集群已启动"; \
		echo "💡 可以稍后手动运行: make jetstream-setup"; \
	}
	@echo ""
	@echo "🎉 NATS集群和JetStream启动完成!"

up-clickhouse:
	@echo "🚀 启动ClickHouse..."
	@cd services/clickhouse && docker compose up -d
	@sleep 5
	@make health-clickhouse
	@echo "🗄️  创建 sysarmor 数据库..."
	@docker exec sysarmor-clickhouse clickhouse-client --user sysarmor --password sysarmor123 --query "CREATE DATABASE IF NOT EXISTS sysarmor" 2>/dev/null || { \
		echo "⚠️  数据库创建失败，可能已存在或权限不足"; \
	}
	@echo "✅ ClickHouse 启动完成，sysarmor 数据库已准备就绪"

up-elasticsearch:
	@echo "🚀 启动Elasticsearch和Kibana..."
	@cd services/elasticsearch && \
	export $$(cat ../../.env | grep -v '^#' | xargs) && \
	docker compose up -d
	@echo "⏳ 等待Elasticsearch启动..."
	@sleep 15
	@make health-elasticsearch
	@echo "📋 创建索引模板..."
	@make elasticsearch-setup-template || { \
		echo "⚠️  索引模板创建失败，可以稍后手动运行: make elasticsearch-setup-template"; \
	}
	@echo "📋 创建Kibana索引模式..."
	@make kibana-setup-index-pattern || { \
		echo "⚠️  Kibana索引模式创建失败，可以稍后手动运行: make kibana-setup-index-pattern"; \
	}
	@echo "✅ Elasticsearch和Kibana启动完成!"
	@echo "💡 现在可以直接访问 Kibana 查看数据: http://$(EXTERNAL_HOST):$(KIBANA_PORT)"

# 停止服务 (支持SERVICES参数)
down:
	@echo "🛑 停止SysArmor基础服务..."
	@SERVICES_TO_STOP="$(if $(SERVICES),$(SERVICES),$(AVAILABLE_SERVICES))"; \
	for service in $$SERVICES_TO_STOP; do \
		if [ -d "services/$$service" ]; then \
			echo "停止 $$service 服务..."; \
			cd services/$$service && docker compose down && cd ../..; \
		else \
			echo "⚠️  服务目录 services/$$service 不存在"; \
		fi; \
	done
	@echo "✅ 服务已停止"

# 单独停止各个服务
down-nats:
	@echo "🛑 停止NATS集群..."
	@cd services/nats && docker compose down

down-clickhouse:
	@echo "🛑 停止ClickHouse..."
	@cd services/clickhouse && docker compose down

down-elasticsearch:
	@echo "🛑 停止Elasticsearch和Kibana..."
	@cd services/elasticsearch && docker compose down

# 重启所有服务
restart: down up

# 查看服务状态
status:
	@echo "📊 SysArmor服务状态:"
	@echo "==================="
	@for service in $(AVAILABLE_SERVICES); do \
		if [ -d "services/$$service" ]; then \
			echo ""; \
			echo "📋 $$service 服务状态:"; \
			cd services/$$service && docker compose ps && cd ../..; \
		fi; \
	done
	@echo ""
	@echo "🐳 所有容器状态:"
	@echo "==============="
	@docker ps --filter "name=sysarmor-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 健康检查
health: health-nats health-clickhouse health-elasticsearch

health-nats:
	@echo "🔍 检查NATS集群健康状态..."
	@for port in $(NATS_MONITOR_PORT_1) $(NATS_MONITOR_PORT_2) $(NATS_MONITOR_PORT_3); do \
		if curl -s http://$(EXTERNAL_HOST):$$port/healthz >/dev/null 2>&1; then \
			echo "✅ NATS节点 :$$port 正常"; \
		else \
			echo "❌ NATS节点 :$$port 异常"; \
		fi; \
	done
	@if curl -s http://$(EXTERNAL_HOST):$(NATS_SURVEYOR_PORT) >/dev/null 2>&1; then \
		echo "✅ NATS Surveyor 正常"; \
	else \
		echo "❌ NATS Surveyor 异常"; \
	fi

health-clickhouse:
	@echo "🔍 检查ClickHouse健康状态..."
	@if curl -s http://$(EXTERNAL_HOST):$(CLICKHOUSE_HTTP_PORT)/ping >/dev/null 2>&1; then \
		echo "✅ ClickHouse 正常"; \
	else \
		echo "❌ ClickHouse 异常"; \
	fi

# 查看日志 (支持SERVICES参数)
logs:
	@echo "📋 查看服务日志 (最近100行):"
	@echo "=========================="
	@SERVICES_TO_LOG="$(if $(SERVICES),$(SERVICES),$(AVAILABLE_SERVICES))"; \
	for service in $$SERVICES_TO_LOG; do \
		if [ -d "services/$$service" ]; then \
			echo ""; \
			echo "📋 $$service 服务日志:"; \
			cd services/$$service && docker compose logs --tail=50 && cd ../..; \
		fi; \
	done

logs-follow:
	@echo "📋 实时跟踪所有服务日志 (Ctrl+C停止):"
	@echo "==============================="
	@for service in $(AVAILABLE_SERVICES); do \
		if [ -d "services/$$service" ]; then \
			cd services/$$service && docker compose logs -f & cd ../..; \
		fi; \
	done; \
	wait

# 查看特定服务日志
logs-nats:
	@cd services/nats && docker compose logs --tail=100

logs-clickhouse:
	@cd services/clickhouse && docker compose logs --tail=100

# 进入容器shell
shell-clickhouse:
	@echo "🐚 进入ClickHouse容器..."
	@docker exec -it sysarmor-clickhouse /bin/sh

# 数据库客户端
clickhouse-client:
	@echo "🔗 连接ClickHouse客户端..."
	@docker exec -it sysarmor-clickhouse clickhouse-client --user sysarmor --password sysarmor123

# 测试连接
test-connection:
	@echo "🧪 测试服务连接..."
	@echo "=================="
	@echo "测试NATS连接:"
	@for port in 4222 4223 4224; do \
		if command -v nats >/dev/null 2>&1; then \
			nats --server=nats://localhost:$$port server ping 2>/dev/null && echo "✅ NATS :$$port 连接成功" || echo "❌ NATS :$$port 连接失败"; \
		else \
			nc -z localhost $$port && echo "✅ NATS :$$port 端口开放" || echo "❌ NATS :$$port 端口关闭"; \
		fi; \
	done
	@echo ""
	@echo "测试ClickHouse连接:"
	@echo "SELECT 'ClickHouse连接成功', version(), now()" | curl -s 'http://localhost:8123/' --data-binary @- 2>/dev/null && echo "" || echo "❌ ClickHouse连接失败"
	@echo ""

# 备份数据
backup:
	@echo "💾 备份SysArmor数据..."
	@mkdir -p $(BACKUP_DIR)
	@TIMESTAMP=$$(date +%Y%m%d_%H%M%S); \
	echo "备份ClickHouse数据..."; \
	docker exec sysarmor-clickhouse clickhouse-client --user sysarmor --password sysarmor123 --query "SELECT * FROM sysarmor_events.events FORMAT CSVWithNames" > $(BACKUP_DIR)/clickhouse_events_$$TIMESTAMP.csv 2>/dev/null || echo "ClickHouse备份失败"; \
	echo "✅ 备份完成，文件保存在 $(BACKUP_DIR)/"


# 查看统计信息
stats:
	@echo "📊 服务资源使用统计:"
	@echo "==================="
	@docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" $$(docker ps --filter "name=sysarmor-" -q) 2>/dev/null || echo "无运行中的容器"

# 清理资源
clean:
	@echo "🧹 清理Docker资源..."
	@make down
	@docker system prune -f
	@docker volume prune -f
	@echo "✅ 清理完成"

# 强制清理所有相关资源
clean-all:
	@echo "🧹 强制清理所有SysArmor相关资源..."
	@echo "停止所有服务..."
	@make down 2>/dev/null || true
	@echo "清理SysArmor容器..."
	@docker ps -a --filter "name=sysarmor-" -q | xargs -r docker rm -f 2>/dev/null || true
	@echo "清理数据卷..."
	@docker volume ls -q --filter "name=sysarmor" | xargs -r docker volume rm -f 2>/dev/null || true
	@docker volume ls -q --filter "name=clickhouse" | xargs -r docker volume rm -f 2>/dev/null || true
	@docker volume ls -q --filter "name=nats" | xargs -r docker volume rm -f 2>/dev/null || true
	@echo "清理网络..."
	@docker network ls --filter "name=sysarmor" -q | xargs -r docker network rm 2>/dev/null || true
	@echo "清理未使用的资源..."
	@docker system prune -f >/dev/null 2>&1 || true
	@docker volume prune -f >/dev/null 2>&1 || true
	@echo "✅ 强制清理完成"

# 完全重置 (危险操作)
reset:
	@echo "⚠️  警告: 这将删除所有数据和配置!"
	@echo "确认删除所有数据? (输入 'yes' 确认): "; \
	read confirm; \
	if [ "$$confirm" = "yes" ]; then \
		echo "🗑️  删除所有数据..."; \
		make clean-all; \
		rm -rf $(BACKUP_DIR) 2>/dev/null || true; \
		echo "✅ 重置完成，所有数据已删除"; \
	else \
		echo "❌ 操作已取消"; \
	fi

# 快速重启 (清理后重新启动)
restart-clean:
	@echo "🔄 清理后重启所有服务..."
	@make clean-all
	@sleep 3
	@make up
	@echo "✅ 清理重启完成"

# 开发环境初始化
dev-init: install-deps up
	@echo "🛠️  初始化开发环境..."
	@sleep 5
	@make test-connection
	@echo ""
	@echo "🎉 开发环境初始化完成!"
	@echo ""
	@echo "💡 快速开始:"
	@echo "  make logs-follow    # 查看实时日志"
	@echo "  make health         # 检查服务健康状态"
	@echo "  make backup         # 备份数据"

# 生产环境检查
prod-check:
	@echo "🔍 生产环境部署检查..."
	@echo "===================="
	@echo ""
	@echo "⚠️  安全检查项:"
	@echo "  1. 修改默认密码"
	@echo "  2. 配置防火墙规则"
	@echo "  3. 启用SSL/TLS"
	@echo "  4. 配置备份策略"
	@echo "  5. 设置监控告警"
	@echo "  6. 配置日志轮转"
	@echo ""
	@echo "📋 配置检查:"
	@if grep -r "sysarmor123" services/ >/dev/null 2>&1; then \
		echo "❌ 发现默认密码，请修改"; \
	else \
		echo "✅ 未发现默认密码"; \
	fi
	@echo ""
	@echo "🔧 系统资源检查:"
	@echo "可用内存: $$(free -h | awk '/^Mem:/ {print $$7}')"
	@echo "可用磁盘: $$(df -h . | awk 'NR==2 {print $$4}')"
	@echo ""
	@echo "请在生产环境部署前完成所有安全配置!"

# 生产环境部署
prod-deploy: prod-check
	@echo "🚀 生产环境部署..."
	@echo "确认在生产环境部署? (输入 'yes' 确认): "; \
	read confirm; \
	if [ "$$confirm" = "yes" ]; then \
		echo "部署到生产环境..."; \
		COMPOSE_PROJECT_NAME=sysarmor-prod make up; \
		sleep 20; \
		make health; \
		echo "✅ 生产环境部署完成"; \
	else \
		echo "❌ 部署已取消"; \
	fi

# 监控面板
monitor:
	@echo "📊 打开监控面板..."
	@echo "NATS节点监控:"
	@echo "  节点1: http://localhost:8222"
	@echo "  节点2: http://localhost:8223"
	@echo "  节点3: http://localhost:8224"
	@echo "NATS Surveyor: http://localhost:7777"
	@if command -v xdg-open >/dev/null 2>&1; then \
		xdg-open http://localhost:8222; \
		xdg-open http://localhost:7777; \
	elif command -v open >/dev/null 2>&1; then \
		open http://localhost:8222; \
		open http://localhost:7777; \
	else \
		echo "请手动打开上述URL"; \
	fi

# JetStream管理命令
jetstream-setup:
	@echo "🚀 设置JetStream Streams和Consumers..."
	@chmod +x scripts/setup-jetstream.sh
	@./scripts/setup-jetstream.sh setup || { \
		echo ""; \
		echo "💡 提示: 请确保NATS集群已启动"; \
		echo "   make up-nats"; \
		echo "   make health-nats"; \
		echo "   然后重新运行: make jetstream-setup"; \
		exit 1; \
	}

jetstream-info:
	@echo "📊 查看JetStream状态信息..."
	@chmod +x scripts/setup-jetstream.sh
	@./scripts/setup-jetstream.sh info || { \
		echo ""; \
		echo "💡 提示: 请确保NATS集群已启动"; \
		echo "   make up-nats"; \
		exit 1; \
	}

jetstream-test:
	@echo "🧪 测试JetStream消息发布..."
	@chmod +x scripts/setup-jetstream.sh
	@./scripts/setup-jetstream.sh test || { \
		echo ""; \
		echo "💡 提示: 请确保NATS集群已启动且JetStream已设置"; \
		echo "   make up-nats"; \
		echo "   make jetstream-setup"; \
		exit 1; \
	}

jetstream-cleanup:
	@echo "🧹 清理JetStream配置..."
	@chmod +x scripts/setup-jetstream.sh
	@./scripts/setup-jetstream.sh cleanup || { \
		echo ""; \
		echo "💡 提示: 请确保NATS集群已启动"; \
		echo "   make up-nats"; \
		exit 1; \
	}

# Elasticsearch管理命令
health-elasticsearch:
	@echo "🔍 检查Elasticsearch健康状态..."
	@if curl -s http://$(EXTERNAL_HOST):$(ELASTICSEARCH_HTTP_PORT)/_cluster/health >/dev/null 2>&1; then \
		echo "✅ Elasticsearch 正常 (端口: $(ELASTICSEARCH_HTTP_PORT))"; \
	else \
		echo "❌ Elasticsearch 异常 (端口: $(ELASTICSEARCH_HTTP_PORT))"; \
	fi
	@if curl -s http://$(EXTERNAL_HOST):$(KIBANA_PORT)/api/status >/dev/null 2>&1; then \
		echo "✅ Kibana 正常 (端口: $(KIBANA_PORT))"; \
	else \
		echo "❌ Kibana 异常 (端口: $(KIBANA_PORT))"; \
	fi

logs-elasticsearch:
	@cd services/elasticsearch && docker compose logs --tail=100

shell-elasticsearch:
	@echo "🐚 进入Elasticsearch容器..."
	@docker exec -it sysarmor-elasticsearch /bin/bash

shell-kibana:
	@echo "🐚 进入Kibana容器..."
	@docker exec -it sysarmor-kibana /bin/bash

elasticsearch-setup-template:
	@echo "📋 创建Elasticsearch索引模板..."
	@curl -X PUT "http://$(EXTERNAL_HOST):$(ELASTICSEARCH_HTTP_PORT)/_index_template/$(INDEX_TEMPLATE_NAME)" \
		-H "Content-Type: application/json" \
		-d @services/elasticsearch/templates/sysarmor-events-template.json \
		2>/dev/null && echo "✅ 索引模板创建成功" || echo "❌ 索引模板创建失败"

kibana-setup-index-pattern:
	@echo "📋 创建Kibana索引模式..."
	@cd services/elasticsearch && \
	chmod +x templates/create-index-pattern.sh && \
	KIBANA_PORT=$(KIBANA_PORT) INDEX_PATTERN=$(INDEX_PATTERN) ./templates/create-index-pattern.sh

elasticsearch-info:
	@echo "📊 Elasticsearch集群信息:"
	@echo "========================"
	@curl -s "http://$(EXTERNAL_HOST):$(ELASTICSEARCH_HTTP_PORT)/_cluster/health?pretty" 2>/dev/null || echo "❌ 无法连接到Elasticsearch"
	@echo ""
	@echo "📋 索引信息:"
	@curl -s "http://$(EXTERNAL_HOST):$(ELASTICSEARCH_HTTP_PORT)/_cat/indices/$(INDEX_PATTERN)?v" 2>/dev/null || echo "❌ 无法获取索引信息"

elasticsearch-test:
	@echo "🧪 测试Elasticsearch连接和功能..."
	@echo "测试连接:"
	@curl -s "http://$(EXTERNAL_HOST):$(ELASTICSEARCH_HTTP_PORT)/" 2>/dev/null && echo "✅ Elasticsearch连接成功 (端口: $(ELASTICSEARCH_HTTP_PORT))" || echo "❌ Elasticsearch连接失败"
	@echo ""
	@echo "测试索引模板:"
	@curl -s "http://$(EXTERNAL_HOST):$(ELASTICSEARCH_HTTP_PORT)/_index_template/$(INDEX_TEMPLATE_NAME)" >/dev/null 2>&1 && echo "✅ 索引模板存在" || echo "❌ 索引模板不存在"
	@echo ""
	@echo "测试Kibana:"
	@curl -s "http://$(EXTERNAL_HOST):$(KIBANA_PORT)/api/status" >/dev/null 2>&1 && echo "✅ Kibana连接成功 (端口: $(KIBANA_PORT))" || echo "❌ Kibana连接失败"
