// JSON 文件缓存 — 原子写入，确保 QML 读到完整数据
use crate::config;
use crate::model::WeatherSnapshot;
use std::fs;

/// 从文件读取缓存
pub fn load() -> Option<WeatherSnapshot> {
    let data = fs::read_to_string(config::forecast_cache_file()).ok()?;
    serde_json::from_str(&data).ok()
}

fn write_atomic(path: &str, json: &str) -> Result<(), String> {
    if let Some(parent) = std::path::Path::new(path).parent() {
        fs::create_dir_all(parent).ok();
    }
    let tmp = format!("{}.tmp", path);
    fs::write(&tmp, json).map_err(|e| format!("写入失败: {}", e))?;
    fs::rename(&tmp, path).map_err(|e| format!("rename 失败: {}", e))?;
    Ok(())
}

/// 原子写入缓存（先写临时文件，再 rename）
///
/// 写两份：完整版留给 daemon 自己复用（重启后不必重抓），
/// 瘦身版给 QML 解析——完整版 221 KB 里天气页用不到 3%。
pub fn save(snapshot: &WeatherSnapshot) -> Result<(), String> {
    let full = serde_json::to_string(snapshot).map_err(|e| format!("序列化失败: {}", e))?;
    write_atomic(&config::forecast_cache_file(), &full)?;

    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    let slim = serde_json::to_string(&snapshot.slim(now))
        .map_err(|e| format!("瘦身序列化失败: {}", e))?;
    write_atomic(&config::forecast_slim_file(), &slim)?;

    Ok(())
}
