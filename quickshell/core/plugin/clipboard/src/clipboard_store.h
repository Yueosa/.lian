#pragma once

#include "clipboard_list_model.h"

#include <QObject>
#include <QString>
#include <QtQml/qqmlregistration.h>

class QThread;
namespace clavis::ipc { class CliphistWatcher; }
namespace clavis::store { class ClipboardDao; }

namespace clavis::services {

// QML 单例：取代 scripts/clipboard_dump.py 全部职责。
//   - 持有 dao + worker 线程上的 cliphist watcher
//   - 暴露 recentEntries 模型（最近 50 条，搜索时为过滤结果）
//   - 提供 paste / remove / clear / refresh
//
// QML import: import Clavis.Clipboard 1.0  → ClipboardStore.recentEntries 等
class ClipboardStore : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(ClipboardListModel* recentEntries READ recentEntries CONSTANT)
    Q_PROPERTY(QString searchKeyword READ searchKeyword WRITE setSearchKeyword NOTIFY searchKeywordChanged)
    Q_PROPERTY(int totalCount READ totalCount NOTIFY entriesChanged)
    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged)

public:
    explicit ClipboardStore(QObject* parent = nullptr);
    ~ClipboardStore() override;

    ClipboardListModel* recentEntries() const { return m_model; }
    QString searchKeyword() const { return m_search; }
    void setSearchKeyword(const QString& s);
    int totalCount() const { return m_total; }
    bool ready() const { return m_ready; }

    Q_INVOKABLE void pasteEntry(qint64 id);
    Q_INVOKABLE void removeEntry(qint64 id);
    Q_INVOKABLE void clearAll();
    Q_INVOKABLE void refresh();

signals:
    void entriesChanged();
    void searchKeywordChanged();
    void readyChanged();

private slots:
    void onWatcherUpdated();

private:
    void reload();

    static constexpr int kRecentLimit = 50;

    clavis::store::ClipboardDao* m_dao = nullptr;
    ClipboardListModel*          m_model = nullptr;
    clavis::ipc::CliphistWatcher* m_watcher = nullptr;
    QThread*                      m_worker = nullptr;
    QString                       m_cacheDir;
    QString                       m_search;
    int                           m_total = 0;
    bool                          m_ready = false;
};

} // namespace clavis::services
