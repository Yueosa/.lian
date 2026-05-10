#include "notification_list_model.h"

#include <QDateTime>

namespace clavis::services {

using clavis::store::NotificationRecord;

NotificationListModel::NotificationListModel(QObject* parent)
    : QAbstractListModel(parent) {}

int NotificationListModel::rowCount(const QModelIndex&) const { return m_data.size(); }

static QString fmtHm(qint64 ms) {
    if (ms <= 0) return {};
    return QDateTime::fromMSecsSinceEpoch(ms).toString(QStringLiteral("HH:mm"));
}

QVariant NotificationListModel::data(const QModelIndex& idx, int role) const {
    if (!idx.isValid() || idx.row() < 0 || idx.row() >= m_data.size()) return {};
    const auto& r = m_data.at(idx.row());
    switch (role) {
        case DbIdRole:        return r.id;
        case NotifIdRole:     return r.notifId;
        case AppNameRole:     return r.appName;
        case AppIdRole:       return r.mappedApp;
        case DesktopEntryRole:return r.desktopEntry;
        case SummaryRole:     return r.summary;
        case TitleRole:       return r.summary;
        case BodyRole:        return r.body;
        case ImagePathRole:   return r.imagePath;
        case TimestampRole:   return r.receivedAt;
        case TimeRole:        return fmtHm(r.receivedAt);
    }
    return {};
}

QHash<int, QByteArray> NotificationListModel::roleNames() const {
    return {
        { DbIdRole,         "dbId" },
        { NotifIdRole,      "notifId" },
        { AppNameRole,      "appName" },
        { AppIdRole,        "appId" },
        { DesktopEntryRole, "desktopEntry" },
        { SummaryRole,      "summary" },
        { TitleRole,        "title" },
        { BodyRole,         "body" },
        { ImagePathRole,    "imagePath" },
        { TimestampRole,    "timestamp" },
        { TimeRole,         "time" }
    };
}

QVariantMap NotificationListModel::get(int row) const {
    QVariantMap m;
    if (row < 0 || row >= m_data.size()) return m;
    const auto& r = m_data.at(row);
    m["dbId"]         = r.id;
    m["notifId"]      = r.notifId;
    m["appName"]      = r.appName;
    m["appId"]        = r.mappedApp;
    m["desktopEntry"] = r.desktopEntry;
    m["summary"]      = r.summary;
    m["title"]        = r.summary;
    m["body"]         = r.body;
    m["imagePath"]    = r.imagePath;
    m["timestamp"]    = r.receivedAt;
    m["time"]         = fmtHm(r.receivedAt);
    return m;
}

void NotificationListModel::setEntries(const QVector<NotificationRecord>& v) {
    const int oldCount = m_data.size();
    beginResetModel();
    m_data = v;
    endResetModel();
    if (m_data.size() != oldCount)
        emit countChanged();
}

void NotificationListModel::prepend(const NotificationRecord& r, int cap) {
    const int oldCount = m_data.size();
    beginInsertRows({}, 0, 0);
    m_data.prepend(r);
    endInsertRows();
    while (cap > 0 && m_data.size() > cap) {
        const int last = m_data.size() - 1;
        beginRemoveRows({}, last, last);
        m_data.removeAt(last);
        endRemoveRows();
    }
    if (m_data.size() != oldCount)
        emit countChanged();
}

void NotificationListModel::removeByNotifId(qint64 notifId) {
    const int oldCount = m_data.size();
    for (int i = 0; i < m_data.size(); ++i) {
        if (m_data.at(i).notifId == notifId) {
            beginRemoveRows({}, i, i);
            m_data.removeAt(i);
            endRemoveRows();
            if (m_data.size() != oldCount)
                emit countChanged();
            return;
        }
    }
}

void NotificationListModel::clearAll() {
    if (m_data.isEmpty()) return;
    beginResetModel();
    m_data.clear();
    endResetModel();
    emit countChanged();
}

} // namespace clavis::services
