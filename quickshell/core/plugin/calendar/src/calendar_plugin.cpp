#include "calendar_plugin.h"

#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocale>

namespace {
QDate parseDate(const QJsonValue &value)
{
    return QDate::fromString(value.toString(), Qt::ISODate);
}

QString joinLabels(const QStringList &labels)
{
    if (labels.isEmpty())
        return {};
    return labels.join(QStringLiteral(" / "));
}
}

CalendarPlugin::CalendarPlugin(QObject *parent)
    : QObject(parent)
    , m_days(this)
    , m_displayYear(QDate::currentDate().year())
    , m_displayMonth(QDate::currentDate().month())
{
    loadData();
    rebuildMonth();
}

int CalendarPlugin::displayYear() const { return m_displayYear; }
int CalendarPlugin::displayMonth() const { return m_displayMonth; }
QString CalendarPlugin::monthTitle() const
{
    return QLocale(QLocale::Chinese, QLocale::China).toString(QDate(m_displayYear, m_displayMonth, 1), QStringLiteral("yyyy年M月"));
}
QString CalendarPlugin::sourceTitle() const { return m_sourceTitle; }
QString CalendarPlugin::sourceUrl() const { return m_sourceUrl; }
QString CalendarPlugin::error() const { return m_error; }
CalendarDayModel *CalendarPlugin::days() { return &m_days; }

void CalendarPlugin::setMonth(int year, int month)
{
    if (month < 1 || month > 12 || year < 1900)
        return;
    if (m_displayYear == year && m_displayMonth == month)
        return;

    m_displayYear = year;
    m_displayMonth = month;
    rebuildMonth();
    emit monthChanged();
}

void CalendarPlugin::previousMonth()
{
    QDate month(m_displayYear, m_displayMonth, 1);
    month = month.addMonths(-1);
    setMonth(month.year(), month.month());
}

void CalendarPlugin::nextMonth()
{
    QDate month(m_displayYear, m_displayMonth, 1);
    month = month.addMonths(1);
    setMonth(month.year(), month.month());
}

void CalendarPlugin::resetToToday()
{
    const QDate today = QDate::currentDate();
    setMonth(today.year(), today.month());
}

void CalendarPlugin::loadData()
{
    QFile file(QStringLiteral(":/Clavis/Calendar/data/cn/2026.json"));
    if (!file.open(QIODevice::ReadOnly)) {
        m_error = file.errorString();
        emit dataChanged();
        return;
    }

    QJsonParseError parseError;
    const QJsonDocument doc = QJsonDocument::fromJson(file.readAll(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !doc.isObject()) {
        m_error = parseError.errorString();
        emit dataChanged();
        return;
    }

    const QJsonObject root = doc.object();
    m_sourceTitle = root.value(QStringLiteral("sourceTitle")).toString();
    m_sourceUrl = root.value(QStringLiteral("sourceUrl")).toString();

    for (const QJsonValue &value : root.value(QStringLiteral("holidays")).toArray()) {
        const QJsonObject item = value.toObject();
        addHolidayRange(item.value(QStringLiteral("name")).toString(),
                        parseDate(item.value(QStringLiteral("start"))),
                        parseDate(item.value(QStringLiteral("end"))));
    }

    for (const QJsonValue &value : root.value(QStringLiteral("workdays")).toArray()) {
        const QJsonObject item = value.toObject();
        addWorkday(item.value(QStringLiteral("name")).toString(), parseDate(item.value(QStringLiteral("date"))));
    }

    for (const QJsonValue &value : root.value(QStringLiteral("festivals")).toArray()) {
        const QJsonObject item = value.toObject();
        addFestival(item.value(QStringLiteral("name")).toString(), parseDate(item.value(QStringLiteral("date"))));
    }

    m_error.clear();
    emit dataChanged();
}

void CalendarPlugin::rebuildMonth()
{
    const QDate monthStart(m_displayYear, m_displayMonth, 1);
    const int startOffset = monthStart.dayOfWeek() - 1;
    QDate cursor = monthStart.addDays(-startOffset);
    const QDate today = QDate::currentDate();

    QList<QVariantMap> items;
    items.reserve(42);
    for (int i = 0; i < 42; ++i) {
        const DayInfo info = infoForDate(cursor);
        const bool officialHoliday = !info.holidayName.isEmpty();
        const bool adjustedWorkday = !info.workdayName.isEmpty();
        const QString festivalText = joinLabels(info.festivals);
        const QString labelText = labelFor(info);

        QVariantMap item;
        item.insert(QStringLiteral("isoDate"), cursor.toString(Qt::ISODate));
        item.insert(QStringLiteral("dayNumber"), cursor.day());
        item.insert(QStringLiteral("isCurrentMonth"), cursor.month() == m_displayMonth && cursor.year() == m_displayYear);
        item.insert(QStringLiteral("isToday"), cursor == today);
        item.insert(QStringLiteral("isWeekend"), cursor.dayOfWeek() >= 6);
        item.insert(QStringLiteral("isOfficialHoliday"), officialHoliday);
        item.insert(QStringLiteral("isAdjustedWorkday"), adjustedWorkday);
        item.insert(QStringLiteral("holidayName"), info.holidayName);
        item.insert(QStringLiteral("workdayName"), info.workdayName);
        item.insert(QStringLiteral("festivalText"), festivalText);
        item.insert(QStringLiteral("labelText"), labelText);
        item.insert(QStringLiteral("badgeText"), adjustedWorkday ? QStringLiteral("班") : (officialHoliday ? QStringLiteral("休") : QString()));
        item.insert(QStringLiteral("badgeKind"), adjustedWorkday ? QStringLiteral("workday") : (officialHoliday ? QStringLiteral("holiday") : QString()));
        item.insert(QStringLiteral("hasEvent"), officialHoliday || adjustedWorkday || !festivalText.isEmpty());
        items.push_back(item);
        cursor = cursor.addDays(1);
    }

    m_days.setItems(items);
}

void CalendarPlugin::addHolidayRange(const QString &name, const QDate &start, const QDate &end)
{
    if (!start.isValid() || !end.isValid() || end < start)
        return;
    for (QDate date = start; date <= end; date = date.addDays(1))
        m_dayInfo[date].holidayName = name;
}

void CalendarPlugin::addWorkday(const QString &name, const QDate &date)
{
    if (!date.isValid())
        return;
    m_dayInfo[date].workdayName = name;
}

void CalendarPlugin::addFestival(const QString &name, const QDate &date)
{
    if (!date.isValid() || name.isEmpty())
        return;
    auto &info = m_dayInfo[date];
    if (!info.festivals.contains(name))
        info.festivals.push_back(name);
}

CalendarPlugin::DayInfo CalendarPlugin::infoForDate(const QDate &date) const
{
    return m_dayInfo.value(date);
}

QString CalendarPlugin::labelFor(const DayInfo &info) const
{
    if (!info.workdayName.isEmpty())
        return QStringLiteral("调休");
    if (!info.festivals.isEmpty())
        return info.festivals.first();
    return {};
}