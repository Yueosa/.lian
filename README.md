# 恋的 Arch 配置

> 我使用的桌面环境是 `Hyprland` + `wayland` + `kitty` + `zshell`

如果你的环境和我一样, 可以直接抄作业!

---

#### 说明:

这个文档会详细的说明我的每一个目录配置, 你可以直接下载到 `~/.config/` 下使用

## | fastfetch

这是一个在终端打印输出系统信息的包, 效果如下:

![fastfetch](./image/fastfetch.png)

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

## | fcitx5

`fcitx5` 是最出名的输入法框架, 我的配置里使用了 `rime` 输入引擎, 以及 `rime-ice` 雾凇拼音输入方案

```bash
sudo pacman -S fcitx5 fcitx5-configtool fcitx5-gtk fcitx5-qt fcitx5-rime
paru -S rime-ice-git
```

将我的配置文件放入 `~/.local/share/fcitx5/rime/default.custom.yaml`

他只有一个目的: 取消 `rime` 默认的 `Shift` 切换中英文

##### 我推荐你直接使用 `fcitx5` 级别的切换中英, 输入 `fcitx5-configtool` 打开图形化配置页面 (或自己编辑配置文件)

1. 确保 **当前输入法列表** 中包含: `键盘 - 英语 (美国)` 和 `中州韵 (Rime)`
2. 在 **全局选项** 里, 配置 切换输入法 的快捷键

##### 关于 `fcitx5` 主题

我使用的主题是 [ayaya](https://github.com/witt-bit/fcitx5-theme-ayaya), 这里不做详细教学

![fcitx5-theme-ayaya](./image/fcitx5.png)

## | kanshi

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

## | kitty

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

## | rofi

`rofi` 是一款应用程序启动器, 我用它做了应用启动菜单, 窗口切换菜单, 剪贴板

| 应用启动菜单 | 剪贴板 |
|-|-|
| ![rofiapp](./image/rofi1.png) | ![clipboard](./image/rofi3.png) |

###### 使用 `pacman` 安装

```bash
sudo pacman -S rofi-wayland
```

##### 我的目录结构如下

```
 rofi
├──  clipboard.rasi        # 剪贴板 窗口主题
├──  cliphist_rofi.sh      # 启动 剪贴板 脚本
├──  images
│   └──  pln.jpeg          # logo
├──  sakurine.rasi         # app, window 窗口主题
└──  scripts
    └──  rofi-launcher.sh  # 启动 app, window 窗口脚本
```

如果你要使用剪贴板脚本的话, 还需要安装以下包:

```bash
sudo pacman -S cliphist wl-clipboard imagemagick papirus-icon-theme ttf-jetbrains-mono-nerd xdg-utils
```

* `cliphist`: 剪贴板历史
* `wl-clipboard`: 写入剪贴板 (提供 `wl-copy`)
* `imagemagick`: 提供 `magick/convert` (没装也能用, 只是二进制图片预览可能不生成缩略图)
* `papirus0icon-theme`: 图标主题
* `ttf-jetbrains-mono-nerd`: 字体
* `xdg-utils`: 提供 `xdg-open`

## | swaync

`swaync` 是一个通知中心, 他通过监听 `D-Bus` 来获得实时的消息显示

| 通知弹窗 | 通知中心 |
|-|-|
| ![swaync](./image/swaync1.png) | ![swayncclient](./image/swaync2.png) |

###### 使用 `paru` 安装

```bash
paru -S swaync
```

我的配置文件非常简单, 直接 `cp` 就可以使用

## | hyprlock

`hyprlock` 是一个简单的锁屏软件

![hyprlock](./image/hyprlock.jpg)

###### 使用 `pacman` 安装

```bash
sudo pacman -S hyprlock
```

如果你想要获得和我一样的效果, 还需要安装这个字体:

```bash
sudo pacman -S ttf-jetbrains-mono-nerd
```

## | wlogout

`wlogout` 提供了一个电源管理页面, 我的配置里分别是 `锁屏` `登出` `关机` `重启`

![wlogout](./image/wlogout.png)

###### 使用 `pacman` 安装

```bash
sudo pacman -S --needed wlogout jq gettext procps-ng
```

锁屏功能 依赖 `hyprlock` 运行, 关机功能则依赖于 `hyprland`

```
 .
├──  icons                 # 图标
├── 󰡯 layout                # 布局
├──  scripts
│   ├──  logoutlaunch.sh
│   └──  wlogout.sh
└──  style.css
```

## | Hyprland

本次配置的重头戏之一, `hyprland` 是我心目中最 **linux** 的桌面环境

###### 使用 `pacman` 安装 (可能会漏掉一些包, 请以 hypr.land 为准)

```bash
sudo pacman -S hyprland xdg-desktop-portal-hyprland xdg-desktop-portal-gtk qt5-wayland qt6-wayland polkit-gnome
```

* `hyprland`: 混成器, 充当窗口管理器, 也是显示服务器
* `xdg-desktop-portal-hyprland`: Hyprland 与 应用 沟通的桥梁
* `xdg-desktop-portal-gtk`: 提供文件选择对话框
* `qt5/6-wayland`: 让基于 qt 框架的应用能跑在 wayland 上 
* `polkit-gnome`: 当你执行需要 sudo 权限的 gui 应用时跳出弹窗

关于 `hyprland` 配置详解, 可以直接 [跳转](./hypr/hyprland.conf) 查看注释, 但这里还是做一个简单介绍

* **修复区:** 这里定义了一些杂项修复
* **窗口规则:** 定义了窗口弹出时的行为, 例如浮动模式弹出, 弹出时的窗口大小 ...
* **NVIDIA:** NVIDIA 显卡的修复, 如果你刚开始觉得渲染网页, 调度GPU卡顿是正常的, 几天后还卡顿那就不正常了(
* **QT变量:** 为了让 QT 高效运行在 wayland 高分屏上的配置
* **全局变量:** hyprland 的配置文件支持使用变量, 建议把你常用的目录全部定义为变量 (例如截图保存目录, 脚本目录)
* **自动启动:** 随着 hyprland 一起启动的软件
* **窗口外观:** 定义窗口的圆角, 边框, 颜色, 动画 ...
* **快捷键:** 这部分建议直接抄作业

你可以直接把 配置文件 丢给 AI 问, 如果有一些软件 AI 不认识 (比如 `lianwall`), 那是正常的

因为这些是我自己写的软件, 在我的 [Github](github.com/Yueosa) 主页可以找到

## | nvim

`nvim` 是一款比 `vim` 更强的文本编辑器, 我目前对他进行了 `rust` 和 `markdown` 的定制化

| rust 开发体验 | markdown 体验 |
|-|-|
| ![rust](./image/nvim1.png) | ![markdown](./image/nvim2.png) |

###### 使用 `pacman` 安装

```bash
sudo pacman -S nvim
```

我的 Neovim 配置入口在 `nvim/`，你可以直接把它放到：

```bash
cp -r ./nvim ~/.config/nvim
```

如果你已经有自己的 nvim 配置，也可以只抄 `lua/` 里的模块结构。

##### 目录结构

```
 nvim
├──  init.lua
├──  lua
│   ├──  core
│   │   ├──  options.lua      # 基础选项（缩进/行号/分屏方向等）
│   │   ├──  autocmds.lua     # 全局自动命令
│   │   └──  keymaps.lua      # 全局快捷键（插件内快捷键就近写）
│   └──  plugins
│       ├──  init.lua         # lazy.nvim 引导 + 聚合 specs
│       └──  specs            # 每类插件一个文件（便于维护）
└──  sakurine                 # 我自己写的主题（colorscheme），不是第三方主题包
		├──  autoload
		└──  colors
```

##### 插件与依赖

我使用 `lazy.nvim` 管理插件，核心插件包括：

- `nvim-tree`：文件树
- `nvim-cmp` + `LuaSnip`：补全
- `mason.nvim` / `nvim-lspconfig`：LSP
- `rustaceanvim`：Rust 开发增强
- `which-key`：按键提示（记不住快捷键时非常有用）
- `CopilotChat.nvim`：右侧 Copilot Chat（像 VS Code 那样的聊天窗口）

系统依赖（建议一次装齐）：

```bash
sudo pacman -S --needed neovim git curl tar nodejs tree-sitter tree-sitter-cli
```

> 说明：
> - `nodejs` 用于 GitHub Copilot / Copilot Chat
> - `tree-sitter`(CLI) 用于 nvim-treesitter 的解析器安装/更新

##### Copilot Chat 使用

1) 先在 nvim 里授权（第一次需要）：

```
:Copilot auth
```

2) 打开右侧聊天窗口：

- `<leader>ac`：开关 Copilot Chat

##### 常用快捷键（当前配置里显式定义的）

> 我把 `<leader>` 设成了空格键（Space）。

- `<leader>w`：文件树开关（nvim-tree）
- `<leader>e`：在「文件树 / 编辑区」之间切换焦点
- 文件树窗口里按 `v`：竖分屏打开选中的文件

其他快捷键（LSP / Git / Copilot Chat 等）不用记：按一下 `Space` 会弹出 which-key 提示。


