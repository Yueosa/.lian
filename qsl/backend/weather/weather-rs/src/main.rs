// weatherd — 天气守护进程
//
// ipwho.is 定位 → Open-Meteo 预报 + 空气质量 → ~/.cache/qsl/forecast.json
// 通过 $XDG_RUNTIME_DIR/qsl/weather_cmd 接收 reload/geocode 命令

mod config;
mod model;
mod http;
mod api;
mod calculator;
mod cache;
mod enrich;
mod daemon;

fn main() { daemon::run(); }
