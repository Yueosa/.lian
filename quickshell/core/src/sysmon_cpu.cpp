#include "sysmon_cpu.h"
#include <QFile>
#include <QFileInfo>
#include <QTextStream>
#include <QVariantMap>
#include <QStringList>
#include <filesystem>
#include <algorithm>
#include <unistd.h>

namespace fs = std::filesystem;

unsigned long long CpuTimes::total() const {
    return user + nice + system + idle + iowait + irq + softirq + steal + guest + guest_nice;
}
unsigned long long CpuTimes::work() const {
    return user + nice + system + irq + softirq + steal;
}

SysmonCpu::SysmonCpu() : m_globalCpuUsage(0.0), m_firstSample(true) {
    m_previousCpuTimes = readCpuTimes();
}

double SysmonCpu::getGlobalCpuUsage() const {
    return m_globalCpuUsage;
}

std::vector<ProcessInfo> SysmonCpu::getTopProcesses(int limit) const {
    std::vector<ProcessInfo> result = m_lastProcesses;
    if (result.size() > static_cast<size_t>(limit)) {
        result.resize(limit);
    }
    return result;
}

QVariantMap SysmonCpu::getProcessDetails(int pid) const {
    QVariantMap detail;
    detail["pid"] = pid;
    detail["available"] = false;
    detail["exactMemory"] = false;
    detail["permissionDenied"] = false;
    detail["error"] = "";
    detail["name"] = "";
    detail["state"] = "";
    detail["threads"] = 0;
    detail["cmdline"] = "";
    detail["exePath"] = "";
    detail["rssKB"] = static_cast<qulonglong>(0);
    detail["pssKB"] = static_cast<qulonglong>(0);
    detail["ussKB"] = static_cast<qulonglong>(0);
    detail["privateDirtyKB"] = static_cast<qulonglong>(0);
    detail["privateCleanKB"] = static_cast<qulonglong>(0);
    detail["sharedCleanKB"] = static_cast<qulonglong>(0);
    detail["sharedDirtyKB"] = static_cast<qulonglong>(0);
    detail["anonymousKB"] = static_cast<qulonglong>(0);
    detail["swapKB"] = static_cast<qulonglong>(0);

    if (pid <= 0) {
        detail["error"] = "invalid pid";
        return detail;
    }

    QFile statusFile(QString("/proc/%1/status").arg(pid));
    if (statusFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        const QStringList lines = QString::fromUtf8(statusFile.readAll()).split('\n');
        for (const QString &line : lines) {
            if (line.startsWith("Name:")) {
                detail["name"] = line.section(':', 1).trimmed();
            } else if (line.startsWith("State:")) {
                detail["state"] = line.section(':', 1).trimmed();
            } else if (line.startsWith("Threads:")) {
                detail["threads"] = line.section(':', 1).trimmed().toInt();
            } else if (line.startsWith("VmRSS:")) {
                const qulonglong vmRssKB = line.section(':', 1).trimmed().section(' ', 0, 0).toULongLong();
                detail["rssKB"] = vmRssKB;
            }
        }
    } else if (!QFileInfo::exists(QString("/proc/%1").arg(pid))) {
        detail["error"] = "process exited";
        return detail;
    }

    QFile cmdlineFile(QString("/proc/%1/cmdline").arg(pid));
    if (cmdlineFile.open(QIODevice::ReadOnly)) {
        QByteArray raw = cmdlineFile.readAll();
        raw.replace('\0', ' ');
        detail["cmdline"] = QString::fromUtf8(raw).trimmed();
    }

    const QString exeLinkPath = QString("/proc/%1/exe").arg(pid);
    const QFileInfo exeInfo(exeLinkPath);
    if (exeInfo.exists() || exeInfo.isSymLink()) {
        detail["exePath"] = exeInfo.symLinkTarget();
    }

    QFile rollupFile(QString("/proc/%1/smaps_rollup").arg(pid));
    if (!rollupFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        detail["permissionDenied"] = true;
        detail["error"] = "smaps_rollup unavailable or permission denied";
        detail["available"] = !detail["name"].toString().isEmpty() || !detail["cmdline"].toString().isEmpty();
        return detail;
    }

    const QStringList rollupLines = QString::fromUtf8(rollupFile.readAll()).split('\n');
    qulonglong privateCleanKB = 0;
    qulonglong privateDirtyKB = 0;
    qulonglong sharedCleanKB = 0;
    qulonglong sharedDirtyKB = 0;

    for (const QString &line : rollupLines) {
        auto valueOf = [&line]() -> qulonglong {
            return line.section(':', 1).trimmed().section(' ', 0, 0).toULongLong();
        };

        if (line.startsWith("Rss:")) {
            detail["rssKB"] = valueOf();
        } else if (line.startsWith("Pss:")) {
            detail["pssKB"] = valueOf();
        } else if (line.startsWith("Private_Clean:")) {
            privateCleanKB = valueOf();
            detail["privateCleanKB"] = privateCleanKB;
        } else if (line.startsWith("Private_Dirty:")) {
            privateDirtyKB = valueOf();
            detail["privateDirtyKB"] = privateDirtyKB;
        } else if (line.startsWith("Shared_Clean:")) {
            sharedCleanKB = valueOf();
            detail["sharedCleanKB"] = sharedCleanKB;
        } else if (line.startsWith("Shared_Dirty:")) {
            sharedDirtyKB = valueOf();
            detail["sharedDirtyKB"] = sharedDirtyKB;
        } else if (line.startsWith("Anonymous:")) {
            detail["anonymousKB"] = valueOf();
        } else if (line.startsWith("Swap:")) {
            detail["swapKB"] = valueOf();
        }
    }

    detail["ussKB"] = privateCleanKB + privateDirtyKB;
    detail["exactMemory"] = true;
    detail["available"] = true;
    detail["permissionDenied"] = false;
    detail["error"] = "";
    return detail;
}

CpuTimes SysmonCpu::readCpuTimes() const {
    CpuTimes times = {0,0,0,0,0,0,0,0,0,0};
    QFile file("/proc/stat");
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) return times;

    QTextStream in(&file);
    QString line = in.readLine();
    if (line.startsWith("cpu ")) {
        QStringList parts = line.split(' ', Qt::SkipEmptyParts);
        if (parts.size() >= 11) {
            times.user = parts[1].toULongLong();
            times.nice = parts[2].toULongLong();
            times.system = parts[3].toULongLong();
            times.idle = parts[4].toULongLong();
            times.iowait = parts[5].toULongLong();
            times.irq = parts[6].toULongLong();
            times.softirq = parts[7].toULongLong();
            times.steal = parts[8].toULongLong();
            times.guest = parts[9].toULongLong();
            times.guest_nice = parts[10].toULongLong();
        }
    }
    return times;
}

void SysmonCpu::update(unsigned long long totalSystemMemKB) {
    CpuTimes currentCpuTimes = readCpuTimes();
    unsigned long long sysTicksDiff = currentCpuTimes.total() - m_previousCpuTimes.total();

    if (!m_firstSample && sysTicksDiff > 0) {
        unsigned long long workDiff = currentCpuTimes.work() - m_previousCpuTimes.work();
        m_globalCpuUsage = (static_cast<double>(workDiff) / static_cast<double>(sysTicksDiff)) * 100.0;
    }
    m_previousCpuTimes = currentCpuTimes;

    std::vector<ProcessInfo> processes;
    std::map<int, unsigned long long> currentProcTicks;
    long pageSizeKB = sysconf(_SC_PAGESIZE) / 1024;

    std::error_code ec;
    for (const auto& entry : fs::directory_iterator("/proc", ec)) {
        if (!entry.is_directory(ec)) continue;
        
        QString dirName = QString::fromStdString(entry.path().filename().string());
        bool isNumeric;
        int pid = dirName.toInt(&isNumeric);
        if (!isNumeric) continue;

        ProcessInfo info;
        info.pid = pid;
        info.uid = -1;
        info.cpuPercent = 0.0;
        info.memoryKB = 0;
        info.memoryPercent = 0.0;

        QFile statFile(QString("/proc/%1/stat").arg(pid));
        if (statFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QByteArray content = statFile.readAll();
            int openParen = content.indexOf('(');
            int closeParen = content.lastIndexOf(')');
            if (openParen != -1 && closeParen != -1 && closeParen > openParen) {
                info.name = QString::fromUtf8(content.mid(openParen + 1, closeParen - openParen - 1));
                
                QString suffix = QString::fromUtf8(content.mid(closeParen + 2));
                QStringList stats = suffix.split(' ', Qt::SkipEmptyParts);
                if (stats.size() >= 13) {
                    unsigned long long utime = stats[11].toULongLong();
                    unsigned long long stime = stats[12].toULongLong();
                    unsigned long long procTotalTicks = utime + stime;
                    
                    currentProcTicks[pid] = procTotalTicks;

                    if (!m_firstSample && sysTicksDiff > 0 && m_previousProcTicks.count(pid)) {
                        unsigned long long procTicksDiff = procTotalTicks - m_previousProcTicks[pid];
                        info.cpuPercent = (static_cast<double>(procTicksDiff) / static_cast<double>(sysTicksDiff)) * 100.0;
                    }
                }
            }
        }

        QFile statmFile(QString("/proc/%1/statm").arg(pid));
        if (statmFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QByteArray content = statmFile.readAll();
            QString line = QString::fromUtf8(content);
            QStringList parts = line.split(' ', Qt::SkipEmptyParts);
            if (parts.size() >= 2) {
                unsigned long long rssPages = parts[1].toULongLong();
                info.memoryKB = rssPages * pageSizeKB;
                if (totalSystemMemKB > 0) {
                    info.memoryPercent = (static_cast<double>(info.memoryKB) / static_cast<double>(totalSystemMemKB)) * 100.0;
                }
            }
        }
        
        // 读取完整命令行
        QFile cmdlineFile(QString("/proc/%1/cmdline").arg(pid));
        if (cmdlineFile.open(QIODevice::ReadOnly)) {
            QByteArray raw = cmdlineFile.readAll();
            // cmdline 中参数用 \0 分隔，取第一个参数作为可执行路径
            int nullIdx = raw.indexOf('\0');
            if (nullIdx > 0) {
                info.cmdline = QString::fromUtf8(raw.left(nullIdx));
            } else if (!raw.isEmpty()) {
                info.cmdline = QString::fromUtf8(raw);
            }
        }
        if (info.cmdline.isEmpty()) {
            info.cmdline = info.name; // 回退到进程名
        }
        
        // 读取 UID (用于用户/系统分类)
        QFile statusFile(QString("/proc/%1/status").arg(pid));
        if (statusFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
            QByteArray statusContent = statusFile.readAll();
            int uidIdx = statusContent.indexOf("Uid:");
            if (uidIdx >= 0) {
                QString uidLine = QString::fromUtf8(statusContent.mid(uidIdx));
                QStringList uidParts = uidLine.split('\n').first().split('\t', Qt::SkipEmptyParts);
                if (uidParts.size() >= 2) {
                    info.uid = uidParts[1].toInt();
                }
            }
        }
        
        processes.push_back(info);
    }

    m_previousProcTicks = std::move(currentProcTicks);
    m_firstSample = false;

    std::sort(processes.begin(), processes.end(), [](const ProcessInfo& a, const ProcessInfo& b) {
        return a.cpuPercent > b.cpuPercent;
    });

    m_lastProcesses = std::move(processes);
}
