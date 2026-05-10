#pragma once

#include <QObject>
#include <QString>
#include <QTimer>
#include <QSet>

namespace clavis::store { class ClipboardDao; }

namespace clavis::ipc {

// 周期性 `cliphist list`，diff 出新 id，对每条 `cliphist decode <id>`，
// 分类（text/image/unknown，含 QQ HTML-img 路径），写入 dao + blob 缓存。
//
// 设计为单一 worker 线程内部使用：构造完成后 moveToThread + 信号触发 start()。
class CliphistWatcher : public QObject {
    Q_OBJECT
public:
    explicit CliphistWatcher(clavis::store::ClipboardDao* dao,
                             const QString& cacheDir,
                             QObject* parent = nullptr);

public slots:
    void start();
    void stop();
    // 立即扫一次（pasteEntry / 外部触发后调用）
    void tick();

signals:
    // 至少新增一条 / 同步出删除时触发
    void entriesUpdated();

private:
    bool ensureCacheDir() const;
    QSet<qint64> listCurrent(QHash<qint64, QString>* previewByIdOut) const;
    bool decodeAndPersist(qint64 id, const QString& previewLine);

    clavis::store::ClipboardDao* m_dao;
    QString m_cacheDir;
    QTimer* m_timer = nullptr;
    int m_intervalMs = 1500;
};

} // namespace clavis::ipc
