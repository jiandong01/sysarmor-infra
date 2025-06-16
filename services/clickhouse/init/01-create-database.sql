-- SysArmor ClickHouse 数据库初始化脚本（优化版）

-- 创建数据库
CREATE DATABASE IF NOT EXISTS sysarmor_events;

-- 使用数据库
USE sysarmor_events;

-- 创建优化的主事件表（按天分区，优化排序键）
CREATE TABLE IF NOT EXISTS events (
    id UInt64,
    timestamp DateTime64(6, 'Asia/Shanghai'),
    agent_id String,
    event_type String,
    source_type String,
    raw_data String,
    processed_at DateTime64(6, 'Asia/Shanghai') DEFAULT now64(),
    INDEX idx_agent_id agent_id TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_event_type event_type TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_source_type source_type TYPE bloom_filter(0.01) GRANULARITY 1
) ENGINE = MergeTree()
PARTITION BY toYYYYMMDD(timestamp)  -- 按天分区，提升查询性能
ORDER BY (agent_id, timestamp, event_type)  -- 优化排序键
SETTINGS index_granularity = 8192;

-- 创建Buffer表加速写入
CREATE TABLE IF NOT EXISTS events_buffer AS events
ENGINE = Buffer(
    sysarmor_events, events,
    16,       -- num_layers
    10,       -- min_time (seconds)
    100,      -- max_time (seconds)
    100000,   -- min_rows
    1000000,  -- max_rows
    10000000, -- min_bytes
    100000000 -- max_bytes (100MB)
);

-- 创建结构化事件表（用于复杂分析）
CREATE TABLE IF NOT EXISTS events_structured (
    id UInt64,
    timestamp DateTime64(6, 'Asia/Shanghai'),
    agent_id String,
    event_type String,
    source_type String,
    
    -- 进程信息
    proc_pid UInt32,
    proc_name String,
    proc_cmdline String,
    proc_user String,
    proc_ppid UInt32,
    proc_pname String,
    
    -- 文件信息
    file_path String,
    file_operation String,
    file_permissions String,
    
    -- 网络信息
    net_src_ip IPv4,
    net_dst_ip IPv4,
    net_src_port UInt16,
    net_dst_port UInt16,
    net_protocol String,
    
    -- 系统调用信息
    syscall_args String,
    syscall_result String,
    
    -- 原始数据（用于调试和完整性）
    raw_data String,
    processed_at DateTime64(6, 'Asia/Shanghai') DEFAULT now64()
    
) ENGINE = MergeTree()
PARTITION BY toYYYYMMDD(timestamp)
ORDER BY (agent_id, timestamp, event_type, proc_pid)
SETTINGS index_granularity = 8192;

-- 创建 Agent 状态表
CREATE TABLE IF NOT EXISTS agent_status (
    agent_id String,
    hostname String,
    ip_address String,
    version String,
    status String,
    last_seen DateTime64(6, 'Asia/Shanghai'),
    first_seen DateTime64(6, 'Asia/Shanghai'),
    event_count UInt64,
    plugins Array(String)
) ENGINE = ReplacingMergeTree(last_seen)
ORDER BY agent_id
SETTINGS index_granularity = 8192;

-- 创建实时统计物化视图
CREATE MATERIALIZED VIEW IF NOT EXISTS events_stats_realtime
ENGINE = SummingMergeTree()
PARTITION BY toYYYYMMDD(minute)
ORDER BY (agent_id, event_type, source_type, minute)
AS SELECT
    agent_id,
    event_type,
    source_type,
    toStartOfMinute(timestamp) as minute,
    count() as event_count,
    uniq(agent_id) as unique_agents
FROM events_buffer
GROUP BY agent_id, event_type, source_type, minute;

-- 创建小时级别聚合表
CREATE MATERIALIZED VIEW IF NOT EXISTS events_hourly_summary
ENGINE = AggregatingMergeTree()
PARTITION BY toYYYYMMDD(hour)
ORDER BY (agent_id, event_type, hour)
AS SELECT
    agent_id,
    event_type,
    toStartOfHour(timestamp) as hour,
    count() as total_events,
    uniqState(event_type) as unique_event_types_state,
    minState(timestamp) as first_event_time,
    maxState(timestamp) as last_event_time
FROM events_buffer
GROUP BY agent_id, event_type, hour;

-- 创建进程活动统计视图
CREATE MATERIALIZED VIEW IF NOT EXISTS process_activity_stats
ENGINE = SummingMergeTree()
PARTITION BY toYYYYMMDD(hour)
ORDER BY (agent_id, proc_name, hour)
AS SELECT
    agent_id,
    proc_name,
    toStartOfHour(timestamp) as hour,
    count() as event_count,
    uniq(proc_pid) as unique_pids,
    uniq(file_path) as unique_files,
    uniq(event_type) as unique_event_types
FROM events_structured
WHERE proc_name != ''
GROUP BY agent_id, proc_name, hour;

-- 创建文件访问统计视图
CREATE MATERIALIZED VIEW IF NOT EXISTS file_access_stats
ENGINE = SummingMergeTree()
PARTITION BY toYYYYMMDD(hour)
ORDER BY (agent_id, file_path, hour)
AS SELECT
    agent_id,
    file_path,
    file_operation,
    toStartOfHour(timestamp) as hour,
    count() as access_count,
    uniq(proc_name) as unique_processes,
    uniq(proc_pid) as unique_pids
FROM events_structured
WHERE file_path != ''
GROUP BY agent_id, file_path, file_operation, hour;

-- 创建网络活动统计视图
CREATE MATERIALIZED VIEW IF NOT EXISTS network_activity_stats
ENGINE = SummingMergeTree()
PARTITION BY toYYYYMMDD(hour)
ORDER BY (agent_id, net_dst_ip, hour)
AS SELECT
    agent_id,
    net_src_ip,
    net_dst_ip,
    net_dst_port,
    net_protocol,
    toStartOfHour(timestamp) as hour,
    count() as connection_count,
    uniq(proc_name) as unique_processes
FROM events_structured
WHERE net_dst_ip != toIPv4('0.0.0.0')
GROUP BY agent_id, net_src_ip, net_dst_ip, net_dst_port, net_protocol, hour;

-- 创建系统性能指标表
CREATE TABLE IF NOT EXISTS system_metrics (
    timestamp DateTime64(6, 'Asia/Shanghai'),
    agent_id String,
    metric_name String,
    metric_value Float64,
    tags Map(String, String)
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(timestamp)
ORDER BY (timestamp, agent_id, metric_name)
SETTINGS index_granularity = 8192;

-- 创建告警规则表
CREATE TABLE IF NOT EXISTS alert_rules (
    id UInt64,
    name String,
    description String,
    query String,
    threshold Float64,
    severity Enum8('low' = 1, 'medium' = 2, 'high' = 3, 'critical' = 4),
    enabled UInt8 DEFAULT 1,
    created_at DateTime64(6, 'Asia/Shanghai') DEFAULT now64(),
    updated_at DateTime64(6, 'Asia/Shanghai') DEFAULT now64()
) ENGINE = MergeTree()
ORDER BY id
SETTINGS index_granularity = 8192;

-- 创建告警历史表
CREATE TABLE IF NOT EXISTS alert_history (
    id UInt64,
    rule_id UInt64,
    agent_id String,
    alert_time DateTime64(6, 'Asia/Shanghai'),
    severity Enum8('low' = 1, 'medium' = 2, 'high' = 3, 'critical' = 4),
    message String,
    details String,
    resolved UInt8 DEFAULT 0,
    resolved_at DateTime64(6, 'Asia/Shanghai')
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(alert_time)
ORDER BY (alert_time, rule_id, agent_id)
SETTINGS index_granularity = 8192;

-- 插入一些示例告警规则
INSERT INTO alert_rules (id, name, description, query, threshold, severity) VALUES
(1, '高频文件访问', '检测异常高频的文件访问行为', 'SELECT count() FROM events WHERE event_type IN (''read'', ''write'', ''openat'') AND timestamp > now() - INTERVAL 5 MINUTE GROUP BY agent_id, proc_name HAVING count() > 1000', 1000, 'medium'),
(2, '可疑网络连接', '检测到未知IP的网络连接', 'SELECT count() FROM events_structured WHERE net_dst_ip NOT IN (''127.0.0.1'', ''0.0.0.0'') AND timestamp > now() - INTERVAL 1 MINUTE', 0, 'high'),
(3, '进程异常退出', '检测进程异常退出事件', 'SELECT count() FROM events WHERE event_type = ''exit'' AND timestamp > now() - INTERVAL 1 MINUTE', 0, 'low');

-- 创建用于监控的系统视图
CREATE VIEW IF NOT EXISTS v_system_overview AS
SELECT
    'Total Events' as metric,
    count() as value,
    'events' as unit
FROM events
UNION ALL
SELECT
    'Events Last Hour' as metric,
    count() as value,
    'events' as unit
FROM events
WHERE timestamp > now() - INTERVAL 1 HOUR
UNION ALL
SELECT
    'Active Agents' as metric,
    uniq(agent_id) as value,
    'agents' as unit
FROM events
WHERE timestamp > now() - INTERVAL 1 HOUR
UNION ALL
SELECT
    'Event Types' as metric,
    uniq(event_type) as value,
    'types' as unit
FROM events;

-- 创建性能监控视图
CREATE VIEW IF NOT EXISTS v_performance_metrics AS
SELECT
    toStartOfMinute(timestamp) as time_window,
    count() as events_per_minute,
    uniq(agent_id) as active_agents,
    uniq(event_type) as event_types,
    avg(length(raw_data)) as avg_event_size
FROM events
WHERE timestamp > now() - INTERVAL 1 HOUR
GROUP BY time_window
ORDER BY time_window DESC;

-- 创建 Agent 健康状态视图
CREATE VIEW IF NOT EXISTS v_agent_health AS
SELECT
    agent_id,
    count() as total_events,
    uniq(event_type) as event_types,
    min(timestamp) as first_event,
    max(timestamp) as last_event,
    dateDiff('second', min(timestamp), max(timestamp)) as active_duration_seconds,
    count() / dateDiff('second', min(timestamp), max(timestamp)) as events_per_second
FROM events
WHERE timestamp > now() - INTERVAL 24 HOUR
GROUP BY agent_id
HAVING dateDiff('second', min(timestamp), max(timestamp)) > 0
ORDER BY total_events DESC;

-- 创建数据质量检查视图
CREATE VIEW IF NOT EXISTS v_data_quality AS
SELECT
    'Total Events' as check_name,
    count() as value,
    CASE WHEN count() > 0 THEN 'PASS' ELSE 'FAIL' END as status
FROM events
UNION ALL
SELECT
    'Events with Raw Data' as check_name,
    count() as value,
    CASE WHEN count() = (SELECT count() FROM events) THEN 'PASS' ELSE 'FAIL' END as status
FROM events
WHERE length(raw_data) > 0
UNION ALL
SELECT
    'Events with Agent ID' as check_name,
    count() as value,
    CASE WHEN count() = (SELECT count() FROM events) THEN 'PASS' ELSE 'FAIL' END as status
FROM events
WHERE agent_id != ''
UNION ALL
SELECT
    'Recent Events (Last Hour)' as check_name,
    count() as value,
    CASE WHEN count() > 0 THEN 'PASS' ELSE 'WARN' END as status
FROM events
WHERE timestamp > now() - INTERVAL 1 HOUR;

-- 授权
GRANT ALL ON sysarmor_events.* TO sysarmor;

-- 完成初始化
SELECT 'SysArmor ClickHouse database initialized successfully with optimizations!' as status;
