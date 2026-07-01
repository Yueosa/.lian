# cava — 音频频谱

> PipeWire 音频 → FFT → 频谱柱数据

---

## 数据流

```
PipeWire 音频流
  ↓
cava (系统包)        ← C 写的成熟 DSP，做 FFT + 平滑滤波
  ↓ stdout (binary, 8bit)
cava-relay (Rust)    ← 读取 30 字节/帧，写入 /dev/shm/qsl_cava.bin
  ↓
qsl/data/service/Cava.qml  ← 读文件，暴露 values: [30]int
  ↓
UI 消费              ← 灵动岛频谱组件、Bar 波形等
```

---

## 为什么用 cava 而不是自己写 FFT

cava 提供了：
- PipeWire/PulseAudio/ALSA 多后端捕获
- FFT 频谱分析
- 6 种平滑滤波器（monstercat/integral/gravity/noise_reduction/ignore/waves）
- 自动灵敏度
- 所有参数都经过数千用户长期调优

重写 = 重复几千行 DSP 代码，且大概率做得更差。

---

## 为什么用 Rust 中继而不是 QML 解析

| | QML 解析 (旧) | Rust 中继 (新) |
|---|---|---|
| 数据格式 | ascii `"30;25;40;\n"` | binary 30 bytes/frame |
| 每秒操作 | 60 × (split + 30×parseInt) | 60 × (read + write) |
| 字符串分配 | 每秒 60 次 | 0 次 |
| CPU | QML JS 引擎 | native |

---

## cava 配置

见 `cava-rs/src/main.rs` 中的 `write_cava_config()`。
关键参数：
- `framerate = 60`
- `bars = 30`
- `data_format = binary`, `bit_format = 8bit`
- `channels = mono`, `mono_option = average`

---

## 构建

```bash
cd qsl/backend/cava/cava-rs
cargo build --release
cp target/release/cava-relay ../build/cava-relay
```
