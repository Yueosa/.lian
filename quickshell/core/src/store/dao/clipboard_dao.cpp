#include "clipboard_dao.h"
#include "store/database.h"

#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <sqlite3.h>

namespace clavis::store {

namespace {

QString colText(sqlite3_stmt* st, int i) {
    auto p = sqlite3_column_text(st, i);
    return p ? QString::fromUtf8(reinterpret_cast<const char*>(p)) : QString();
}

ClipboardEntry rowToEntry(sqlite3_stmt* st) {
    ClipboardEntry e;
    e.id          = sqlite3_column_int64(st, 0);
    e.kind        = colText(st, 1);
    e.mime        = colText(st, 2);
    e.textPreview = colText(st, 3);
    e.width       = sqlite3_column_int(st, 4);
    e.height      = sqlite3_column_int(st, 5);
    e.bytes       = sqlite3_column_int64(st, 6);
    e.sha256      = colText(st, 7);
    e.blobPath    = colText(st, 8);
    e.pasteMime   = colText(st, 9);
    e.pasteHtml   = colText(st, 10);
    e.createdAt   = sqlite3_column_int64(st, 11);
    e.lastUsedAt  = sqlite3_column_int64(st, 12);
    return e;
}

constexpr const char* kSelectCols =
    "id,kind,mime,text_preview,width,height,bytes,sha256,blob_path,"
    "paste_mime,paste_html,created_at,last_used_at";

void bindText(sqlite3_stmt* st, int i, const QString& s) {
    if (s.isNull()) sqlite3_bind_null(st, i);
    else {
        QByteArray b = s.toUtf8();
        sqlite3_bind_text(st, i, b.constData(), b.size(), SQLITE_TRANSIENT);
    }
}

} // namespace

bool ClipboardDao::upsert(const ClipboardEntry& e) {
    auto* db = Database::instance().writer();
    if (!db) return false;
    const char* sql =
        "INSERT OR IGNORE INTO clipboard_entries"
        "(id,kind,mime,text_preview,width,height,bytes,sha256,blob_path,"
        " paste_mime,paste_html,created_at,last_used_at)"
        "VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?);";;
    sqlite3_stmt* st = nullptr;
    if (sqlite3_prepare_v2(db, sql, -1, &st, nullptr) != SQLITE_OK) {
        qWarning() << "[clipboard_dao] prepare upsert:" << sqlite3_errmsg(db);
        return false;
    }
    sqlite3_bind_int64(st, 1, e.id);
    bindText(st, 2, e.kind);
    bindText(st, 3, e.mime);
    bindText(st, 4, e.textPreview);
    sqlite3_bind_int(st, 5, e.width);
    sqlite3_bind_int(st, 6, e.height);
    sqlite3_bind_int64(st, 7, e.bytes);
    bindText(st, 8, e.sha256);
    bindText(st, 9, e.blobPath);
    bindText(st, 10, e.pasteMime);
    bindText(st, 11, e.pasteHtml);
    sqlite3_bind_int64(st, 12, e.createdAt);
    sqlite3_bind_int64(st, 13, e.lastUsedAt);
    int rc = sqlite3_step(st);
    int changes = sqlite3_changes(db);
    sqlite3_finalize(st);
    if (rc != SQLITE_DONE) {
        qWarning() << "[clipboard_dao] step upsert:" << sqlite3_errmsg(db);
        return false;
    }
    return changes > 0;
}

QVector<ClipboardEntry> ClipboardDao::recent(int limit, const QString& keyword) const {
    QVector<ClipboardEntry> out;
    auto* db = Database::instance().openReader();
    if (!db) return out;

    QString sql = QStringLiteral("SELECT %1 FROM clipboard_entries").arg(QString::fromLatin1(kSelectCols));
    QByteArray kwBytes;
    if (!keyword.isEmpty()) {
        sql += QStringLiteral(" WHERE LOWER(text_preview) LIKE ?");
        kwBytes = (QStringLiteral("%") + keyword.toLower() + QStringLiteral("%")).toUtf8();
    }
    sql += QStringLiteral(" ORDER BY created_at DESC LIMIT ?;");

    sqlite3_stmt* st = nullptr;
    QByteArray sb = sql.toUtf8();
    if (sqlite3_prepare_v2(db, sb.constData(), sb.size(), &st, nullptr) != SQLITE_OK) {
        qWarning() << "[clipboard_dao] prepare recent:" << sqlite3_errmsg(db);
        if (db != Database::instance().writer()) sqlite3_close(db);
        return out;
    }
    int idx = 1;
    if (!kwBytes.isEmpty()) {
        sqlite3_bind_text(st, idx++, kwBytes.constData(), kwBytes.size(), SQLITE_TRANSIENT);
    }
    sqlite3_bind_int(st, idx, limit);

    while (sqlite3_step(st) == SQLITE_ROW) {
        out.push_back(rowToEntry(st));
    }
    sqlite3_finalize(st);
    if (db != Database::instance().writer()) sqlite3_close(db);
    return out;
}

QSet<qint64> ClipboardDao::existingIds() const {
    QSet<qint64> out;
    auto* db = Database::instance().openReader();
    if (!db) return out;
    sqlite3_stmt* st = nullptr;
    if (sqlite3_prepare_v2(db, "SELECT id FROM clipboard_entries;", -1, &st, nullptr) == SQLITE_OK) {
        while (sqlite3_step(st) == SQLITE_ROW) out.insert(sqlite3_column_int64(st, 0));
    }
    sqlite3_finalize(st);
    if (db != Database::instance().writer()) sqlite3_close(db);
    return out;
}

bool ClipboardDao::remove(qint64 id) {
    auto* db = Database::instance().writer();
    if (!db) return false;
    QString blob;
    sqlite3_stmt* qs = nullptr;
    if (sqlite3_prepare_v2(db, "SELECT blob_path FROM clipboard_entries WHERE id=?;",
                           -1, &qs, nullptr) == SQLITE_OK) {
        sqlite3_bind_int64(qs, 1, id);
        if (sqlite3_step(qs) == SQLITE_ROW) blob = colText(qs, 0);
    }
    sqlite3_finalize(qs);

    sqlite3_stmt* st = nullptr;
    if (sqlite3_prepare_v2(db, "DELETE FROM clipboard_entries WHERE id=?;",
                           -1, &st, nullptr) != SQLITE_OK) return false;
    sqlite3_bind_int64(st, 1, id);
    int rc = sqlite3_step(st);
    sqlite3_finalize(st);
    if (rc != SQLITE_DONE) return false;

    if (!blob.isEmpty()) QFile::remove(blob);
    return true;
}

bool ClipboardDao::clear(const QString& cacheDir) {
    auto* db = Database::instance().writer();
    if (!db) return false;
    char* err = nullptr;
    if (sqlite3_exec(db, "DELETE FROM clipboard_entries;", nullptr, nullptr, &err) != SQLITE_OK) {
        qWarning() << "[clipboard_dao] clear:" << (err ? err : "");
        sqlite3_free(err);
        return false;
    }
    if (!cacheDir.isEmpty()) {
        QDir d(cacheDir);
        if (d.exists()) {
            const auto files = d.entryList(QDir::Files | QDir::NoSymLinks);
            for (const auto& f : files) d.remove(f);
        }
    }
    return true;
}

bool ClipboardDao::touch(qint64 id) {
    auto* db = Database::instance().writer();
    if (!db) return false;
    sqlite3_stmt* st = nullptr;
    if (sqlite3_prepare_v2(db, "UPDATE clipboard_entries SET last_used_at=? WHERE id=?;",
                           -1, &st, nullptr) != SQLITE_OK) return false;
    sqlite3_bind_int64(st, 1, QDateTime::currentMSecsSinceEpoch());
    sqlite3_bind_int64(st, 2, id);
    int rc = sqlite3_step(st);
    sqlite3_finalize(st);
    return rc == SQLITE_DONE;
}

int ClipboardDao::totalCount() const {
    auto* db = Database::instance().openReader();
    if (!db) return 0;
    sqlite3_stmt* st = nullptr;
    int n = 0;
    if (sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM clipboard_entries;", -1, &st, nullptr) == SQLITE_OK) {
        if (sqlite3_step(st) == SQLITE_ROW) n = sqlite3_column_int(st, 0);
    }
    sqlite3_finalize(st);
    if (db != Database::instance().writer()) sqlite3_close(db);
    return n;
}

} // namespace clavis::store
