#pragma once

#include "store/dao/clipboard_dao.h"

#include <QAbstractListModel>
#include <QHash>
#include <QVariantMap>
#include <QVector>

namespace clavis::services {

class ClipboardListModel : public QAbstractListModel {
    Q_OBJECT
public:
    enum Roles {
        IdRole = Qt::UserRole + 1,
        KindRole,
        MimeRole,
        PreviewRole,
        BlobPathRole,
        ThumbUrlRole,        // file:// + blobPath，方便 QML Image 直接绑定
        WidthRole,
        HeightRole,
        BytesRole,
        CreatedAtRole
    };

    explicit ClipboardListModel(QObject* parent = nullptr);

    int rowCount(const QModelIndex& = {}) const override;
    QVariant data(const QModelIndex&, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    Q_INVOKABLE int count() const { return rowCount(); }
    Q_INVOKABLE QVariantMap get(int row) const;

    void setEntries(const QVector<clavis::store::ClipboardEntry>& v);
    const clavis::store::ClipboardEntry* findById(qint64 id) const;

private:
    QVector<clavis::store::ClipboardEntry> m_data;
};

} // namespace clavis::services
