#include "cliphist_watcher.h"

#include "store/dao/clipboard_dao.h"
#include "util/image_detect.h"

#include <QByteArray>
#include <QCryptographicHash>
#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QHash>
#include <QProcess>
#include <QRegularExpression>
#include <QSet>
#include <QStringDecoder>

using clavis::store::ClipboardEntry;
using clavis::util::detectImageKind;
using clavis::util::extForKind;
using clavis::util::extractHtmlImagePath;
using clavis::util::hintImageKind;
using clavis::util::looksBinary;
using clavis::util::stripHtmlToPlain;

namespace clavis::ipc {

namespace {

// 同步执行 cliphist；input 非空时写入 stdin；返回 stdout 字节
QByteArray runCliphist(const QStringList& args,
                       const QByteArray& input = {},
                       int* exitCodeOut = nullptr,
                       int timeoutMs = 4000) {
    QProcess p;
    p.setProcessChannelMode(QProcess::SeparateChannels);
    p.start(QStringLiteral("cliphist"), args);
    if (!p.waitForStarted(1500)) {
        if (exitCodeOut) *exitCodeOut = -1;
        return {};
    }
    if (!input.isEmpty()) {
        p.write(input);
        p.closeWriteChannel();
    }
    if (!p.waitForFinished(timeoutMs)) {
        p.kill();
        p.waitForFinished(500);
        if (exitCodeOut) *exitCodeOut = -1;
        return {};
    }
    if (exitCodeOut) *exitCodeOut = p.exitCode();
    return p.readAllStandardOutput();
}

QString normalizePreview(const QString& s) {
    QString one = s;
    one.replace(QLatin1Char('\n'), QLatin1Char(' '));
    one.replace(QLatin1Char('\r'), QLatin1Char(' '));
    one = one.simplified();
    return one.left(220);
}

} // namespace

CliphistWatcher::CliphistWatcher(clavis::store::ClipboardDao* dao,
                                 const QString& cacheDir, QObject* parent)
    : QObject(parent), m_dao(dao), m_cacheDir(cacheDir) {}

void CliphistWatcher::start() {
    ensureCacheDir();
    if (!m_timer) {
        m_timer = new QTimer(this);
        m_timer->setInterval(m_intervalMs);
        connect(m_timer, &QTimer::timeout, this, &CliphistWatcher::tick);
    }
    m_timer->start();
    QMetaObject::invokeMethod(this, &CliphistWatcher::tick, Qt::QueuedConnection);
}

void CliphistWatcher::stop() {
    if (m_timer) m_timer->stop();
}

bool CliphistWatcher::ensureCacheDir() const {
    QDir d;
    return d.mkpath(m_cacheDir);
}

// cliphist list 输出每行 "<id>\t<preview>"，preview 可能含 [[ binary data ... ]] 提示
QSet<qint64> CliphistWatcher::listCurrent(QHash<qint64, QString>* previewByIdOut) const {
    QSet<qint64> ids;
    int rc = 0;
    QByteArray out = runCliphist({QStringLiteral("list")}, {}, &rc);
    if (rc != 0) return ids;

    static const QRegularExpression re(QStringLiteral(R"(^\s*(\d+)\s+(.*)$)"));
    const auto lines = QString::fromUtf8(out).split(QLatin1Char('\n'), Qt::SkipEmptyParts);
    for (const QString& raw : lines) {
        QString line = raw;
        if (line.startsWith(QChar(0x2502))) line = line.mid(1).trimmed(); // '│'
        auto m = re.match(line);
        if (!m.hasMatch()) continue;
        bool ok = false;
        qint64 id = m.captured(1).toLongLong(&ok);
        if (!ok) continue;
        ids.insert(id);
        if (previewByIdOut) previewByIdOut->insert(id, m.captured(2).trimmed());
    }
    return ids;
}

bool CliphistWatcher::decodeAndPersist(qint64 id, const QString& previewLine) {
    int rc = 0;
    // 先按 id 解码（cliphist 兼容）
    QByteArray decoded = runCliphist({QStringLiteral("decode")},
                                     (QString::number(id) + QChar('\n')).toUtf8(),
                                     &rc, 6000);
    if (rc != 0 || decoded.isEmpty()) {
        // 回退：完整 list 行作为 stdin
        QString fallback = QString::number(id) + QLatin1Char('\t') + previewLine;
        decoded = runCliphist({QStringLiteral("decode")},
                              (fallback + QChar('\n')).toUtf8(), &rc, 6000);
    }
    if (decoded.isEmpty()) return false;

    ClipboardEntry e;
    e.id = id;
    e.bytes = decoded.size();
    e.createdAt = QDateTime::currentMSecsSinceEpoch();

    const QString hint = hintImageKind(previewLine);
    const QString magic = detectImageKind(decoded);

    // (1) 真二进制图片
    if (!hint.isEmpty() || !magic.isEmpty()) {
        const QString kind = !magic.isEmpty() ? magic : hint;
        const QString digest = QString::fromLatin1(
            QCryptographicHash::hash(decoded, QCryptographicHash::Sha1).toHex().left(20));
        const QString ext = extForKind(kind);
        const QString blob = m_cacheDir + QLatin1Char('/') + digest + QLatin1Char('.') + ext;
        if (!QFileInfo::exists(blob)) {
            QFile f(blob);
            if (!f.open(QIODevice::WriteOnly)) return false;
            f.write(decoded);
            f.close();
        }
        e.kind        = QStringLiteral("image");
        e.mime        = QStringLiteral("image/") + kind;
        e.textPreview = normalizePreview(previewLine);
        e.sha256      = digest;
        e.blobPath    = blob;
        e.pasteMime   = e.mime;
        return m_dao->upsert(e);
    }

    // 解码为文本
    auto dec = QStringDecoder(QStringDecoder::Utf8, QStringDecoder::Flag::Stateless);
    QString text = dec.decode(decoded);
    if (dec.hasError()) {
        // 替换性解码
        text = QString::fromUtf8(decoded);
    }

    // (2) HTML 富文本含本地图片（QQ 等）
    QString htmlImg = extractHtmlImagePath(text);
    if (!htmlImg.isEmpty() && QFile::exists(htmlImg)) {
        QFile srcF(htmlImg);
        if (srcF.open(QIODevice::ReadOnly)) {
            QByteArray srcBytes = srcF.readAll();
            srcF.close();
            QString k = detectImageKind(srcBytes);
            if (k.isEmpty()) {
                QString suf = QFileInfo(htmlImg).suffix().toLower();
                k = suf.isEmpty() ? QStringLiteral("png") : suf;
                if (k == QLatin1String("jpg")) k = QStringLiteral("jpeg");
            }
            const QString digest = QString::fromLatin1(
                QCryptographicHash::hash(srcBytes, QCryptographicHash::Sha1).toHex().left(20));
            const QString ext = extForKind(k);
            const QString blob = m_cacheDir + QLatin1Char('/') + digest + QLatin1Char('.') + ext;
            if (!QFileInfo::exists(blob)) {
                QFile out(blob);
                if (out.open(QIODevice::WriteOnly)) { out.write(srcBytes); out.close(); }
            }
            e.kind        = QStringLiteral("image");
            e.mime        = QStringLiteral("image/") + k;
            e.textPreview = QStringLiteral("[图片] ") + QFileInfo(htmlImg).fileName();
            e.sha256      = digest;
            e.blobPath    = blob;
            e.pasteMime   = QStringLiteral("text/html");
            e.pasteHtml   = QStringLiteral("<img src=\"file://") + htmlImg + QStringLiteral("\">");
            return m_dao->upsert(e);
        }
    }

    // (3) 看起来是二进制但识别不出 → unknown，避免渲染乱码
    if (looksBinary(decoded)) {
        e.kind = QStringLiteral("unknown");
        e.textPreview = previewLine.isEmpty()
            ? QStringLiteral("[二进制 %1 字节]").arg(decoded.size())
            : normalizePreview(previewLine);
        return m_dao->upsert(e);
    }

    // (4) 真文本（如果是 HTML 片段则剥成纯文本）
    text.replace(QChar('\0'), QChar(' '));
    QString head = text.trimmed().left(32).toLower();
    if (head.startsWith(QLatin1String("<html"))
        || head.startsWith(QLatin1String("<body"))
        || head.startsWith(QLatin1String("<!doctype"))) {
        text = stripHtmlToPlain(text);
    }
    if (text.trimmed().isEmpty()) text = previewLine;

    e.kind        = QStringLiteral("text");
    e.mime        = QStringLiteral("text/plain");
    e.textPreview = normalizePreview(text);
    e.pasteMime   = QStringLiteral("text/plain");
    return m_dao->upsert(e);
}

void CliphistWatcher::tick() {
    if (!m_dao) return;
    QHash<qint64, QString> previews;
    auto current = listCurrent(&previews);
    if (current.isEmpty()) {
        // cliphist 异常或为空；不要清表（可能只是临时失败）
        return;
    }
    auto known = m_dao->existingIds();

    bool changed = false;

    // 同步删除：DB 有但 cliphist 没了
    for (auto it = known.begin(); it != known.end(); ++it) {
        if (!current.contains(*it)) {
            if (m_dao->remove(*it)) changed = true;
        }
    }

    // 新增
    QList<qint64> news;
    for (auto it = current.begin(); it != current.end(); ++it) {
        if (!known.contains(*it)) news.append(*it);
    }
    std::sort(news.begin(), news.end()); // 升序，便于按入库顺序处理
    for (qint64 id : news) {
        if (decodeAndPersist(id, previews.value(id))) changed = true;
    }

    if (changed) emit entriesUpdated();
}

} // namespace clavis::ipc
