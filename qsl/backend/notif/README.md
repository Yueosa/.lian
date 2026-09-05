# notifctl — 通知 SQLite 适配器

> NotificationServer → notifctl → SQLite；一次性 CLI，不常驻

## 命令

```bash
notifctl ingest '<json>'
notifctl list [--limit N]
notifctl dismiss <row_id>          # 关掉这一行
notifctl dismiss-live <notif_id>   # 关掉持有该协议 id 的最新一行
notifctl clear
```

两个 dismiss 别用混：`notif_id` 是 D-Bus 协议 id，各应用各发各的、还会复用，
库里同一个 `notif_id` 常常横跨好几个应用几十条。要关某一条就用 `list` 给出的
`id`（行号，唯一）。`dismiss-live` 只给「刚到达、还没入库拿到行号」的兜底，
所以它限定只动最新一行。

DB：`~/.local/state/qsl/notif.db`  
缓存：`~/.cache/qsl/notif-list.json`

## 构建

```bash
cd notif-rs && cargo build --release && cp target/release/notifctl ../build/
```
