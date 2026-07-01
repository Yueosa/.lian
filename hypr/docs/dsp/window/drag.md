# hl.dsp.window.drag()

> 鼠标拖拽窗口。必须配合 `{ mouse = true }` 标志使用。

- **所属:** `hl.dsp.window`
- **关联:** [[resize]]

---

## 签名

```lua
hl.dsp.window.drag()
```

## 参数

无。

## 示例

```lua
-- Super+左键拖拽窗口
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
```

## 注意事项

- 必须设置 `{ mouse = true }`，否则不生效。
- `mouse:272` = 左键，`mouse:273` = 右键。

## 相关链接
