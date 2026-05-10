#include "clipboard_store.h"

#include "ipc/cliphist_watcher.h"
#include "store/database.h"
#include "store/dao/clipboard_dao.h"

#include <QDebug>
#include <QDir>
#include <QFile>
#include <QProcess>
#include <QStandardPaths>
#include <QThread>

using clavis::ipc::CliphistWatcher;
using clavis::store::ClipboardDao;
using clavis::store::ClipboardEntry;
using clavis::store::Database;

namespace clavis::services {

namespace {

QString cacheDirPath() {
    QString c = qEnvironmentVariable("XDG_CACHE_HOME");
    if (c.isEmpty()) c = QDir::homePath() + QStringLiteral("/.cache");
    return c + QStringLiteral("/lian/clip");
}

// 命令注入防御：仅允许 mime 字符集
QString sanitizeMime(const QString& s) {
    QString out;
    out.reserve(s.size());
    for (QChar ch : s) {
        if (ch.isLetterOrNumber()
            || ch == QLatin1Char('/')
            || ch == QLatin1Char('.')
            || ch == QLatin1Char('+')
            || ch == QLatin1Char('-')) out.append(ch);
    }
    return out;
}

} // namespace

ClipboardStore::ClipboardStore(QObject* parent)
    : QObject(parent), m_cacheDir(cacheDirPath()) {

    if (!Database::instance().open()) {
        qWarning() << "[ClipboardStore] DB open failed; clipboard disabled";
        return;
    }

    m_dao = new ClipboardDao();
    m_model = new ClipboardListModel(this);
    QDir().mkpath(m_cacheDir);

    // worker 线程：watcher 在该线程内做 cliphist 调用 + decode + dao 写入
    m_worker = new QThread(this);
    m_worker->setObjectName(QStringLiteral("ClipboardWatcher"));
    m_watcher = new CliphistWatcher(m_dao, m_cacheDir);
    m_watcher->moveToThread(m_worker);

    connect(m_worker, &QThread::started,  m_watcher, &CliphistWatcher::start);
    connect(m_worker, &QThread::finished, m_watcher, &QObject::deleteLater);
    connect(m_watcher, &CliphistWatcher::entriesUpdated,
            this, &ClipboardStore::onWatcherUpdated, Qt::QueuedConnection);

    m_worker->start();

    // 初始装载（可能为空）
    reload();
}

ClipboardStore::~ClipboardStore() {
    if (m_worker) {
        QMetaObject::invokeMethod(m_watcher, &CliphistWatcher::stop, Qt::BlockingQueuedConnection);
        m_worker->quit();
        m_worker->wait(2000);
    }
    delete m_dao;
}

void ClipboardStore::setSearchKeyword(const QString& s) {
    if (m_search == s) return;
    m_search = s;
    emit searchKeywordChanged();
    reload();
}

void ClipboardStore::onWatcherUpdated() { reload(); }

void ClipboardStore::reload() {
    if (!m_dao || !m_model) return;
    m_model->setEntries(m_dao->recent(kRecentLimit, m_search));
    emit entriesChanged();
}

void ClipboardStore::refresh() {
    if (m_watcher) {
        QMetaObject::invokeMethod(m_watcher, &CliphistWatcher::tick, Qt::QueuedConnection);
    }
    reload();
}

void ClipboardStore::pasteEntry(qint64 id) {
    if (!m_dao) return;
    const auto* e = m_model->findById(id);
    QString pasteMime;
    QString pasteHtml;
    if (e) {
        pasteMime = e->pasteMime.isEmpty() ? e->mime : e->pasteMime;
        pasteHtml = e->pasteHtml;
    }
    pasteMime = sanitizeMime(pasteMime);

    QStringList wlcopy{ QStringLiteral("wl-copy"), QStringLiteral("-n") };
    if (!pasteMime.isEmpty()) {
        wlcopy << QStringLiteral("--type") << pasteMime;
    }

    QString cmd;
    if (pasteMime == QLatin1String("text/html") && !pasteHtml.isEmpty()) {
        // 直接灌 paste_html，不走 cliphist decode（避免多行 html/body 包装）
        const QString safe = QString(pasteHtml).replace(QLatin1Char('\''), QLatin1String("'\\''"));
        cmd = QStringLiteral("printf '%s' '%1' | %2").arg(safe, wlcopy.join(QLatin1Char(' ')));
    } else {
        cmd = QStringLiteral("printf '%1\\n' | cliphist decode | %2")
                  .arg(QString::number(id), wlcopy.join(QLatin1Char(' ')));
    }

    QProcess::startDetached(QStringLiteral("bash"),
                            { QStringLiteral("-lc"), cmd });
    m_dao->touch(id);
}

void ClipboardStore::clearAll() {
    if (!m_dao) return;
    QProcess::startDetached(QStringLiteral("bash"),
        { QStringLiteral("-lc"), QStringLiteral("cliphist wipe >/dev/null 2>&1") });
    m_dao->clear(m_cacheDir);
    reload();
}

} // namespace clavis::services
