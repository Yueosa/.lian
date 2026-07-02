// 系统负载 — 读 /proc/loadavg
use crate::model::Load;
use std::fs;

pub fn sample() -> Load {
    let s = fs::read_to_string("/proc/loadavg").unwrap_or_default();
    let parts: Vec<&str> = s.split_whitespace().collect();
    Load {
        load1:  parts.get(0).and_then(|v| v.parse().ok()).unwrap_or(0.0),
        load5:  parts.get(1).and_then(|v| v.parse().ok()).unwrap_or(0.0),
        load15: parts.get(2).and_then(|v| v.parse().ok()).unwrap_or(0.0),
    }
}
