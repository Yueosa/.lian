#!/usr/bin/env python3
import json
import os
from datetime import datetime
from pathlib import Path


def main() -> int:
    state_file = Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))) / "waybar_clock_mode"

    mode = 0
    try:
        mode = int(state_file.read_text(encoding="utf-8").strip())
    except Exception:
        mode = 0

    if mode == 1:
        fmt = "%H:%M:%S"
    elif mode == 2:
        fmt = "%Y-%m-%d %H:%M:%S"
    else:
        fmt = "%Y-%m-%d %H:%M"

    text = datetime.now().strftime(fmt)
    print(json.dumps({"text": text}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
