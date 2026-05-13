#include "lianwall_list_model.h"

#include <QCryptographicHash>
#include <QDir>
#include <QFileInfo>
#include <QSet>
#include <QStandardPaths>
#include <QUrl>

#include <algorithm>

namespace {
bool isVideoPath(const QString &filename)
{
    static const QSet<QString> videoExtensions = {
        QStringLiteral("mp4"), QStringLiteral("mkv"), QStringLiteral("webm"),
        QStringLiteral("avi"), QStringLiteral("mov"), QStringLiteral("flv"),
        QStringLiteral("wmv"), QStringLiteral("m4v"), QStringLiteral("3gp"),
        QStringLiteral("ogv"), QStringLiteral("ts"), QStringLiteral("m2ts"),
    };

    return videoExtensions.contains(QFileInfo(filename).suffix().toLower());
}

QString lianwallCacheDir()
{
    const QString standard = QStandardPaths::writableLocation(QStandardPaths::CacheLocation)
                             + QStringLiteral("/thumbnails");
    if (QDir(standard).exists())
        return standard;

    return QDir::homePath() + QStringLiteral("/.cache/Lian/LianWall/thumbnails");
}

QString thumbnailPath(const QString &path)
{
    const QByteArray hash = QCryptographicHash::hash(path.toUtf8(), QCryptographicHash::Md5).toHex();
    return lianwallCacheDir() + QLatin1Char('/') + QString::fromLatin1(hash) + QStringLiteral("_720x720.jpg");
}
}

LianwallListModel::LianwallListModel(QObject *parent)
    : QAbstractListModel(parent)
{
    m_roles = {
        { IndexRole, "wallpaperIndex" },
        { FilenameRole, "wallpaperFilename" },
        { PathRole, "wallpaperPath" },
        { AngleRole, "wallpaperAngle" },
        { LockedRole, "wallpaperLocked" },
        { InCooldownRole, "wallpaperInCooldown" },
        { IsCurrentRole, "wallpaperIsCurrent" },
        { IsVideoRole, "wallpaperIsVideo" },
        { ThumbnailSourceRole, "thumbnailSource" },
        { HasThumbnailRole, "hasThumbnail" },
        { StatusIconRole, "statusIcon" },
        { StatusTextRole, "statusText" },
    };
}

int LianwallListModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_items.size();
}

QVariant LianwallListModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_items.size())
        return {};

    const auto &item = m_items.at(index.row());
    switch (role) {
    case Qt::DisplayRole: return item.filename;
    case IndexRole: return item.index;
    case FilenameRole: return item.filename;
    case PathRole: return item.path;
    case AngleRole: return item.angle;
    case LockedRole: return item.locked;
    case InCooldownRole: return item.inCooldown;
    case IsCurrentRole: return item.isCurrent;
    case IsVideoRole: return item.isVideo;
    case ThumbnailSourceRole: return item.thumbnailSource;
    case HasThumbnailRole: return item.hasThumbnail;
    case StatusIconRole: return statusIcon(item);
    case StatusTextRole: return statusText(item);
    default: return {};
    }
}

QHash<int, QByteArray> LianwallListModel::roleNames() const
{
    return m_roles;
}

QVariantMap LianwallListModel::get(int row) const
{
    if (row < 0 || row >= m_items.size())
        return {};
    return toMap(m_items.at(row));
}

int LianwallListModel::count() const
{
    return m_items.size();
}

QString LianwallListModel::pathAt(int row) const
{
    if (row < 0 || row >= m_items.size())
        return {};
    return m_items.at(row).path;
}

void LianwallListModel::setItems(QList<LianwallItem> items)
{
    for (auto &item : items) {
        item.isVideo = isVideoPath(item.filename.isEmpty() ? item.path : item.filename);
        item.thumbnailSource = thumbnailSourceFor(item);
        item.hasThumbnail = !item.thumbnailSource.isEmpty();
    }

    std::stable_sort(items.begin(), items.end(), [](const LianwallItem &a, const LianwallItem &b) {
        if (a.isCurrent != b.isCurrent)
            return a.isCurrent;
        return a.index < b.index;
    });

    beginResetModel();
    m_items = std::move(items);
    endResetModel();
}

void LianwallListModel::updateThumbnailSources()
{
    if (m_items.isEmpty())
        return;

    for (auto &item : m_items) {
        item.thumbnailSource = thumbnailSourceFor(item);
        item.hasThumbnail = !item.thumbnailSource.isEmpty();
    }

    emit dataChanged(index(0), index(m_items.size() - 1), { ThumbnailSourceRole, HasThumbnailRole });
}

QVariantMap LianwallListModel::toMap(const LianwallItem &item) const
{
    return {
        { QStringLiteral("wallpaperIndex"), item.index },
        { QStringLiteral("wallpaperFilename"), item.filename },
        { QStringLiteral("wallpaperPath"), item.path },
        { QStringLiteral("wallpaperAngle"), item.angle },
        { QStringLiteral("wallpaperLocked"), item.locked },
        { QStringLiteral("wallpaperInCooldown"), item.inCooldown },
        { QStringLiteral("wallpaperIsCurrent"), item.isCurrent },
        { QStringLiteral("wallpaperIsVideo"), item.isVideo },
        { QStringLiteral("thumbnailSource"), item.thumbnailSource },
        { QStringLiteral("hasThumbnail"), item.hasThumbnail },
        { QStringLiteral("statusIcon"), statusIcon(item) },
        { QStringLiteral("statusText"), statusText(item) },
    };
}

QString LianwallListModel::statusIcon(const LianwallItem &item)
{
    if (item.isCurrent)
        return QStringLiteral("");
    if (item.locked)
        return QStringLiteral("");
    if (item.inCooldown)
        return QStringLiteral("");
    return QString();
}

QString LianwallListModel::statusText(const LianwallItem &item)
{
    QStringList states;
    if (item.isCurrent)
        states.push_back(QStringLiteral("当前"));
    if (item.locked)
        states.push_back(QStringLiteral("锁定"));
    if (item.inCooldown)
        states.push_back(QStringLiteral("冷却"));
    return states.join(QStringLiteral(" / "));
}

QString LianwallListModel::thumbnailSourceFor(const LianwallItem &item)
{
    if (item.path.isEmpty())
        return {};

    const QString cached = thumbnailPath(item.path);
    if (QFileInfo::exists(cached))
        return QUrl::fromLocalFile(cached).toString();

    if (!item.isVideo && QFileInfo::exists(item.path))
        return QUrl::fromLocalFile(item.path).toString();

    return {};
}