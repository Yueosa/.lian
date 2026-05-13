#include "lianwall_plugin.h"

#include <QCoreApplication>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QUrl>

namespace {
QString jsonString(const QJsonObject &obj, const QString &key, const QString &fallback = {})
{
    const auto value = obj.value(key);
    if (value.isNull() || value.isUndefined())
        return fallback;
    return value.toString(fallback);
}

int jsonInt(const QJsonObject &obj, const QString &key, int fallback = 0)
{
    const auto value = obj.value(key);
    if (value.isNull() || value.isUndefined())
        return fallback;
    return value.toInt(fallback);
}
}

LianwallPlugin::LianwallPlugin(QObject *parent)
    : QObject(parent)
    , m_wallpapers(this)
{
    m_tickTimer.setInterval(1000);
    connect(&m_tickTimer, &QTimer::timeout, this, [this]() {
        if (m_displaySecs > 0) {
            --m_displaySecs;
            emit countdownChanged();
        } else if (m_displaySecs == 0) {
            scheduleRefresh();
        }
    });
    m_tickTimer.start();

    m_refreshDebounce.setSingleShot(true);
    m_refreshDebounce.setInterval(350);
    connect(&m_refreshDebounce, &QTimer::timeout, this, &LianwallPlugin::refresh);

    QTimer::singleShot(0, this, [this]() {
        refresh();
        startSubscribe();
    });
}

LianwallPlugin::~LianwallPlugin()
{
    const auto processes = findChildren<QProcess *>();
    for (auto *process : processes) {
        if (!process)
            continue;
        process->disconnect(this);
        if (process->state() != QProcess::NotRunning) {
            process->kill();
            process->waitForFinished(1000);
        }
    }
}

bool LianwallPlugin::loading() const { return m_pendingCommands > 0; }
bool LianwallPlugin::hasData() const { return m_hasData; }
QString LianwallPlugin::mode() const { return m_mode; }
QString LianwallPlugin::modeLabel() const { return m_mode == QStringLiteral("Video") ? QStringLiteral("视频") : QStringLiteral("图片"); }
QString LianwallPlugin::modeIcon() const { return m_mode == QStringLiteral("Video") ? QStringLiteral("") : QStringLiteral(""); }
QString LianwallPlugin::currentPath() const { return m_currentPath; }
QString LianwallPlugin::currentFilename() const { return m_currentFilename; }
QString LianwallPlugin::engine() const { return m_engine; }
int LianwallPlugin::totalWallpapers() const { return m_totalWallpapers; }
int LianwallPlugin::availableCount() const { return m_availableCount; }
int LianwallPlugin::lockedCount() const { return m_lockedCount; }
int LianwallPlugin::nextSwitchSecs() const { return m_nextSwitchSecs; }
int LianwallPlugin::displaySecs() const { return m_displaySecs; }
int LianwallPlugin::intervalSecs() const { return activeIntervalSecs(); }
double LianwallPlugin::progress() const
{
    const int interval = activeIntervalSecs();
    if (interval <= 0 || m_displaySecs < 0)
        return 0.0;
    return qBound(0.0, static_cast<double>(m_displaySecs) / static_cast<double>(interval), 1.0);
}
QString LianwallPlugin::error() const { return m_error; }
LianwallListModel *LianwallPlugin::wallpapers() { return &m_wallpapers; }

void LianwallPlugin::refresh()
{
    refreshStatus();
    refreshSpace();
    refreshIntervals();
}

void LianwallPlugin::next()
{
    runAction({ QStringLiteral("--json"), QStringLiteral("next") });
}

void LianwallPlugin::previous()
{
    runAction({ QStringLiteral("--json"), QStringLiteral("prev") });
}

void LianwallPlugin::switchMode()
{
    runAction({ QStringLiteral("--json"), QStringLiteral("switch") });
}

void LianwallPlugin::openGui()
{
    QProcess::startDetached(QStringLiteral("lianwall-gui"), {});
}

void LianwallPlugin::setWallpaper(const QString &path)
{
    if (path.isEmpty())
        return;
    runAction({ QStringLiteral("--json"), QStringLiteral("set"), path });
}

QString LianwallPlugin::formatDuration(int secs) const
{
    if (secs < 0)
        return QStringLiteral("--:--");

    const int hours = secs / 3600;
    const int minutes = (secs % 3600) / 60;
    const int seconds = secs % 60;
    if (hours > 0)
        return QStringLiteral("%1:%2:%3")
            .arg(hours)
            .arg(minutes, 2, 10, QLatin1Char('0'))
            .arg(seconds, 2, 10, QLatin1Char('0'));
    return QStringLiteral("%1:%2")
        .arg(minutes, 2, 10, QLatin1Char('0'))
        .arg(seconds, 2, 10, QLatin1Char('0'));
}

void LianwallPlugin::refreshStatus()
{
    runCommand({ QStringLiteral("--json"), QStringLiteral("status") }, [this](const QJsonObject &obj) {
        parseStatus(obj);
    });
}

void LianwallPlugin::refreshSpace()
{
    runCommand({ QStringLiteral("--json"), QStringLiteral("space") }, [this](const QJsonObject &obj) {
        parseSpace(obj);
    });
}

void LianwallPlugin::refreshIntervals()
{
    runCommand({ QStringLiteral("--json"), QStringLiteral("config"), QStringLiteral("get"), QStringLiteral("image_engine.interval") },
               [this](const QJsonObject &obj) { parseConfigValue(obj); });
    runCommand({ QStringLiteral("--json"), QStringLiteral("config"), QStringLiteral("get"), QStringLiteral("video_engine.interval") },
               [this](const QJsonObject &obj) { parseConfigValue(obj); });
}

void LianwallPlugin::runCommand(const QStringList &args, JsonCallback callback)
{
    auto *process = new QProcess(this);
    process->setProgram(QStringLiteral("lianwall"));
    process->setArguments(args);
    process->setProcessChannelMode(QProcess::SeparateChannels);

    setPendingDelta(1);

    connect(process, &QProcess::finished, this, [this, process, callback](int exitCode, QProcess::ExitStatus exitStatus) {
        const QByteArray stdoutData = process->readAllStandardOutput();
        const QByteArray stderrData = process->readAllStandardError();
        process->deleteLater();
        setPendingDelta(-1);

        if (exitStatus != QProcess::NormalExit || exitCode != 0) {
            setError(QString::fromUtf8(stderrData).trimmed());
            return;
        }

        QJsonParseError parseError;
        const QJsonDocument doc = QJsonDocument::fromJson(stdoutData, &parseError);
        if (parseError.error != QJsonParseError::NoError || !doc.isObject()) {
            setError(parseError.errorString());
            return;
        }

        setError(QString());
        if (callback)
            callback(doc.object());
    });

    connect(process, &QProcess::errorOccurred, this, [this, process](QProcess::ProcessError) {
        setError(process->errorString());
    });

    process->start();
}

void LianwallPlugin::runAction(const QStringList &args)
{
    runCommand(args, [this](const QJsonObject &obj) {
        if (obj.value(QStringLiteral("success")).toBool(false) || obj.value(QStringLiteral("status")).toString() == QStringLiteral("ok")) {
            scheduleRefresh();
        } else if (obj.contains(QStringLiteral("error"))) {
            setError(obj.value(QStringLiteral("error")).toString());
        } else {
            scheduleRefresh();
        }
    });
}

void LianwallPlugin::startSubscribe()
{
    if (m_subscribeProcess && m_subscribeProcess->state() != QProcess::NotRunning)
        return;

    auto *process = new QProcess(this);
    m_subscribeProcess = process;
    process->setProgram(QStringLiteral("lianwall"));
    process->setArguments({ QStringLiteral("subscribe"), QStringLiteral("--json"), QStringLiteral("wallpaper"),
                            QStringLiteral("status"), QStringLiteral("space"), QStringLiteral("time"), QStringLiteral("error") });
    process->setProcessChannelMode(QProcess::SeparateChannels);

    connect(process, &QProcess::readyReadStandardOutput, this, [this, process]() {
        while (process->canReadLine()) {
            const QByteArray line = process->readLine().trimmed();
            if (!line.isEmpty())
                scheduleRefresh();
        }
    });
    connect(process, &QProcess::finished, this, [this, process](int, QProcess::ExitStatus) {
        if (m_subscribeProcess == process)
            m_subscribeProcess = nullptr;
        process->deleteLater();
        QTimer::singleShot(5000, this, &LianwallPlugin::startSubscribe);
    });
    process->start();
}

void LianwallPlugin::scheduleRefresh()
{
    m_refreshDebounce.start();
}

void LianwallPlugin::parseStatus(const QJsonObject &obj)
{
    m_hasData = true;
    m_mode = jsonString(obj, QStringLiteral("mode"), m_mode);
    m_currentPath = jsonString(obj, QStringLiteral("current"), jsonString(obj, QStringLiteral("current_wallpaper"), m_currentPath));
    m_currentFilename = jsonString(obj, QStringLiteral("current_filename"), QFileInfo(m_currentPath).fileName());
    m_engine = jsonString(obj, QStringLiteral("engine"), m_engine);
    m_totalWallpapers = jsonInt(obj, QStringLiteral("total_wallpapers"), m_totalWallpapers);
    m_availableCount = jsonInt(obj, QStringLiteral("available_count"), m_availableCount);
    m_lockedCount = jsonInt(obj, QStringLiteral("locked_count"), m_lockedCount);

    const auto nextValue = obj.value(QStringLiteral("next_switch_secs"));
    m_nextSwitchSecs = nextValue.isNull() || nextValue.isUndefined() ? -1 : nextValue.toInt(-1);
    m_displaySecs = m_nextSwitchSecs;

    emit dataChanged();
    emit countdownChanged();
}

void LianwallPlugin::parseSpace(const QJsonObject &obj)
{
    const auto itemsValue = obj.value(QStringLiteral("items"));
    if (!itemsValue.isArray())
        return;

    QList<LianwallItem> items;
    const auto array = itemsValue.toArray();
    items.reserve(array.size());
    for (const auto &value : array) {
        const auto itemObj = value.toObject();
        LianwallItem item;
        item.index = jsonInt(itemObj, QStringLiteral("index"));
        item.filename = jsonString(itemObj, QStringLiteral("filename"));
        item.path = jsonString(itemObj, QStringLiteral("path"));
        item.angle = itemObj.value(QStringLiteral("angle")).toDouble(0.0);
        item.locked = itemObj.value(QStringLiteral("locked")).toBool(false);
        item.inCooldown = itemObj.value(QStringLiteral("in_cooldown")).toBool(false);
        item.isCurrent = itemObj.value(QStringLiteral("is_current")).toBool(false);
        items.push_back(item);
    }

    m_wallpapers.setItems(std::move(items));
    emit dataChanged();
}

void LianwallPlugin::parseConfigValue(const QJsonObject &obj)
{
    const QString key = obj.value(QStringLiteral("key")).toString();
    const int value = obj.value(QStringLiteral("value")).toInt(600);
    if (key == QStringLiteral("image_engine.interval"))
        m_imageIntervalSecs = value;
    else if (key == QStringLiteral("video_engine.interval"))
        m_videoIntervalSecs = value;
    emit countdownChanged();
}

void LianwallPlugin::setError(const QString &error)
{
    if (m_error == error)
        return;
    m_error = error;
    emit errorChanged();
}

void LianwallPlugin::setPendingDelta(int delta)
{
    const bool wasLoading = loading();
    m_pendingCommands = qMax(0, m_pendingCommands + delta);
    if (wasLoading != loading())
        emit loadingChanged();
}

int LianwallPlugin::activeIntervalSecs() const
{
    return m_mode == QStringLiteral("Video") ? m_videoIntervalSecs : m_imageIntervalSecs;
}