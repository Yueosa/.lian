// GPU — 调用 nvidia-smi
use crate::model::Gpu;
use std::process::Command;

pub fn sample() -> Gpu {
    let output = match Command::new("nvidia-smi")
        .args(["--query-gpu=temperature.gpu,utilization.gpu,memory.used,memory.total,power.draw",
               "--format=csv,noheader,nounits"])
        .output()
    {
        Ok(o) => o,
        Err(_) => return Gpu { available: false, ..Default::default() },
    };

    let s = String::from_utf8_lossy(&output.stdout);
    let parts: Vec<&str> = s.split(',').map(|p| p.trim()).collect();
    if parts.len() < 5 { return Gpu { available: false, ..Default::default() }; }

    Gpu {
        available: true,
        temp: parts[0].parse().unwrap_or(0.0),
        usage_percent: parts[1].parse().unwrap_or(0.0),
        memory_used_mb: parts[2].parse().unwrap_or(0),
        memory_total_mb: parts[3].parse().unwrap_or(0),
        power_watts: parts[4].parse().unwrap_or(0.0),
    }
}
