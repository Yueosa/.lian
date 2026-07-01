// 本地歌词查找：~/.lyrics/ + 媒体文件同目录 .lrc
use crate::lrc::{self, LyricLine};
use std::path::Path;

/// 媒体文件同目录同名 .lrc（file:///.../song.mp3 → song.lrc）
pub fn near_media(media_url: &str) -> Vec<LyricLine> {
    let url = media_url.trim();
    if !url.starts_with("file://") { return vec![]; }
    let path = urlencoding(&url[7..]);
    let base = Path::new(&path).with_extension("");
    let lrc = base.with_extension("lrc");
    lrc::parse_file(&lrc)
}

/// ~/.lyrics/ 目录模糊匹配（文件名包含 title 或 artist）
pub fn from_home_dir(title: &str, artist: &str) -> Vec<LyricLine> {
    let dir = match dirs() { Some(d) => d, None => return vec![] };
    if !dir.is_dir() { return vec![]; }

    let title_n = title.to_lowercase();
    let artist_n = artist.to_lowercase();

    let mut best: Option<(Vec<LyricLine>, i32)> = None;
    let mut newest_path: Option<String> = None;
    let mut newest_mtime: f64 = -1.0;

    if let Ok(entries) = std::fs::read_dir(&dir) {
        for entry in entries.flatten() {
            let path = entry.path();
            if path.extension().map_or(true, |e| e != "lrc") { continue; }
            let name = path.file_name().unwrap_or_default().to_string_lossy().to_lowercase();
            let mtime = std::fs::metadata(&path).ok()
                .and_then(|m| m.modified().ok())
                .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
                .map(|d| d.as_secs_f64()).unwrap_or(0.0);

            if mtime > newest_mtime {
                newest_mtime = mtime;
                newest_path = Some(path.to_string_lossy().to_string());
            }

            let mut score = 0;
            if !title_n.is_empty() && name.contains(&title_n) { score += 10; }
            if !artist_n.is_empty() && name.contains(&artist_n) { score += 10; }
            if !title_n.is_empty() && !artist_n.is_empty()
                && name.contains(&title_n) && name.contains(&artist_n) { score += 80; }

            if score > 0 {
                let lyrics = lrc::parse_file(&path);
                if !lyrics.is_empty() {
                    match &best {
                        Some((_, s)) if score <= *s => {}
                        _ => { best = Some((lyrics, score)); }
                    }
                }
            }
        }
    }

    if let Some((lyrics, _)) = best { return lyrics; }

    // 兜底：最近 1 小时内更新的文件
    if let Some(p) = newest_path {
        let path = Path::new(&p);
        let lyrics = lrc::parse_file(path);
        if !lyrics.is_empty() { return lyrics; }
    }

    vec![]
}

fn dirs() -> Option<std::path::PathBuf> {
    let home = std::env::var("HOME").ok()?;
    let dir = std::path::PathBuf::from(home).join(".lyrics");
    Some(dir)
}

fn urlencoding(s: &str) -> String {
    let mut out = String::new();
    for b in s.bytes() {
        match b {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' | b'/' => out.push(b as char),
            b'%' => {
                // 已经 encoded 的保留
                out.push(b as char);
            }
            b' ' => out.push_str("%20"),
            _ => out.push_str(&format!("%{:02X}", b)),
        }
    }
    out
}
