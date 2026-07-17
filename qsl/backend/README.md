# backend — 编译型数据源

> QML 层负责消费数据，backend/ 负责获取数据。
> 这里的模块全部使用编译型语言（C++/Rust），不依赖 QML 引擎。

---

## 原则

1. **内核级数据。** `/proc`、`/sys`、D-Bus 系统总线、HTTP API——都是 QML 不该直接碰的
2. **输出给 data/service/ 消费。** 每个 backend 模块对应一个 `data/service/` 下的薄封装
3. **构建产物留在仓库内。** `.so` / 二进制 在 `backend/<name>/build/` 下，软链到 Quickshell 能找到的位置

---

## 模块清单

### 1. sysmon — 系统监控

| 项 | 值 |
|---|---|
| 数据来源 | `/proc/stat`, `/proc/meminfo`, `/sys/class/hwmon`, `/proc/net/dev` |
| 更新频率 | 每秒 |
| 提供数据 | CPU 使用率/温度、RAM、GPU 使用率/温度、磁盘 IO、网络速率、风扇转速、系统负载 |
| 现状 | C++ 静态库 `libClavisSysmonCore.a` + QML 插件 `Clavis.Sysmon` |

**迁移方向：** C++ 代码质量不错，优先保留。检查构建系统（CMakeLists.txt），确保产物路径在 `qsl/backend/sysmon/build/`。

### 2. weather — 天气数据

| 项 | 值 |
|---|---|
| 数据来源 | Open-Meteo HTTP API (open-meteo.com) |
| 更新频率 | 按需 + 缓存（磁盘 JSON） |
| 提供数据 | 当前天气、逐时预报（48h）、逐日预报（7d）、空气质量、UV 指数、花粉 |
| 现状 | C++ 后端（openmeteo_client + weather_backend + weather_cache + weather_calculator）+ QML 插件 `Clavis.Weather` + Python 脚本（weather.py, weather_geocode.py） |

**问题：** `WeatherView.qml` 直接创建 Process 调用 `weather_geocode.py`——数据获取泄漏到了 UI 层。

**迁移方向：** 把 geocode（地名→坐标）收进 C++，所有 HTTP 请求统一走 C++ 后端。Python 脚本删除。

### 3. cava — 音频频谱

| 项 | 值 |
|---|---|
| 数据来源 | PipeWire 音频流 |
| 更新频率 | 60 FPS |
| 提供数据 | 30 根频谱柱高度值（0-100） |
| 现状 | 外部进程 `/usr/bin/cava` + `CavaService.qml` 解析 stdout 文本 |

**问题：** 60fps 文本解析在 QML 的 SplitParser 里——这是 QML 最不擅长的。每 16ms 一次字符串 split + parseInt。

**迁移方向：** Rust 重写。直接读 PipeWire，输出二进制到共享内存或 Unix socket。这是最需要重写的模块。

### 4. lyrics — 歌词获取

| 项 | 值 |
|---|---|
| 数据来源 | HTTP API（歌词源） |
| 更新频率 | 播放器换歌时触发 |
| 提供数据 | 同步/逐字歌词文本 |
| 现状 | Python 脚本 `lyrics_fetcher.py` |

**迁移方向：** 功能简单，HTTP GET + JSON 解析。Rust 改写，编译为独立二进制，通过 `data/service/Lyrics.qml` 调用。

---

## 迁移顺序

按「QML 泄漏修复优先」排列：

| 优先级 | 模块 | 理由 |
|---|---|---|
| 1 | cava | QML 做 60fps 文本解析是性能灾难 |
| 2 | weather | UI 层直接 Process 调 Python 脚本 |
| 3 | sysmon | C++ 代码完好，主要做构建路径调整 |
| 4 | lyrics | 轻量 HTTP，快速完成 |
| ~~5~~ | ~~calendar~~ | — | **降级为 QML**：纯静态 JSON，data/service/Calendar.qml |
