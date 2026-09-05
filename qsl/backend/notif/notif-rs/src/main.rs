// notifctl — 通知 SQLite 一次性适配器
//
// 用法：
//   notifctl ingest '<json>'     写入一条（协议字段）
//   notifctl list [--limit N]     stdout JSON + 写缓存
//   notifctl dismiss <row_id>     soft-dismiss 指定的那一行
//   notifctl dismiss-live <notif_id>
//                                 soft-dismiss 持有该协议 id 的**最新**一行
//
// 为什么分成两个：notif_id 是 D-Bus 协议 id，各应用各发各的、还会复用，
// 库里同一个 notif_id 常常横跨好几个应用几十条（实测最多 61 条）。原先
// dismiss 按 notif_id 全量 UPDATE，面板上关掉一条会连带关掉那一批——
// 第 9 轮审计时踩到的。只有「刚到达、还没拿到行号」的情况才需要按协议 id
// 找，那时要的也永远是最新那条，所以单开 dismiss-live 并且限定一行。
//   notifctl clear                清空全部活动通知
//   notifctl prune [--days N]     删除已读且超期的历史行

use rusqlite::{params, Connection};
use serde::{Deserialize, Serialize};
use serde_json;
use std::fs;
use std::path::PathBuf;

const DEFAULT_LIMIT: usize = 80;
// dismiss 只写 dismissed_at 不删行，不清理的话表会无限增长（实测数月即数千行）。
// 已读行只对「历史回看」有意义，超期直接删。
const DEFAULT_RETAIN_DAYS: i64 = 30;
// 二级兜底：即便都在保留期内，也不让已读行无限堆积
const MAX_DISMISSED_ROWS: i64 = 5000;

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

// FNV-1a 64：内容哈希手写实现（std 的 DefaultHasher 跨编译器版本不稳定，
// 图标缓存名必须稳定，同内容天然去重）
fn fnv1a64(bytes: &[u8]) -> u64 {
    let mut h: u64 = 0xcbf29ce484222325;
    for &b in bytes {
        h ^= b as u64;
        h = h.wrapping_mul(0x100000001b3);
    }
    h
}

fn icon_cache_dir() -> PathBuf {
    PathBuf::from(home()).join(".cache/qsl/notif-icons")
}

// 通知 DB 持久化，但 /tmp、/run、/var/tmp 下的图标文件活不过重启
// （Chrome 的 scoped_dir、lya 的 tray 图标都在 /tmp）——收到时拷进持久缓存。
// 主题图标名 / qsimage 进程句柄没有文件可拷，原样保留。
fn persist_image(resolved: &str) -> String {
    let raw = resolved
        .strip_prefix("image://icon/")
        .or_else(|| resolved.strip_prefix("file://"))
        .unwrap_or(resolved);
    let transient = raw.starts_with("/tmp/")
        || raw.starts_with("/run/")
        || raw.starts_with("/var/tmp/");
    if !transient {
        return resolved.to_string();
    }
    let src = std::path::Path::new(raw);
    let bytes = match fs::read(src) {
        Ok(b) => b,
        Err(_) => return resolved.to_string(),
    };
    let ext = src.extension().and_then(|e| e.to_str()).unwrap_or("png");
    let name = format!("{:x}-{}.{}", fnv1a64(&bytes), bytes.len(), ext);
    let dir = icon_cache_dir();
    if fs::create_dir_all(&dir).is_err() {
        return resolved.to_string();
    }
    let dest = dir.join(&name);
    if !dest.exists() && fs::write(&dest, &bytes).is_err() {
        return resolved.to_string();
    }
    dest.to_string_lossy().into_owned()
}

// 清掉没有任何行引用的缓存图标（只动缓存目录内的文件）
fn prune_icon_cache(conn: &Connection) {
    let mut referenced = std::collections::HashSet::new();
    if let Ok(mut stmt) = conn.prepare("SELECT DISTINCT image_path FROM notifications") {
        if let Ok(rows) = stmt.query_map([], |row| row.get::<_, String>(0)) {
            for r in rows.flatten() {
                referenced.insert(r);
            }
        }
    }
    if let Ok(rd) = fs::read_dir(icon_cache_dir()) {
        for entry in rd.flatten() {
            let path = entry.path();
            if !referenced.contains(path.to_string_lossy().as_ref()) {
                let _ = fs::remove_file(&path);
            }
        }
    }
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
    let image = persist_image(&resolve_image(&n));
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

fn now_ms() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0)
}

// 只删已读行；未读的一律保留，与 dismissed_at=0 的查询语义一致。
fn prune_old(conn: &Connection, retain_days: i64) -> usize {
    let cutoff = now_ms() - retain_days.max(1) * 24 * 60 * 60 * 1000;
    let mut removed = conn
        .execute(
            "DELETE FROM notifications WHERE dismissed_at > 0 AND dismissed_at < ?1",
            params![cutoff],
        )
        .unwrap_or(0);

    removed += conn
        .execute(
            "DELETE FROM notifications
             WHERE dismissed_at > 0 AND id NOT IN (
                 SELECT id FROM notifications
                 WHERE dismissed_at > 0
                 ORDER BY dismissed_at DESC
                 LIMIT ?1
             )",
            params![MAX_DISMISSED_ROWS],
        )
        .unwrap_or(0);

    removed
}

fn cmd_prune(retain_days: i64) -> i32 {
    let conn = match open_db() {
        Ok(c) => c,
        Err(e) => {
            eprintln!("notifctl: db: {}", e);
            return 1;
        }
    };
    let removed = prune_old(&conn, retain_days);
    // 顺手清图标缓存：删的是没有任何行引用的文件（只动缓存目录）
    prune_icon_cache(&conn);
    let _ = conn.execute_batch("VACUUM");
    println!("{}", removed);
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
    // 面板打开是低频动作，顺手清一次历史，避免依赖额外的定时任务
    prune_old(&conn, DEFAULT_RETAIN_DAYS);
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

// 按唯一行号关一条。面板里点掉某条走的是这条路——entries 里每条都带着
// list 给出的 id。
fn cmd_dismiss(row_id: i64) -> i32 {
    let conn = match open_db() {
        Ok(c) => c,
        Err(e) => {
            eprintln!("notifctl: db: {}", e);
            return 1;
        }
    };
    let now = now_ms();
    let _ = conn.execute(
        "UPDATE notifications SET dismissed_at = ?1
         WHERE id = ?2 AND dismissed_at = 0",
        params![now, row_id],
    );
    refresh_cache(&conn);
    0
}

// 按协议 id 关**最新**一条。只给「刚从 D-Bus 到达、还没入库拿到行号」的
// 条目兜底（服务层那边是 id = -1 的临时行）。限定一行是关键：不限定就是
// 上面注释里说的那个 bug。
fn cmd_dismiss_live(notif_id: i64) -> i32 {
    let conn = match open_db() {
        Ok(c) => c,
        Err(e) => {
            eprintln!("notifctl: db: {}", e);
            return 1;
        }
    };
    let now = now_ms();
    let _ = conn.execute(
        "UPDATE notifications SET dismissed_at = ?1
         WHERE id = (
             SELECT id FROM notifications
             WHERE notif_id = ?2 AND dismissed_at = 0
             ORDER BY received_at DESC, id DESC
             LIMIT 1
         )",
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
            if id <= 0 {
                eprintln!("usage: notifctl dismiss <row_id>");
                1
            } else {
                cmd_dismiss(id)
            }
        }
        "dismiss-live" => {
            let id = args
                .get(2)
                .and_then(|s| s.parse::<i64>().ok())
                .unwrap_or(0);
            if id <= 0 {
                eprintln!("usage: notifctl dismiss-live <notif_id>");
                1
            } else {
                cmd_dismiss_live(id)
            }
        }
        "clear" => cmd_clear(),
        "prune" => {
            let mut days = DEFAULT_RETAIN_DAYS;
            let mut i = 2;
            while i < args.len() {
                if args[i] == "--days" {
                    if let Some(v) = args.get(i + 1).and_then(|s| s.parse().ok()) {
                        days = v;
                    }
                    i += 2;
                } else {
                    i += 1;
                }
            }
            cmd_prune(days)
        }
        _ => {
            eprintln!(
                "usage: notifctl <ingest|list|dismiss|dismiss-live|clear|prune>"
            );
            1
        }
    };
    std::process::exit(code);
}
