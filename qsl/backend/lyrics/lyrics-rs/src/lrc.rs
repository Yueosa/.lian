// LRC 文本解析 → Vec<LyricLine>
use serde::Serialize;

#[derive(Debug, Clone, Serialize)]
pub struct LyricLine {
    pub time: f64,
    pub text: String,
}

/// 解析 LRC 文本。支持 [mm:ss.xx] 和 [mm:ss.xxx] 格式。
pub fn parse(text: &str) -> Vec<LyricLine> {
    let mut lines: Vec<LyricLine> = Vec::new();
    let clean = text.replace("&apos;", "'").replace("&quot;", "\"").replace("&amp;", "&");

    for raw in clean.lines() {
        let line = raw.trim();
        if line.is_empty() || !line.starts_with('[') { continue; }

        // 手动解析 [mm:ss.xx] 或 [mm:ss.xxx]
        let close = match line.find(']') { Some(i) => i, None => continue };
        let tag = &line[1..close];
        let text = line[close+1..].trim().to_string();

        let parts: Vec<&str> = tag.split(&[':', '.'][..]).collect();
        if parts.len() < 3 { continue; }
        let minutes: f64 = parts[0].parse().unwrap_or(0.0);
        let seconds: f64 = parts[1].parse().unwrap_or(0.0);
        let ms_str = parts[2];
        let ms: f64 = if ms_str.len() == 2 {
            ms_str.parse::<f64>().unwrap_or(0.0) * 10.0
        } else {
            ms_str.parse().unwrap_or(0.0)
        };

        let skip = ["offset:", "by:", "al:", "ti:", "ar:"];
        if text.is_empty() || skip.iter().any(|p| text.to_lowercase().starts_with(p)) { continue; }

        lines.push(LyricLine { time: minutes * 60.0 + seconds + ms / 1000.0, text });
    }

    lines.sort_by(|a, b| a.time.partial_cmp(&b.time).unwrap());
    lines
}

/// 从文件读取并解析 LRC
pub fn parse_file(path: &std::path::Path) -> Vec<LyricLine> {
    match std::fs::read(path) {
        Ok(data) => parse(&String::from_utf8_lossy(&data)),
        Err(_) => vec![],
    }
}
