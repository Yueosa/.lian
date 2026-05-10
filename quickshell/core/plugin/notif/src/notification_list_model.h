#pragma once

#include "store/dao/notification_dao.h"

#include <QAbstractListModel>
#include <QHash>
#include <QVariantMap>
#include <QVector>

namespace clavis::services {

class NotificationListModel : public QAbstractListModel {
    Q_OBJECT
public:
    enum Roles {
        DbIdRole = Qt::UserRole + 1,
        NotifIdRole,
        AppNameRole,
        AppIdRole,        // mappedApp
        DesktopEntryRole,
        SummaryRole,
        BodyRole,
        ImagePathRole,
        TimestampRole,    // unix ms
        TimeRole,         // "HH:mm" 兼容旧字段
        // 兼容 Lock NotificationCard：title/imagePath/summary/body/time
        TitleRole,        // = summary
    };

    explicit NotificationListModel(QObject* parent = nullptr);

    int rowCount(const QModelIndex& = {}) const override;
    QVariant data(const QModelIndex&, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE int count() const { return rowCount(); }
    Q_INVOKABLE QVariantMap get(int row) const;

    void setEntries(const QVector<clavis::store::NotificationRecord>& v);
    void prepend(const clavis::store::NotificationRecord& r, int cap);
    void removeByNotifId(qint64 notifId);
    void clearAll();

private:
    QVector<clavis::store::NotificationRecord> m_data;
};

} // namespace clavis::services
