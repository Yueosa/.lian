# 恋的 Arch 配置

> 我使用的桌面环境是 `Hyprland` + `wayland` + `kitty` + `zshell`

如果你的环境和我一样, 可以直接抄作业!

---

## 说明:

这个文档会详细的说明我的每一个目录配置, 你可以直接下载到 `~/.config/` 下使用

#### fastfetch

这是一个在终端打印输出系统信息的包, 效果如下:

![fastfetch](./image/fastfetch)

###### 你可以使用 `pacman` 进行安装:

```bash
sudo pacmna -S fastfetch
```

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

#### kanshi

这是一个智能的显示器管理器, 如果你有多个显示器, 用他来管理是个很不错的方案!

###### 使用 `pacman` 进行安装

```bash
sudo pacman -S kanshi
```

我推荐你直接在 `~/.config/hypr/hyprland.conf` 中加入 `exec-once = kanshi` 来启动他

我的配置文件只有一个, 内容如下:

```ini
profile {
	output eDP-1 enable mode 2560x1440@165 position 0,0
}

profile {
	output eDP-1 disable
	output HDMI-A-1 enable mode 1920x1080@180 position 0,0
}
```

我有笔记本显示器 `eDP-1` 和外接显示器 `HDMI-A-1`, 策略是有外接显示器时笔记本就熄屏

#### kitty

`kitty` 是一个支持 真彩色, 光标拖尾, 更强控制序列的终端

###### 使用 `pacman` 安装

```bash
sudo pacman -S kitty
```

我的配置文件非常简单, 我使用 `kitty-theme` 挑选了自己喜欢的主题, 然后自己配置了一些 字体, 光标拖尾

```
 kitty
├── 󱁻 current-theme.conf    # 终端主题
├── 󱁻 dark-theme.auto.conf
└── 󱁻 kitty.conf            # 配置文件
```

如果你想要安装我的字体

```bash
sudo pacman -S ttf-fira-code
```

这是一款非常适合编程的字体, 支持连字


