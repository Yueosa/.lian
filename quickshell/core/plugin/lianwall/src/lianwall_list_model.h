#pragma once

#include <QAbstractListModel>
#include <QVariantMap>

struct LianwallItem {
    int index = 0;
    QString filename;
    QString path;
    double angle = 0.0;
    bool locked = false;
    bool inCooldown = false;
    bool isCurrent = false;
    bool isVideo = false;
    QString thumbnailSource;
    bool hasThumbnail = false;
};

class LianwallListModel : public QAbstractListModel {
    Q_OBJECT

public:
    enum Roles {
        IndexRole = Qt::UserRole + 1,
        FilenameRole,
        PathRole,
        AngleRole,
        LockedRole,
        InCooldownRole,
        IsCurrentRole,
        IsVideoRole,
        ThumbnailSourceRole,
        HasThumbnailRole,
        StatusIconRole,
        StatusTextRole,
    };

    explicit LianwallListModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE QVariantMap get(int row) const;
    Q_INVOKABLE int count() const;
    Q_INVOKABLE QString pathAt(int row) const;

    void setItems(QList<LianwallItem> items);
    void updateThumbnailSources();

private:
    QList<LianwallItem> m_items;
    QHash<int, QByteArray> m_roles;

    QVariantMap toMap(const LianwallItem &item) const;
    static QString statusIcon(const LianwallItem &item);
    static QString statusText(const LianwallItem &item);
    static QString thumbnailSourceFor(const LianwallItem &item);
};