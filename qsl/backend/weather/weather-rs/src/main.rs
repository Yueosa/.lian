// weatherd — 天气守护进程
mod config;
mod model;
mod http;
mod api;
mod calculator;
mod cache;
mod daemon;

fn main() { daemon::run(); }
