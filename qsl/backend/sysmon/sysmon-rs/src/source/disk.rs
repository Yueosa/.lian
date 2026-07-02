// 磁盘使用率 — statvfs 系统调用
use crate::model::Disk;

pub fn sample() -> Disk {
    // statvfs 获取根分区的使用情况
    let mut stat: libc::statvfs = unsafe { std::mem::zeroed() };
    let path = std::ffi::CString::new("/").unwrap();
    if unsafe { libc::statvfs(path.as_ptr(), &mut stat) } != 0 {
        return Disk::default();
    }
    let block_size = stat.f_frsize as u64;
    let total = stat.f_blocks * block_size;
    let avail = stat.f_bavail * block_size;
    let used = total.saturating_sub(avail);

    Disk {
        used_gb: used as f64 / 1073741824.0,
        total_gb: total as f64 / 1073741824.0,
        percent: if total > 0 { used as f64 / total as f64 * 100.0 } else { 0.0 },
    }
}
