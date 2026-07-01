// cava-relay — 将 cava 的二进制频谱数据中继到共享内存文件
//
// 数据流：
//   PipeWire → cava (binary stdout) → 本程序读取 → /dev/shm/qsl_cava.bin
//
// QML 端通过 data/service/Cava.qml 读取 /dev/shm/qsl_cava.bin，
// 每帧 30 字节（每字节一个柱，0-255），零解析开销。
//
// 生命周期：
//   由 QML/Quickshell 通过 Process 启动和终止。
//   退出时 OS 自动清理 /dev/shm/qsl_cava.bin（tmpfs）。

use std::fs;
use std::io::{self, Read};
use std::path::PathBuf;
use std::process::{Child, Command, Stdio};
use std::thread;
use std::time::Duration;

const BAR_COUNT: usize = 30;
const FRAMERATE: u32 = 60;
const OUTPUT_FILE: &str = "/dev/shm/qsl_cava.bin";

fn main() {
    let config_path = match write_cava_config() {
        Ok(p) => p,
        Err(e) => {
            eprintln!("cava-relay: 无法写入配置: {}", e);
            return;
        }
    };

    let mut child = match spawn_cava(&config_path) {
        Ok(c) => c,
        Err(e) => {
            eprintln!("cava-relay: 无法启动 cava: {}", e);
            let _ = fs::remove_file(&config_path);
            return;
        }
    };

    // cava 已读取配置，可以删除
    let _ = fs::remove_file(&config_path);

    let stdout = match child.stdout.take() {
        Some(s) => s,
        None => {
            eprintln!("cava-relay: cava 没有 stdout");
            let _ = child.kill();
            return;
        }
    };

    let mut reader = io::BufReader::new(stdout);
    let mut frame = vec![0u8; BAR_COUNT];

    loop {
        match reader.read_exact(&mut frame) {
            Ok(()) => {
                // 原子写入：先写临时文件，再 rename（POSIX 保证 rename 原子性）
                let tmp = format!("{}.tmp", OUTPUT_FILE);
                if fs::write(&tmp, &frame).is_ok() {
                    let _ = fs::rename(&tmp, OUTPUT_FILE);
                }
            }
            Err(e) if e.kind() == io::ErrorKind::UnexpectedEof => {
                // cava 进程退出，尝试重启
                eprintln!("cava-relay: cava 退出，1 秒后重试...");
                let _ = child.wait();
                thread::sleep(Duration::from_secs(1));

                // 重新生成配置（/dev/shm 在 tmpfs 上，之前的应该已被删除）
                match write_cava_config() {
                    Ok(p) => match spawn_cava(&p) {
                        Ok(c) => {
                            child = c;
                            let _ = fs::remove_file(&p);
                            if let Some(s) = child.stdout.take() {
                                reader = io::BufReader::new(s);
                                continue;
                            }
                        }
                        Err(e2) => eprintln!("cava-relay: 重启失败: {}", e2),
                    },
                    Err(e2) => eprintln!("cava-relay: 配置写入失败: {}", e2),
                }
                break;
            }
            Err(e) => {
                eprintln!("cava-relay: 读取错误: {}", e);
                break;
            }
        }
    }

    let _ = child.kill();
    let _ = child.wait();
    let _ = fs::remove_file(OUTPUT_FILE);
}

fn write_cava_config() -> io::Result<PathBuf> {
    let config = format!(
        concat!(
            "[general]\n",
            "framerate={framerate}\n",
            "bars={bars}\n",
            "autosens=1\n",
            "\n",
            "[output]\n",
            "method=raw\n",
            "raw_target=/dev/stdout\n",
            "data_format=binary\n",
            "bit_format=8bit\n",
            "channels=mono\n",
            "mono_option=average\n",
            "\n",
            "[smoothing]\n",
            "noise_reduction=35\n",
            "integral=90\n",
            "gravity=95\n",
            "ignore=2\n",
            "monstercat=1.5\n",
        ),
        framerate = FRAMERATE,
        bars = BAR_COUNT,
    );

    let path = PathBuf::from(format!("/dev/shm/qsl_cava_config_{}.tmp", std::process::id()));
    fs::write(&path, &config)?;
    Ok(path)
}

fn spawn_cava(config_path: &PathBuf) -> io::Result<Child> {
    Command::new("cava")
        .arg("-p")
        .arg(config_path)
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .stdin(Stdio::null())
        .spawn()
}
