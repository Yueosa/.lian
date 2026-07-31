// SPlayer 本地数据库读取 — ~/.config/SPlayer/DataCache/cache.db
// data 列为 BLOB；歌词常为 yrc JSON 行 + 标准 LRC 混排
// playerctl -p 大小写敏感；trackid 常带引号

use crate::lrc::{self, LyricLine};
use serde_json::Value;
use std::path::PathBuf;
use std::process::Command;

pub fn fetch(player_name: &str) -> Vec<LyricLine> {
    if !looks_like_splayer(player_name) {
        return vec![];
    }

    let db_path = splayer_db_path();
    if !db_path.exists() {
        return vec![];
    }

    let song_id = match splayer_track_id(player_name) {
        Some(id) => id,
        None => return vec![],
    };

    let conn = match rusqlite::Connection::open_with_flags(
        &db_path,
        rusqlite::OpenFlags::SQLITE_OPEN_READ_ONLY,
    ) {
        Ok(c) => c,
        Err(_) => return vec![],
    };

    for suffix in &[".json", ".qrc.json"] {
        let key = format!("{}{}", song_id, suffix);
        let row: Result<Vec<u8>, _> = conn.query_row(
            "SELECT data FROM kv_cache WHERE type='lyrics' AND key=?1 LIMIT 1",
            rusqlite::params![key],
            |row| row.get(0),
        );

        if let Ok(bytes) = row {
            let raw = String::from_utf8_lossy(&bytes);
            let lyrics = parse_cache_blob(&raw);
            if !lyrics.is_empty() {
                return lyrics;
            }
        }
    }

    vec![]
}

fn looks_like_splayer(name: &str) -> bool {
    name.to_lowercase().contains("splayer")
}

fn parse_cache_blob(raw: &str) -> Vec<LyricLine> {
    let lyric_text = if let Ok(j) = serde_json::from_str::<Value>(raw) {
        j.get("lrc")
            .and_then(|l| l.get("lyric"))
            .and_then(|v| v.as_str())
            .or_else(|| j.get("lyric").and_then(|v| v.as_str()))
            .unwrap_or(raw)
            .to_string()
    } else {
        raw.to_string()
    };

    parse_mixed_lyrics(&lyric_text)
}

fn parse_mixed_lyrics(text: &str) -> Vec<LyricLine> {
    let mut lines: Vec<LyricLine> = Vec::new();

    for raw in text.lines() {
        let line = raw.trim();
        if line.is_empty() {
            continue;
        }
        if line.starts_with('{') {
            if let Some(l) = parse_yrc_line(line) {
                if !l.text.is_empty() {
                    lines.push(l);
                }
            }
        }
    }

    for l in lrc::parse(text) {
        lines.push(l);
    }

    lines.sort_by(|a, b| a.time.partial_cmp(&b.time).unwrap());
    lines.dedup_by(|a, b| (a.time - b.time).abs() < 0.001 && a.text == b.text);
    lines
}

fn parse_yrc_line(line: &str) -> Option<LyricLine> {
    let v: Value = serde_json::from_str(line).ok()?;
    let ms = v
        .get("t")
        .and_then(|t| t.as_f64().or_else(|| t.as_u64().map(|u| u as f64)))?;
    let parts = v.get("c")?.as_array()?;
    let mut text = String::new();
    for p in parts {
        if let Some(tx) = p.get("tx").and_then(|x| x.as_str()) {
            text.push_str(tx);
        }
    }
    let text = text.trim().to_string();
    if text.is_empty() {
        return None;
    }
    Some(LyricLine {
        time: ms / 1000.0,
        text,
    })
}

fn splayer_db_path() -> PathBuf {
    if let Ok(p) = std::env::var("WAYBAR_SPLAYER_CACHE_DB") {
        let expanded = if p.starts_with('~') {
            p.replacen('~', &std::env::var("HOME").unwrap_or_default(), 1)
        } else {
            p
        };
        return PathBuf::from(expanded);
    }
    let cfg = std::env::var("XDG_CONFIG_HOME")
        .unwrap_or_else(|_| format!("{}/.config", std::env::var("HOME").unwrap_or_default()));
    PathBuf::from(cfg).join("SPlayer/DataCache/cache.db")
}

fn splayer_track_id(player_name: &str) -> Option<String> {
    for p in resolve_playerctl_names(player_name) {
        if let Some(id) = track_id_for(&p) {
            return Some(id);
        }
    }
    None
}

fn resolve_playerctl_names(player_name: &str) -> Vec<String> {
    let mut out = Vec::new();
    let raw = player_name.trim();
    if raw.is_empty() {
        return list_splayer_players();
    }

    let stripped = strip_mpris_prefix(raw);
    let lower = stripped.to_lowercase();
    out.push(stripped.clone());
    if lower != stripped {
        out.push(lower.clone());
    }
    if lower == "splayer" || !lower.contains('.') {
        for p in list_splayer_players() {
            if !out.iter().any(|x| x == &p) {
                out.push(p);
            }
        }
    }
    out
}

fn strip_mpris_prefix(name: &str) -> String {
    const PREFIX: &str = "org.mpris.MediaPlayer2.";
    name.strip_prefix(PREFIX)
        .unwrap_or(name)
        .to_string()
}

fn list_splayer_players() -> Vec<String> {
    let output = match Command::new("playerctl").args(["-l"]).output() {
        Ok(o) => o,
        Err(_) => return vec![],
    };
    String::from_utf8_lossy(&output.stdout)
        .lines()
        .map(|s| s.trim().to_string())
        .filter(|s| s.to_lowercase().starts_with("splayer"))
        .collect()
}

fn track_id_for(player: &str) -> Option<String> {
    let output = Command::new("playerctl")
        .args(["-p", player, "metadata", "mpris:trackid", "-s"])
        .output()
        .ok()?;
    if !output.status.success() {
        return None;
    }
    let out = String::from_utf8_lossy(&output.stdout);
    // playerctl -s：'/com/splayer/track/2124731026'
    let cleaned = out.trim().trim_matches(|c| c == '\'' || c == '"');
    let id = cleaned.rsplit('/').next().unwrap_or("").trim();
    if id.is_empty() || !id.chars().all(|c| c.is_ascii_digit()) {
        None
    } else {
        Some(id.to_string())
    }
}
