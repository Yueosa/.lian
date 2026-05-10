#pragma once

class SysmonRam {
public:
    SysmonRam();
    ~SysmonRam() = default;

    void update();
    
    unsigned long long getTotalMemKB() const;
    double getMemUsagePercent() const;
    double getUsedMemGB() const;
    double getSwapUsedGB() const;
    double getSwapTotalGB() const;

private:
    unsigned long long m_totalMemKB;
    double m_memUsagePercent;
    double m_usedMemGB;
    double m_swapUsedGB;
    double m_swapTotalGB;
};
