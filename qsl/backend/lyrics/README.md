# lyrics-fetch — 多源歌词获取

> 本地 .lrc → SPlayer SQLite → QQ 音乐 → 网易云 → `[{"time":s, "text":"词"}]`

---

## 对外接口

**CLI 调用：** QML 通过 Process 执行

```bash
lyrics-fetch <title> <artist> [player_name] [media_url]
```

**输出：** stdout JSON 数组 `[{"time": 0.0, "text": "作词 : 张安缇"}, ...]`

无结果时返回 `[{"time": 0, "text": "暂无歌词"}]`

---

## 工作流程

```
1. 媒体文件同目录 .lrc            ← 最快，毫秒
2. ~/.lyrics/ 文件名模糊匹配      ← 本地，毫秒
3. SPlayer cache.db SQLite       ← 本地数据库，毫秒（仅当 player=splayer）
4. QQ 音乐 HTTP API              ← 网络，秒级
5. 网易云音乐 HTTP API            ← 网络，秒级
```

---

## 构建

```bash
cd lyrics-rs && cargo build --release && cp target/release/lyrics-fetch ../build/
```
