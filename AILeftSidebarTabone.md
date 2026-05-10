# AILeftSidebarTabone

## 目标

给 QuickShell 的 Sidebar（以下简称 QUI）接入 LianClaw 的“普通会话”聊天能力，只做轻量客户端，不复刻 WebUI 全量功能。

本文件面向负责写 QML 的 code agent，目标是让它直接开工。

---

## 已确认决策

1. 会话切换：采用完整会话列表方案。
   - 用 `GET /sessions` 拉全量普通会话列表。
   - 支持创建、切换、删除、重命名普通会话。

2. 工具审批：采用 WebUI 默认策略，不做“强行全部自动通过”。
   - 发送消息时不传 `confirm_all_tools`，或者显式传 `false`。
   - 这样默认 `confirm_policy=never` 的工具直接运行。
   - 真正需要确认的危险调用仍会经过 `tool/confirm_required`。

3. fast/deep：采用会话级切换，默认 `fast`。
   - QUI 顶部放 segmented control：`fast | deep`。
   - 切换后调用 `PUT /sessions/{sid}/mode-choice`。

4. ask/plan/agent：采用会话级切换，默认 `agent`。
   - QUI 顶部再放 segmented control：`ask | plan | agent`。
   - 切换后调用 `PUT /sessions/{sid}/work-mode`。

5. 思考/工具展示：采用窄侧栏友好的内联方案。
   - 思考、工具调用、工具结果都直接显示在消息流中。
   - 不做复杂折叠树；最多只做“长内容展开/收起”。

---

## 连接策略：必须处理端口退避

LianClaw 启动时，Server / MCP / WebClient 都有端口退避逻辑：

- 默认 Server 端口是 `50516`
- 端口被占用时，从默认端口开始逐个 `+1` 探测
- 最多尝试 10 个端口，即 `[50516, 50525]`
- 真源在 `main.py` 的 `_find_available_port()`

### 最稳连接方式

不要硬编码只连 `50516`。

QUI 启动时应该按以下顺序解析后端地址：

1. 先读 `~/.lianclaw/running.json`
2. 若存在且 JSON 合法，优先使用其中的：
   - `server_url`
   - `mcp_url`
   - `webclient_url`
3. 若文件不存在，再 fallback 到：
   - `http://127.0.0.1:50516`
4. 如果请求失败，可在 `50516..50525` 范围内顺序探测 `/sessions`
5. 一旦某个地址成功，缓存为当前 server base

### running.json 形状

```json
{
  "server_url": "http://127.0.0.1:50516",
  "mcp_url": "http://127.0.0.1:50526",
  "webclient_url": "http://127.0.0.1:50536",
  "shutdown_url": "http://127.0.0.1:50516/api/shutdown"
}
```

### 建议

QUI 只需要 `server_url`。

不要连 `50536`。那是 WebUI 静态资源端口，不是聊天 API。

---

## QUI 需要实现的最小功能

### 需要

1. 普通会话列表
2. 新建普通会话
3. 切换普通会话
4. 删除普通会话
5. 重命名普通会话
6. 查看历史消息
7. 发送消息
8. 接收 SSE 流式回复
9. 切换 `fast/deep`
10. 切换 `ask/plan/agent`
11. 处理工具确认
12. 处理表单确认
13. Markdown 渲染
14. 代码块高亮
15. 本地图片引用渲染
16. 思考流 / 工具调用 / 工具结果 / 进度文本显示

### 不需要

1. 永驻会话 `_permanent`
2. Branch tree / 分支管理 UI
3. 知识库管理 UI
4. Skills 管理 UI
5. Runtime 模型配置 UI
6. traces 页面
7. tasks 页面
8. office / monitor / resources 等 WebUI 子页面

---

## 后端接口子集

以下仅列 QUI 需要的接口。

### 1. 会话列表 / 创建 / 详情 / 删除 / 重命名

#### 列出会话

- `GET /sessions?status=all`

返回数组，每项至少关心：

- `session_id`
- `title`
- `status`
- `work_mode`
- `session_type`
- `updated_at`（如果有）

#### 创建普通会话

- `POST /sessions`

请求体：

```json
{
  "title": "新对话",
  "work_mode": "agent"
}
```

注意：

- `work_mode` 可省略，默认就是 `agent`
- 新会话创建后，再立即补一次 mode-choice 为 `fast`

#### 获取会话详情

- `GET /sessions/{sid}`

QUI 至少可用它拿：

- `title`
- `work_mode`
- `message_count`
- `status`

#### 重命名

- `PUT /sessions/{sid}`

请求体：

```json
{
  "title": "新的标题"
}
```

#### 删除

- `DELETE /sessions/{sid}`

注意：

- 普通会话可删
- `_permanent` 不可删，但 QUI 不做永驻，所以无需特殊展示

---

### 2. 会话历史

#### 拉历史

- `GET /sessions/{sid}/history?limit=50&offset=0`

返回体形状：

```json
{
  "messages": [...],
  "total": 123,
  "offset": 0,
  "limit": 50,
  "has_more": true,
  "last_event_seq": 456
}
```

关键点：

- `messages` 是当前分支的历史消息
- `last_event_seq` 很重要，它是启动 SSE 时的游标
- QUI 的首屏流程应该是：
  1. 先拉 history
  2. 再以 `last_event_seq` 去订阅 SSE

如果后续要支持上翻加载旧消息，再用 `offset += limit` 继续拉。

---

### 3. 发送消息

#### 发送

- `POST /sessions/{sid}/messages`

请求体：

```json
{
  "message": "你好",
  "client_message_id": "uuid",
  "confirm_all_tools": false
}
```

字段说明：

- `message`: 用户输入
- `client_message_id`: 幂等键，建议每次发消息都带 UUID
- `confirm_all_tools`: QUI 默认传 `false` 或者直接不传

返回：

```json
{
  "intent_id": "...",
  "session_id": "..."
}
```

HTTP 状态码是 `202 Accepted`。

#### 停止本轮

- `POST /sessions/{sid}/cancel`

用户点击“停止”时调用。

#### 重试

- `POST /sessions/{sid}/retry`

最简单可只支持空 body，表示重试最后一条 user 消息。

---

### 4. 会话模式

#### 切换 fast / deep

- `PUT /sessions/{sid}/mode-choice`

请求体：

```json
{
  "choice": "fast"
}
```

或：

```json
{
  "choice": "deep"
}
```

#### 读取当前 fast / deep

- `GET /sessions/{sid}/runtime`

返回至少关心：

```json
{
  "session_id": "...",
  "mode_choice": "fast",
  "agent_overrides": {}
}
```

注意：

- 如果该会话从未设置过，会回落默认值
- 后端当前的默认回落是 `deep`
- 但 QUI 产品层默认想要 `fast`，所以建议：
  - 新建会话后，立即调用一次 `PUT /sessions/{sid}/mode-choice` 为 `fast`

#### 切换 ask / plan / agent

- `PUT /sessions/{sid}/work-mode`

请求体：

```json
{
  "work_mode": "agent"
}
```

可选值：

- `ask`
- `plan`
- `agent`

建议：

- 新建会话默认 `agent`
- 切换工作模式是会话级，不是单条消息级

---

### 5. SSE 实时流

#### 订阅地址

- `GET /sessions/{sid}/events?after=<last_event_seq>`

也支持 `Last-Event-ID` 头，但 WebUI 当前用的是 query 参数 `after`，QUI 也可以沿用这一套，简单稳定。

#### 协议形状

SSE 只有一个事件名：

```text
event: lc
```

`data:` 是 JSON：

```json
{
  "v": 2,
  "seq": 12,
  "ts": "2025-01-01T00:00:00Z",
  "session_id": "sess-xxx",
  "domain": "llm",
  "type": "delta",
  "data": {"text": "你好"}
}
```

#### 重连语义

- `seq` 单调递增
- 掉线后应记住本地收到的最大 `seq`
- 重连时带 `after=<max_seq>` 或 `Last-Event-ID`
- 服务端会补发缺失事件，然后继续推 live 事件

#### 心跳

服务端每 30s 发一条 SSE comment：

```text
: keep-alive
```

或 `: ping`

QUI 只要忽略 comment 即可。

---

## SSE 事件清单（QUI 必须处理）

以下列出真实 `(domain, type)`，并给出推荐 UI 行为。

### A. 控制流

#### `control / intent_accepted`

含义：后端已接收用户消息，开始处理。

QUI 行为：

- 创建一轮“进行中”的流式状态
- 状态栏显示：`处理中…`

#### `control / intent_processing`

含义：进入处理阶段。

如果 `data.reconnect == true`，说明是断线重连后服务端合成的“你这轮还没跑完”。

QUI 行为：

- 保持当前会话为 streaming 状态
- 不需要再插入新消息

#### `control / intent_done`

含义：本轮 intent 成功完成。

QUI 行为：

- 可视为“这一轮控制层结束”
- 但真正收尾仍建议以 `agent / turn_end` 为准

#### `control / intent_failed`

含义：intent 失败。

QUI 行为：

- 标记本轮结束
- 如果还没有 assistant reply，可插入一个错误块

> 注意：旧前端里还兼容了一些旧名，比如 `intent_completed`、`intent_cancelled`。QML 新实现应优先按当前协议真源实现：`intent_done` / `intent_failed`。

---

### B. agent 阶段事件

#### `agent / compact_start`

```json
{
  "round_index": 1,
  "estimated_tokens": 12345
}
```

QUI 行为：

- 显示进度行：`压缩上下文…`
- 可以作为一条系统状态块插入消息流

#### `agent / context_ready`

```json
{
  "round_index": 1,
  "compact": {
    "before_tokens": 12000,
    "after_tokens": 4500,
    "pipeline": ["..."]
  }
}
```

QUI 行为：

- 更新进度：`上下文就绪`
- 如果带 `compact`，可以把压缩结果文本显示在状态块里

#### `agent / llm_start`

```json
{
  "model": "...",
  "estimated_tokens": 5200
}
```

QUI 行为：

- 状态栏：`正在调用 LLM...`
- 可以把模型名显示在消息右上角或底部 metadata

#### `agent / round_end`

```json
{
  "round_index": 1,
  "tool_calls_count": 2
}
```

QUI 行为：

- 状态栏更新：`第 1 轮完成 (2 工具)`

#### `agent / turn_end`

```json
{
  "reason": "completed",
  "total_rounds": 1,
  "code": "...",
  "message": "..."
}
```

`reason` 可能是：

- `completed`
- `error`
- `aborted`
- `max_rounds`

QUI 行为：

- 标记本轮结束
- 停掉 typing / thinking / running 动画
- 如果是错误，把 `code/message` 附加到 reply 尾部，或单独插入错误块

#### `agent / action_start`

```json
{
  "name": "...",
  "arguments_preview": "...",
  "tool_call_id": "..."
}
```

注意：这是 agent 内部 action handler 事件，不等同于 tool call。

QUI 行为建议：

- 可以弱化显示为“阶段动作”，不作为主要内容
- 如果实现成本高，可以只更新状态栏，不单独渲染

#### `agent / action_result`

```json
{
  "name": "...",
  "success": true,
  "content_preview": "...",
  "terminal": false
}
```

QUI 行为建议：

- 与 `action_start` 配套
- 可弱化显示或忽略，只保留状态文本

---

### C. LLM 文本流

#### `llm / thinking`

```json
{
  "text": "..."
}
```

QUI 行为：

- 追加到当前 assistant 消息的 `thinking` 字段
- 作为灰色小字/次级块内联显示
- 因为你已经决定 Q5 采用方案 B，所以不默认折叠

#### `llm / delta`

```json
{
  "text": "..."
}
```

QUI 行为：

- 追加到当前 assistant 消息的 `content` 字段
- 实时刷新 Markdown 渲染

> 注意：渲染层应做节流。不要每个 token 来一次就全量重排整个复杂组件。

推荐：

- 文本流先累积到内存字符串
- 每 30~60ms 刷一次 UI

---

### D. 工具事件

#### `tool / call`

```json
{
  "tool_call_id": "...",
  "name": "image_scan",
  "arguments_preview": "{...}"
}
```

QUI 行为：

- 在消息流插入一条“工具调用中”块
- 记录索引：`tool_call_id -> ui block`
- 标题示例：`调用 image_scan` 或 `image_scan 执行中…`

#### `tool / result`

```json
{
  "tool_call_id": "...",
  "name": "image_scan",
  "summary": "...",
  "is_error": false
}
```

QUI 行为：

- 用 `tool_call_id` 找到前面的工具块
- 把状态改为 done / error
- 展示 `summary`

如果找不到对应 tool_call_id，也要能补插一条独立工具结果块，避免 UI 丢内容。

#### `tool / confirm_required`

```json
{
  "confirmation_id": "...",
  "tool_name": "...",
  "tool_call_id": "...",
  "command": "...",
  "reasons": ["..."],
  "payload_preview": "...",
  "matched_rule_id": "...",
  "risk_level": "high"
}
```

QUI 行为：

- 弹确认对话框
- 默认按钮聚焦在“取消”而不是“允许”
- 确认时调用：
  - `POST /sessions/{sid}/confirm`

请求体：

```json
{
  "confirmation_id": "...",
  "approved": true,
  "feedback": "可选"
}
```

#### `tool / confirm_resolved`

```json
{
  "confirmation_id": "...",
  "approved": true,
  "comment": "..."
}
```

QUI 行为：

- 关闭确认 UI
- 工具块继续后续状态流转

---

### E. 表单事件

#### `human / form_required`

```json
{
  "form_id": "...",
  "title": "...",
  "questions": [...]
}
```

QUI 行为：

- 弹一个轻量表单面板
- 用户提交后调用：
  - `POST /sessions/{sid}/form_response`

请求体：

```json
{
  "form_id": "...",
  "answers": {...}
}
```

#### `human / form_resolved`

QUI 行为：

- 关闭表单 UI

---

### F. 系统错误

#### `system / error`

```json
{
  "code": "...",
  "message": "...",
  "retryable": true
}
```

QUI 行为：

- 顶部 toast + 消息流内错误块
- 若 `retryable=true`，可提供“重试”按钮

---

## 历史消息如何转成 QUI 的消息块

后端 `GET /history` 返回的 `messages` 是存储层消息，不是 UI 直接展示层。

推荐把它映射成统一的前端块模型。

### 建议的 UI 模型

```ts
interface QuiMessageBlock {
  id: string
  kind: 'user' | 'reply' | 'thinking' | 'tool' | 'status' | 'error'
  role?: 'user' | 'assistant' | 'tool' | 'system'
  text: string
  thinking?: string
  toolCallId?: string
  toolName?: string
  toolArgsPreview?: string
  toolState?: 'running' | 'done' | 'error' | 'confirm_required'
  createdAt?: string
  done?: boolean
}
```

### 历史映射规则

1. `role == user`
   - 映射成 `kind=user`

2. `role == assistant`
   - 若存在 `thinking` 或 `_thinking`
     - 先插一条 `kind=thinking`
   - 若存在 `content`
     - 再插一条 `kind=reply`

3. `role == tool`
   - 映射成 `kind=tool`
   - `name` 和 `tool_call_id` 都保留

4. `role == system`
   - 若是内部动作消息，可根据需要忽略
   - QUI 可以不完全复刻 WebUI 的系统 action block

---

## 完整数据流（QUI）

### 进入会话

1. 用户点击某个 session
2. `GET /sessions/{sid}/runtime`
   - 读取当前 `mode_choice`
3. `GET /sessions/{sid}`
   - 读取 `work_mode` / title
4. `GET /sessions/{sid}/history?limit=50&offset=0`
5. 渲染历史
6. 取返回的 `last_event_seq`
7. 打开 SSE：
   - `GET /sessions/{sid}/events?after=<last_event_seq>`

### 发送消息

1. 本地先插入 user bubble
2. `POST /sessions/{sid}/messages`
3. 等待 SSE：
   - `control/intent_accepted`
   - `agent/llm_start`
   - `llm/thinking`
   - `llm/delta`
   - `tool/*`
   - `agent/turn_end`
4. 在 `turn_end` 后把当前 assistant 块标记 done

### 断线重连

1. 记录最后收到的 `seq`
2. SSE 断开后重连
3. 重连 URL 带 `after=<lastSeq>`
4. 如果服务端补发 `control/intent_processing` 且 `reconnect=true`
   - 说明上一轮还在跑
   - UI 保持 streaming 状态即可

### 停止

1. 用户点击停止
2. `POST /sessions/{sid}/cancel`
3. 本轮 UI 标为 stopped
4. 等 SSE 后续收尾或重新拉 history 修正状态

---

## QML 侧建议的渲染策略

### 1. Markdown

需要支持：

- 标题
- 列表
- 加粗/斜体
- 行内代码
- fenced code block
- 链接
- 图片
- blockquote
- table（如果成本可控）

如果 QML 原生 markdown 能力不够，建议：

- 用一个 markdown parser 先转 HTML
- 再喂给 `TextArea` / `WebEngineView` / 自定义富文本组件

### 2. 代码块

需要支持：

- monospaced 字体
- 横向滚动
- 复制按钮
- 语言标签（可选）

### 3. 图片引用渲染

Agent 现在会在回复里直接写：

```md
![描述](/home/user/Pictures/a.jpg)
```

QUI 需要把本地绝对路径图片改写成后端图片代理地址：

缩略图：

```text
http://127.0.0.1:50516/local-image?path=<encodeURIComponent(path)>&thumb=512
```

原图：

```text
http://127.0.0.1:50516/local-image?path=<encodeURIComponent(path)>
```

注意事项：

1. 先处理端口退避：基于实际 `server_url` 构造，不要硬写 `50516`
2. 如果 markdown parser 已把路径中的空格编码成 `%20`
   - 在重新 encode 前先 decode 一次
   - 避免 `%20 -> %2520` 双重编码
3. 默认展示缩略图
4. 点击时再加载原图
5. 设置 lazy load

### 4. 思考流

由于侧栏较窄，建议：

- thinking 用小号灰字显示
- 放在对应 assistant reply 之前
- 若 thinking 太长，可只显示前几行，提供“展开”

### 5. 工具调用

工具块 UI 建议：

- 第一行：图标 + 工具名 + 状态
- 第二行：参数摘要
- 第三行：结果 summary

状态颜色：

- running: 蓝/黄
- done: 绿
- error: 红
- confirm_required: 橙

### 6. 进度文本

顶部状态栏或输入框上方一行即可：

- `处理中…`
- `正在压缩上下文…`
- `正在调用 LLM…`
- `正在回复…`
- `调用 image_scan…`
- `完成`

---

## 推荐的 QML 客户端状态机

### 全局状态

```ts
serverBase: string
sessions: SessionSummary[]
currentSessionId: string | null
currentModeChoice: 'fast' | 'deep'
currentWorkMode: 'ask' | 'plan' | 'agent'
messages: QuiMessageBlock[]
streaming: boolean
lastEventSeq: number
pendingConfirmation: ConfirmPayload | null
pendingForm: FormPayload | null
```

### 进入会话伪码

```ts
async function openSession(sid) {
  currentSessionId = sid
  streaming = false
  messages = []

  const runtime = await GET(`/sessions/${sid}/runtime`)
  currentModeChoice = runtime.mode_choice || 'deep'

  const meta = await GET(`/sessions/${sid}`)
  currentWorkMode = meta.work_mode || 'agent'

  const hist = await GET(`/sessions/${sid}/history?limit=50&offset=0`)
  messages = mapHistory(hist.messages)
  lastEventSeq = Number(hist.last_event_seq || 0)

  connectSse(sid, lastEventSeq)
}
```

### 发送消息伪码

```ts
async function sendMessage(text) {
  const sid = currentSessionId
  if (!sid || !text.trim()) return

  appendUserBubble(text)

  await POST(`/sessions/${sid}/messages`, {
    message: text,
    client_message_id: uuid(),
    confirm_all_tools: false,
  })
}
```

### SSE 处理伪码

```ts
function onEnvelope(env) {
  lastEventSeq = Math.max(lastEventSeq, env.seq || 0)

  switch (`${env.domain}/${env.type}`) {
    case 'control/intent_accepted':
      streaming = true
      setStatus('处理中…')
      ensureCurrentAssistantDraft()
      break

    case 'llm/thinking':
      ensureCurrentThinkingBlock().text += env.data?.text || ''
      break

    case 'llm/delta':
      ensureCurrentReplyBlock().text += env.data?.text || ''
      throttleRender()
      break

    case 'tool/call':
      upsertToolRunning(env.data)
      break

    case 'tool/result':
      applyToolResult(env.data)
      break

    case 'tool/confirm_required':
      pendingConfirmation = env.data
      openConfirmDialog()
      break

    case 'human/form_required':
      pendingForm = env.data
      openFormDialog()
      break

    case 'agent/turn_end':
      streaming = false
      markCurrentBlocksDone(env.data)
      setStatus('完成')
      break

    case 'system/error':
      streaming = false
      appendErrorBlock(env.data)
      break
  }
}
```

### 工具确认伪码

```ts
async function approveTool(confirmationId, approved, feedback='') {
  await POST(`/sessions/${currentSessionId}/confirm`, {
    confirmation_id: confirmationId,
    approved,
    feedback,
  })
}
```

### 表单提交伪码

```ts
async function submitForm(formId, answers) {
  await POST(`/sessions/${currentSessionId}/form_response`, {
    form_id: formId,
    answers,
  })
}
```

---

## WebUI 可借鉴的关键思路

虽然 QUI 不直接复用 Vue 代码，但下面这些思路值得照搬。

### 1. 历史和实时流分离

WebUI 做法：

- 先拉 `history`
- 再订阅 `events`
- 用 `last_event_seq` 作为连接游标

意义：

- 冷启动稳定
- 刷新后能无缝恢复
- 避免历史和实时消息重复

### 2. 统一消息块模型

WebUI 不直接把后端原始 message 当 UI 节点，而是映射成：

- user block
- reply block
- think block
- tool block
- action/status block

QUI 也应该这么做。

### 3. SSE 先落本地状态，再驱动渲染

不要把 SSE 事件直接“边收边操作复杂组件树”。

建议：

- 先更新 JS/TS/QML 对象模型
- 再通过绑定刷新 UI

### 4. 流式文本要节流

不要 token 级别触发全组件重排。

推荐：

- 文本先累积到字符串 buffer
- 用 30~60ms timer 批量 flush 到 UI

### 5. 工具块按 tool_call_id 回填

`tool/call` 和 `tool/result` 是分开发的。

必须维护：

```ts
Map<tool_call_id, blockIndex>
```

否则工具结果很难稳定对应回原来的调用行。

---

## 最小可交付 UI 结构

建议 Sidebar 结构：

1. 顶部工具栏
   - 新建会话按钮
   - 会话标题
   - `fast | deep`
   - `ask | plan | agent`

2. 左侧或上方会话列表
   - 标题
   - 最近更新时间
   - 删除按钮
   - 重命名入口

3. 中间消息流
   - user / reply / thinking / tool / error

4. 底部输入区
   - 文本输入
   - 发送
   - 停止

5. 弹层
   - confirm dialog
   - form dialog
   - image preview

---

## 关键坑位

### 1. 不要连 WebClient 端口

聊天 API 走 `server_url`，不是 `webclient_url`。

### 2. 不要忽略端口退避

优先读取 `~/.lianclaw/running.json`。

### 3. 不要把 `%20` 再编码成 `%2520`

图片路径在重新 encode 之前先 decode。

### 4. 不要假设一轮只会有一条 reply

可能会出现：

- thinking
- tool call
- tool result
- 再 thinking
- 再 reply

UI 状态机必须支持交错。

### 5. 不要假设所有消息都一次性结束

一轮结束应以 `agent/turn_end` 为主，不要只凭某个 `llm/delta` 停止。

### 6. 不要在危险确认上自动 approve

本项目已明确选择方案 A，不做真正的“全部自动通过”。

---

## 推荐实现顺序

### 第 1 步

先做连接层：

- 读取 `running.json`
- fallback 到 `50516..50525`
- 封装 GET / POST / SSE

### 第 2 步

做会话列表：

- list
- create
- rename
- delete
- switch

### 第 3 步

做历史 + SSE：

- history 首屏拉取
- events 流接入
- last_event_seq 重连

### 第 4 步

做消息状态机：

- user
- reply
- thinking
- tool
- error

### 第 5 步

做渲染层：

- markdown
- code block
- image preview
- status bar

### 第 6 步

做交互：

- fast/deep
- ask/plan/agent
- stop
- retry
- confirm
- form

---

## 最终验收标准

QML agent 完成后，QUI 至少应满足：

1. 能列出普通会话并切换
2. 能新建普通会话
3. 能删除和重命名普通会话
4. 新会话默认 `agent + fast`
5. 能发送消息并收到流式回复
6. 能显示 thinking
7. 能显示 tool call / tool result
8. 能显示“调用 LLM / 压缩上下文 / 完成”等进度文本
9. 能处理 confirm_required
10. 能处理 form_required
11. 能正确渲染 markdown / code block / 本地图片引用
12. 掉线能自动重连，并从 `lastEventSeq` 续传
13. 端口退避时仍能连上正确 server

---

## 参考真源文件

以下文件是协议与实现真源，QML agent 若需核对，优先看这些：

- `main.py`
- `docs/http-api.md`
- `docs/sse-lc-protocol.md`
- `mylib/server/routes/messages.py`
- `mylib/server/routes/sessions.py`
- `mylib/server/routes/runtime_routes.py`
- `mylib/server/routes/confirm.py`
- `mylib/server/routes/form.py`
- `mylib/contracts/http.py`
- `mylib/contracts/sse.py`
- `frontend/src/api/endpoints.ts`
- `frontend/src/composables/useSessionEventsStream.ts`
- `frontend/src/composables/useChatSseHandlers.ts`
- `frontend/src/composables/chatHistoryMapper.ts`
- `frontend/src/components/MessageBubble.vue`
- `frontend/src/app.ts`

如果协议和旧前端局部实现有冲突，以 `docs/sse-lc-protocol.md` 与后端 route / contract 为准。
