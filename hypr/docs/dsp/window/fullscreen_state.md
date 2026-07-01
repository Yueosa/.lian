# hl.dsp.window.fullscreen_state()

> 精确控制窗口的全屏/最大化状态。

- **所属:** `hl.dsp.window`
- **关联:** [[fullscreen]]

---

## 签名

```lua
hl.dsp.window.fullscreen_state({ internal, client, action?, window? })
```

## 参数

| 参数 | 类型 | 必需 | 说明 |
|---|---|---|---|
| `internal` | int | 是 | -1=保持, 0=无, 1=最大化, 2=全屏, 3=两者 |
| `client` | int | 是 | 同上 |
| `action` | string | 否 | `"toggle"` / `"set"` / `"unset"` |
| `window` | 窗口选择器 | 否 | 默认当前 |

## 返回值

## 示例

## 注意事项

## 相关链接
