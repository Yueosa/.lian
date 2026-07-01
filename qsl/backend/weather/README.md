# weatherd — 天气守护进程

> ipwho.is 定位 → Open-Meteo 预报 + 空气质量 → ~/.cache/qsl/forecast.json

---

## 对外接口

**输出文件：** `~/.cache/qsl/forecast.json`（持久化，重启后复用）

JSON 结构见 `weather-rs/src/model.rs` 的 `WeatherSnapshot`。

**命令管道：** `$XDG_RUNTIME_DIR/qsl/weather_cmd`

| 命令 | 行为 |
|---|---|
| `refresh` | 立即拉取最新数据 |
| `geocode 北京` | 搜索城市 → 切换到该城市坐标 → 立即拉取 |

QML 端 `data/service/Weather.qml` 读 JSON，按需向管道发命令。

---

## 工作流程

```
1. ipwho.is → IP 定位获取初始坐标和城市名
2. api.open-meteo.com/v1/forecast → 16 天预报 + 48h 逐时 + 当前天气
3. air-quality-api.open-meteo.com → 7 天 AQI + 花粉
4. 天气代码 → 文本/图标（calculator）
5. 序列化为 JSON → 原子写入缓存文件
6. 休眠 15 分钟，检查命令管道，重复 2
```

---

## 构建

```bash
cd weather-rs && cargo build --release && cp target/release/weatherd ../build/
```
