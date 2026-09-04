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
//   RowSync.sync(_nearbyModel, list, "network")                  // 按身份
//   RowSync.sync(_aurModel, pkgs, "pkg", p => p.name)            // 按键
//
// role 是存值的角色名。默认按对象身份比对——服务层的设备/网络对象是稳定的
// QObject 引用，能这么比。但包列表那种每次重算都新建的字面量对象就得给
// keyOf（比如包名），否则每次刷新都会被当成「全删全增」，动画反而更糟。
function sync(model, list, role, keyOf) {
    const key = keyOf || function (x) { return x }
    const wanted = []
    for (let i = 0; i < list.length; i++)
        wanted.push(key(list[i]))

    // 先删：倒着走，删除不影响未遍历的下标
    for (let i = model.count - 1; i >= 0; i--) {
        if (wanted.indexOf(key(model.get(i)[role])) < 0)
            model.remove(i)
    }

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
