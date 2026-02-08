# 恋的 Arch 配置

---

## 说明:

这个文档会详细的说明我的每一个目录配置, 你可以直接下载到 `~/.config/` 下使用

#### fastfetch

这是一个在终端打印输出系统信息的包, 效果如下:

![fastfetch](./image/fastfetch)

我的配置目录如下:

```
 fastfetch
├──  config.jsonc              # 基本的样式配置
├──  logo                      # 存放 logo 图片的目录
└──  scripts
    ├──  fastfetch-age.sh      # 获取系统使用时间的脚本
    ├──  fastfetch-ip.sh       # 获取系统 IP 地址的脚本
    └──  fastfetch-logo.sh     # 从 logo/ 目录中抽图片
```

* 如果你想使用默认的logo, 那么直接删除 `logo/` 目录即可
* 系统使用时间我在脚本里硬编码了从 `2025-05-12` 日开始计算, 你可以自己更改



