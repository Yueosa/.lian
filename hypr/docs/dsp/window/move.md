# hl.dsp.window.move()

> 移动窗口。支持方向、工作区、显示器、像素坐标、编组操作。

- **所属:** `hl.dsp.window`
- **关联:** [[swap]], [[center]]

---

## 签名

```lua
-- 方向移动
hl.dsp.window.move({ direction = "l", group_aware?, window? })

-- 移到工作区
hl.dsp.window.move({ workspace = i, follow?, window? })

-- 移到显示器
hl.dsp.window.move({ monitor = m, follow?, window? })

-- 像素坐标
hl.dsp.window.move({ x, y, relative?, window? })

-- 编组
hl.dsp.window.move({ into_group = direction, window? })
hl.dsp.window.move({ into_or_create_group = direction, window? })
hl.dsp.window.move({ out_of_group, window? })
```

## 参数

| 参数 | 类型 | 必需 | 说明 |
|---|---|---|---|
| `direction` | string | 方向移动时 | `"l"/"r"/"u"/"d"` |
| `workspace` | 工作区选择器 | 工作区移动时 | |
| `monitor` | 显示器选择器 | 显示器移动时 | |
| `x, y` | int | 像素移动时 | |
| `relative` | bool | 像素移动时 | 是否相对当前位置 |
| `follow` | bool | 否 | 窗口是否跟随到目标工作区/显示器 |
| `group_aware` | bool | 否 | 编组感知 |
| `window` | 窗口选择器 | 否 | 默认当前 |

## 返回值

## 示例

## 注意事项

## 相关链接
