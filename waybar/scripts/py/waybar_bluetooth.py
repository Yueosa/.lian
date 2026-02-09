#!/usr/bin/env python3
from __future__ import annotations

import json
import shutil
import subprocess
import re
from typing import List, Tuple

PINK = "#F5A9B8"
BLUE = "#209CE6"

ICON_ON = ""
ICON_OFF = "󰂲"


def sh(cmd: List[str]) -> str:
    return subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL).strip()


def try_sh(cmd: List[str]) -> str:
    try:
        return sh(cmd)
    except Exception:
        return ""


def icon_span(icon: str) -> str:
    return f"<span color='{PINK}'>{icon}</span>"


def pango_escape(s: str) -> str:
    s = s or ""
    return (
        s.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
        .replace("'", "&#39;")
    )


def label(field: str) -> str:
    return f"<span color='{PINK}'>{pango_escape(field)}</span>"


def value(v: str) -> str:
    return f"<span color='{BLUE}'>{pango_escape(v)}</span>"


def parse_battery_percent(raw: str) -> int | None:
    # bluetoothctl 常见："0x14 (20)" 或 "20%"
    raw = (raw or "").strip()
    if not raw:
        return None
    m = re.search(r"\((\d{1,3})\)", raw)
    if m:
        try:
            return int(m.group(1))
        except Exception:
            return None
    m = re.search(r"(\d{1,3})%", raw)
    if m:
        try:
            return int(m.group(1))
        except Exception:
            return None
    return None


def parse_controller_info(show_out: str) -> Tuple[str, bool, bool]:
    # Returns: (alias, powered, available)
    if not show_out:
        return ("Bluetooth", False, False)

    alias = "Bluetooth"
    powered = False

    for line in show_out.splitlines():
        line = line.strip()
        if line.startswith("Alias:"):
            alias = line.split(":", 1)[1].strip() or alias
        elif line.startswith("Powered:"):
            powered = line.split(":", 1)[1].strip().lower() == "yes"

    return (alias, powered, True)


def connected_devices() -> List[Tuple[str, str, int | None]]:
    # Returns list of (mac, name, battery_percent)
    # Try fast path first.
    out = try_sh(["bluetoothctl", "devices", "Connected"])
    devices: List[Tuple[str, str, int | None]] = []

    lines = out.splitlines() if out else []
    if not lines:
        # Fallback: enumerate devices and check info (slower but reliable)
        all_out = try_sh(["bluetoothctl", "devices"])
        lines = all_out.splitlines() if all_out else []

    for line in lines:
        line = line.strip()
        if not line.startswith("Device "):
            continue
        parts = line.split(maxsplit=2)
        if len(parts) < 2:
            continue
        mac = parts[1]
        name = parts[2] if len(parts) >= 3 else mac

        info = try_sh(["bluetoothctl", "info", mac])
        if not info:
            continue

        is_conn = False
        batt: int | None = None
        alias = name

        for il in info.splitlines():
            il = il.strip()
            if il.startswith("Name:"):
                alias = il.split(":", 1)[1].strip() or alias
            elif il.startswith("Alias:"):
                alias = il.split(":", 1)[1].strip() or alias
            elif il.startswith("Connected:"):
                is_conn = il.split(":", 1)[1].strip().lower() == "yes"
            elif il.startswith("Battery Percentage:"):
                # e.g. "Battery Percentage: 80%"
                batt = parse_battery_percent(il.split(":", 1)[1].strip())

        if is_conn:
            devices.append((mac, alias, batt))

    return devices


def main() -> int:
    if not shutil.which("bluetoothctl"):
        print(json.dumps({"text": f"{icon_span(ICON_OFF)} BT", "class": "bt-missing", "tooltip": "bluetoothctl not found"}, ensure_ascii=False))
        return 0

    show_out = try_sh(["bluetoothctl", "show"])
    controller_alias, powered, available = parse_controller_info(show_out)

    if not available:
        print(json.dumps({"text": f"{icon_span(ICON_OFF)} BT", "class": "bt-unavailable", "tooltip": "Bluetooth unavailable"}, ensure_ascii=False))
        return 0

    if not powered:
        print(
            json.dumps(
                {
                    "text": f"{icon_span(ICON_OFF)} Off",
                    "class": "bt-off",
                    "tooltip": f"{label('BT')} {value(controller_alias)}\n{label('Status:')} {value('Off')}",
                },
                ensure_ascii=False,
            )
        )
        return 0

    devs = connected_devices()
    if not devs:
        print(
            json.dumps(
                {
                    "text": f"{icon_span(ICON_ON)} 0",
                    "class": "bt-on",
                    "tooltip": f"{label('BT')} {value(controller_alias)}\n{label('Status:')} {value('On')}\n\n{label('Device')}\n{value('(none)')}",
                },
                ensure_ascii=False,
            )
        )
        return 0

    count = len(devs)
    # bar：只显示连接数 +（若可得）电量百分比
    batt_vals = [b for _mac, _name, b in devs if isinstance(b, int) and 0 <= b <= 100]
    batt_part = f" {icon_span('󰂄')} {batt_vals[0]}%" if len(batt_vals) == 1 and count == 1 else ""
    text = f"{icon_span(ICON_ON)} {count}{batt_part}"

    tooltip_lines = [f"{label('BT')} {value(controller_alias)}", f"{label('Status:')} {value('Connected')}", "", f"{label('Device')}"]
    for mac, name, batt in devs[:8]:
        name_s = pango_escape(name)
        mac_s = pango_escape(mac)
        if isinstance(batt, int) and 0 <= batt <= 100:
            tooltip_lines.append(f"{value(name_s)}\t@ {value(mac_s)}\t{label('󰂄')} {value(str(batt) + '%')}")
        else:
            tooltip_lines.append(f"{value(name_s)}\t@ {value(mac_s)}")
    if len(devs) > 8:
        tooltip_lines.append(f"{value('... (+' + str(len(devs) - 8) + ')')}" )

    print(json.dumps({"text": text, "class": "bt-connected", "tooltip": "\n".join(tooltip_lines)}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
