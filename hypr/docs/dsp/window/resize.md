# hl.dsp.window.resize()

> 鼠标调整窗口大小 / 像素级精确调整。

- **所属:** `hl.dsp.window`
- **关联:** [[drag]]

---

## 签名

```lua
-- 鼠标调整
hl.dsp.window.resize()
hl.dsp.window.resize({ keep_aspect_ratio })

-- 像素级调整
hl.dsp.window.resize({ x, y, relative?, window? })
```

## 参数

## 示例

```lua
-- Super+右键调整大小
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })
```

## 注意事项

- 鼠标调整必须配合 `{ mouse = true }`。

## 相关链接
