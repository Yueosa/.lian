#!/usr/bin/env python3
"""Hyprland 工作区滚轮切换逻辑（被 Waybar 调用）。

用途：配合 waybar_workspaces_scroll.sh，根据滚轮方向切换到“下/上一个有窗口的工作区”。

输入（通过环境变量传入）：
- DIR: up|down|empty
- ACTIVE_JSON: `hyprctl activeworkspace -j` 的输出
- WS_JSON: `hyprctl workspaces -j` 的输出

输出：无（仅调用 hyprctl dispatch）。

依赖：hyprctl。
"""

import json
import os
import subprocess


def main() -> int:
    dir_ = os.environ.get("DIR", "up")
    try:
        active = json.loads(os.environ.get("ACTIVE_JSON") or "{}")
        workspaces = json.loads(os.environ.get("WS_JSON") or "[]")
    except Exception:
        return 0

    active_id = int(active.get("id") or 0)

    # 处理切换到最小空工作区的情况
    if dir_ == "empty":
        # 收集所有已存在的工作区ID
        occupied_ids: set[int] = set()
        for w in workspaces:
            try:
                wid = int(w.get("id") or 0)
                if wid > 0:
                    occupied_ids.add(wid)
            except Exception:
                continue
        
        # 查找最小的空工作区（1-10 范围内）
        for candidate_id in range(1, 11):
            if candidate_id not in occupied_ids:
                subprocess.run(
                    ["hyprctl", "dispatch", "workspace", str(candidate_id)],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                )
                return 0
        # 如果1-10都被占用了，就不做任何操作
        return 0

    # 原有的上下切换逻辑
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
    step = 1 if dir_ == "up" else -1
    next_id = ids[(idx + step) % len(ids)]

    subprocess.run(
        ["hyprctl", "dispatch", "workspace", str(next_id)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
