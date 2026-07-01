# hl.dsp.window.kill()

> 强杀窗口 (SIGKILL)。不经过应用，直接终止进程。

- **所属:** `hl.dsp.window`
- **关联:** [[close]], [[signal]]

---

## 签名

```lua
hl.dsp.window.kill(window?)
```

## 参数

## 返回值

## 示例

## 注意事项

- 与 `.close()` 的区别：`.close()` 请求应用退出，`.kill()` 直接杀进程。
- 可能导致未保存数据丢失。

## 相关链接
