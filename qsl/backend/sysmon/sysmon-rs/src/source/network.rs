// 网络速率 — 两次读 /proc/net/dev 取差值
use std::fs;

pub struct NetSampler {
    prev_down: u64,
    prev_up: u64,
    iface: String,
}

impl NetSampler {
    pub fn new() -> Self {
        let (prev_down, prev_up, iface) = read_net_totals();
        Self { prev_down, prev_up, iface }
    }

    /// 返回 (down_bps, up_bps, interface_name)
    pub fn sample(&mut self) -> (f64, f64, String) {
        let (down, up, iface) = read_net_totals();
        let down_diff = down.saturating_sub(self.prev_down);
        let up_diff = up.saturating_sub(self.prev_up);
        self.prev_down = down;
        self.prev_up = up;
        (down_diff as f64, up_diff as f64, iface)
    }
}

fn read_net_totals() -> (u64, u64, String) {
    let mut down = 0u64;
    let mut up = 0u64;
    let mut iface = String::new();
    let Ok(s) = fs::read_to_string("/proc/net/dev") else { return (0, 0, iface) };
    for line in s.lines().skip(2) {
        let parts: Vec<&str> = line.split_whitespace().collect();
        if parts.len() < 10 { continue; }
        let name = parts[0].trim_end_matches(':');
        // 跳过 loopback 和 Mihomo 虚拟接口
        if name == "lo" || name.starts_with("Mihomo") || name.starts_with("tun") { continue; }
        let rx: u64 = parts[1].parse().unwrap_or(0);
        let tx: u64 = parts[9].parse().unwrap_or(0);
        down += rx;
        up += tx;
        if iface.is_empty() { iface = name.to_string(); }
    }
    (down, up, iface)
}
