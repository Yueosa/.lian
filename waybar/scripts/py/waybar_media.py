#!/usr/bin/env python3
import json
import os
import re
import shutil
import sqlite3
import subprocess
import time
import urllib.parse
from typing import List, Tuple

PINK = "#F5A9B8"
BLUE = "#209CE6"


def pango_escape(s: str) -> str:
    # Waybar may treat module output as Pango markup (escape=false + format-icons markup).
    # Any user-provided text must be escaped to avoid breaking markup parsing.
    s = s or ""
    return (
        s.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
        .replace("'", "&#39;")
    )


def sh(cmd: List[str]) -> str:
    return subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL).strip()


def try_sh(cmd: List[str]) -> str:
    try:
        return sh(cmd)
    except Exception:
        return ""


def span(color: str, text: str, *, escape: bool = True) -> str:
    if escape:
        text = pango_escape(text)
    return f"<span color='{color}'>{text}</span>"


def field(label: str, value: str) -> str:
    return f"{span(PINK, label)} {span(BLUE, value)}"


def choose_player() -> str:
    players_raw = try_sh(["playerctl", "-l"])
    players = [p.strip() for p in players_raw.splitlines() if p.strip()]
    if not players:
        return ""

    # Waybar 里“显示哪个 player”与“点击控制哪个 player”必须一致。
    # 这里选择策略尽量贴近用户直觉：
    # 1) 先选 Playing 的（音乐播放器优先于浏览器）
    # 2) 没有 Playing 再选 Paused 的（同样音乐播放器优先）
    # 3) 再退回其它/第一个

    # 你可以按需扩展这些名称（playerctl -l 可看到实际名字）
    # 注意：有些播放器会以 instance 名出现（例如 splayer.instance123）。
    prefer_prefix = (
        "splayer",
        "neteasecloudmusicgtk4",
        "spotify",
    )
    low_priority_prefix = (
        "chromium",
        "google-chrome",
        "chrome",
        "firefox",
        "brave",
        "vivaldi",
        "edge",
        "microsoft edge",
    )

    def is_low_priority(name: str) -> bool:
        n = name.casefold()
        return any(n.startswith(p.casefold()) for p in low_priority_prefix)

    def name_rank(name: str) -> int:
        n = name.casefold()
        for i, p in enumerate(prefer_prefix):
            if n.startswith(p):
                return i
        return 50

    candidates = []
    for p in players:
        st = try_sh(["playerctl", "-p", p, "status", "-s"])
        status_rank = {"Playing": 0, "Paused": 1}.get(st, 2)
        candidates.append(
            (
                status_rank,
                1 if is_low_priority(p) else 0,
                name_rank(p),
                p,
            )
        )

    candidates.sort(key=lambda x: (x[0], x[1], x[2]))
    return candidates[0][3] if candidates else ""


def norm(s: str) -> str:
    return (s or "").casefold().strip()


def find_lrc_path(title: str, artist: str, album: str) -> str:
    lyrics_dir = os.path.expanduser("~/.lyrics")
    if not os.path.isdir(lyrics_dir):
        return ""

    title_n = norm(title)
    artist_n = norm(artist)
    album_n = norm(album)

    best_path = ""
    best_score = -1
    best_mtime = -1.0

    newest_path = ""
    newest_mtime = -1.0

    try:
        entries = os.listdir(lyrics_dir)
    except Exception:
        return ""

    for name in entries:
        if not name.endswith(".lrc"):
            continue
        path = os.path.join(lyrics_dir, name)
        try:
            st = os.stat(path)
            mtime = st.st_mtime
        except Exception:
            continue

        if mtime > newest_mtime:
            newest_mtime = mtime
            newest_path = path

        name_n = norm(name)
        score = 0
        if title_n and title_n in name_n:
            score += 10
        if artist_n and artist_n in name_n:
            score += 10
        if title_n and artist_n and (title_n in name_n and artist_n in name_n):
            score += 80
        if album_n and album_n in name_n:
            score += 20

        if score > best_score or (score == best_score and mtime > best_mtime):
            best_score = score
            best_mtime = mtime
            best_path = path

    if best_score <= 0 and newest_path:
        if time.time() - newest_mtime <= 3600:
            return newest_path

    return best_path if best_score > 0 else ""


def url_to_local_path(url: str) -> str:
    url = (url or "").strip()
    if not url:
        return ""
    if url.startswith("file://"):
        # file:///home/user/Music/a.flac
        path = urllib.parse.unquote(url[7:])
        return path
    return ""


def find_lrc_near_media(url: str) -> str:
    path = url_to_local_path(url)
    if not path:
        return ""
    # 同目录同名 .lrc：foo.mp3 -> foo.lrc
    base, _ext = os.path.splitext(path)
    cand = base + ".lrc"
    return cand if os.path.isfile(cand) else ""


def find_lrc_in_extra_dirs(title: str, artist: str, album: str) -> str:
    # 允许用户通过环境变量追加歌词目录（冒号分隔）
    # 例如：WAYBAR_LYRICS_DIRS="$HOME/.lyrics:$HOME/.local/share/splayer/lyrics"
    raw = os.environ.get("WAYBAR_LYRICS_DIRS", "").strip()
    if not raw:
        return ""

    dirs = [os.path.expanduser(p) for p in raw.split(":") if p.strip()]
    for d in dirs:
        if not os.path.isdir(d):
            continue
        # 临时复用 find_lrc_path 的匹配逻辑：通过切换 ~/.lyrics 的概念
        # 为了最小改动，这里做一个轻量扫描。
        title_n = norm(title)
        artist_n = norm(artist)
        album_n = norm(album)

        best_path = ""
        best_score = -1
        best_mtime = -1.0
        try:
            entries = os.listdir(d)
        except Exception:
            continue

        for name in entries:
            if not name.endswith(".lrc"):
                continue
            path = os.path.join(d, name)
            try:
                st = os.stat(path)
                mtime = st.st_mtime
            except Exception:
                continue

            name_n = norm(name)
            score = 0
            if title_n and title_n in name_n:
                score += 10
            if artist_n and artist_n in name_n:
                score += 10
            if title_n and artist_n and (title_n in name_n and artist_n in name_n):
                score += 80
            if album_n and album_n in name_n:
                score += 20

            if score > best_score or (score == best_score and mtime > best_mtime):
                best_score = score
                best_mtime = mtime
                best_path = path

        if best_score > 0 and best_path:
            return best_path

    return ""


def write_selected_player_cache(player: str) -> None:
    cache_dir = os.path.join(os.path.expanduser(os.environ.get("XDG_CACHE_HOME", "~/.cache")), "waybar")
    try:
        os.makedirs(cache_dir, exist_ok=True)
        with open(os.path.join(cache_dir, "media_player"), "w", encoding="utf-8") as f:
            f.write((player or "").strip() + "\n")
    except Exception:
        pass


def is_splayer(name: str) -> bool:
    return (name or "").casefold().startswith("splayer")


def parse_splayer_track_id(trackid: str) -> str:
    # 例：/com/splayer/track/501848550
    trackid = (trackid or "").strip()
    if not trackid:
        return ""

    # playerctl 有时会把 dbus object path 用引号包起来
    if (trackid.startswith("'") and trackid.endswith("'")) or (trackid.startswith('"') and trackid.endswith('"')):
        trackid = trackid[1:-1].strip()

    m = re.search(r"/track/(\d+)$", trackid)
    return m.group(1) if m else ""


def get_splayer_cache_db_path() -> str:
    # SPlayer (Electron) 默认 userData: $XDG_CONFIG_HOME/SPlayer
    # 默认 cachePath: join(userData, 'DataCache')，cache.db 位于 cachePath 下。
    # 允许通过环境变量覆盖，便于便携模式或自定义设置。
    override = os.environ.get("WAYBAR_SPLAYER_CACHE_DB", "").strip()
    if override:
        p = os.path.expanduser(override)
        return p if os.path.isfile(p) else ""

    cfg_home = os.path.expanduser(os.environ.get("XDG_CONFIG_HOME", "~/.config"))
    user_data = os.path.join(cfg_home, "SPlayer")

    cache_path = os.path.join(user_data, "DataCache")
    cfg = os.path.join(user_data, "config.json")
    try:
        with open(cfg, "r", encoding="utf-8") as f:
            data = json.load(f)
        cp = (data.get("cachePath") or "").strip()
        if cp:
            cache_path = os.path.expanduser(cp)
    except Exception:
        pass

    db = os.path.join(cache_path, "cache.db")
    return db if os.path.isfile(db) else ""


_TS_RE = re.compile(r"\[(?:(\d+):)?(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]")


def parse_lrc_text(text: str) -> List[Tuple[int, str]]:
    text = text or ""

    offset_ms = 0
    m = re.search(r"\[offset:([+-]?\d+)\]", text, flags=re.IGNORECASE)
    if m:
        try:
            offset_ms = int(m.group(1))
        except Exception:
            offset_ms = 0

    entries: List[Tuple[int, str]] = []
    for line in text.splitlines():
        line = line.strip("\ufeff").strip()
        if not line:
            continue
        if re.match(r"^\[(ti|ar|al|by|re|ve|length|offset):", line, flags=re.IGNORECASE):
            continue

        stamps = list(_TS_RE.finditer(line))
        if not stamps:
            continue

        lyric = _TS_RE.sub("", line).strip()
        if not lyric:
            continue

        for s in stamps:
            hh = int(s.group(1) or 0)
            mm = int(s.group(2) or 0)
            ss = int(s.group(3) or 0)
            frac = s.group(4) or "0"
            if len(frac) == 1:
                ms = int(frac) * 100
            elif len(frac) == 2:
                ms = int(frac) * 10
            else:
                ms = int(frac[:3])

            t_ms = (((hh * 60) + mm) * 60 + ss) * 1000 + ms + offset_ms
            if t_ms < 0:
                t_ms = 0
            entries.append((t_ms, lyric))

    entries.sort(key=lambda x: x[0])
    return entries


def parse_netease_yrc_entries(text: str) -> List[Tuple[int, str]]:
    # SPlayer 缓存中可能出现网易云歌词的“yrc”风格：每行是一个 JSON 对象
    # 例如：{"t": 12345, "c": [{"tx": "hello"}, {"tx": " world"}]}
    text = (text or "").strip()
    if not text:
        return []

    entries: List[Tuple[int, str]] = []
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        if line.startswith('\\{') and line.endswith('}'):  # 形如 \{"t":...}
            line = line[1:]
        if not (line.startswith("{") and line.endswith("}")):
            continue
        try:
            obj = json.loads(line)
        except Exception:
            continue

        t = obj.get("t")
        c = obj.get("c")
        if not isinstance(t, int):
            continue
        if not isinstance(c, list):
            continue
        parts: List[str] = []
        for seg in c:
            if isinstance(seg, dict) and isinstance(seg.get("tx"), str):
                parts.append(seg["tx"])
        lyric = "".join(parts).strip()
        if lyric:
            entries.append((max(t, 0), lyric))

    entries.sort(key=lambda x: x[0])
    return entries


def normalize_escaped_lyrics_text(text: str) -> str:
    # SPlayer/平台接口有时会把歌词再额外 JSON-escape 一层（出现 \n、\"）。
    # 这里做一个保守的反转义，让解析器能吃到真实换行/引号。
    text = text or ""
    if "\\n" in text and "\n" not in text:
        text = text.replace("\\n", "\n")
    if "\\\"" in text:
        text = text.replace("\\\"", '"')
    return text


def looks_like_blob(s: str) -> bool:
    s = (s or "").strip()
    if not s:
        return False
    if len(s) > 200:
        return True
    if s.startswith("{") and any(k in s for k in ('"lrc"', '"tlyric"', '"romalrc"', '"code"', '"sgc"')):
        return True
    if s.startswith("\\{"):
        return True
    return False


def parse_best_timed_lyrics(text: str) -> List[Tuple[int, str]]:
    # SPlayer 缓存里可能混合：
    # - 标准 LRC（[mm:ss.xx]xxx）
    # - 网易云 yrc 风格（每行 JSON：{"t":ms,"c":[{"tx":...}]}
    # - 甚至两者同时存在或夹杂其它行
    # 这里同时解析两种并择优，避免仅凭出现一次时间戳就误判。
    lrc_entries = parse_lrc_text(text)
    yrc_entries = parse_netease_yrc_entries(text)
    if len(yrc_entries) > len(lrc_entries):
        return yrc_entries
    return lrc_entries


def parse_lrc_lines(path: str) -> List[Tuple[int, str]]:
    try:
        raw = open(path, "rb").read()
    except Exception:
        return []

    text = raw.decode("utf-8", errors="ignore")
    return parse_lrc_text(text)


_TTML_P_RE = re.compile(r"<p\b[^>]*?\bbegin=\"([^\"]+)\"[^>]*>(.*?)</p>", flags=re.IGNORECASE | re.DOTALL)


def _parse_ttml_time_to_ms(s: str) -> int:
    # 常见：00:01:23.456 或 01:23.456
    s = (s or "").strip()
    m = re.match(r"^(?:(\d+):)?(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?$", s)
    if not m:
        return 0
    hh = int(m.group(1) or 0)
    mm = int(m.group(2) or 0)
    ss = int(m.group(3) or 0)
    frac = m.group(4) or "0"
    if len(frac) == 1:
        ms = int(frac) * 100
    elif len(frac) == 2:
        ms = int(frac) * 10
    else:
        ms = int(frac[:3])
    return (((hh * 60) + mm) * 60 + ss) * 1000 + ms


def current_lyric_ttml(ttml: str, pos_ms: int) -> str:
    ttml = ttml or ""
    last = ""
    for begin_s, body in _TTML_P_RE.findall(ttml):
        begin_ms = _parse_ttml_time_to_ms(begin_s)
        if begin_ms > pos_ms:
            break
        # 轻量去标签
        text = re.sub(r"<[^>]+>", "", body)
        text = " ".join(text.split()).strip()
        if text:
            last = text
    return last


def splayer_get_current_lyric(player: str, pos_ms: int) -> str:
    # 通过 mpris:trackid 获取 SPlayer 的内部歌曲 id，并从 cache.db 读取歌词缓存。
    trackid = try_sh(["playerctl", "-p", player, "metadata", "mpris:trackid", "-s"])
    song_id = parse_splayer_track_id(trackid)
    if not song_id:
        return ""

    db_path = get_splayer_cache_db_path()
    if not db_path:
        return ""

    # SPlayer 的 LyricManager 缓存 key 规则：${id}.json / ${id}.qrc.json / ${id}.ttml
    keys = (f"{song_id}.json", f"{song_id}.qrc.json", f"{song_id}.ttml")

    try:
        conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    except Exception:
        return ""

    try:
        cur = conn.cursor()
        for k in keys:
            try:
                row = cur.execute(
                    "SELECT data FROM kv_cache WHERE type = ? AND key = ? LIMIT 1",
                    ("lyrics", k),
                ).fetchone()
            except Exception:
                row = None

            if not row or row[0] is None:
                continue

            raw = row[0]
            if isinstance(raw, memoryview):
                raw = raw.tobytes()
            if isinstance(raw, bytes):
                payload = raw.decode("utf-8", errors="ignore")
            else:
                payload = str(raw)

            if k.endswith(".ttml"):
                line = current_lyric_ttml(payload, pos_ms)
                if line:
                    return line
                continue

            # .json / .qrc.json：通常是 JSON 字符串，里面包含 lrc/lyric 字段
            try:
                j = json.loads(payload)
            except Exception:
                j = None

            if isinstance(j, dict):
                # Netease 常见：{ lrc: { lyric: "[00:..]..." }, tlyric: {...} }
                lrc_text = ""
                if isinstance(j.get("lrc"), dict) and isinstance(j["lrc"].get("lyric"), str):
                    lrc_text = j["lrc"]["lyric"]
                elif isinstance(j.get("lyric"), str):
                    lrc_text = j["lyric"]
                elif isinstance(j.get("lrc"), str):
                    lrc_text = j["lrc"]

                if lrc_text:
                    lrc_text = normalize_escaped_lyrics_text(lrc_text)
                    entries = parse_best_timed_lyrics(lrc_text)
                    line = current_lyric(entries, pos_ms).strip() if entries else ""
                    if line:
                        return line

            # 兜底：如果 payload 本身就是 LRC 文本
            entries = parse_best_timed_lyrics(payload)
            line = current_lyric(entries, pos_ms).strip() if entries else ""
            if line:
                return line

        return ""
    finally:
        try:
            conn.close()
        except Exception:
            pass


def current_lyric(entries: List[Tuple[int, str]], pos_ms: int) -> str:
    if not entries:
        return ""
    last = ""
    for t_ms, lyric in entries:
        if t_ms <= pos_ms:
            last = lyric
        else:
            break
    return last


def main() -> int:
    if not shutil.which("playerctl"):
        print(
            json.dumps(
                {"text": "YeaArch-Sakurine", "class": "stopped", "alt": "stopped", "tooltip": "playerctl not found"},
                ensure_ascii=False,
            )
        )
        return 0

    player = choose_player()
    if not player:
        print(json.dumps({"text": "YeaArch-Sakurine", "class": "stopped", "alt": "stopped", "tooltip": "No player"}, ensure_ascii=False))
        return 0

    # 让点击/滚轮控制与当前显示保持一致
    write_selected_player_cache(player)

    status = try_sh(["playerctl", "-p", player, "status", "-s"])
    if status not in ("Playing", "Paused"):
        print(
            json.dumps(
                {"text": "YeaArch-Sakurine", "class": "stopped", "alt": "stopped", "tooltip": "Arch Linux"},
                ensure_ascii=False,
            )
        )
        return 0

    title = try_sh(["playerctl", "-p", player, "metadata", "title", "-s"])
    artist = try_sh(["playerctl", "-p", player, "metadata", "artist", "-s"])
    album = try_sh(["playerctl", "-p", player, "metadata", "album", "-s"])
    url = try_sh(["playerctl", "-p", player, "metadata", "xesam:url", "-s"])

    full = (title or "Unknown Title").strip()
    if artist.strip():
        full = f"{full} - {artist.strip()}"

    pos_s = try_sh(["playerctl", "-p", player, "position", "-s"])
    try:
        pos_ms = int(float(pos_s) * 1000)
    except Exception:
        pos_ms = 0

    lyric_line = ""
    lrc_path = find_lrc_near_media(url)
    if not lrc_path:
        lrc_path = find_lrc_in_extra_dirs(title, artist, album)
    if not lrc_path:
        lrc_path = find_lrc_path(title, artist, album)
    if lrc_path:
        entries = parse_lrc_lines(lrc_path)
        lyric_line = current_lyric(entries, pos_ms).strip()

    if not lyric_line and is_splayer(player):
        lyric_line = splayer_get_current_lyric(player, pos_ms).strip()

    # 避免把接口 JSON 或异常超长内容当歌词显示出来
    if looks_like_blob(lyric_line):
        lyric_line = ""

    # The module format includes Pango markup in {icon}; keep {text} safe.
    text = pango_escape(lyric_line if lyric_line else full)

    cls = "playing" if status == "Playing" else "paused"

    tooltip_lines = [field("歌名:", (title or "").strip() or "Unknown")]
    if artist.strip():
        tooltip_lines.append(field("歌手:", artist.strip()))
    if album.strip():
        tooltip_lines.append(field("专辑:", album.strip()))
    if lyric_line:
        tooltip_lines.append(field("歌词:", lyric_line))

    tooltip = "\n".join(tooltip_lines)

    print(json.dumps({"text": text, "class": cls, "alt": cls, "tooltip": tooltip}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
