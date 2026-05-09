#!/usr/bin/env python3
"""Hyprland 工作区滚轮切换 / 跳到最小空 workspace。

用法：qs_workspaces [up|down|empty]
- up/down：在「有窗口的工作区 + 当前工作区」中循环切换
- empty：  跳到 1..10 中数值最小的空工作区

外部依赖：hyprctl。无任何配置文件 / 环境变量。
"""

from __future__ import annotations

import json
import subprocess
import sys


def _run(args: list[str]) -> str:
    try:
        return subprocess.run(
            args, check=False, capture_output=True, text=True
        ).stdout
    except FileNotFoundError:
        return ""


def main() -> int:
    direction = sys.argv[1] if len(sys.argv) > 1 else "up"

    try:
        active = json.loads(_run(["hyprctl", "activeworkspace", "-j"]) or "{}")
        workspaces = json.loads(_run(["hyprctl", "workspaces", "-j"]) or "[]")
    except Exception:
        return 0

    active_id = int(active.get("id") or 0)

    if direction == "empty":
        occupied: set[int] = set()
        for w in workspaces:
            try:
                wid = int(w.get("id") or 0)
            except Exception:
                continue
            if wid > 0:
                occupied.add(wid)
        for candidate in range(1, 11):
            if candidate not in occupied:
                subprocess.run(
                    ["hyprctl", "dispatch", "workspace", str(candidate)],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                )
                return 0
        return 0

    ids: list[int] = []
    for w in workspaces:
        try:
            wid = int(w.get("id") or 0)
            windows = int(w.get("windows") or 0)
        except Exception:
            continue
        if wid <= 0:
            continue
        if windows > 0 or wid == active_id:
            ids.append(wid)

    ids = sorted(set(ids))
    if not ids:
        return 0
    if active_id not in ids:
        ids.append(active_id)
        ids = sorted(set(ids))

    idx = ids.index(active_id)
    step = 1 if direction == "up" else -1
    next_id = ids[(idx + step) % len(ids)]

    subprocess.run(
        ["hyprctl", "dispatch", "workspace", str(next_id)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
