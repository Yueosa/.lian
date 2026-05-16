#pragma once

#include "calendar_day_model.h"

#include <QDate>
#include <QHash>
#include <QObject>
#include <QStringList>
#include <QtQml/qqmlregistration.h>

class CalendarPlugin : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(int displayYear READ displayYear NOTIFY monthChanged)
    Q_PROPERTY(int displayMonth READ displayMonth NOTIFY monthChanged)
    Q_PROPERTY(QString monthTitle READ monthTitle NOTIFY monthChanged)
    Q_PROPERTY(QString sourceTitle READ sourceTitle NOTIFY dataChanged)
    Q_PROPERTY(QString sourceUrl READ sourceUrl NOTIFY dataChanged)
    Q_PROPERTY(QString error READ error NOTIFY dataChanged)
    Q_PROPERTY(CalendarDayModel* days READ days CONSTANT)

public:
    explicit CalendarPlugin(QObject *parent = nullptr);

    int displayYear() const;
    int displayMonth() const;
    QString monthTitle() const;
    QString sourceTitle() const;
    QString sourceUrl() const;
    QString error() const;
    CalendarDayModel *days();

    Q_INVOKABLE void setMonth(int year, int month);
    Q_INVOKABLE void previousMonth();
    Q_INVOKABLE void nextMonth();
    Q_INVOKABLE void resetToToday();

signals:
    void monthChanged();
    void dataChanged();

private:
    struct DayInfo {
        QString holidayName;
        QString workdayName;
        QStringList festivals;
    };

    CalendarDayModel m_days;
    QHash<QDate, DayInfo> m_dayInfo;
    int m_displayYear;
    int m_displayMonth;
    QString m_sourceTitle;
    QString m_sourceUrl;
    QString m_error;

    void loadData();
    void rebuildMonth();
    void addHolidayRange(const QString &name, const QDate &start, const QDate &end);
    void addWorkday(const QString &name, const QDate &date);
    void addFestival(const QString &name, const QDate &date);
    DayInfo infoForDate(const QDate &date) const;
    QString labelFor(const DayInfo &info) const;
};