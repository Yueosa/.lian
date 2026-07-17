// 守护进程主循环 — 定时刷新 + 命令管道 + 位置持久化
use crate::{api, cache, config, enrich, model::*};
use std::{
    fs, thread,
    time::{Duration, Instant, SystemTime, UNIX_EPOCH},
};

pub fn run() {
    let (mut lat, mut lon, mut name) = load_location();
    eprintln!("weatherd: 定位 -> {} ({}, {})", name, lat, lon);

    let cmd_file = config::cmd_pipe();
    if let Some(parent) = std::path::Path::new(&cmd_file).parent() {
        fs::create_dir_all(parent).ok();
    }
    let _ = fs::OpenOptions::new()
        .create(true)
        .write(true)
        .open(&cmd_file);

    loop {
        do_refresh(lat, lon, &name);

        let deadline = Instant::now() + Duration::from_secs(config::REFRESH_INTERVAL);
        while Instant::now() < deadline {
            if let Some(cmd) = read_command(&cmd_file) {
                match cmd.as_str() {
                    "refresh" => {
                        eprintln!("weatherd: 收到 refresh");
                        break;
                    }
                    s if s.starts_with("geocode ") => {
                        // 搜索城市 → 写结果文件 → QML 展示列表
                        let query = &s[8..];
                        eprintln!("weatherd: 搜索城市: {}", query);
                        match api::geocode::search(query) {
                            Ok(results) => {
                                let json =
                                    serde_json::to_string(&results).unwrap_or_else(|_| "[]".into());
                                let _ = fs::write(config::geocode_results_file(), &json);
                                eprintln!("weatherd: 找到 {} 个结果", results.len());
                            }
                            Err(e) => eprintln!("weatherd: 搜索失败: {}", e),
                        }
                    }
                    s if s.starts_with("set_location ") => {
                        // QML 选择了搜索结果 → 保存位置 → 立即刷新
                        let args: Vec<&str> = s[13..].splitn(3, ' ').collect();
                        if args.len() >= 3 {
                            lat = args[0].parse().unwrap_or(lat);
                            lon = args[1].parse().unwrap_or(lon);
                            name = args[2].to_string();
                            save_location(lat, lon, &name);
                            eprintln!("weatherd: 切换到 {} 并保存", name);
                            break;
                        }
                    }
                    s if s == "reset_location" => match api::location::detect() {
                        Ok(loc) => {
                            lat = loc.latitude;
                            lon = loc.longitude;
                            name = loc.name;
                            let _ = fs::remove_file(config::location_file());
                            eprintln!("weatherd: 重置为 IP 定位 -> {}", name);
                            break;
                        }
                        Err(e) => eprintln!("weatherd: IP 定位失败: {}", e),
                    },
                    _ => {}
                }
            }
            thread::sleep(Duration::from_millis(1000));
        }
    }
}

fn load_location() -> (f64, f64, String) {
    // 优先读用户手动设置的位置
    if let Ok(data) = fs::read_to_string(config::location_file()) {
        if let Ok(v) = serde_json::from_str::<serde_json::Value>(&data) {
            let lat = v["latitude"].as_f64().unwrap_or(0.0);
            let lon = v["longitude"].as_f64().unwrap_or(0.0);
            let name = v["name"].as_str().unwrap_or("").to_string();
            if lat != 0.0 && !name.is_empty() {
                return (lat, lon, name);
            }
        }
    }
    // fallback: IP 定位
    match api::location::detect() {
        Ok(loc) => (loc.latitude, loc.longitude, loc.name),
        Err(e) => {
            eprintln!("weatherd: IP 定位失败: {}，使用默认", e);
            (28.2282, 112.9388, "Changsha".into())
        }
    }
}

fn save_location(lat: f64, lon: f64, name: &str) {
    let path = config::location_file();
    if let Some(parent) = std::path::Path::new(&path).parent() {
        let _ = fs::create_dir_all(parent);
    }
    let json = serde_json::json!({
        "latitude": lat,
        "longitude": lon,
        "name": name,
    });
    if let Err(e) = fs::write(&path, json.to_string()) {
        eprintln!("weatherd: 保存位置失败: {}", e);
    }
}

fn do_refresh(lat: f64, lon: f64, name: &str) {
    let result = (|| -> Result<WeatherSnapshot, String> {
        let fc = api::forecast::fetch(lat, lon)?;
        let aq = api::air_quality::fetch(lat, lon)?;
        let (current, hourly, daily) = enrich::forecast(&fc)?;
        let air_quality = enrich::air_quality(&aq);
        Ok(WeatherSnapshot {
            status: "fresh".into(),
            location_name: name.into(),
            latitude: lat,
            longitude: lon,
            last_updated: now_ts(),
            current,
            hourly,
            daily,
            air_quality,
        })
    })();

    match result {
        Ok(snap) => {
            if let Err(e) = cache::save(&snap) {
                eprintln!("weatherd: 缓存写入失败: {}", e);
            }
        }
        Err(e) => {
            eprintln!("weatherd: 刷新失败: {}", e);
            if let Some(mut old) = cache::load() {
                old.status = "stale".into();
                let _ = cache::save(&old);
            }
        }
    }
}

fn read_command(path: &str) -> Option<String> {
    let pending = format!("{}.pending", path);
    if fs::rename(path, &pending).is_err() {
        return None;
    }

    let _ = fs::OpenOptions::new().create(true).append(true).open(path);
    let command = fs::read_to_string(&pending).unwrap_or_default();
    let _ = fs::remove_file(&pending);

    let command = command.trim().to_string();
    if command.is_empty() {
        None
    } else {
        Some(command)
    }
}

fn now_ts() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs()
}
