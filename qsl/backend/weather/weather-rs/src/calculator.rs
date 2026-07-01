// 天气代码 → 文本描述 / 图标名称
// 参考 WMO 天气代码标准

pub fn weather_text(code: u8) -> &'static str {
    match code {
        0 => "Clear",
        1 => "Mainly clear",
        2 => "Partly cloudy",
        3 => "Overcast",
        45 | 48 => "Fog",
        51 | 53 | 55 => "Drizzle",
        56 | 57 => "Freezing drizzle",
        61 | 63 | 65 => "Rain",
        66 | 67 => "Freezing rain",
        71 | 73 | 75 => "Snow",
        77 => "Snow grains",
        80 | 81 | 82 => "Showers",
        85 | 86 => "Snow showers",
        95 => "Thunderstorm",
        96 | 99 => "Thunderstorm with hail",
        _ => "Unknown",
    }
}

pub fn icon_name(code: u8) -> &'static str {
    match code {
        0 => "clear_day",
        1 | 2 => "partly_cloudy_day",
        3 => "cloudy",
        45 | 48 => "fog",
        51..=67 | 80..=82 => "rainy",
        71..=77 | 85 | 86 => "snowy",
        95..=99 => "thunderstorm",
        _ => "cloudy",
    }
}
