// QQ 音乐歌词 API — 搜多首，按标题/艺人打分挑最佳；不达标返回空
use crate::http;
use crate::lrc::{self, LyricLine};
use crate::match_score;

const SEARCH_LIMIT: usize = 8;

pub fn fetch(title: &str, artist: &str) -> Vec<LyricLine> {
    let keyword = format!("{} {}", title, artist);
    let search_url = format!(
        "https://c.y.qq.com/soso/fcgi-bin/client_search_cp?w={}&format=json&n={}",
        urlencoding(&keyword),
        SEARCH_LIMIT
    );

    let search = match http::get_json(&search_url, "https://y.qq.com/") {
        Ok(j) => j,
        Err(_) => return vec![],
    };

    let list = match search["data"]["song"]["list"].as_array() {
        Some(a) if !a.is_empty() => a,
        _ => return vec![],
    };

    let mut best_mid = String::new();
    let mut best_score = -1;
    for item in list.iter().take(SEARCH_LIMIT) {
        let got_title = item["songname"].as_str().unwrap_or("");
        let got_artist = item["singer"]
            .as_array()
            .and_then(|arr| arr.first())
            .and_then(|s| s["name"].as_str())
            .unwrap_or("");
        let mid = item["songmid"].as_str().unwrap_or("");
        if mid.is_empty() {
            continue;
        }
        let s = match_score::score_pair(title, artist, got_title, got_artist);
        if s > best_score {
            best_score = s;
            best_mid = mid.to_string();
        }
    }

    if best_mid.is_empty() || !match_score::accept(best_score) {
        return vec![];
    }

    let lyric_url = format!(
        "https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg?songmid={}&format=json&nobase64=1",
        best_mid
    );

    let lyric_data = match http::get_json(&lyric_url, "https://y.qq.com/") {
        Ok(j) => j,
        Err(_) => return vec![],
    };

    let raw = lyric_data["lyric"].as_str().unwrap_or("");
    let lrc_text = if let Ok(decoded) = base64_decode(raw) {
        String::from_utf8_lossy(&decoded).to_string()
    } else {
        raw.to_string()
    };

    lrc::parse(&lrc_text)
}

fn base64_decode(s: &str) -> Result<Vec<u8>, ()> {
    use std::collections::HashMap;
    let chars: HashMap<char, u8> = ('A'..='Z')
        .enumerate()
        .map(|(i, c)| (c, i as u8))
        .chain(('a'..='z').enumerate().map(|(i, c)| (c, 26 + i as u8)))
        .chain(('0'..='9').enumerate().map(|(i, c)| (c, 52 + i as u8)))
        .chain([('+', 62), ('/', 63), ('=', 64)])
        .collect();

    let mut out = Vec::new();
    let mut buf: u32 = 0;
    let mut bits = 0;
    for ch in s.chars() {
        let val = *chars.get(&ch).ok_or(())?;
        if val >= 64 {
            break;
        }
        buf = (buf << 6) | val as u32;
        bits += 6;
        if bits >= 8 {
            bits -= 8;
            out.push((buf >> bits) as u8);
        }
    }
    if out.is_empty() {
        Err(())
    } else {
        Ok(out)
    }
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
