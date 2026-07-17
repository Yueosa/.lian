// notifctl — 通知 SQLite 一次性适配器
//
// 用法：
//   notifctl ingest '<json>'     写入一条（协议字段）
//   notifctl list [--limit N]     stdout JSON + 写缓存
//   notifctl dismiss <notif_id>   soft-dismiss
//   notifctl clear                清空全部活动通知

use rusqlite::{params, Connection};
use serde::{Deserialize, Serialize};
use serde_json;
use std::fs;
use std::path::PathBuf;

const DEFAULT_LIMIT: usize = 80;

#[derive(Debug, Deserialize)]
struct IngestInput {
    id: i64,
    #[serde(default, rename = "appName")]
    app_name: String,
    #[serde(default, rename = "desktopEntry")]
    desktop_entry: String,
    #[serde(default)]
    summary: String,
    #[serde(default)]
    body: String,
    #[serde(default)]
    image: String,
    #[serde(default, rename = "appIcon")]
    app_icon: String,
    #[serde(default)]
    icon: String,
}

#[derive(Debug, Serialize)]
struct ListEntry {
    id: i64,
    #[serde(rename = "notifId")]
    notif_id: i64,
    #[serde(rename = "appName")]
    app_name: String,
    #[serde(rename = "desktopEntry")]
    desktop_entry: String,
    summary: String,
    body: String,
    #[serde(rename = "imagePath")]
    image_path: String,
    #[serde(rename = "mappedApp")]
    mapped_app: String,
    #[serde(rename = "receivedAt")]
    received_at: i64,
}

fn home() -> String {
    std::env::var("HOME").unwrap_or_else(|_| "/tmp".into())
}

fn db_path() -> PathBuf {
    PathBuf::from(home()).join(".local/state/qsl/notif.db")
}

fn list_cache_path() -> PathBuf {
    PathBuf::from(home()).join(".cache/qsl/notif-list.json")
}

fn open_db() -> Result<Connection, String> {
    let path = db_path();
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|e| e.to_string())?;
    }
    let conn = Connection::open(&path).map_err(|e| e.to_string())?;
    conn.execute_batch(
        "CREATE TABLE IF NOT EXISTS notifications (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            notif_id INTEGER NOT NULL,
            app_name TEXT NOT NULL DEFAULT '',
            desktop_entry TEXT NOT NULL DEFAULT '',
            summary TEXT NOT NULL DEFAULT '',
            body TEXT NOT NULL DEFAULT '',
            image_path TEXT NOT NULL DEFAULT '',
            mapped_app TEXT NOT NULL DEFAULT 'system',
            received_at INTEGER NOT NULL,
            dismissed_at INTEGER NOT NULL DEFAULT 0
         );
         CREATE INDEX IF NOT EXISTS idx_notif_active
            ON notifications(dismissed_at, received_at DESC);",
    )
    .map_err(|e| e.to_string())?;
    Ok(conn)
}

fn map_app(desktop: &str, app_name: &str, summary: &str) -> String {
    let blob = format!("{} {} {}", desktop, app_name, summary).to_lowercase();
    if blob.contains("telegram") {
        "telegram".into()
    } else if blob.contains("discord") {
        "discord".into()
    } else if blob.contains("wechat") || blob.contains("weixin") {
        "wechat".into()
    } else if blob.contains("linuxqq") || blob.contains("qq") {
        "qq".into()
    } else {
        "system".into()
    }
}

fn should_skip(desktop: &str, app_name: &str) -> bool {
    let d = desktop.to_lowercase();
    let a = app_name.to_lowercase();
    d.contains("spotify")
        || d.contains("player")
        || a.contains("spotify")
        || a.ends_with("player")
}

fn resolve_image(n: &IngestInput) -> String {
    for cand in [&n.image, &n.app_icon, &n.icon] {
        let s = cand.trim();
        if !s.is_empty() {
            return s.to_string();
        }
    }
    String::new()
}

fn write_list_cache(entries: &[ListEntry]) {
    let path = list_cache_path();
    if let Some(parent) = path.parent() {
        let _ = fs::create_dir_all(parent);
    }
    if let Ok(s) = serde_json::to_string(entries) {
        let _ = fs::write(path, s);
    }
}

fn load_entries(conn: &Connection, limit: usize) -> Result<Vec<ListEntry>, String> {
    let mut stmt = conn
        .prepare(
            "SELECT id, notif_id, app_name, desktop_entry, summary, body, image_path, mapped_app, received_at
             FROM notifications
             WHERE dismissed_at = 0
             ORDER BY received_at DESC
             LIMIT ?1",
        )
        .map_err(|e| e.to_string())?;
    let rows = stmt
        .query_map(params![limit as i64], |row| {
            Ok(ListEntry {
                id: row.get(0)?,
                notif_id: row.get(1)?,
                app_name: row.get(2)?,
                desktop_entry: row.get(3)?,
                summary: row.get(4)?,
                body: row.get(5)?,
                image_path: row.get(6)?,
                mapped_app: row.get(7)?,
                received_at: row.get(8)?,
            })
        })
        .map_err(|e| e.to_string())?;
    let mut entries = Vec::new();
    for r in rows.flatten() {
        entries.push(r);
    }
    Ok(entries)
}

fn refresh_cache(conn: &Connection) {
    if let Ok(entries) = load_entries(conn, DEFAULT_LIMIT) {
        write_list_cache(&entries);
    }
}

fn cmd_ingest(raw: &str) -> i32 {
    let n: IngestInput = match serde_json::from_str(raw) {
        Ok(v) => v,
        Err(e) => {
            eprintln!("notifctl: bad json: {}", e);
            return 1;
        }
    };
    if should_skip(&n.desktop_entry, &n.app_name) {
        return 0;
    }
    let conn = match open_db() {
        Ok(c) => c,
        Err(e) => {
            eprintln!("notifctl: db: {}", e);
            return 1;
        }
    };
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0);
    let mapped = map_app(&n.desktop_entry, &n.app_name, &n.summary);
    let image = resolve_image(&n);
    if let Err(e) = conn.execute(
        "INSERT INTO notifications
         (notif_id, app_name, desktop_entry, summary, body, image_path, mapped_app, received_at, dismissed_at)
         VALUES (?1,?2,?3,?4,?5,?6,?7,?8,0)",
        params![
            n.id,
            n.app_name,
            n.desktop_entry,
            n.summary,
            n.body,
            image,
            mapped,
            now
        ],
    ) {
        eprintln!("notifctl: insert: {}", e);
        return 1;
    }
    refresh_cache(&conn);
    0
}

fn cmd_list(limit: usize) -> i32 {
    let conn = match open_db() {
        Ok(c) => c,
        Err(e) => {
            eprintln!("notifctl: db: {}", e);
            return 1;
        }
    };
    match load_entries(&conn, limit) {
        Ok(entries) => {
            write_list_cache(&entries);
            println!(
                "{}",
                serde_json::to_string(&entries).unwrap_or_else(|_| "[]".into())
            );
            0
        }
        Err(e) => {
            eprintln!("notifctl: query: {}", e);
            1
        }
    }
}

fn cmd_dismiss(notif_id: i64) -> i32 {
    let conn = match open_db() {
        Ok(c) => c,
        Err(e) => {
            eprintln!("notifctl: db: {}", e);
            return 1;
        }
    };
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0);
    let _ = conn.execute(
        "UPDATE notifications SET dismissed_at = ?1
         WHERE notif_id = ?2 AND dismissed_at = 0",
        params![now, notif_id],
    );
    refresh_cache(&conn);
    0
}

fn cmd_clear() -> i32 {
    let conn = match open_db() {
        Ok(c) => c,
        Err(e) => {
            eprintln!("notifctl: db: {}", e);
            return 1;
        }
    };
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0);
    let _ = conn.execute(
        "UPDATE notifications SET dismissed_at = ?1 WHERE dismissed_at = 0",
        params![now],
    );
    write_list_cache(&[]);
    0
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let cmd = args.get(1).map(|s| s.as_str()).unwrap_or("");
    let code = match cmd {
        "ingest" => {
            let raw = args.get(2).map(|s| s.as_str()).unwrap_or("");
            if raw.is_empty() {
                eprintln!("usage: notifctl ingest '<json>'");
                1
            } else {
                cmd_ingest(raw)
            }
        }
        "list" => {
            let mut limit = DEFAULT_LIMIT;
            let mut i = 2;
            while i < args.len() {
                if args[i] == "--limit" {
                    if let Some(v) = args.get(i + 1).and_then(|s| s.parse().ok()) {
                        limit = v;
                    }
                    i += 2;
                } else {
                    i += 1;
                }
            }
            cmd_list(limit)
        }
        "dismiss" => {
            let id = args
                .get(2)
                .and_then(|s| s.parse::<i64>().ok())
                .unwrap_or(0);
            if id == 0 {
                eprintln!("usage: notifctl dismiss <notif_id>");
                1
            } else {
                cmd_dismiss(id)
            }
        }
        "clear" => cmd_clear(),
        _ => {
            eprintln!("usage: notifctl <ingest|list|dismiss|clear>");
            1
        }
    };
    std::process::exit(code);
}
