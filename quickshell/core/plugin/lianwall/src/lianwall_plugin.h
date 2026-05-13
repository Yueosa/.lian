#pragma once

#include "lianwall_list_model.h"

#include <QJsonObject>
#include <QObject>
#include <QPointer>
#include <QProcess>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

#include <functional>

class LianwallPlugin : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)
    Q_PROPERTY(bool hasData READ hasData NOTIFY dataChanged)
    Q_PROPERTY(QString mode READ mode NOTIFY dataChanged)
    Q_PROPERTY(QString modeLabel READ modeLabel NOTIFY dataChanged)
    Q_PROPERTY(QString modeIcon READ modeIcon NOTIFY dataChanged)
    Q_PROPERTY(QString currentPath READ currentPath NOTIFY dataChanged)
    Q_PROPERTY(QString currentFilename READ currentFilename NOTIFY dataChanged)
    Q_PROPERTY(QString engine READ engine NOTIFY dataChanged)
    Q_PROPERTY(int totalWallpapers READ totalWallpapers NOTIFY dataChanged)
    Q_PROPERTY(int availableCount READ availableCount NOTIFY dataChanged)
    Q_PROPERTY(int lockedCount READ lockedCount NOTIFY dataChanged)
    Q_PROPERTY(int nextSwitchSecs READ nextSwitchSecs NOTIFY countdownChanged)
    Q_PROPERTY(int displaySecs READ displaySecs NOTIFY countdownChanged)
    Q_PROPERTY(int intervalSecs READ intervalSecs NOTIFY countdownChanged)
    Q_PROPERTY(double progress READ progress NOTIFY countdownChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)
    Q_PROPERTY(LianwallListModel* wallpapers READ wallpapers CONSTANT)

public:
    explicit LianwallPlugin(QObject *parent = nullptr);
    ~LianwallPlugin() override;

    bool loading() const;
    bool hasData() const;
    QString mode() const;
    QString modeLabel() const;
    QString modeIcon() const;
    QString currentPath() const;
    QString currentFilename() const;
    QString engine() const;
    int totalWallpapers() const;
    int availableCount() const;
    int lockedCount() const;
    int nextSwitchSecs() const;
    int displaySecs() const;
    int intervalSecs() const;
    double progress() const;
    QString error() const;
    LianwallListModel *wallpapers();

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void next();
    Q_INVOKABLE void previous();
    Q_INVOKABLE void switchMode();
    Q_INVOKABLE void openGui();
    Q_INVOKABLE void setWallpaper(const QString &path);
    Q_INVOKABLE QString formatDuration(int secs) const;

signals:
    void dataChanged();
    void loadingChanged();
    void countdownChanged();
    void errorChanged();

private:
    using JsonCallback = std::function<void(const QJsonObject &)>;

    LianwallListModel m_wallpapers;
    QTimer m_tickTimer;
    QTimer m_refreshDebounce;
    QPointer<QProcess> m_subscribeProcess;

    int m_pendingCommands = 0;
    bool m_hasData = false;
    QString m_mode = QStringLiteral("Image");
    QString m_currentPath;
    QString m_currentFilename;
    QString m_engine;
    QString m_error;
    int m_totalWallpapers = 0;
    int m_availableCount = 0;
    int m_lockedCount = 0;
    int m_nextSwitchSecs = -1;
    int m_displaySecs = -1;
    int m_imageIntervalSecs = 600;
    int m_videoIntervalSecs = 600;

    void refreshStatus();
    void refreshSpace();
    void refreshIntervals();
    void runCommand(const QStringList &args, JsonCallback callback = {});
    void runAction(const QStringList &args);
    void startSubscribe();
    void scheduleRefresh();
    void parseStatus(const QJsonObject &obj);
    void parseSpace(const QJsonObject &obj);
    void parseConfigValue(const QJsonObject &obj);
    void setError(const QString &error);
    void setPendingDelta(int delta);
    int activeIntervalSecs() const;
};