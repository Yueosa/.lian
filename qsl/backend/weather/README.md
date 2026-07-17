# weatherd — 天气守护进程

> ipwho.is 定位 → Open-Meteo 预报 + 空气质量 → ~/.cache/qsl/forecast.json

---

## 对外接口

**输出文件：** `~/.cache/qsl/forecast.json`（持久化，重启后复用）

JSON 结构见 `weather-rs/src/model.rs` 的 `WeatherSnapshot`。

**命令管道：** `$XDG_RUNTIME_DIR/qsl/weather_cmd`

| 命令 | 行为 |
|---|---|
| `refresh` | 软刷新：缓存未过期则跳过 |
| `refresh force` | 强制拉取（UI 刷新按钮） |
| `geocode 北京` | 搜索城市 → 结果写入 `~/.cache/qsl/geocode_results.json` |
| `set_location 39.9 116.4 北京,中国` | QML 选择结果后调用 → 持久化 + 强制刷新 |
| `reset_location` | 清除手动位置 → 恢复 IP 定位 + 强制刷新 |

定时拉取默认 15 分钟；遇 429 退避 30 分钟。软刷新最短间隔 10 分钟。

位置保存到 `~/.cache/qsl/location.json`，重启后优先使用。

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
