#include "clipboard_list_model.h"

namespace clavis::services {

ClipboardListModel::ClipboardListModel(QObject* parent)
    : QAbstractListModel(parent) {}

int ClipboardListModel::rowCount(const QModelIndex&) const { return m_data.size(); }

QVariant ClipboardListModel::data(const QModelIndex& idx, int role) const {
    if (!idx.isValid() || idx.row() < 0 || idx.row() >= m_data.size()) return {};
    const auto& e = m_data.at(idx.row());
    switch (role) {
        case IdRole:        return e.id;
        case KindRole:      return e.kind;
        case MimeRole:      return e.mime;
        case PreviewRole:   return e.textPreview;
        case BlobPathRole:  return e.blobPath;
        case ThumbUrlRole:  return e.blobPath.isEmpty() ? QString() : QStringLiteral("file://") + e.blobPath;
        case WidthRole:     return e.width;
        case HeightRole:    return e.height;
        case BytesRole:     return e.bytes;
        case CreatedAtRole: return e.createdAt;
    }
    return {};
}

QHash<int, QByteArray> ClipboardListModel::roleNames() const {
    return {
        { IdRole,        "entryId" },
        { KindRole,      "kind" },
        { MimeRole,      "mime" },
        { PreviewRole,   "preview" },
        { BlobPathRole,  "blobPath" },
        { ThumbUrlRole,  "thumbUrl" },
        { WidthRole,     "imgWidth" },
        { HeightRole,    "imgHeight" },
        { BytesRole,     "byteSize" },
        { CreatedAtRole, "createdAt" }
    };
}

QVariantMap ClipboardListModel::get(int row) const {
    QVariantMap m;
    if (row < 0 || row >= m_data.size()) return m;
    const auto& e = m_data.at(row);
    m["entryId"]   = e.id;
    m["kind"]      = e.kind;
    m["mime"]      = e.mime;
    m["preview"]   = e.textPreview;
    m["blobPath"]  = e.blobPath;
    m["thumbUrl"]  = e.blobPath.isEmpty() ? QString() : QStringLiteral("file://") + e.blobPath;
    m["imgWidth"]  = e.width;
    m["imgHeight"] = e.height;
    m["byteSize"]  = e.bytes;
    m["createdAt"] = e.createdAt;
    return m;
}

void ClipboardListModel::setEntries(const QVector<clavis::store::ClipboardEntry>& v) {
    beginResetModel();
    m_data = v;
    endResetModel();
}

const clavis::store::ClipboardEntry* ClipboardListModel::findById(qint64 id) const {
    for (const auto& e : m_data) if (e.id == id) return &e;
    return nullptr;
}

} // namespace clavis::services
