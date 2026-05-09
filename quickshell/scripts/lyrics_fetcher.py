#!/usr/bin/env python3
import sys
import json
import urllib.request
import urllib.parse
import re
import os
import hashlib
import base64
import sqlite3
import time

# ================= 配置区 =================
CACHE_BASE = os.path.expanduser(os.environ.get("XDG_CACHE_HOME", "~/.cache"))
CACHE_DIR = os.path.join(CACHE_BASE, "quickshell", "lyrics")
LEGACY_CACHE_DIR = "/tmp/qs_lyrics_cache"
if not os.path.exists(CACHE_DIR):
    os.makedirs(CACHE_DIR)

HEADERS = {
    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
}
# =========================================


def get_cache_path(title, artist):
    safe_name = f"{title}-{artist}".encode("utf-8", errors="ignore")
    hash_str = hashlib.md5(safe_name).hexdigest()
    return os.path.join(CACHE_DIR, f"{hash_str}.json")


def get_legacy_cache_path(title, artist):
    safe_name = f"{title}-{artist}".encode("utf-8", errors="ignore")
    hash_str = hashlib.md5(safe_name).hexdigest()
    return os.path.join(LEGACY_CACHE_DIR, f"{hash_str}.json")


# ============================================================
# 本地歌词查找（~/.lyrics/  +  媒体文件同目录  +  SPlayer cache.db）
# ============================================================

def _norm(s):
    return (s or "").casefold().strip()


def parse_lrc_file(path):
    try:
        text = open(path, "rb").read().decode("utf-8", errors="ignore")
        return parse_lrc(text)
    except Exception:
        return []


def find_local_lrc(title, artist):
    """在 ~/.lyrics/ 中按文件名相似度匹配 .lrc"""
    lyrics_dir = os.path.expanduser("~/.lyrics")
    if not os.path.isdir(lyrics_dir):
        return []

    title_n = _norm(title)
    artist_n = _norm(artist)

    best_path, best_score, best_mtime = "", -1, -1.0
    newest_path, newest_mtime = "", -1.0

    try:
        entries = os.listdir(lyrics_dir)
    except Exception:
        return []

    for name in entries:
        if not name.endswith(".lrc"):
            continue
        path = os.path.join(lyrics_dir, name)
        try:
            mtime = os.stat(path).st_mtime
        except Exception:
            continue
        if mtime > newest_mtime:
            newest_mtime, newest_path = mtime, path

        name_n = name.casefold()
        score = 0
        if title_n and title_n in name_n:
            score += 10
        if artist_n and artist_n in name_n:
            score += 10
        if title_n and artist_n and (title_n in name_n and artist_n in name_n):
            score += 80
        if score > best_score or (score == best_score and mtime > best_mtime):
            best_score, best_mtime, best_path = score, mtime, path

    if best_score > 0:
        return parse_lrc_file(best_path)
    # 最近 1h 内更新的文件作为兜底（播放器刚写入的歌词文件）
    if newest_path and time.time() - newest_mtime <= 3600:
        return parse_lrc_file(newest_path)
    return []


def find_lrc_near_media(url):
    """媒体文件同目录同名 .lrc（file:///.../song.mp3 → song.lrc）"""
    url = (url or "").strip()
    if not url.startswith("file://"):
        return []
    import urllib.parse as _up
    path = _up.unquote(url[7:])
    base, _ = os.path.splitext(path)
    lrc = base + ".lrc"
    return parse_lrc_file(lrc) if os.path.isfile(lrc) else []


def _splayer_track_id(player_name):
    try:
        import subprocess
        out = subprocess.check_output(
            ["playerctl", "-p", player_name, "metadata", "mpris:trackid", "-s"],
            text=True, stderr=subprocess.DEVNULL
        ).strip()
        m = re.search(r"/track/(\d+)$", out)
        return m.group(1) if m else ""
    except Exception:
        return ""


def fetch_splayer_db(player_name):
    """从 SPlayer cache.db 读取 LRC 歌词"""
    cfg_home = os.path.expanduser(os.environ.get("XDG_CONFIG_HOME", "~/.config"))
    db_path = os.path.join(cfg_home, "SPlayer", "DataCache", "cache.db")
    # 允许通过环境变量覆盖
    db_path = os.path.expanduser(os.environ.get("WAYBAR_SPLAYER_CACHE_DB", db_path))
    if not os.path.isfile(db_path):
        return []

    song_id = _splayer_track_id(player_name)
    if not song_id:
        return []

    try:
        conn = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
        cur = conn.cursor()
        for key in (f"{song_id}.json", f"{song_id}.qrc.json"):
            row = cur.execute(
                "SELECT data FROM kv_cache WHERE type=? AND key=? LIMIT 1",
                ("lyrics", key)
            ).fetchone()
            if not row or row[0] is None:
                continue
            raw = row[0]
            if isinstance(raw, memoryview):
                raw = raw.tobytes()
            payload = raw.decode("utf-8", errors="ignore") if isinstance(raw, bytes) else str(raw)
            try:
                j = json.loads(payload)
            except Exception:
                j = None
            lrc_text = ""
            if isinstance(j, dict):
                if isinstance(j.get("lrc"), dict) and isinstance(j["lrc"].get("lyric"), str):
                    lrc_text = j["lrc"]["lyric"]
                elif isinstance(j.get("lyric"), str):
                    lrc_text = j["lyric"]
            if not lrc_text:
                lrc_text = payload
            entries = parse_lrc(lrc_text)
            if entries:
                conn.close()
                return entries
        conn.close()
    except Exception:
        pass
    return []


# ============================================================

def parse_lrc(lrc_text):
    """解析 LRC 文本为 [{time:秒, text:词}, ...]"""
    if not lrc_text:
        return []
    lines = []
    pattern = re.compile(r"\[(\d{2}):(\d{2})[\.:](\d{2,3})\](.*)")
    lrc_text = (
        lrc_text.replace("&apos;", "'").replace("&quot;", '"').replace("&amp;", "&")
    )

    for line in lrc_text.split("\n"):
        line = line.strip()
        if not line:
            continue
        match = pattern.match(line)
        if match:
            minutes = int(match.group(1))
            seconds = int(match.group(2))
            ms_str = match.group(3)
            ms = int(ms_str) * 10 if len(ms_str) == 2 else int(ms_str)
            total_seconds = minutes * 60 + seconds + ms / 1000
            text = match.group(4).strip()

            if text and not text.lower().startswith(
                ("offset:", "by:", "al:", "ti:", "ar:")
            ):
                lines.append({"time": total_seconds, "text": text})

    lines.sort(key=lambda x: x["time"])
    return lines


def request_url(url, data=None, headers=None):
    if headers is None:
        headers = HEADERS
    try:
        req = urllib.request.Request(url, data=data, headers=headers)
        with urllib.request.urlopen(req, timeout=3) as response:
            return json.loads(response.read().decode())
    except Exception:
        return None


# --- 1. QQ 音乐源 (Priority 1) ---
def fetch_qq(track, artist):
    qq_headers = HEADERS.copy()
    qq_headers["Referer"] = "https://y.qq.com/"
    try:
        keyword = f"{track} {artist}"
        search_url = f"https://c.y.qq.com/soso/fcgi-bin/client_search_cp?w={urllib.parse.quote(keyword)}&format=json"
        search_data = request_url(search_url, headers=qq_headers)

        songmid = ""
        if (
            search_data
            and "data" in search_data
            and "song" in search_data["data"]
            and "list" in search_data["data"]["song"]
        ):
            song_list = search_data["data"]["song"]["list"]
            if song_list:
                songmid = song_list[0]["songmid"]

        if not songmid:
            return []

        lyric_url = f"https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg?songmid={songmid}&format=json&nobase64=1"
        lyric_data = request_url(lyric_url, headers=qq_headers)

        if lyric_data and "lyric" in lyric_data:
            raw_lrc = lyric_data["lyric"]
            try:
                decoded_lrc = base64.b64decode(raw_lrc).decode("utf-8")
            except:
                decoded_lrc = raw_lrc
            return parse_lrc(decoded_lrc)
    except Exception:
        pass
    return []


# --- 2. 网易云音乐源 (Priority 2) ---
def fetch_netease(track, artist):
    search_url = "http://music.163.com/api/search/get/"
    ne_headers = HEADERS.copy()
    ne_headers["Referer"] = "http://music.163.com/"
    post_data = urllib.parse.urlencode(
        {"s": f"{track} {artist}", "type": 1, "offset": 0, "total": "true", "limit": 1}
    ).encode("utf-8")

    try:
        res = request_url(search_url, data=post_data, headers=ne_headers)
        if (
            res
            and "result" in res
            and "songs" in res["result"]
            and res["result"]["songs"]
        ):
            song_id = res["result"]["songs"][0]["id"]
            lyric_url = f"http://music.163.com/api/song/lyric?os=pc&id={song_id}&lv=-1&kv=-1&tv=-1"
            lrc_data = request_url(lyric_url, headers=ne_headers)
            if lrc_data and "lrc" in lrc_data and "lyric" in lrc_data["lrc"]:
                return parse_lrc(lrc_data["lrc"]["lyric"])
    except Exception:
        pass
    return []


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(json.dumps([{"time": 0, "text": "等待播放..."}]))
        sys.exit(0)

    title = sys.argv[1]
    artist = sys.argv[2] if len(sys.argv) > 2 else ""
    player_name = sys.argv[3] if len(sys.argv) > 3 else ""
    media_url = sys.argv[4] if len(sys.argv) > 4 else ""
    cache_file = get_cache_path(title, artist)
    legacy_cache_file = get_legacy_cache_path(title, artist)

    # 0. 磁盘缓存（最高优先，已有结果直接返回）
    if os.path.exists(cache_file):
        try:
            with open(cache_file, "r") as f:
                cached_data = json.load(f)
                if cached_data:
                    print(json.dumps(cached_data))
                    sys.exit(0)
        except Exception:
            pass

    if os.path.exists(legacy_cache_file):
        try:
            with open(legacy_cache_file, "r") as f:
                cached_data = json.load(f)
                if cached_data:
                    print(json.dumps(cached_data))
                    sys.exit(0)
        except Exception:
            pass

    # 1. 媒体文件同目录 .lrc（本地，最快）
    lyrics = find_lrc_near_media(media_url)

    # 2. ~/.lyrics/ 目录模糊匹配
    if not lyrics:
        lyrics = find_local_lrc(title, artist)

    # 3. SPlayer cache.db
    if not lyrics and player_name.casefold().startswith("splayer"):
        lyrics = fetch_splayer_db(player_name)

    # 4. QQ 音乐
    if not lyrics:
        lyrics = fetch_qq(title, artist)

    # 5. 网易云音乐
    if not lyrics:
        lyrics = fetch_netease(title, artist)

    if not lyrics:
        lyrics = [{"time": 0, "text": "暂无歌词"}]
    else:
        # 本地来源也写入缓存，避免重复解析文件
        try:
            with open(cache_file, "w") as f:
                json.dump(lyrics, f)
        except Exception:
            pass

    print(json.dumps(lyrics))
