# cava — 音频频谱

> PipeWire 音频 → cava FFT → binary stdout → cava-relay 中继 → $XDG_RUNTIME_DIR/qsl/cava.bin

---

## 对外接口

**输出文件：** `$XDG_RUNTIME_DIR/qsl/cava.bin`

每帧 30 字节（每字节一个频谱柱，值 0-255），60fps 覆盖写入。

QML 端 `data/service/Cava.qml` 每 16ms 读 30 字节，零解析开销。

---

## 工作流程

```
1. cava-relay 生成 cava 配置（binary/8bit/30bars/60fps）
2. 启动 cava -p <config>
3. 循环：读 cava stdout（30 bytes/frame）→ 原子写入 cava.bin
4. cava 崩溃 → 等 1 秒 → 重启 cava
5. 退出时杀 cava + 删 cava.bin
```

---

## 构建

```bash
cd cava-rs && cargo build --release && cp target/release/cava-relay ../build/
```
