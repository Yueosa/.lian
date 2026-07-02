// 配置常量
use std::env;

/// 输出文件
pub fn output_file() -> String {
    let runtime = env::var("XDG_RUNTIME_DIR").unwrap_or_else(|_| "/tmp".into());
    format!("{}/qsl/sysmon.json", runtime)
}

/// 进程列表输出（按需）
pub fn process_file() -> String {
    let runtime = env::var("XDG_RUNTIME_DIR").unwrap_or_else(|_| "/tmp".into());
    format!("{}/qsl/sysmon_process.json", runtime)
}

/// 进程详情输出（按需）
pub fn detail_file(pid: i32) -> String {
    let runtime = env::var("XDG_RUNTIME_DIR").unwrap_or_else(|_| "/tmp".into());
    format!("{}/qsl/sysmon_detail_{}.json", runtime, pid)
}

/// 命令管道
pub fn cmd_pipe() -> String {
    let runtime = env::var("XDG_RUNTIME_DIR").unwrap_or_else(|_| "/tmp".into());
    format!("{}/qsl/sysmon_cmd", runtime)
}
