#!/usr/bin/env python3

import json
import subprocess
from typing import Any


SYMBOL = {
    1: "❶",
    2: "❷",
    3: "❸",
    4: "❹",
    5: "❺",
    6: "❻",
    7: "❼",
    8: "❽",
    9: "❾",
    10: "⓿",
}


def _run(cmd: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, text=True, capture_output=True, check=False)


def _safe_int(value: Any) -> int | None:
    try:
        return int(value)
    except Exception:
        return None


def main() -> None:
    # Always print valid JSON so Waybar never marks the module failed.
    ws_id: int | None = None
    ws_name: str | None = None

    proc = _run(["hyprctl", "activeworkspace", "-j"])
    if proc.returncode == 0 and proc.stdout.strip():
        try:
            data = json.loads(proc.stdout)
            ws_id = _safe_int(data.get("id"))
            ws_name = str(data.get("name")) if data.get("name") is not None else None
        except Exception:
            ws_id = None

    if ws_id is None:
        out = {
            "text": "?",
            "class": "ws-current",
            "tooltip": "workspace: unknown",
        }
        print(json.dumps(out, ensure_ascii=False))
        return

    symbol = SYMBOL.get(ws_id, str(ws_id))
    tooltip = f"workspace {ws_id}"
    if ws_name and ws_name != str(ws_id):
        tooltip = f"workspace {ws_id} ({ws_name})"

    out = {
        "text": symbol,
        "class": f"ws-current ws-{ws_id}",
        "tooltip": tooltip,
    }
    print(json.dumps(out, ensure_ascii=False))


if __name__ == "__main__":
    main()
