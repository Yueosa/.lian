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
    /// 15 分钟粒度降水临近预报。旧缓存没有这个字段，故 default。
    #[serde(default)]
    pub minutely: Vec<MinutelyPoint>,
}

/// 降水临近预报的一个时间点。回答的是「接下来这几十分钟会不会下」，
/// 逐小时预报答不了——一小时里前 15 分钟下和后 15 分钟下是两回事。
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct MinutelyPoint {
    pub time: u64,
    pub precipitation: f64,
    pub precipitation_probability: u8,
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

// ============================================================
// 瘦身快照 — 只给 QML 看的那一份
// ============================================================
// 完整 forecast.json 有 221 KB（hourly 408 条 × 18 字段、air_quality
// 12 个数组 × 192 点），而天气页真正读的不到 3%。每次开页 / 刷新都让
// QV4 嚼一遍 221 KB、分配两千多个转手就丢的对象，纯属白烧 GC。
// 完整数据仍原样缓存在 forecast.json（换 UI 时不必重抓），
// QML 只解析这份瘦的。

#[derive(Debug, Clone, Serialize)]
pub struct SlimSnapshot {
    pub status: String,
    pub location_name: String,
    pub latitude: f64,
    pub longitude: f64,
    pub last_updated: u64,
    pub current: SlimCurrent,
    pub hourly: Vec<SlimHourly>,
    pub daily: Vec<SlimDaily>,
    pub air: SlimAir,
    /// 只带未来的点；已经过去的 15 分钟对「等下要不要带伞」没有意义
    pub minutely: Vec<MinutelyPoint>,
}

// 字段名与完整版保持一致，QML 侧的解析逻辑不用跟着改
#[derive(Debug, Clone, Serialize, Default)]
pub struct SlimCurrent {
    pub temperature: f64,
    pub apparent_temperature: f64,
    pub weather_code: u8,
    pub weather_text: String,
    pub icon_name: String,
    pub wind_speed: f64,
    pub humidity: u8,
    pub pressure: f64,
    pub uv_index: f64,
    pub wind_direction: f64,
    /// 近 3 小时气压变化（hPa）。绝对值 1011 说明不了什么，
    /// 但「3 小时掉了 2 hPa」是天气转坏的经典信号。
    pub pressure_trend: f64,
}

#[derive(Debug, Clone, Serialize, Default)]
pub struct SlimHourly {
    pub time: u64,
    pub temperature: f64,
    pub precipitation_probability: u8,
    pub precipitation: f64,
    pub weather_code: u8,
    pub icon_name: String,
    pub is_day: bool,
}

#[derive(Debug, Clone, Serialize, Default)]
pub struct SlimDaily {
    pub date: u64,
    pub temp_max: f64,
    pub temp_min: f64,
    pub weather_code: u8,
    pub icon_name: String,
    pub uv_index_max: f64,
}

#[derive(Debug, Clone, Serialize, Default)]
pub struct SlimAir {
    pub pm2_5: f64,
    pub pm10: f64,
    /// 是否真的取到了值——全 0 既可能是好空气也可能是没数据，得分清
    pub available: bool,
}

/// 未来要保留的小时数。页面当前只画 12 条，多留一倍给降水图和以后的 24h 视图，
/// 代价是几 KB。
const SLIM_HOURS: usize = 24;
const SLIM_DAYS: usize = 7;
/// 8 × 15min = 2 小时，够回答「等下出门要不要带伞」
const SLIM_MINUTELY: usize = 8;

/// 在按小时排列的序列里取「离现在最近且不晚于现在」的那个值，
/// 没有就退回第一个。
fn value_at_now(series: &[HourlyValue], now: u64) -> Option<f64> {
    if series.is_empty() {
        return None;
    }
    let mut best: Option<&HourlyValue> = None;
    for p in series {
        if p.time <= now && best.map_or(true, |b| p.time > b.time) {
            best = Some(p);
        }
    }
    Some(best.unwrap_or(&series[0]).value)
}

impl WeatherSnapshot {
    pub fn slim(&self, now: u64) -> SlimSnapshot {
        // 从当前小时开始截，之前的小时对「接下来会不会下雨」没有意义
        let start = self
            .hourly
            .iter()
            .position(|h| h.time >= now)
            .unwrap_or(0);

        let pm2_5 = value_at_now(&self.air_quality.pm2_5, now);
        let pm10 = value_at_now(&self.air_quality.pm10, now);

        SlimSnapshot {
            status: self.status.clone(),
            location_name: self.location_name.clone(),
            latitude: self.latitude,
            longitude: self.longitude,
            last_updated: self.last_updated,
            current: SlimCurrent {
                temperature: self.current.temperature,
                apparent_temperature: self.current.apparent_temperature,
                weather_code: self.current.weather_code,
                weather_text: self.current.weather_text.clone(),
                icon_name: self.current.icon_name.clone(),
                wind_speed: self.current.wind_speed,
                humidity: self.current.humidity,
                pressure: self.current.pressure,
                uv_index: self.current.uv_index,
                wind_direction: self.current.wind_direction,
                // hourly 带 past_days=1，往回退 3 小时取得到
                pressure_trend: {
                    let past = self
                        .hourly
                        .iter()
                        .filter(|h| h.time <= now.saturating_sub(3 * 3600))
                        .next_back()
                        .map(|h| h.pressure)
                        .unwrap_or(0.0);
                    if past > 0.0 && self.current.pressure > 0.0 {
                        self.current.pressure - past
                    } else {
                        0.0
                    }
                },
            },
            hourly: self
                .hourly
                .iter()
                .skip(start)
                .take(SLIM_HOURS)
                .map(|h| SlimHourly {
                    time: h.time,
                    temperature: h.temperature,
                    precipitation_probability: h.precipitation_probability,
                    precipitation: h.precipitation,
                    weather_code: h.weather_code,
                    icon_name: h.icon_name.clone(),
                    is_day: h.is_day,
                })
                .collect(),
            daily: self
                .daily
                .iter()
                .take(SLIM_DAYS)
                .map(|d| SlimDaily {
                    date: d.date,
                    temp_max: d.temp_max,
                    temp_min: d.temp_min,
                    weather_code: d.weather_code,
                    icon_name: d.icon_name.clone(),
                    uv_index_max: d.uv_index_max,
                })
                .collect(),
            air: SlimAir {
                pm2_5: pm2_5.unwrap_or(0.0),
                pm10: pm10.unwrap_or(0.0),
                available: pm2_5.is_some() || pm10.is_some(),
            },
            // 保留当前所处的那一格（time <= now 的最后一个），
            // 否则刚过整点时会丢掉"现在正在下"这个信息
            minutely: {
                let start = self
                    .minutely
                    .iter()
                    .rposition(|p| p.time <= now)
                    .unwrap_or(0);
                self.minutely
                    .iter()
                    .skip(start)
                    .take(SLIM_MINUTELY)
                    .cloned()
                    .collect()
            },
        }
    }
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
