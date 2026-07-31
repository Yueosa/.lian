# lyrics-fetch — 多源歌词获取

> 本地 .lrc → SPlayer SQLite → QQ 音乐 → 网易云 → `[{"time":s, "text":"词"}]`

---

## 对外接口

**CLI 调用：** QML 通过 Process 执行

```bash
lyrics-fetch <title> <artist> [player_name] [media_url]
```

`player_name` 须为 **playerctl 实例名**（如 `splayer.instance8090`），不要传展示用 Identity（`SPlayer` 会因大小写失败）。

**输出：** stdout JSON 数组 `[{"time": 0.0, "text": "..."}, ...]`

无结果时返回 `[{"time": 0, "text": "暂无歌词"}]`

---

## 工作流程

```
1. 媒体文件同目录 .lrc
2. ~/.lyrics/ 文件名匹配达标（无「最新文件」兜底）
3. SPlayer cache.db（BLOB；yrc JSON + LRC 混排）← player=splayer*
4. QQ 音乐 HTTP（搜多首打分）
5. 网易云 HTTP（搜多首打分）
```

网络源标题/艺人综合分 ≥ 60 才采用。

---

## 构建

```bash
cd lyrics-rs && cargo build --release && cp target/release/lyrics-fetch ../build/
```
