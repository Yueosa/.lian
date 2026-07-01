// SPlayer 本地数据库读取 — ~/.config/SPlayer/DataCache/cache.db
use crate::lrc::{self, LyricLine};
use std::path::PathBuf;

pub fn fetch(player_name: &str) -> Vec<LyricLine> {
    if !player_name.to_lowercase().starts_with("splayer") { return vec![]; }

    let db_path = splayer_db_path();
    if !db_path.exists() { return vec![]; }

    let song_id = match splayer_track_id(player_name) {
        Some(id) => id,
        None => return vec![],
    };

    let conn = match rusqlite::Connection::open_with_flags(
        &db_path, rusqlite::OpenFlags::SQLITE_OPEN_READ_ONLY
    ) {
        Ok(c) => c,
        Err(_) => return vec![],
    };

    for suffix in &[".json", ".qrc.json"] {
        let key = format!("{}{}", song_id, suffix);
        let row: Result<String, _> = conn.query_row(
            "SELECT data FROM kv_cache WHERE type='lyrics' AND key=?1 LIMIT 1",
            rusqlite::params![key],
            |row| row.get(0),
        );

        if let Ok(raw) = row {
            if let Ok(j) = serde_json::from_str::<serde_json::Value>(&raw) {
                let lrc_text = j.get("lrc").and_then(|l| l.get("lyric")).and_then(|v| v.as_str())
                    .or_else(|| j.get("lyric").and_then(|v| v.as_str()))
                    .unwrap_or(&raw);
                let lyrics = lrc::parse(lrc_text);
                if !lyrics.is_empty() { return lyrics; }
            }
        }
    }

    vec![]
}

fn splayer_db_path() -> PathBuf {
    if let Ok(p) = std::env::var("WAYBAR_SPLAYER_CACHE_DB") {
        let expanded = if p.starts_with('~') {
            p.replacen('~', &std::env::var("HOME").unwrap_or_default(), 1)
        } else { p };
        return PathBuf::from(expanded);
    }
    let cfg = std::env::var("XDG_CONFIG_HOME")
        .unwrap_or_else(|_| format!("{}/.config", std::env::var("HOME").unwrap_or_default()));
    PathBuf::from(cfg).join("SPlayer/DataCache/cache.db")
}

fn splayer_track_id(player_name: &str) -> Option<String> {
    use std::process::Command;
    let output = Command::new("playerctl")
        .args(["-p", player_name, "metadata", "mpris:trackid", "-s"])
        .output().ok()?;
    let out = String::from_utf8_lossy(&output.stdout);
    // 从 "xxx/track/12345" 提取数字 ID
    let id = out.trim().rsplit('/').next().unwrap_or("");
    if id.is_empty() || !id.chars().all(|c| c.is_ascii_digit()) { None }
    else { Some(id.to_string()) }
}
