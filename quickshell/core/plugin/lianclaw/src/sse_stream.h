#pragma once

#include <QObject>
#include <QByteArray>
#include <QString>
#include <QTimer>
#include <QPointer>

class QNetworkAccessManager;
class QNetworkReply;

// One-session SSE consumer for LianClaw.
// Handles line buffering, comment skipping, "event: lc" + "data: {json}" framing,
// auto-reconnect with backoff, and lastSeq tracking.
class SseStream : public QObject {
    Q_OBJECT
public:
    explicit SseStream(QNetworkAccessManager* nam, QObject* parent = nullptr);

    void start(const QString& serverBase, const QString& sessionId, qint64 afterSeq);
    void stop(const QString& reason = QStringLiteral("manual"));

    bool isActive() const { return m_active; }
    qint64 lastSeq() const { return m_lastSeq; }
    QString sessionId() const { return m_sessionId; }

signals:
    void opened();
    void closed(const QString& reason);
    void envelope(const QVariantMap& env);
    void lastSeqChanged(qint64 seq);

private slots:
    void onReadyRead();
    void onFinished();
    void onConnected();
    void onReconnectTimer();

private:
    void connectOnce();
    void scheduleReconnect();
    void handleLine(const QByteArray& line);
    void dispatchEvent();

    QNetworkAccessManager* m_nam;
    QPointer<QNetworkReply> m_reply;
    QTimer m_reconnectTimer;

    QString m_serverBase;
    QString m_sessionId;
    qint64 m_lastSeq = 0;
    bool m_active = false;
    bool m_haveOpened = false;
    int m_reconnectAttempt = 0;

    QByteArray m_buffer;
    QByteArray m_currentEvent;   // event: name
    QByteArray m_currentData;    // accumulated data: lines
};
