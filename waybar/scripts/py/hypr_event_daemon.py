#!/usr/bin/env python3
"""Hyprland 事件守护：监听 .socket2.sock，把活动窗口/工作区写入缓存并通知 waybar。

效果：让 waybar 的 custom/window 与 custom/ws_current 模块由"每秒轮询"变成"事件驱动"。

事件 → 信号映射：
- activewindow / windowtitle / openwindow / closewindow / movewindow
  / changefloatingmode → 刷新 active_window.json + RTMIN+12
- workspace / focusedmon / createworkspace / destroyworkspace
  / moveworkspace → 刷新 active_workspace.json + RTMIN+13

环境依赖：
- HYPRLAND_INSTANCE_SIGNATURE
- XDG_RUNTIME_DIR
- hyprctl 在 PATH
"""

from __future__ import annotations

import os
import signal
import socket
import subprocess
import sys
import threading
import time
from pathlib import Path

CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))) / "waybar"
WIN_CACHE = CACHE_DIR / "active_window.json"
WS_CACHE = CACHE_DIR / "active_workspace.json"

WIN_EVENTS = {
    "activewindow",
    "activewindowv2",
    "windowtitle",
    "windowtitlev2",
    "openwindow",
    "closewindow",
    "movewindow",
    "movewindowv2",
    "changefloatingmode",
    "fullscreen",
}
WS_EVENTS = {
    "workspace",
    "workspacev2",
    "focusedmon",
    "createworkspace",
    "createworkspacev2",
    "destroyworkspace",
    "destroyworkspacev2",
    "moveworkspace",
    "moveworkspacev2",
    "renameworkspace",
}

DEBOUNCE_S = 0.04  # 40ms 合并连续事件


def socket_path() -> Path:
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
    runtime = os.environ.get("XDG_RUNTIME_DIR", "")
    if not sig or not runtime:
        sys.stderr.write("missing HYPRLAND_INSTANCE_SIGNATURE or XDG_RUNTIME_DIR\n")
        sys.exit(1)
    return Path(runtime) / "hypr" / sig / ".socket2.sock"


def hyprctl(args: list[str]) -> str:
    try:
        return subprocess.check_output(
            ["hyprctl", *args],
            text=True,
            stderr=subprocess.DEVNULL,
            timeout=2.0,
        )
    except Exception:
        return ""


def atomic_write(path: Path, data: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + f".tmp.{os.getpid()}")
    tmp.write_text(data, encoding="utf-8")
    tmp.replace(path)


def signal_waybar(sig_offset: int) -> None:
    # waybar custom signal: SIGRTMIN+N
    rtmin = signal.SIGRTMIN  # type: ignore[attr-defined]
    try:
        subprocess.run(
            ["pkill", "-" + str(int(rtmin) + sig_offset), "waybar"],
            stderr=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            check=False,
        )
    except Exception:
        pass


class Refresher:
    """单事件类型的 debounce 刷新：连续事件期间合并成一次刷新。"""

    def __init__(self, name: str, hypr_args: list[str], cache: Path, sig_offset: int) -> None:
        self.name = name
        self.hypr_args = hypr_args
        self.cache = cache
        self.sig_offset = sig_offset
        self._lock = threading.Lock()
        self._timer: threading.Timer | None = None

    def trigger(self) -> None:
        with self._lock:
            if self._timer is not None:
                self._timer.cancel()
            self._timer = threading.Timer(DEBOUNCE_S, self._do)
            self._timer.daemon = True
            self._timer.start()

    def _do(self) -> None:
        out = hyprctl(self.hypr_args).strip()
        if not out:
            return
        try:
            atomic_write(self.cache, out + "\n")
        except Exception as e:
            sys.stderr.write(f"{self.name} cache write failed: {e}\n")
            return
        signal_waybar(self.sig_offset)


def initial_seed(window: Refresher, ws: Refresher) -> None:
    # 启动时主动刷新一次，避免 waybar 启动早于守护时缓存为空。
    window.trigger()
    ws.trigger()


def main() -> int:
    sock_path = socket_path()
    # hyprland-session.target 可能在 socket 就绪前激活；做几次重试。
    deadline = time.monotonic() + 30.0
    while not sock_path.exists():
        if time.monotonic() > deadline:
            sys.stderr.write(f"socket not found: {sock_path}\n")
            return 1
        time.sleep(0.5)

    window = Refresher("window", ["activewindow", "-j"], WIN_CACHE, 12)
    ws = Refresher("workspace", ["activeworkspace", "-j"], WS_CACHE, 13)

    initial_seed(window, ws)

    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect(str(sock_path))
    sock_file = sock.makefile("r", encoding="utf-8", errors="replace")

    for line in sock_file:
        line = line.strip()
        if not line or ">>" not in line:
            continue
        event = line.split(">>", 1)[0]
        if event in WIN_EVENTS:
            window.trigger()
        if event in WS_EVENTS:
            ws.trigger()
            # 工作区切换通常也意味着活动窗口变化
            window.trigger()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
