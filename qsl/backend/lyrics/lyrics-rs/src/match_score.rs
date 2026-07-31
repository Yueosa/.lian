// 曲目匹配打分：网络源 / ~/.lyrics 共用
// 返回 0..=100；过低视为「搜到了但不是这首」
//
// 设计：标题必须实质命中（相等 / 包含），不用「字符碰巧重叠」——
// 否则搜 "nobody" 会把 Ariana 的 nowhere,nobody 当成命中。

/// 规范化：小写、去空白/标点变体、去掉括号附属标记
pub fn normalize(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    let lower = s.to_lowercase();
    let mut chars = lower.chars().peekable();
    while let Some(c) = chars.next() {
        if c == '(' || c == '（' || c == '[' || c == '【' {
            let end = match c {
                '(' => ')',
                '（' => '）',
                '[' => ']',
                _ => '】',
            };
            while let Some(n) = chars.next() {
                if n == end {
                    break;
                }
            }
            continue;
        }
        if c.is_whitespace()
            || c == '-'
            || c == '_'
            || c == '·'
            || c == '/'
            || c == ','
            || c == '，'
            || c == '.'
            || c == '\''
            || c == '"'
        {
            continue;
        }
        out.push(c);
    }
    out
}

/// 标题 + 艺人综合分（0..=100）
pub fn score_pair(want_title: &str, want_artist: &str, got_title: &str, got_artist: &str) -> i32 {
    let wt = normalize(want_title);
    let wa = normalize(want_artist);
    let gt = normalize(got_title);
    let ga = normalize(got_artist);

    if wt.is_empty() {
        return 0;
    }
    if gt.is_empty() {
        return 0;
    }

    let title_s = title_score(&wt, &gt);
    // 标题不过关直接失败（避免靠艺人分硬抬）
    if title_s < 50 {
        return title_s.min(30);
    }

    let artist_s = if wa.is_empty() {
        60 // 没给艺人：不拖后腿，也不当满分
    } else {
        field_score(&wa, &ga)
    };

    let mut score = (title_s * 70 + artist_s * 30) / 100;
    if wt == gt {
        score = (score + 10).min(100);
    }
    score
}

/// 是否接受该候选（网络 / 本地统一门槛）
pub fn accept(score: i32) -> bool {
    score >= 60
}

/// 标题：只认相等 / 足够长的包含关系
fn title_score(want: &str, got: &str) -> i32 {
    if want == got {
        return 100;
    }
    // 过短关键词（如 "a" / "nobody" 当标题碎片）禁止靠包含抬分
    let min_len = 2usize;
    if want.chars().count() < min_len || got.chars().count() < min_len {
        return 0;
    }
    if got.contains(want) || want.contains(got) {
        let a = want.chars().count().min(got.chars().count()) as i32;
        let b = want.chars().count().max(got.chars().count()) as i32;
        // 较短方至少占较长方 45%，避免 "夜" 命中 "夜曲"
        if a * 100 / b < 45 {
            return 20;
        }
        return (70 + 30 * a / b).min(95);
    }
    0
}

fn field_score(want: &str, got: &str) -> i32 {
    if want.is_empty() {
        return 50;
    }
    if got.is_empty() {
        return 0;
    }
    if want == got {
        return 100;
    }
    if got.contains(want) || want.contains(got) {
        let a = want.chars().count().min(got.chars().count()) as i32;
        let b = want.chars().count().max(got.chars().count()) as i32;
        if a * 100 / b < 40 {
            return 15;
        }
        return (65 + 35 * a / b).min(95);
    }
    0
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn jay_chou_exact() {
        let s = score_pair("夜曲", "周杰伦", "夜曲", "周杰伦");
        assert!(accept(s), "score={}", s);
    }

    #[test]
    fn reject_keyword_collision() {
        let s = score_pair(
            "asdfghjkl_not_a_song_xyz",
            "nobody",
            "nowhere, nobody",
            "Ariana Grande",
        );
        assert!(!accept(s), "score={}", s);
    }

    #[test]
    fn accept_containment() {
        let s = score_pair("夜曲", "周杰伦", "夜曲", "周杰伦 Jay Chou");
        assert!(accept(s), "score={}", s);
    }
}
