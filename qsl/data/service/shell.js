.pragma library

// 往 shell 命令行里塞字符串的唯一正确写法，全壳共用这一份。
//
// 第 10 轮收编前这段逻辑有三份：HyprService.shellQuote、Weather.shellQuote
// （两份字节完全相同），外加 Avatar 里直接内联的一句 replace。最后那份最要命
// ——它引的是 remoteUrl，来自用户配置文件，一路拼进 bash -lc。转义规则要是哪天
// 发现写漏了（比如换行、$'...' 的边角），三处得一起改，而内联那处必然被漏掉。
//
// 单引号包起来、内部单引号换成 '\'' —— POSIX shell 里唯一不用查转义表的写法，
// 单引号中间什么都不解释。

function quote(s) {
    return "'" + String(s).replace(/'/g, "'\\''") + "'"
}

// argv 拼成一行命令。收 argv 的接口（Process.command）不需要这个，只有那些
// 「只认一行字符串」的地方才要——hl.exec_cmd、bash -lc。
function join(argv) {
    if (!argv || !argv.length)
        return ""
    const parts = []
    for (let i = 0; i < argv.length; i++)
        parts.push(quote(argv[i]))
    return parts.join(" ")
}
