#pragma once

#include <QHash>
#include <QString>
#include <QVector>
#include <cstdint>

namespace clavis::store {

struct NotificationRecord {
    qint64  id           = 0;       // DB row id (AUTOINCREMENT)
    qint64  notifId      = 0;       // 协议 id（freedesktop notification 的 n.id）
    QString appName;
    QString desktopEntry;
    QString summary;
    QString body;
    QString imagePath;              // 已解析：file://... 或 icon:NAME
    QString category;               // 'im' | 'sys'
    QString mappedApp;              // 'system' | 'qq' | 'wechat' | ...
    qint64  receivedAt   = 0;       // unix ms
    qint64  readAt       = 0;       // 0 = 未读
    qint64  dismissedAt  = 0;       // 0 = 仍在历史中；非 0 = 已被 dismiss/clear
};

// 同步 DAO；仅活动通知（dismissed_at IS NULL）参与展示。
class NotificationDao {
public:
    // 写入新通知，返回 DB row id（失败返回 0）
    qint64 insert(const NotificationRecord& r);

    // 标记 dismissed（按协议 id；最近一条匹配的活动条目）
    bool dismissByNotifId(qint64 notifId);

    // 标记 dismissed（按 DB row id）
    bool dismissByRowId(qint64 dbId);

    // 把指定 mappedApp 的所有活动通知 dismiss；空字符串 = 全部
    bool clear(const QString& mappedApp = {});

    // 最近 N 条活动通知（按 received_at DESC）
    QVector<NotificationRecord> recent(int limit) const;

    // 按 mappedApp 过滤的最近活动通知
    QVector<NotificationRecord> recentForApp(const QString& mappedApp, int limit) const;

    // 各 mappedApp 当前活动通知数量
    QHash<QString, int> activeCounts() const;

    // 全量活动数
    int activeTotal() const;
};

} // namespace clavis::store
