#!/usr/bin/env python3
# WiFi SSID 显示名修复：Quickshell 用 fromUtf8，GBK 等非 UTF-8 SSID 会变成 U+FFFD。
# 输出 JSON：{ "<broken utf-8 replace 名>": "<可读名>" }
# 仅在 detail 页需要时由 Network.qml 调用，非常驻。

from __future__ import annotations

import json
import sys

def decode_ssid(raw: bytes) -> str:
    if not raw:
        return ""
    try:
        return raw.decode("utf-8")
    except UnicodeDecodeError:
        pass
    for enc in ("gb18030", "gbk", "big5", "shift_jis", "latin-1"):
        try:
            return raw.decode(enc)
        except UnicodeDecodeError:
            continue
    return raw.decode("utf-8", errors="replace")


def main() -> int:
    try:
        import gi

        gi.require_version("NM", "1.0")
        from gi.repository import NM
    except Exception as e:
        print("{}", end="")
        print(f"wifi_ssid_fix: NM unavailable: {e}", file=sys.stderr)
        return 0

    client = NM.Client.new(None)
    fixes: dict[str, str] = {}

    for dev in client.get_devices():
        if dev.get_device_type() != NM.DeviceType.WIFI:
            continue
        for ap in dev.get_access_points() or []:
            ssid = ap.get_ssid()
            if ssid is None:
                continue
            raw = bytes(ssid.get_data())
            if not raw:
                continue
            broken = raw.decode("utf-8", errors="replace")
            if "\ufffd" not in broken:
                continue
            fixed = decode_ssid(raw)
            if fixed and fixed != broken:
                fixes[broken] = fixed

    sys.stdout.write(json.dumps(fixes, ensure_ascii=False, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
