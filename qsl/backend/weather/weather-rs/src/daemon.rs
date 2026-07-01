// 守护进程主循环 — 定时刷新 + 命令管道
use crate::{config, api, cache, enrich, model::*};
use std::{fs, thread, time::{SystemTime, UNIX_EPOCH, Duration, Instant}};

pub fn run() {
    let loc = api::location::detect().unwrap_or_else(|e| {
        eprintln!("weatherd: IP 定位失败: {}，使用默认", e);
        IpLocation { latitude: 28.2282, longitude: 112.9388, name: "Changsha".into() }
    });
    let mut lat = loc.latitude;
    let mut lon = loc.longitude;
    let mut name = loc.name;
    eprintln!("weatherd: 定位 -> {} ({}, {})", name, lat, lon);

    let cmd_file = config::cmd_pipe();
    if let Some(parent) = std::path::Path::new(&cmd_file).parent() {
        fs::create_dir_all(parent).ok();
    }
    let _ = fs::OpenOptions::new().create(true).write(true).open(&cmd_file);

    loop {
        do_refresh(lat, lon, &name);

        let deadline = Instant::now() + Duration::from_secs(config::REFRESH_INTERVAL);
        while Instant::now() < deadline {
            if let Some(cmd) = read_command(&cmd_file) {
                match cmd.as_str() {
                    "refresh" => { eprintln!("weatherd: 收到 refresh"); break; }
                    s if s.starts_with("geocode ") => {
                        let query = &s[8..];
                        eprintln!("weatherd: 搜索城市: {}", query);
                        if let Ok(results) = api::geocode::search(query) {
                            if let Some(r) = results.first() {
                                lat = r.latitude; lon = r.longitude; name = r.label.clone();
                                eprintln!("weatherd: 切换到 {}", name);
                                break;
                            }
                        }
                    }
                    _ => {}
                }
            }
            thread::sleep(Duration::from_millis(1000));
        }
    }
}

fn do_refresh(lat: f64, lon: f64, name: &str) {
    let result = (|| -> Result<WeatherSnapshot, String> {
        let fc = api::forecast::fetch(lat, lon)?;
        let aq = api::air_quality::fetch(lat, lon)?;
        let (current, hourly, daily) = enrich::forecast(&fc);
        let air_quality = enrich::air_quality(&aq);
        Ok(WeatherSnapshot {
            status: "fresh".into(), location_name: name.into(),
            latitude: lat, longitude: lon,
            last_updated: now_ts(),
            current, hourly, daily, air_quality,
        })
    })();

    match result {
        Ok(snap) => { if let Err(e) = cache::save(&snap) { eprintln!("weatherd: 缓存写入失败: {}", e); } }
        Err(e) => {
            eprintln!("weatherd: 刷新失败: {}", e);
            if let Some(mut old) = cache::load() { old.status = "stale".into(); let _ = cache::save(&old); }
        }
    }
}

fn read_command(path: &str) -> Option<String> {
    match fs::read_to_string(path) {
        Ok(s) if !s.trim().is_empty() => { let _ = fs::write(path, ""); Some(s.trim().to_string()) }
        _ => None,
    }
}

fn now_ts() -> u64 { SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs() }
