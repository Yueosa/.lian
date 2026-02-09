#!/usr/bin/env python3
import json
import os
import re
from pathlib import Path

PINK = "#F5A9B8"
BLUE = "#209CE6"
PAGE_SIZE = os.sysconf("SC_PAGE_SIZE")


def span(color: str, text: str) -> str:
    return f"<span color='{color}'>{text}</span>"


def field(label: str, value: str) -> str:
    return f"{span(PINK, label)} {span(BLUE, value)}"


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


def read_meminfo() -> dict[str, int]:
    out: dict[str, int] = {}
    try:
        for line in Path("/proc/meminfo").read_text(encoding="utf-8", errors="ignore").splitlines():
            if ":" not in line:
                continue
            k, rest = line.split(":", 1)
            parts = rest.strip().split()
            if not parts:
                continue
            try:
                out[k] = int(parts[0])  # kB
            except Exception:
                continue
    except Exception:
        pass
    return out


def mem_percents():
    mi = read_meminfo()
    mt = mi.get("MemTotal", 0) * 1024
    ma = mi.get("MemAvailable", 0) * 1024
    st = mi.get("SwapTotal", 0) * 1024
    sf = mi.get("SwapFree", 0) * 1024

    mem_pct = None
    if mt > 0:
        used = max(0, mt - ma)
        mem_pct = round(used / mt * 100)

    swap_pct = None
    if st > 0:
        used = max(0, st - sf)
        swap_pct = round(used / st * 100)

    return mem_pct, swap_pct


def list_pids():
    for d in Path("/proc").iterdir():
        if d.is_dir() and d.name.isdigit():
            yield int(d.name)


def read_stat(pid: int):
    # /proc/<pid>/stat : pid (comm) state ppid ... rss
    try:
        s = Path(f"/proc/{pid}/stat").read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return None

    lpar = s.find("(")
    rpar = s.rfind(")")
    if lpar == -1 or rpar == -1 or rpar < lpar:
        return None

    comm = s[lpar + 1 : rpar]
    after = s[rpar + 2 :].split()
    if len(after) < 22:
        return None

    try:
        ppid = int(after[1])
        rss_pages = int(after[21])
    except Exception:
        return None

    return comm, ppid, rss_pages


def read_cmdline(pid: int) -> str:
    try:
        raw = Path(f"/proc/{pid}/cmdline").read_bytes()
        if not raw:
            return ""
        parts = [p.decode("utf-8", errors="ignore") for p in raw.split(b"\x00") if p]
        return " ".join(parts).strip()
    except Exception:
        return ""


def pss_bytes(pid: int) -> int:
    # Prefer PSS from smaps_rollup; may fail due to permission/kernel config.
    try:
        txt = Path(f"/proc/{pid}/smaps_rollup").read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return 0

    # Find: Pss: <kB> kB
    m = re.search(r"^Pss:\s*(\d+)\s*kB\s*$", txt, flags=re.M)
    if not m:
        return 0
    try:
        return int(m.group(1)) * 1024
    except Exception:
        return 0


def mem_bytes(pid: int, rss_pages: int) -> tuple[int, bool]:
    # returns (bytes, used_rss_fallback)
    pss = pss_bytes(pid)
    if pss > 0:
        return pss, False
    return max(0, rss_pages) * PAGE_SIZE, True


def top5_memory_groups():
    # Group by "app root" = climb until parent is init/DM boundary.
    comm: dict[int, str] = {}
    ppid: dict[int, int] = {}
    rss_pages: dict[int, int] = {}

    for pid in list_pids():
        st = read_stat(pid)
        if not st:
            continue
        c, p, rpages = st
        comm[pid] = c
        ppid[pid] = p
        rss_pages[pid] = rpages

    def is_boundary(pid: int) -> bool:
        c = comm.get(pid, "").lower()
        boundaries = ("systemd", "sddm", "gdm", "lightdm", "greetd")
        return any(c == b or c.startswith(b) for b in boundaries)

    root_cache: dict[int, int] = {}

    def app_root(pid: int) -> int:
        if pid in root_cache:
            return root_cache[pid]
        cur = pid
        seen: set[int] = set()
        while True:
            if cur in seen:
                break
            seen.add(cur)
            parent = ppid.get(cur, 0)
            if parent <= 1 or parent not in ppid or is_boundary(parent):
                break
            cur = parent
        root_cache[pid] = cur
        return cur

    groups: dict[int, dict] = {}
    for pid, rpages in rss_pages.items():
        root = app_root(pid)
        b, used_rss = mem_bytes(pid, rpages)
        g = groups.get(root)
        if not g:
            g = {"bytes": 0, "count": 0, "any_rss": False}
            groups[root] = g
        g["bytes"] += b
        g["count"] += 1
        g["any_rss"] = g["any_rss"] or used_rss

    items = []
    for rpid, g in groups.items():
        if g["bytes"] <= 0:
            continue
        name = read_cmdline(rpid) or comm.get(rpid, str(rpid))
        if len(name) > 38:
            name = name[:38] + "…"
        items.append((int(g["bytes"]), rpid, int(g["count"]), bool(g["any_rss"]), name))

    items.sort(reverse=True)
    return items[:5]


def main() -> int:
    mem_pct, swap_pct = mem_percents()
    mem_text = "--%" if mem_pct is None else f"{mem_pct}%"
    swap_text = "--%" if swap_pct is None else f"{swap_pct}%"
    text = f"{span(PINK,'')} {mem_text} {span(PINK,'')} {swap_text}"

    mi = read_meminfo()
    mt = mi.get("MemTotal", 0) * 1024
    ma = mi.get("MemAvailable", 0) * 1024
    used_b = max(0, mt - ma)

    rows = top5_memory_groups()
    any_rss = any(_any_rss for _b, _rpid, _cnt, _any_rss, _name in rows)

    lines: list[str] = []
    if mt > 0 and mem_pct is not None:
        lines.append(field("RAM已用:", f"{human_bytes(used_b)} / {human_bytes(mt)} ({mem_pct}%)"))

    suffix = "RSS" if any_rss else ""
    lines.append("")
    lines.append(field("Top 5 内存:", f"PSS > {suffix}"))

    for b, _rpid, _cnt, used_rss, name in rows:
        val = f"{human_bytes(int(b))}" + (" -RSS" if used_rss else "")
        lines.append(field(f"{name}:", val))

    tooltip = "\n".join(lines) if lines else field("Top 5 内存:", "N/A")

    print(json.dumps({"text": text, "tooltip": tooltip}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
