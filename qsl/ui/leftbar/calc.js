.pragma library

// 计算器求值器 — 四则 + 括号 + 百分比（递归下降，不用 eval）
//
// eval 是给代码用的，这里吃的是用户输入，不能当代码执行。手写 tokenizer +
// 递归下降，语法按优先级从低到高：
//   expr    := term (('+' | '-') term)*
//   term    := factor (('*' | '/') factor)*
//   factor  := ('+' | '-') factor | primary
//   primary := number | '(' expr ')'
//   number  := 数字[.数字] 后面可跟任意个 '%'
//
// 百分比是后缀一元（除 100）：50% = 0.5、200 + 10% = 200.1。这是纯数学语义，
// 不是手机计算器那种「A + B% = A×(1+B%)」魔法——那套规则隐式、难预料，
// 写进注释都说不清什么时候生效。
//
// evaluate(expr) → { ok, value, error }；ok=false 时 error 是给人看的一句话。
// format(n) 把结果压成 12 位有效数字、去尾零。

function _tokenize(s) {
    const toks = []
    let i = 0
    while (i < s.length) {
        const c = s[i]
        if (c === " " || c === "\t") {
            i++
            continue
        }
        if ("+-*/%()".indexOf(c) >= 0) {
            toks.push({ t: c })
            i++
            continue
        }
        if ((c >= "0" && c <= "9") || c === ".") {
            let j = i
            let dots = 0
            while (j < s.length) {
                const d = s[j]
                if (d >= "0" && d <= "9") {
                    j++
                } else if (d === ".") {
                    if (dots > 0)
                        return { err: "数字里有两个小数点" }
                    dots++
                    j++
                } else {
                    break
                }
            }
            toks.push({ t: "num", v: parseFloat(s.slice(i, j)) })
            i = j
            continue
        }
        return { err: "不认识的字符：" + c }
    }
    toks.push({ t: "end" })
    return { toks: toks }
}

function _makeParser(toks) {
    let p = 0
    const peek = () => toks[p]
    const next = () => toks[p++]
    function fail(msg) { throw { message: msg } }

    function expr() {
        let v = term()
        for (;;) {
            const t = peek().t
            if (t === "+") { next(); v += term() }
            else if (t === "-") { next(); v -= term() }
            else return v
        }
    }
    function term() {
        let v = factor()
        for (;;) {
            const t = peek().t
            if (t === "*") { next(); v *= factor() }
            else if (t === "/") {
                next()
                const d = factor()
                if (d === 0)
                    fail("除以零")
                v /= d
            } else return v
        }
    }
    function factor() {
        const t = next()
        if (t.t === "+")
            return factor()
        if (t.t === "-")
            return -factor()
        if (t.t === "num") {
            let v = t.v
            while (peek().t === "%") {
                next()
                v /= 100
            }
            return v
        }
        if (t.t === "(") {
            const v = expr()
            if (next().t !== ")")
                fail("括号没闭合")
            let r = v
            while (peek().t === "%") {
                next()
                r /= 100
            }
            return r
        }
        fail(t.t === "end" ? "表达式不完整" : "意外的符号：" + t.t)
    }

    return {
        parse: function () {
            const v = expr()
            if (peek().t === "num")
                fail("两个数之间缺运算符")
            if (peek().t !== "end")
                fail("表达式没算完：" + peek().t)
            return v
        }
    }
}

function evaluate(expr) {
    try {
        const s = String(expr || "")
        const r = _tokenize(s)
        if (r.err)
            return { ok: false, value: NaN, error: r.err }
        if (r.toks.length <= 1)
            return { ok: false, value: NaN, error: "" }
        const v = _makeParser(r.toks).parse()
        if (!isFinite(v))
            return { ok: false, value: NaN, error: "超出范围" }
        return { ok: true, value: v, error: "" }
    } catch (e) {
        return { ok: false, value: NaN, error: (e && e.message) ? e.message : "算不了" }
    }
}

function format(n) {
    if (typeof n !== "number" || isNaN(n))
        return "?"
    if (!isFinite(n))
        return "∞"
    if (n === 0)
        return "0"
    const s = n.toPrecision(12)
    if (s.indexOf("e") < 0)
        return s.replace(/0+$/, "").replace(/\.$/, "")
    const parts = s.split("e")
    return parts[0].replace(/0+$/, "").replace(/\.$/, "") + "e" + parts[1]
}
