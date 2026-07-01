// 数据模型 — 所有结构体定义集中于此
use serde::{Deserialize, Serialize};

/// 最终输出给 QML 的完整天气快照
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WeatherSnapshot {
    pub status: String,       // "fresh" | "stale" | "error"
    pub location_name: String,
    pub latitude: f64,
    pub longitude: f64,
    pub last_updated: u64,    // unix timestamp
    pub current: Current,
    pub hourly: Vec<Hourly>,
    pub daily: Vec<Daily>,
    pub air_quality: AirQuality,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct Current {
    pub temperature: f64,
    pub apparent_temperature: f64,
    pub weather_code: u8,
    pub weather_text: String,
    pub icon_name: String,
    pub wind_speed: f64,
    pub wind_direction: f64,
    pub wind_gusts: f64,
    pub humidity: u8,
    pub dew_point: f64,
    pub pressure: f64,
    pub cloud_cover: u8,
    pub visibility: f64,
    pub uv_index: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct Hourly {
    pub time: u64,
    pub temperature: f64,
    pub apparent_temperature: f64,
    pub precipitation_probability: u8,
    pub precipitation: f64,
    pub weather_code: u8,
    pub weather_text: String,
    pub icon_name: String,
    pub wind_speed: f64,
    pub wind_direction: f64,
    pub wind_gusts: f64,
    pub humidity: u8,
    pub dew_point: f64,
    pub pressure: f64,
    pub cloud_cover: u8,
    pub visibility: f64,
    pub uv_index: f64,
    pub is_day: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct Daily {
    pub date: u64,
    pub temp_max: f64,
    pub temp_min: f64,
    pub apparent_max: f64,
    pub apparent_min: f64,
    pub weather_code: u8,
    pub weather_text: String,
    pub icon_name: String,
    pub sunshine_duration: f64,
    pub uv_index_max: f64,
    pub humidity_mean: u8,
    pub dew_point_mean: f64,
    pub pressure_mean: f64,
    pub cloud_cover_mean: u8,
    pub visibility_mean: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct AirQuality {
    pub pm10: Vec<HourlyValue>,
    pub pm2_5: Vec<HourlyValue>,
    pub carbon_monoxide: Vec<HourlyValue>,
    pub nitrogen_dioxide: Vec<HourlyValue>,
    pub sulphur_dioxide: Vec<HourlyValue>,
    pub ozone: Vec<HourlyValue>,
    pub alder_pollen: Vec<HourlyValue>,
    pub birch_pollen: Vec<HourlyValue>,
    pub grass_pollen: Vec<HourlyValue>,
    pub mugwort_pollen: Vec<HourlyValue>,
    pub olive_pollen: Vec<HourlyValue>,
    pub ragweed_pollen: Vec<HourlyValue>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct HourlyValue {
    pub time: u64,
    pub value: f64,
}

/// IP 定位返回
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IpLocation {
    pub latitude: f64,
    pub longitude: f64,
    pub name: String,
}

/// 地理编码搜索结果
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GeocodeResult {
    pub name: String,
    pub label: String,
    pub country: String,
    pub admin1: String,
    pub latitude: f64,
    pub longitude: f64,
}
