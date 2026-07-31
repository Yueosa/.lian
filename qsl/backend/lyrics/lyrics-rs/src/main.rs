// lyrics-fetch — 多源歌词获取
//
// 优先级：同目录 .lrc → ~/.lyrics/（需匹配达标）→ SPlayer → QQ → 网易
// QQ/网易：搜多首打分，不达标则试下一源（避免 list[0] 串歌）
//
// 用法：
//   lyrics-fetch <title> <artist> [player_name] [media_url]

mod http;
mod local;
mod lrc;
mod match_score;
mod netease;
mod qq;
mod splayer;

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let title = args.get(1).map(|s| s.as_str()).unwrap_or("");
    let artist = args.get(2).map(|s| s.as_str()).unwrap_or("");
    let player = args.get(3).map(|s| s.as_str()).unwrap_or("");
    let media_url = args.get(4).map(|s| s.as_str()).unwrap_or("");

    let lyrics = find_lyrics(title, artist, player, media_url);
    let fallback = if lyrics.is_empty() {
        serde_json::json!([{"time": 0, "text": "暂无歌词"}])
    } else {
        serde_json::json!(lyrics)
    };

    println!("{}", serde_json::to_string(&fallback).unwrap());
}

fn find_lyrics(title: &str, artist: &str, player: &str, media_url: &str) -> Vec<lrc::LyricLine> {
    let r = local::near_media(media_url);
    if !r.is_empty() {
        return r;
    }

    let r = local::from_home_dir(title, artist);
    if !r.is_empty() {
        return r;
    }

    let r = splayer::fetch(player);
    if !r.is_empty() {
        return r;
    }

    let r = qq::fetch(title, artist);
    if !r.is_empty() {
        return r;
    }

    let r = netease::fetch(title, artist);
    if !r.is_empty() {
        return r;
    }

    vec![]
}
