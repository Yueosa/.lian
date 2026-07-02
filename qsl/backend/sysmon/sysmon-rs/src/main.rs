// sysmond — 系统监控守护进程
//
// 分级轮询：1s(CPU/Net) 2s(Mem/Thermal/GPU) 5s(Load) 30s(Disk/Uptime)
// 进程信息按需响应（通过命令管道）

mod config;
mod model;
mod source;
mod process;

use std::{fs, thread, time::{Duration, Instant}};

fn main() {
    let out = config::output_file();
    let cmd = config::cmd_pipe();
    if let Some(parent) = std::path::Path::new(&out).parent() { fs::create_dir_all(parent).ok(); }
    if let Some(parent) = std::path::Path::new(&cmd).parent() { fs::create_dir_all(parent).ok(); }
    let _ = fs::OpenOptions::new().create(true).write(true).open(&cmd);

    let mut cpu = source::cpu::CpuSampler::new();
    let mut net = source::network::NetSampler::new();
    let mut proc_sampler = process::ProcessSampler::new();

    let mut fast   = Instant::now() + Duration::from_secs(1);
    let mut medium = Instant::now() + Duration::from_secs(2);
    let mut slow   = Instant::now() + Duration::from_secs(5);
    let mut glacial = Instant::now() + Duration::from_secs(30);

    // 启动时所有数据采样一次，避免初始值为零
    let mut snapshot = model::Snapshot {
        cpu_percent: cpu.sample(),
        memory: source::memory::sample(),
        network: { let (d,u,i) = net.sample(); model::Network { down_bps: d, up_bps: u, iface: i } },
        thermal: source::thermal::sample(),
        gpu: source::gpu::sample(),
        load: source::load::sample(),
        disk: source::disk::sample(),
        uptime_secs: source::uptime::sample(),
    };

    loop {
        let now = Instant::now();

        // === Fast: 1s (CPU, Net) ===
        if now >= fast {
            snapshot.cpu_percent = libm::round(cpu.sample() * 10.0) / 10.0;
            let (down, up, iface) = net.sample();
            snapshot.network = model::Network { down_bps: down, up_bps: up, iface };
            fast = now + Duration::from_secs(1);
        }

        // === Medium: 2s (Mem, Thermal, GPU) ===
        if now >= medium {
            snapshot.memory = source::memory::sample();
            snapshot.thermal = source::thermal::sample();
            snapshot.gpu = source::gpu::sample();
            medium = now + Duration::from_secs(2);
        }

        // === Slow: 5s (Load) ===
        if now >= slow {
            snapshot.load = source::load::sample();
            slow = now + Duration::from_secs(5);
        }

        // === Glacial: 30s (Disk, Uptime) ===
        if now >= glacial {
            snapshot.disk = source::disk::sample();
            snapshot.uptime_secs = source::uptime::sample();
            glacial = now + Duration::from_secs(30);
        }

        // 每次循环都写输出（实时性要求高的数据每 1s 刷新）
        let json = serde_json::to_string(&snapshot).unwrap_or_default();
        let tmp = format!("{}.tmp", out);
        let _ = fs::write(&tmp, &json);
        let _ = fs::rename(&tmp, &out);

        // 检查命令管道
        if let Ok(s) = fs::read_to_string(&cmd) {
            let s = s.trim().to_string();
            if !s.is_empty() {
                let _ = fs::write(&cmd, "");
                if s.starts_with("process_list") {
                    let procs = proc_sampler.sample();
                    let json = serde_json::to_string(&procs).unwrap_or_default();
                    let _ = fs::write(config::process_file(), &json);
                } else if s.starts_with("process_detail ") {
                    let pid: i32 = s[15..].trim().parse().unwrap_or(0);
                    if pid > 0 {
                        let detail = process::detail::process_detail(pid);
                        let json = serde_json::to_string(&detail).unwrap_or_default();
                        let _ = fs::write(config::detail_file(pid), &json);
                    }
                }
            }
        }

        thread::sleep(Duration::from_millis(200));
    }
}
