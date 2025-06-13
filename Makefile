# SysArmor Infrastructure Services Management Makefile
# 灵活管理NATS集群、ClickHouse、PostgreSQL、Redis等基础服务
# 每个服务都有独立的docker-compose.yml文件

.PHONY: help install-deps up down restart status health logs clean backup restore

# 环境变量
COMPOSE_PROJECT_NAME ?= sysarmor
BACKUP_DIR ?= ./backups
LOG_LEVEL ?= info

# 服务列表
SERVICES := nats clickhouse postgres redis
AVAILABLE_SERVICES := $(SERVICES)

# 默认目标
help:
	@echo "SysArmor Infrastructure Services Management"
	@echo "=========================================="
	@echo ""
	@echo "🚀 服务部署 (支持参数 SERVICES='service1 service2'):"
	@echo "  up                  - 启动所有服务"
	@echo "  up-nats             - 仅启动NATS集群"
	@echo "  up-clickhouse       - 仅启动ClickHouse"
	@echo "  up-postgres         - 仅启动PostgreSQL"
	@echo "  up-redis            - 仅启动Redis"
	@echo "  down                - 停止所有服务"
	@echo "  down-nats           - 仅停止NATS集群"
	@echo "  down-clickhouse     - 仅停止ClickHouse"
	@echo "  down-postgres       - 仅停止PostgreSQL"
	@echo "  down-redis          - 仅停止Redis"
	@echo "  restart             - 重启所有服务"
	@echo ""
	@echo "📊 监控和状态:"
	@echo "  status              - 查看所有服务状态"
	@echo "  health              - 健康检查所有服务"
	@echo "  logs                - 查看所有服务日志"
	@echo "  logs-follow         - 实时跟踪日志"
	@echo "  logs-nats           - 查看NATS日志"
	@echo "  logs-clickhouse     - 查看ClickHouse日志"
	@echo "  logs-postgres       - 查看PostgreSQL日志"
	@echo "  logs-redis          - 查看Redis日志"
	@echo ""
	@echo "🔧 维护操作:"
	@echo "  backup              - 备份所有数据"
	@echo "  restore-postgres    - 恢复PostgreSQL数据"
	@echo "  clean               - 清理未使用的资源"
	@echo "  reset               - 完全重置 (删除所有数据)"
	@echo ""
	@echo "🛠️  开发工具:"
	@echo "  dev-init            - 初始化开发环境"
	@echo "  test-connection     - 测试所有服务连接"
	@echo "  shell-clickhouse    - 进入ClickHouse容器"
	@echo "  shell-postgres      - 进入PostgreSQL容器"
	@echo "  shell-redis         - 进入Redis容器"
	@echo ""
	@echo "🔍 生产环境:"
	@echo "  prod-check          - 生产环境部署检查"
	@echo "  prod-deploy         - 生产环境部署"
	@echo ""
	@echo "📋 服务访问信息:"
	@echo "  NATS Cluster:   nats://localhost:4222,4223,4224"
	@echo "  NATS Monitor:   http://localhost:8222,8223,8224"
	@echo "  NATS Surveyor:  http://localhost:7777"
	@echo "  ClickHouse:     http://localhost:8123 (sysarmor/sysarmor123)"
	@echo "  PostgreSQL:     localhost:5432 (sysarmor/sysarmor123)"
	@echo "  Redis:          localhost:6379"
	@echo ""
	@echo "💡 使用示例:"
	@echo "  make up SERVICES='nats clickhouse'  # 只启动NATS和ClickHouse"
	@echo "  make down SERVICES='redis'          # 只停止Redis"
	@echo "  make logs SERVICES='nats postgres'  # 查看NATS和PostgreSQL日志"

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
			cd services/$$service && docker-compose up -d && cd ../..; \
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
	@cd services/nats && docker-compose up -d
	@sleep 5
	@make health-nats

up-clickhouse:
	@echo "🚀 启动ClickHouse..."
	@cd services/clickhouse && docker-compose up -d
	@sleep 5
	@make health-clickhouse

up-postgres:
	@echo "🚀 启动PostgreSQL..."
	@cd services/postgres && docker-compose up -d
	@sleep 5
	@make health-postgres

up-redis:
	@echo "🚀 启动Redis..."
	@cd services/redis && docker-compose up -d
	@sleep 3
	@make health-redis

# 停止服务 (支持SERVICES参数)
down:
	@echo "🛑 停止SysArmor基础服务..."
	@SERVICES_TO_STOP="$(if $(SERVICES),$(SERVICES),$(AVAILABLE_SERVICES))"; \
	for service in $$SERVICES_TO_STOP; do \
		if [ -d "services/$$service" ]; then \
			echo "停止 $$service 服务..."; \
			cd services/$$service && docker-compose down && cd ../..; \
		else \
			echo "⚠️  服务目录 services/$$service 不存在"; \
		fi; \
	done
	@echo "✅ 服务已停止"

# 单独停止各个服务
down-nats:
	@echo "🛑 停止NATS集群..."
	@cd services/nats && docker-compose down

down-clickhouse:
	@echo "🛑 停止ClickHouse..."
	@cd services/clickhouse && docker-compose down

down-postgres:
	@echo "🛑 停止PostgreSQL..."
	@cd services/postgres && docker-compose down

down-redis:
	@echo "🛑 停止Redis..."
	@cd services/redis && docker-compose down

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
			cd services/$$service && docker-compose ps && cd ../..; \
		fi; \
	done
	@echo ""
	@echo "🐳 所有容器状态:"
	@echo "==============="
	@docker ps --filter "name=sysarmor-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 健康检查
health: health-nats health-clickhouse health-postgres health-redis

health-nats:
	@echo "🔍 检查NATS集群健康状态..."
	@for port in 8222 8223 8224; do \
		if curl -s http://localhost:$$port/healthz >/dev/null 2>&1; then \
			echo "✅ NATS节点 :$$port 正常"; \
		else \
			echo "❌ NATS节点 :$$port 异常"; \
		fi; \
	done
	@if curl -s http://localhost:7777 >/dev/null 2>&1; then \
		echo "✅ NATS Surveyor 正常"; \
	else \
		echo "❌ NATS Surveyor 异常"; \
	fi

health-clickhouse:
	@echo "🔍 检查ClickHouse健康状态..."
	@if curl -s http://localhost:8123/ping >/dev/null 2>&1; then \
		echo "✅ ClickHouse 正常"; \
	else \
		echo "❌ ClickHouse 异常"; \
	fi

health-postgres:
	@echo "🔍 检查PostgreSQL健康状态..."
	@if docker exec sysarmor-postgres pg_isready -U sysarmor -d sysarmor_meta >/dev/null 2>&1; then \
		echo "✅ PostgreSQL 正常"; \
	else \
		echo "❌ PostgreSQL 异常"; \
	fi

health-redis:
	@echo "🔍 检查Redis健康状态..."
	@if docker exec sysarmor-redis redis-cli ping >/dev/null 2>&1; then \
		echo "✅ Redis 正常"; \
	else \
		echo "❌ Redis 异常"; \
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
			cd services/$$service && docker-compose logs --tail=50 && cd ../..; \
		fi; \
	done

logs-follow:
	@echo "📋 实时跟踪所有服务日志 (Ctrl+C停止):"
	@echo "==============================="
	@for service in $(AVAILABLE_SERVICES); do \
		if [ -d "services/$$service" ]; then \
			cd services/$$service && docker-compose logs -f & cd ../..; \
		fi; \
	done; \
	wait

# 查看特定服务日志
logs-nats:
	@cd services/nats && docker-compose logs --tail=100

logs-clickhouse:
	@cd services/clickhouse && docker-compose logs --tail=100

logs-postgres:
	@cd services/postgres && docker-compose logs --tail=100

logs-redis:
	@cd services/redis && docker-compose logs --tail=100

# 进入容器shell
shell-clickhouse:
	@echo "🐚 进入ClickHouse容器..."
	@docker exec -it sysarmor-clickhouse /bin/sh

shell-postgres:
	@echo "🐚 进入PostgreSQL容器..."
	@docker exec -it sysarmor-postgres /bin/bash

shell-redis:
	@echo "🐚 进入Redis容器..."
	@docker exec -it sysarmor-redis /bin/sh

# 数据库客户端
clickhouse-client:
	@echo "🔗 连接ClickHouse客户端..."
	@docker exec -it sysarmor-clickhouse clickhouse-client --user sysarmor --password sysarmor123

postgres-client:
	@echo "🔗 连接PostgreSQL客户端..."
	@docker exec -it sysarmor-postgres psql -U sysarmor -d sysarmor_meta

redis-client:
	@echo "🔗 连接Redis客户端..."
	@docker exec -it sysarmor-redis redis-cli

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
	@echo "测试PostgreSQL连接:"
	@docker exec sysarmor-postgres psql -U sysarmor -d sysarmor_meta -c "SELECT 'PostgreSQL连接成功', version(), now();" 2>/dev/null || echo "❌ PostgreSQL连接失败"
	@echo ""
	@echo "测试Redis连接:"
	@docker exec sysarmor-redis redis-cli ping 2>/dev/null || echo "❌ Redis连接失败"

# 备份数据
backup:
	@echo "💾 备份SysArmor数据..."
	@mkdir -p $(BACKUP_DIR)
	@TIMESTAMP=$$(date +%Y%m%d_%H%M%S); \
	echo "备份ClickHouse数据..."; \
	docker exec sysarmor-clickhouse clickhouse-client --user sysarmor --password sysarmor123 --query "SELECT * FROM sysarmor_events.events FORMAT CSVWithNames" > $(BACKUP_DIR)/clickhouse_events_$$TIMESTAMP.csv 2>/dev/null || echo "ClickHouse备份失败"; \
	echo "备份PostgreSQL数据..."; \
	docker exec sysarmor-postgres pg_dump -U sysarmor sysarmor_meta > $(BACKUP_DIR)/postgres_meta_$$TIMESTAMP.sql 2>/dev/null || echo "PostgreSQL备份失败"; \
	echo "备份Redis数据..."; \
	docker exec sysarmor-redis redis-cli --rdb /data/dump.rdb >/dev/null 2>&1 && docker cp sysarmor-redis:/data/dump.rdb $(BACKUP_DIR)/redis_$$TIMESTAMP.rdb 2>/dev/null || echo "Redis备份失败"; \
	echo "备份配置文件..."; \
	tar -czf $(BACKUP_DIR)/configs_$$TIMESTAMP.tar.gz services/ scripts/ Makefile 2>/dev/null || echo "配置备份失败"; \
	echo "✅ 备份完成，文件保存在 $(BACKUP_DIR)/"

# 恢复数据
restore-postgres:
	@if [ -z "$(FILE)" ]; then \
		echo "❌ 请指定备份文件: make restore-postgres FILE=backups/postgres_meta_20241201_120000.sql"; \
		exit 1; \
	fi
	@echo "🔄 恢复PostgreSQL数据从 $(FILE)..."
	@docker exec -i sysarmor-postgres psql -U sysarmor sysarmor_meta < $(FILE)
	@echo "✅ PostgreSQL数据恢复完成"

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

# 完全重置 (危险操作)
reset:
	@echo "⚠️  警告: 这将删除所有数据和配置!"
	@echo "确认删除所有数据? (输入 'yes' 确认): "; \
	read confirm; \
	if [ "$$confirm" = "yes" ]; then \
		echo "🗑️  删除所有数据..."; \
		make down; \
		docker volume rm -f $$(docker volume ls -q | grep -E "(clickhouse|postgres|nats|redis)" 2>/dev/null) 2>/dev/null || true; \
		rm -rf $(BACKUP_DIR) 2>/dev/null || true; \
		echo "✅ 重置完成，所有数据已删除"; \
	else \
		echo "❌ 操作已取消"; \
	fi

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
