# clipboardctl — 剪贴板一次性适配器

> cliphist 历史 → JSON 元数据 + 受控缩略图；不常驻，被调用时跑一次

---

## 定位

历史存储、去重、持久化交给系统组件，本工具只做「取一份轻量数据给 UI」：

- `cliphist-watch.service` / `cliphist-watch-image.service`：`wl-paste --watch` 写入历史
- `wl-clip-persist.service`：源应用退出后仍能粘贴
- `clipboardctl`：把 `cliphist list` 转成 QML 好用的 JSON，并按需生成缩略图

**真源是 cliphist**；`~/.cache/qsl/clipboard-list.json` 只是 UI 秒开用的元数据缓存（preview / thumb 路径），不复制原文/原图。

---

## 命令

```bash
clipboardctl list [--limit N]   # 默认 100；stdout JSON，并写入缓存
clipboardctl paste <id> [mime]  # 把历史项重新写入 selection
clipboardctl clear              # cliphist wipe + 清空缩略图与 JSON 缓存
```

### 缓存路径

| 路径 | 内容 |
|---|---|
| `~/.cache/qsl/clipboard-list.json` | list 元数据（id/kind/mime/preview/thumb） |
| `~/.cache/qsl/clipboard-thumbs/<id>.png` | 图片缩略图，长边 ≤ 384 |

---

## 构建

```bash
cd clipboard-rs && cargo build --release && cp target/release/clipboardctl ../build/
```
