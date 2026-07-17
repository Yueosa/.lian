// clipboardctl — cliphist 的一次性适配器
//
// 只在被调用时跑一次，不常驻：list / paste / clear。
// 历史仍由 cliphist 维护；list 额外写出轻量 JSON 缓存供 UI 秒开。
//
// 用法：
//   clipboardctl list [--limit N]      → stdout JSON + 写 ~/.cache/qsl/clipboard-list.json
//   clipboardctl paste <id> [mime]     → 把历史项重新写入 selection
//   clipboardctl clear                 → cliphist wipe + 清空缩略图/JSON 缓存

use std::collections::HashSet;
use std::fs;
use std::io::Write;
use std::path::PathBuf;
use std::process::{Command, Stdio};

const THUMB_MAX: u32 = 384;
const DEFAULT_LIMIT: usize = 100;

fn home() -> String {
    std::env::var("HOME").unwrap_or_else(|_| "/root".to_string())
}

fn thumbs_dir() -> PathBuf {
    PathBuf::from(home()).join(".cache/qsl/clipboard-thumbs")
}

fn list_cache_path() -> PathBuf {
    PathBuf::from(home()).join(".cache/qsl/clipboard-list.json")
}

fn write_list_cache(items: &serde_json::Value) {
    let path = list_cache_path();
    if let Some(parent) = path.parent() {
        let _ = fs::create_dir_all(parent);
    }
    if let Ok(s) = serde_json::to_string(items) {
        let _ = fs::write(path, s);
    }
}

fn cliphist_list() -> Vec<String> {
    match Command::new("cliphist").arg("list").output() {
        Ok(o) if o.status.success() => String::from_utf8_lossy(&o.stdout)
            .lines()
            .map(|s| s.to_string())
            .collect(),
        _ => Vec::new(),
    }
}

fn cliphist_decode(id: &str) -> Option<Vec<u8>> {
    let out = Command::new("cliphist").arg("decode").arg(id).output().ok()?;
    if out.status.success() {
        Some(out.stdout)
    } else {
        None
    }
}

fn parse_image(preview: &str) -> Option<(String, u32, u32)> {
    let p = preview.trim();
    if !p.starts_with("[[ binary data") || !p.ends_with("]]") {
        return None;
    }
    let inner = &p[2..p.len() - 2];
    let tokens: Vec<&str> = inner.split_whitespace().collect();
    if tokens.len() < 2 {
        return None;
    }
    let dims = tokens[tokens.len() - 1];
    let fmt = tokens[tokens.len() - 2];
    let mut wh = dims.split('x');
    let w = wh.next()?.parse::<u32>().ok()?;
    let h = wh.next()?.parse::<u32>().ok()?;
    let mime = match fmt.to_lowercase().as_str() {
        "png" => "image/png".to_string(),
        "jpg" | "jpeg" => "image/jpeg".to_string(),
        "gif" => "image/gif".to_string(),
        "bmp" => "image/bmp".to_string(),
        "webp" => "image/webp".to_string(),
        other => format!("image/{}", other),
    };
    Some((mime, w, h))
}

fn ensure_thumb(id: &str) -> Option<PathBuf> {
    let dir = thumbs_dir();
    let path = dir.join(format!("{}.png", id));
    if path.exists() {
        return Some(path);
    }
    let bytes = cliphist_decode(id)?;
    let img = image::load_from_memory(&bytes).ok()?;
    let thumb = img.thumbnail(THUMB_MAX, THUMB_MAX);
    fs::create_dir_all(&dir).ok()?;
    thumb.save_with_format(&path, image::ImageFormat::Png).ok()?;
    Some(path)
}

fn prune_thumbs(live_ids: &HashSet<String>) {
    let dir = thumbs_dir();
    let entries = match fs::read_dir(&dir) {
        Ok(e) => e,
        Err(_) => return,
    };
    for entry in entries.flatten() {
        let p = entry.path();
        if p.extension().and_then(|s| s.to_str()) != Some("png") {
            continue;
        }
        if let Some(stem) = p.file_stem().and_then(|s| s.to_str()) {
            if !live_ids.contains(stem) {
                let _ = fs::remove_file(&p);
            }
        }
    }
}

fn cmd_list(limit: usize) {
    let lines = cliphist_list();

    let mut live_ids: HashSet<String> = HashSet::new();
    for line in &lines {
        if let Some((id, _)) = line.split_once('\t') {
            live_ids.insert(id.to_string());
        }
    }
    prune_thumbs(&live_ids);

    let mut items: Vec<serde_json::Value> = Vec::new();
    for line in lines.iter().take(limit) {
        let (id, preview) = match line.split_once('\t') {
            Some(v) => v,
            None => continue,
        };

        if let Some((mime, w, h)) = parse_image(preview) {
            let thumb = ensure_thumb(id)
                .map(|p| p.to_string_lossy().to_string())
                .unwrap_or_default();
            items.push(serde_json::json!({
                "id": id,
                "kind": "image",
                "mime": mime,
                "preview": preview,
                "thumb": thumb,
                "width": w,
                "height": h,
            }));
        } else {
            items.push(serde_json::json!({
                "id": id,
                "kind": "text",
                "mime": "text/plain",
                "preview": preview,
                "thumb": "",
                "width": 0,
                "height": 0,
            }));
        }
    }

    let arr = serde_json::Value::Array(items);
    write_list_cache(&arr);
    println!("{}", arr);
}

fn cmd_paste(id: &str, mime: &str) -> i32 {
    let bytes = match cliphist_decode(id) {
        Some(b) => b,
        None => {
            eprintln!("clipboardctl: decode failed for id {}", id);
            return 1;
        }
    };

    let mut cmd = Command::new("wl-copy");
    if !mime.is_empty() {
        cmd.arg("--type").arg(mime);
    }
    let mut child = match cmd.stdin(Stdio::piped()).spawn() {
        Ok(c) => c,
        Err(e) => {
            eprintln!("clipboardctl: spawn wl-copy failed: {}", e);
            return 1;
        }
    };
    if let Some(stdin) = child.stdin.as_mut() {
        if stdin.write_all(&bytes).is_err() {
            eprintln!("clipboardctl: write to wl-copy failed");
            return 1;
        }
    }
    match child.wait() {
        Ok(s) if s.success() => 0,
        _ => 1,
    }
}

fn cmd_clear() -> i32 {
    let _ = Command::new("cliphist").arg("wipe").status();
    let dir = thumbs_dir();
    if let Ok(entries) = fs::read_dir(&dir) {
        for entry in entries.flatten() {
            let _ = fs::remove_file(entry.path());
        }
    }
    write_list_cache(&serde_json::json!([]));
    0
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let cmd = args.get(1).map(|s| s.as_str()).unwrap_or("list");

    let code = match cmd {
        "list" => {
            let mut limit = DEFAULT_LIMIT;
            let mut i = 2;
            while i < args.len() {
                if args[i] == "--limit" {
                    if let Some(v) = args.get(i + 1).and_then(|s| s.parse::<usize>().ok()) {
                        limit = v;
                    }
                    i += 2;
                } else {
                    i += 1;
                }
            }
            cmd_list(limit);
            0
        }
        "paste" => {
            let id = args.get(2).map(|s| s.as_str()).unwrap_or("");
            let mime = args.get(3).map(|s| s.as_str()).unwrap_or("");
            if id.is_empty() {
                eprintln!("usage: clipboardctl paste <id> [mime]");
                1
            } else {
                cmd_paste(id, mime)
            }
        }
        "clear" => cmd_clear(),
        other => {
            eprintln!("clipboardctl: unknown command '{}'", other);
            1
        }
    };

    std::process::exit(code);
}
