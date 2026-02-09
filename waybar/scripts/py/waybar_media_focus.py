#!/usr/bin/env python3
import json
import shutil
import subprocess


def sh(cmd):
    return subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL).strip()


def try_sh(cmd):
    try:
        return sh(cmd)
    except Exception:
        return ""


def choose_player() -> str:
    try:
        players = [p.strip() for p in sh(["playerctl", "-l"]).splitlines() if p.strip()]
    except Exception:
        players = []

    if not players:
        return ""

    best = None
    best_rank = 99
    for p in players:
        try:
            st = sh(["playerctl", "-p", p, "status", "-s"]).strip()
        except Exception:
            st = ""
        rank = {"Playing": 0, "Paused": 1}.get(st, 2)
        if rank < best_rank:
            best, best_rank = p, rank

    return best or players[0]


def norm(s: str) -> str:
    return (s or "").strip().lower()


def focus(player: str, title: str) -> None:
    player_l = player.lower()
    patterns = {player_l}
    patterns |= {player_l.replace(".", ""), player_l.replace("-", "")}

    known = {
        "spotify": {"spotify", "Spotify"},
        "firefox": {"firefox", "Firefox"},
        "chromium": {"chromium", "Chromium", "google-chrome", "Google-chrome"},
        "brave": {"brave", "Brave-browser"},
        "mpv": {"mpv"},
        "vlc": {"vlc", "Vlc"},
    }
    for k, vals in known.items():
        if k in player_l:
            patterns |= {v.lower() for v in vals}

    try:
        clients_raw = subprocess.check_output(["hyprctl", "clients", "-j"], text=True)
        clients = json.loads(clients_raw)
    except Exception:
        return

    def score(c: dict) -> int:
        cls = norm(c.get("class") or c.get("initialClass") or "")
        appid = norm(c.get("appid") or "")
        ttl = (c.get("title") or "").strip()
        ttl_l = ttl.lower()

        s = 999
        if cls in patterns or appid in patterns:
            s = min(s, 0)
        if player_l and (player_l in cls or player_l in appid):
            s = min(s, 10)
        if title and title.lower() in ttl_l:
            s = min(s, 20)
        return s

    best = None
    best_s = 999
    for c in clients:
        s = score(c)
        if s < best_s:
            best_s = s
            best = c

    if not best or best_s >= 999:
        return

    addr = best.get("address")
    if not addr:
        return

    subprocess.run(
        ["hyprctl", "dispatch", "focuswindow", f"address:{addr}"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def main() -> int:
    if not shutil.which("playerctl") or not shutil.which("hyprctl"):
        return 0

    player = choose_player()
    if not player:
        return 0

    title = try_sh(["playerctl", "-p", player, "metadata", "title", "-s"])
    focus(player, title)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
