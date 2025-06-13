-- 创建SysArmor元数据数据库初始化脚本

-- 启用必要的扩展
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 创建Agent管理表
CREATE TABLE IF NOT EXISTS agents (
    id SERIAL PRIMARY KEY,
    agent_id VARCHAR(255) UNIQUE NOT NULL,
    hostname VARCHAR(255) NOT NULL,
    ip_address INET,
    os_type VARCHAR(50),
    os_version VARCHAR(100),
    collector_version VARCHAR(50),
    last_seen TIMESTAMPTZ DEFAULT NOW(),
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'offline', 'error')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 创建命令管理表
CREATE TABLE IF NOT EXISTS commands (
    id BIGSERIAL PRIMARY KEY,
    command_id UUID DEFAULT uuid_generate_v4(),
    agent_id VARCHAR(255) NOT NULL,
    command_type VARCHAR(100) NOT NULL,
    command_data JSONB NOT NULL,
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'executing', 'completed', 'failed', 'timeout')),
    priority INTEGER DEFAULT 5 CHECK (priority BETWEEN 1 AND 10),
    timeout_seconds INTEGER DEFAULT 30,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    sent_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    result JSONB,
    error_message TEXT,
    retry_count INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 3
);

-- 创建分析规则表
CREATE TABLE IF NOT EXISTS analysis_rules (
    id SERIAL PRIMARY KEY,
    rule_id UUID DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    rule_type VARCHAR(50) NOT NULL CHECK (rule_type IN ('threshold', 'pattern', 'correlation', 'anomaly')),
    rule_config JSONB NOT NULL,
    enabled BOOLEAN DEFAULT true,
    severity VARCHAR(20) DEFAULT 'medium' CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    tags TEXT[],
    created_by VARCHAR(100),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    last_triggered TIMESTAMPTZ
);

-- 创建告警结果表
CREATE TABLE IF NOT EXISTS alerts (
    id BIGSERIAL PRIMARY KEY,
    alert_id UUID DEFAULT uuid_generate_v4(),
    rule_id INTEGER REFERENCES analysis_rules(id),
    agent_id VARCHAR(255),
    alert_type VARCHAR(100) NOT NULL,
    severity VARCHAR(20) NOT NULL CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    title VARCHAR(500) NOT NULL,
    description TEXT,
    event_data JSONB,
    context_data JSONB,
    status VARCHAR(20) DEFAULT 'open' CHECK (status IN ('open', 'investigating', 'resolved', 'false_positive', 'suppressed')),
    assigned_to VARCHAR(100),
    tags TEXT[],
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    resolved_at TIMESTAMPTZ,
    resolution_notes TEXT
);

-- 创建用户管理表
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    user_id UUID DEFAULT uuid_generate_v4(),
    username VARCHAR(100) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    salt VARCHAR(255) NOT NULL,
    role VARCHAR(50) DEFAULT 'analyst' CHECK (role IN ('admin', 'analyst', 'viewer', 'operator')),
    permissions JSONB DEFAULT '{}',
    is_active BOOLEAN DEFAULT true,
    last_login TIMESTAMPTZ,
    failed_login_attempts INTEGER DEFAULT 0,
    locked_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 创建用户会话表
CREATE TABLE IF NOT EXISTS user_sessions (
    id BIGSERIAL PRIMARY KEY,
    session_id UUID DEFAULT uuid_generate_v4(),
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    is_active BOOLEAN DEFAULT true
);

-- 创建系统配置表
CREATE TABLE IF NOT EXISTS system_config (
    key VARCHAR(100) PRIMARY KEY,
    value JSONB NOT NULL,
    description TEXT,
    category VARCHAR(50) DEFAULT 'general',
    is_sensitive BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 创建审计日志表
CREATE TABLE IF NOT EXISTS audit_logs (
    id BIGSERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    action VARCHAR(100) NOT NULL,
    resource_type VARCHAR(50),
    resource_id VARCHAR(255),
    details JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 创建通知配置表
CREATE TABLE IF NOT EXISTS notification_configs (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    type VARCHAR(50) NOT NULL CHECK (type IN ('email', 'webhook', 'slack', 'teams')),
    config JSONB NOT NULL,
    enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 创建通知历史表
CREATE TABLE IF NOT EXISTS notification_history (
    id BIGSERIAL PRIMARY KEY,
    config_id INTEGER REFERENCES notification_configs(id),
    alert_id BIGINT REFERENCES alerts(id),
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'failed', 'retry')),
    message TEXT,
    error_message TEXT,
    sent_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 创建索引以提高查询性能
CREATE INDEX IF NOT EXISTS idx_agents_agent_id ON agents(agent_id);
CREATE INDEX IF NOT EXISTS idx_agents_status ON agents(status);
CREATE INDEX IF NOT EXISTS idx_agents_last_seen ON agents(last_seen);

CREATE INDEX IF NOT EXISTS idx_commands_agent_id ON commands(agent_id);
CREATE INDEX IF NOT EXISTS idx_commands_status ON commands(status);
CREATE INDEX IF NOT EXISTS idx_commands_created_at ON commands(created_at);
CREATE INDEX IF NOT EXISTS idx_commands_command_type ON commands(command_type);

CREATE INDEX IF NOT EXISTS idx_alerts_agent_id ON alerts(agent_id);
CREATE INDEX IF NOT EXISTS idx_alerts_status ON alerts(status);
CREATE INDEX IF NOT EXISTS idx_alerts_severity ON alerts(severity);
CREATE INDEX IF NOT EXISTS idx_alerts_created_at ON alerts(created_at);
CREATE INDEX IF NOT EXISTS idx_alerts_rule_id ON alerts(rule_id);

CREATE INDEX IF NOT EXISTS idx_analysis_rules_enabled ON analysis_rules(enabled);
CREATE INDEX IF NOT EXISTS idx_analysis_rules_rule_type ON analysis_rules(rule_type);

CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_is_active ON users(is_active);

CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id ON user_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_sessions_expires_at ON user_sessions(expires_at);

CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs(created_at);

-- 创建触发器函数用于自动更新updated_at字段
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- 为需要的表创建触发器
CREATE TRIGGER update_agents_updated_at BEFORE UPDATE ON agents
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_analysis_rules_updated_at BEFORE UPDATE ON analysis_rules
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_alerts_updated_at BEFORE UPDATE ON alerts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_system_config_updated_at BEFORE UPDATE ON system_config
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_notification_configs_updated_at BEFORE UPDATE ON notification_configs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 插入默认系统配置
INSERT INTO system_config (key, value, description, category) VALUES
('system.name', '"SysArmor EDR/XDR Platform"', 'System name', 'general'),
('system.version', '"1.0.0"', 'System version', 'general'),
('data.retention_days', '90', 'Data retention period in days', 'data'),
('alerts.max_per_hour', '1000', 'Maximum alerts per hour', 'alerts'),
('auth.session_timeout', '3600', 'Session timeout in seconds', 'auth'),
('auth.max_failed_attempts', '5', 'Maximum failed login attempts', 'auth'),
('auth.lockout_duration', '1800', 'Account lockout duration in seconds', 'auth')
ON CONFLICT (key) DO NOTHING;

-- 创建默认管理员用户 (密码: admin123)
INSERT INTO users (username, email, password_hash, salt, role) VALUES
('admin', 'admin@sysarmor.local', 
 crypt('admin123', gen_salt('bf', 12)), 
 gen_salt('bf', 12), 
 'admin')
ON CONFLICT (username) DO NOTHING;

-- 插入示例数据
INSERT INTO agents (agent_id, hostname, ip_address, os_type, os_version, collector_version) VALUES
('agent-001', 'web-server-01', '192.168.1.100', 'Linux', 'Ubuntu 22.04', '1.0.0'),
('agent-002', 'db-server-01', '192.168.1.101', 'Linux', 'CentOS 8', '1.0.0'),
('agent-003', 'win-workstation-01', '192.168.1.102', 'Windows', 'Windows 11', '1.0.0')
ON CONFLICT (agent_id) DO NOTHING;

-- 插入示例分析规则
INSERT INTO analysis_rules (name, description, rule_type, rule_config, severity) VALUES
('High CPU Usage', 'Detect when CPU usage exceeds 90%', 'threshold', 
 '{"metric": "cpu_usage", "threshold": 90, "duration": "5m"}', 'high'),
('Suspicious File Access', 'Detect access to sensitive files', 'pattern',
 '{"patterns": ["/etc/passwd", "/etc/shadow", "/etc/sudoers"], "action": "read"}', 'medium'),
('Multiple Failed Logins', 'Detect brute force login attempts', 'correlation',
 '{"events": ["login_failed"], "count": 5, "timeframe": "1m"}', 'high')
ON CONFLICT DO NOTHING;

-- 创建视图用于常用查询
CREATE OR REPLACE VIEW active_agents AS
SELECT 
    agent_id,
    hostname,
    ip_address,
    os_type,
    os_version,
    collector_version,
    last_seen,
    EXTRACT(EPOCH FROM (NOW() - last_seen)) AS seconds_since_last_seen
FROM agents 
WHERE status = 'active' 
  AND last_seen > NOW() - INTERVAL '1 hour';

CREATE OR REPLACE VIEW recent_alerts AS
SELECT 
    a.alert_id,
    a.title,
    a.severity,
    a.status,
    a.agent_id,
    ag.hostname,
    r.name as rule_name,
    a.created_at
FROM alerts a
LEFT JOIN agents ag ON a.agent_id = ag.agent_id
LEFT JOIN analysis_rules r ON a.rule_id = r.id
WHERE a.created_at > NOW() - INTERVAL '24 hours'
ORDER BY a.created_at DESC;

-- 创建函数用于清理过期数据
CREATE OR REPLACE FUNCTION cleanup_expired_data()
RETURNS void AS $$
DECLARE
    retention_days INTEGER;
BEGIN
    -- 获取数据保留天数
    SELECT (value::text)::integer INTO retention_days 
    FROM system_config 
    WHERE key = 'data.retention_days';
    
    IF retention_days IS NULL THEN
        retention_days := 90;
    END IF;
    
    -- 清理过期的用户会话
    DELETE FROM user_sessions 
    WHERE expires_at < NOW();
    
    -- 清理过期的审计日志
    DELETE FROM audit_logs 
    WHERE created_at < NOW() - INTERVAL '1 day' * retention_days;
    
    -- 清理过期的通知历史
    DELETE FROM notification_history 
    WHERE created_at < NOW() - INTERVAL '1 day' * retention_days;
    
    RAISE NOTICE 'Expired data cleanup completed for % days retention', retention_days;
END;
$$ LANGUAGE plpgsql;
