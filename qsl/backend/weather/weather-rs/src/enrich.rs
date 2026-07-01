// 将 Open-Meteo 原始 JSON 转换为带衍生字段的结构体
use crate::calculator;
use crate::model::*;
use serde_json::Value;

/// 从预报 JSON 中提取 current/hourly/daily，填充 weather_text 和 icon_name
pub fn forecast(json: &Value) -> (Current, Vec<Hourly>, Vec<Daily>) {
    let c = &json["current"];
    let current = Current {
        temperature:        f64_or(c, "temperature_2m", 0.0),
        apparent_temperature: f64_or(c, "apparent_temperature", 0.0),
        weather_code:       u8_or(c, "weather_code", 0),
        weather_text:       calculator::weather_text(u8_or(c, "weather_code", 0)).into(),
        icon_name:          calculator::icon_name(u8_or(c, "weather_code", 0)).into(),
        wind_speed:         f64_or(c, "wind_speed_10m", 0.0),
        wind_direction:     f64_or(c, "wind_direction_10m", 0.0),
        wind_gusts:         f64_or(c, "wind_gusts_10m", 0.0),
        humidity:           u8_or(c, "relative_humidity_2m", 0),
        dew_point:          f64_or(c, "dew_point_2m", 0.0),
        pressure:           f64_or(c, "pressure_msl", 0.0),
        cloud_cover:        u8_or(c, "cloud_cover", 0),
        visibility:         f64_or(c, "visibility", 0.0),
        uv_index:           f64_or(c, "uv_index", 0.0),
    };

    let times = json["hourly"]["time"].as_array().unwrap();
    let empty: Vec<Value> = vec![];
    let hourly: Vec<Hourly> = times.iter().enumerate().map(|(i, t)| {
        let code = arr_f64(&json["hourly"], "weather_code", i, 0.0) as u8;
        let h = &json["hourly"];
        Hourly {
            time: t.as_u64().unwrap_or(0),
            temperature:                arr_f64(h, "temperature_2m", i, 0.0),
            apparent_temperature:       arr_f64(h, "apparent_temperature", i, 0.0),
            precipitation_probability:  arr_f64(h, "precipitation_probability", i, 0.0) as u8,
            precipitation:              arr_f64(h, "precipitation", i, 0.0),
            weather_code:   code,
            weather_text:   calculator::weather_text(code).into(),
            icon_name:      calculator::icon_name(code).into(),
            wind_speed:     arr_f64(h, "wind_speed_10m", i, 0.0),
            wind_direction: arr_f64(h, "wind_direction_10m", i, 0.0),
            wind_gusts:     arr_f64(h, "wind_gusts_10m", i, 0.0),
            humidity:       arr_f64(h, "relative_humidity_2m", i, 0.0) as u8,
            dew_point:      arr_f64(h, "dew_point_2m", i, 0.0),
            pressure:       arr_f64(h, "pressure_msl", i, 0.0),
            cloud_cover:    arr_f64(h, "cloud_cover", i, 0.0) as u8,
            visibility:     arr_f64(h, "visibility", i, 0.0),
            uv_index:       arr_f64(h, "uv_index", i, 0.0),
            is_day:         arr_f64(h, "is_day", i, 0.0) > 0.0,
        }
    }).collect();

    let dtimes = json["daily"]["time"].as_array().unwrap_or(&empty);
    let daily: Vec<Daily> = dtimes.iter().enumerate().map(|(i, t)| {
        let code = arr_f64(&json["daily"], "weather_code", i, 0.0) as u8;
        let d = &json["daily"];
        Daily {
            date: t.as_u64().unwrap_or(0),
            temp_max:       arr_f64(d, "temperature_2m_max", i, 0.0),
            temp_min:       arr_f64(d, "temperature_2m_min", i, 0.0),
            apparent_max:   arr_f64(d, "apparent_temperature_max", i, 0.0),
            apparent_min:   arr_f64(d, "apparent_temperature_min", i, 0.0),
            weather_code:   code,
            weather_text:   calculator::weather_text(code).into(),
            icon_name:      calculator::icon_name(code).into(),
            sunshine_duration: arr_f64(d, "sunshine_duration", i, 0.0),
            uv_index_max:   arr_f64(d, "uv_index_max", i, 0.0),
            humidity_mean:  arr_f64(d, "relative_humidity_2m_mean", i, 0.0) as u8,
            dew_point_mean: arr_f64(d, "dew_point_2m_mean", i, 0.0),
            pressure_mean:  arr_f64(d, "pressure_msl_mean", i, 0.0),
            cloud_cover_mean: arr_f64(d, "cloud_cover_mean", i, 0.0) as u8,
            visibility_mean: arr_f64(d, "visibility_mean", i, 0.0),
        }
    }).collect();

    (current, hourly, daily)
}

/// 从空气质量 JSON 提取所有指标
pub fn air_quality(json: &Value) -> AirQuality {
    AirQuality {
        pm10:            extract_hourly(json, "pm10"),
        pm2_5:           extract_hourly(json, "pm2_5"),
        carbon_monoxide: extract_hourly(json, "carbon_monoxide"),
        nitrogen_dioxide: extract_hourly(json, "nitrogen_dioxide"),
        sulphur_dioxide: extract_hourly(json, "sulphur_dioxide"),
        ozone:           extract_hourly(json, "ozone"),
        alder_pollen:    extract_hourly(json, "alder_pollen"),
        birch_pollen:    extract_hourly(json, "birch_pollen"),
        grass_pollen:    extract_hourly(json, "grass_pollen"),
        mugwort_pollen:  extract_hourly(json, "mugwort_pollen"),
        olive_pollen:    extract_hourly(json, "olive_pollen"),
        ragweed_pollen:  extract_hourly(json, "ragweed_pollen"),
    }
}

// ---- helpers ----

fn f64_or(v: &Value, key: &str, default: f64) -> f64 {
    v.get(key).and_then(|x| x.as_f64()).unwrap_or(default)
}

fn u8_or(v: &Value, key: &str, default: u8) -> u8 {
    v.get(key).and_then(|x| x.as_u64()).unwrap_or(default as u64) as u8
}

fn arr_f64(obj: &Value, field: &str, idx: usize, default: f64) -> f64 {
    obj.get(field)
       .and_then(|a| a.as_array())
       .and_then(|a| a.get(idx))
       .and_then(|v| v.as_f64())
       .unwrap_or(default)
}

fn extract_hourly(json: &Value, field: &str) -> Vec<HourlyValue> {
    let empty: Vec<Value> = vec![];
    let times = json["hourly"]["time"].as_array().unwrap_or(&empty);
    let values = json["hourly"][field].as_array().unwrap_or(&empty);
    times.iter().zip(values.iter())
        .map(|(t, v)| HourlyValue {
            time: t.as_u64().unwrap_or(0),
            value: v.as_f64().unwrap_or(0.0),
        })
        .collect()
}
