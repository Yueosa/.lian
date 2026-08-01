// 配置常量 — URL、文件路径、刷新间隔
use std::env;

/// 运行时目录（tmpfs，$XDG_RUNTIME_DIR/qsl/，登出自动清理）
pub fn runtime_dir() -> String {
    env::var("XDG_RUNTIME_DIR").unwrap_or_else(|_| "/tmp".into())
}

/// 缓存目录（持久化，$HOME/.cache/qsl/）
pub fn cache_dir() -> String {
    let home = env::var("HOME").unwrap_or_else(|_| "/tmp".into());
    format!("{}/.cache/qsl", home)
}

/// 天气预报缓存（持久化到磁盘，重启后复用）— 完整数据，仅 daemon 自己读
pub fn forecast_cache_file() -> String { format!("{}/forecast.json", cache_dir()) }

/// 瘦身快照 — QML 只解析这一份，约为完整版的 5%
pub fn forecast_slim_file() -> String { format!("{}/forecast_slim.json", cache_dir()) }

/// 用户指定位置（优先于 IP 定位，通过 geocode 命令设置）
pub fn location_file() -> String { format!("{}/location.json", cache_dir()) }

/// 命令管道（tmpfs，接收 QML 端命令）
pub fn cmd_pipe() -> String { format!("{}/qsl/weather_cmd", runtime_dir()) }

/// 搜索结果缓存（持久化，跨 QML/weatherd 通信）
pub fn geocode_results_file() -> String { format!("{}/geocode_results.json", cache_dir()) }

/// 天气数据刷新间隔（秒）— 定时主动拉取
pub const REFRESH_INTERVAL: u64 = 15 * 60;

/// 软刷新最短间隔：缓存未过期则忽略 `refresh`（`refresh force` 除外）
pub const MIN_REFRESH_SECS: u64 = 10 * 60;

/// 遭遇 429 后推迟下次定时刷新（秒）
pub const BACKOFF_429_SECS: u64 = 30 * 60;

/// HTTP 请求超时（秒）
pub const HTTP_TIMEOUT: u64 = 10;

/// API 端点
pub const IPWHO_URL: &str = "https://ipwho.is/?fields=success,latitude,longitude,city,region,country";
pub const FORECAST_URL: &str = "https://api.open-meteo.com/v1/forecast";
pub const AIR_QUALITY_URL: &str = "https://air-quality-api.open-meteo.com/v1/air-quality";
// Nominatim：Open-Meteo 的 geocoding 在中国只到市级，搜不到区
pub const GEOCODE_URL: &str = "https://nominatim.openstreetmap.org/search";
// 反查：用户直接给经纬度时，用它换回街道级地名当标签
pub const REVERSE_URL: &str = "https://nominatim.openstreetmap.org/reverse";
// Nominatim 条款要求 UA 能标识应用与联系方式
pub const USER_AGENT: &str = "qsl-weather/1.0 (personal dotfiles; github.com/Yueosa)";
