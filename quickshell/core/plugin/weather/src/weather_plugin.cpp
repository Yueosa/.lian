#include "weather_plugin.h"

#include <cmath>
#include <QtGlobal>

WeatherPlugin::WeatherPlugin(QObject *parent)
    : QObject(parent),
      m_backend(this),
      m_hourly(this),
      m_daily(this),
      m_dailyTrend(this),
      m_minutely(this)
{
    connect(&m_backend, &WeatherBackend::snapshotChanged, this, [this]() {
        syncModels();
        emit dataChanged();
    });
    connect(&m_backend, &WeatherBackend::loadingChanged, this, &WeatherPlugin::loadingChanged);
    syncModels();
}

bool WeatherPlugin::loading() const { return m_backend.loading(); }
bool WeatherPlugin::hasValidData() const { return m_backend.snapshot().valid; }
QString WeatherPlugin::status() const { return m_backend.snapshot().status; }
QString WeatherPlugin::locationName() const { return m_backend.snapshot().locationName; }
double WeatherPlugin::latitude() const { return m_backend.snapshot().latitude; }
double WeatherPlugin::longitude() const { return m_backend.snapshot().longitude; }
QString WeatherPlugin::lastUpdated() const { return m_backend.snapshot().lastUpdated.toString(Qt::ISODate); }

double WeatherPlugin::currentTemperatureC() const { return currentValue("temperatureC", 0.0).toDouble(); }
double WeatherPlugin::currentFeelsLikeC() const { return currentValue("feelsLikeC", currentTemperatureC()).toDouble(); }
int WeatherPlugin::currentWeatherCode() const { return currentValue("weatherCode", -1).toInt(); }
QString WeatherPlugin::currentWeatherText() const { return currentValue("weatherText", "Unknown").toString(); }
QString WeatherPlugin::currentIconName() const { return currentValue("iconName", "cloud").toString(); }
double WeatherPlugin::currentWindSpeedMs() const { return currentValue("windSpeedMs", 0.0).toDouble(); }
double WeatherPlugin::currentWindDirection() const { return currentValue("windDirection", 0.0).toDouble(); }
double WeatherPlugin::currentWindGustsMs() const { return currentValue("windGustsMs", 0.0).toDouble(); }
double WeatherPlugin::currentUvIndex() const { return currentValue("uvIndex", 0.0).toDouble(); }
double WeatherPlugin::currentRelativeHumidity() const { return currentValue("relativeHumidity", 0.0).toDouble(); }
double WeatherPlugin::currentDewPointC() const { return currentValue("dewPointC", 0.0).toDouble(); }
double WeatherPlugin::currentPressureHpa() const { return currentValue("pressureHpa", 0.0).toDouble(); }
double WeatherPlugin::currentCloudCover() const { return currentValue("cloudCover", 0.0).toDouble(); }
double WeatherPlugin::currentVisibilityM() const { return currentValue("visibilityM", 0.0).toDouble(); }
QVariantMap WeatherPlugin::currentAirQuality() const { return currentValue("airQuality").toMap(); }

WeatherListModel* WeatherPlugin::hourlyForecast() { return &m_hourly; }
WeatherListModel* WeatherPlugin::dailyForecast() { return &m_daily; }
WeatherListModel* WeatherPlugin::dailyTrendForecast() { return &m_dailyTrend; }
WeatherListModel* WeatherPlugin::minutelyForecast() { return &m_minutely; }

void WeatherPlugin::refresh() { m_backend.refresh(); }
void WeatherPlugin::setManualLocation(double latitude, double longitude, const QString &name) { m_backend.setManualLocation(latitude, longitude, name); }
void WeatherPlugin::clearManualLocation() { m_backend.clearManualLocation(); }
QVariantMap WeatherPlugin::current() const { return m_backend.snapshot().current; }
QVariantMap WeatherPlugin::makeQuadraticSamples(double startX,
                                                double startY,
                                                double controlX,
                                                double controlY,
                                                double endX,
                                                double endY,
                                                int steps) const {
    const int safeSteps = qMax(1, steps);
    QVariantList points;
    points.reserve(safeSteps + 1);

    QVariantMap first;
    first.insert(QStringLiteral("x"), startX);
    first.insert(QStringLiteral("y"), startY);
    first.insert(QStringLiteral("len"), 0.0);
    points.push_back(first);

    double prevX = startX;
    double prevY = startY;
    double totalLength = 0.0;

    for (int i = 1; i <= safeSteps; ++i) {
        const double t = static_cast<double>(i) / safeSteps;
        const double inv = 1.0 - t;
        const double x = inv * inv * startX + 2.0 * inv * t * controlX + t * t * endX;
        const double y = inv * inv * startY + 2.0 * inv * t * controlY + t * t * endY;
        const double dx = x - prevX;
        const double dy = y - prevY;
        totalLength += std::sqrt(dx * dx + dy * dy);

        QVariantMap point;
        point.insert(QStringLiteral("x"), x);
        point.insert(QStringLiteral("y"), y);
        point.insert(QStringLiteral("len"), totalLength);
        points.push_back(point);

        prevX = x;
        prevY = y;
    }

    QVariantMap result;
    result.insert(QStringLiteral("points"), points);
    result.insert(QStringLiteral("totalLength"), totalLength);
    return result;
}

QVariant WeatherPlugin::currentValue(const QString &key, const QVariant &fallback) const {
    return m_backend.snapshot().current.value(key, fallback);
}

void WeatherPlugin::syncModels() {
    const auto &snapshot = m_backend.snapshot();
    m_hourly.setItems(snapshot.hourly);
    m_daily.setItems(snapshot.daily);
    m_dailyTrend.setItems(snapshot.dailyTrend);
    m_minutely.setItems(snapshot.minutely);
}
