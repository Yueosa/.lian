// 守护进程主循环 — 定时刷新 + 命令输入
use crate::config;
use crate::api;
use crate::cache;
use crate::calculator;
use crate::model::*;
use std::fs;
use std::thread;
use std::time::{SystemTime, UNIX_EPOCH, Duration};

/// 预处理：填充每个 forecast item 的 weather_text 和 icon_name
fn enrich_forecast(json: &serde_json::Value) -> (Current, Vec<Hourly>, Vec<Daily>) {
    let c = &json["current"];
    let current = Current {
        temperature: c["temperature_2m"].as_f64().unwrap_or(0.0),
        apparent_temperature: c["apparent_temperature"].as_f64().unwrap_or(0.0),
        weather_code: c["weather_code"].as_u64().unwrap_or(0) as u8,
        weather_text: calculator::weather_text(c["weather_code"].as_u64().unwrap_or(0) as u8).into(),
        icon_name: calculator::icon_name(c["weather_code"].as_u64().unwrap_or(0) as u8).into(),
        wind_speed: c["wind_speed_10m"].as_f64().unwrap_or(0.0),
        wind_direction: c["wind_direction_10m"].as_f64().unwrap_or(0.0),
        wind_gusts: c["wind_gusts_10m"].as_f64().unwrap_or(0.0),
        humidity: c["relative_humidity_2m"].as_u64().unwrap_or(0) as u8,
        dew_point: c["dew_point_2m"].as_f64().unwrap_or(0.0),
        pressure: c["pressure_msl"].as_f64().unwrap_or(0.0),
        cloud_cover: c["cloud_cover"].as_u64().unwrap_or(0) as u8,
        visibility: c["visibility"].as_f64().unwrap_or(0.0),
        uv_index: c["uv_index"].as_f64().unwrap_or(0.0),
    };

    let hourly: Vec<Hourly> = json["hourly"]["time"].as_array().unwrap_or(&vec![])
        .iter().enumerate().map(|(i, t)| {
            let code = pick_arr(&json["hourly"]["weather_code"], i);
            Hourly {
                time: t.as_u64().unwrap_or(0),
                temperature: pick_arr(&json["hourly"]["temperature_2m"], i),
                apparent_temperature: pick_arr(&json["hourly"]["apparent_temperature"], i),
                precipitation_probability: pick_arr(&json["hourly"]["precipitation_probability"], i) as u8,
                precipitation: pick_arr(&json["hourly"]["precipitation"], i),
                weather_code: code as u8,
                weather_text: calculator::weather_text(code as u8).into(),
                icon_name: calculator::icon_name(code as u8).into(),
                wind_speed: pick_arr(&json["hourly"]["wind_speed_10m"], i),
                wind_direction: pick_arr(&json["hourly"]["wind_direction_10m"], i),
                wind_gusts: pick_arr(&json["hourly"]["wind_gusts_10m"], i),
                humidity: pick_arr(&json["hourly"]["relative_humidity_2m"], i) as u8,
                dew_point: pick_arr(&json["hourly"]["dew_point_2m"], i),
                pressure: pick_arr(&json["hourly"]["pressure_msl"], i),
                cloud_cover: pick_arr(&json["hourly"]["cloud_cover"], i) as u8,
                visibility: pick_arr(&json["hourly"]["visibility"], i),
                uv_index: pick_arr(&json["hourly"]["uv_index"], i),
                is_day: pick_arr(&json["hourly"]["is_day"], i) > 0.0,
            }
        }).collect();

    let daily: Vec<Daily> = json["daily"]["time"].as_array().unwrap_or(&vec![])
        .iter().enumerate().map(|(i, t)| {
            let code = pick_arr(&json["daily"]["weather_code"], i);
            Daily {
                date: t.as_u64().unwrap_or(0),
                temp_max: pick_arr(&json["daily"]["temperature_2m_max"], i),
                temp_min: pick_arr(&json["daily"]["temperature_2m_min"], i),
                apparent_max: pick_arr(&json["daily"]["apparent_temperature_max"], i),
                apparent_min: pick_arr(&json["daily"]["apparent_temperature_min"], i),
                weather_code: code as u8,
                weather_text: calculator::weather_text(code as u8).into(),
                icon_name: calculator::icon_name(code as u8).into(),
                sunshine_duration: pick_arr(&json["daily"]["sunshine_duration"], i),
                uv_index_max: pick_arr(&json["daily"]["uv_index_max"], i),
                humidity_mean: pick_arr(&json["daily"]["relative_humidity_2m_mean"], i) as u8,
                dew_point_mean: pick_arr(&json["daily"]["dew_point_2m_mean"], i),
                pressure_mean: pick_arr(&json["daily"]["pressure_msl_mean"], i),
                cloud_cover_mean: pick_arr(&json["daily"]["cloud_cover_mean"], i) as u8,
                visibility_mean: pick_arr(&json["daily"]["visibility_mean"], i),
            }
        }).collect();

    (current, hourly, daily)
}

fn enrich_air_quality(json: &serde_json::Value) -> AirQuality {
    let pm10 = extract_hourly(&json["hourly"], "pm10");
    let pm2_5 = extract_hourly(&json["hourly"], "pm2_5");
    let carbon_monoxide = extract_hourly(&json["hourly"], "carbon_monoxide");
    let nitrogen_dioxide = extract_hourly(&json["hourly"], "nitrogen_dioxide");
    let sulphur_dioxide = extract_hourly(&json["hourly"], "sulphur_dioxide");
    let ozone = extract_hourly(&json["hourly"], "ozone");
    let alder_pollen = extract_hourly(&json["hourly"], "alder_pollen");
    let birch_pollen = extract_hourly(&json["hourly"], "birch_pollen");
    let grass_pollen = extract_hourly(&json["hourly"], "grass_pollen");
    let mugwort_pollen = extract_hourly(&json["hourly"], "mugwort_pollen");
    let olive_pollen = extract_hourly(&json["hourly"], "olive_pollen");
    let ragweed_pollen = extract_hourly(&json["hourly"], "ragweed_pollen");

    AirQuality { pm10, pm2_5, carbon_monoxide, nitrogen_dioxide, sulphur_dioxide,
        ozone, alder_pollen, birch_pollen, grass_pollen, mugwort_pollen, olive_pollen, ragweed_pollen }
}

fn extract_hourly(json: &serde_json::Value, field: &str) -> Vec<HourlyValue> {
    let empty: Vec<serde_json::Value> = vec![];
    let times = json["time"].as_array().unwrap_or(&empty);
    let values = json[field].as_array().unwrap_or(&empty);
    times.iter().zip(values.iter()).map(|(t, v)| {
        HourlyValue { time: t.as_u64().unwrap_or(0), value: v.as_f64().unwrap_or(0.0) }
    }).collect()
}

fn pick_arr(arr: &serde_json::Value, i: usize) -> f64 {
    arr.as_array().and_then(|a| a.get(i)).and_then(|v| v.as_f64()).unwrap_or(0.0)
}

fn now_ts() -> u64 {
    SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs()
}

/// 单次刷新：拉预报 + 空气 → 计算 → 写缓存
fn refresh(lat: f64, lon: f64, location_name: &str) -> Result<WeatherSnapshot, String> {
    let fc_json = api::forecast::fetch(lat, lon)?;
    let aq_json = api::air_quality::fetch(lat, lon)?;
    let (current, hourly, daily) = enrich_forecast(&fc_json);
    let air_quality = enrich_air_quality(&aq_json);

    Ok(WeatherSnapshot {
        status: "fresh".into(),
        location_name: location_name.into(),
        latitude: lat, longitude: lon,
        last_updated: now_ts(),
        current, hourly, daily, air_quality,
    })
}

/// 主循环
pub fn run() {
    // 1. IP 定位
    let loc = match api::location::detect() {
        Ok(l) => {
            eprintln!("weatherd: 定位 -> {} ({}, {})", l.name, l.latitude, l.longitude);
            l
        }
        Err(e) => {
            eprintln!("weatherd: 定位失败: {}", e);
            // 默认：长沙
            IpLocation { latitude: 28.2282, longitude: 112.9388, name: "Changsha".into() }
        }
    };

    let mut lat = loc.latitude;
    let mut lon = loc.longitude;
    let mut name = loc.name;

    // 2. 创建运行时目录和命令管道
    let cmd_file = config::cmd_pipe();
    if let Some(parent) = std::path::Path::new(&cmd_file).parent() {
        fs::create_dir_all(parent).ok();
    }
    let _ = fs::remove_file(&cmd_file);
    let _ = fs::OpenOptions::new().create(true).write(true).open(&cmd_file);

    loop {
        // 刷新数据
        match refresh(lat, lon, &name) {
            Ok(snapshot) => {
                if let Err(e) = cache::save(&snapshot) {
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

        // 休眠期间检查命令管道
        let pipe = cmd_file.clone();
        let deadline = std::time::Instant::now() + Duration::from_secs(config::REFRESH_INTERVAL);

        while std::time::Instant::now() < deadline {
            if let Ok(buf) = fs::read_to_string(&pipe) {
                if !buf.trim().is_empty() {
                    let cmd = buf.trim();
                    if cmd == "refresh" {
                        eprintln!("weatherd: 收到 refresh 命令");
                        let _ = fs::write(&pipe, "");
                        break;
                    } else if cmd.starts_with("geocode ") {
                        let query = &cmd[8..];
                        eprintln!("weatherd: 搜索城市: {}", query);
                        if let Ok(results) = api::geocode::search(query) {
                            if let Some(first) = results.first() {
                                lat = first.latitude;
                                lon = first.longitude;
                                name = first.label.clone();
                                eprintln!("weatherd: 切换到 {} ({}, {})", name, lat, lon);
                                let _ = fs::write(&pipe, "");
                                break;
                            }
                        }
                    }
                    let _ = fs::write(&pipe, "");
                }
            }
            thread::sleep(Duration::from_millis(500));
        }
    }
}
