#include "calendar_day_model.h"

CalendarDayModel::CalendarDayModel(QObject *parent)
    : QAbstractListModel(parent)
{
    const QList<QByteArray> names = {
        "isoDate", "dayNumber", "isCurrentMonth", "isToday", "isWeekend",
        "isOfficialHoliday", "isAdjustedWorkday", "holidayName", "workdayName",
        "festivalText", "labelText", "badgeText", "badgeKind", "hasEvent"
    };
    for (int i = 0; i < names.size(); ++i)
        m_roles[Qt::UserRole + 1 + i] = names[i];
}

int CalendarDayModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid())
        return 0;
    return m_items.size();
}

QVariant CalendarDayModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_items.size())
        return {};
    if (role == Qt::DisplayRole)
        return m_items[index.row()];
    const auto name = m_roles.value(role);
    if (name.isEmpty())
        return {};
    return m_items[index.row()].value(QString::fromUtf8(name));
}

QHash<int, QByteArray> CalendarDayModel::roleNames() const
{
    return m_roles;
}

QVariantMap CalendarDayModel::get(int index) const
{
    if (index < 0 || index >= m_items.size())
        return {};
    return m_items[index];
}

int CalendarDayModel::count() const
{
    return m_items.size();
}

void CalendarDayModel::setItems(const QList<QVariantMap> &items)
{
    beginResetModel();
    m_items = items;
    endResetModel();
}