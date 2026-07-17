// 内存 / Swap — 读 /proc/meminfo
use crate::model::Memory;
use std::fs;

pub fn sample() -> Memory {
    let s = match fs::read_to_string("/proc/meminfo") {
        Ok(s) => s,
        Err(_) => return Memory::default(),
    };
    let mut total_kb = 0u64;
    let mut avail_kb = 0u64;
    let mut free_kb = 0u64;
    let mut buffers_kb = 0u64;
    let mut cached_kb = 0u64;
    let mut sreclaim_kb = 0u64;
    let mut swap_total_kb = 0u64;
    let mut swap_free_kb = 0u64;

    for line in s.lines() {
        let parts: Vec<&str> = line.split_whitespace().collect();
        if parts.len() < 2 {
            continue;
        }
        let val: u64 = parts[1].parse().unwrap_or(0);
        match parts[0] {
            "MemTotal:" => total_kb = val,
            "MemAvailable:" => avail_kb = val,
            "MemFree:" => free_kb = val,
            "Buffers:" => buffers_kb = val,
            "Cached:" => cached_kb = val,
            "SReclaimable:" => sreclaim_kb = val,
            "SwapTotal:" => swap_total_kb = val,
            "SwapFree:" => swap_free_kb = val,
            _ => {}
        }
    }

    // 与常见监视器一致：used(压力) = total - available
    let used_kb = total_kb.saturating_sub(avail_kb);
    // cache 可回收段；app ≈ total - free - cache（夹在 [0, used]）
    let cache_kb = buffers_kb.saturating_add(cached_kb).saturating_add(sreclaim_kb);
    let app_kb = total_kb
        .saturating_sub(free_kb)
        .saturating_sub(cache_kb)
        .min(used_kb);

    Memory {
        used_gb: used_kb as f64 / 1048576.0,
        total_gb: total_kb as f64 / 1048576.0,
        percent: if total_kb > 0 {
            used_kb as f64 / total_kb as f64 * 100.0
        } else {
            0.0
        },
        app_gb: app_kb as f64 / 1048576.0,
        cache_gb: cache_kb as f64 / 1048576.0,
        swap_used_gb: swap_total_kb.saturating_sub(swap_free_kb) as f64 / 1048576.0,
        swap_total_gb: swap_total_kb as f64 / 1048576.0,
    }
}
