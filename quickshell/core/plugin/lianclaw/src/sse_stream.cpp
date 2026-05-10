#include "sse_stream.h"

#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QJsonDocument>
#include <QJsonObject>
#include <QUrl>
#include <QUrlQuery>
#include <QDebug>

SseStream::SseStream(QNetworkAccessManager* nam, QObject* parent)
    : QObject(parent), m_nam(nam) {
    m_reconnectTimer.setSingleShot(true);
    connect(&m_reconnectTimer, &QTimer::timeout, this, &SseStream::onReconnectTimer);
}

void SseStream::start(const QString& serverBase, const QString& sessionId, qint64 afterSeq) {
    stop(QStringLiteral("restart"));
    m_serverBase = serverBase;
    m_sessionId = sessionId;
    m_lastSeq = afterSeq;
    m_active = true;
    m_reconnectAttempt = 0;
    connectOnce();
}

void SseStream::stop(const QString& reason) {
    m_reconnectTimer.stop();
    m_active = false;
    if (m_reply) {
        QNetworkReply* r = m_reply;
        m_reply = nullptr;
        disconnect(r, nullptr, this, nullptr);
        r->abort();
        r->deleteLater();
    }
    if (m_haveOpened) {
        m_haveOpened = false;
        emit closed(reason);
    }
    m_buffer.clear();
    m_currentEvent.clear();
    m_currentData.clear();
}

void SseStream::connectOnce() {
    if (!m_active || m_serverBase.isEmpty() || m_sessionId.isEmpty()) return;

    QUrl url(m_serverBase + "/sessions/" + m_sessionId + "/events");
    QUrlQuery q;
    q.addQueryItem("after", QString::number(m_lastSeq));
    url.setQuery(q);

    QNetworkRequest req(url);
    req.setRawHeader("Accept", "text/event-stream");
    req.setRawHeader("Cache-Control", "no-cache");
    req.setAttribute(QNetworkRequest::HttpPipeliningAllowedAttribute, false);

    m_reply = m_nam->get(req);
    connect(m_reply, &QNetworkReply::readyRead, this, &SseStream::onReadyRead);
    connect(m_reply, &QNetworkReply::finished, this, &SseStream::onFinished);
    connect(m_reply, &QNetworkReply::metaDataChanged, this, &SseStream::onConnected);
}

void SseStream::onConnected() {
    if (!m_reply || m_haveOpened) return;
    int status = m_reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    if (status >= 200 && status < 300) {
        m_haveOpened = true;
        m_reconnectAttempt = 0;
        emit opened();
    }
}

void SseStream::onReadyRead() {
    if (!m_reply) return;
    m_buffer.append(m_reply->readAll());
    int idx;
    while ((idx = m_buffer.indexOf('\n')) != -1) {
        QByteArray line = m_buffer.left(idx);
        m_buffer.remove(0, idx + 1);
        if (!line.isEmpty() && line.endsWith('\r')) line.chop(1);
        handleLine(line);
    }
}

void SseStream::handleLine(const QByteArray& line) {
    if (line.isEmpty()) {
        // event boundary
        dispatchEvent();
        return;
    }
    if (line.startsWith(':')) {
        // comment / heartbeat — ignore
        return;
    }
    int sep = line.indexOf(':');
    QByteArray field, value;
    if (sep < 0) {
        field = line;
    } else {
        field = line.left(sep);
        value = line.mid(sep + 1);
        if (value.startsWith(' ')) value.remove(0, 1);
    }
    if (field == "event") {
        m_currentEvent = value;
    } else if (field == "data") {
        if (!m_currentData.isEmpty()) m_currentData.append('\n');
        m_currentData.append(value);
    } else if (field == "id") {
        // Last-Event-ID semantics; we use seq from envelope instead, but record it
        bool ok = false;
        qint64 sid = QString::fromUtf8(value).toLongLong(&ok);
        if (ok && sid > m_lastSeq) {
            m_lastSeq = sid;
            emit lastSeqChanged(m_lastSeq);
        }
    }
    // ignore "retry:" — we handle backoff ourselves
}

void SseStream::dispatchEvent() {
    if (m_currentData.isEmpty()) {
        m_currentEvent.clear();
        return;
    }
    QJsonParseError err;
    QJsonDocument doc = QJsonDocument::fromJson(m_currentData, &err);
    m_currentData.clear();
    QByteArray evName = m_currentEvent;
    m_currentEvent.clear();

    if (err.error != QJsonParseError::NoError || !doc.isObject()) {
        return;
    }
    QVariantMap env = doc.object().toVariantMap();
    bool ok = false;
    qint64 seq = env.value("seq").toLongLong(&ok);
    if (ok && seq > m_lastSeq) {
        m_lastSeq = seq;
        emit lastSeqChanged(m_lastSeq);
    }
    emit envelope(env);
    Q_UNUSED(evName);
}

void SseStream::onFinished() {
    if (!m_reply) return;
    QNetworkReply::NetworkError err = m_reply->error();
    QString errStr = m_reply->errorString();
    m_reply->deleteLater();
    m_reply = nullptr;

    if (m_haveOpened) {
        m_haveOpened = false;
        emit closed(errStr.isEmpty() ? QStringLiteral("eof") : errStr);
    }

    if (m_active) {
        scheduleReconnect();
    }
    Q_UNUSED(err);
}

void SseStream::scheduleReconnect() {
    static const int delays[] = {1000, 2000, 3000, 5000, 8000};
    int n = sizeof(delays) / sizeof(delays[0]);
    int idx = m_reconnectAttempt < n ? m_reconnectAttempt : n - 1;
    int delay = delays[idx];
    m_reconnectAttempt++;
    m_reconnectTimer.start(delay);
}

void SseStream::onReconnectTimer() {
    if (m_active) connectOnce();
}
