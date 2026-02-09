<div align="center">

# 恋的 Arch 配置

> 我使用的桌面环境是 `Hyprland` + `wayland` + `kitty` + `zsh`

![Hyprland](./image/hyprland.png)

如果你的环境和我一样, 可以直接抄作业! **执行任何命令之前, 请确保你了解他在做什么!!!**

</div>

克隆我的仓库到你的 `$HOME/.lian` 下

```bash
git clone git@github.com:Yueosa/.lian.git ~/.lian
```

如果你没有配置 SSH Key，也可以用 HTTPS：

```bash
git clone https://github.com/Yueosa/.lian.git ~/.lian
```

---

#### 说明

这个文档会详细的说明我的每一个目录配置, 你可以直接下载到 `~/.config/` 下使用

或者直接将整个仓库 clone 到 `$HOME/.lian`, 然后用我推荐的软链方式部署

我的大部分软件是在 `hyprland.conf` 中配置了 `exec-once` (随 `hyprland` 启动)

还有一小部分 (例如 `sddm` `bluetooth` `polkit` `wpa_supplicant`) 要在用户登录前启动, 所以配置为 `systemd enable`

#### 推荐的软链布局（最佳实践）

我推荐的策略是：**所有配置源文件都维护在 `~/.lian`**，然后：

- `~/.config/<软件>` 软链到 `~/.lian/<软件>`（让应用都按常规从 `~/.config` 读取）
- `~/.local/bin/<分类>/<命令>` 软链到 `~/.lian/...`（Hyprland 的 `$script_dir` 只负责调用稳定入口）

下面这三段就是我当前机器上最终的软链状态（可以当成目标形态对照）：

```bash
 ~/.local/bin/
├──  rofi
│   ├── 󰡯 cliphist -> $HOME/.lian/rofi/cliphist_rofi.sh
│   └── 󰡯 rofi-launcher -> $HOME/.lian/rofi/scripts/rofi-launcher.sh
├──  waybar
│   ├── 󰡯 waybar-window -> $HOME/.lian/waybar/scripts/waybar_window.sh
│   └── 󰡯 waybar-workspaces -> $HOME/.lian/waybar/scripts/waybar_workspaces_scroll.sh
└──  wlogout
	└── 󰡯 wlogout -> $HOME/.lian/wlogout/scripts/logoutlaunch.sh
```

```bash
 ~/.config/
├──  environment.d -> $HOME/.lian/environment.d
├──  fastfetch -> $HOME/.lian/fastfetch
├──  gtk-3.0 -> $HOME/.lian/gtk-3.0
├──  gtk-4.0 -> $HOME/.lian/gtk-4.0
├──  hypr -> $HOME/.lian/hypr
├──  kanshi -> $HOME/.lian/kanshi
├──  kitty -> $HOME/.lian/kitty
├──  nvim -> $HOME/.lian/nvim
├──  rofi -> $HOME/.lian/rofi
├──  swaync -> $HOME/.lian/swaync
├──  waybar -> $HOME/.lian/waybar
└──  wlogout -> $HOME/.lian/wlogout
```

```bash
 ~/
└── 󱆃 .zshrc -> $HOME/.lian/.zshrc
```

#### 目录（快速跳转）

| 模块 | 说明 |
|---|---|
| [fastfetch](#fastfetch) | 终端系统信息展示与脚本（开机/开终端美化）。 |
| [fcitx5](#fcitx5) | 输入法框架 + Rime（含取消 Shift 切换中英）。 |
| [GRUB](#grub) | 引导界面主题配置。 |
| [sddm](#sddm) | 登录管理器 + astronaut 主题与登录问题修复。 |
| [zsh](#zsh) | Shell 本体 + starship/zoxide + 常用插件与安装命令。 |
| [kanshi](#kanshi) | 多显示器自动切换配置（笔记本/外接屏）。 |
| [kitty](#kitty) | 终端模拟器配置与字体、ssh 兼容说明。 |
| [GTK](#gtk) | GTK 3/4 主题覆盖（不抄会导致应用窗口样式不一致）。 |
| [rofi](#rofi) | 应用启动器/窗口切换/剪贴板菜单与脚本。 |
| [swaync](#swaync) | 通知中心配置。 |
| [hyprlock](#hyprlock) | 锁屏配置与字体依赖。 |
| [wlogout](#wlogout) | 电源菜单（锁屏/登出/关机/重启）。 |
| [Hyprland](#hyprland) | 窗口管理器/混成器核心配置说明。 |
| [nvim](#nvim) | Neovim 配置结构、插件与依赖。 |
| [waybar](#waybar) | 状态栏配置、模块预览与脚本拆解。 |

---

## | fastfetch

这是一个在终端打印输出系统信息的包, 效果如下:

![fastfetch](./image/fastfetch.png)

###### 你可以使用 `pacman` 进行安装:

```bash
sudo pacman -S fastfetch
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

##### 必须的环境变量（systemd `environment.d`）

如果你发现 `fcitx5` 已经启动，但 GTK/Qt/SDL/GLFW 程序里仍然没法正常输入，通常就是缺少输入法环境变量。

我把这组变量放在本仓库的 [environment.d/10-input.conf](environment.d/10-input.conf)，建议你软链回系统目录：

```bash
mkdir -p ~/.config/environment.d
ln -sf ~/.lian/environment.d/10-input.conf ~/.config/environment.d/10-input.conf
```

> 这个目录会在“用户级 systemd”启动时读取，所以你需要**重新登录**（或重启）后环境变量才会生效。

将我的配置文件放入 `~/.local/share/fcitx5/rime/default.custom.yaml`

他只有一个目的: 取消 `rime` 默认的 `Shift` 切换中英文

##### 我推荐你直接使用 `fcitx5` 级别的切换中英, 输入 `fcitx5-configtool` 打开图形化配置页面 (或自己编辑配置文件)

1. 确保 **当前输入法列表** 中包含: `键盘 - 英语 (美国)` 和 `中州韵 (Rime)`
2. 在 **全局选项** 里, 配置 切换输入法 的快捷键

##### 关于 `fcitx5` 主题

我使用的主题是 [ayaya](https://github.com/witt-bit/fcitx5-theme-ayaya), 这里不做详细教学

![fcitx5-theme-ayaya](./image/fcitx5.png)

## | GRUB

我的 `GRUB` 只做了主题配置, 是用的是 [suiGRUB](https://www.gnome-look.org/p/2219756)

![grub](./image/grub.png)

## | sddm

`sddm` 是一款基于 `QML` 的显示管理器, 我使用他作为我的登录管理器

###### 使用 `pacman` 安装 - 并且设置开机自启

```bash
sudo pacman -S sddm
sudo systemctl enable sddm
```

##### 我使用的主题是 [sddm-astronaut-theme](https://github.com/Keyitdev/sddm-astronaut-theme/), 他是一个 `sddm` 主题库

我使用的是其中的 `hyprland_kath` 主题, 因为嫌其他主题太冗余, 就直接删掉了

![sddm](./image/sddm.png)

你可以直接把我的 `sddm/themes/sddm-astronaut-theme` 复制到 `/usr/sddm/themes` 

然后编辑 `/etc/sddm.conf`, 写入:

```ini
[Theme]
    Current=sddm-astronaut-theme
```

##### 无法登录问题

如果你也使用 `sddm-astronaut-theme`, 那么可能遇到一个登录问题: **用户名显示全大写, 而实际用户名是包含大小写的**

这个问题在 [issues #58](https://github.com/Keyitdev/sddm-astronaut-theme/issues/58) 中提及, 需要修改对应主题的 `conf` 文件

配置这个字段 `AllowUppercaseLettersInUsernames="false" `

## | zsh

`zsh` 是一款强大的 shell 程序

我的配置主要由三部分组成：

- 一些更顺手的命令行工具（`eza` / `bat` / `dust` / `fastfetch`）
- 提示符与目录跳转（`starship` / `zoxide`）
- zsh 插件与补全（`zsh-completions` / `zsh-autosuggestions` / `zsh-syntax-highlighting`）

###### 安装（Arch Linux）

```bash
sudo pacman -S --needed \
	zsh \
	starship zoxide \
	eza bat dust fastfetch \
	zsh-completions zsh-autosuggestions zsh-syntax-highlighting
```

> 说明：
> - 我在 `.zshrc` 里是从 `/usr/share/zsh/plugins/...` 读取插件的，所以你需要安装上面这三个 `zsh-*` 包。
> - `fastfetch` 负责我每次打开终端自动展示系统信息（`.zshrc` 最后有一行 `f`）。

##### 启用 zsh（可选）

如果你想把 zsh 设为默认 shell：

```bash
chsh -s /bin/zsh
```

##### 配置文件位置

我的 `.zshrc` 里用到的关键点：

- 历史记录：写入到 `~/.config/zsh/zsh_history`，建议先建目录

```bash
mkdir -p ~/.config/zsh
```

- 别名：
	- `ls` → `eza`（带图标、git 状态）
	- `cat` → `bat` (更好的 cat)
	- `du` → `dust` (更优雅的查看磁盘占用)
	- `f` → `fastfetch` (上文有介绍)

- 增强：
	- `compinit` + `zsh-completions`：补全增强
	- `zsh-autosuggestions`：自动建议
	- `zsh-syntax-highlighting`：语法高亮

- 体验：
	- `starship`：提示符
	- `zoxide`：目录跳转（我把 `cd` alias 成了 `z`，以及 `cdi` → `zi`）

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

![kitty](./image/kitty.png)

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

##### 使用 `kitty` 进行 ssh 连接

`kitty` 拥有自己专属的终端类型 `xterm-kitty`

所以如果你直接 ssh 服务器, 大概率会报警 `WARNING: terminal is not fully functional` `'xterm-kitty': unknown terminal type` ...

`kitty` 官方推荐的解决方案是, 将 terminfo 安装到你要 ssh 的远端设备上

```bash
kitty +kitten ssh 用户@地址
```

## | GTK

如果你抄完本仓库后发现 GTK 应用（例如 `gnome-calendar` / `nautilus` / `pavucontrol` 等）窗口配色、字体、光标风格和我的截图不一致，通常就是你本机缺少 `~/.config/gtk-3.0/` 与 `~/.config/gtk-4.0/` 的覆盖配置。

本仓库提供了：

- [gtk-3.0/settings.ini](gtk-3.0/settings.ini) + [gtk-3.0/gtk.css](gtk-3.0/gtk.css)
- [gtk-4.0/settings.ini](gtk-4.0/settings.ini) + [gtk-4.0/gtk.css](gtk-4.0/gtk.css)

安装方式（会覆盖同名文件，请先备份你自己的配置）：

```bash
ln -sf ~/.lian/gtk-3.0 ~/.config/gtk-3.0
ln -sf ~/.lian/gtk-4.0 ~/.config/gtk-4.0
```

> 说明：
> - 我这里 `settings.ini` 里仍然使用 `Adwaita` 作为 GTK 主题/图标主题。
> - 光标主题我设置成了 `BreezeX-RosePineDawn-Linux`；你如果没装对应光标主题，会回退成系统默认光标。

## | rofi

`rofi` 是一款应用程序启动器, 我用它做了应用启动菜单, 窗口切换菜单, 剪贴板

| 应用菜单 | 剪贴板 |
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
* `papirus-icon-theme`: 图标主题
* `ttf-jetbrains-mono-nerd`: 字体
* `xdg-utils`: 提供 `xdg-open`

## | swaync

`swaync` 是一个通知中心, 他通过监听 `D-Bus` 来获得实时的消息显示

| 消息通知弹窗 | 通知中心 |
|-|-|
| ![swaync1](./image/swaync1.png) <br> ![swaync2](./image/rofi2.png) | ![swayncclient](./image/swaync2.png) |

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

因为这些是我自己写的软件, 在我的 [Github](https://github.com/Yueosa) 主页可以找到

还有一些快捷键绑定的脚本, 他们是来源于 `rofi` `waybar` ...

#### 配合 `rofi` `waybar` 的快捷键以及功能

你会注意到我在 [hypr/hyprland.conf](hypr/hyprland.conf) 里把 `$script_dir` 指向了 `~/.local/bin`，然后快捷键都去调用这个目录下的脚本

而我的真实脚本/配置源文件在 `~/.lian`（也就是本仓库），并且会软链到 `~/.config/`

> 说明：我不会建议你“把脚本直接丢进 `~/.local/bin`”。
>
> 所以我的策略是, 把 `~/.config/` 下的脚本, 软链接到 `~/.local/bin`, 并且在调用时统一调用路径 `~/.local/bin`

另外我在仓库里也提供了一个 [bin/README.md](bin/README.md)：里面是一些“可选的 wrapper/跳板脚本”，只是为了更方便地创建软链（不是必须，更推荐你直接软链 `~/.config` 下的真实脚本）。

##### 脚本权限（重要）

如果你运行快捷键后发现命令报错 `permission denied`，基本就是脚本没有可执行权限。你可以先给这些脚本补一次权限：

```bash
chmod +x \
	~/.lian/rofi/scripts/rofi-launcher.sh \
	~/.lian/rofi/cliphist_rofi.sh \
	~/.lian/wlogout/scripts/*.sh \
	~/.lian/waybar/lbar \
	~/.lian/waybar/scripts/*.sh
```

> 因为 `~/.config/*` 只是软链到 `~/.lian/*`，所以给 `~/.lian` 补权限最省事。

```bash
mkdir -p ~/.local/bin/{rofi,waybar,wlogout}
# rofi 相关脚本
ln -sf ~/.lian/rofi/scripts/rofi-launcher.sh ~/.local/bin/rofi/rofi-launcher
ln -sf ~/.lian/rofi/cliphist_rofi.sh ~/.local/bin/rofi/cliphist
# wlogout 相关脚本
ln -sf ~/.lian/wlogout/scripts/logoutlaunch.sh ~/.local/bin/wlogout/wlogout
# waybar 相关脚本
ln -sf ~/.lian/waybar/scripts/waybar_window.sh ~/.local/bin/waybar/waybar-window
ln -sf ~/.lian/waybar/scripts/waybar_workspaces_scroll.sh ~/.local/bin/waybar/waybar-workspaces
ln -sf ~/.lian/waybar/lbar ~/.local/bin/waybar/lbar
```

对应快捷键（来自 [hypr/hyprland.conf](hypr/hyprland.conf)）：

- `SUPER + A`：rofi drun（`~/.local/bin/rofi/rofi-launcher drun`）
- `ALT + TAB`：rofi window（`~/.local/bin/rofi/rofi-launcher window`）
- `SUPER + SPACE`：wlogout（`~/.local/bin/wlogout/wlogout`）
- `SUPER + Z`：剪贴板 rofi（`~/.local/bin/rofi/cliphist`）
- `SUPER + X`：弹出当前窗口信息（`~/.local/bin/waybar/waybar-window show`）
- `SUPER + SHIFT + ←/→/↓`：工作区快速切换（`~/.local/bin/waybar/waybar-workspaces down|up|empty`）



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

## | waybar

`waybar` 是专为 wayland 设计的 **高定义, 极强性能, 无限拓展** 的状态栏

###### 使用 `pacman` 安装 - 以及安装我的 `waybar` 配置用到的所有依赖

> 我推荐你先阅读后面的各模块说明再来装逐步安装软件包
>
> **一条命令梭哈完的话, 你后续管理/自定义起来会很麻烦**

```bash
sudo pacman -S --needed \
	waybar \
	python \
	playerctl cava \
	btop \
	networkmanager \
	pavucontrol \
	bluez blueman \
	wl-clipboard cliphist \
	pacman-contrib \
	libnotify
```

如果你要启用 AUR 更新统计（`custom/updates` 的 AUR 部分），以及使用 `nmrs` / `lian` 这类 AUR 社区软件，就需要 AUR helper（例如 `paru`）。

```bash
paru -S --needed nmrs lian
```

可选依赖（本配置的某些点击动作会用到）：

```bash
sudo pacman -S --needed gnome-calendar
```

> 说明：
> - `pacman-contrib` 提供 `checkupdates`（官方仓库更新统计）。
> - `playerctl` 用于媒体模块；`cava` 用于音频频谱。
> - `bluez`/`blueman` 用于蓝牙模块（点击打开 `blueman-manager`）。
> - `libnotify` 提供 `notify-send`（窗口信息弹窗用，可选但建议装）。
> - `wl-clipboard` 用于复制（窗口弹窗里“复制 Class”时会用到，可选）。

##### 快速使用

把本仓库的 `waybar/` 复制到你的配置目录：

```bash
cp -r ./waybar ~/.config/waybar
```

然后在 `hyprland.conf` 里启动：

```ini
exec-once = $script_dir/waybar/lbar start
```

`lbar` 是我给 Waybar 写的守护脚本：Waybar 崩了会自动重启。

你本机的 `~/.local/bin` 建议全部保持为“软链目录”，所以我推荐这样链接：

```bash
mkdir -p ~/.local/bin/waybar
ln -sf ~/.config/waybar/lbar ~/.local/bin/waybar/lbar
```

```bash
$script_dir/waybar/lbar status
$script_dir/waybar/lbar stop
$script_dir/waybar/lbar start
```

##### 目录结构

```
 waybar
├──  config.jsonc            # 主配置：组装各模块（include + group/island-*）
├──  style.css               # 样式入口：只负责 @import（已模块化）
├──  theme.css               # 主题变量：颜色 @define-color
├──  style/                  # 模块化样式目录
├──  modules/                # 每个模块一个 jsonc（更易维护）
└──  scripts/                # 自定义脚本（sh + py）
		└──  py
```

##### 关于 “on-scroll = :” 的细节

Waybar 有个很烦的小坑：某些模块没有配置滚轮动作时，如果你手贱在它上面滚一下，Waybar 可能会直接崩。

所以我在很多模块里都显式写了：

```jsonc
"on-scroll-up": ":",
"on-scroll-down": ":"
```

它的含义就是“啥也不做”，但能避免 Waybar 因为缺少 action 而崩掉。

##### 效果预览

| 模块名称 | 模块预览 |
|---|---|
| `左侧岛屿` <br> 工作区 / logo / 窗口 | <img src="./image/waybarleft1.png" alt="waybarleft" width="420" /> |
| `焦点窗口信息` | <img src="./image/waybarwindow.png" alt="window" width="420" /> |
| `时间显示` | <img src="./image/waybarclock.jpg" alt="clock" width="420" /> |
| `显卡监控` | <img src="./image/waybargpu.png" alt="gpu" width="420" /> |
| `CPU 监控` | <img src="./image/waybarcpu.png" alt="cpu" width="420" /> |
| `内存监控` | <img src="./image/waybarmem.png" alt="mem" width="420" /> |
| `媒体信息` <br> `音频流可视化` | <img src="./image/waybarmedia.png" alt="media" width="420" /> |
| `右侧岛屿` <br> 网络 / 音量 / 电池 / 蓝牙 …） | <img src="./image/waybarright1.png" alt="waybarright" width="420" /> |
| `网络信息` | <img src="./image/waybarnet.png" alt="net" width="420" /> |
| `蓝牙信息` | <img src="./image/waybarblt.png" alt="bluetooth" width="420" /> |
| `包管理器` | <img src="./image/waybarup.png" alt="update" width="420" /> |
| `系统托盘` | <img src="./image/waybartray.png" alt="tray" width="420" /> |
| `托盘右键菜单样式` | <img src="./image/waybaronright.png" alt="onright" width="420" /> |


#### 因为我的配置比较复杂, 所以特意放到最后来说

在这里我会将每一个模块拆解开, 为你介绍他的功能, 依赖, 脚本, 以及脚本的用法

##### 我的 `waybar` 开发规范是

在 `jsonc` 模块文件中调用 `shell` 脚本

当 `shell` 脚本不足以实现功能 (过于臃肿时), 传发到 `py` 脚本

##### 脚本文件阅读说明

每一个脚本文件开头都有详细的注释 (示例如下), 如果你的脚本不工作, 可以直接模块化测试

**shell 脚本注释示例**

```shell
# ----------------------------------------------------------------------
# 脚本：waybar_media.sh
# 用途：Waybar 自定义媒体/歌词模块入口。
# 使用位置：
#   - modules/media.jsonc -> custom/media (return-type=json)
# 调用：
#   - python scripts/py/waybar_media.py
#     - Output: 单行 JSON（text/class/alt/tooltip；text 为歌词或曲目信息）
# 输出：
#   - stdout：直接输出 Python 的 JSON
# 退出码：
#   - 0：即使缺依赖也返回 JSON（避免 Waybar 判定模块失败）
# ----------------------------------------------------------------------
```

**python 脚本注释示例**

```python
"""Waybar 内存/Swap 模块（输出 JSON）。

用途：显示 RAM 与 Swap 的使用百分比，并在 tooltip 里列出 Top 5 内存占用的“应用组”。

实现要点：
- 百分比来自 /proc/meminfo。
- Top 5 优先使用 /proc/<pid>/smaps_rollup 的 PSS（更接近真实占用），拿不到则回退 RSS。

输出：
- stdout 单行 JSON：{"text": "…", "tooltip": "…"}

依赖：Python 标准库（无需第三方包）。
"""
```

---

## 附录: Waybar 各模块配置详解

##### | 当前工作区显示 ws_current

文件：`modules/ws_current.jsonc`

功能：只显示“当前在哪个工作区”的单字符指示器（圈号/数字）。

- 依赖：`hyprctl`、`python3`
- 脚本：`scripts/waybar_ws_current.sh` → `scripts/py/waybar_ws_current.py`
- 刷新：`interval: 1`

##### | 所有工作区状态 workspaces

文件：`modules/workspaces.jsonc`

功能：使用 Waybar 的 `hyprland/workspaces` 模块显示所有工作区状态。

- 左键：点击切换工作区（`on-click: activate`）
- 滚轮：切换到上/下一个“已有窗口或当前”的工作区
	- 脚本：`scripts/waybar_workspaces_scroll.sh` → `scripts/py/waybar_workspaces_scroll.py`
- 依赖：`hyprctl`、`python3`

> 我的jsonc配置与python中有如下硬编码配置, 这是我的个人使用习惯, 但你可以直接改源代码

| 工作区序号 | 说明 | 默认图标 | 是否默认显示 |
|-|-|-|-|
| `1` `2` `3` | 代码区 | `󰅩` | `1` 默认显示；`2` `3` 按需出现 |
| `4` `5` `6` | 游戏区 | `󰓓` | `4` 默认显示；`5` `6` 按需出现 |
| `7` | 其它/杂项 | `󰏘` | 按需出现 |
| `8` | 媒体 | `󰭹` | 默认显示 |
| `9` | 社交/聊天 | `󰭹` | 默认显示 |
| `10` | 代理/音乐 | `󰓇` | 默认显示 |

> “是否默认显示”对应 `modules/workspaces.jsonc` 里的 `persistent-workspaces`：被列出来的工作区即使空着也会显示。

##### | 图标 arch_logo

文件：`modules/logo.jsonc`

功能：显示一个 Arch 图标。

- 左键：打开 AUR 网站

##### | 当前活动窗口监控 window

文件：`modules/window.jsonc`

功能：显示当前活动窗口标题，并在 tooltip 展示 PID/Class/CPU/RAM。

- 脚本：`scripts/waybar_window.sh`（Waybar 模式）
	- 读取 `hyprctl activewindow -j`，交给 `scripts/py/waybar_window.py` 输出 JSON
- 额外玩法：`scripts/waybar_window.sh show|copy-class`
	- `show`：用 `notify-send` 弹窗显示窗口信息，并让模块短暂高亮（hot）
	- `copy-class`：复制窗口 Class（优先 `wl-copy`，没有就用 `xclip`）
- 依赖：`hyprctl`、`python3`；可选 `libnotify`/`wl-clipboard`

##### | 时间和日期显示 clock

文件：`modules/clock.jsonc`

功能：日期/时间显示（右键切换显示模式）。

- 左键：打开 `gnome-calendar`（Hyprland 里我给它配了浮动窗口规则 `org.gnome.Calendar`）
- 右键：切换模式（分三档），并用 `pkill -RTMIN+11 waybar` 立即刷新
- 脚本：`scripts/waybar_clock.sh` + `scripts/waybar_clock_toggle.sh` → `scripts/py/waybar_clock.py`
- 依赖：`python3`；可选 `gnome-calendar`（`sudo pacman -S --needed gnome-calendar`）

##### | 显卡监控 gpuinfo

文件：`modules/gpu.jsonc`

功能：NVIDIA 显卡监控（优先显示显存占用百分比）。

- 脚本：`scripts/waybar_gpu.sh` → `scripts/py/waybar_gpu.py`
- 左键：打开 `nvidia-smi` 实时监控（`kitty --title nvidia-smi -e bash -lc '...'`）
- 依赖：
	- NVIDIA：`nvidia-utils`（提供 `nvidia-smi`）
	- 终端：`kitty`

##### | cpu监控 cpu

文件：`modules/cpu.jsonc`

功能：CPU 使用率监控 + tooltip 详细信息（尽量展示温度/功耗/频率等）。

- 脚本：`scripts/waybar_cpu.sh` → `scripts/py/waybar_cpu.py`
- 左键：打开 `btop`
- 依赖：`python3`；可选 `lm_sensors`（提供 `sensors`，温度/功耗更准）

> 部分 CPU 信息不好拿, 所以只能保证尽量展示, 但作者本人使用环境下并未出错过

##### | 内存与swap监控 memory

文件：`modules/memory.jsonc`

功能：显示 RAM / Swap 使用率；tooltip 显示 Top 5 内存占用（按“应用组”聚合）。

- 脚本：`scripts/waybar_memory.sh` → `scripts/py/waybar_memory.py`
- 左键：打开 `btop`
- 依赖：`python3`

> 内存统计优先使用 PSS 模式, 否则降级为 RSS (这个模式存在统计数值虚高的问题)

##### | 媒体显示器 media

文件：`modules/media.jsonc`

功能：显示当前播放器状态（播放/暂停/停止）与文本（优先歌词）。

- 脚本：
	- 显示：`scripts/waybar_media.sh` → `scripts/py/waybar_media.py`
	- 控制：`scripts/waybar_media_ctl.sh`（播放/暂停、上一首、下一首；保证控制“当前显示的 player”）
- 左键：播放/暂停（调用 `waybar_media_ctl.sh play-pause`）
- 滚轮：上一首 / 下一首（调用 `waybar_media_ctl.sh previous|next`）
- 右键：聚焦播放器窗口（Hyprland）
	- `scripts/waybar_media_focus.sh` → `scripts/py/waybar_media_focus.py`
- 依赖：`playerctl`、`python3`、（右键聚焦需要 `hyprctl`）

> 歌词目录：默认扫 `~/.lyrics/*.lrc`；也支持用环境变量 `WAYBAR_LYRICS_DIRS` 追加目录（冒号分隔）。

##### | 音频可视化 cava

文件：`modules/cava.jsonc`

功能：音频频谱可视化（静音一段时间后自动隐藏）。

- 脚本：`scripts/waybar_cava.sh`（长驻自恢复）
	- `cava -p ~/.config/cava/config_waybar` 输出数值频谱
	- `scripts/py/waybar_cava_proc.py` 把数值映射为字符条
- 依赖：`cava`、`python3`

> 注意：你需要准备 `~/.config/cava/config_waybar`，否则模块会持续输出空行等待你修复。
>
> 本仓库提供了一个最小可用示例：`cava/config_waybar`，你可以这样安装：
>
> ```bash
> mkdir -p ~/.config/cava
> cp ./cava/config_waybar ~/.config/cava/config_waybar
> ```

> 如果你系统里已经有 `~/.config/cava/` 的真实配置，不需要特地 `mv` 过来：
> - 最简单就是把你现有配置复制/调整成 `config_waybar`（关键是输出要适配本模块）。
> - 或者用软链把你维护的文件指向 `~/.config/cava/config_waybar`。

##### | 网络模块 network

文件：`modules/network.jsonc`

功能：Waybar 原生网络模块，显示 Wi-Fi SSID / 有线 / 断开状态。

- 左键：运行 `nmrs`（AUR 社区软件，窗口类名 `org.netrs.ui`）
- 右键：在终端里打开 `nmtui`（`scripts/waybar_open_nmtui.sh` 会自动找终端）
- 依赖：`networkmanager`（提供 `nmtui`）

安装 `nmrs`（AUR）：

```bash
paru -S --needed nmrs
```

> 如果你没有 `nmrs`，把 `on-click` 改成 `nmtui` / `nm-connection-editor` 就行。

##### | 音频控制 pulseaudio

文件：`modules/pulseaudio.jsonc`

功能：音量显示与控制（Waybar 原生 pulseaudio 模块；PipeWire 也兼容）。

- 左键：打开 `pavucontrol -t 3`
- 右键：静音切换（`pactl set-sink-mute @DEFAULT_SINK@ toggle`）
- 滚轮：调音量（步进 1）
- 依赖：`pavucontrol`、`pactl`（通常来自 `pulseaudio` 或 `pipewire-pulse`）

##### | 电池信息 battery

文件：`modules/battery.jsonc`

功能：电池容量显示。

- 左键：打开 `/opt/tuxedo-control-center/tuxedo-control-center`

> 如果你不是 TUXEDO 设备/没装这个软件，把 `on-click` 改成你自己的电源管理器即可。

##### | 蓝牙模块 bluetooth

文件：`modules/bluetooth.jsonc`

功能：显示蓝牙开关、连接数（以及单设备电量）。

- 左键：打开 `blueman-manager`
- 依赖：`bluez`（bluetoothctl）、`blueman`（GUI）

蓝牙服务建议开机自启：

```bash
sudo systemctl enable --now bluetooth
```

##### | 剪贴板 clipboard

文件：`modules/clipboard.jsonc`

功能：剪贴板菜单入口（本质上是一个按钮）。

- 左键：运行 `~/.config/rofi/cliphist_rofi.sh`
- 右键：清空历史（`cliphist wipe`）
- 依赖：`cliphist`、`wl-clipboard`、`rofi-wayland`

##### | 系统更新 updates

文件：`modules/updates.jsonc`

功能：统计官方仓库 + AUR 的可更新数量。

- 脚本：`scripts/waybar_updates.sh`
	- 官方：`checkupdates` 计数
	- AUR：`paru -Qua` 计数（带 timeout + cache，避免断网卡死）
- 左键：`kitty -e lian`
- 依赖：`pacman-contrib`（checkupdates）、`paru`（AUR 统计）、`kitty`、`lian`

安装 `lian`（AUR）：

```bash
paru -S --needed lian
```

> `lian` 是我自己开发的包管理器前端, 对新手非常友好, 你可以在我的 [Github](https://github.com/Yueosa/lian) 详细了解他

##### | 系统托盘 tray

文件：`modules/tray.jsonc`

功能：系统托盘（后台应用图标）。

- 样式：右键菜单样式在 `style/tray-menu.css`

##### | (未启用) backlight

文件：`modules/backlight.jsonc`

我这份配置里暂时没启用它；如果你是笔记本并且需要亮度条，可以按需启用。
