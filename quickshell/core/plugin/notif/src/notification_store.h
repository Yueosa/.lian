#pragma once

#include "notification_list_model.h"

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

namespace clavis::store { class NotificationDao; }

namespace clavis::services {

// QML 单例：取代 scripts/notify_db.py + config/NotificationStore.qml + WidgetState 通知数据。
//   - 通知 ingest：QML NotificationServer 单点回调 → 自动做 IM 映射 + 图标解析 + DB 写入
//   - recentModel：最近 N 条活动通知（dismissed_at IS NULL），上限 kHistoryLimit
//   - popupModel：DnD 关闭时短暂展示的飘窗，纯内存，上限 kPopupLimit
//   - appCounts：各 mappedApp 当前活动数量，给 NotifMainView 列表/角标用
//
// QML import: import Clavis.Notif 1.0
class NotificationStore : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(NotificationListModel* recentModel READ recentModel CONSTANT)
    Q_PROPERTY(NotificationListModel* popupModel  READ popupModel  CONSTANT)
    Q_PROPERTY(QVariantMap appCounts  READ appCounts  NOTIFY dataChanged)

public:
    explicit NotificationStore(QObject* parent = nullptr);
    ~NotificationStore() override;

    NotificationListModel* recentModel() const { return m_recent; }
    NotificationListModel* popupModel()  const { return m_popup;  }
    QVariantMap appCounts() const;

    // 入库；n 来自 QML NotificationServer。showPopup 控制是否进 popupModel（DnD 关闭时为 true）。
    Q_INVOKABLE qint64 ingest(const QVariantMap& n, bool showPopup);

    // dismiss：按协议 id 把当前活动条目标记为已 dismiss
    Q_INVOKABLE void dismiss(qint64 notifId);
    // dismiss：按 DB row id
    Q_INVOKABLE void dismissByRowId(qint64 dbId);
    // 全部 dismiss
    Q_INVOKABLE void clearAll();

    // popup 模型操作（不影响历史）
    Q_INVOKABLE void removePopup(qint64 notifId);

    // 给 NotifMainView / NotifDetailView 用：返回某 app 最近活动通知数组
    Q_INVOKABLE QVariantList messagesForApp(const QString& appId, int limit = 50) const;
    // 给 NotifAllView / NotificationContent 用：返回所有活动通知（合并）
    Q_INVOKABLE QVariantList allMessages(int limit = 200) const;
    // app 最近一条的 timestamp（NotifMainView 排序用）
    Q_INVOKABLE qint64 lastTimestampForApp(const QString& appId) const;

signals:
    void dataChanged();        // 历史数据有变更（ingest/dismiss/clear）

private:
    void reloadRecent();
    static QString mapAppId(const QString& desktopEntry,
                            const QString& appName,
                            const QString& summary);
    static QString resolveImage(const QVariantMap& n,
                                const QString& mappedApp,
                                const QString& homeDir);

    static constexpr int kHistoryLimit = 50;
    static constexpr int kPopupLimit   = 3;

    clavis::store::NotificationDao* m_dao = nullptr;
    NotificationListModel*          m_recent = nullptr;
    NotificationListModel*          m_popup  = nullptr;
    QString m_homeDir;
};

} // namespace clavis::services
