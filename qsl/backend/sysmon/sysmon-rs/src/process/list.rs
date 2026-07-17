// 进程列表 — 遍历 /proc/<pid>/stat 获取 CPU% + RSS
use std::collections::HashMap;
use std::fs;

use serde::Serialize;

#[derive(Debug, Clone, Serialize)]
pub struct ProcessInfo {
    pub pid: i32,
    pub uid: u32,
    pub name: String,
    pub cpu_percent: f64,
    pub memory_kb: u64,
    pub memory_percent: f64,
    pub cmdline: String,
}

pub struct ProcessSampler {
    prev_ticks: HashMap<i32, u64>,
    prev_total_ticks: u64,
    first_sample: bool,
    page_size_kb: u64,
    mem_total_kb: u64,
}

impl ProcessSampler {
    pub fn new() -> Self {
        let page_size_kb = unsafe { libc::sysconf(libc::_SC_PAGESIZE) as u64 / 1024 };
        let mem_total_kb = total_mem_kb();
        Self {
            prev_ticks: HashMap::new(),
            prev_total_ticks: 0,
            first_sample: true,
            page_size_kb,
            mem_total_kb,
        }
    }

    pub fn sample(&mut self) -> Vec<ProcessInfo> {
        let (total_ticks, current_ticks) = read_all_procs(self.page_size_kb);
        let mut processes: Vec<ProcessInfo> = current_ticks
            .iter()
            .map(|(pid, (ticks, info))| {
                let cpu = if !self.first_sample && total_ticks > self.prev_total_ticks {
                    let diff = total_ticks - self.prev_total_ticks;
                    let prev = self.prev_ticks.get(pid).copied().unwrap_or(*ticks);
                    if *ticks > prev {
                        (*ticks - prev) as f64 / diff as f64 * 100.0
                    } else {
                        0.0
                    }
                } else {
                    0.0
                };
                let mem_pct = if self.mem_total_kb > 0 {
                    info.memory_kb as f64 / self.mem_total_kb as f64 * 100.0
                } else {
                    0.0
                };
                ProcessInfo {
                    pid: info.pid,
                    uid: info.uid,
                    name: info.name.clone(),
                    cpu_percent: cpu,
                    memory_kb: info.memory_kb,
                    memory_percent: mem_pct,
                    cmdline: info.cmdline.clone(),
                }
            })
            .collect();

        processes.sort_by(|a, b| {
            b.cpu_percent
                .partial_cmp(&a.cpu_percent)
                .unwrap_or(std::cmp::Ordering::Equal)
        });
        processes.truncate(50);
        self.prev_ticks = current_ticks
            .iter()
            .map(|(pid, (ticks, _))| (*pid, *ticks))
            .collect();
        self.prev_total_ticks = total_ticks;
        self.first_sample = false;
        processes
    }
}

struct RawInfo {
    pid: i32,
    uid: u32,
    name: String,
    memory_kb: u64,
    cmdline: String,
}

fn read_all_procs(page_size_kb: u64) -> (u64, HashMap<i32, (u64, RawInfo)>) {
    let total_ticks = read_total_cpu_ticks();
    let mut map = HashMap::new();

    let Ok(dir) = fs::read_dir("/proc") else {
        return (total_ticks, map);
    };
    for entry in dir.flatten() {
        let name = entry.file_name();
        let name_str = name.to_string_lossy();
        let pid: i32 = match name_str.parse() {
            Ok(p) => p,
            Err(_) => continue,
        };

        let (ticks, info) = match read_proc_stat(pid, page_size_kb) {
            Some(r) => r,
            None => continue,
        };
        map.insert(pid, (ticks, info));
    }
    (total_ticks, map)
}

fn read_proc_stat(pid: i32, page_size_kb: u64) -> Option<(u64, RawInfo)> {
    let path = format!("/proc/{}/stat", pid);
    let s = fs::read_to_string(&path).ok()?;

    let open = s.find('(')?;
    let close = s.rfind(')')?;
    let name = s[open + 1..close].to_string();

    // 读 UID from /proc/<pid>/status (need it for user/system filtering)
    let uid = read_uid(pid).unwrap_or(0);

    // 读 cmdline
    let cmdline = read_cmdline(pid).unwrap_or_else(|| name.clone());

    let rest = &s[close + 2..];
    let fields: Vec<&str> = rest.split_whitespace().collect();
    // stat 字段: state(0) ppid(1) ... utime(11) stime(12) ... rss(21)
    let utime: u64 = fields.get(11)?.parse().ok()?;
    let stime: u64 = fields.get(12)?.parse().ok()?;
    let rss_pages: u64 = fields.get(21)?.parse().ok()?;

    Some((
        utime + stime,
        RawInfo {
            pid,
            uid,
            name,
            memory_kb: rss_pages * page_size_kb,
            cmdline,
        },
    ))
}

fn read_uid(pid: i32) -> Option<u32> {
    let s = fs::read_to_string(format!("/proc/{}/status", pid)).ok()?;
    for line in s.lines() {
        if line.starts_with("Uid:") {
            return line.split_whitespace().nth(1)?.parse().ok();
        }
    }
    None
}

fn read_cmdline(pid: i32) -> Option<String> {
    let data = fs::read(format!("/proc/{}/cmdline", pid)).ok()?;
    let first = data.split(|&b| b == 0).next().unwrap_or(&[]);
    if first.is_empty() {
        None
    } else {
        Some(String::from_utf8_lossy(first).to_string())
    }
}

fn read_total_cpu_ticks() -> u64 {
    let s = fs::read_to_string("/proc/stat").unwrap_or_default();
    for line in s.lines() {
        if line.starts_with("cpu ") {
            return line
                .split_whitespace()
                .skip(1)
                .filter_map(|v| v.parse::<u64>().ok())
                .sum();
        }
    }
    1 // 防止除以 0
}

fn total_mem_kb() -> u64 {
    let s = fs::read_to_string("/proc/meminfo").unwrap_or_default();
    for line in s.lines() {
        if line.starts_with("MemTotal:") {
            return line
                .split_whitespace()
                .nth(1)
                .and_then(|v| v.parse().ok())
                .unwrap_or(1);
        }
    }
    1
}
