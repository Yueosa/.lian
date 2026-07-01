// lyrics-fetch — 多源歌词获取
//
// 优先级：同目录 .lrc → ~/.lyrics/ → SPlayer SQLite → QQ 音乐 → 网易云
//
// 用法：
//   lyrics-fetch <title> <artist> [player_name] [media_url]

mod lrc;
mod local;
mod splayer;
mod qq;
mod netease;
mod http;

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
    // 1. 同目录 .lrc
    let r = local::near_media(media_url);
    if !r.is_empty() { return r; }

    // 2. ~/.lyrics/
    let r = local::from_home_dir(title, artist);
    if !r.is_empty() { return r; }

    // 3. SPlayer cache.db
    let r = splayer::fetch(player);
    if !r.is_empty() { return r; }

    // 4. QQ 音乐
    let r = qq::fetch(title, artist);
    if !r.is_empty() { return r; }

    // 5. 网易云
    let r = netease::fetch(title, artist);
    if !r.is_empty() { return r; }

    vec![]
}
