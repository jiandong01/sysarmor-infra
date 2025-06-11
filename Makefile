# NATS Server Management Makefile
# 用于管理NATS集群的启动、停止、监控等操作

.PHONY: help up down restart status logs clean health monitor install-tools

# Default target
help:
	@echo "NATS Server Management Commands:"
	@echo ""
	@echo "  up              - Start NATS cluster"
	@echo "  down            - Stop NATS cluster"
	@echo "  restart         - Restart NATS cluster"
	@echo "  status          - Show cluster status"
	@echo "  logs            - Show cluster logs"
	@echo "  logs-follow     - Follow cluster logs"
	@echo "  health          - Check cluster health"
	@echo "  monitor         - Open monitoring dashboards"
	@echo "  clean           - Clean up volumes and networks"
	@echo "  install-tools   - Install NATS CLI tools"
	@echo "  test-connection - Test NATS connection"
	@echo "  help            - Show this help message"
	@echo ""
	@echo "Monitoring URLs:"
	@echo "  Node 1: http://localhost:8222"
	@echo "  Node 2: http://localhost:8223"
	@echo "  Node 3: http://localhost:8224"
	@echo "  Surveyor: http://localhost:7777"

# Start NATS cluster
up:
	@echo "Starting NATS cluster..."
	docker compose up -d
	@echo "NATS cluster started successfully!"
	@echo ""
	@echo "Monitoring URLs:"
	@echo "  Node 1: http://localhost:8222"
	@echo "  Node 2: http://localhost:8223"
	@echo "  Node 3: http://localhost:8224"
	@echo "  Surveyor: http://localhost:7777"

# Stop NATS cluster
down:
	@echo "Stopping NATS cluster..."
	docker compose down
	@echo "NATS cluster stopped."

# Restart NATS cluster
restart: down up

# Show cluster status
status:
	@echo "NATS Cluster Status:"
	@echo "===================="
	@docker compose ps
	@echo ""
	@echo "Container Health:"
	@echo "=================="
	@docker ps --filter "name=nats-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Show logs
logs:
	@echo "NATS Cluster Logs:"
	@echo "=================="
	docker compose logs --tail=50

# Follow logs
logs-follow:
	@echo "Following NATS Cluster Logs (Ctrl+C to stop):"
	@echo "=============================================="
	docker compose logs -f

# Check cluster health
health:
	@echo "Checking NATS Cluster Health:"
	@echo "============================="
	@echo "Node 1 Health:"
	@curl -s http://localhost:8222/healthz || echo "Node 1 is not responding"
	@echo ""
	@echo "Node 2 Health:"
	@curl -s http://localhost:8223/healthz || echo "Node 2 is not responding"
	@echo ""
	@echo "Node 3 Health:"
	@curl -s http://localhost:8224/healthz || echo "Node 3 is not responding"
	@echo ""
	@echo "Cluster Routes (Node 1):"
	@curl -s http://localhost:8222/routez | jq '.routes[] | {host: .host, port: .port, did_solicit: .did_solicit}' 2>/dev/null || echo "jq not installed or node not responding"

# Open monitoring dashboards
monitor:
	@echo "Opening NATS monitoring dashboards..."
	@echo "Node 1: http://localhost:8222"
	@echo "Node 2: http://localhost:8223"
	@echo "Node 3: http://localhost:8224"
	@echo "Surveyor: http://localhost:7777"
	@which xdg-open >/dev/null 2>&1 && xdg-open http://localhost:8222 || echo "Please open http://localhost:8222 manually"

# Clean up volumes and networks
clean: down
	@echo "Cleaning up NATS volumes and networks..."
	docker compose down -v
	docker system prune -f --filter "label=com.docker.compose.project=sysarmor-nats-server"
	@echo "Cleanup completed."

# Install NATS CLI tools
install-tools:
	@echo "Installing NATS CLI tools..."
	@which go >/dev/null 2>&1 || (echo "Go is required to install NATS CLI tools" && exit 1)
	go install github.com/nats-io/natscli/nats@latest
	@echo "NATS CLI tools installed successfully!"
	@echo "Usage: nats --help"

# Test NATS connection
test-connection:
	@echo "Testing NATS connection..."
	@which nats >/dev/null 2>&1 || (echo "NATS CLI not installed. Run 'make install-tools' first." && exit 1)
	@echo "Testing Node 1 (localhost:4222):"
	@nats --server=nats://localhost:4222 server ping || echo "Node 1 connection failed"
	@echo "Testing Node 2 (localhost:4223):"
	@nats --server=nats://localhost:4223 server ping || echo "Node 2 connection failed"
	@echo "Testing Node 3 (localhost:4224):"
	@nats --server=nats://localhost:4224 server ping || echo "Node 3 connection failed"
	@echo ""
	@echo "Cluster info:"
	@nats --server=nats://localhost:4222 server info || echo "Failed to get cluster info"

# Development helpers
dev-up: up
	@echo "Development environment started."
	@echo "Waiting for cluster to be ready..."
	@sleep 5
	@make health

dev-down: down
	@echo "Development environment stopped."

# Backup configuration
backup-config:
	@echo "Backing up NATS configuration..."
	@mkdir -p backups
	@tar -czf backups/nats-config-$(shell date +%Y%m%d_%H%M%S).tar.gz configs/
	@echo "Configuration backed up to backups/"

# Show cluster statistics
stats:
	@echo "NATS Cluster Statistics:"
	@echo "======================="
	@echo "Node 1 Stats:"
	@curl -s http://localhost:8222/varz | jq '{connections: .connections, in_msgs: .in_msgs, out_msgs: .out_msgs, in_bytes: .in_bytes, out_bytes: .out_bytes}' 2>/dev/null || echo "Node 1 stats unavailable"
	@echo ""
	@echo "Node 2 Stats:"
	@curl -s http://localhost:8223/varz | jq '{connections: .connections, in_msgs: .in_msgs, out_msgs: .out_msgs, in_bytes: .in_bytes, out_bytes: .out_bytes}' 2>/dev/null || echo "Node 2 stats unavailable"
	@echo ""
	@echo "Node 3 Stats:"
	@curl -s http://localhost:8224/varz | jq '{connections: .connections, in_msgs: .in_msgs, out_msgs: .out_msgs, in_bytes: .in_bytes, out_bytes: .out_bytes}' 2>/dev/null || echo "Node 3 stats unavailable"
