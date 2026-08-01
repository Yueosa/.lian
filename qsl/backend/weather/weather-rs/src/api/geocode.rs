// 地理编码 — 地名 → 坐标搜索
//
// 用 Nominatim (OpenStreetMap) 而不是 Open-Meteo 自带的 geocoding：
// 后者在中国基本只到市级，搜「昆明市官渡区」一个结果都没有，
// 搜「官渡」返回的全是重庆、贵州、湖北、广东的同名地点。
// Nominatim 能直接命中「官渡区, 昆明市, 云南省, 中国」。
//
// 这不只是标签好看：昆明市中心与官渡区相距约 13 公里、海拔差 65 米，
// 落在预报模型的不同网格里，降水量能差两三倍。
//
// Nominatim 使用条款要求带可识别的 User-Agent 且不超过 1 请求/秒。
// 搜索由用户手动触发，天然满足频率限制。
use crate::config;
use crate::http;
use crate::model::GeocodeResult;

pub fn search(query: &str) -> Result<Vec<GeocodeResult>, String> {
    let q = query.trim();
    if q.is_empty() {
        return Err("搜索词为空".into());
    }

    let url = format!(
        "{}?q={}&format=json&limit=8&addressdetails=1&accept-language=zh",
        config::GEOCODE_URL,
        urlencoding(q)
    );

    let json = http::get_json(&url)?;
    // Nominatim 顶层直接是数组，不像 Open-Meteo 包在 results 里
    let arr = match json.as_array() {
        Some(a) => a,
        None => return Ok(vec![]),
    };

    let items: Vec<GeocodeResult> = arr.iter().filter_map(parse_item).collect();

    Ok(items)
}

/// 坐标 → 地名。用户直接输经纬度时走这条：一个区可能横跨十几公里，
/// 让他在「官渡区」的两个候选里猜，不如让他把自己的坐标喂进来。
pub fn reverse(lat: f64, lon: f64) -> Result<GeocodeResult, String> {
    let url = format!(
        "{}?lat={:.6}&lon={:.6}&format=json&addressdetails=1&accept-language=zh&zoom=16",
        config::REVERSE_URL,
        lat,
        lon
    );

    let json = http::get_json(&url)?;
    // 反查返回单个对象，不是数组
    match parse_item(&json) {
        // 反查给的 lat/lon 是匹配到的要素中心，不是用户输入的点；
        // 这里要的是标签，坐标必须保留用户原值
        Some(mut r) => {
            r.latitude = lat;
            r.longitude = lon;
            Ok(r)
        }
        None => Ok(GeocodeResult {
            name: format!("{:.4}, {:.4}", lat, lon),
            label: format!("{:.4}, {:.4}", lat, lon),
            country: String::new(),
            admin1: String::new(),
            latitude: lat,
            longitude: lon,
        }),
    }
}

/// Nominatim 的 search 与 reverse 返回同构的要素对象，解析逻辑共用
fn parse_item(item: &serde_json::Value) -> Option<GeocodeResult> {
    // lat/lon 是字符串
    let lat: f64 = item["lat"].as_str()?.parse().ok()?;
    let lon: f64 = item["lon"].as_str()?.parse().ok()?;

    let addr = &item["address"];
    let pick = |keys: &[&str]| -> String {
        for k in keys {
            if let Some(v) = addr[*k].as_str() {
                if !v.is_empty() {
                    return v.to_string();
                }
            }
        }
        String::new()
    };

    // 最具体的一级作为主名：街道 → 区 → 县 → 镇 → 市
    let name = {
        let n = pick(&[
            "suburb", "city_district", "district", "county",
            "town", "village", "city", "municipality", "state",
        ]);
        if n.is_empty() {
            // 兜底取 display_name 的第一段
            item["display_name"]
                .as_str()
                .and_then(|s| s.split(',').next())
                .unwrap_or("")
                .trim()
                .to_string()
        } else {
            n
        }
    };
    if name.is_empty() {
        return None;
    }

    let admin1 = pick(&["state", "province", "region"]);
    let country = pick(&["country"]);
    let city = pick(&["city", "municipality", "county"]);
    let district = pick(&["city_district", "district"]);

    // 「关上街道, 官渡区, 昆明市, 云南省, 中国」——逐级去重，避免层级同名时重复
    let mut parts: Vec<String> = Vec::new();
    for p in [name.clone(), district, city, admin1.clone(), country.clone()] {
        if !p.is_empty() && !parts.contains(&p) {
            parts.push(p);
        }
    }
    let label = parts.join(", ");

    Some(GeocodeResult {
        name,
        label,
        country,
        admin1,
        latitude: lat,
        longitude: lon,
    })
}

fn urlencoding(s: &str) -> String {
    let mut out = String::new();
    for b in s.bytes() {
        match b {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => out.push(b as char),
            b' ' => out.push_str("%20"),
            _ => out.push_str(&format!("%{:02X}", b)),
        }
    }
    out
}
