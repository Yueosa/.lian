# notifctl — 通知 SQLite 适配器

> NotificationServer → notifctl → SQLite；一次性 CLI，不常驻

## 命令

```bash
notifctl ingest '<json>'
notifctl list [--limit N]
notifctl dismiss <notif_id>
notifctl clear
```

DB：`~/.local/state/qsl/notif.db`  
缓存：`~/.cache/qsl/notif-list.json`

## 构建

```bash
cd notif-rs && cargo build --release && cp target/release/notifctl ../build/
```
