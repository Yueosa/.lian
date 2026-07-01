// Open-Meteo 空气质量 API
use crate::config;
use crate::http;
use serde_json::Value;

pub fn fetch(lat: f64, lon: f64) -> Result<Value, String> {
    let url = format!(
        "{}?timezone=auto&timeformat=unixtime&latitude={:.6}&longitude={:.6}&\
         forecast_days=7&past_days=1&\
         hourly=pm10,pm2_5,carbon_monoxide,nitrogen_dioxide,sulphur_dioxide,ozone,\
         alder_pollen,birch_pollen,grass_pollen,mugwort_pollen,olive_pollen,ragweed_pollen",
        config::AIR_QUALITY_URL, lat, lon
    );
    http::get_json(&url)
}
