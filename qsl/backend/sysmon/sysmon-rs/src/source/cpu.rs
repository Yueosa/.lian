// CPU 使用率 — 两次读 /proc/stat 取差值
use std::fs;

/// /proc/stat 第一行 "cpu  user nice system idle iowait irq softirq steal guest guest_nice"
pub struct CpuSampler {
    prev_total: u64,
    prev_work: u64,
}

impl CpuSampler {
    pub fn new() -> Self {
        let (_work, total) = read_stat().unwrap_or((0, 1));
        Self { prev_total: total, prev_work: 0 }
    }

    pub fn sample(&mut self) -> f64 {
        let (work, total) = read_stat().unwrap_or((self.prev_work, self.prev_total));
        let total_diff = total.saturating_sub(self.prev_total);
        let work_diff = work.saturating_sub(self.prev_work);
        self.prev_total = total;
        self.prev_work = work;
        if total_diff == 0 { return 0.0; }
        work_diff as f64 / total_diff as f64 * 100.0
    }
}

fn read_stat() -> Option<(u64, u64)> {
    let s = fs::read_to_string("/proc/stat").ok()?;
    let line = s.lines().next()?;
    if !line.starts_with("cpu ") { return None; }
    let parts: Vec<&str> = line.split_whitespace().skip(1).collect();
    let nums: Vec<u64> = parts.iter().filter_map(|p| p.parse().ok()).collect();
    if nums.len() < 10 { return None; }
    let idle = nums[3] + nums[4]; // idle + iowait
    let work = nums[0] + nums[1] + nums[2] + nums[5] + nums[6] + nums[7]; // user+nice+system+irq+softirq+steal
    Some((work, idle + work))
}
