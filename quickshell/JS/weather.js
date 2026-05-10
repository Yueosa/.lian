.pragma library

function fetchLocationAndWeather(callback) {
    var locXhr = new XMLHttpRequest();
    locXhr.timeout = 5000; // 强制 5 秒超时设置

    locXhr.onreadystatechange = function() {
        if (locXhr.readyState === XMLHttpRequest.DONE) {
            if (locXhr.status === 200) {
                try {
                    var locData = JSON.parse(locXhr.responseText);
                    if (locData.success === false) {
                        callback(null); // API 报错，返回 null
                        return;
                    }

                    var lat = locData.latitude;
                    var lon = locData.longitude;
                    var cityStr = locData.city;
                    if (!cityStr || cityStr.trim() === "") cityStr = locData.region;
                    if (!cityStr || cityStr.trim() === "") cityStr = locData.country;
                    if (!cityStr || cityStr.trim() === "") cityStr = "UNKNOWN";

                    fetchWeatherAPI(lat, lon, cityStr.toUpperCase(), callback);
                } catch(e) {
                    console.log("Location Parse Error:", e);
                    callback(null); // 解析失败，返回 null
                }
            } else {
                console.log("Location Network Error:", locXhr.status);
                callback(null); // 状态码非 200，返回 null
            }
        }
    }
    
    // 捕获底层网络断开和超时
    locXhr.onerror = function() { console.log("Location XHR Error"); callback(null); }
    locXhr.ontimeout = function() { console.log("Location XHR Timeout"); callback(null); }

    locXhr.open("GET", "https://ipwho.is/?t=" + new Date().getTime(), true);
    locXhr.send();
}

function fetchWeatherAPI(lat, lon, city, callback) {
    var url = "https://api.open-meteo.com/v1/forecast?latitude=" + lat + "&longitude=" + lon + 
              "&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,wind_speed_10m,surface_pressure" + 
              "&hourly=temperature_2m,weather_code" + 
              "&daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=auto";
              
    var xhr = new XMLHttpRequest();
    xhr.timeout = 5000; // 天气请求同样增加 5 秒超时

    xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
            if (xhr.status === 200) {
                var data = JSON.parse(xhr.responseText);
                data.locName = city;
                data.lat = lat;
                data.lon = lon;
                callback(data);
            } else {
                console.log("Weather API Network Error:", xhr.status);
                callback(null);
            }
        }
    }
    
    // 捕获天气接口的网络异常
    xhr.onerror = function() { console.log("Weather XHR Error"); callback(null); }
    xhr.ontimeout = function() { console.log("Weather XHR Timeout"); callback(null); }

    xhr.open("GET", url, true);
    xhr.send();
}

function getMaterialIcon(code) {
    if (code === 0) return "sunny";
    if (code === 1 || code === 2) return "partly_cloudy_day";
    if (code === 3) return "cloudy";
    if (code === 45 || code === 48) return "foggy";
    if (code >= 51 && code <= 67) return "rainy";
    if (code >= 71 && code <= 82) return "snowing";
    if (code >= 95) return "thunderstorm";
    return "cloud";
}

function getWeatherDesc(code) {
    var mapping = {
        0: "Clear", 1: "Mainly Clear", 2: "Partly Cloudy", 3: "Overcast",
        45: "Fog", 48: "Rime Fog", 51: "Drizzle", 61: "Rain", 71: "Snow", 95: "Storm"
    };
    return mapping[code] || "Cloudy";
}

// ============================================================
// 通用纯函数: 数值校验 / 格式化 / UV / 风 / 方位 / AQI / 能见度
// 多个 *TrendCard / *TrendPane / WeatherView 共用, 集中在此, 禁止再就地复制
// ============================================================

function validNumber(v) { return v !== undefined && v !== null && !isNaN(v); }

function fmtTemp(v)        { return validNumber(v) ? Math.round(v) + "°"               : "--"; }
function fmtTempPlain(v)   { return validNumber(v) ? Math.round(v).toString()          : "--"; }
function fmtSpeed(ms)      { return validNumber(ms) ? ms.toFixed(1) + " m/s"           : "--"; }
function fmtPercent(v)     { return validNumber(v) ? Math.round(v) + "%"               : "--"; }
function fmtDistance(m)    { return validNumber(m) ? (m / 1000).toFixed(1) + " km"     : "--"; }
function fmtTime(epoch)    { return epoch ? Qt.formatDateTime(new Date(epoch*1000), "hh:mm") : "--"; }

function dayLabel(index, epoch) {
    if (index === 0) return "Today";
    if (index === 1) return "Tomorrow";
    return epoch ? Qt.formatDateTime(new Date(epoch*1000), "ddd") : "--";
}

function uvLevel(v) {
    if (!validNumber(v)) return "--";
    if (v < 3) return "低"; if (v < 6) return "中"; if (v < 8) return "高";
    if (v < 11) return "很高"; return "极高";
}
function uvIndexBucket(v) {
    if (!validNumber(v)) return -1;
    if (v < 3) return 0; if (v < 6) return 1; if (v < 8) return 2;
    if (v < 11) return 3; return 4;
}

function windAccent(ms) {
    if (!validNumber(ms)) return "#4d8d7b";
    if (ms < 4)  return "#72d572"; if (ms < 6)  return "#ffca28";
    if (ms < 8)  return "#ffa726"; if (ms < 10) return "#e52f35";
    if (ms < 12) return "#99004c"; return "#7e0023";
}

function directionLabel(deg) {
    if (!validNumber(deg)) return "--";
    var n = ((deg % 360) + 360) % 360;
    if (n < 22.5 || n >= 337.5) return "N";
    if (n < 67.5)  return "NE"; if (n < 112.5) return "E";
    if (n < 157.5) return "SE"; if (n < 202.5) return "S";
    if (n < 247.5) return "SW"; if (n < 292.5) return "W";
    return "NW";
}

function visibilityDescription(meters) {
    if (!validNumber(meters)) return "--";
    var km = meters / 1000;
    if (km >= 16) return "Crystal clear"; if (km >= 10) return "Clear";
    if (km >= 6)  return "Good";          if (km >= 3)  return "Hazy";
    if (km >= 1)  return "Low";           return "Dense";
}

function pressureValueText(v) {
    return validNumber(v) ? Number(v).toLocaleString(Qt.locale(), "f", 1) : "--";
}

function humidityWaveAccent() { return "#625985"; }

// AQI: thresholds 是该污染物各级浓度上限 (ug/m3 或 ppm), aqi 数组是统一刻度
var AQI_INDEX_BREAKPOINTS = [0, 20, 50, 100, 150, 250];
function aqiThresholds() { return AQI_INDEX_BREAKPOINTS; }

function pollutantIndex(value, thresholds) {
    if (!validNumber(value)) return NaN;
    var level = -1;
    for (var i = 0; i < thresholds.length; ++i)
        if (value >= thresholds[i]) level = i;
    if (level < 0) return NaN;
    var aqi = AQI_INDEX_BREAKPOINTS;
    if (level < thresholds.length - 1) {
        var bpLo = thresholds[level], bpHi = thresholds[level + 1];
        var inLo = aqi[level],        inHi = aqi[level + 1];
        return Math.round(((inHi - inLo) / (bpHi - bpLo)) * (value - bpLo) + inLo);
    }
    return Math.round((value * aqi[aqi.length - 1]) / thresholds[thresholds.length - 1]);
}

function aqiLevelIndex(v) {
    if (!validNumber(v)) return -1;
    var t = AQI_INDEX_BREAKPOINTS, lvl = 0;
    for (var i = 0; i < t.length; ++i) if (v >= t[i]) lvl = i;
    return Math.min(lvl, 5);
}

var AQI_PALETTE = ["#00e59b", "#ffc302", "#ff712b", "#f62a55", "#c72eaa", "#9930ff"];
var AQI_NAMES   = ["优", "良", "差", "不健康", "很不健康", "危险"];
function aqiPalette(level) { return AQI_PALETTE[Math.max(0, Math.min(AQI_PALETTE.length - 1, level))]; }
function aqiLevelName(level) { return (level < 0 || level >= AQI_NAMES.length) ? "--" : AQI_NAMES[level]; }

// 中文版日历标签 (DailyAirQuality / DailyWind / DailyForecast 趋势卡共用)
var WEEK_CN = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"];
function dayLabelCN(index, epoch) {
    if (index === 0) return "昨天";
    if (index === 1) return "今天";
    if (index === 2) return "明天";
    return epoch ? WEEK_CN[new Date(epoch * 1000).getDay()] : "--";
}
