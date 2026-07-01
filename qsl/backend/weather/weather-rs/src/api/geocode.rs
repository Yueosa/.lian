// Open-Meteo 地理编码 — 地名 → 坐标搜索
use crate::config;
use crate::http;
use crate::model::GeocodeResult;

pub fn search(query: &str) -> Result<Vec<GeocodeResult>, String> {
    let q = query.trim();
    if q.is_empty() {
        return Err("搜索词为空".into());
    }

    let url = format!(
        "{}?name={}&count=12&language=zh&format=json",
        config::GEOCODE_URL,
        urlencoding(q)
    );

    let json = http::get_json(&url)?;
    let results = json["results"].as_array();

    let items: Vec<GeocodeResult> = match results {
        Some(arr) => arr.iter().filter_map(|item| {
            let name = item["name"].as_str().unwrap_or("").to_string();
            let admin1 = item["admin1"].as_str().unwrap_or("").to_string();
            let country = item["country"].as_str().unwrap_or("").to_string();
            let lat = item["latitude"].as_f64()?;
            let lon = item["longitude"].as_f64()?;

            let parts: Vec<&str> = [name.as_str(), admin1.as_str(), country.as_str()]
                .iter().filter(|s| !s.is_empty()).copied().collect();
            let label = parts.join(", ");

            Some(GeocodeResult { name, label, country, admin1, latitude: lat, longitude: lon })
        }).collect(),
        None => vec![],
    };

    Ok(items)
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
