# sysmond — 系统监控守护进程

> /proc /sys / nvidia-smi → 分级轮询 → $XDG_RUNTIME_DIR/qsl/sysmon.json

---

## 对外接口

**输出文件：** `$XDG_RUNTIME_DIR/qsl/sysmon.json`

```json
{
  "cpu_percent": 8.2,
  "memory": { "used_gb": 8.07, "total_gb": 15.35, "percent": 52.5, "app_gb": 6.2, "cache_gb": 4.1, "swap_used_gb": 0.34, "swap_total_gb": 16.0 },
  "network": { "down_bps": 4716, "up_bps": 3205, "iface": "wlo1" },
  "thermal": { "cpu_package": 75, "cpu_hottest_core": 75, "ssd": 50.9, "wifi": 60 },
  "gpu": { "available": true, "temp": 56, "usage_percent": 32, "memory_used_mb": 1063, "memory_total_mb": 8188, "power_watts": 12.3 },
  "load": { "load1": 0.75, "load5": 0.77, "load15": 0.95 },
  "disk": { "used_gb": 243.8, "total_gb": 915.0, "percent": 26.6 },
  "uptime_secs": 20232
}
```

**命令管道：** `$XDG_RUNTIME_DIR/qsl/sysmon_cmd`

| 命令 | 输出文件 |
|---|---|
| `process_list` | `sysmon_process.json`（top 50 进程） |
| `process_detail <pid>` | `sysmon_detail_<pid>.json` |

---

## 与 qsl UI 的约定

- QML 服务：`qsl/data/service/Sysmon.qml`
- **开 System 页时**会 `ensureDaemon()`：若无 `sysmond` 进程，则后台拉起 `backend/sysmon/build/sysmond`
- 关页停止进程轮询并清空列表；快照文件仍可被 daemon 更新，但 UI 不再 watch
- 电池走 UPower `Battery.qml`，不经本 daemon
- 可选常驻：把 `build/sysmond` 链到 `~/.local/bin` 并挂 user systemd；非必须（开页自启即可）

---

## 工作流程

```
1s:  CPU (/proc/stat 差分), Net (/proc/net/dev 差分)
2s:  RAM/Swap (/proc/meminfo), Thermal (/sys/class/hwmon), GPU (nvidia-smi)
5s:  Load (/proc/loadavg)
30s: Disk (statvfs), Uptime (/proc/uptime)
启动: 全部采样一次，避免初始零值
进程: 按需响应（通过命令管道）
```

---

## 构建

```bash
cd sysmon-rs && cargo build --release && cp target/release/sysmond ../build/
```
