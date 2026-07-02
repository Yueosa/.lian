// 进程信息 — 按需读取 /proc/<pid>/
pub mod list;
pub mod detail;

pub use list::ProcessSampler;
