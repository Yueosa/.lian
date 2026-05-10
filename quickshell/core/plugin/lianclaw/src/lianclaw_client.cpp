#include "lianclaw_client.h"
#include "sse_stream.h"

#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonObject>
#include <QFile>
#include <QDir>
#include <QStandardPaths>
#include <QUrl>
#include <QUrlQuery>
#include <QDebug>

LianClawClient::LianClawClient(QObject* parent)
    : QObject(parent),
      m_nam(new QNetworkAccessManager(this)),
      m_stream(new SseStream(m_nam, this)) {
    connect(m_stream, &SseStream::envelope, this, &LianClawClient::envelope);
    connect(m_stream, &SseStream::opened, this, [this]{
        emit streamStateChanged();
        emit streamOpened();
    });
    connect(m_stream, &SseStream::closed, this, [this](const QString& r){
        emit streamStateChanged();
        emit streamClosed(r);
    });
    connect(m_stream, &SseStream::lastSeqChanged, this, [this](qint64){
        emit lastSeqChanged();
    });

    // kick off auto-resolve at construction
    resolveServerBase();
}

bool LianClawClient::streamActive() const { return m_stream && m_stream->isActive(); }
QString LianClawClient::streamSessionId() const { return m_stream ? m_stream->sessionId() : QString(); }
qint64 LianClawClient::lastSeq() const { return m_stream ? m_stream->lastSeq() : 0; }

void LianClawClient::setServerBase(const QString& base) {
    if (m_serverBase == base) return;
    m_serverBase = base;
    emit serverBaseChanged();
}

void LianClawClient::setLastError(const QString& err) {
    if (m_lastError == err) return;
    m_lastError = err;
    emit lastErrorChanged();
}

void LianClawClient::resolveServerBase() {
    // 1. Try ~/.lianclaw/running.json
    QString home = QDir::homePath();
    QString runningPath = home + "/.lianclaw/running.json";
    QFile f(runningPath);
    if (f.open(QIODevice::ReadOnly)) {
        QByteArray raw = f.readAll();
        f.close();
        QJsonParseError err;
        QJsonDocument doc = QJsonDocument::fromJson(raw, &err);
        if (err.error == QJsonParseError::NoError && doc.isObject()) {
            QString surl = doc.object().value("server_url").toString();
            if (!surl.isEmpty()) {
                setServerBase(surl);
                return;
            }
        }
    }

    // 2. Fallback: probe 50516..50525 via /sessions
    m_probeQueue.clear();
    for (int p = 50516; p <= 50525; ++p) {
        m_probeQueue.append(QStringLiteral("http://127.0.0.1:%1").arg(p));
    }
    probeNext();
}

void LianClawClient::probeNext() {
    if (m_probeQueue.isEmpty()) {
        setLastError(QStringLiteral("no LianClaw server found in 50516..50525"));
        setServerBase(QString());
        return;
    }
    QString base = m_probeQueue.takeFirst();
    QNetworkRequest req(QUrl(base + "/sessions?status=all"));
    req.setRawHeader("Accept", "application/json");
    QNetworkReply* reply = m_nam->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply, base]{
        int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        bool ok = (reply->error() == QNetworkReply::NoError) && status >= 200 && status < 500;
        reply->deleteLater();
        if (ok) {
            setServerBase(base);
            setLastError(QString());
        } else {
            probeNext();
        }
    });
}

void LianClawClient::request(const QString& token,
                              const QString& method,
                              const QString& path,
                              const QVariant& body) {
    if (m_serverBase.isEmpty()) {
        emit requestFinished(token, false, 0, QStringLiteral("server not resolved"));
        return;
    }
    QUrl url(m_serverBase + path);
    QNetworkRequest req(url);
    req.setRawHeader("Accept", "application/json");

    QByteArray payload;
    if (body.isValid() && !body.isNull()) {
        // QML JS 对象传到 C++ 后通常是 QJSValue 或 QVariantMap，
        // 严格 typeId 判断会漏掉 QJSValue 路径；统一尝试 toMap，再 fallback 到字符串。
        QVariantMap m;
        if (body.typeId() == QMetaType::QVariantMap) {
            m = body.toMap();
        } else if (body.canConvert<QVariantMap>()) {
            m = body.toMap();
        }
        if (!m.isEmpty()) {
            QJsonDocument doc(QJsonObject::fromVariantMap(m));
            payload = doc.toJson(QJsonDocument::Compact);
            req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
        } else if (body.canConvert<QString>()) {
            QString s = body.toString();
            if (!s.isEmpty()) {
                payload = s.toUtf8();
                req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
            }
        }
        // 即使 payload 为空，对 POST/PUT 也强制带 Content-Type，方便服务端默认值生效
        if (payload.isEmpty() && (method.toUpper() == "POST" || method.toUpper() == "PUT")) {
            req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
            payload = "{}";
        }
    } else if (method.toUpper() == "POST" || method.toUpper() == "PUT") {
        req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
        payload = "{}";
    }

    QString m = method.toUpper();
    QNetworkReply* reply = nullptr;
    if (m == "GET") {
        reply = m_nam->get(req);
    } else if (m == "POST") {
        reply = m_nam->post(req, payload);
    } else if (m == "PUT") {
        reply = m_nam->put(req, payload);
    } else if (m == "DELETE") {
        reply = m_nam->deleteResource(req);
    } else {
        emit requestFinished(token, false, 0, QStringLiteral("unsupported method: %1").arg(method));
        return;
    }

    connect(reply, &QNetworkReply::finished, this, [this, reply, token]{
        int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        QByteArray raw = reply->readAll();
        QString netErr = reply->errorString();
        QNetworkReply::NetworkError nerr = reply->error();
        reply->deleteLater();

        QVariant parsed;
        if (!raw.isEmpty()) {
            QJsonParseError pe;
            QJsonDocument doc = QJsonDocument::fromJson(raw, &pe);
            if (pe.error == QJsonParseError::NoError) {
                parsed = doc.toVariant();
            } else {
                parsed = QString::fromUtf8(raw);
            }
        }
        bool ok = (nerr == QNetworkReply::NoError) && status >= 200 && status < 300;
        if (!ok && parsed.isNull() && nerr != QNetworkReply::NoError) {
            parsed = netErr;
        }
        emit requestFinished(token, ok, status, parsed);
    });
}

void LianClawClient::openStream(const QString& sessionId, qint64 afterSeq) {
    if (m_serverBase.isEmpty() || sessionId.isEmpty()) return;
    m_stream->start(m_serverBase, sessionId, afterSeq);
    emit streamStateChanged();
}

void LianClawClient::closeStream() {
    m_stream->stop(QStringLiteral("manual"));
    emit streamStateChanged();
}

QString LianClawClient::imageProxyUrl(const QString& absPath, int thumb) const {
    if (m_serverBase.isEmpty() || absPath.isEmpty()) return QString();
    // Defensive double-decode: markdown layer may have already %-encoded the path.
    QString decoded = QUrl::fromPercentEncoding(absPath.toUtf8());
    QString encoded = QString::fromUtf8(QUrl::toPercentEncoding(decoded));
    QString url = m_serverBase + "/local-image?path=" + encoded;
    if (thumb > 0) url += "&thumb=" + QString::number(thumb);
    return url;
}
