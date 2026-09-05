.pragma library

// 把 JS 数组的差异增量搬进 ListModel。
//
// 为什么要它：ListView 的 add / remove / move / displaced 过渡只在模型
// 真的「增删移」时才触发。服务层原来每次刷新都重算一整个 JS 数组，视图拿到
// 新数组只能整体重建，过渡压根没机会播——新条目就是硬冒出来的（wifi 的
// ssid 列表、蓝牙设备列表、updates 的包列表都是这个毛病）。
//
// 开销：纯 JS，O(n²) 但 n 是「一屏能看的条目数」量级（几个到几十个），
// 且只在服务层数据真的变了那一拍跑一次，不进渲染循环。
//
// 用法（服务层）：
//   import "rowsync.js" as RowSync
//   RowSync.sync(_devModel, devices, "device")                   // 按身份
//   RowSync.sync(_aurModel, pkgs, "pkg", p => p.name)            // 按键
//
// role 是存值的角色名。默认按对象身份比对，**但身份稳不稳要一条条确认**：
//   - 每次重算都新建的字面量对象（包列表）显然不能按身份，得给 keyOf
//   - 底层服务给的 QObject 也未必稳：NM 每次重扫 wifi 都可能给同一个 SSID
//     换一个新的 WifiNetwork 对象，按身份比就是每次扫描「全删全增」——白干
//     一整列 delegate，还给 add/remove 过渡制造互相打断的机会（见
//     plan-notes.md：扫完多出一条一样的 SSID 叠在原来那条上）
// 拿不准就给 keyOf 一个业务上的稳定键（SSID、MAC、包名），键相同而对象换了
// 的情况下面那条 setProperty 会原地换值，行不动。
function sync(model, list, role, keyOf) {
    const key = keyOf || function (x) { return x }
    const wanted = []
    for (let i = 0; i < list.length; i++)
        wanted.push(key(list[i]))

    // 先删：倒着走，删除不影响未遍历的下标。
    //
    // 连续的一段并成一次 remove(i, n)。一次删一行的话，每行都是一次独立事务，
    // ListView 每次都要给底下所有幸存行重排一遍 displaced —— 100 行滤成 5 行
    // 就是 95 次事务、95 轮级联动画互相打断，这才是行级动画当初读起来像噪音的
    // 真正原因（而不是"改动多了就没法读"）。并段之后事务数 = 幸存段数，
    // 一般个位数，每个幸存行只被顶一次，动画于是能一路播完
    let run = 0
    for (let i = model.count - 1; i >= 0; i--) {
        if (wanted.indexOf(key(model.get(i)[role])) < 0) {
            run++
            continue
        }
        if (run > 0) {
            model.remove(i + 1, run)
            run = 0
        }
    }
    if (run > 0)
        model.remove(0, run)

    // 再按目标次序插入或搬移。j 之前的都已就位，所以只需从 j 往后找
    for (let j = 0; j < list.length; j++) {
        let cur = -1
        for (let k = j; k < model.count; k++) {
            if (key(model.get(k)[role]) === wanted[j]) {
                cur = k
                break
            }
        }
        if (cur < 0) {
            const item = {}
            item[role] = list[j]
            model.insert(j, item)
            continue
        }
        if (cur !== j)
            model.move(cur, j, 1)
        // 键没变但内容变了（包的版本号跳了一档）：原地换值。
        // 走 insert 会让这一行重播入场动画，明明它只是改了个版本号
        if (model.get(j)[role] !== list[j])
            model.setProperty(j, role, list[j])
    }
}

// 这一次要增几行、删几行（不数搬移）。
//
// 给调用方决定「还要不要播行级过渡」用。**增删要分开看**，两头的代价不对称：
//   删——sync 把连续段并成一次 remove，事务数 = 幸存段数，几十行也便宜，
//       动画能一路播完，读起来正是「筛掉」那个意思
//   增——ListModel 没有批量插入接口，回灌 48 行就是 48 次事务、48 轮 displaced
//       级联互相打断（用户看到的是「本该在别页的条目跑到第一屏又迅速消失」，
//       还带一阵掉帧）
// 所以门槛只该卡在「增」那一侧。详见 plan-notes.md 第 7 轮 / backspace 回灌
function delta(model, list, role, keyOf) {
    const key = keyOf || function (x) { return x }

    const now = {}
    for (let i = 0; i < model.count; i++)
        now[key(model.get(i)[role])] = true

    const want = {}
    let added = 0
    for (let i = 0; i < list.length; i++) {
        const k = key(list[i])
        want[k] = true
        if (!now[k])
            added++
    }

    let removed = 0
    for (const k in now) {
        if (!want[k])
            removed++
    }
    return { added: added, removed: removed }
}

// 大改专用的便宜路：前缀原地换值、尾巴一次性增删。
//
// 不复用 sync：它为了保住条目身份是 O(n²) 的，48 格的回灌实测掉一帧（34ms），
// 而且 48 次插入 = 48 次布局。这一拍反正不播行级动画，身份就不值钱了。
// 关键是 count **不经 0**：清空重填会让容器自报空、按占位协议先收一半，再变
// 非空又要等上升沿防抖，复位那一下只能跳（实测 128 → … → 72 → 一帧 352）
function overwrite(model, list, role) {
    const keep = Math.min(model.count, list.length)
    for (let i = 0; i < keep; i++) {
        if (model.get(i)[role] !== list[i])
            model.setProperty(i, role, list[i])
    }
    if (model.count > list.length)
        model.remove(list.length, model.count - list.length)
    for (let i = model.count; i < list.length; i++) {
        const item = {}
        item[role] = list[i]
        model.append(item)
    }
}
