// 运行时间 — 读 /proc/uptime
use std::fs;

pub fn sample() -> u64 {
    let s = fs::read_to_string("/proc/uptime").unwrap_or_default();
    s.split_whitespace()
        .next()
        .and_then(|v| v.parse::<f64>().ok())
        .map(|t| t as u64)
        .unwrap_or(0)
}
