# hl.dsp.window

> 窗口相关的全部 dispatcher。是 `hl.dsp` 下最大的子命名空间。

- **所属:** `hl.dsp`
- **关联:** [[focus]], [[workspace]], [[group]]

---

## 方法索引

| 方法 | 文件 | 说明 |
|---|---|---|
| `.close()` | [[close]] | 优雅关闭窗口 |
| `.kill()` | [[kill]] | 强杀窗口 (SIGKILL) |
| `.signal()` | [[signal]] | 发送 POSIX 信号 |
| `.float()` | [[float]] | 切换浮动/嵌入 |
| `.fullscreen()` | [[fullscreen]] | 全屏/最大化 |
| `.fullscreen_state()` | [[fullscreen_state]] | 精确全屏状态控制 |
| `.pseudo()` | [[pseudo]] | 伪平铺 |
| `.move()` | [[move]] | 移动窗口（方向/工作区/显示器/坐标/编组） |
| `.swap()` | [[swap]] | 与相邻窗口交换位置 |
| `.center()` | [[center]] | 窗口居中 |
| `.cycle_next()` | [[cycle_next]] | 聚焦下一个窗口 |
| `.tag()` | [[tag]] | 打标签 |
| `.clear_tags()` | [[clear_tags]] | 清除标签 |
| `.toggle_swallow()` | [[toggle_swallow]] | 切换窗口吞噬可见性 |
| `.pin()` | [[pin]] | 固定浮动窗口到所有工作区 |
| `.alter_zorder()` | [[alter_zorder]] | 修改 Z 序 |
| `.set_prop()` | [[set_prop]] | 动态设置窗口属性 |
| `.deny_from_group()` | [[deny_from_group]] | 阻止窗口进入编组 |
| `.drag()` | [[drag]] | 鼠标拖拽 |
| `.resize()` | [[resize]] | 鼠标调整大小 / 像素级调整 |

## 相关链接

- Wiki Dispatchers: https://wiki.hyprland.org/Configuring/Basics/Dispatchers/
