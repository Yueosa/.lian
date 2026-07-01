# weatherd — 天气守护进程

ipwho.is 定位 → Open-Meteo 预报 + 空气质量 → 计算衍生字段 → ~/.cache/qsl/forecast.json

- `weatherd` 启动后循环刷新（15 分钟间隔）
- 通过 `$XDG_RUNTIME_DIR/qsl/weather_cmd` 接收命令：`refresh` / `geocode <城市>`
- QML 端 `data/service/Weather.qml` 读缓存 JSON

构建：`cd weather-rs && cargo build --release && cp target/release/weatherd ../build/`
