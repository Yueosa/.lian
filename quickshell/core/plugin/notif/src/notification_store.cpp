#include "notification_store.h"

#include "store/database.h"
#include "store/dao/notification_dao.h"

#include <QDateTime>
#include <QDebug>
#include <QDir>

using clavis::store::Database;
using clavis::store::NotificationDao;
using clavis::store::NotificationRecord;

namespace clavis::services {

namespace {

// IM 应用关键字映射；QML 端原表照搬
QString matchImKeyword(const QString& s) {
    const QString lower = s.toLower();
    if (lower.contains(QStringLiteral("qq")) || lower.contains(QStringLiteral("tencent")))
        return QStringLiteral("qq");
    if (lower.contains(QStringLiteral("wechat")) || lower.contains(QStringLiteral("\u5fae\u4fe1")))
        return QStringLiteral("wechat");
    if (lower.contains(QStringLiteral("telegram")))
        return QStringLiteral("telegram");
    if (lower.contains(QStringLiteral("discord")))
        return QStringLiteral("discord");
    return {};
}

QString defaultRecord(const QVariantMap& n, const QString& key) {
    auto v = n.value(key);
    return v.isValid() ? v.toString() : QString();
}

} // namespace

NotificationStore::NotificationStore(QObject* parent) : QObject(parent) {
    m_homeDir = qEnvironmentVariable("HOME");
    if (m_homeDir.isEmpty()) m_homeDir = QDir::homePath();

    if (!Database::instance().open()) {
        qWarning() << "[NotificationStore] DB open failed; notifications disabled";
        m_recent = new NotificationListModel(this);
        m_popup  = new NotificationListModel(this);
        return;
    }

    m_dao    = new NotificationDao();
    m_recent = new NotificationListModel(this);
    m_popup  = new NotificationListModel(this);

    reloadRecent();
}

NotificationStore::~NotificationStore() {
    delete m_dao;
}

void NotificationStore::reloadRecent() {
    if (!m_dao) return;
    m_recent->setEntries(m_dao->recent(kHistoryLimit));
    emit dataChanged();
}

QVariantMap NotificationStore::appCounts() const {
    QVariantMap out;
    // 默认五个分类即使为 0 也回 0，保持与 QML 旧表结构一致
    out["system"]   = 0;
    out["qq"]       = 0;
    out["wechat"]   = 0;
    out["telegram"] = 0;
    out["discord"]  = 0;
    if (!m_dao) return out;
    const auto m = m_dao->activeCounts();
    for (auto it = m.constBegin(); it != m.constEnd(); ++it) {
        out[it.key()] = it.value();
    }
    return out;
}

QString NotificationStore::mapAppId(const QString& desktopEntry,
                                    const QString& appName,
                                    const QString& summary) {
    const QString hay =
        desktopEntry.toLower() + QLatin1Char(' ') +
        appName.toLower()      + QLatin1Char(' ') +
        summary.toLower();
    QString id = matchImKeyword(hay);
    return id.isEmpty() ? QStringLiteral("system") : id;
}

QString NotificationStore::resolveImage(const QVariantMap& n,
                                        const QString& mappedApp,
                                        const QString& homeDir) {
    // IM 应用一律走静态 svg（QML 老逻辑：image-data 内联头像暂未支持）
    if (mappedApp != QLatin1String("system")) {
        return QStringLiteral("file://") + homeDir +
               QStringLiteral("/.config/quickshell/assets/apps/") + mappedApp +
               QStringLiteral(".svg");
    }
    const QString rawImage = defaultRecord(n, QStringLiteral("image"));
    if (!rawImage.isEmpty() && !rawImage.startsWith(QStringLiteral("image://qsimage/"))) {
        return rawImage.startsWith(QLatin1Char('/'))
            ? (QStringLiteral("file://") + rawImage)
            : rawImage;
    }
    QString iconName = defaultRecord(n, QStringLiteral("appIcon"));
    if (iconName.isEmpty()) iconName = defaultRecord(n, QStringLiteral("desktopEntry"));
    if (iconName.isEmpty()) iconName = defaultRecord(n, QStringLiteral("icon"));
    if (iconName.isEmpty()) return {};
    if (iconName.startsWith(QLatin1Char('/')) || iconName.startsWith(QStringLiteral("file://"))) {
        return iconName.startsWith(QLatin1Char('/'))
            ? (QStringLiteral("file://") + iconName) : iconName;
    }
    return QStringLiteral("icon:") + iconName;
}

qint64 NotificationStore::ingest(const QVariantMap& n, bool showPopup) {
    if (!m_dao) return 0;

    const QString appName      = defaultRecord(n, QStringLiteral("appName"));
    const QString desktopEntry = defaultRecord(n, QStringLiteral("desktopEntry"));
    const QString summary      = defaultRecord(n, QStringLiteral("summary"));
    const QString body         = defaultRecord(n, QStringLiteral("body"));
    const qint64  notifId      = n.value(QStringLiteral("id")).toLongLong();

    // 过滤媒体类（保持与旧 QML 行为一致）
    const QString deLower = desktopEntry.toLower();
    if (deLower == QLatin1String("spotify") || deLower.contains(QStringLiteral("player"))) {
        return 0;
    }

    NotificationRecord r;
    r.notifId      = notifId;
    r.appName      = appName;
    r.desktopEntry = desktopEntry;
    r.summary      = summary;
    r.body         = body;
    r.mappedApp    = mapAppId(desktopEntry, appName, summary);
    r.category     = (r.mappedApp == QLatin1String("system"))
                        ? QStringLiteral("sys") : QStringLiteral("im");
    r.imagePath    = resolveImage(n, r.mappedApp, m_homeDir);
    r.receivedAt   = QDateTime::currentMSecsSinceEpoch();

    qint64 dbId = m_dao->insert(r);
    if (dbId == 0) return 0;
    r.id = dbId;

    m_recent->prepend(r, kHistoryLimit);
    if (showPopup) {
        m_popup->prepend(r, kPopupLimit);
    }
    emit dataChanged();
    return notifId;
}

void NotificationStore::dismiss(qint64 notifId) {
    if (!m_dao) return;
    if (!m_dao->dismissByNotifId(notifId)) return;
    m_recent->removeByNotifId(notifId);
    m_popup->removeByNotifId(notifId);
    emit dataChanged();
}

void NotificationStore::dismissByRowId(qint64 dbId) {
    if (!m_dao) return;
    if (!m_dao->dismissByRowId(dbId)) return;
    reloadRecent();
}

void NotificationStore::clearAll() {
    if (!m_dao) return;
    if (!m_dao->clear()) return;
    m_popup->clearAll();
    reloadRecent();
}

void NotificationStore::removePopup(qint64 notifId) {
    if (!m_popup) return;
    m_popup->removeByNotifId(notifId);
}

QVariantList NotificationStore::messagesForApp(const QString& appId, int limit) const {
    QVariantList out;
    if (!m_dao || appId.isEmpty()) return out;
    const auto rows = m_dao->recentForApp(appId, limit);
    out.reserve(rows.size());
    for (const auto& r : rows) {
        QVariantMap m;
        m["id"]        = r.notifId;       // 兼容 QML modelData.id == 协议 id
        m["dbId"]      = r.id;
        m["notifId"]   = r.notifId;
        m["title"]     = r.summary;
        m["summary"]   = r.summary;
        m["body"]      = r.body;
        m["timestamp"] = r.receivedAt;
        m["appId"]     = r.mappedApp;
        m["imagePath"] = r.imagePath;
        out.push_back(m);
    }
    return out;
}

QVariantList NotificationStore::allMessages(int limit) const {
    QVariantList out;
    if (!m_dao) return out;
    const auto rows = m_dao->recent(limit);
    out.reserve(rows.size());
    for (const auto& r : rows) {
        QVariantMap m;
        m["id"]        = r.notifId;
        m["dbId"]      = r.id;
        m["notifId"]   = r.notifId;
        m["title"]     = r.summary;
        m["summary"]   = r.summary;
        m["body"]      = r.body;
        m["timestamp"] = r.receivedAt;
        m["appId"]     = r.mappedApp;
        m["imagePath"] = r.imagePath;
        out.push_back(m);
    }
    return out;
}

qint64 NotificationStore::lastTimestampForApp(const QString& appId) const {
    if (!m_dao || appId.isEmpty()) return 0;
    const auto rows = m_dao->recentForApp(appId, 1);
    return rows.isEmpty() ? 0 : rows.first().receivedAt;
}

} // namespace clavis::services
