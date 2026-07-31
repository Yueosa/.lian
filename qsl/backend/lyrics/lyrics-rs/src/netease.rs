// 网易云音乐歌词 API — 搜多首，按标题/艺人打分挑最佳；不达标返回空
use crate::http;
use crate::lrc::{self, LyricLine};
use crate::match_score;

const SEARCH_LIMIT: usize = 8;

pub fn fetch(title: &str, artist: &str) -> Vec<LyricLine> {
    let body = format!(
        "s={}%20{}&type=1&offset=0&total=true&limit={}",
        urlencoding(title),
        urlencoding(artist),
        SEARCH_LIMIT
    );

    let search = match http::post_json(
        "http://music.163.com/api/search/get/",
        &body,
        "http://music.163.com/",
    ) {
        Ok(j) => j,
        Err(_) => return vec![],
    };

    let songs = match search["result"]["songs"].as_array() {
        Some(a) if !a.is_empty() => a,
        _ => return vec![],
    };

    let mut best_id: u64 = 0;
    let mut best_score = -1;
    for item in songs.iter().take(SEARCH_LIMIT) {
        let got_title = item["name"].as_str().unwrap_or("");
        let got_artist = item["artists"]
            .as_array()
            .and_then(|arr| arr.first())
            .and_then(|a| a["name"].as_str())
            .unwrap_or("");
        let id = item["id"].as_u64().unwrap_or(0);
        if id == 0 {
            continue;
        }
        let s = match_score::score_pair(title, artist, got_title, got_artist);
        if s > best_score {
            best_score = s;
            best_id = id;
        }
    }

    if best_id == 0 || !match_score::accept(best_score) {
        return vec![];
    }

    let lyric_url = format!(
        "http://music.163.com/api/song/lyric?os=pc&id={}&lv=-1&kv=-1&tv=-1",
        best_id
    );

    let lyric_data = match http::get_json(&lyric_url, "http://music.163.com/") {
        Ok(j) => j,
        Err(_) => return vec![],
    };

    let lrc_text = lyric_data["lrc"]["lyric"].as_str().unwrap_or("");
    lrc::parse(lrc_text)
}

fn urlencoding(s: &str) -> String {
    let mut out = String::new();
    for b in s.bytes() {
        match b {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => {
                out.push(b as char)
            }
            b' ' => out.push_str("%20"),
            _ => out.push_str(&format!("%{:02X}", b)),
        }
    }
    out
}
