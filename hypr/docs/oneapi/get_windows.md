# hl.get_windows()

> 获取所有窗口对象列表。

- **所属:** `hl`
- **类型:** 一级方法
- **关联:** [[get_workspaces]], [[get_monitors]], [[on]]

---

## 签名

```lua
local windows = hl.get_windows()
```

## 参数

无。

## 返回值

`HL.Window[]` — 窗口对象数组。

### HL.Window 属性

| 属性 | 类型 | 说明 |
|---|---|---|
| `.address` | string | 窗口地址 |
| `.title` | string | 窗口标题 |
| `.class` | string | 窗口类名 |
| `.workspace` | HL.Workspace | 所在工作区 |
| `.monitor` | HL.Monitor | 所在显示器 |
| `.floating` | bool | 是否浮动 |
| `.pid` | int | 进程 PID |

## 示例

## 注意事项

## 相关链接
