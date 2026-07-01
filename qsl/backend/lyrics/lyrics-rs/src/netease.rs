// 网易云音乐歌词 API
use crate::lrc::{self, LyricLine};
use crate::http;

pub fn fetch(title: &str, artist: &str) -> Vec<LyricLine> {
    let body = format!("s={}%20{}&type=1&offset=0&total=true&limit=1",
        urlencoding(title), urlencoding(artist));

    let search = match http::post_json(
        "http://music.163.com/api/search/get/",
        &body,
        "http://music.163.com/",
    ) {
        Ok(j) => j,
        Err(_) => return vec![],
    };

    let song_id = search["result"]["songs"][0]["id"].as_u64().unwrap_or(0);
    if song_id == 0 { return vec![]; }

    let lyric_url = format!(
        "http://music.163.com/api/song/lyric?os=pc&id={}&lv=-1&kv=-1&tv=-1",
        song_id
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
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'_' | b'.' | b'~' => out.push(b as char),
            b' ' => out.push_str("%20"),
            _ => out.push_str(&format!("%{:02X}", b)),
        }
    }
    out
}
