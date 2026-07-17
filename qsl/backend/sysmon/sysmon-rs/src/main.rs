// sysmond — 系统监控守护进程
//
// 分级轮询：1s(CPU/Net) 2s(Mem/Thermal/GPU) 5s(Load) 30s(Disk/Uptime)
// 进程信息按需响应（通过命令管道）

mod config;
mod model;
mod process;
mod source;

use serde::Serialize;
use std::{
    fs, thread,
    time::{Duration, Instant},
};

fn main() {
    let out = config::output_file();
    let cmd = config::cmd_pipe();
    if let Some(parent) = std::path::Path::new(&out).parent() {
        fs::create_dir_all(parent).ok();
    }
    if let Some(parent) = std::path::Path::new(&cmd).parent() {
        fs::create_dir_all(parent).ok();
    }
    let _ = fs::OpenOptions::new().create(true).write(true).open(&cmd);

    let mut cpu = source::cpu::CpuSampler::new();
    let mut net = source::network::NetSampler::new();
    let mut proc_sampler = process::ProcessSampler::new();

    let mut fast = Instant::now() + Duration::from_secs(1);
    let mut medium = Instant::now() + Duration::from_secs(2);
    let mut slow = Instant::now() + Duration::from_secs(5);
    let mut glacial = Instant::now() + Duration::from_secs(30);

    // 启动时所有数据采样一次，避免初始值为零
    let mut snapshot = model::Snapshot {
        cpu_percent: cpu.sample(),
        memory: source::memory::sample(),
        network: {
            let (d, u, i) = net.sample();
            model::Network {
                down_bps: d,
                up_bps: u,
                iface: i,
            }
        },
        thermal: source::thermal::sample(),
        gpu: source::gpu::sample(),
        load: source::load::sample(),
        disk: source::disk::sample(),
        uptime_secs: source::uptime::sample(),
    };

    let mut snapshot_dirty = true;

    loop {
        let now = Instant::now();

        // === Fast: 1s (CPU, Net) ===
        if now >= fast {
            snapshot.cpu_percent = libm::round(cpu.sample() * 10.0) / 10.0;
            let (down, up, iface) = net.sample();
            snapshot.network = model::Network {
                down_bps: down,
                up_bps: up,
                iface,
            };
            fast = now + Duration::from_secs(1);
            snapshot_dirty = true;
        }

        // === Medium: 2s (Mem, Thermal, GPU) ===
        if now >= medium {
            snapshot.memory = source::memory::sample();
            snapshot.thermal = source::thermal::sample();
            snapshot.gpu = source::gpu::sample();
            medium = now + Duration::from_secs(2);
            snapshot_dirty = true;
        }

        // === Slow: 5s (Load) ===
        if now >= slow {
            snapshot.load = source::load::sample();
            slow = now + Duration::from_secs(5);
            snapshot_dirty = true;
        }

        // === Glacial: 30s (Disk, Uptime) ===
        if now >= glacial {
            snapshot.disk = source::disk::sample();
            snapshot.uptime_secs = source::uptime::sample();
            glacial = now + Duration::from_secs(30);
            snapshot_dirty = true;
        }

        if snapshot_dirty {
            if let Err(err) = write_json_atomic(&out, &snapshot) {
                eprintln!("sysmond: 写入快照失败: {}", err);
            }
            snapshot_dirty = false;
        }

        // 检查命令管道
        if let Some(s) = read_command(&cmd) {
            if s.starts_with("process_list") {
                let procs = proc_sampler.sample();
                if let Err(err) = write_json_atomic(&config::process_file(), &procs) {
                    eprintln!("sysmond: 写入进程列表失败: {}", err);
                }
            } else if s.starts_with("process_detail ") {
                let pid: i32 = s[15..].trim().parse().unwrap_or(0);
                if pid > 0 {
                    let detail = process::detail::process_detail(pid);
                    if let Err(err) = write_json_atomic(&config::detail_file(pid), &detail) {
                        eprintln!("sysmond: 写入进程详情失败: {}", err);
                    }
                }
            }
        }

        thread::sleep(Duration::from_millis(200));
    }
}

fn write_json_atomic<T: Serialize>(path: &str, value: &T) -> Result<(), String> {
    if let Some(parent) = std::path::Path::new(path).parent() {
        fs::create_dir_all(parent).map_err(|e| format!("创建目录失败: {}", e))?;
    }
    let json = serde_json::to_string(value).map_err(|e| format!("序列化失败: {}", e))?;
    let tmp = format!("{}.tmp", path);
    fs::write(&tmp, json).map_err(|e| format!("写临时文件失败: {}", e))?;
    fs::rename(&tmp, path).map_err(|e| format!("rename 失败: {}", e))?;
    Ok(())
}

fn read_command(path: &str) -> Option<String> {
    let pending = format!("{}.pending", path);
    if fs::rename(path, &pending).is_err() {
        return None;
    }

    let _ = fs::OpenOptions::new().create(true).append(true).open(path);
    let command = fs::read_to_string(&pending).ok()?;
    let _ = fs::remove_file(&pending);

    let command = command.trim().to_string();
    if command.is_empty() {
        None
    } else {
        Some(command)
    }
}
