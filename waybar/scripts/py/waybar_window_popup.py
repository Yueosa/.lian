#!/usr/bin/env python3
"""窗口信息弹窗/复制工具（非 Waybar 输出）。

用途：配合 waybar_window.sh 的参数模式：
- show：notify-send 弹出窗口 PID/Class/CPU/RAM 信息
- copy-class：复制当前窗口 Class 到剪贴板

输入：
- 环境变量 ACTIVE_JSON：由 waybar_window.sh 传入（hyprctl activewindow -j）
- 环境变量 MODE：show / copy-class

输出：
- 默认无 stdout；通过 notify-send 弹窗。
- 会写入 HOT_FILE 使 Waybar 的 window 模块短暂变粉（hot 状态），并发送 RTMIN+12 刷新。

依赖：
- notify-send（可选，但建议安装）
- wl-copy 或 xclip（用于复制）
- ps、/proc
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import time
from pathlib import Path

HOT_SECONDS = 10

CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache")))
HOT_FILE = CACHE_DIR / "waybar_window_hot_until"


def has(cmd: str) -> bool:
    return shutil.which(cmd) is not None


def run_text(cmd: list[str]) -> str:
    try:
        return subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return ""


def env_truthy(name: str, default: str = "1") -> bool:
    return os.environ.get(name, default).strip().lower() in ("1", "true", "yes", "on")


def proc_children(pid: int) -> list[int]:
    if pid <= 0:
        return []
    try:
        children_path = Path(f"/proc/{pid}/task/{pid}/children")
        raw = children_path.read_text(encoding="utf-8", errors="ignore").strip()
        if not raw:
            return []
        return [int(x) for x in raw.split() if x.isdigit()]
    except Exception:
        pass

    out = run_text(["ps", "--no-headers", "-o", "pid=", "--ppid", str(pid)])
    if not out:
        return []
    pids: list[int] = []
    for part in out.split():
        try:
            pids.append(int(part))
        except Exception:
            pass
    return pids


def collect_tree_pids(root_pid: int, max_pids: int = 512) -> list[int]:
    if root_pid <= 0:
        return []
    seen: set[int] = set()
    stack: list[int] = [root_pid]
    out: list[int] = []
    while stack and len(out) < max_pids:
        pid = stack.pop()
        if pid <= 0 or pid in seen:
            continue
        seen.add(pid)
        out.append(pid)
        try:
            stack.extend(proc_children(pid))
        except Exception:
            pass
    return out


def ps_cpu_sum(pids: list[int]) -> float:
    if not pids:
        return 0.0
    pid_arg = ",".join(str(p) for p in pids)
    out = run_text(["ps", "-p", pid_arg, "-o", "%cpu="])
    if not out:
        return 0.0
    total = 0.0
    for line in out.splitlines():
        try:
            total += float(line.strip())
        except Exception:
            pass
    return total


def format_cpu(v: float) -> str:
    if v <= 0:
        return "0"
    s = f"{v:.1f}"
    return s.rstrip("0").rstrip(".")


def rss_bytes(pid: int) -> int:
    try:
        with open(f"/proc/{pid}/status", "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                if line.startswith("VmRSS:"):
                    m = re.search(r"VmRSS:\s*(\d+)\s*kB", line)
                    if m:
                        return int(m.group(1)) * 1024
    except Exception:
        pass
    return 0


def pss_bytes(pid: int) -> int:
    try:
        with open(f"/proc/{pid}/smaps_rollup", "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                if line.startswith("Pss:"):
                    m = re.search(r"Pss:\s*(\d+)\s*kB", line)
                    if m:
                        return int(m.group(1)) * 1024
    except Exception:
        pass
    return 0


def mem_bytes(pid: int) -> int:
    metric = os.environ.get("WAYBAR_WINDOW_MEM_METRIC", "pss").strip().lower()
    if metric == "rss":
        return rss_bytes(pid)
    pss = pss_bytes(pid)
    return pss if pss > 0 else rss_bytes(pid)


def human_bytes(n: int) -> str:
    if n <= 0:
        return "0B"
    units = ["B", "K", "M", "G", "T"]
    v = float(n)
    for u in units:
        if v < 1024.0 or u == units[-1]:
            if u == "B":
                return f"{int(v)}{u}"
            return f"{v:.0f}{u}" if v >= 10 else f"{v:.1f}{u}"
        v /= 1024.0


def get_info(active: dict) -> tuple[str, str]:
    pid = int(active.get("pid") or 0)
    cls = (active.get("class") or "").strip() or "-"

    show_pid = os.environ.get("WAYBAR_WINDOW_POPUP_SHOW_PID", "1") in ("1", "true", "yes", "on")

    tree_mode = env_truthy("WAYBAR_WINDOW_TREE_SUM", "1")

    cpu = "0"
    ram = "0B"
    if pid > 0 and tree_mode:
        pids = collect_tree_pids(pid)
        cpu = format_cpu(ps_cpu_sum(pids))
        ram = human_bytes(sum(mem_bytes(p) for p in pids))
    elif pid > 0:
        cpu = run_text(["ps", "-p", str(pid), "-o", "%cpu="]) or "0"
        ram = human_bytes(mem_bytes(pid))

    lines: list[str] = []
    if show_pid:
        lines.append(f"PID: {pid if pid else '-'}")
    lines.extend(
        [
            f"Class {cls}",
            f"CPU {cpu}%",
            f"RAM {ram}",
        ]
    )

    return cls, "\n".join(lines)


def copy_to_clipboard(text: str) -> None:
    if has("wl-copy"):
        subprocess.run(["wl-copy"], input=text, text=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    elif has("xclip"):
        subprocess.run(
            ["xclip", "-selection", "clipboard"],
            input=text,
            text=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )


def main() -> int:
    raw = os.environ.get("ACTIVE_JSON", "")
    mode = os.environ.get("MODE", "show")

    try:
        active = json.loads(raw) if raw else {}
    except Exception:
        active = {}

    cls, body = get_info(active)

    # set hot highlight for Waybar window module
    try:
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        HOT_FILE.write_text(str(time.time() + HOT_SECONDS), encoding="utf-8")
    except Exception:
        pass

    if mode in ("copy-class", "copy_class"):
        copy_to_clipboard(cls)
    else:
        if has("notify-send"):
            action = ""
            try:
                action = subprocess.check_output(
                    [
                        "notify-send",
                        "-t",
                        str(int(HOT_SECONDS * 1000)),
                        "-A",
                        "copy_class=Copy Class",
                        "Window Info",
                        body,
                    ],
                    text=True,
                    stderr=subprocess.DEVNULL,
                ).strip()
            except Exception:
                action = ""

            if action == "copy_class":
                copy_to_clipboard(cls)

    subprocess.run(["pkill", "-RTMIN+12", "waybar"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
