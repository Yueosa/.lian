# hl.get_workspaces()

> 获取所有工作区对象列表。

- **所属:** `hl`
- **类型:** 一级方法
- **关联:** [[get_windows]], [[get_monitors]]

---

## 签名

```lua
local workspaces = hl.get_workspaces()
```

## 参数

无。

## 返回值

`HL.Workspace[]` — 工作区对象数组。

### HL.Workspace 属性

| 属性 | 类型 | 说明 |
|---|---|---|
| `.id` | int | 工作区编号 |
| `.name` | string | 工作区名称 |
| `.monitor` | HL.Monitor | 所在显示器 |
| `.windows` | HL.Window[] | 工作区内的窗口 |
| `.is_special` | bool | 是否为特殊工作区 |

## 示例

## 注意事项

## 相关链接
