# hl.get_monitors()

> 获取所有显示器对象列表。

- **所属:** `hl`
- **类型:** 一级方法
- **关联:** [[get_windows]], [[get_workspaces]], [[monitor]]

---

## 签名

```lua
local monitors = hl.get_monitors()
```

## 参数

无。

## 返回值

`HL.Monitor[]` — 显示器对象数组。

### HL.Monitor 属性

| 属性 | 类型 | 说明 |
|---|---|---|
| `.id` | int | 显示器编号 |
| `.name` | string | 显示器名称（如 `DP-1`） |
| `.width` | int | 宽度（像素） |
| `.height` | int | 高度（像素） |
| `.refresh_rate` | float | 刷新率（Hz） |
| `.active_workspace` | HL.Workspace | 当前活跃工作区 |

## 示例

## 注意事项

## 相关链接
