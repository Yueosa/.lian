// IP 定位 — ipwho.is → 坐标 + 城市名
use crate::config;
use crate::http;
use crate::model::IpLocation;

pub fn detect() -> Result<IpLocation, String> {
    let json = http::get_json(config::IPWHO_URL)?;

    let success = json["success"].as_bool().unwrap_or(false);
    if !success {
        return Err("IP 定位失败".into());
    }

    let lat = json["latitude"].as_f64().unwrap_or(0.0);
    let lon = json["longitude"].as_f64().unwrap_or(0.0);
    let city = json["city"].as_str().unwrap_or("").to_string();
    let region = json["region"].as_str().unwrap_or("").to_string();
    let country = json["country"].as_str().unwrap_or("").to_string();

    let name = if !city.is_empty() { city }
        else if !region.is_empty() { region }
        else if !country.is_empty() { country }
        else { "Unknown".into() };

    Ok(IpLocation { latitude: lat, longitude: lon, name })
}
