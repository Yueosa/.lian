#!/usr/bin/env python3
"""Waybar 窗口标题模块（输出 JSON）。

用途：显示当前活动窗口标题，并在 tooltip 展示 PID/Class/CPU/RAM。

输入：
- 环境变量 ACTIVE_JSON：由 waybar_window.sh 传入（hyprctl activewindow -j）。

输出：
- stdout 单行 JSON：{"text": "<title>", "tooltip": "..."}

可选行为（环境变量）：
- WAYBAR_WINDOW_TREE_SUM=1：对窗口进程树汇总 CPU/RAM（默认开启）。
- WAYBAR_WINDOW_MEM_METRIC=pss|rss：内存统计方式。

依赖：hyprctl、ps、/proc。
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import time
from pathlib import Path

PINK = "#F5A9B8"
BLUE = "#209CE6"

HOT_FILE = Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))) / "waybar_window_hot_until"
CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache")))
INFO_CACHE_FILE = CACHE_DIR / "waybar_window_info_cache.json"
WINDOW_KEY_FILE = CACHE_DIR / "waybar_window_last_key"

CACHE_TTL_SECONDS = 1.5


def now_s() -> float:
    return time.time()


def run(cmd: list[str]) -> str:
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

    out = run(["ps", "--no-headers", "-o", "pid=", "--ppid", str(pid)])
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
    out = run(["ps", "-p", pid_arg, "-o", "%cpu="])
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


def load_info_cache() -> dict:
    try:
        raw = INFO_CACHE_FILE.read_text(encoding="utf-8").strip()
        return json.loads(raw) if raw else {}
    except Exception:
        return {}


def save_info_cache(data: dict) -> None:
    try:
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        INFO_CACHE_FILE.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
    except Exception:
        pass


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


def tooltip_line(field: str, value: str) -> str:
    return f"<span color='{PINK}'>{field}</span><span color='{BLUE}'>: {value}</span>"


def build_info(active: dict) -> dict:
    pid = int(active.get("pid") or 0)
    cls = (active.get("class") or "").strip()
    title = (active.get("title") or "").strip()

    if not title:
        title = cls or "Desktop"

    tree_mode = env_truthy("WAYBAR_WINDOW_TREE_SUM", "1")

    cache = load_info_cache()
    cached_pid = int(cache.get("pid") or 0)
    cached_ts = float(cache.get("ts") or 0.0)
    cached_tree = bool(cache.get("tree"))
    cache_fresh = (
        pid > 0
        and pid == cached_pid
        and cached_tree == tree_mode
        and (now_s() - cached_ts) <= CACHE_TTL_SECONDS
    )

    cpu = "0"
    ram = "0B"
    if pid > 0 and cache_fresh:
        cpu = str(cache.get("cpu") or "0")
        ram = str(cache.get("ram") or "0B")
    elif pid > 0:
        if tree_mode:
            pids = collect_tree_pids(pid)
            cpu = format_cpu(ps_cpu_sum(pids))
            ram = human_bytes(sum(mem_bytes(p) for p in pids))
        else:
            cpu_raw = run(["ps", "-p", str(pid), "-o", "%cpu="])
            cpu = cpu_raw.strip() or "0"
            ram = human_bytes(mem_bytes(pid))
        save_info_cache({"pid": pid, "ts": now_s(), "cpu": cpu, "ram": ram, "tree": tree_mode})

    tooltip = "\n".join(
        [
            tooltip_line("PID", str(pid) if pid else "-"),
            tooltip_line("Class", cls or "-"),
            tooltip_line("CPU", f"{cpu}%"),
            tooltip_line("RAM", ram),
        ]
    )

    return {"text": title, "tooltip": tooltip}


def is_hot() -> bool:
    try:
        until = float(HOT_FILE.read_text(encoding="utf-8").strip())
        return now_s() < until
    except Exception:
        return False


def window_key(active: dict, text: str) -> str:
    pid = int(active.get("pid") or 0)
    addr = (active.get("address") or "").strip()
    cls = (active.get("class") or "").strip()
    # title/text 可能包含换行等；压一压避免文件异常膨胀
    safe_text = (text or "").replace("\n", " ").strip()
    return f"{pid}|{addr}|{cls}|{safe_text}"


def read_last_key() -> str:
    try:
        return WINDOW_KEY_FILE.read_text(encoding="utf-8", errors="ignore").strip()
    except Exception:
        return ""


def write_last_key(k: str) -> None:
    try:
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        WINDOW_KEY_FILE.write_text((k or "").strip(), encoding="utf-8")
    except Exception:
        pass


def main() -> int:
    raw = os.environ.get("ACTIVE_JSON", "")
    try:
        active = json.loads(raw) if raw else {}
    except Exception:
        active = {}

    info = build_info(active)
    # class 设计：
    # - 默认 window（蓝色）
    # - 切换焦点时加 flash（粉色），随后 CSS 3s 过渡回蓝色
    # - 保留原 hot（手动高亮）
    key = window_key(active, str(info.get("text", "")))
    last = read_last_key()
    changed = False
    if key and not last:
        write_last_key(key)
    elif key and key != last:
        changed = True
        write_last_key(key)

    cls_parts = ["window"]
    if changed:
        cls_parts.append("flash")
    if is_hot():
        cls_parts.append("hot")
    cls = " ".join(cls_parts)

    out = {"text": info.get("text", ""), "tooltip": info.get("tooltip", ""), "class": cls}
    print(json.dumps(out, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
