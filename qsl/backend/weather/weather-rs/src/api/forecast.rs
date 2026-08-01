// Open-Meteo 预报 API
use crate::config;
use crate::http;
use serde_json::Value;

pub fn fetch(lat: f64, lon: f64) -> Result<Value, String> {
    let url = format!(
        "{}?timezone=auto&timeformat=unixtime&models=best_match&\
         latitude={:.6}&longitude={:.6}&forecast_days=16&past_days=1&windspeed_unit=ms&\
         daily=temperature_2m_max,temperature_2m_min,apparent_temperature_max,apparent_temperature_min,\
         sunshine_duration,uv_index_max,relative_humidity_2m_mean,dew_point_2m_mean,\
         pressure_msl_mean,cloud_cover_mean,visibility_mean&\
         hourly=temperature_2m,apparent_temperature,precipitation_probability,precipitation,\
         weather_code,wind_speed_10m,wind_direction_10m,wind_gusts_10m,uv_index,is_day,\
         relative_humidity_2m,dew_point_2m,pressure_msl,cloud_cover,visibility&\
         current=temperature_2m,apparent_temperature,weather_code,wind_speed_10m,\
         wind_direction_10m,wind_gusts_10m,uv_index,relative_humidity_2m,dew_point_2m,\
         pressure_msl,cloud_cover,visibility&\
         minutely_15=precipitation,precipitation_probability&forecast_minutely_15=12",
        config::FORECAST_URL, lat, lon
    );
    http::get_json(&url)
}
