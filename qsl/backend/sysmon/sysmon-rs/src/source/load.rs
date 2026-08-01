// 系统负载 — /proc/loadavg + /proc/pressure（PSI）
//
// loadavg 保留但不再是主指标：它的绝对值必须除以核心数才有意义，
// 而且把 CPU 抢占和 D 状态（卡在 IO）混成一个数，看到变大也不知道该怪谁。
// PSI 直接给出「过去 10 秒有多少比例的时间被卡住」，且三种资源分开。
use crate::model::Load;
use std::fs;
use std::path::Path;

/// 从 /proc/pressure/<res> 里取某一行（some / full）的 avg10。
/// 文件格式：
///   some avg10=0.95 avg60=0.24 avg300=0.07 total=415948557
///   full avg10=0.00 avg60=0.00 avg300=0.00 total=0
fn psi_avg10(res: &str, kind: &str) -> f64 {
    let path = format!("/proc/pressure/{}", res);
    let s = match fs::read_to_string(&path) {
        Ok(v) => v,
        Err(_) => return 0.0,
    };
    for line in s.lines() {
        if !line.starts_with(kind) {
            continue;
        }
        for tok in line.split_whitespace() {
            if let Some(v) = tok.strip_prefix("avg10=") {
                return v.parse().unwrap_or(0.0);
            }
        }
    }
    0.0
}

pub fn sample() -> Load {
    let s = fs::read_to_string("/proc/loadavg").unwrap_or_default();
    let parts: Vec<&str> = s.split_whitespace().collect();

    // 内核可能没开 CONFIG_PSI，或开了但被 psi=0 关掉
    let psi_available = Path::new("/proc/pressure/cpu").exists();

    Load {
        load1: parts.first().and_then(|v| v.parse().ok()).unwrap_or(0.0),
        load5: parts.get(1).and_then(|v| v.parse().ok()).unwrap_or(0.0),
        load15: parts.get(2).and_then(|v| v.parse().ok()).unwrap_or(0.0),

        // CPU 只有 some 有意义：full 表示所有任务都在等 CPU，
        // 而「在等 CPU」本身就说明还有任务能跑，所以内核恒报 0。
        psi_cpu: if psi_available { psi_avg10("cpu", "some") } else { 0.0 },
        psi_io: if psi_available { psi_avg10("io", "some") } else { 0.0 },
        psi_mem: if psi_available { psi_avg10("memory", "some") } else { 0.0 },
        psi_io_full: if psi_available { psi_avg10("io", "full") } else { 0.0 },
        psi_mem_full: if psi_available { psi_avg10("memory", "full") } else { 0.0 },
        psi_available,
    }
}
