// JSON 文件缓存 — 原子写入，确保 QML 读到完整数据
use crate::config;
use crate::model::WeatherSnapshot;
use std::fs;

/// 从文件读取缓存
pub fn load() -> Option<WeatherSnapshot> {
    let data = fs::read_to_string(config::forecast_cache_file()).ok()?;
    serde_json::from_str(&data).ok()
}

/// 原子写入缓存（先写临时文件，再 rename）
pub fn save(snapshot: &WeatherSnapshot) -> Result<(), String> {
    let path = config::forecast_cache_file();
    if let Some(parent) = std::path::Path::new(&path).parent() {
        fs::create_dir_all(parent).ok();
    }
    let json = serde_json::to_string(snapshot).map_err(|e| format!("序列化失败: {}", e))?;
    let tmp = format!("{}.tmp", path);
    fs::write(&tmp, &json).map_err(|e| format!("写入失败: {}", e))?;
    fs::rename(&tmp, &path).map_err(|e| format!("rename 失败: {}", e))?;
    Ok(())
}
