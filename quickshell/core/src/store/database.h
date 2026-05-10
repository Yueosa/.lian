#pragma once

#include <QString>
#include <QMutex>
#include <sqlite3.h>

namespace clavis::store {

// Database 单例：持有可写连接（writer 线程独占），并提供只读连接工厂。
//
// 使用约束：
//   - open() 必须先于任何 DAO 调用；失败时降级到 :memory: 但仍可用
//   - writer 操作必须在 writer 线程串行调用（DAO 自己保证）
//   - 读操作可在任意线程，使用 openReader() 拿到一条独立连接
//   - 析构由 instance() 的 Q_GLOBAL_STATIC 接管
class Database {
public:
    static Database& instance();

    // 第一次调用：在标准位置打开 ~/.local/state/lian/lian.db，跑 migration。
    // 失败时改用 :memory:，inMemory() 返回 true。重复调用 no-op。
    bool open();

    bool isOpen() const { return m_writer != nullptr; }
    bool inMemory() const { return m_inMemory; }
    QString path() const { return m_path; }
    int schemaVersion() const { return m_version; }

    // 写连接（单例共享）。仅供 DAO 在 writer 线程使用。
    sqlite3* writer() { return m_writer; }

    // 新开一个只读连接，调用方负责 sqlite3_close。线程安全。
    // file 模式下走 file:...?mode=ro&cache=shared；in-memory 模式回写连接（受 mutex）
    sqlite3* openReader();

    // 关闭并释放连接。仅在进程退出前调用一次。
    void shutdown();

private:
    Database() = default;
    ~Database();
    Database(const Database&) = delete;
    Database& operator=(const Database&) = delete;

    bool execMany(sqlite3* db, const char* sql);
    bool migrate();

    sqlite3* m_writer = nullptr;
    bool m_inMemory = false;
    QString m_path;
    int m_version = 0;
    QMutex m_openMutex;
};

} // namespace clavis::store
