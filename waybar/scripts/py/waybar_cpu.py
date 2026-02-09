#!/usr/bin/env python3
"""Waybar CPU 模块（输出 JSON）。

用途：输出 CPU 使用率（含每核心/平均频率），并尽可能展示温度与功耗。

数据来源：
- /proc/stat：计算每核心使用率（使用缓存文件做 delta）
- /sys/devices/system/cpu：读取频率（可用时）
- 温度：优先 sensors -j，其次 /sys/class/thermal
- 功耗：优先 RAPL(/sys/class/powercap)，其次 hwmon，再次 sensors

输出：
- stdout 单行 JSON：{"text": "…", "tooltip": "…"}

依赖：Python 标准库；可选安装 lm_sensors（提供 sensors）以获得更准确温度/功耗。
"""

import json
import math
import os
import re
import shutil
import time
from pathlib import Path

PINK = "#F5A9B8"
BLUE = "#209CE6"

CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
CACHE_DIR.mkdir(parents=True, exist_ok=True)

STAT_CACHE = CACHE_DIR / "waybar_cpu_stat.json"
POWER_CACHE = CACHE_DIR / "waybar_cpu_power.json"


def has(cmd: str) -> bool:
    return shutil.which(cmd) is not None


def span(color: str, text: str) -> str:
    return f"<span color='{color}'>{text}</span>"


def field(label: str, value: str) -> str:
    return f"{span(PINK, label)} {span(BLUE, value)}"


def read_proc_stat():
    cores = []
    with open("/proc/stat", "r", encoding="utf-8") as f:
        for line in f:
            if not line.startswith("cpu"):
                continue
            parts = line.split()
            name = parts[0]
            if name == "cpu":
                continue
            if not re.fullmatch(r"cpu\d+", name):
                continue
            nums = list(map(int, parts[1:9]))
            while len(nums) < 8:
                nums.append(0)
            cores.append(nums)
    return cores


def usage_from(prev, cur):
    # fields: user nice system idle iowait irq softirq steal
    prev_total = sum(prev)
    cur_total = sum(cur)
    prev_idle = prev[3] + prev[4]
    cur_idle = cur[3] + cur[4]
    total_delta = cur_total - prev_total
    idle_delta = cur_idle - prev_idle
    if total_delta <= 0:
        return None
    usage = 100.0 * (total_delta - idle_delta) / total_delta
    return max(0.0, min(100.0, usage))


def per_core_usage_percent():
    now = time.time()
    cur = read_proc_stat()
    if not cur:
        return None

    try:
        prev = json.loads(STAT_CACHE.read_text(encoding="utf-8"))
        prev_cores = prev.get("cores")
    except Exception:
        prev_cores = None

    STAT_CACHE.write_text(json.dumps({"ts": now, "cores": cur}), encoding="utf-8")

    if not prev_cores or len(prev_cores) != len(cur):
        return None

    usages = []
    for p, c in zip(prev_cores, cur):
        usages.append(usage_from(p, c))
    return usages


def avg_freq_ghz():
    cpu_paths = sorted(Path("/sys/devices/system/cpu").glob("cpu[0-9]*"))
    freqs = []
    for cpu in cpu_paths:
        for fname in ("scaling_cur_freq", "cpuinfo_cur_freq"):
            p = cpu / "cpufreq" / fname
            if p.exists():
                try:
                    khz = int(p.read_text(encoding="utf-8").strip())
                    if khz > 0:
                        freqs.append(khz / 1_000_000.0)
                except Exception:
                    pass
                break
    if freqs:
        return sum(freqs) / len(freqs)

    mhz = []
    try:
        with open("/proc/cpuinfo", "r", encoding="utf-8") as f:
            for line in f:
                if line.lower().startswith("cpu mhz"):
                    mhz.append(float(line.split(":", 1)[1].strip()))
    except Exception:
        pass

    if mhz:
        return (sum(mhz) / len(mhz)) / 1000.0

    return None


def cpu_temp_c():
    if has("sensors"):
        try:
            import subprocess

            out = subprocess.check_output(["sensors", "-j"], text=True, stderr=subprocess.DEVNULL)
            data = json.loads(out)
            candidates = []

            def walk(obj):
                if isinstance(obj, dict):
                    for k, v in obj.items():
                        lk = str(k).lower()
                        if lk.endswith("_input") and any(x in lk for x in ("tctl", "tdie", "package", "temp")):
                            try:
                                fv = float(v)
                                if 10.0 <= fv <= 120.0:
                                    candidates.append(fv)
                            except Exception:
                                pass
                        walk(v)
                elif isinstance(obj, list):
                    for it in obj:
                        walk(it)

            walk(data)
            if candidates:
                return max(candidates)
        except Exception:
            pass

    temps = []
    for p in Path("/sys/class/thermal").glob("thermal_zone*/temp"):
        try:
            raw = p.read_text(encoding="utf-8").strip()
            v = int(raw)
            c = v / 1000.0 if v > 1000 else float(v)
            if 10.0 <= c <= 120.0:
                temps.append(c)
        except Exception:
            pass
    if temps:
        return max(temps)

    return None


def rapl_power_w():
    powercap = Path("/sys/class/powercap")
    if not powercap.exists():
        return None

    now = time.time()
    try:
        cache = json.loads(POWER_CACHE.read_text(encoding="utf-8"))
        if not isinstance(cache, dict):
            cache = {}
    except Exception:
        cache = {}

    updated = {}
    candidates = []

    for energy_path in sorted(powercap.rglob("energy_uj")):
        try:
            energy = int(energy_path.read_text(encoding="utf-8").strip())
        except Exception:
            continue

        key = str(energy_path)
        prev = cache.get(key)
        updated[key] = {"ts": now, "energy_uj": energy}

        if not isinstance(prev, dict):
            continue
        try:
            dt = now - float(prev.get("ts", 0))
            de = energy - int(prev.get("energy_uj", 0))
        except Exception:
            continue

        if dt <= 0 or de <= 0:
            continue

        w = (de / 1_000_000.0) / dt
        if 0.1 <= w <= 300.0:
            candidates.append(w)

    try:
        POWER_CACHE.write_text(json.dumps(updated), encoding="utf-8")
    except Exception:
        pass

    return max(candidates) if candidates else None


def hwmon_power_w():
    hwmon_root = Path("/sys/class/hwmon")
    if not hwmon_root.exists():
        return None

    candidates = []
    for hw in hwmon_root.glob("hwmon*"):
        for pat in ("power*_average", "power*_input"):
            for p in hw.glob(pat):
                try:
                    v = float(p.read_text(encoding="utf-8").strip())
                    w = v / 1_000_000.0 if v > 10_000 else v
                    if 0.1 <= w <= 300.0:
                        candidates.append(w)
                except Exception:
                    pass

    return max(candidates) if candidates else None


def sensors_power_w():
    if not has("sensors"):
        return None
    try:
        import subprocess

        out = subprocess.check_output(["sensors", "-j"], text=True, stderr=subprocess.DEVNULL)
        data = json.loads(out)
        vals = []

        def walk(obj):
            if isinstance(obj, dict):
                for k, v in obj.items():
                    lk = str(k).lower()
                    if lk.endswith("_input") and "power" in lk:
                        try:
                            fv = float(v)
                            if 0.1 <= fv <= 300.0:
                                vals.append(fv)
                        except Exception:
                            pass
                    walk(v)
            elif isinstance(obj, list):
                for it in obj:
                    walk(it)

        walk(data)
        return max(vals) if vals else None
    except Exception:
        return None


def cpu_power_w():
    # Try multiple sources; keep the highest plausible.
    vals = [rapl_power_w(), hwmon_power_w(), sensors_power_w()]
    vals = [v for v in vals if isinstance(v, (int, float))]
    return max(vals) if vals else None


def choose_cols(n: int) -> int:
    if n <= 1:
        return 1
    if n <= 4:
        return 2
    if n <= 8:
        return 4
    if n <= 12:
        return 6
    return 8


def format_core_grid(usages):
    if not isinstance(usages, list) or not usages:
        return None

    cells = []
    for i, u in enumerate(usages):
        if u is None:
            value = "  --%"
        else:
            value = f"{u:>3.0f}%"
        cells.append(f"{span(PINK, f'C{i:02d}')} {span(BLUE, value)}")

    cols = choose_cols(len(cells))
    lines = []
    for i in range(0, len(cells), cols):
        lines.append("  ".join(cells[i : i + cols]))
    return lines


def main() -> int:
    freq = avg_freq_ghz()
    temp = cpu_temp_c()
    _power = cpu_power_w()
    cores = per_core_usage_percent()

    text_freq = f"{freq:.2f}GHz" if isinstance(freq, (int, float)) else "--GHz"
    text = f"<span color='{PINK}'></span> {text_freq}"

    tooltip_lines = []

    temp_str = f"{temp:.1f}°C" if isinstance(temp, (int, float)) else "N/A"
    tooltip_lines.append(field("CPU温度:", temp_str))

    core_grid = format_core_grid(cores)
    if core_grid:
        valid = [u for u in cores if isinstance(u, (int, float))]
        avg_usage = (sum(valid) / len(valid)) if valid else None
        tooltip_lines.append("")
        if isinstance(avg_usage, (int, float)):
            tooltip_lines.append(field("平均使用率:", f"{avg_usage:.0f}%"))
        tooltip_lines.extend(core_grid)
    else:
        tooltip_lines.append("")
        tooltip_lines.append(field("核心使用率:", "采样中…"))

    tooltip = "\n".join(tooltip_lines)

    print(json.dumps({"text": text, "tooltip": tooltip}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
 