// 进程详情 — /proc/<pid>/smaps_rollup + /proc/<pid>/status
use serde::Serialize;
use std::fs;

#[derive(Debug, Clone, Serialize, Default)]
pub struct ProcessDetail {
    pub pid: i32,
    pub name: String,
    pub cmdline: String,
    pub state: String,
    pub threads: u32,
    pub rss_kb: u64,
    pub pss_kb: u64,
    pub uss_kb: u64,
    pub swap_kb: u64,
    pub private_dirty_kb: u64,
    pub private_clean_kb: u64,
}

pub fn process_detail(pid: i32) -> ProcessDetail {
    let mut d = ProcessDetail { pid, ..Default::default() };

    if let Ok(s) = fs::read_to_string(format!("/proc/{}/status", pid)) {
        for line in s.lines() {
            let parts: Vec<&str> = line.splitn(2, ':').collect();
            let val = parts.get(1).map(|v| v.trim()).unwrap_or("");
            match parts.get(0).map(|k| k.trim()) {
                Some("Name") => d.name = val.to_string(),
                Some("State") => d.state = val.split_whitespace().next().unwrap_or("").to_string(),
                Some("Threads") => d.threads = val.parse().unwrap_or(0),
                Some("VmRSS") => d.rss_kb = val.split_whitespace().next().and_then(|v| v.parse().ok()).unwrap_or(0),
                _ => {}
            }
        }
    }

    if let Ok(s) = fs::read_to_string(format!("/proc/{}/cmdline", pid)) {
        d.cmdline = s.replace('\0', " ").trim().to_string();
    }

    if let Ok(s) = fs::read_to_string(format!("/proc/{}/smaps_rollup", pid)) {
        for line in s.lines() {
            let parts: Vec<&str> = line.splitn(2, ':').collect();
            let val: u64 = parts.get(1)
                .and_then(|v| v.trim().split_whitespace().next())
                .and_then(|v| v.parse().ok()).unwrap_or(0);
            match parts.get(0).map(|k| k.trim()) {
                Some("Pss") => d.pss_kb = val,
                Some("Private_Clean") => d.private_clean_kb = val,
                Some("Private_Dirty") => d.private_dirty_kb = val,
                Some("Swap") => d.swap_kb = val,
                _ => {}
            }
        }
        d.uss_kb = d.private_clean_kb + d.private_dirty_kb;
    }

    d
}
