use serde::Serialize;

#[derive(Debug, Clone, Serialize, Default)]
pub struct Snapshot {
    pub cpu_percent: f64,
    pub memory: Memory,
    pub network: Network,
    pub thermal: Thermal,
    pub gpu: Gpu,
    pub load: Load,
    pub disk: Disk,
    pub uptime_secs: u64,
}

#[derive(Debug, Clone, Serialize, Default)]
pub struct Memory {
    pub used_gb: f64,
    pub total_gb: f64,
    pub percent: f64,
    pub swap_used_gb: f64,
    pub swap_total_gb: f64,
}

#[derive(Debug, Clone, Serialize, Default)]
pub struct Network {
    // 历史字段名保留为 bps；实际含义是 bytes per second，QML 展示时再换算单位。
    pub down_bps: f64,
    pub up_bps: f64,
    pub iface: String, // read by QML via JSON
}

#[derive(Debug, Clone, Serialize, Default)]
pub struct Thermal {
    pub cpu_package: f64,      // Package id 0
    pub cpu_hottest_core: f64, // max core temp
    pub ssd: f64,              // nvme Composite
    pub wifi: f64,             // iwlwifi
}

#[derive(Debug, Clone, Serialize, Default)]
pub struct Gpu {
    pub available: bool,
    pub temp: f64,
    pub usage_percent: f64,
    pub memory_used_mb: u64,
    pub memory_total_mb: u64,
    pub power_watts: f64,
}

#[derive(Debug, Clone, Serialize, Default)]
pub struct Load {
    pub load1: f64,
    pub load5: f64,
    pub load15: f64,
}

#[derive(Debug, Clone, Serialize, Default)]
pub struct Disk {
    pub used_gb: f64,
    pub total_gb: f64,
    pub percent: f64,
}
