// 本地歌词查找：~/.lyrics/ + 媒体文件同目录 .lrc
// ~/.lyrics：必须标题/艺人文件名匹配达标；去掉「最近文件」兜底（易串歌）

use crate::lrc::{self, LyricLine};
use crate::match_score;
use std::path::Path;

/// 媒体文件同目录同名 .lrc（file:///.../song.mp3 → song.lrc）
pub fn near_media(media_url: &str) -> Vec<LyricLine> {
    let url = media_url.trim();
    if !url.starts_with("file://") {
        return vec![];
    }
    let path = decode_file_url(&url[7..]);
    let base = Path::new(&path).with_extension("");
    let lrc = base.with_extension("lrc");
    lrc::parse_file(&lrc)
}

/// ~/.lyrics/：文件名与 title/artist 打分，过门槛才用
pub fn from_home_dir(title: &str, artist: &str) -> Vec<LyricLine> {
    let dir = match dirs() {
        Some(d) => d,
        None => return vec![],
    };
    if !dir.is_dir() {
        return vec![];
    }

    let mut best: Option<(Vec<LyricLine>, i32)> = None;

    if let Ok(entries) = std::fs::read_dir(&dir) {
        for entry in entries.flatten() {
            let path = entry.path();
            if path.extension().map_or(true, |e| e != "lrc") {
                continue;
            }
            let name = path
                .file_stem()
                .unwrap_or_default()
                .to_string_lossy()
                .to_string();

            // 文件名常是 "title - artist" 或 "artist - title"；两边都试
            let (a, b) = split_name(&name);
            let s1 = match_score::score_pair(title, artist, &a, &b);
            let s2 = match_score::score_pair(title, artist, &b, &a);
            let s3 = match_score::score_pair(title, artist, &name, "");
            let score = s1.max(s2).max(s3);

            if !match_score::accept(score) {
                continue;
            }

            let lyrics = lrc::parse_file(&path);
            if lyrics.is_empty() {
                continue;
            }
            match &best {
                Some((_, s)) if score <= *s => {}
                _ => best = Some((lyrics, score)),
            }
        }
    }

    best.map(|(l, _)| l).unwrap_or_default()
}

fn split_name(name: &str) -> (String, String) {
    for sep in [" - ", " – ", " — ", "-", "_"] {
        if let Some((a, b)) = name.split_once(sep) {
            return (a.trim().to_string(), b.trim().to_string());
        }
    }
    (name.to_string(), String::new())
}

fn dirs() -> Option<std::path::PathBuf> {
    let home = std::env::var("HOME").ok()?;
    Some(std::path::PathBuf::from(home).join(".lyrics"))
}

fn decode_file_url(s: &str) -> String {
    // 简单 %XX 解码，保留路径
    let bytes = s.as_bytes();
    let mut out = Vec::with_capacity(bytes.len());
    let mut i = 0;
    while i < bytes.len() {
        if bytes[i] == b'%' && i + 2 < bytes.len() {
            let h = hex(bytes[i + 1]);
            let l = hex(bytes[i + 2]);
            if let (Some(h), Some(l)) = (h, l) {
                out.push((h << 4) | l);
                i += 3;
                continue;
            }
        }
        out.push(bytes[i]);
        i += 1;
    }
    String::from_utf8_lossy(&out).into_owned()
}

fn hex(b: u8) -> Option<u8> {
    match b {
        b'0'..=b'9' => Some(b - b'0'),
        b'a'..=b'f' => Some(b - b'a' + 10),
        b'A'..=b'F' => Some(b - b'A' + 10),
        _ => None,
    }
}
