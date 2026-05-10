#include "notification_dao.h"
#include "store/database.h"

#include <QDateTime>
#include <QDebug>
#include <sqlite3.h>

namespace clavis::store {

namespace {

QString colText(sqlite3_stmt* st, int i) {
    auto p = sqlite3_column_text(st, i);
    return p ? QString::fromUtf8(reinterpret_cast<const char*>(p)) : QString();
}

void bindText(sqlite3_stmt* st, int i, const QString& s) {
    if (s.isNull()) {
        sqlite3_bind_null(st, i);
    } else {
        QByteArray b = s.toUtf8();
        sqlite3_bind_text(st, i, b.constData(), b.size(), SQLITE_TRANSIENT);
    }
}

constexpr const char* kSelectCols =
    "id,notif_id,app_name,desktop_entry,summary,body,image_path,"
    "category,mapped_app,received_at,read_at,dismissed_at";

NotificationRecord rowToRecord(sqlite3_stmt* st) {
    NotificationRecord r;
    r.id           = sqlite3_column_int64(st, 0);
    r.notifId      = sqlite3_column_int64(st, 1);
    r.appName      = colText(st, 2);
    r.desktopEntry = colText(st, 3);
    r.summary      = colText(st, 4);
    r.body         = colText(st, 5);
    r.imagePath    = colText(st, 6);
    r.category     = colText(st, 7);
    r.mappedApp    = colText(st, 8);
    r.receivedAt   = sqlite3_column_int64(st, 9);
    r.readAt       = sqlite3_column_int64(st, 10);
    r.dismissedAt  = sqlite3_column_int64(st, 11);
    return r;
}

} // namespace

qint64 NotificationDao::insert(const NotificationRecord& r) {
    auto* db = Database::instance().writer();
    if (!db) return 0;
    const char* sql =
        "INSERT INTO notifications"
        "(notif_id,app_name,desktop_entry,summary,body,image_path,"
        " category,mapped_app,received_at,read_at,dismissed_at)"
        "VALUES(?,?,?,?,?,?,?,?,?,NULL,NULL);";
    sqlite3_stmt* st = nullptr;
    if (sqlite3_prepare_v2(db, sql, -1, &st, nullptr) != SQLITE_OK) {
        qWarning() << "[notification_dao] prepare insert:" << sqlite3_errmsg(db);
        return 0;
    }
    sqlite3_bind_int64(st, 1, r.notifId);
    bindText(st, 2, r.appName);
    bindText(st, 3, r.desktopEntry);
    bindText(st, 4, r.summary);
    bindText(st, 5, r.body);
    bindText(st, 6, r.imagePath);
    bindText(st, 7, r.category);
    bindText(st, 8, r.mappedApp);
    sqlite3_bind_int64(st, 9, r.receivedAt);
    int rc = sqlite3_step(st);
    qint64 newId = (rc == SQLITE_DONE) ? sqlite3_last_insert_rowid(db) : 0;
    sqlite3_finalize(st);
    if (rc != SQLITE_DONE) {
        qWarning() << "[notification_dao] step insert:" << sqlite3_errmsg(db);
        return 0;
    }
    return newId;
}

bool NotificationDao::dismissByNotifId(qint64 notifId) {
    auto* db = Database::instance().writer();
    if (!db) return false;
    sqlite3_stmt* st = nullptr;
    // 同一 notif_id 可能历史出现过多次（通知被替换），只 dismiss 当前活动条目
    if (sqlite3_prepare_v2(db,
            "UPDATE notifications SET dismissed_at=? "
            "WHERE notif_id=? AND dismissed_at IS NULL;",
            -1, &st, nullptr) != SQLITE_OK) return false;
    sqlite3_bind_int64(st, 1, QDateTime::currentMSecsSinceEpoch());
    sqlite3_bind_int64(st, 2, notifId);
    int rc = sqlite3_step(st);
    sqlite3_finalize(st);
    return rc == SQLITE_DONE;
}

bool NotificationDao::dismissByRowId(qint64 dbId) {
    auto* db = Database::instance().writer();
    if (!db) return false;
    sqlite3_stmt* st = nullptr;
    if (sqlite3_prepare_v2(db,
            "UPDATE notifications SET dismissed_at=? WHERE id=? AND dismissed_at IS NULL;",
            -1, &st, nullptr) != SQLITE_OK) return false;
    sqlite3_bind_int64(st, 1, QDateTime::currentMSecsSinceEpoch());
    sqlite3_bind_int64(st, 2, dbId);
    int rc = sqlite3_step(st);
    sqlite3_finalize(st);
    return rc == SQLITE_DONE;
}

bool NotificationDao::clear(const QString& mappedApp) {
    auto* db = Database::instance().writer();
    if (!db) return false;
    sqlite3_stmt* st = nullptr;
    if (mappedApp.isEmpty()) {
        if (sqlite3_prepare_v2(db,
                "UPDATE notifications SET dismissed_at=? WHERE dismissed_at IS NULL;",
                -1, &st, nullptr) != SQLITE_OK) return false;
        sqlite3_bind_int64(st, 1, QDateTime::currentMSecsSinceEpoch());
    } else {
        if (sqlite3_prepare_v2(db,
                "UPDATE notifications SET dismissed_at=? "
                "WHERE mapped_app=? AND dismissed_at IS NULL;",
                -1, &st, nullptr) != SQLITE_OK) return false;
        sqlite3_bind_int64(st, 1, QDateTime::currentMSecsSinceEpoch());
        bindText(st, 2, mappedApp);
    }
    int rc = sqlite3_step(st);
    sqlite3_finalize(st);
    return rc == SQLITE_DONE;
}

QVector<NotificationRecord> NotificationDao::recent(int limit) const {
    QVector<NotificationRecord> out;
    auto* db = Database::instance().openReader();
    if (!db) return out;
    QString sql = QStringLiteral("SELECT %1 FROM notifications "
                                 "WHERE dismissed_at IS NULL "
                                 "ORDER BY received_at DESC LIMIT ?;")
                      .arg(QString::fromLatin1(kSelectCols));
    sqlite3_stmt* st = nullptr;
    QByteArray sb = sql.toUtf8();
    if (sqlite3_prepare_v2(db, sb.constData(), sb.size(), &st, nullptr) == SQLITE_OK) {
        sqlite3_bind_int(st, 1, limit);
        while (sqlite3_step(st) == SQLITE_ROW) out.push_back(rowToRecord(st));
    }
    sqlite3_finalize(st);
    if (db != Database::instance().writer()) sqlite3_close(db);
    return out;
}

QVector<NotificationRecord> NotificationDao::recentForApp(const QString& mappedApp, int limit) const {
    QVector<NotificationRecord> out;
    auto* db = Database::instance().openReader();
    if (!db) return out;
    QString sql = QStringLiteral("SELECT %1 FROM notifications "
                                 "WHERE dismissed_at IS NULL AND mapped_app=? "
                                 "ORDER BY received_at DESC LIMIT ?;")
                      .arg(QString::fromLatin1(kSelectCols));
    sqlite3_stmt* st = nullptr;
    QByteArray sb = sql.toUtf8();
    if (sqlite3_prepare_v2(db, sb.constData(), sb.size(), &st, nullptr) == SQLITE_OK) {
        bindText(st, 1, mappedApp);
        sqlite3_bind_int(st, 2, limit);
        while (sqlite3_step(st) == SQLITE_ROW) out.push_back(rowToRecord(st));
    }
    sqlite3_finalize(st);
    if (db != Database::instance().writer()) sqlite3_close(db);
    return out;
}

QHash<QString, int> NotificationDao::activeCounts() const {
    QHash<QString, int> out;
    auto* db = Database::instance().openReader();
    if (!db) return out;
    sqlite3_stmt* st = nullptr;
    if (sqlite3_prepare_v2(db,
            "SELECT COALESCE(mapped_app,'system'), COUNT(*) FROM notifications "
            "WHERE dismissed_at IS NULL GROUP BY COALESCE(mapped_app,'system');",
            -1, &st, nullptr) == SQLITE_OK) {
        while (sqlite3_step(st) == SQLITE_ROW) {
            out.insert(colText(st, 0), sqlite3_column_int(st, 1));
        }
    }
    sqlite3_finalize(st);
    if (db != Database::instance().writer()) sqlite3_close(db);
    return out;
}

int NotificationDao::activeTotal() const {
    auto* db = Database::instance().openReader();
    if (!db) return 0;
    sqlite3_stmt* st = nullptr;
    int n = 0;
    if (sqlite3_prepare_v2(db,
            "SELECT COUNT(*) FROM notifications WHERE dismissed_at IS NULL;",
            -1, &st, nullptr) == SQLITE_OK) {
        if (sqlite3_step(st) == SQLITE_ROW) n = sqlite3_column_int(st, 0);
    }
    sqlite3_finalize(st);
    if (db != Database::instance().writer()) sqlite3_close(db);
    return n;
}

} // namespace clavis::store
