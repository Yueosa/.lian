# --- 环境变量 ---
export EDITOR=nvim	# 默认编辑器
export VISUAL=nvim	# 图形编辑器
export PATH="$HOME/.local/bin:$PATH"	# 命令位置
export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"

# --- 私密环境变量 ---
[[ -f "$HOME/.lian/.env" ]] && source "$HOME/.lian/.env"


# --- 历史记录 ---
HISTFILE=~/.config/zsh/zsh_history		# 历史记录文件路径
HISTSIZE=5000
SAVEHIST=5000
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt SHARE_HISTORY
setopt APPEND_HISTORY
setopt EXTENDED_HISTORY


# --- 别名 ---
alias ls='eza --icons --group-directories-first'
alias l='eza -ln --icons --git --group-directories-first'
alias la='eza -a --icons --group-directories-first'
alias lt='eza --tree --level=4 --icons'
alias cat='bat'
alias f='fastfetch'
alias n='nvim'
alias du='dust'
alias cbs='mkdir -p build && cd build && cmake -G Ninja .. && ninja'


# --- 补全增强 ----
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
autoload -Uz compinit && compinit


# 加载 zsh-completions
[[ -f /usr/share/zsh/plugins/zsh-completions/zsh-completions.zsh ]] && \
    source /usr/share/zsh/plugins/zsh-completions/zsh-completions.zsh


# --- 插件系统 ---
# 自动建议
[[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
    source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# 命令语法高亮
[[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && \
    source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh


# --- 提示符 & 键位 ---
eval "$(starship init zsh)"
eval "$(zoxide init zsh)"
alias cd='z'
alias cdi='zi'

# 始终使用 Emacs 键位（避免误入 vi-mode 导致一堆 vi 快捷键）
bindkey -e
bindkey "^[[3~" delete-char

# Home/End 键支持
[[ -n ${terminfo[khome]-} ]] && bindkey "${terminfo[khome]}" beginning-of-line
[[ -n ${terminfo[kend]-}  ]] && bindkey "${terminfo[kend]}"  end-of-line
bindkey "\e[1~" beginning-of-line
bindkey "\e[4~" end-of-line
bindkey "\e[H" beginning-of-line
bindkey "\e[F" end-of-line
bindkey "\eOH" beginning-of-line
bindkey "\eOF" end-of-line
bindkey "\e[7~" beginning-of-line
bindkey "\e[8~" end-of-line


# 删除键支持
bindkey '^?' backward-delete-char
bindkey '^H' backward-delete-char

# --- 自动启动 ---
f
