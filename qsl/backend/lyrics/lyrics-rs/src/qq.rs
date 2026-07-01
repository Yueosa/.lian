// QQ 音乐歌词 API
use crate::lrc::{self, LyricLine};
use crate::http;

pub fn fetch(title: &str, artist: &str) -> Vec<LyricLine> {
    let keyword = format!("{} {}", title, artist);
    let search_url = format!(
        "https://c.y.qq.com/soso/fcgi-bin/client_search_cp?w={}&format=json",
        urlencoding(&keyword)
    );

    let search = match http::get_json(&search_url, "https://y.qq.com/") {
        Ok(j) => j,
        Err(_) => return vec![],
    };

    let songmid = search["data"]["song"]["list"][0]["songmid"]
        .as_str().unwrap_or("");
    if songmid.is_empty() { return vec![]; }

    let lyric_url = format!(
        "https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg?songmid={}&format=json&nobase64=1",
        songmid
    );

    let lyric_data = match http::get_json(&lyric_url, "https://y.qq.com/") {
        Ok(j) => j,
        Err(_) => return vec![],
    };

    let raw = lyric_data["lyric"].as_str().unwrap_or("");
    // QQ 音乐歌词可能是 base64 编码的
    let lrc_text = if let Ok(decoded) = base64_decode(raw) {
        String::from_utf8_lossy(&decoded).to_string()
    } else {
        raw.to_string()
    };

    lrc::parse(&lrc_text)
}

fn base64_decode(s: &str) -> Result<Vec<u8>, ()> {
    use std::collections::HashMap;
    let chars: HashMap<char, u8> = ('A'..='Z').enumerate().map(|(i, c)| (c, i as u8))
        .chain(('a'..='z').enumerate().map(|(i, c)| (c, 26 + i as u8)))
        .chain(('0'..='9').enumerate().map(|(i, c)| (c, 52 + i as u8)))
        .chain([('+', 62), ('/', 63), ('=', 64)])
        .collect();

    let mut out = Vec::new();
    let mut buf: u32 = 0;
    let mut bits = 0;
    for ch in s.chars() {
        let val = *chars.get(&ch).ok_or(())?;
        if val >= 64 { break; }
        buf = (buf << 6) | val as u32;
        bits += 6;
        if bits >= 8 {
            bits -= 8;
            out.push((buf >> bits) as u8);
        }
    }
    if out.is_empty() { Err(()) } else { Ok(out) }
}

fn urlencoding(s: &str) -> String {
    let mut out = String::new();
    for b in s.bytes() {
        match b {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => out.push(b as char),
            b' ' => out.push_str("%20"),
            _ => out.push_str(&format!("%{:02X}", b)),
        }
    }
    out
}
