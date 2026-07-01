# cava — 音频频谱

PipeWire 音频 → cava FFT → binary stdout → cava-relay 中继 → /dev/shm/qsl_cava.bin

- cava-relay 启动 cava（binary 输出，30 柱，60fps，8bit），读 stdout 写入共享内存文件
- cava 崩溃自动重启
- QML 端 `data/service/Cava.qml` 读 /dev/shm/qsl_cava.bin（30 字节/帧，零解析开销）

构建：`cd cava-rs && cargo build --release && cp target/release/cava-relay ../build/`
