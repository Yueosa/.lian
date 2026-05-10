#pragma once

#include <QString>
#include <QVector>
#include <QSet>
#include <cstdint>

namespace clavis::store {

struct ClipboardEntry {
    qint64  id = 0;
    QString kind;          // "text" | "image" | "unknown"
    QString mime;          // image/png, text/plain, ...
    QString textPreview;   // 文本前 N 字符；图片为 label
    int     width = 0;
    int     height = 0;
    qint64  bytes = 0;
    QString sha256;
    QString blobPath;      // 图片缩略图绝对路径
    QString pasteMime;     // wl-copy --type
    QString pasteHtml;     // mime=text/html 时的 payload
    qint64  createdAt = 0; // unix ms
    qint64  lastUsedAt = 0;
};

// 同步 DAO；读用临时 reader 连接，写经 writer。
// 调用方不必关心线程，但写入不应被高频并发调用（单 writer）。
class ClipboardDao {
public:
    // 仅当 id 不存在时插入；返回是否新增
    bool upsert(const ClipboardEntry& e);

    // 列出最新 N 条；若 keyword 非空，按 text_preview LIKE %kw% (case-insensitive)
    QVector<ClipboardEntry> recent(int limit, const QString& keyword = {}) const;

    // 当前所有 id（用于 watcher diff）
    QSet<qint64> existingIds() const;

    // 删除单条 + 关联 blob 文件
    bool remove(qint64 id);

    // 清空整张表 + cacheDir 下所有 blob
    bool clear(const QString& cacheDir);

    // 标记最近使用（用于排序提示，目前未参与排序，预留）
    bool touch(qint64 id);
};

} // namespace clavis::store
