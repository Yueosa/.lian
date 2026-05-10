#include "sysmon_plugin.h"
#include "sysmon_backend.h"

#include <QtGlobal>

SysmonPlugin::SysmonPlugin(QObject *parent) 
    : QObject(parent),
    m_cpuUsage(0), m_ramUsage(0), m_ramUsedGB(0), m_ramTotalGB(0),
    m_swapUsedGB(0), m_swapTotalGB(0),
      m_netDownBps(0), m_netUpBps(0),
      m_coreTemp(0), m_gpuTemp(0), m_gpuUsage(0),
      m_load1(0), m_load5(0), m_load15(0), m_cpuFreqGHz(0),
      m_taskRunning(0), m_taskTotal(0),
      m_batteryPercent(0), m_batteryHealth(100), m_batteryPowerW(0),
      m_diskUsage(0), m_diskUsedGB(0), m_diskTotalGB(0),
      m_processModel(new ProcessModel(this))
{
    // 四级定时器
    connect(&m_fastTimer, &QTimer::timeout, this, &SysmonPlugin::onFastTick);
    m_fastTimer.setInterval(1000);
    m_fastTimer.start();
    
    connect(&m_mediumTimer, &QTimer::timeout, this, &SysmonPlugin::onMediumTick);
    m_mediumTimer.setInterval(2000);
    m_mediumTimer.start();
    
    connect(&m_slowTimer, &QTimer::timeout, this, &SysmonPlugin::onSlowTick);
    m_slowTimer.setInterval(5000);
    m_slowTimer.start();
    
    connect(&m_glacialTimer, &QTimer::timeout, this, &SysmonPlugin::onGlacialTick);
    m_glacialTimer.setInterval(30000);
    m_glacialTimer.start();
    
    // 首次全量采集
    onFastTick();
    onMediumTick();
    onSlowTick();
    onGlacialTick();
}

// === Getters ===

// Fast
double SysmonPlugin::cpuUsage() const { return m_cpuUsage; }
double SysmonPlugin::ramUsage() const { return m_ramUsage; }
double SysmonPlugin::ramUsedGB() const { return m_ramUsedGB; }
double SysmonPlugin::ramTotalGB() const { return m_ramTotalGB; }
double SysmonPlugin::swapUsedGB() const { return m_swapUsedGB; }
double SysmonPlugin::swapTotalGB() const { return m_swapTotalGB; }
double SysmonPlugin::netDownBps() const { return m_netDownBps; }
double SysmonPlugin::netUpBps() const { return m_netUpBps; }
ProcessModel* SysmonPlugin::processes() const { return m_processModel; }
QVariantMap SysmonPlugin::getProcessDetails(int pid) const { return SysmonBackend::instance().getProcessDetails(pid); }
QVariantList SysmonPlugin::buildChartPoints(const QVariantList &values,
                                            double maxValue,
                                            double chartWidth,
                                            double chartHeight,
                                            double slideProgress) const {
    QVariantList out;
    const int n = values.size();
    if (n < 2 || chartWidth <= 0 || chartHeight <= 0) {
        return out;
    }

    const double maxV = qMax(0.0001, maxValue);
    const double padX = 2.0;
    const double padY = 4.0;
    const double baseY = chartHeight - padY;
    const double usableW = qMax(1.0, chartWidth - padX * 2.0);
    const double usableH = qMax(1.0, chartHeight - padY * 2.0);
    const double seg = qMax(1, n - 1);
    const double prog = qBound(0.0, slideProgress, 1.0);

    out.reserve(n);
    for (int i = 0; i < n; ++i) {
        const double t = (static_cast<double>(i) + 1.0 - prog) / seg;
        double v = qMax(0.0, values.at(i).toDouble());
        if (i == n - 1 && n >= 2) {
            const double prev = qMax(0.0, values.at(n - 2).toDouble());
            v = prev + (v - prev) * prog;
        }

        QVariantMap point;
        point.insert(QStringLiteral("x"), padX + usableW * t);
        point.insert(QStringLiteral("y"), baseY - (v / maxV) * usableH);
        out.push_back(point);
    }

    return out;
}

// Medium
double SysmonPlugin::coreTemp() const { return m_coreTemp; }
double SysmonPlugin::gpuTemp() const { return m_gpuTemp; }
double SysmonPlugin::gpuUsage() const { return m_gpuUsage; }
double SysmonPlugin::load1() const { return m_load1; }
double SysmonPlugin::load5() const { return m_load5; }
double SysmonPlugin::load15() const { return m_load15; }
double SysmonPlugin::cpuFreqGHz() const { return m_cpuFreqGHz; }

// Slow
double SysmonPlugin::batteryPercent() const { return m_batteryPercent; }
QString SysmonPlugin::batteryStatus() const { return m_batteryStatus; }
int SysmonPlugin::batteryHealth() const { return m_batteryHealth; }
double SysmonPlugin::batteryPowerW() const { return m_batteryPowerW; }

// Glacial
double SysmonPlugin::diskUsage() const { return m_diskUsage; }
double SysmonPlugin::diskUsedGB() const { return m_diskUsedGB; }
double SysmonPlugin::diskTotalGB() const { return m_diskTotalGB; }
QString SysmonPlugin::uptime() const { return m_uptime; }
int SysmonPlugin::taskRunning() const { return m_taskRunning; }
int SysmonPlugin::taskTotal() const { return m_taskTotal; }

// === 分级更新槽 ===

void SysmonPlugin::onFastTick() {
    auto &be = SysmonBackend::instance();
    be.updateFast();
    
    m_cpuUsage   = be.getGlobalCpuUsage();
    m_ramUsage   = be.getRamUsagePercent();
    m_ramUsedGB  = be.getRamUsedGB();
    m_ramTotalGB = be.getRamTotalGB();
    m_swapUsedGB = be.getSwapUsedGB();
    m_swapTotalGB = be.getSwapTotalGB();
    m_netDownBps = be.getNetDownBps();
    m_netUpBps   = be.getNetUpBps();
    
    m_processModel->setProcesses(be.getTopProcesses(50));
    
    emit fastDataChanged();
}

void SysmonPlugin::onMediumTick() {
    auto &be = SysmonBackend::instance();
    be.updateMedium();
    
    m_coreTemp    = be.getCoreTempCelsius();
    m_gpuTemp     = be.getGpuTempCelsius();
    m_gpuUsage    = be.getGpuUsagePercent();
    m_load1       = be.getLoad1();
    m_load5       = be.getLoad5();
    m_load15      = be.getLoad15();
    m_cpuFreqGHz  = be.getCpuFreqGHz();
    m_taskRunning = be.getRunningTasks();
    m_taskTotal   = be.getTotalTasks();
    
    emit mediumDataChanged();
}

void SysmonPlugin::onSlowTick() {
    auto &be = SysmonBackend::instance();
    be.updateSlow();
    
    m_batteryPercent = be.getBatteryPercent();
    m_batteryStatus  = be.getBatteryStatus();
    m_batteryHealth  = be.getBatteryHealth();
    m_batteryPowerW  = be.getBatteryPowerW();
    
    emit slowDataChanged();
}

void SysmonPlugin::onGlacialTick() {
    auto &be = SysmonBackend::instance();
    be.updateGlacial();
    
    m_diskUsage   = be.getDiskUsagePercent();
    m_diskUsedGB  = be.getDiskUsedGB();
    m_diskTotalGB = be.getDiskTotalGB();
    m_uptime      = be.getUptime();
    
    emit glacialDataChanged();
}
