// sysmond — 系统监控守护进程
//
// 两档分级轮询，由 `detail <0|1>` 命令切换：
//   detail=1（System 页打开）：1s(CPU/Net) 2s(Mem/Thermal) 3s(GPU) 5s(Load) 30s(Disk/Uptime)
//   detail=0（仅顶栏摘要）   ：3s(CPU/Net) 5s(Mem/Thermal) 15s(GPU) 15s(Load) 60s(Disk/Uptime)
//
// GPU 单独成档：每次采样都要 fork 一个 nvidia-smi（含驱动初始化，约 10–30ms CPU），
// 挂在 2s 档等于常年占用约 1.5% 的一个核，仅为顶栏一个悬停数字。
//
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

struct Tiers {
    fast: Duration,
    medium: Duration,
    gpu: Duration,
    slow: Duration,
    glacial: Duration,
    poll: Duration,
}

impl Tiers {
    fn for_mode(detail: bool) -> Self {
        if detail {
            Tiers {
                fast: Duration::from_secs(1),
                medium: Duration::from_secs(2),
                gpu: Duration::from_secs(3),
                slow: Duration::from_secs(5),
                glacial: Duration::from_secs(30),
                poll: Duration::from_millis(200),
            }
        } else {
            Tiers {
                fast: Duration::from_secs(3),
                medium: Duration::from_secs(5),
                gpu: Duration::from_secs(15),
                slow: Duration::from_secs(15),
                glacial: Duration::from_secs(60),
                // 命令管道靠轮询 rename()，摘要档放宽到 500ms：
                // 开 System 页时首帧最多晚半秒，换来 60% 更少的空转唤醒
                poll: Duration::from_millis(500),
            }
        }
    }
}

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

    // 未收到 detail 命令前按摘要档跑；QML 打开 System 页时会立刻切换
    let mut detail_mode = false;
    let mut tiers = Tiers::for_mode(detail_mode);

    let mut fast = Instant::now() + tiers.fast;
    let mut medium = Instant::now() + tiers.medium;
    let mut gpu = Instant::now() + tiers.gpu;
    let mut slow = Instant::now() + tiers.slow;
    let mut glacial = Instant::now() + tiers.glacial;

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
            fast = now + tiers.fast;
            snapshot_dirty = true;
        }

        // === Medium: Mem, Thermal ===
        if now >= medium {
            snapshot.memory = source::memory::sample();
            snapshot.thermal = source::thermal::sample();
            medium = now + tiers.medium;
            snapshot_dirty = true;
        }

        // === GPU: 单独成档（每次都 fork nvidia-smi）===
        if now >= gpu {
            snapshot.gpu = source::gpu::sample();
            gpu = now + tiers.gpu;
            snapshot_dirty = true;
        }

        // === Slow: Load ===
        if now >= slow {
            snapshot.load = source::load::sample();
            slow = now + tiers.slow;
            snapshot_dirty = true;
        }

        // === Glacial: Disk, Uptime ===
        if now >= glacial {
            snapshot.disk = source::disk::sample();
            snapshot.uptime_secs = source::uptime::sample();
            glacial = now + tiers.glacial;
            snapshot_dirty = true;
        }

        if snapshot_dirty {
            if let Err(err) = write_json_atomic(&out, &snapshot) {
                eprintln!("sysmond: 写入快照失败: {}", err);
            }
            snapshot_dirty = false;
        }

        // 检查命令管道（可能一次取到多条：QML 侧是追加写）
        for s in read_commands(&cmd) {
            if let Some(arg) = s.strip_prefix("detail ") {
                let want = arg.trim() != "0";
                if want != detail_mode {
                    detail_mode = want;
                    tiers = Tiers::for_mode(detail_mode);
                    // 切到详情档时立刻补一轮，别让用户盯着上一档的陈旧数字
                    let base = Instant::now();
                    if detail_mode {
                        fast = base;
                        medium = base;
                        gpu = base;
                        slow = base;
                    } else {
                        fast = base + tiers.fast;
                        medium = base + tiers.medium;
                        gpu = base + tiers.gpu;
                        slow = base + tiers.slow;
                    }
                }
            } else if s.starts_with("process_list") {
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

        thread::sleep(tiers.poll);
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

// 命令文件是「取走即清空」的一次性投递：rename 出去再读，避免与写入方竞争。
// 写入方用追加而非截断，所以一次可能取到多行，逐条返回。
fn read_commands(path: &str) -> Vec<String> {
    let pending = format!("{}.pending", path);
    if fs::rename(path, &pending).is_err() {
        return Vec::new();
    }

    let _ = fs::OpenOptions::new().create(true).append(true).open(path);
    let raw = fs::read_to_string(&pending).unwrap_or_default();
    let _ = fs::remove_file(&pending);

    raw.lines()
        .map(|l| l.trim().to_string())
        .filter(|l| !l.is_empty())
        .collect()
}
