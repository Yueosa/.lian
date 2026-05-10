#include "database.h"

#include <QDir>
#include <QFileInfo>
#include <QMutexLocker>
#include <QStandardPaths>
#include <QString>
#include <QDebug>

namespace clavis::store {

namespace {

// schema v1：所有表。新增表 → 升 version + 写 migration。
constexpr const char* kSchemaV1 = R"SQL(
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS schema_version (
    version INTEGER PRIMARY KEY
);

-- 通知（Phase C3）
CREATE TABLE IF NOT EXISTS notifications (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    notif_id      INTEGER NOT NULL,
    app_name      TEXT,
    desktop_entry TEXT,
    summary       TEXT,
    body          TEXT,
    image_path    TEXT,
    category      TEXT,
    mapped_app    TEXT,
    received_at   INTEGER NOT NULL,
    read_at       INTEGER,
    dismissed_at  INTEGER
);
CREATE INDEX IF NOT EXISTS idx_notif_received ON notifications(received_at DESC);
CREATE INDEX IF NOT EXISTS idx_notif_category ON notifications(category, received_at DESC);

-- 剪贴板（Phase C2）
CREATE TABLE IF NOT EXISTS clipboard_entries (
    id            INTEGER PRIMARY KEY,
    kind          TEXT NOT NULL,
    mime          TEXT,
    text_preview  TEXT,
    width         INTEGER,
    height        INTEGER,
    bytes         INTEGER,
    sha256        TEXT,
    blob_path     TEXT,
    paste_mime    TEXT,           -- wl-copy --type 实际写入的 mime（HTML 图片走 text/html）
    paste_html    TEXT,           -- 当 paste_mime='text/html' 时的内容（已剥离多行包装）
    created_at    INTEGER NOT NULL,
    last_used_at  INTEGER
);
CREATE INDEX IF NOT EXISTS idx_clip_created ON clipboard_entries(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_clip_sha
    ON clipboard_entries(sha256) WHERE sha256 IS NOT NULL;

-- 媒体历史（Phase C4）
CREATE TABLE IF NOT EXISTS media_history (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    player      TEXT,
    artist      TEXT,
    title       TEXT,
    album       TEXT,
    art_url     TEXT,
    started_at  INTEGER NOT NULL,
    ended_at    INTEGER
);
CREATE INDEX IF NOT EXISTS idx_media_started ON media_history(started_at DESC);

CREATE TABLE IF NOT EXISTS lyrics_cache (
    key         TEXT PRIMARY KEY,
    provider    TEXT,
    lrc         TEXT,
    fetched_at  INTEGER NOT NULL,
    ttl_until   INTEGER NOT NULL
);

-- 课表（Phase C5）
CREATE TABLE IF NOT EXISTS schedule_events (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    course      TEXT,
    location    TEXT,
    teacher     TEXT,
    weekday     INTEGER,
    start_min   INTEGER,
    end_min     INTEGER,
    weeks_mask  INTEGER,
    source_hash TEXT
);
CREATE INDEX IF NOT EXISTS idx_sched_day ON schedule_events(weekday, start_min);

-- 更新计数（Phase C5）
CREATE TABLE IF NOT EXISTS updates_snapshot (
    id            INTEGER PRIMARY KEY,
    repo_count    INTEGER,
    aur_count     INTEGER,
    flatpak_count INTEGER,
    fetched_at    INTEGER NOT NULL
);
)SQL";

constexpr int kCurrentVersion = 3;

QString defaultDbPath() {
    // XDG_STATE_HOME，回退 ~/.local/state
    QString stateHome = qEnvironmentVariable("XDG_STATE_HOME");
    if (stateHome.isEmpty())
        stateHome = QDir::homePath() + QStringLiteral("/.local/state");
    return stateHome + QStringLiteral("/lian/lian.db");
}

} // namespace

Database& Database::instance() {
    static Database s;
    return s;
}

Database::~Database() {
    shutdown();
}

bool Database::execMany(sqlite3* db, const char* sql) {
    char* err = nullptr;
    if (sqlite3_exec(db, sql, nullptr, nullptr, &err) != SQLITE_OK) {
        qWarning() << "[clavis::store] exec failed:" << (err ? err : "unknown");
        sqlite3_free(err);
        return false;
    }
    return true;
}

bool Database::open() {
    QMutexLocker lock(&m_openMutex);
    if (m_writer) return true;

    m_path = defaultDbPath();
    QFileInfo fi(m_path);
    QDir().mkpath(fi.absolutePath());

    int rc = sqlite3_open_v2(
        m_path.toUtf8().constData(),
        &m_writer,
        SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX,
        nullptr);

    if (rc != SQLITE_OK) {
        qWarning() << "[clavis::store] open file failed, falling back to :memory:"
                   << sqlite3_errstr(rc) << "path=" << m_path;
        if (m_writer) { sqlite3_close(m_writer); m_writer = nullptr; }
        if (sqlite3_open(":memory:", &m_writer) != SQLITE_OK) {
            qWarning() << "[clavis::store] open :memory: failed";
            m_writer = nullptr;
            return false;
        }
        m_inMemory = true;
    }

    // PRAGMA：WAL + 性能折衷
    if (!m_inMemory) {
        execMany(m_writer,
            "PRAGMA journal_mode=WAL;"
            "PRAGMA synchronous=NORMAL;"
            "PRAGMA temp_store=MEMORY;"
            "PRAGMA busy_timeout=5000;");
    }
    execMany(m_writer, "PRAGMA foreign_keys=ON;");

    if (!migrate()) {
        qWarning() << "[clavis::store] migrate failed";
        return false;
    }

    qInfo() << "[clavis::store] opened" << (m_inMemory ? ":memory:" : m_path)
            << "schema_version=" << m_version;
    return true;
}

bool Database::migrate() {
    if (!execMany(m_writer, kSchemaV1)) return false;

    sqlite3_stmt* st = nullptr;
    int rc = sqlite3_prepare_v2(m_writer,
        "SELECT version FROM schema_version LIMIT 1;", -1, &st, nullptr);
    if (rc != SQLITE_OK) return false;

    int existing = 0;
    if (sqlite3_step(st) == SQLITE_ROW) {
        existing = sqlite3_column_int(st, 0);
    }
    sqlite3_finalize(st);

    if (existing == 0) {
        char* err = nullptr;
        QString sql = QStringLiteral("INSERT INTO schema_version(version) VALUES(%1);")
                          .arg(kCurrentVersion);
        if (sqlite3_exec(m_writer, sql.toUtf8().constData(), nullptr, nullptr, &err) != SQLITE_OK) {
            qWarning() << "[clavis::store] insert version failed:" << (err ? err : "");
            sqlite3_free(err);
            return false;
        }
        existing = kCurrentVersion;
    }

    // v1 → v2：clipboard_entries 增补 paste_mime / paste_html 两列（幂等：失败即视为已存在）
    if (existing < 2) {
        sqlite3_exec(m_writer, "ALTER TABLE clipboard_entries ADD COLUMN paste_mime TEXT;",
                     nullptr, nullptr, nullptr);
        sqlite3_exec(m_writer, "ALTER TABLE clipboard_entries ADD COLUMN paste_html TEXT;",
                     nullptr, nullptr, nullptr);
        sqlite3_exec(m_writer, "UPDATE schema_version SET version=2;",
                     nullptr, nullptr, nullptr);
        existing = 2;
    }

    // v2 → v3：sha256 不再唯一（同图多次复制需保留所有条目，cliphist id 是真主键）
    if (existing < 3) {
        sqlite3_exec(m_writer, "DROP INDEX IF EXISTS idx_clip_sha;",
                     nullptr, nullptr, nullptr);
        sqlite3_exec(m_writer,
                     "CREATE INDEX IF NOT EXISTS idx_clip_sha "
                     "ON clipboard_entries(sha256) WHERE sha256 IS NOT NULL;",
                     nullptr, nullptr, nullptr);
        sqlite3_exec(m_writer, "UPDATE schema_version SET version=3;",
                     nullptr, nullptr, nullptr);
        existing = 3;
    }

    // 未来 migration 链：if (existing < 4) runV3ToV4(); ...

    m_version = existing;
    return true;
}

sqlite3* Database::openReader() {
    if (!m_writer) return nullptr;
    sqlite3* r = nullptr;
    if (m_inMemory) {
        // :memory: 不能跨连接共享，复用 writer。调用方需保证 SELECT 期间无写。
        return m_writer;
    }
    QString uri = QStringLiteral("file:%1?mode=ro&cache=shared").arg(m_path);
    int rc = sqlite3_open_v2(
        uri.toUtf8().constData(), &r,
        SQLITE_OPEN_READONLY | SQLITE_OPEN_URI | SQLITE_OPEN_NOMUTEX,
        nullptr);
    if (rc != SQLITE_OK) {
        qWarning() << "[clavis::store] reader open failed:" << sqlite3_errstr(rc);
        if (r) sqlite3_close(r);
        return nullptr;
    }
    sqlite3_busy_timeout(r, 5000);
    return r;
}

void Database::shutdown() {
    QMutexLocker lock(&m_openMutex);
    if (m_writer) {
        sqlite3_close(m_writer);
        m_writer = nullptr;
    }
}

} // namespace clavis::store
