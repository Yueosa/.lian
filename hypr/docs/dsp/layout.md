# hl.dsp.layout()

> 发送消息给当前布局引擎。参数含义取决于当前布局（dwindle/scrolling/master）。

- **所属:** `hl.dsp`
- **关联:** [[config|oneapi/config]]

---

## 签名

```lua
hl.dsp.layout(message)
```

## 参数

### message（字符串）

## 返回值

## 示例

### scrolling 布局

```lua
hl.dsp.layout("move +col")  -- 移到右边列
hl.dsp.layout("move -col")  -- 移到左边列
```

## 注意事项

## 相关链接
