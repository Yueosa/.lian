#include "sysmon_ram.h"
#include <QFile>
#include <QStringList>

SysmonRam::SysmonRam()
    : m_totalMemKB(1)
    , m_memUsagePercent(0.0)
    , m_usedMemGB(0.0)
    , m_swapUsedGB(0.0)
    , m_swapTotalGB(0.0) {
    update();
}

unsigned long long SysmonRam::getTotalMemKB() const { return m_totalMemKB; }
double SysmonRam::getMemUsagePercent() const { return m_memUsagePercent; }
double SysmonRam::getUsedMemGB() const { return m_usedMemGB; }
double SysmonRam::getSwapUsedGB() const { return m_swapUsedGB; }
double SysmonRam::getSwapTotalGB() const { return m_swapTotalGB; }

void SysmonRam::update() {
    QFile file("/proc/meminfo");
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) return;

    QByteArray content = file.readAll();
    QString text = QString::fromUtf8(content);
    QStringList lines = text.split('\n');
    
    unsigned long long memTotal = 0;
    unsigned long long memAvailable = 0;
    unsigned long long swapTotal = 0;
    unsigned long long swapFree = 0;
    
    for (const QString& line : lines) {
        if (line.startsWith("MemTotal:")) {
            QStringList parts = line.split(' ', Qt::SkipEmptyParts);
            if (parts.size() >= 2) memTotal = parts[1].toULongLong();
        } else if (line.startsWith("MemAvailable:")) {
            QStringList parts = line.split(' ', Qt::SkipEmptyParts);
            if (parts.size() >= 2) memAvailable = parts[1].toULongLong();
        } else if (line.startsWith("SwapTotal:")) {
            QStringList parts = line.split(' ', Qt::SkipEmptyParts);
            if (parts.size() >= 2) swapTotal = parts[1].toULongLong();
        } else if (line.startsWith("SwapFree:")) {
            QStringList parts = line.split(' ', Qt::SkipEmptyParts);
            if (parts.size() >= 2) swapFree = parts[1].toULongLong();
        }
        
        // /proc/meminfo 很小，直接完整扫描，避免在读到 SwapTotal/SwapFree 之前提前退出。
    }

    if (memTotal > 0) {
        unsigned long long usedKB = memTotal - memAvailable;
        m_totalMemKB = memTotal;
        m_memUsagePercent = (static_cast<double>(usedKB) / static_cast<double>(memTotal)) * 100.0;
        m_usedMemGB = static_cast<double>(usedKB) / (1024.0 * 1024.0);
    }

    if (swapTotal >= swapFree) {
        const unsigned long long swapUsedKB = swapTotal - swapFree;
        m_swapUsedGB = static_cast<double>(swapUsedKB) / (1024.0 * 1024.0);
        m_swapTotalGB = static_cast<double>(swapTotal) / (1024.0 * 1024.0);
    }
}
