#pragma once

#include <QObject>
#include <QString>
#include <QVariant>
#include <QtQml/qqmlregistration.h>

class QNetworkAccessManager;
class SseStream;

// QML singleton: Clavis.LianClaw.LianClawClient
//
// Transport layer only — HTTP request/response and SSE envelope passthrough.
// All business logic (sessions, history, message blocks) lives in QML.
class LianClawClient : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QString serverBase READ serverBase NOTIFY serverBaseChanged)
    Q_PROPERTY(bool serverReady READ serverReady NOTIFY serverBaseChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)

    Q_PROPERTY(bool streamActive READ streamActive NOTIFY streamStateChanged)
    Q_PROPERTY(QString streamSessionId READ streamSessionId NOTIFY streamStateChanged)
    Q_PROPERTY(qint64 lastSeq READ lastSeq NOTIFY lastSeqChanged)

public:
    explicit LianClawClient(QObject* parent = nullptr);

    QString serverBase() const { return m_serverBase; }
    bool serverReady() const { return !m_serverBase.isEmpty(); }
    QString lastError() const { return m_lastError; }

    bool streamActive() const;
    QString streamSessionId() const;
    qint64 lastSeq() const;

    // Resolve serverBase from ~/.lianclaw/running.json + port probing.
    // Asynchronous; emits serverBaseChanged when settled.
    Q_INVOKABLE void resolveServerBase();

    // Generic HTTP. method: "GET" | "POST" | "PUT" | "DELETE".
    // body may be a QVariantMap (JSON-encoded), QString (sent raw as utf8),
    // or invalid (no body). token is echoed back in requestFinished so the
    // QML caller can correlate. Emits requestFinished(token, ok, status, parsedBody).
    Q_INVOKABLE void request(const QString& token,
                             const QString& method,
                             const QString& path,
                             const QVariant& body = QVariant());

    // SSE control
    Q_INVOKABLE void openStream(const QString& sessionId, qint64 afterSeq);
    Q_INVOKABLE void closeStream();

    // Build a /local-image proxy URL. absPath is the literal local path
    // possibly already %-encoded (markdown round-trip safe).
    Q_INVOKABLE QString imageProxyUrl(const QString& absPath, int thumb = 0) const;

signals:
    void serverBaseChanged();
    void lastErrorChanged();
    void requestFinished(const QString& token, bool ok, int status, const QVariant& body);
    void envelope(const QVariantMap& env);
    void streamStateChanged();
    void streamOpened();
    void streamClosed(const QString& reason);
    void lastSeqChanged();

private:
    void setServerBase(const QString& base);
    void setLastError(const QString& err);
    void probePortRange();
    void probeNext();

    QNetworkAccessManager* m_nam;
    SseStream* m_stream;

    QString m_serverBase;
    QString m_lastError;

    // probing state
    QStringList m_probeQueue;
};
