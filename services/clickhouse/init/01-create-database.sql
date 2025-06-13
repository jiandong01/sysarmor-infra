-- 创建SysArmor事件数据库
CREATE DATABASE IF NOT EXISTS sysarmor_events;

-- 使用数据库
USE sysarmor_events;

-- 创建主事件表，支持冷热分离
CREATE TABLE IF NOT EXISTS events (
    id UInt64,
    timestamp DateTime64(6, 'Asia/Shanghai'),
    agent_id String,
    hostname String,
    event_type String,
    source_type String CODEC(LZ4),
    raw_data String CODEC(ZSTD(1)),
    processed_at DateTime64(6, 'Asia/Shanghai') DEFAULT now64()
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (timestamp, agent_id, event_type)
SETTINGS 
    index_granularity = 8192,
    storage_policy = 'hot_cold_policy';

-- 创建物化视图用于实时统计
CREATE MATERIALIZED VIEW IF NOT EXISTS events_stats_mv
ENGINE = SummingMergeTree()
PARTITION BY toYYYYMMDD(hour)
ORDER BY (agent_id, event_type, hour)
AS SELECT
    agent_id,
    event_type,
    source_type,
    toStartOfHour(timestamp) as hour,
    count() as event_count,
    uniq(agent_id) as unique_agents
FROM events
GROUP BY agent_id, event_type, source_type, hour;

-- 创建每日统计表
CREATE MATERIALIZED VIEW IF NOT EXISTS events_daily_stats_mv
ENGINE = SummingMergeTree()
PARTITION BY toYYYYMM(date)
ORDER BY (agent_id, event_type, date)
AS SELECT
    agent_id,
    event_type,
    source_type,
    toDate(timestamp) as date,
    count() as daily_count,
    uniq(agent_id) as unique_agents,
    min(timestamp) as first_event,
    max(timestamp) as last_event
FROM events
GROUP BY agent_id, event_type, source_type, date;

-- 创建Agent状态表
CREATE TABLE IF NOT EXISTS agent_status (
    agent_id String,
    hostname String,
    ip_address String,
    os_type String,
    os_version String,
    collector_version String,
    last_seen DateTime64(6, 'Asia/Shanghai'),
    status String DEFAULT 'active',
    created_at DateTime64(6, 'Asia/Shanghai') DEFAULT now64(),
    updated_at DateTime64(6, 'Asia/Shanghai') DEFAULT now64()
) ENGINE = ReplacingMergeTree(updated_at)
ORDER BY agent_id;

-- 创建性能监控表
CREATE TABLE IF NOT EXISTS performance_metrics (
    timestamp DateTime64(6, 'Asia/Shanghai'),
    agent_id String,
    metric_name String,
    metric_value Float64,
    tags Map(String, String)
) ENGINE = MergeTree()
PARTITION BY toYYYYMMDD(timestamp)
ORDER BY (timestamp, agent_id, metric_name)
SETTINGS index_granularity = 8192;

-- 创建索引以提高查询性能
-- 为events表创建跳数索引
ALTER TABLE events ADD INDEX idx_agent_id agent_id TYPE bloom_filter GRANULARITY 1;
ALTER TABLE events ADD INDEX idx_event_type event_type TYPE bloom_filter GRANULARITY 1;
ALTER TABLE events ADD INDEX idx_source_type source_type TYPE bloom_filter GRANULARITY 1;

-- 插入一些示例数据用于测试
INSERT INTO events (id, timestamp, agent_id, hostname, event_type, source_type, raw_data) VALUES
(1, now64(), 'agent-001', 'web-server-01', 'file_access', 'sysdig', '{"file": "/etc/passwd", "process": "cat", "pid": 1234}'),
(2, now64(), 'agent-001', 'web-server-01', 'network_connection', 'sysdig', '{"src_ip": "192.168.1.100", "dst_ip": "8.8.8.8", "port": 53}'),
(3, now64(), 'agent-002', 'db-server-01', 'process_start', 'osquery', '{"name": "mysqld", "pid": 5678, "cmdline": "/usr/sbin/mysqld"}');

-- 插入Agent状态数据
INSERT INTO agent_status (agent_id, hostname, ip_address, os_type, os_version, collector_version) VALUES
('agent-001', 'web-server-01', '192.168.1.100', 'Linux', 'Ubuntu 22.04', '1.0.0'),
('agent-002', 'db-server-01', '192.168.1.101', 'Linux', 'CentOS 8', '1.0.0');
