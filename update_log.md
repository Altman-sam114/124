# WWIIHexV0 版本更新记录

本文档记录项目从 v0 到当前 v3.x 隋唐迁移阶段的版本演进。资料来源包括 `git log`、`README.md`、阶段文档与测试/验收报告。

维护规则：

- 每完成一个新的 v 版本任务后，必须在本文档追加对应版本记录。
- 记录应包含：版本号、完成日期、核心变更、关键文件/系统、验证结果、遗留事项。
- 若本轮只是文档整理、目录迁移、回滚或打捞，不应伪装成新 v 版本；可写入“历史维护记录”。
- 若 README、测试规范或源码语义发生变化，应同步更新本日志。

## v3.7-preflight.97 - 动态方面推进势力兜底收口

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在 legacy phase 存档规范化之后，继续处理总提示词 §0.2 的 P1 风险：`WarCommandExecutor.applyStrategicAdvance` 在异常缺少 advancing zone faction 时，会把 `TheaterSystem.expandDynamicTheater` 的推进势力静默兜底为 `.germany`。本轮只改动态方面推进势力推断，不改变 hex 占领权威、动态 theater/front/deploy 权威、同步器主逻辑、命令 schema、规则数值、AI 决策或存档格式。

核心更新：

- `WarCommandExecutor.applyStrategicAdvance` 不再用 `.germany` 作为 `expandDynamicTheater` faction fallback。
- 新增 `resolvedAdvancingFaction(for:advancingZoneId:state:)`：优先取 `frontZones[advancingZoneId].faction`，异常缺 zone 时回退实际行动军队的 `division.faction`。
- 如果 source zone 与行动军队都无法确认推进势力，本次动态方面推进会跳过，并写入“动态方面推进跳过：无法确认推进势力。”战报。
- `shouldAdvanceDynamicTheater` 改为接收已确认的推进势力，避免在判断层继续依赖缺 zone 的 legacy fallback。
- 总提示词 §0.2 / §0.4 将 P1 标记为 v3.7-preflight.97 已收口，后续队列保留 P0、P2、P3 等独立切片。
- 云端 run 28826017428 暴露两个编译问题后追加补修：`GameState` 解码 `playerFaction` 时直接用 `Faction(rawValue:)` 解析字符串；`EconomyRules` 生产部署日志在读取部署州郡名时先解包 optional `regionId`。
- 云端 run 28826187439 继续暴露 `GeneralRegistry.commanderConfig(zoneId:)` 缺少 `return`，已补回显式返回，不改变生成配置内容。
- 云端 run 28826279374 继续暴露 `WarCommandExecutor.defensiveDestination` 的 chained collection expression 触发 Swift type-check 超时，已拆为显式循环构建候选 hex，保持排序和过滤语义不变。

关键文件：

- `WWIIHexV0/Commands/WarCommandExecutor.swift`
- `WWIIHexV0/Agents/GeneralRegistry.swift`
- `WWIIHexV0/Core/GameState.swift`
- `WWIIHexV0/Rules/EconomyRules.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_dynamic_theater_faction_fallback_record.md`
- `md/prompt/v3.0-隋唐迁移/codex-v3.0-隋末唐初aiagent历史策略迁移总提示词.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `command -v swiftc`：无输出，当前容器缺少 `swiftc`，未能执行 Swift 单文件 parse。
- 源码聚焦扫描 `faction: .*?? .germany`：无命中。
- 源码聚焦扫描 `resolvedAdvancingFaction(`、`shouldAdvanceDynamicTheater(` 和“动态方面推进跳过”：均有预期命中。
- 本轮改动文件尾随空白扫描：无命中。
- 本轮改动文件行首冲突标记扫描：无命中。
- `git diff --check`：通过，无输出。

未执行：

- 未跑本机 Xcode build / XCTest / UI test / 模拟器 / Probe / Smoke / Full；按 `md/test/test.md` 当前规范，这些重验证需云端或人工授权。

遗留风险：

- 本轮未运行 AI directive move、动态方面推进、旧阿登场景、默认隋唐场景或异常缺 zone 的自定义场景。
- 单文件 Swift parse 未执行成功，因为当前容器缺少 `swiftc`。
- 并发源码扫描还指出 `RegionDataSet` null owner/controller fallback、MapEditor 非法 unit faction fallback、非 `wude_618` 自定义场景默认势力推断和非 wude 胜负 fallback 等候选，后续应单独切片处理。

## 历史维护记录 - v3 隋唐总提示词并发边界收口

完成日期：2026-07-06

性质：文档整理，不伪装成新 v 版本。本轮按普通 Codex 任务使用并发只读子 Agent 审查总提示词、源码候选残留和文档一致性；主 Agent 只做文档口径修正。

核心更新：

- `AGENTS.md` 的当前目标 prompt 示例从旧 v0.37 路径改为 v3.0 隋唐迁移总提示词路径。
- `md/flow/flow.md` 修正入口文档名为 `AGENTS.md`，并把旧 v0.4 工作树混杂提示改为历史备注，避免误导当前 `main` 直推流程。
- `md/flow/flowchart.md` 的 Agent C artifact 缓存路径统一为 `/private/tmp/wwiihexv0-c-review-<run_id>/`。
- `codex-v3.0-隋末唐初aiagent历史策略迁移总提示词.md` 明确第 5 节是历史路线和架构合同，历史阶段标签不再代表当前默认新建分支；当前仍按 `AGENTS.md` 在 `main` 小步提交和云端验证。
- 总提示词进一步明确并发子 Agent 只属于单轮内部拆分，不替代 Agent A/B/C；Agent C 云端 artifact 核对是 push main 后的必做验收，不是可选发布候选功能。
- 总提示词将 v3.7-preflight.96 后续源码风险按 P0-P3 沉淀：`RegionDataSet` null owner/controller fallback、`WarCommandExecutor` 动态 theater `.germany` fallback、非 `wude_618` 自定义场景默认 faction 推断和 MapEditor 非法 unit faction fallback。
- 总提示词新增单轮切片交付模板，要求每轮写明切片 ID、来源、当前基线、目标/非目标、文件边界、禁止项、实现步骤、轻量检查、文档同步、验收标准、风险和 push/CI 交付。
- 总提示词新增 P0-P3 下一轮切片建议，明确每个风险的单轮处理范围、禁止混入的相邻问题和完成后必须更新 §0.2 队列。
- 总提示词新增子 Agent 固定输出格式和主 Agent 并发整合交付项，要求说明文件重叠、public API / enum / JSON schema 分叉、project 文件、规则管线、动态权威边界和文档口径一致性。
- 总提示词新增维护与冻结标准：本文件只维护长期合同、当前交接状态、候选队列和模板；单轮实现流水应写入阶段记录、`update_log.md` 或 `md/flow/*`，不继续塞回总提示词。
- 总提示词强化第 5 节历史归档口径，明确历史“目标 / 推荐文件 / 验收”只用于理解架构边界，不是 Agent B 默认实现清单；后续仍从 §0.2 或人工新目标切片。
- 总提示词补齐本阶段额外约束：并发子 Agent 默认只做单轮内部拆分、不建候选分支、不 push；`md/prompt/README.md` 只是通用摘要，Agent C 仍按 `AGENTS.md` 完成云端验收后同步 `md/flow/*` 和必要的 `update_log.md`。

未执行：

- 未跑本机 Xcode build / XCTest / UI test / 模拟器 / Probe / Smoke / Full；按 `md/test/test.md` 当前规范，这些重验证需云端或人工授权。

## v3.7-preflight.96 - legacy phase 存档规范化收口

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在 DataLoader 场景阶段兜底收口之后，继续处理 `.95` 留下的 legacy phase 执行判断残留：旧 `.germanAI` / `.alliedPlayer` 阶段仍在命令校验、自动回合判断和回合推进中分散绑定 `.germany` / `.allies`。本轮集中 phase 规范化口径，让脏存档或自定义隋唐场景不会因旧 phase rawValue 回到 legacy 行动判断；同时保留合法 legacy 阿登双势力存档的旧阶段推进。

核心更新：

- `GamePhase` 新增 `normalized(forActiveFaction:playerFaction:)` 和 `allowsCommandExecution(forActiveFaction:playerFaction:)`，集中判断当前 phase 对 active faction / player faction 的真实语义。
- `GameState` 解码存档时会按 active faction 与 player faction 规范化 phase；合法 legacy 阿登 `.germanAI` / `.alliedPlayer` 仍可保留，隋唐或自定义脏 phase 会落到 `.playerCommand` / `.aiCommand`。
- `AppContainer` 在初始化、bootstrap、继续存档、新局、重置和切换执掌势力后统一规范化 phase，并让玩家可操作守卫、玩家命令 bookkeeping、自动回合判断读取规范化 phase。
- `CommandValidator.phaseAllowsCommands(in:)` 改为复用 `GamePhase` helper，不再在本地分散维护 `.germanAI -> .germany` / `.alliedPlayer -> .allies` 判断。
- `CommandExecutor.advanceActiveFaction(in:)` 先规范化当前 phase；合法 legacy 阿登阶段仍走原双势力推进，其他场景走通用 turn order。
- `TurnManager.isAITurn(faction:state:)` 改为按 active faction 和规范化 phase 判断是否可执行自动回合，保留观察模式下 AI 代走玩家阶段的可执行语义。

关键文件：

- `WWIIHexV0/Core/GamePhase.swift`
- `WWIIHexV0/Core/GameState.swift`
- `WWIIHexV0/App/AppContainer.swift`
- `WWIIHexV0/Rules/CommandValidator.swift`
- `WWIIHexV0/Rules/CommandExecutor.swift`
- `WWIIHexV0/Turn/TurnManager.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_legacy_phase_normalization_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `command -v swiftc`：无输出，当前容器缺少 `swiftc`，未能执行 Swift 单文件 parse。
- 旧 phase 直接绑定扫描：`state.phase == .germanAI`、`state.phase == .alliedPlayer`、`phase == .germanAI`、`phase == .alliedPlayer`、`return state.activeFaction == .germany`、`return state.activeFaction == .allies` 无命中。
- 新 phase helper 扫描：`GamePhase.normalized(forActiveFaction:playerFaction:)`、`allowsCommandExecution(forActiveFaction:playerFaction:)`、`GameState` 解码、`AppContainer` 启动/继续/新局/切换执掌势力、`CommandExecutor`、`CommandValidator` 和 `TurnManager` 均有预期命中。
- 聚焦扫描 `.95` 当前状态残留和待补占位：无命中。
- 本轮改动文件尾随空白扫描：无命中。
- 本轮改动文件行首冲突标记扫描：无命中。
- `git diff --check`：通过，无输出。

未执行：

- 未跑本机 Xcode build / XCTest / UI test / 模拟器 / Probe / Smoke / Full；按 `md/test/test.md` 当前规范，这些重验证需云端或人工授权。

遗留风险：

- 本轮未运行旧阿登存档、默认隋唐存档或故意写入 legacy phase 的自定义坏存档。
- 单文件 Swift parse 未执行成功，因为当前容器缺少 `swiftc`。
- 并发源码扫描还指出 `WarCommandExecutor` 动态战区推进 `.germany` fallback、RegionDataSet null owner/controller fallback、MapEditor 非法 unit faction fallback、非 `wude_618` 自定义场景的 legacy GameAgent 默认势力等候选，后续应单独切片处理。

## v3.7-preflight.95 - DataLoader 场景阶段兜底收口

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在默认指挥风格共享 helper 收口之后，继续处理并发只读扫描指出的 DataLoader 迁移残留：`scenario.initialPhase` 无效时仍 fallback 到 `.germanAI`，`initialActiveFaction(for:)` 又独立用 `.alliedPlayer` fallback，导致坏数据或自定义隋唐场景可能回到 legacy 阶段口径且 phase / active faction / 初始战报各自分叉。本轮只改加载兜底，不改变合法 JSON、`GamePhase` case/rawValue、旧阿登显式阶段、命令管线、规则执行、AI 决策或存档 schema。

核心更新：

- `DataLoader.loadGameState(scenario:regionData:)` 只解析一次 `initialPhase` 与 `initialActiveFaction`，并复用到 `GameState` 和初始 `GameLogEntry`。
- 新增 `initialPhase(for:)`：合法 rawValue 直通；无效时 legacy 阿登 fallback `.alliedPlayer`，隋唐或未知自定义场景 fallback `.playerCommand`。
- `initialActiveFaction(for:phase:)` 改为接收已解析 phase，不再内部另用 `.alliedPlayer` fallback。
- 新增 `initialPlayerFaction(for:)`：无效 player faction 时 legacy 阿登 fallback `.allies`，隋唐或未知自定义场景 fallback `.tang`，避免自定义隋唐路径回到 legacy 西路势力。

关键文件：

- `WWIIHexV0/Data/DataLoader.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_dataloader_phase_fallback_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `command -v swiftc`：无输出，当前容器缺少 `swiftc`，未能执行 Swift 单文件 parse。
- 精确扫描旧 DataLoader 直接 fallback：`phase: GamePhase(rawValue: scenario.initialPhase)`、`let phase = ... ??`、`initialActiveFaction(for: scenario)` 无命中。
- 聚焦扫描新 DataLoader helper：`initialPhase(for:)`、`initialActiveFaction(for:phase:)`、`initialPlayerFaction(for:)` 均有预期命中。
- 聚焦扫描 `.94` 当前状态残留：当前交接文档无命中。
- 本轮改动文件尾随空白扫描：无命中。
- 本轮改动文件行首冲突标记扫描：无命中。
- `git diff --check`：通过，无输出。

未执行：

- 未跑本机 Xcode build / XCTest / UI test / 模拟器 / Probe / Smoke / Full；按 `md/test/test.md` 当前规范，这些重验证需云端或人工授权。

遗留风险：

- 本轮未运行默认隋唐场景、旧阿登 fallback 场景或自定义坏 phase JSON 加载。
- 单文件 Swift parse 未执行成功，因为当前容器缺少 `swiftc`。
- legacy phase 执行判断仍保留 `.germanAI` / `.alliedPlayer` 对 `.germany` / `.allies` 的兼容逻辑；后续可单独做“隋唐存档 legacy phase 规范化”补洞。

## v3.7-preflight.94 - 默认指挥风格共享 helper 收口

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在自动总管默认指挥风格对齐多势力映射之后，继续处理 `.93` 留下的维护风险：`AppContainer` 与 `ZoneCommanderAgent` 各自维护一份相同默认指挥风格 switch。本轮只抽取共享 helper，不改变默认映射结果、directive schema、命令管线、规则执行、AI 阈值、战术选择函数、势力 rawValue 或存档格式。

核心更新：

- `ZoneCommanderAgentConfig.CommandStyle` 新增静态 `defaultForFaction(_:)`，集中维护默认指挥风格映射。
- `TheaterCommanderPool.defaultConfig(for:)` 与 `AppContainer.buildCommanderPool(state:registry:)` 均改为调用该共享 helper。
- 删除 `TheaterCommanderPool` 与 `AppContainer` 内部重复的 `defaultCommandStyle(for:)`。
- 保留 `CommandStyle` case、rawValue、Codable、`.cautious` case 和既有战术阈值逻辑。

关键文件：

- `WWIIHexV0/Agents/ZoneCommanderAgent.swift`
- `WWIIHexV0/App/AppContainer.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_command_style_helper_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `command -v swiftc`：无输出，当前容器缺少 `swiftc`，未能执行 Swift 单文件 parse。
- 源码聚焦扫描 `defaultCommandStyle(`：`WWIIHexV0/Agents/ZoneCommanderAgent.swift` 与 `WWIIHexV0/App/AppContainer.swift` 无命中。
- 源码聚焦扫描 `defaultForFaction`：命中共享 helper 定义与两个调用点。
- 聚焦扫描 `.93` 当前状态残留、`AppContainer.defaultCommandStyle` 和“宜抽共享 helper”：无命中。
- 本轮改动文件尾随空白扫描：无命中。
- 本轮改动文件行首冲突标记扫描：无命中。
- `git diff --check`：通过，无输出。

未执行：

- 未跑本机 Xcode build / XCTest / UI test / 模拟器 / Probe / Smoke / Full；按 `md/test/test.md` 当前规范，这些重验证需云端或人工授权。

遗留风险：

- 本轮未运行 AI 回合、方面总管生成链、directive 编译执行链或多势力自动回合。
- 单文件 Swift parse 未执行成功，因为当前容器缺少 `swiftc`。

## v3.7-preflight.93 - 自动总管默认指挥风格收口

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在阶段与旧总管展示口径收口之后，继续处理一个低风险 AI 配置残留：自动方面总管默认配置仍用 `.germany` 二元判断决定指挥风格，导致隋唐主路径自动总管全部落到 `.balanced`。本轮只统一默认配置口径，不改变 directive schema、命令管线、规则执行、AI 阈值、战术选择函数、势力 rawValue 或存档格式。

核心更新：

- `ZoneCommanderAgent.defaultConfig(for:)` 改为调用私有 `defaultCommandStyle(for:)`，不再用 `zone.faction == .germany` 判断指挥风格。
- 默认指挥风格与 `AppContainer` 默认配置口径对齐：旧东路势力、唐、瓦岗、薛秦、刘武周默认 `.aggressive`；旧西路势力、洛阳隋、夏、东突厥默认 `.balanced`。
- 保留 `ZoneCommanderAgentConfig.CommandStyle` rawValue、Codable、`.cautious` case 和既有战术阈值逻辑。
- 总提示词当前交接状态推进到 v3.7-preflight.93，并明确后续 Agent 应从 v3.7+ 风险和 v3.8+ 队列切片，不重做历史路线。

关键文件：

- `WWIIHexV0/Agents/ZoneCommanderAgent.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_agent_default_command_style_record.md`
- `md/prompt/v3.0-隋唐迁移/codex-v3.0-隋末唐初aiagent历史策略迁移总提示词.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `command -v swiftc`：无输出，当前容器缺少 `swiftc`，未能执行 `swiftc -parse WWIIHexV0/Agents/ZoneCommanderAgent.swift`。
- 聚焦扫描 `zone.faction == .germany ? .aggressive : .balanced`、`.92` 当前状态残留和 README 过时 legacy 胜负口径：无命中。
- 本轮改动文件尾随空白扫描：无命中。
- 本轮改动文件行首冲突标记扫描：无命中。
- `git diff --check`：通过，无输出。

未执行：

- 未跑本机 Xcode build / XCTest / UI test / 模拟器 / Probe / Smoke / Full；按 `md/test/test.md` 当前规范，这些重验证需云端或人工授权。

遗留风险：

- 本轮未运行 AI 回合、方面总管生成链、directive 编译执行链或多势力自动回合。
- 单文件 Swift parse 未执行成功，因为当前容器缺少 `swiftc`。
- `AppContainer` 与 `ZoneCommanderAgent` 当时各自维护一份默认指挥风格映射；该维护风险已在 v3.7-preflight.94 通过共享 helper 收口。

## v3.7-preflight.92 - 阶段与旧总管展示口径收口

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在指令结果语义化固守判定收口之后，继续处理两个低风险可见口径残留：通用自动行动阶段仍显示 `AI`，legacy `general_agents.json` 兼容配置仍带旧人物专名。本轮只改展示名和文档，不改变回合 rawValue、legacy id、势力 rawValue、单位 id、AI 决策、命令管线、规则执行或存档格式。

核心更新：

- `GamePhase.displayName` 的 `.germanAI` / `.aiCommand` 展示从 `AI 行动` / `AI 军令` 改为 `朝堂行动` / `朝堂军令`。
- `general_agents.json` 中 legacy `guderian` 配置的展示名从 `古德里安` 改为 `历史总管`。
- 保留 `guderian` id、`.germany` rawValue、legacy `ger_*` assigned division id 和 `breakthrough` command style，用于旧数据兼容与校验。
- 新增阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_phase_legacy_agent_display_record.md`，同步 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Core/GamePhase.swift`
- `WWIIHexV0/Data/general_agents.json`
- `md/prompt/v3.0-隋唐迁移/v3.7_phase_legacy_agent_display_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `command -v swiftc`：无输出，当前容器缺少 `swiftc`，未能执行 Swift 单文件语法检查。
- `command -v jq`：无输出，当前容器缺少 `jq`。
- `node -e 'JSON.parse(require("fs").readFileSync("WWIIHexV0/Data/general_agents.json", "utf8")); console.log("json ok")'`：通过，输出 `json ok`。
- 聚焦扫描 `AI 行动` / `AI 军令` / `"name": "古德里安"`：改动文件中不再命中。
- 本轮改动文件尾随空白扫描：无命中。
- 本轮改动文件冲突标记扫描：无命中。
- `git diff --check`：通过，无输出。

未执行：

- 未跑本机 Xcode build / XCTest / UI test / 模拟器 / Probe / Smoke / Full；按 `md/test/test.md` 当前规范，这些重验证需云端或人工授权。

遗留风险：

- 本轮未启动主游戏、HUD、开局引导、命令面板或 legacy prompt 路径，展示效果仍需云端构建或人工授权运行时验证确认。
- legacy objective 展示名 fallback 和 `MarshalFrontSummary.status` 字符串逻辑仍未收口，后续可作为规则/AI 结构补洞继续处理。

## v3.7-preflight.91 - 指令结果语义化固守判定收口

完成日期：2026-07-07

性质：完整 v3.7 发布候选前置补洞。在命令与 AI 诊断文案多轮中文化之后，继续处理一处逻辑仍反向依赖旧英文展示名的问题。本轮让命令结果记录携带独立命令语义，避免 `ZoneCommanderAgent` 用 `Hold` 展示文本判断上一轮静态防御。

核心更新：

- `CommandResultSummary` 新增可选 `CommandSummaryKind` 字段，新生成的 AI order、directive command、system command 和 end turn 结果会记录命令语义。
- `ZoneCommanderAgent.hasRecentStaticDefense` 改为判断 `summary.commandKind == .hold`，不再依赖 `commandDisplayName?.hasPrefix("Hold")`。
- 保留 `commandDisplayName` 只作 UI 展示；旧存档缺少 `commandKind` 时 Codable 可按 optional 字段兼容。
- 未新增 Swift 文件，未修改 `WWIIHexV0.xcodeproj/project.pbxproj`。

关键文件：

- `WWIIHexV0/Agents/AgentDecisionRecord.swift`
- `WWIIHexV0/Agents/ZoneCommanderAgent.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_command_result_semantic_kind_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse WWIIHexV0/Agents/AgentDecisionRecord.swift`：通过，无输出。
- `swiftc -parse WWIIHexV0/Agents/ZoneCommanderAgent.swift`：通过，无输出。
- 聚焦扫描 `hasPrefix("Hold")` / `commandDisplayName?.hasPrefix` / `summary.commandKind == .hold` / `CommandSummaryKind`：改动源码中不再命中展示文本前缀判断，只剩 `commandKind` 定义、写入、兼容解码和 `.hold` 语义判断。
- 本轮改动文件尾随空白扫描：无命中。
- 本轮改动文件冲突标记扫描：无命中。
- `git diff --check`：通过，无输出。

未执行：

- 未跑本机 Xcode build / XCTest / UI test / 模拟器 / Probe / Smoke / Full；按 `md/test/test.md` 当前规范，这些重验证需云端或人工授权。

遗留风险：

- 本轮未运行 AI 回合、directive 编译执行链或多回合静态防御场景；命令结果语义字段的运行时效果仍需云端构建或人工授权重验证确认。

## v3.7-preflight.90 - 共享隋唐胜负 evaluator 收口

完成日期：2026-07-07

性质：完整 v3.7 发布候选前置补洞。在 `RegionVictoryRules` 隋唐胜负摘要对齐之后，继续处理 `VictoryRules` 与 `RegionVictoryRules` 各自维护 `wude_618` 胜负判断的分叉风险。本轮抽出共享只读 evaluator，不改变 objective id、地图数据、胜负阈值、回合推进、命令管线、AI 决策或存档格式。

核心更新：

- `VictoryState.swift` 新增 `VictoryAssessment`，用于表达只读胜负评估结果。
- `VictoryRules.swift` 新增规则层 `Wude618VictoryEvaluator`，集中维护默认隋唐剧本洛阳、洛口仓、潼关和终局长安胜负判断。
- `VictoryState.apply(_:)` 负责把只读评估结果写回主胜负状态。
- `VictoryRules` 的 `wude_618` 分支改为调用共享 evaluator 后写入 `GameState.victoryState`。
- `RegionVictoryRules` 的 `wude_618` 分支改为复用同一个 evaluator，`RegionVictoryAssessment` 改为 `VictoryAssessment` 的 typealias。
- 未新增 Swift 文件，未修改 `WWIIHexV0.xcodeproj/project.pbxproj`。

关键文件：

- `WWIIHexV0/Core/VictoryState.swift`
- `WWIIHexV0/Rules/VictoryRules.swift`
- `WWIIHexV0/Rules/RegionVictoryRules.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_shared_victory_evaluator_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse WWIIHexV0/Core/VictoryState.swift`：通过，无输出。
- `swiftc -parse WWIIHexV0/Rules/VictoryRules.swift`：通过，无输出。
- `swiftc -parse WWIIHexV0/Rules/RegionVictoryRules.swift`：通过，无输出。
- 聚焦扫描共享 evaluator 和两条调用路径：`wude_618` 胜负判断只剩 `Wude618VictoryEvaluator` 一处实现。
- 本轮改动文件尾随空白扫描：无命中。
- 本轮改动文件冲突标记扫描：无命中。
- `git diff --check`：通过，无输出。

未执行：

- 未跑本机 Xcode build / XCTest / UI test / 模拟器 / Probe / Smoke / Full；按 `md/test/test.md` 当前规范，这些重验证需云端或人工授权。

遗留风险：

- 本轮未运行默认隋唐剧本、旧 fallback 剧本或 region 分析调用链。
- 单文件 parse 只覆盖语法，不等同于 Xcode 构建；共享 evaluator 的跨文件类型引用仍需云端构建或人工授权重验证确认。

## v3.7-preflight.89 - RegionVictoryRules 隋唐胜负摘要对齐

完成日期：2026-07-07

性质：完整 v3.7 发布候选前置补洞。在 legacy objective lookup 字面量收口之后，继续处理 `RegionRuleSystem.analyze(_:)` 所使用的 `RegionVictoryRules` 仍只返回 legacy 胜负摘要的问题。本轮只改 region 分析层的胜负摘要口径，不改变主 `VictoryRules.updateVictoryState(in:)` 执行路径、`GameState.victoryState`、胜负阈值、命令管线或存档格式。

核心更新：

- `RegionVictoryRules.assessVictory(in:)` 按 `scenarioId` 分支，默认 `wude_618_guanzhong_luoyang` 走隋唐摘要评估。
- 隋唐摘要按 `obj_luoyang`、`obj_luokou`、`obj_tongguan`、`obj_changan` objective id 评估唐胜、洛阳隋胜和终局长安结算。
- legacy fallback 摘要下沉到 `assessLegacyFallbackVictory(in:)`，继续保留旧 objective id 和中性旧战局目标名兼容。
- 新增阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_region_victory_suitang_alignment_record.md`，同步 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Rules/RegionVictoryRules.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_region_victory_suitang_alignment_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse WWIIHexV0/Rules/RegionVictoryRules.swift`：通过，无输出。
- 聚焦扫描 `RegionVictoryRules.swift` 中旧战役可见地名字面量：无命中。
- 本轮改动文件尾随空白扫描：无命中。
- 本轮改动文件冲突标记扫描：无命中。
- `git diff --check`：通过，无输出。

未执行：

- 未跑本机 Xcode build / XCTest / UI test / 模拟器 / Probe / Smoke / Full；按 `md/test/test.md` 当前规范，这些重验证需云端或人工授权。

遗留风险：

- 本轮未运行 region 分析调用链，未验证默认隋唐剧本或旧 fallback 剧本的运行时摘要展示；`RegionVictoryRules` 与 `VictoryRules` 重复维护 `wude_618` 胜负判断的问题已在 v3.7-preflight.90 收口。

## v3.7-preflight.88 - legacy objective lookup 字面量收口

完成日期：2026-07-07

性质：完整 v3.7 发布候选前置补洞。在静态 `GameState` / `MapState` fallback 可见文本收口之后，继续处理 legacy 胜负规则和旧 MockAI 回归路径中的旧战役 objective 名称查找字面量。本轮只改私有函数名、局部变量和 fallback 查找文本，不改变 objective id、胜负阈值、AI 行动策略、命令管线、规则执行或存档字段。

核心更新：

- `VictoryRules` 的旧 fallback 胜负分支改名为 `updateLegacyFallbackVictoryState`，目标查找改为 legacy objective id 优先，并只 fallback 到中性“旧战局要地甲 / 旧战局要地乙”。
- `RegionVictoryRules` 的旧 region 胜负评估同样按 objective id 优先，再按中性旧战局城邑名兼容。
- `MockAIClient` 的旧回归主目标查找按 `bastogne` objective id 优先，再按中性“旧战局要地甲”兼容；注释和本轮触及局部变量去旧战役地名口径。
- 新增阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_legacy_objective_lookup_text_record.md`，同步 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Rules/VictoryRules.swift`
- `WWIIHexV0/Rules/RegionVictoryRules.swift`
- `WWIIHexV0/Agents/MockAIClient.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_legacy_objective_lookup_text_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse WWIIHexV0/Rules/VictoryRules.swift`：通过，无输出。
- `swiftc -parse WWIIHexV0/Rules/RegionVictoryRules.swift`：通过，无输出。
- `swiftc -parse WWIIHexV0/Agents/MockAIClient.swift`：通过，无输出。
- 聚焦扫描 `VictoryRules.swift`、`RegionVictoryRules.swift`、`MockAIClient.swift` 中旧战役可见地名字面量：不再命中；剩余 `germanBastogneHeldSinceTurn` 属于 `VictoryState` 兼容字段访问，不是本轮可见文本。
- 本轮改动文件尾随空白扫描：无命中。
- 本轮改动文件冲突标记扫描：无命中。
- `git diff --check`：通过，无输出。

未执行：

- 未跑本机 Xcode build / XCTest / UI test / 模拟器 / Probe / Smoke / Full；按 `md/test/test.md` 当前规范，这些重验证需云端或人工授权。

遗留风险：

- 本轮未启动游戏、MapEditor 或旧 fallback 剧本，未验证 legacy 胜负和旧 MockAI 路径运行时表现。
- `VictoryState` 兼容字段名、`VictoryReason` legacy case、`bastogne` / `st_vith` objective id、`.germany` / `.allies` rawValue 仍按存档与 schema 合同保留。

## v3.7-preflight.87 - 静态 fallback 源码可见文本收口

完成日期：2026-07-07

性质：完整 v3.7 发布候选前置补洞。在源码层 legacy 可见兜底文本收口之后，继续按并发复扫结论处理 `DataLoader.loadInitialGameState()` 最后兜底会进入的静态 `GameState.initial()` 和 `MapState.ardennesV0()` 可见文本。本轮只改静态 fallback 的展示名和初始化战报，不改变 scenario id、objective id、faction、坐标、地形、补给源、胜负规则、加载顺序、命令管线或存档字段。

核心更新：

- `GameState.initial()` 的最后兜底单位名改为中性旧战局东路/西路军队口径。
- `GameState.initial()` 的初始化战报改为“旧战局 fallback 已初始化。”。
- `MapState.ardennesV0()` 的最后兜底城邑、要塞和 objective 展示名改为中性旧战局口径。
- 新增阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_legacy_static_fallback_source_text_record.md`，同步 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Core/GameState.swift`
- `WWIIHexV0/Core/MapState.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_legacy_static_fallback_source_text_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse WWIIHexV0/Core/GameState.swift`：通过，无输出。
- `swiftc -parse WWIIHexV0/Core/MapState.swift`：通过，无输出。
- 聚焦扫描 `GameState.swift`、`MapState.swift` 中旧题材可见字符串：无命中。
- 本轮改动文件尾随空白扫描：无命中。
- 本轮改动文件冲突标记扫描：无命中。
- `git diff --check`：通过，无输出。

未执行：

- 未跑本机 Xcode build / XCTest / UI test / 模拟器 / Probe / Smoke / Full；按 `md/test/test.md` 当前规范，这些重验证需云端或人工授权。

遗留风险：

- 本轮未启动游戏或 MapEditor，未验证最后兜底实际加载和地图渲染路径。
- 规则兼容查找中的旧战役地名字面量已在 v3.7-preflight.88 收口；仍需保留 legacy objective id、`VictoryState` 字段和 enum case 兼容。

## v3.7-preflight.86 - 源码层 legacy 可见兜底文本收口

完成日期：2026-07-07

性质：完整 v3.7 发布候选前置补洞。在 fallback JSON 可见数据文本收口之后，继续按并发复扫结论处理源码层仍可能被 HUD、发布检查、胜负提示、MapEditor 或错误反馈直接读取的 legacy 可见兜底文本。本轮只改展示文案和校验错误描述，不改变 enum rawValue、JSON schema、id、兼容查找、胜负判定、加载顺序、命令管线、规则或存档格式。

核心更新：

- `Faction.displayName` 的 `.germany` / `.allies` 展示从旧题材势力名改为“旧剧本东路势力 / 旧剧本西路势力”。
- `VictoryReason.displayName` 的 legacy 胜负原因从旧题材目标、势力和补给描述改为中性旧战局口径。
- `DataLoader.validate(...)` 中旧战局补给源和旧代理配置错误改为中性描述，保留 `guderian` id 查找和 legacy schema 兼容。
- 新增阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_legacy_source_fallback_visible_text_record.md`，同步 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Core/Faction.swift`
- `WWIIHexV0/Core/VictoryState.swift`
- `WWIIHexV0/Data/DataLoader.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_legacy_source_fallback_visible_text_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse WWIIHexV0/Core/Faction.swift`：通过，无输出。
- `swiftc -parse WWIIHexV0/Core/VictoryState.swift`：通过，无输出。
- `swiftc -parse WWIIHexV0/Data/DataLoader.swift`：通过，无输出。
- 聚焦扫描 `Faction.swift`、`VictoryState.swift`、`DataLoader.swift` 中旧题材可见词：剩余命中为类型名、enum case、函数名、兼容 id 或注释，不是本轮展示字符串。
- 本轮改动文件尾随空白扫描：无命中。
- 本轮改动文件冲突标记扫描：无命中。
- `git diff --check`：通过，无输出。

未执行：

- 未跑本机 Xcode build / XCTest / UI test / 模拟器 / Probe / Smoke / Full；按 `md/test/test.md` 当前规范，这些重验证需云端或人工授权。

遗留风险：

- 本轮未启动游戏或 MapEditor，未验证 HUD、发布检查、胜负提示或错误反馈实际渲染路径。
- 仍需继续复扫静态 `GameState` / `MapState` fallback、MapEditor legacy metadata 和其他源码注释外的可见文本路径。

## v3.7-preflight.85 - fallback JSON 可见数据文本收口

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在将领档案和总管军令称谓净化对齐之后，继续按并发子 Agent 复扫结论收口 legacy fallback JSON 数据自身可能直出的可见展示字段。本轮只改 fallback JSON 的展示文本，不改变 JSON key、id、rawValue、schema、坐标、faction、templateId、加载顺序、命令管线、规则或存档格式。

核心更新：

- `ardennes_v0_scenario.json` 的场景名、dataNotes、初始单位名、keyLocations 名称和 map `cityName` 改为中性旧战局口径。
- `ardennes_v02_regions.json` 的数据集名、region 名和 city 名补齐中性展示文本。
- `unit_templates.json` 的 legacy 单位模板 `displayName` 改为甲骑军、骑军、步卒军、弓弩军、拒马弩军和守军。
- `generals.json` 的 legacy 将领可见 `name`、`localizedName`、`rank` 和 `biography` 改为迁移期中性总管称谓。
- 新增阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_legacy_fallback_json_visible_data_text_record.md`，同步 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Data/ardennes_v0_scenario.json`
- `WWIIHexV0/Data/ardennes_v02_regions.json`
- `WWIIHexV0/Data/unit_templates.json`
- `WWIIHexV0/Data/generals.json`
- `md/prompt/v3.0-隋唐迁移/v3.7_legacy_fallback_json_visible_data_text_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `jq empty WWIIHexV0/Data/ardennes_v0_scenario.json`：通过，无输出。
- `jq empty WWIIHexV0/Data/ardennes_v02_regions.json`：通过，无输出。
- `jq empty WWIIHexV0/Data/unit_templates.json`：通过，无输出。
- `jq empty WWIIHexV0/Data/generals.json`：通过，无输出。
- 聚焦扫描四个改动 JSON 的可见字段 legacy 残留：无命中。
- 本轮改动文件尾随空白扫描：无命中。
- 本轮改动文件冲突标记扫描：无命中。
- `git diff --check`：通过，无输出。

未执行：

- 未跑本机 Xcode build / XCTest / UI test / 模拟器 / Probe / Smoke / Full；按 `md/test/test.md` 当前规范，这些重验证需云端或人工授权。

遗留风险：

- 本轮未启动游戏、MapEditor 或 UI，未验证 fallback JSON 实际加载渲染路径。
- 并发复扫仍发现 `Faction.displayName`、`VictoryReason.displayName`、`DataLoader` 校验错误、静态 `GameState` / `MapState` fallback 等可见兜底残留，建议下一轮继续按同样边界小步收口。

## v3.7-preflight.84 - 将领档案/总管军令称谓净化对齐

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在源头 legacy 中文势力/国家/地名展示净化之后，继续按主线程扫描结论收口将领档案和总管军令面板中与 `.82` 不一致的 legacy 称谓。本轮只改展示净化和 fallback 展示名，不改变 `GeneralData`、`Division.name`、`AgentRole` rawValue、JSON、命令管线、规则或存档格式。

核心更新：

- `GeneralProfileView.displayGeneralRank(_:)` 与 `GeneralCommandPanelView.displayGeneralRank(_:)` 的 `Field Marshal` 展示统一为“行军总管”。
- `GeneralProfileView` 与 `GeneralCommandPanelView` 的 `Guderian / 古德里安` 展示统一为“历史总管”。
- 两个将领相关面板的空单位名 fallback 改用 legacy 势力展示净化，避免旧数据缺单位名时直出旧势力显示。
- 新增阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_general_panel_title_sanitizer_record.md`，同步 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/UI/GeneralProfileView.swift`
- `WWIIHexV0/UI/GeneralCommandPanelView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_general_panel_title_sanitizer_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse WWIIHexV0/UI/GeneralProfileView.swift`：通过，无输出。
- `swiftc -parse WWIIHexV0/UI/GeneralCommandPanelView.swift`：通过，无输出。
- 聚焦扫描 `.84` 文档状态、`Field Marshal` / `Guderian` / `古德里安` / “旧剧本将领” / “行军大总管”：符合预期，源码剩余命中为净化词表左侧，文档旧名命中为历史版本记录。
- 本轮改动文件尾随空白扫描：无命中。
- 本轮改动文件冲突标记扫描：无命中。
- `git diff --check`：通过，无输出。

未执行：

- 未跑本机 Xcode build / XCTest / UI test / 模拟器 / Probe / Smoke / Full；按 `md/test/test.md` 当前规范，这些重验证需云端或人工授权。

遗留风险：

- 本轮未运行将领档案或总管军令 UI，未验证实际渲染路径。
- 展示净化 helper 仍分散在多个面板，后续可抽共享 sanitizer。

## v3.7-preflight.83 - 源头 legacy 中文势力/国家/地名展示净化收口

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在行军总管可见称谓净化收口之后，继续按并发子 Agent 复扫结论收口源头诊断、外交摘要和战报消息中仍可能出现的 legacy 中文势力、旧国家、旧地名、旧单位词和英文工程/角色词。本轮只改源头展示文本和净化词表，不改变数据、rawValue、record id、Codable schema、命令管线、规则或存档格式。

核心更新：

- `TurnManager.userFacingDiagnostic` 补齐 legacy 中文势力、旧国家、旧地名、旧单位词和英文势力词净化，覆盖自动回合失败、方面军令诊断和错误兜底展示。
- `DiplomacyState` 的外交事件、归附交接、善后压力和善后处置摘要改走现有 `displayFactionName(_:)` helper。
- `DiplomacyState.displayCountryName(_:)` 补齐 `旧剧本德方 / 美方 / 英方` 中文旧国家名净化。
- `GameLogEntry.sanitizedMessage(_:)` 补齐 `Guderian`、`Field Marshal`、`Germany`、`Allies`、`rawJSON`、`schema`、`provider` 等源头战报净化。
- 新增阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_source_legacy_chinese_text_sanitizer_record.md`，同步 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Turn/TurnManager.swift`
- `WWIIHexV0/Core/DiplomacyState.swift`
- `WWIIHexV0/Core/GameLogEntry.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_source_legacy_chinese_text_sanitizer_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse WWIIHexV0/Turn/TurnManager.swift`：通过，无输出。
- `swiftc -parse WWIIHexV0/Core/DiplomacyState.swift`：通过，无输出。
- `swiftc -parse WWIIHexV0/Core/GameLogEntry.swift`：通过，无输出。
- 聚焦扫描 `.83` 文档记录、源头 legacy 中文势力/国家/地名、英文角色/势力词和工程词：符合预期，剩余命中为净化词表、结构化字段或兼容存储值。
- 本轮改动文件尾随空白扫描：无命中。
- 本轮改动文件冲突标记扫描：无命中。
- `git diff --check`：通过，无输出。

未执行：

- 未跑本机 Xcode build / XCTest / UI test / 模拟器 / Probe / Smoke / Full；按 `md/test/test.md` 当前规范，这些重验证需云端或人工授权。

遗留风险：

- 本轮未运行 AI 回合或外交/战报 UI，未验证所有运行时展示路径。
- 展示净化 helper 仍分散在多个文件，后续可抽共享 sanitizer，但本轮为降低脏工作区冲突面没有做共享抽象。

## v3.7-preflight.82 - 行军总管可见称谓净化收口

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在朝堂/外交实际记录 id 展示净化之后，继续按并发子 Agent 扫描结论收口 UI 和角色展示层残留的“元帅 / Field Marshal / Guderian”旧口径。本轮只改展示层文案、展示净化词表和角色 `displayName`，不改变 `AgentRole.fieldMarshal` rawValue、`MarshalDirective` provider suffix、record id、Codable schema、JSON 数据、AI 决策、命令管线、规则或存档格式。

核心更新：

- `AgentPanelView` 的 `MarshalDirective` 来源显示从“元帅军议”改为“军议”。
- `AgentPanelView`、`EventLogView`、`DiplomacyPanelView` 的 `Field Marshal` 展示净化统一为“行军总管”。
- `DiplomacyPanelView` 的裸 `Guderian` 展示从“古德里安”改为“历史总管”。
- `CommandPanelView` 和 `EventLogView` 补齐 `directive_*command_*`、`order_*` 和朝堂 agent 前缀记录的展示净化。
- `AgentRole.fieldMarshal.displayName` 改为“行军总管”，保留 rawValue 兼容。
- 新增阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_marshal_visible_title_sanitizer_record.md`，同步 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/UI/AgentPanelView.swift`
- `WWIIHexV0/UI/EventLogView.swift`
- `WWIIHexV0/UI/DiplomacyPanelView.swift`
- `WWIIHexV0/UI/CommandPanelView.swift`
- `WWIIHexV0/Agents/GameAgent.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_marshal_visible_title_sanitizer_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse WWIIHexV0/UI/AgentPanelView.swift`：通过，无输出。
- `swiftc -parse WWIIHexV0/UI/EventLogView.swift`：通过，无输出。
- `swiftc -parse WWIIHexV0/UI/DiplomacyPanelView.swift`：通过，无输出。
- `swiftc -parse WWIIHexV0/UI/CommandPanelView.swift`：通过，无输出。
- `swiftc -parse WWIIHexV0/Agents/GameAgent.swift`：通过，无输出。
- 聚焦扫描 `.82` 文档状态、`Field Marshal` / `Guderian` / “元帅军议”可见称谓和 `directive_*command_*` / `order_*` / agent 前缀净化：符合预期，剩余命中为净化词表或注释。
- 尾随空白扫描：无命中。
- 冲突标记扫描：无命中。
- `git diff --check`：通过，无输出。

未执行：

- 未跑本机 Xcode build / XCTest / UI test / 模拟器 / Probe / Smoke / Full；按 `md/test/test.md` 当前规范，这些重验证需云端或人工授权。

遗留风险：

- 本轮未运行 UI 或 AI 回合，未验证所有运行时展示路径。
- `MarshalDirective`、`fieldMarshal` 等内部名仍作为 provider / rawValue / schema 合同保留。
- 展示净化 helper 仍重复维护，后续可抽共享 sanitizer。

## v3.7-preflight.81 - 朝堂/外交实际记录 id 展示净化收口

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在 legacy fallback 行军总管配置收口之后，继续按并发子 Agent 扫描结论补齐 `RulerAgent` / `CourtAgent` / `DiplomacyState` 实际记录 id 与展示净化词表不一致的问题。本轮只改展示净化、源头战报 message、prompt 输入和外交摘要文案，不改变记录 id 生成格式、Codable 字段、`relatedRecordId`、raw JSON 审计合同、外交关系判定、命令管线、规则或存档 schema。

核心更新：

- `TurnManager` 让 `courtRecord.summary` 进入 `parsedIntent` 和“朝堂决策完成”战报事件前先走展示净化。
- `canonicalCourtDirectiveJSON` 的朝堂步骤摘要改用展示净化文本，保留 directive JSON 结构化审计合同。
- `TurnManager`、`AgentPanelView`、`DiplomacyPanelView`、`EventLogView`、`CommandPanelView`、`GameLogEntry` 和 `AgentPromptBuilder` 的净化词表补齐真实 `ruler_*_turn_*`、`court_*_turn_*`、`court_<turn>_*` 和 `diplomacy_<turn>_*` 记录 id。
- `DiplomacyState.summary(for:)` 把“敌对关系 N 条”修正为“敌对国家 N 个”，匹配 `hostileCountryIds(to:)` 的实际去重国家计数。
- legacy `.germany` / `.allies` 和常见旧国家名在外交摘要中使用中性展示口径。
- 新增阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_court_diplomacy_record_id_sanitizer_record.md`，同步 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Turn/TurnManager.swift`
- `WWIIHexV0/Core/DiplomacyState.swift`
- `WWIIHexV0/UI/AgentPanelView.swift`
- `WWIIHexV0/UI/DiplomacyPanelView.swift`
- `WWIIHexV0/UI/EventLogView.swift`
- `WWIIHexV0/UI/CommandPanelView.swift`
- `WWIIHexV0/Core/GameLogEntry.swift`
- `WWIIHexV0/Agents/AgentPromptBuilder.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_court_diplomacy_record_id_sanitizer_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse WWIIHexV0/Turn/TurnManager.swift`：通过，无输出。
- `swiftc -parse WWIIHexV0/Core/DiplomacyState.swift`：通过，无输出。
- `swiftc -parse WWIIHexV0/UI/AgentPanelView.swift`：通过，无输出。
- `swiftc -parse WWIIHexV0/UI/DiplomacyPanelView.swift`：通过，无输出。
- `swiftc -parse WWIIHexV0/UI/EventLogView.swift`：通过，无输出。
- `swiftc -parse WWIIHexV0/UI/CommandPanelView.swift`：通过，无输出。
- `swiftc -parse WWIIHexV0/Core/GameLogEntry.swift`：通过，无输出。
- `swiftc -parse WWIIHexV0/Agents/AgentPromptBuilder.swift`：通过，无输出。
- 聚焦扫描 `.81` 文档状态、实际记录 id 净化 regex 和“敌对关系”旧文案：符合预期，旧文案仅保留在本轮修正说明中。
- 尾随空白扫描：无命中。
- 冲突标记扫描：无命中。
- `git diff --check`：通过，无输出。

未执行：

- 未跑本机 Xcode build / XCTest / UI test / 模拟器 / Probe / Smoke / Full；按 `md/test/test.md` 当前规范，这些重验证需云端或人工授权。

遗留风险：

- 本轮未运行 AI 回合，未验证朝堂 / 外交记录在真实多回合 UI 中的所有展示路径。
- 多个展示净化 helper 仍重复维护；为降低当前脏工作区冲突面，本轮没有抽共享 sanitizer。
- `rawJSON` 仍保留结构化审计原文，不承诺完全去工程字段。

## v3.7-preflight.80 - legacy fallback 行军总管配置收口

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在 legacy LocalLLM prompt 临时编号别名收口之后，继续按并发子 Agent 扫描结论收口旧 fallback 指挥官 / 元帅配置中的二战人物、旧势力词、旧 `marshal_*` 前缀和诊断文案。本轮只改 fallback 配置和可见诊断口径，不改变 `ZoneCommanderAgentConfig`、`MarshalAgentConfig`、`MarshalBattlefieldSummary`、`MarshalLLMClient`、`DirectiveEnvelope`、`TheaterDirectiveEnvelope` 字段结构或函数签名，不改变 `Faction` enum、JSON 数据、`Command` / `ZoneDirective` / `WarCommandExecutor` / `RuleEngine` 管线或存档格式。

核心更新：

- `GameAgent.guderian(from:state:)` 不再把旧 `guderian` 定义直接作为运行 agent 返回，而是迁移为本地行军总管 fallback。
- `guderianFallback` 不再硬编码 `id: "guderian"`、古德里安、`.germany` 和 `ger_*` 默认单位 id。
- `MarshalAgentConfig.automatic` 的 `.germany` / `.allies` legacy 分支改为中性“旧剧本势力行军总管”配置，不再输出伦德施泰特、艾森豪威尔或盟军人格文案。
- `TheaterCommanderPool` fallback 总管名称和 context summary 避免直接使用 legacy faction display name。
- `SimulatedMarshalLLMClient` 生成的 directive id 前缀从 `marshal_` 改为 `command_`，rationale 改为“模拟军议”口径。
- `MarshalAgent.resolve` 和 `TurnManager` 的可见诊断把“元帅军令 / 元帅军议”收口为“军议 / 行军总管”口径。
- 新增阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_legacy_marshal_fallback_config_record.md`，同步 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Agents/AgentConfiguration.swift`
- `WWIIHexV0/Agents/ZoneCommanderAgent.swift`
- `WWIIHexV0/Turn/TurnManager.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_legacy_marshal_fallback_config_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse WWIIHexV0/Agents/AgentConfiguration.swift`：通过，无输出。
- `swiftc -parse WWIIHexV0/Agents/ZoneCommanderAgent.swift`：通过，无输出。
- `swiftc -parse WWIIHexV0/Turn/TurnManager.swift`：通过，无输出。

未执行：

- 未跑本机 Xcode build / XCTest / UI test / 模拟器 / Probe / Smoke / Full；按 `md/test/test.md` 当前规范，这些重验证需云端或人工授权。

遗留风险：

- 本轮未运行 AI 回合，未验证 fallback 行军总管在 legacy 阿登和默认隋唐剧本中的运行时行为。
- `RulerAgent` / `CourtDecisionRecord` 的 court step summary、`ruler_*` / `court_*` / `diplomacy_*` 实际 id 净化仍需下一轮继续收口。
- JSON 字段名和内部 id 仍保留为审计/解析合同；本轮只处理可见配置与诊断口径。

## v3.7-preflight.79 - legacy LocalLLM prompt 临时编号别名收口

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在 GameLogEntry 源头战报 legacy 文案收口之后，继续按并发子 Agent 扫描结论收口旧 `AgentPromptBuilder` 面向 LocalLLM 的 prompt 输入风险。本轮只改旧 LocalLLM prompt 构造与解析后别名回填，不改变默认战争 AI 主链路、`AgentDecisionEnvelope` / `AgentOrder` schema、JSON 字段名、`AgentOrderType` rawValue、parser 支持版本、命令结构、`AgentCommandMapper`、规则系统或存档格式。

核心更新：

- `AgentPromptBuilder` 的系统 prompt 势力名改走展示净化，legacy `.germany` / `.allies` 显示为“旧剧本势力”。
- 战场摘要中的目标、己方军队、敌军、可见州郡和编号旁说明名改走 prompt 局部展示 helper。
- `sanitizePromptText(_:)` 补齐 legacy 势力名、旧地名、旧题材单位词、模型/工程词和 `objective_*` raw id 的净化。
- 新增 `AgentPromptAliasBook`，把 prompt 内可选取的 `divisionId` / `targetDivisionId` / `toRegionId` / `agentId` 值显示为“军队一 / 敌军一 / 州郡一 / 本地决策者”等临时编号。
- `LocalLLMDecisionProvider` 在解析 LLM JSON 后用同一本别名表回填真实 id，再交给既有 mapper。
- 新增阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_agent_prompt_alias_sanitizer_record.md`，同步 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Agents/AgentPromptBuilder.swift`
- `WWIIHexV0/Agents/LocalLLMDecisionProvider.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_agent_prompt_alias_sanitizer_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse WWIIHexV0/Agents/AgentPromptBuilder.swift`：通过，无输出。
- `swiftc -parse WWIIHexV0/Agents/LocalLLMDecisionProvider.swift`：通过，无输出。

未执行：

- 未跑本机 Xcode build / XCTest / UI test / 模拟器 / Probe / Smoke / Full；按 `md/test/test.md` 当前规范，这些重验证需云端或人工授权。

遗留风险：

- 本轮未实际调用 LocalLLM，未验证模型是否稳定返回临时编号。
- JSON 字段名和命令 type 原值仍保留为解析合同；若未来要求 LLM 完全不可见工程字段，需要引入更大的工具协议 / adapter 层。
- `ZoneCommanderAgent` fallback config、`AgentConfiguration` legacy fallback 指挥官和 `RulerAgent` 朝堂 step 记录仍需下一轮继续收口。

## v3.7-preflight.78 - GameLogEntry 源头战报 legacy 文案收口

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在 AppContainer 交互日志与存档反馈 legacy 文案收口之后，继续按并发子 Agent 扫描结论收口 Rules / Commands / Data / Core 等源头写入 `GameState.eventLog` 时的 legacy 势力名、旧地名、旧单位词和 raw id 直出风险。本轮只改 `GameLogEntry` 消息初始化入口和文档，不改变 `GameState.eventLog` 字段结构、`GameLogEntry` schema、`relatedRecordId` 合同、规则数值、命令执行、`Command` / `ZoneDirective`、`Division.name`、`RegionNode.name`、`FrontZone.name`、JSON、id / rawValue、AI 决策或存档格式。

核心更新：

- `GameLogEntry.init(...)` 对传入 `message` 做源头展示净化后再保存到 `message`。
- 净化覆盖常见审计 id、region / theater / front zone / objective / hex / division / unit / command / agent raw id。
- 净化覆盖 legacy 势力显示“德军（旧）/ 盟军（旧）/ 德军 / 盟军”。
- 净化覆盖旧地名和旧题材单位词：`阿登`、`巴斯托涅`、`圣维特`、`Ardennes`、`Bastogne`、`St. Vith`、`St Vith`、`Sedan`、`装甲`、`摩托化`、`炮兵`、`步兵`、`反装甲`。
- 不全局替换单字“师”，避免误伤“军师”等普通文本；只替换明确旧兵种词。
- 新增阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_event_log_source_sanitizer_record.md`，同步 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Core/GameLogEntry.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_event_log_source_sanitizer_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse WWIIHexV0/Core/GameLogEntry.swift`：通过，无输出。
- 定向残留扫描：`GameLogEntry.swift` 中 legacy 地名、旧势力词和 raw id 前缀只命中 sanitizer 词表或正则。
- `appendEvent` / `GameLogEntry(...)` 创建点扫描：Rules / Commands / Data / Core 写入战报的路径均进入 `GameLogEntry.init(...)`。
- 本轮改动文件尾随空白扫描：无命中。
- 本轮改动文件行首冲突标记扫描：无命中。
- `git diff --check`：通过，无输出。

未执行：

- 未跑本机 Xcode build / XCTest / UI test / 模拟器 / Probe / Smoke / Full；按 `md/test/test.md` 当前规范，这些重验证需云端或人工授权。

遗留风险：

- 本轮未做运行时战报面板、存档读取后旧日志展示、战斗 / 补给 / 经济 / 外交事件实际渲染或云端 artifact 验收，实际显示仍待授权构建/启动或云端流程确认。
- `AgentPromptBuilder` prompt 输入、`ZoneCommanderAgent` fallback config 与 `RulerAgent` 朝堂 step 记录仍有玩家可见 legacy 文案复扫价值，可作为下一轮小刀继续处理。
- 若后续净化词表继续膨胀，应评估把 UI / App / Core 的展示 sanitizer 收敛为共享展示工具。

## v3.7-preflight.77 - AppContainer 交互日志与存档反馈 legacy 文案收口

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在 MapEditor 选择器与状态消息 legacy 文案收口之后，继续按并发子 Agent 和主线程扫描结论收口 `AppContainer` 交互日志、存档反馈、地图选择、军队选择和 fallback 总管名称中的 legacy 势力名、旧地名、旧单位词和 raw id 直出风险。本轮只改 AppContainer 展示 helper 和文档，不改变 `GameState`、`GameSaveStore`、`GameSaveStatus`、`GameLogEntry`、`Command` 合同、`Division.name`、`RegionNode.name`、`FrontZone.name`、JSON、id / rawValue、AI 决策、命令结构、规则执行或存档 schema。

核心更新：

- 存档载入、继续、自动保存、新局和切换执掌势力反馈中的势力名改走 `displayFactionName(_:)`，legacy `.germany` / `.allies` 显示为“旧剧本势力”。
- 军队点击日志中的 `division.name` 改走 `displayDivisionName(_:)`，清理 `division_` / `unit_` raw id 和旧“德军 / 盟军 / 装甲 / 摩托化 / 炮兵 / 步兵 / 师”口径。
- 州郡经营拒绝、地图地块选择和总管防区提交消息中的 region / front zone 名称改走 `displayMapName(_:fallback:)` 或 `displayFrontZoneName(_:)`。
- fallback 临时总管和自动总管名称中的势力 / 防区展示改走同一套 helper。
- `submit(_:)` 的交互日志不再直接使用外交 / 归附命令的 `Command.displayName`，在 AppContainer 层用 `displayCommandName(_:)` 重新净化势力展示；`Command.displayName` 合同保持不变。
- 新增阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_appcontainer_interaction_text_record.md`，同步 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/App/AppContainer.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_appcontainer_interaction_text_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse WWIIHexV0/App/AppContainer.swift`：通过，无输出。
- 定向残留扫描：`command.displayName`、`activeFaction.displayName`、`playerFaction.displayName`、`submitted.displayName`、`faction.displayName`、`zone.faction.displayName`、`division.name`、`region.name`、`zone.name` 只命中 helper 内部读取、默认分支或已净化调用。
- legacy/raw 词扫描：`AppContainer.swift` 中 legacy 地名、旧势力词和 raw id 前缀只命中 helper 词表或内部 id。
- 本轮改动文件尾随空白扫描：无命中。
- 本轮改动文件行首冲突标记扫描：无命中。
- `git diff --check`：通过，无输出。

未执行：

- 未跑本机 Xcode build / XCTest / UI test / 模拟器 / Probe / Smoke / Full；按 `md/test/test.md` 当前规范，这些重验证需云端或人工授权。

遗留风险：

- 本轮未做运行时点击、存档载入/继续、新局、切换势力、外交/归附命令日志或云端 artifact 验收，实际渲染仍待授权构建/启动或云端流程确认。
- `CommandExecutor` / `SupplyRules` / `WarCommandExecutor` / `EconomyRules` 战报源头、`AgentPromptBuilder` prompt 输入、`ZoneCommanderAgent` fallback config 与 `RulerAgent` 朝堂 step 记录仍有玩家可见 legacy 文案复扫价值，可作为下一轮小刀继续处理。

## v3.7-preflight.76 - MapEditor 选择器与状态消息 legacy 文案收口

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在 MapDisplayAdapter / SpriteKit 地图展示入口 legacy 文案收口之后，继续按并发子 Agent 和主线程扫描结论收口 MapEditor 选择器与状态消息里的 legacy 地名、旧势力词和 raw id 直出风险。本轮只改 MapEditor 展示 helper 和文档，不改变 `MapEditorDocument`、导出 JSON、id / rawValue、默认资源桥、MapEditor 存储 schema、主游戏数据加载、地图规则、AI、命令或运行时状态。

核心更新：

- `MapEditorView` 的“当前州郡”“当前方面”下拉项不再直接显示 `region.name` / `theater.name`，改为走 `MapEditorViewModel.displayName(for:)`。
- `MapEditorViewModel.displayName(for:)` 增加局部展示净化，清理常见 region / theater / objective / location / unit raw id、legacy 地名、旧势力词和旧“战区”口径。
- 创建州郡、创建方面、保存地点、删除地点的状态消息显示前先走同一展示净化。
- 原始名称仍保存在 `MapEditorDocument` 中，TextField 编辑和导出仍使用原始数据；本轮只改可见展示兜底。
- 并发只读扫描记录了后续优先项：`AgentPromptBuilder` prompt / sanitizer、`ZoneCommanderAgent` fallback marshal config、`RulerAgent` 朝堂 step、`AppContainer` 交互日志、Rules / Commands 源头战报。
- 新增阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_mapeditor_selector_status_text_record.md`，同步 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `MapEditor/MapEditorView.swift`
- `MapEditor/MapEditorViewModel.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_mapeditor_selector_status_text_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse MapEditor/MapEditorView.swift`：通过，无输出。
- `swiftc -parse MapEditor/MapEditorViewModel.swift`：通过，无输出。
- 定向残留扫描：`Text(region.name)`、`Text(theater.name)`、状态消息直接拼接原始 name、`displayName(for:)` 原样返回 document 名称均无命中。
- legacy/raw 词扫描：`MapEditorView.swift`、`MapEditorViewModel.swift` 中 legacy 地名、旧势力词和 raw id 前缀只命中 helper 词表或正则。
- 本轮改动文件尾随空白扫描：无命中。
- 本轮改动文件行首冲突标记扫描：无命中。
- `git diff --check`：通过，无输出。

未执行：

- 未跑本机 Xcode build / XCTest / UI test / 模拟器 / Probe / Smoke / Full；按 `md/test/test.md` 当前规范，这些重验证需云端或人工授权。

遗留风险：

- 本轮未做 MapEditor 运行时点击、下拉展开、导出覆盖、截图、VoiceOver 或云端 artifact 验收，实际渲染仍待授权构建/启动或云端流程确认。
- `AppContainer` 交互日志、Rules / Commands 源头战报、`AgentPromptBuilder` prompt 输入和 AI fallback 配置仍有玩家可见 legacy 文案复扫价值，可作为下一轮小刀继续处理。

## v3.7-preflight.75 - MapDisplayAdapter / SpriteKit 地图展示入口 legacy 文案收口

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在将领与总管面板 legacy 文案复扫收口之后，继续按并发子 Agent 扫描结论收口 `MapDisplayAdapter` 输出给 SpriteKit 地图标签和详情面板入口的 legacy 地名、目标名、旧势力词和 raw id 直出风险。本轮主改 adapter 展示 helper，并对 `RegionInspectorView` / `UnitInspectorView` 中既有 id 与势力名展示做局部兜底；不改变 `HexDisplayState`、`RegionInspectorState`、`UnitInspectorStrategicState` 字段结构，不改变地图 JSON、rawValue、objective id、keyLocations、`RegionNode` / `HexTile` / `Objective` 存储、动态方面 / 防区权威、AI 决策、命令结构、规则执行或存档 schema。

核心更新：

- `HexDisplayState.cityName` / `fortressName` 在 `MapDisplayAdapter.hexDisplayState` 输出前进入展示净化，避免 `HexNode` 直接画出 legacy 地名或 raw id。
- `RegionInspectorState.objectiveNames` 在 adapter 内先净化 objective name，再交给州郡详情面板。
- `RegionInspectorState.objectiveStatus` 中 legacy `Faction.displayName` 经 adapter 局部势力展示 helper 收口。
- `RegionInspectorView` / `UnitInspectorView` 对既有 region / theater / front zone id 和 legacy faction display 做局部净化兜底，避免扩展 inspector state 字段结构。
- 新增阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_map_display_adapter_spritekit_legacy_text_record.md`，同步 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/SpriteKit/MapDisplayAdapter.swift`
- `WWIIHexV0/UI/RegionInspectorView.swift`
- `WWIIHexV0/UI/UnitInspectorView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_map_display_adapter_spritekit_legacy_text_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse WWIIHexV0/SpriteKit/MapDisplayAdapter.swift`：通过，无输出。
- `swiftc -parse WWIIHexV0/UI/RegionInspectorView.swift`：通过，无输出。
- `swiftc -parse WWIIHexV0/UI/UnitInspectorView.swift`：通过，无输出。
- 定向残留扫描：`MapDisplayAdapter.swift` 不再命中 `.map(\.name)` 直接 objective name、原样 `regionName` 赋值、原样 `cityName = tile?.cityName` 或 `fortressName = tile?.fortressName` 风险。
- legacy/raw 词扫描：`MapDisplayAdapter.swift`、`RegionInspectorView.swift`、`UnitInspectorView.swift` 中 legacy 地名、旧势力词和 raw id 前缀只命中 helper 词表或正则。
- 本轮改动文件尾随空白扫描：无命中。
- 本轮改动文件行首冲突标记扫描：无命中。
- `git diff --check`：通过，无输出。

未执行：

- 未跑本机 Xcode build / XCTest / UI test / 模拟器 / Probe / Smoke / Full；按 `md/test/test.md` 当前规范，这些重验证需云端或人工授权。

遗留风险：

- 本轮未做运行时地图截图、点击、缩放、VoiceOver 或云端 artifact 验收，实际地图标签渲染仍待授权构建/启动或云端流程确认。
- 其他复合记录出口和 AI prompt / 战报跨层入口仍有玩家可见 legacy 文案复扫价值，可作为下一轮小刀继续处理。

## v3.7-preflight.74 - 将领与总管面板 legacy 文案复扫收口

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在州郡详情 legacy 地名与目标名展示收口之后，继续按并发子 Agent 扫描结论收口将领档案和总管军令面板中的 legacy 将领名、旧军阶、旧地名、旧兵种词和 raw id 直出风险。本轮只改 `GeneralProfileView` / `GeneralCommandPanelView` 展示 helper 和文档，不改变 `GeneralData`、`GeneralAssignment`、`FrontZone`、`Division.name`、`PlayerPlannedOperation`、JSON、rawValue、存档、AI 决策、命令结构、规则执行或运行时状态。

核心更新：

- `GeneralProfileView` 的将领名、军衔、履历、所属防区、所属军队和画像 accessibility 文案进入局部展示 helper。
- `GeneralCommandPanelView` 的将领名、军衔、履历、防区名、所属军队、目标州郡、预备军令目标和头像 / 查看档案 accessibility 文案进入局部展示 helper。
- 两个面板清理 `general_*`、`agent_*`、`commander_*`、`front_zone_*`、`theater_*`、`region_*`、`objective_*`、`division_*`、`unit_*` 等常见 raw id。
- legacy 词表补齐 `Heinz Guderian`、`Guderian`、`古德里安`、`Panzer`、`armor`、`breakthrough`、`Field Marshal`、`Army Commander`、`General`、`Ardennes`、`Bastogne`、`St. Vith`、`St Vith`、`Sedan`、`阿登`、`巴斯托涅`、`圣维特`、`德军`、`盟军` 和旧兵种词。
- 保留 `generalSkillDisplayName` 对 legacy skill rawValue 的兼容映射，不改 skill rawValue 或将领 registry。
- 新增阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_legacy_general_panel_record_summary_text_record.md`，同步 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/UI/GeneralProfileView.swift`
- `WWIIHexV0/UI/GeneralCommandPanelView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_legacy_general_panel_record_summary_text_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse WWIIHexV0/UI/GeneralProfileView.swift`：通过，无输出。
- `swiftc -parse WWIIHexV0/UI/GeneralCommandPanelView.swift`：通过，无输出。
- 定向残留扫描：两个面板不再命中 `Text(general.localizedName)`、`Text(general.biography)`、`Text(general.rank)`、`Label(division.name)`、`LabeledContent(division.name)`、`Text(targetRegion.name)` 或 `return targetRegion.name`。
- legacy/raw 词扫描：两个面板中 legacy 将领名、旧军阶、旧地名、旧兵种词和 raw id 前缀只命中 helper 词表、正则或 `generalSkillDisplayName` 兼容 case。
- 本轮改动文件尾随空白扫描：无命中。
- 本轮改动文件行首冲突标记扫描：无命中。
- `git diff --check`：通过，无输出。

未执行：

- 未跑本机 Xcode build / XCTest / UI test / 模拟器 / Probe / Smoke / Full；按 `md/test/test.md` 当前规范，这些重验证需云端或人工授权。

遗留风险：

- 本轮未做运行时将领档案 / 总管面板点击、截图、VoiceOver 或云端 artifact 验收，实际渲染仍待授权构建/启动或云端流程确认。
- `MapDisplayAdapter` 和其他复合记录出口仍有玩家可见 legacy 名称复扫价值，可作为下一轮小刀继续处理。

## v3.7-preflight.73 - 州郡详情 legacy 地名与目标名展示收口

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在单位详情与提示 legacy 单位名展示收口之后，继续按并发子 Agent 扫描结论收口州郡详情面板中的 legacy 地名、目标名、驻军名和 raw id 直出风险。本轮只改 `RegionInspectorView` 展示 helper 和文档，不改变 region / hex / objective / division 存储、JSON、id、rawValue、objectiveId、keyLocations、胜负规则、地图数据、AI 决策、命令结构、规则执行或运行时状态。

核心更新：

- `RegionInspectorView` 的州郡标题、城邑、当前方面、行军防区、dominant 方面 / 防区、要地列表和驻军列表不再原样显示上游名称，统一进入局部展示 helper。
- 地图名称 helper 清理 `region_*`、`theater_*`、`front_zone_*`、`obj_*`、`hex_*`、`germany_*`、`france_*`、`allied_*`、`axis_*` 等常见 raw id。
- legacy 地名 / 旧题材词表补齐 `巴斯托涅`、`圣维特`、`阿登`、`Ardennes`、`Bastogne`、`St. Vith`、`St Vith`、`Sedan`、`德军`、`盟军` 和旧“防区”口径。
- 驻军列表复用本地单位展示 helper，清理 `division_*` / `unit_*` raw id，并把旧 fallback 单位词“德军 / 盟军 / 装甲 / 摩托化 / 炮兵 / 步兵 / 师”转为迁移前置口径。
- 并发子 Agent 核对后确认本轮不改 `MapDisplayAdapter` 和 `RegionInspectorState` 合同，动态方面 / 防区权威仍由 `hexToTheater`、`hexToFrontZone` 提供。
- 新增阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_legacy_region_detail_location_objective_text_record.md`，同步 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/UI/RegionInspectorView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_legacy_region_detail_location_objective_text_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse WWIIHexV0/UI/RegionInspectorView.swift`：通过，无输出。
- 定向残留扫描：`RegionInspectorView.swift` 不再命中 `Text(state.region.name)`、`Text(state.region.city?.name`、`state.objectiveNames.joined`、`divisions.map(\.name)`、`selectedHexDynamicTheaterName ??`、`selectedHexFrontZoneName ??`、`state.theaterName ??` 或 `state.frontZoneName ??`。
- legacy/raw 词扫描：`RegionInspectorView.swift` 中 legacy 地名、旧题材词和 raw id 前缀只命中 helper 词表或正则。
- 本轮改动文件尾随空白扫描：无命中。
- 本轮改动文件行首冲突标记扫描：无命中。
- `git diff --check`：通过，无输出。

未执行：

- 未跑本机 Xcode build / XCTest / UI test / 模拟器 / Probe / Smoke / Full；按 `md/test/test.md` 当前规范，这些重验证需云端或人工授权。

遗留风险：

- 本轮未做运行时州郡详情点击、截图或辅助功能实测，实际渲染仍待授权构建/启动或云端流程确认。
- `GeneralProfileView`、`GeneralCommandPanelView`、防区展示名和其他复合记录出口仍有玩家可见 legacy 名称复扫价值，可作为下一轮小刀继续处理。

## v3.7-preflight.72 - 单位详情与提示 legacy 单位名展示收口

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在 CommandPanel 命令消息展示净化之后，继续按并发子 Agent 扫描结论收口单位详情和地图 tooltip 中的 legacy 单位名直出风险。本轮只改玩家可见展示 helper 和文档，不改变 `Division.name` 存储、JSON、templateId、rawValue、存档 schema、AI 决策、命令结构、规则执行或运行时状态。

核心更新：

- `UnitInspectorView` 的单位标题从直接显示 `division.name` 改为 `displayDivisionName(_:)`。
- `UnitTooltipView` 的可见单位标题和 `accessibilityLabel` 同步使用展示净化后的单位名，避免 VoiceOver 继续读出旧 fallback 单位名。
- 两个单位面板的本地 helper 清理 `division_*` / `unit_*` raw id，并把旧 fallback 单位词“德军 / 盟军 / 装甲 / 摩托化 / 炮兵 / 步兵 / 师”转为迁移前置展示口径。
- 保留 `ComponentType.displayName` 作为兵种显示权威，不改 `unitKindDisplayName`、兵种 rawValue、战斗数值或规则语义。
- 新增阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_legacy_unit_detail_tooltip_text_record.md`，同步 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/UI/UnitInspectorView.swift`
- `WWIIHexV0/UI/UnitTooltipView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_legacy_unit_detail_tooltip_text_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse WWIIHexV0/UI/UnitInspectorView.swift`：通过，无输出。
- `swiftc -parse WWIIHexV0/UI/UnitTooltipView.swift`：通过，无输出。
- 定向残留扫描：`UnitInspectorView.swift` 与 `UnitTooltipView.swift` 不再命中 `Text(division.name)` 或 `accessibilityLabel("\\(division.name)`。
- 本轮改动文件尾随空白扫描：无命中。
- 本轮改动文件行首冲突标记扫描：无命中。
- `git diff --check`：通过，无输出。

未执行：

- 未跑本机 Xcode build / XCTest / UI test / 模拟器 / Probe / Smoke / Full；按 `md/test/test.md` 当前规范，这些重验证需云端或人工授权。

遗留风险：

- 本轮未做运行时 tooltip 或 VoiceOver 实测，实际渲染和辅助功能播报仍待授权构建/启动或云端流程确认。
- `RegionInspectorView`、`GeneralProfileView`、`GeneralCommandPanelView` 与 `MapDisplayAdapter` 仍有玩家可见 legacy 名称复扫价值，可作为下一轮小刀继续处理。

## v3.7-preflight.71 - CommandPanel 命令消息展示净化收口

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在 legacy 将领与朝堂记录可见文案复扫之后，按并发子 Agent 扫描结论收口 `CommandPanelView` 的命令消息展示出口。本轮只改展示 helper 和文档，不改变 `AppContainer.lastCommandMessage` 存储、交互日志、命令结构、校验逻辑、AI 决策、规则执行或运行时状态。

核心更新：

- `CommandPanelView` 不再原样显示 `lastCommandMessage`，改为调用本地 `displayCommandMessage(_:)`。
- 新增 `sanitizeCommandRawIdentifiers(in:)`，显示前清理 `war_directive_*`、`player_directive_*`、`player_operation_*`、`submission_*`、`diplomacy_event_*`、`region_*`、`theater_*`、`front_zone_*`、`hex_*`、`division_*`、`unit_*`、`command_*` 等常见内部 id。
- 命令面板词表补齐 `rawJSON`、`JSON`、`schema`、`RuleEngine`、`ZoneDirective`、`FrontZone`、`WarDeploymentState`、`Division`、`Command`、`Provider`、`local-model`、`OpenAI`、`GPT`、`Claude`、`Gemini`、`LLM`、`MockAI`、`AI`、`pipeline`、`fallback` 和 `hex` 等展示兜底。
- 并发子 Agent 额外指出 `UnitInspectorView`、`UnitTooltipView`、`RegionInspectorView`、`GeneralProfileView` 与 `MapDisplayAdapter` 仍可作为下一轮玩家可见 legacy 名称复扫候选；本轮未混入这些范围。
- 新增阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_command_panel_message_text_record.md`，同步 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/UI/CommandPanelView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_command_panel_message_text_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse WWIIHexV0/UI/CommandPanelView.swift`：通过，无输出。
- 定向残留扫描：`CommandPanelView.swift` 不再命中 `Text(lastCommandMessage)`。
- 本轮改动文件尾随空白扫描：无命中。
- 本轮改动文件行首冲突标记扫描：无命中。
- `git diff --check`：通过，无输出。

未执行：

- 未跑本机 Xcode build / XCTest / UI test / 模拟器 / Probe / Smoke / Full；按 `md/test/test.md` 当前规范，这些重验证需云端或人工授权。

遗留风险：

- 本轮未做运行时点击验证，命令面板实际渲染仍待授权构建/启动或云端流程确认。
- `UnitInspectorView`、`UnitTooltipView`、`RegionInspectorView`、`GeneralProfileView` 与 `MapDisplayAdapter` 的旧 fallback 名称直出风险可作为下一轮小刀继续收口。

## v3.7-preflight.70 - legacy 将领与朝堂记录可见文案复扫

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在 UI/战报/外交记录净化 helper 对齐之后，继续抽样复扫 legacy 将领、朝堂步骤和结构化军令记录中的玩家可见旧题材 / 工程词。本轮只改自由文本和展示 helper，不改变内部 id、rawValue、JSON 字段、解析合同、AI 决策、命令结构、规则执行或运行时状态。

核心更新：

- `GameAgent.guderianFallback` 的 legacy fallback 作战偏好从“装甲突破 / 装甲部队”改为“破阵突击 / 突击部队”口径。
- `GameAgent.localizedPersonalityPrompt(for:)` 对 legacy `guderian` 数据的可见 prompt 兜底同步改为隋唐化突击口径。
- `general_agents.json` 中 legacy `guderian` 的 `personalityPrompt` 中文展示文案同步去掉“装甲部队”。
- `generalSkillDisplayName` 中 `armor_expert` / `armor_theory` 的展示名从“装甲战法”改为“突击战法”，保留 skill rawValue 不变。
- `RulerAgent` 使者层 rationale 去掉“AI 自动回合”，改为“自动轮转”。
- `TurnManager` 写入 `rawJSON` 记录的标题从“方面军令 JSON”改为“结构化方面军令”，保留 `rawJSON` 字段和编码内容不变。
- `DiplomacyPanelView.displayRecordText` 补齐 `Field Marshal`、`Army Commander`、`WarDeploymentState`、`FrontZone`、`Division`、`Heinz Guderian` 和 `breakthrough` 等展示净化词。
- `md/plan/plan.md` 当前结果标题和下一轮阅读清单补齐到 v3.7-preflight.70，避免下一轮接手口径回退。
- 新增阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_legacy_general_court_visible_text_record.md`，同步 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Agents/AgentConfiguration.swift`
- `WWIIHexV0/Agents/RulerAgent.swift`
- `WWIIHexV0/Turn/TurnManager.swift`
- `WWIIHexV0/UI/GeneralCommandPanelView.swift`
- `WWIIHexV0/UI/DiplomacyPanelView.swift`
- `WWIIHexV0/Data/general_agents.json`
- `md/prompt/v3.0-隋唐迁移/v3.7_legacy_general_court_visible_text_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse WWIIHexV0/Agents/AgentConfiguration.swift`：通过，无输出。
- `swiftc -parse WWIIHexV0/Agents/RulerAgent.swift`：通过，无输出。
- `swiftc -parse WWIIHexV0/Turn/TurnManager.swift`：通过，无输出。
- `swiftc -parse WWIIHexV0/UI/GeneralCommandPanelView.swift`：通过，无输出。
- `swiftc -parse WWIIHexV0/UI/DiplomacyPanelView.swift`：通过，无输出。
- `jq empty WWIIHexV0/Data/general_agents.json`：通过，无输出。
- 定向残留扫描：本轮 touched legacy 将领 / 朝堂记录路径不再命中“装甲突破 / 装甲部队 / 装甲战法 / AI 自动回合 / 方面军令 JSON”。
- 本轮改动文件尾随空白扫描：无命中。
- 本轮改动文件行首冲突标记扫描：无命中。
- `git diff --check`：通过，无输出。

未执行：

- 未跑 Xcode build、XCTest、模拟器、Probe、Smoke、Stage Regression、Dynamic Theater Regression、Full、性能测试、app 启动或 UI 点击烟测；按当前 `md/test/test.md` 规则，本机默认只做轻量检查，重验证需走 GitHub Actions 或人工授权。

遗留风险：

- 本轮只处理并发扫描发现的 legacy 将领、朝堂步骤和结构化军令标题，不代表全项目可见文本已穷尽。
- `guderian`、`ger_panzer_*`、`armor_expert`、`armor_theory`、`rawJSON` 等内部 id / rawValue / 字段仍保留，这是兼容和解析合同。
- 最终 UI 展示效果仍未经过运行时截图或交互验证。

## v3.7-preflight.69 - UI/战报/外交记录净化 helper 对齐

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在模拟元帅输出纯 JSON 收口之后，继续收口 AI 面板、战报面板和外交面板中的记录 / 诊断展示净化 helper。此前 `AgentPanelView` 先清理 raw id 再做语义替换，但 `EventLogView` 与 `DiplomacyPanelView` 先替换 `agent` / `directive` 等词，再清理 raw id，可能把 `war_directive_*`、`player_directive_*`、`agent_*` 等审计 id 提前破坏，导致正则净化失效。本轮统一三处 helper 的顺序和词表，不改变记录 schema、日志来源、UI 布局、AI 决策、命令结构、规则执行或运行时状态。

核心更新：

- `EventLogView.displayDiagnosticText` 改为先执行 `sanitizeRawIdentifiers(in:)`，再做展示词表替换。
- `DiplomacyPanelView.displayRecordText` 改为先执行 `sanitizeRawIdentifiers(in:)`，再做展示词表替换。
- `AgentPanelView`、`EventLogView`、`DiplomacyPanelView` 统一补齐 `rawJson`、`raw JSON`、`Provider`、`Schema`、`AI`、`LLM`、`OpenAI`、`GPT`、`Claude`、`Gemini`、`record`、`Legacy Pipeline` 和裸 `pipeline` 等展示替换。
- `RuleEngine`、`local-model`、`Model`、`model` 在三处 helper 中对齐为军令校验、本地军议来源和军议来源口径。
- `DiplomacyPanelView.sanitizeRawIdentifiers` 补齐 `hex_*`、`player_directive_*`、`player_operation_*`、`directive_*command_*`、`order_*`、`division_*` / `unit_*` 和 `command_*` 等常见 raw id 前缀。
- 新增阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_ui_record_sanitizer_helper_record.md`，同步 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/UI/AgentPanelView.swift`
- `WWIIHexV0/UI/EventLogView.swift`
- `WWIIHexV0/UI/DiplomacyPanelView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_ui_record_sanitizer_helper_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse WWIIHexV0/UI/AgentPanelView.swift`：通过，无输出。
- `swiftc -parse WWIIHexV0/UI/EventLogView.swift`：通过，无输出。
- `swiftc -parse WWIIHexV0/UI/DiplomacyPanelView.swift`：通过，无输出。
- 定向顺序扫描：三处展示 helper 均先调用 raw id sanitizer，再做语义替换。
- 本轮改动文件尾随空白扫描：无命中。
- 本轮改动文件行首冲突标记扫描：无命中。
- `git diff --check`：通过，无输出。

未执行：

- 未跑 Xcode build、XCTest、模拟器、Probe、Smoke、Stage Regression、Dynamic Theater Regression、Full、性能测试、app 启动或 UI 点击烟测；按当前 `md/test/test.md` 规则，本机默认只做轻量检查，重验证需走 GitHub Actions 或人工授权。

遗留风险：

- 本轮只收口三处已有 UI 展示 helper，不做全项目可见文本穷尽审计。
- 替换词表仍是局部显示净化，不改变真实 record id、schema 字段、存档内容或审计原文。
- 最终 UI 展示效果仍未经过运行时截图或交互验证。

## v3.7-preflight.68 - 模拟元帅输出纯 JSON 收口

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在 legacy prompt 工程说明词收口之后，继续收口默认 AI 上游的模拟元帅输出格式。`SimulatedMarshalLLMClient` 原先主动把 `TheaterDirectiveEnvelope` 包成 Markdown 代码围栏形式的 fenced JSON；本轮改为直接返回纯 JSON 字符串，减少模拟路径继续制造排版标记和工程格式的机会。不改变 `TheaterDirectiveEnvelope` / `TheaterDirective` schema、字段名、schema version、decoder fenced JSON 兼容、元帅策略、fallback、命令编译、规则执行、存档字段或运行时状态。

核心更新：

- `SimulatedMarshalLLMClient.completeTheaterDirectiveJSON` 编码 `TheaterDirectiveEnvelope` 后直接返回 JSON 字符串。
- 保留 `TheaterDirectiveDecoder.extractJSON` 对带 json 标记的代码围栏、普通代码围栏和纯 JSON 的双兼容，外部模型输出合同不变。
- 保留 `MarshalAgent` 的解析、编译、fallback 和诊断流程。
- 保留 `TheaterDirectiveEnvelope`、`TheaterDirective`、`rawTheaterJSON`、`schemaVersion`、`issuerId`、`turn`、`faction`、zone / region / tactic 校验合同。
- 新增阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_marshal_pure_json_output_record.md`，同步 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Agents/ZoneCommanderAgent.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_marshal_pure_json_output_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse WWIIHexV0/Agents/ZoneCommanderAgent.swift`：通过，无输出。
- 定向残留扫描：模拟端 fenced JSON 返回语句在 `WWIIHexV0/Agents/ZoneCommanderAgent.swift` 无命中。
- 本轮改动文件尾随空白扫描：无命中。
- 本轮改动文件行首冲突标记扫描：无命中。
- `git diff --check`：通过，无输出。

未执行：

- 未跑 Xcode build、XCTest、模拟器、Probe、Smoke、Stage Regression、Dynamic Theater Regression、Full、性能测试、app 启动或 AI 回合运行；按当前 `md/test/test.md` 规则，本机默认只做轻量检查，重验证需走 GitHub Actions 或人工授权。

遗留风险：

- `TheaterDirectiveDecoder` 仍必须兼容 fenced JSON，因为总提示词和外部模型合同允许 fenced JSON 或纯 JSON；本轮只调整内置模拟客户端输出格式。
- `rawTheaterJSON` 仍保存结构化原文，字段名不能改；本轮只去掉模拟端主动生成的 Markdown 包装。
- 本轮未运行 AI 回合或真实模型输出质量验证。

## v3.7-preflight.67 - legacy prompt 工程说明词收口

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在 legacy MockAI stance 文案收口之后，继续收口旧 `AgentPromptBuilder` 中面向 LocalLLM 的 prompt 说明词，把 `hex`、`schema`、`Markdown` 和 `JSON schema` 等工程化说明转为中文结构化军令口径，降低 legacy Agent D / LocalLLM 回归路径把工程词回写到 `intent`、`reason`、`stance` 的风险。不改变 `responseFormat`、JSON key、schema version、agent id、内部编号字段、命令 type rawValue、parser / mapper 合同、AI 决策、规则执行、存档字段或运行时状态。

核心更新：

- `AgentPromptBuilder.systemPrompt` 中“回合制 hex 策略战局”改为“回合制六角格策略战局”。
- `AgentPromptBuilder.systemPrompt` 中“符合 schema 的有效 JSON / Markdown”说明改为“符合下方结构化格式的 JSON 内容 / 排版标记”。
- `AgentPromptBuilder.systemPrompt` 中“JSON key 或英文 type 值”改为“字段名或命令类型原值”，避免在摘要约束里继续强调工程词。
- `AgentPromptBuilder.userPrompt` 中编号用途和格式标题改为“结构化军令字段取值”和“结构化输出格式”。
- 保留实际 JSON 示例、`schemaVersion`、`agentId`、`turn`、`orders`、`divisionId`、`targetDivisionId`、`toRegionId` 和 `move` / `attack` / `hold` / `resupply` 合同值。
- 新增阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_legacy_prompt_schema_wording_record.md`，同步 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Agents/AgentPromptBuilder.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_legacy_prompt_schema_wording_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse WWIIHexV0/Agents/AgentPromptBuilder.swift`：通过，无输出。
- 定向残留扫描：`hex 策略`、`JSON schema`、`schema 的有效 JSON`、`Markdown` 在 `AgentPromptBuilder.swift` 无命中。
- 本轮改动文件尾随空白扫描：无命中。
- 本轮改动文件行首冲突标记扫描：无命中。
- `git diff --check`：通过，无输出。

未执行：

- 未跑 Xcode build、XCTest、模拟器、Probe、Smoke、Stage Regression、Dynamic Theater Regression、Full、性能测试、app 启动或真实 LocalLLM 调用；按当前 `md/test/test.md` 规则，本机默认只做轻量检查，重验证需走 GitHub Actions 或人工授权。

遗留风险：

- prompt 示例仍必须保留 JSON 结构、字段名、内部编号和命令类型原值，否则 legacy parser / mapper 合同会失效。
- 本轮只处理 `AgentPromptBuilder` 的 prompt 可见工程说明词；源码注释、变量名和内部 API 名仍保留英文工程语义。
- 本轮未验证真实模型输出质量，只收口 prompt 文案入口。

## v3.7-preflight.66 - legacy MockAI stance 文案收口

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在 legacy prompt 决策者身份净化之后，继续收口 legacy `MockAIClient` 生成的 `AgentOrder.stance` 中仍保留的英文自由文本，避免旧 Agent D / MockAI 回归路径把英文姿态写入 raw JSON、AI 面板或战报摘要。不改变 `AgentOrderType`、内部 id、parser / mapper 合同、MockAI 决策策略、命令结构、规则执行、存档字段或运行时状态。

核心更新：

- `MockAIClient` 中所有直接赋值的 `AgentOrder.stance` 改为中文短语。
- 覆盖整补恢复、火力支援、突破、沿路推进、稳步推进、固守、前线整补、收紧包围、前线进攻、围堵敌军、固守前线、纵深驰援、纵深待命、驻防、前线待命和战役预备。
- 保留 `AgentOrder.type` 的 `move`、`attack`、`hold`、`resupply` rawValue。
- 保留 `divisionId`、`targetDivisionId`、`toRegionId`、objective id 和 region id 等解析 / 规则合同。
- 新增阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_legacy_mockai_stance_text_record.md`，同步 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Agents/MockAIClient.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_legacy_mockai_stance_text_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse WWIIHexV0/Agents/MockAIClient.swift`：通过，无输出。
- 定向残留扫描：`stance: "[A-Za-z]`、英文三元 stance 和英文 `let stance` 在 `MockAIClient.swift` 无命中。
- 本轮改动文件尾随空白扫描：无命中。
- 本轮改动文件行首冲突标记扫描：无命中。
- `git diff --check`：通过，无输出。

未执行：

- 未跑 Xcode build、XCTest、模拟器、Probe、Smoke、Stage Regression、Dynamic Theater Regression、Full、性能测试、app 启动或 legacy MockAI 回合运行；按当前 `md/test/test.md` 规则，本机默认只做轻量检查，重验证需走 GitHub Actions 或人工授权。

遗留风险：

- `AgentOrder.type`、内部 id 和 objective id 仍保持英文 / rawValue，这是解析和规则管线合同，不能在本片中文化。
- `MockAIClient` 内部排序、变量名和 legacy 注释仍有英文开发语义；本轮只处理可能进入模型输出 / raw JSON / UI 摘要的 `stance` 自由文本。
- 本轮未通过运行时 AI 回合验证最终 UI 展示。

## v3.7-preflight.65 - legacy prompt 决策者身份净化

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在 legacy prompt 直通文本净化之后，继续收口旧 `AgentPromptBuilder.systemPrompt` 中 `context.agentId` 和 `context.personality` 作为自由文本原样进入 LocalLLM prompt 的问题，避免 raw agent id、英文 personality 或工程词在系统提示层诱导模型回写到中文摘要字段。不改变 JSON schema、agent id rawValue、解析合同、命令结构、AI 决策、规则执行、存档字段或运行时状态。

核心更新：

- `AgentPromptBuilder.systemPrompt` 中“决策者”改为展示名：`guderian` 显示为“古德里安”，其他纯内部 id 形式的 agent id 泛化为“本地军议决策者”。
- `AgentPromptBuilder.systemPrompt` 中“性格”改走 prompt-local `sanitizePromptText(_:)`，复用 `.64` 的自由文本净化。
- `GameAgent.sample` 的默认 personality prompt 从英文改为中文“遵守角色职责，保持建议结构清晰。”。
- `GameAgent.sample` 的 traits 从 `disciplined` 改为“守纪”。
- JSON schema 中的 `"agentId": "\(context.agentId)"` 保持不变，继续满足 `LocalLLMDecisionProvider` 与 `AgentDecisionParser` 的 expected agent id 合同。
- 新增阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_legacy_prompt_agent_identity_record.md`，同步 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Agents/AgentPromptBuilder.swift`
- `WWIIHexV0/Agents/GameAgent.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_legacy_prompt_agent_identity_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse WWIIHexV0/Agents/AgentPromptBuilder.swift WWIIHexV0/Agents/GameAgent.swift`：通过，无输出。
- 定向残留扫描：`决策者：\\(context.agentId)`、`性格：\\(context.personality)`、`Follow role responsibilities`、`disciplined` 在目标文件无命中。
- 本轮改动文件尾随空白扫描：无命中。
- 本轮改动文件行首冲突标记扫描：无命中。
- `git diff --check`：通过，无输出。

未执行：

- 未跑 Xcode build、XCTest、模拟器、Probe、Smoke、Stage Regression、Dynamic Theater Regression、Full、性能测试、app 启动或真实 LocalLLM 调用；按当前 `md/test/test.md` 规则，本机默认只做轻量检查，重验证需走 GitHub Actions 或人工授权。

遗留风险：

- JSON schema 仍必须暴露 raw `agentId`，否则 parser 的 agent mismatch 校验会失效；本轮只净化自由文本身份描述。
- `sanitizePromptText(_:)` 是 `AgentPromptBuilder` 局部 helper，尚未抽成共享 formatter；这是刻意控制范围，避免牵动 UI 展示层。
- 本轮未验证真实模型输出质量，只收口 prompt 文本入口。

## v3.7-preflight.64 - legacy prompt 直通文本净化

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在 legacy prompt 内部编号分层之后，继续收口旧 `AgentPromptBuilder` 中 `recentEvents.message` 与 `playerDirective` 原样进入 LocalLLM prompt 的问题，避免上游战报、玩家意图或历史记录中残留的 raw id、工程词和旧英文口径再次诱导模型写入 `intent`、`reason`、`stance`。不改变展示 sanitizer、解析合同、命令结构、AI 决策、规则执行、存档字段或运行时状态。

核心更新：

- `AgentPromptBuilder` 对近期战报逐条调用局部 `sanitizePromptText(_:)` 后再拼入 prompt。
- `AgentPromptBuilder` 对 `playerDirective` 调用同一局部净化后再拼入 prompt。
- 新增 prompt-local raw id 正则净化，覆盖 `war_directive_*`、`player_directive_*`、`submission_handoff_*`、`diplomacy_event_*`、`court_decision_*`、`ruler_decision_*`、`region_*`、`theater_*`、`front_zone_*`、`obj_*`、`hex_*`、`division_*`、`unit_*`、`command_*`、`agent_*` 和朝堂角色前缀记录。
- 局部净化同步当前展示层内部词口径，把 `Heinz Guderian`、`rawJSON`、`local-model`、`ZoneDirective`、`RuleEngine`、`MockAI`、`hexToTheater` 等转为玩家语义。
- 净化只用于 legacy prompt 的自由文本区，不作用于内部编号表或 JSON schema。
- 新增阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_legacy_prompt_passthrough_sanitizer_record.md`，同步 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Agents/AgentPromptBuilder.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_legacy_prompt_passthrough_sanitizer_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse WWIIHexV0/Agents/AgentPromptBuilder.swift`：通过，无输出。
- 定向残留扫描：`recentEvents = context.recentEvents.map(\\.message)` 和 `\\(context.playerDirective ?? "无")` 直通拼接在 `AgentPromptBuilder.swift` 无命中。
- 本轮改动文件尾随空白扫描：无命中。
- 本轮改动文件行首冲突标记扫描：无命中。
- `git diff --check`：通过，无输出。

未执行：

- 未跑 Xcode build、XCTest、模拟器、Probe、Smoke、Stage Regression、Dynamic Theater Regression、Full、性能测试、app 启动或真实 LocalLLM 调用；按当前 `md/test/test.md` 规则，本机默认只做轻量检查，重验证需走 GitHub Actions 或人工授权。

遗留风险：

- `context.agentId`、内部编号表和 `type` rawValue 仍必须暴露给 prompt 以维持解析合同，不能完全隐藏英文 key / rawValue。
- 上游 `recentEvents` 与 `playerDirective` 的原始存储文本不被改写；本轮只净化进入 legacy prompt 的自由文本副本。
- 本轮未验证真实模型输出质量，只收口 prompt 文本入口。

## v3.7-preflight.63 - legacy prompt 内部编号分层收口

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在 legacy 总管配置中文兜底之后，继续收口旧 `AgentPromptBuilder` 中 raw id、英文命令 type 和英文 schema 示例值混在战场摘要正文里，可能诱导 legacy LocalLLM 把内部编号或英文 type 回写到 `intent`、`reason`、`stance` 的问题。不改变 `AgentDecisionEnvelope`、`AgentOrderType`、解析合同、命令结构、AI 决策、规则执行、存档字段或运行时状态。

核心更新：

- `AgentPromptBuilder.systemPrompt` 明确 `intent`、`reason`、`stance` 不得复述内部编号、JSON key 或英文 type 值，除非字段本身要求填写编号。
- 战场摘要中的目标、己方军队、敌军和可见州郡改为中文名称优先，不再把 `division.id`、`regionId.rawValue` 或 neighbor rawValue 混在正文里。
- 新增“提交军令时必须使用的内部编号”小节，单独列出 `divisionId`、`targetDivisionId` 和 `toRegionId` 的可选值。
- JSON schema 示例中的英文占位改为中文说明。
- 保留 `type` 字段的 `move`、`attack`、`hold`、`resupply` rawValue 合同，避免破坏 `AgentOrderType` Codable 解析。
- 新增阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_legacy_prompt_internal_id_record.md`，同步 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Agents/AgentPromptBuilder.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_legacy_prompt_internal_id_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse WWIIHexV0/Agents/AgentPromptBuilder.swift`：通过，无输出。
- 定向残留扫描：旧英文占位 `existing division id`、`existing visible region id` 和 `move|attack|hold|resupply` 在 `AgentPromptBuilder.swift` 无命中。
- 本轮改动文件尾随空白扫描：无命中。
- 本轮改动文件行首冲突标记扫描：无命中。
- `git diff --check`：通过，无输出。

未执行：

- 未跑 Xcode build、XCTest、模拟器、Probe、Smoke、Stage Regression、Dynamic Theater Regression、Full、性能测试、app 启动或真实 LocalLLM 调用；按当前 `md/test/test.md` 规则，本机默认只做轻量检查，重验证需走 GitHub Actions 或人工授权。

遗留风险：

- 旧 LocalLLM prompt 仍必须暴露解析所需的内部编号和 `type` rawValue，不能完全去除英文合同值。
- 本轮未验证真实模型输出质量，只收口 prompt 文本结构。
- 默认元帅链路不依赖 `AgentPromptBuilder`，本轮收益主要是降低旧路径回归或未来启用 LocalLLM 时的英文/内部编号回流风险。

## v3.7-preflight.62 - legacy 总管配置中文兜底

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在 AI 诊断净化口径对齐之后，继续收口 legacy `general_agents.json` 中 `guderian` 配置优先于代码 fallback 加载时，英文展示名和英文 personality prompt 仍可能进入旧 LocalLLM / legacy Agent D 上下文的问题。不改变 JSON schema、id、rawValue、command style、命令解析合同、AI 决策、规则执行、存档字段或运行时状态。

核心更新：

- `WWIIHexV0/Data/general_agents.json` 中 legacy `guderian` 的 `name` 改为“古德里安”。
- `WWIIHexV0/Data/general_agents.json` 中 legacy `guderian` 的 `personalityPrompt` 改为中文作战偏好，避免英文 prompt 进入旧本地军议上下文。
- `GameAgent(definition:)` 对 `definition.id == "guderian"` 保留窄口径中文兜底，保护旧 bundle 或旧数据。
- `GameAgent(definition:)` 的 `AgentPersonality.traits` 将 `breakthrough` 展示为“突破”，但 aggression / riskTolerance 的数值判断仍读取原始 `definition.commandStyle`。
- `guderianFallback` 的 traits 同步改为“突破”，保持 JSON 成功加载和 fallback 路径的展示口径一致。
- 新增阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_legacy_general_agent_config_record.md`，同步 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Data/general_agents.json`
- `WWIIHexV0/Agents/AgentConfiguration.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_legacy_general_agent_config_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse WWIIHexV0/Agents/AgentConfiguration.swift`：通过，无输出。
- `jq empty WWIIHexV0/Data/general_agents.json`：通过，无输出。
- 定向残留扫描：`Heinz Guderian`、旧英文 personality prompt 片段在 `WWIIHexV0/Agents/AgentConfiguration.swift` 与 `WWIIHexV0/Data/general_agents.json` 无命中。
- 本轮改动文件尾随空白扫描：无命中。
- 本轮改动文件冲突标记扫描：无命中。
- `git diff --check`：通过，无输出。

未执行：

- 未跑 Xcode build、XCTest、模拟器、Probe、Smoke、Stage Regression、Dynamic Theater Regression、Full、性能测试或 app 启动；按当前 `md/test/test.md` 规则，本机默认只做轻量检查，重验证需走 GitHub Actions 或人工授权。

遗留风险：

- 本轮未启动 legacy LocalLLM 管线验证最终 prompt 上下文，只收口配置入口和代码兜底。
- 历史测试如果仍断言 `guderian.name == "Heinz Guderian"`，后续维护测试时需要按中文展示口径更新；本轮按规则未运行 XCTest，也不主动改测试。
- `AgentPromptBuilder` 仍可能把 raw id / 英文 type 合同写入模型提示，建议后续作为 `.63` 独立收口。

## v3.7-preflight.61 - AI 诊断净化口径对齐

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在 MapEditor 导出元数据 fallback 收口之后，继续收口 AI / 朝堂诊断源头和 AI 面板展示中仍可能保留的旧二战专名、内部工程词、半清洗审计 id 与旧“模型/管线/规则系统”口径。不改变记录 schema、AI 决策、prompt、解析、命令结构、规则执行、存档字段或运行时状态。

核心更新：

- `TurnManager.userFacingDiagnostic(_:)` 与 `AgentPanelView.displayDiagnosticText(_:)` 统一将 `Heinz Guderian` / `Guderian` 显示为“历史总管”。
- `local-model` / `model`、`legacy pipeline`、`RuleEngine` 分别显示为“本地军议来源 / 军议来源”“备用军议路径”“军令校验”。
- `AgentPanelView.displayDiagnosticText(_:)` 改为先做 raw id 正则净化，再做普通工程词替换，避免 `war_directive_*`、`agent_*`、`hex_*` 等被半清洗后无法命中正则。
- `AgentPanelView` 的命令结果标题和本地 provider 展示同步走玩家语义。
- `AgentPanelView` 与 `TurnManager` 的 raw id sanitizer 补齐 `war_directive_*`、`player_directive_*`、`player_operation_*`、`submission_handoff_*`、`submission_aftermath_*`、`diplomacy_event_*`、`court_decision_*`、`ruler_decision_*`、`hex_*`、`division_*`、`unit_*`、`command_*` 等常见审计 id。
- `TurnManager` 中无行军防区的跳过诊断从“旧管线”改为“备用军议路径”。
- 新增阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_agent_panel_diagnostic_sanitizer_record.md`，同步 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/UI/AgentPanelView.swift`
- `WWIIHexV0/Turn/TurnManager.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_agent_panel_diagnostic_sanitizer_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse WWIIHexV0/UI/AgentPanelView.swift WWIIHexV0/Turn/TurnManager.swift`：通过，无输出。
- 定向残留扫描：`war_军令` / `player_军令` / `朝堂成员_` / `地块_` 等半清洗文本无命中；旧“旧管线”“本地模型”“规则系统”“古德里安”“结构化记录”“诊断”旧口径在目标文件无命中。
- 本轮改动文件尾随空白扫描：无命中。
- 本轮改动文件冲突标记扫描：无命中。
- `git diff --check`：通过，无输出。

未执行：

- 未跑 Xcode build、XCTest、模拟器、Probe、Smoke、Stage Regression、Dynamic Theater Regression、Full、性能测试或 app 启动；按当前 `md/test/test.md` 规则，本机默认只做轻量检查，重验证需走 GitHub Actions 或人工授权。

遗留风险：

- 本轮未启动 app 或真实 UI 截图验证所有历史诊断组合的展示效果。
- 已写入旧存档或旧历史记录中的文本仍可能保留旧口径；本轮只保证进入 `TurnManager.userFacingDiagnostic` 和 `AgentPanelView.displayDiagnosticText` 的路径继续净化。

## v3.7-preflight.60 - MapEditor 导出元数据 fallback 收口

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在战报意图屏蔽与中文分类收口之后，继续收口 MapEditor 普通预览/目录导出路径中未显式传入 `MapEditorExportMetadata` 时，未知自定义文档 id 可能默认落到 legacy 阿登元数据的问题。不改变 JSON schema、MapEditor 文档字段、keyLocations 合并规则、主游戏加载规则、运行时玩法、规则或命令管线。

核心更新：

- `MapEditorExportMetadata.inferred(for:)` 保留 `wude_618` 文档使用 `.wude618Default`。
- 文档 id 或展示名明确包含隋唐口径时使用 `.suitangDraft`。
- 只有文档 id 或展示名明确包含 `legacy`、`ardennes`、`wwii`、`阿登` 或 `旧战局` 时才使用 `.legacyArdennes`。
- 其他未知自定义文档默认使用 `.suitangDraft`，避免普通新地图误导出 legacy faction / phase / dataNotes。
- 新增阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_mapeditor_export_metadata_fallback_record.md`，同步 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `MapEditor/MapEditorExporter.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_mapeditor_export_metadata_fallback_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/flow/04_mapeditor_to_game_data.mermaid`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse MapEditor/MapEditorExporter.swift`：通过，无输出。
- 定向 fallback 扫描：`MapEditorExportMetadata.inferred(for:)` 仅在 `document.id` / `document.displayName` 明确包含 `legacy`、`ardennes`、`wwii`、`阿登` 或 `旧战局` 时返回 `.legacyArdennes`；未知自定义文档最终返回 `.suitangDraft`。
- 本轮改动文件尾随空白扫描：无命中。
- 本轮改动文件冲突标记扫描：无命中。
- `git diff --check`：通过，无输出。

未执行：

- 未跑 Xcode build、XCTest、模拟器、Probe、Smoke、Stage Regression、Dynamic Theater Regression、Full、性能测试或 app 启动；按当前 `md/test/test.md` 规则，本机默认只做轻量检查，重验证需走 GitHub Actions 或人工授权。

遗留风险：

- 覆盖默认资源入口仍会优先使用当前 `wude_618_scenario` 读取出的 metadata；是否需要阻止非默认文档覆盖默认资源，应作为后续单独小片处理。
- 静态 `.wude618Default` 仍只是降级 metadata，不完整携带当前默认 JSON 的渡口、港口、海港和 objective 点数；默认资源桥覆盖保存仍应优先使用当前 JSON 读取出的 metadata。
- `keyLocationsAreAuthoritative` 与 hex 派生地点的长期语义仍可后续单独整理，但不应混入本小片。

## v3.7-preflight.59 - 战报意图屏蔽与中文分类收口

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在外交面板名称与记录净化收口之后，继续收口战报面板中 v3.x 诊断文本、复合 intent、审计 record id 和中文隋唐战报分类的展示问题。不改变 `GameLogEntry`、日志写入源头、事件 category schema、record id、AI 决策、命令结构、存档字段、规则或命令管线。

核心更新：

- `EventLogView.displayedIntent(_:)` 的结构化意图屏蔽从只识别 `v0.` 扩展为识别 `v[0-9]+(.N)*` 版本号。
- 复合 intent 如 `attack_front`、`move_to_hex`、`hold_position` 按前缀显示中文摘要；未知 snake_case intent 显示“已记录军议意图”，不回显原始字符串。
- 审计 record id 净化前移到 `sanitizeRawIdentifiers(in:)`，避免普通 `directive` 替换先执行后留下半清洗文本。
- `sanitizeRawIdentifiers(in:)` 补齐 `war_directive_*`、`player_directive_*`、`player_operation_*`、`submission_handoff_*`、`submission_aftermath_*`、`diplomacy_event_*`、`hex_*`、`division_*`、`unit_*`、`command_*` 等常见 raw id 前缀。
- 战报诊断净化将旧 `Heinz Guderian` / `Guderian` 统一显示为“历史总管”，并把 `model`、`legacy pipeline`、`RuleEngine` 调整为“军议来源”“备用军议路径”“军令校验”等玩家语义。
- `LogDisplayCategory` 的 `.event` fallback 分类补齐撤退、退却、溃退、补员、整补、围困、包围、断粮、攻击、进攻、进军、战斗、打击、伤亡、损失、粮道、补给、粮草、军粮等中文关键词。
- 新增阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_event_log_intent_category_record.md`，同步 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/UI/EventLogView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_event_log_intent_category_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse WWIIHexV0/UI/EventLogView.swift`：通过，无输出。
- 定向残留扫描：`v0.`、半清洗 `war_军令` / `player_军令`、复合 intent 示例无命中；`Heinz Guderian`、`Guderian`、`legacy pipeline`、`RuleEngine` 仅作为替换表左侧旧词常量保留，最终展示映射为中文玩家语义。
- 尾随空白扫描：本轮改动 Swift / Markdown 文件无命中。
- 行首冲突标记扫描：本轮改动 Swift / Markdown 文件无命中。
- `git diff --check`：通过，无输出。

未执行：

- 未跑 Xcode build、XCTest、模拟器、Probe、Smoke、Stage Regression、Dynamic Theater Regression、Full、性能测试或 app 启动；按当前 `md/test/test.md` 规则，本机默认只做轻量检查，重验证需走 GitHub Actions 或人工授权。

遗留风险：

- 战报分类仍是展示层关键词兜底，不能替代源头事件 category 的长期治理。
- 未通过真实运行时多回合战报样本确认所有组合的分类效果。

## v3.7-preflight.58 - 外交面板名称与记录净化收口

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在 legacy LLM prompt 语言收口之后，继续收口外交面板中仍可能绕过展示 helper 的数据层英文名称和常见内部诊断词。不改变 `DiplomacyState` 数据结构、外交关系、命令结构、JSON key、rawValue、record id、AI 决策、存档 schema、规则或命令管线。

核心更新：

- `DiplomacyPanelView` 的势力列表名称从 `country.name` 改为 `countryDisplayName(country)`。
- `DiplomacyPanelView` 的盟从列表名称从 `bloc.name` 改为 `blocDisplayName(bloc)`。
- `countryDisplayName(_:)` 与 `blocDisplayName(_:)` 在未知数据 fallback 中检测拉丁字母；命中时回落到势力中文展示名，避免新增或 legacy 数据直接显示英文名称。
- `displayRecordText(_:)` 补齐 `intent`、`reason`、`source`、`command`、`directive`、`RuleEngine`、`MockAI`、`model`、`Guderian` 等常见内部词替换。
- `sanitizeRawIdentifiers(in:)` 补齐 `war_directive_*`、`court_decision_*`、`ruler_decision_*`、`diplomacy_event_*`、`submission_handoff_*`、`submission_aftermath_*` 等记录 id 净化。
- 新增阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_diplomacy_panel_name_sanitizer_record.md`，同步 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/UI/DiplomacyPanelView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_diplomacy_panel_name_sanitizer_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse WWIIHexV0/UI/DiplomacyPanelView.swift`：通过，无输出。
- 定向残留扫描：`Text(country.name)`、`LabeledContent(bloc.name)`、直接 `return country.name` / `return bloc.name` 风险路径无命中；保留的 `return country.name` / `return bloc.name` 均位于拉丁字母检测后的安全 fallback 分支。
- 尾随空白扫描：本轮改动 Swift / Markdown 文件无命中。
- 行首冲突标记扫描：本轮改动 Swift / Markdown 文件无命中。
- `git diff --check`：通过，无输出。

未执行：

- 未跑 Xcode build、XCTest、模拟器、Probe、Smoke、Stage Regression、Dynamic Theater Regression、Full、性能测试或 app 启动；按当前 `md/test/test.md` 规则，本机默认只做轻量检查，重验证需走 GitHub Actions 或人工授权。

遗留风险：

- 外交面板 sanitizer 仍是局部展示层净化，后续可与 `AgentPanelView`、`EventLogView` 抽成共享 formatter，减少规则漂移。
- 未通过真实 UI 截图确认所有历史记录组合的展示效果。

## v3.7-preflight.57 - legacy LLM prompt 语言收口

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在 legacy static fallback 目标兼容与展示文案收口之后，继续处理旧 LocalLLM / legacy Agent 管线中仍可能诱导英文 `intent`、`reason` 和 `summary` 回流到军情面板的 prompt 入口；同时收口数据加载失败时的古德里安 fallback 英文展示名。不改变 JSON schema、command type、agent id、rawValue、解析合同、AI 决策结构、规则或命令管线。

核心更新：

- `AgentPromptBuilder.systemPrompt` 改为中文，并明确 `intent`、`reason`、`stance` 摘要必须使用中文。
- `AgentPromptBuilder.userPrompt` 的任务说明、可用命令、战场摘要、补给、近期战报和玩家意图说明中文化。
- prompt 中目标、己方军队、敌军和可见州郡摘要使用中文字段标签。
- JSON 示例中的 `intent`、`reason` 和 `stance` 示例值改为中文。
- `GameAgent.guderianFallback` 的展示名改为“古德里安”，personality prompt 改为中文。
- 新增阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_legacy_llm_prompt_language_record.md`，同步 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Agents/AgentPromptBuilder.swift`
- `WWIIHexV0/Agents/AgentConfiguration.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_legacy_llm_prompt_language_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse WWIIHexV0/Agents/AgentPromptBuilder.swift WWIIHexV0/Agents/AgentConfiguration.swift`：通过，无输出。
- 定向残留扫描：`You are the local LLM`、`Current task`、`Available commands`、`Battlefield summary`、`short operational intent`、`short reason`、`Heinz Guderian`、`Prioritize armored` 在目标文件无命中。

未执行：

- 未跑 Xcode build、XCTest、模拟器、Probe、Smoke、Stage Regression、Dynamic Theater Regression、Full、性能测试或 app 启动；按当前 `md/test/test.md` 规则，本机默认只做轻量检查，重验证需走 GitHub Actions 或人工授权。

遗留风险：

- 未真实启用 LocalLLM 管线验证模型输出是否完全中文。
- DiplomacyPanel、AgentPanel 和 EventLog 的诊断 sanitizer 仍有进一步合并与兜底空间。

## v3.7-preflight.56 - legacy static fallback 目标兼容与展示文案收口

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在 legacy fallback 单位与防区展示文案收口之后，继续处理静态阿登 fallback 路径中仍可能进入玩家视野的英文地点、单位、初始化战报和胜负原因；同时修正前序地点名中文化后，legacy 胜负规则和 MockAI 仍只按英文展示名查找目标的兼容风险。不改变 objective id、JSON key、rawValue、coord、faction、templateId、胜负阈值、行动策略、存档字段或命令管线。

核心更新：

- `MapState.ardennesV0()` 的静态城市、要塞和 objective 展示名改为巴斯托涅、圣维特、侯法利兹和巴斯托涅要塞。
- `GameState.initial()` 的 legacy 样例单位名和初始化战报改为中文。
- `VictoryState.displayName` 的 legacy 阿登胜负原因从“旧剧本 / AI / 玩家”口径改为“阿登 / 德军 / 盟军”口径。
- `VictoryRules` 与 `RegionVictoryRules` 的阿登目标判断优先按 objective id 查找，再兼容中文和英文展示名。
- `MockAIClient` 的 legacy 目标选择优先按 `bastogne` objective id 查找，再兼容“巴斯托涅 / Bastogne”展示名。
- 新增阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_legacy_static_fallback_objective_text_record.md`，同步 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Core/MapState.swift`
- `WWIIHexV0/Core/GameState.swift`
- `WWIIHexV0/Core/VictoryState.swift`
- `WWIIHexV0/Rules/VictoryRules.swift`
- `WWIIHexV0/Rules/RegionVictoryRules.swift`
- `WWIIHexV0/Agents/MockAIClient.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_legacy_static_fallback_objective_text_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse WWIIHexV0/Rules/VictoryRules.swift WWIIHexV0/Rules/RegionVictoryRules.swift WWIIHexV0/Agents/MockAIClient.swift WWIIHexV0/Core/MapState.swift WWIIHexV0/Core/GameState.swift WWIIHexV0/Core/VictoryState.swift`：通过，无输出。
- 定向残留扫描：静态 fallback 英文展示名、英文初始化战报和“旧剧本 / AI / 玩家”胜负原因无命中；`"Bastogne"` / `"St. Vith"` 仅作为旧数据兼容查找值保留。

未执行：

- 未跑 Xcode build、XCTest、模拟器、Probe、Smoke、Stage Regression、Dynamic Theater Regression、Full、性能测试或 app 启动；按当前 `md/test/test.md` 规则，本机默认只做轻量检查，重验证需走 GitHub Actions 或人工授权。

遗留风险：

- 本轮没有真实启动 app 或 legacy fallback 样例确认 UI 展示效果。
- MapEditor 默认导出 metadata、隋唐将领 `name` 字段和 victory condition `status` 的进一步收口留给后续独立切片。

## v3.7-preflight.55 - legacy fallback 单位与防区展示文案收口

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在 legacy fallback 数据展示文案收口之后，继续按人工要求使用并发只读子 agent 复扫剩余可见字段，收口 `initialUnits[].name` 的“师 N”泛化名、阿登场景“预检”口径和阿登 region “州郡”口径；不改变 JSON key、id、rawValue、coord、faction、templateId、objective kind、schemaVersion、加载顺序、规则数值或命令管线。

核心更新：

- `ardennes_v0_scenario.json` 的 `displayName` 从“阿登预检剧本”改为“阿登战局”，dataNotes 从“阿登预检场景数据”改为“阿登战局场景数据”。
- `ardennes_v0_scenario.json` 的 41 个 `initialUnits[].name` 不再使用“师 N”，改为按阵营和兵种区分的德军/盟军步兵、炮兵、装甲、摩托化展示名。
- `ardennes_v02_regions.json` 的数据集名从“阿登地区州郡”改为“阿登战区分区”，`regions[].name` 从“方位州郡”改为“防区”口径。
- 新增阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_legacy_unit_region_display_text_record.md`，同步 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Data/ardennes_v0_scenario.json`
- `WWIIHexV0/Data/ardennes_v02_regions.json`
- `md/prompt/v3.0-隋唐迁移/v3.7_legacy_unit_region_display_text_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `jq empty WWIIHexV0/Data/ardennes_v0_scenario.json WWIIHexV0/Data/ardennes_v02_regions.json WWIIHexV0/Data/generals.json`：通过，无输出。
- 定向残留扫描：`"name" : "师 [0-9]+"`、`阿登预检`、`城邑 [-0-9]`、`补给点 [-0-9]`、`新省份`、`地图编辑器旧剧本`、`旧剧本`、`装甲总管`、`集团军总管`、`"localizedName": "博客"` 在目标数据文件无命中；`州郡` 在阿登 fallback 数据展示字段无命中。

未执行：

- 未跑 Xcode build、XCTest、模拟器、Probe、Smoke、Stage Regression、Dynamic Theater Regression、Full、性能测试或 app 启动；按当前 `md/test/test.md` 规则，本机默认只做轻量检查，重验证需走 GitHub Actions 或人工授权。

遗留风险：

- 本轮没有真实启动 app、打开 legacy fallback 场景、地图详情、防区详情或单位详情确认视觉效果。
- 阿登 fallback 仍保留二战势力 raw id、unit template id 和内部文件名，这是 legacy 兼容层的一部分，不在本轮展示文案范围内。
- 单位名采用阵营和兵种泛化展示，不宣称还原完整历史番号。

## v3.7-preflight.54 - legacy fallback 数据展示文案收口

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在总管与将领档案防区展示名 raw id 收口之后，继续按人工要求使用并发只读子 agent 扫描 legacy fallback 数据中仍可能进入玩家视野的草稿名、坐标式地点名和旧剧本文案；不改变 JSON key、id、rawValue、coord、faction、templateId、objective kind、schemaVersion、加载顺序、规则数值或命令管线。

核心更新：

- `ardennes_v0_scenario.json` 的展示名改为“阿登预检剧本”，dataNotes 改为玩家语义说明。
- `ardennes_v0_scenario.json` 的 keyLocations 和 map tile `cityName` 不再使用“城邑 q,r / 补给点 q,r”，改为巴斯托涅、圣维特、马尔梅迪、迪南、纳缪尔、侯法利兹、拉罗什、圣于贝尔、色当、马尔什、纽沙托和补给站名称。
- `ardennes_v02_regions.json` 的数据集名、region name 和 city name 去掉“地图编辑器旧剧本州郡”“新省份N”和坐标式城邑名。
- `generals.json` 的 legacy 将领履历去掉“旧剧本总管 / 旧剧本装甲总管 / 旧剧本集团军总管”，并把 `general_bock.localizedName` 从“博客”修正为“博克”。
- 新增阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_legacy_data_display_text_record.md`，同步 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Data/ardennes_v0_scenario.json`
- `WWIIHexV0/Data/ardennes_v02_regions.json`
- `WWIIHexV0/Data/generals.json`
- `md/prompt/v3.0-隋唐迁移/v3.7_legacy_data_display_text_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `jq empty WWIIHexV0/Data/ardennes_v0_scenario.json WWIIHexV0/Data/ardennes_v02_regions.json WWIIHexV0/Data/generals.json`：通过，无输出。
- 定向残留扫描：`城邑 [-0-9]`、`补给点 [-0-9]`、`新省份`、`地图编辑器旧剧本`、`旧剧本`、`装甲总管`、`集团军总管`、`"localizedName": "博客"` 无命中。

未执行：

- 未跑 Xcode build、XCTest、模拟器、Probe、Smoke、Stage Regression、Dynamic Theater Regression、Full、性能测试或 app 启动；按当前 `md/test/test.md` 规则，本机默认只做轻量检查，重验证需走 GitHub Actions 或人工授权。

遗留风险：

- 本轮没有真实启动 app、打开 legacy fallback 场景、地图详情、州郡详情或将领档案确认视觉效果。
- 阿登 fallback 仍保留二战势力 raw id、unit template id 和内部文件名，这是 legacy 兼容层的一部分，不在本轮展示文案范围内。
- `initialUnits[].name` 仍是“师 N”泛化名，后续可按阵营和兵种做更完整的用户可见单位名收口。

## v3.7-preflight.53 - 总管与将领档案防区展示名 raw id 收口

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在命令错误与源头战报可见文案收口之后，继续按人工要求使用并发只读子 agent 扫描玩家可见 raw id 残留，收口自动总管配置和将领档案中仍可能暴露 raw 防区 id / raw 防区名的展示路径；不改变 `ZoneCommanderAgentConfig.id`、`assignedZoneId`、`FrontZoneId`、front zone schema、AI 决策、命令结构、规则数值或执行语义。

核心更新：

- `MockAICommander.defaultConfig(for:)` 的本地模拟总管展示名不再拼接 `zone.id.rawValue`。
- `TheaterCommanderPool.defaultConfig(for:)` 的自动总管展示名不再拼接 `zone.id.rawValue`。
- `GeneralProfileView` 的“所属防区”不再直接显示 `zone.name`，改用与其它 UI 一致的 raw 防区名 fallback。
- 新增阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_zone_display_name_record.md`，同步 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Agents/MockAICommander.swift`
- `WWIIHexV0/Agents/ZoneCommanderAgent.swift`
- `WWIIHexV0/UI/GeneralProfileView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_zone_display_name_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse WWIIHexV0/Agents/MockAICommander.swift WWIIHexV0/Agents/ZoneCommanderAgent.swift WWIIHexV0/UI/GeneralProfileView.swift`：通过，无输出。
- 定向残留扫描：`总管（.*rawValue`、`Text(zone.name)`、`name: .*zone.id.rawValue` 无命中。

未执行：

- 未跑 Xcode build、XCTest、模拟器、Probe、Smoke、Stage Regression、Dynamic Theater Regression、Full、性能测试或 app 启动；按当前 `md/test/test.md` 规则，本机默认只做轻量检查，重验证需走 GitHub Actions 或人工授权。

遗留风险：

- 本轮没有真实启动 app、打开将领档案、AI 面板或自动回合审计记录确认视觉效果。
- 同势力多个 fallback 防区展示名可能同名；内部 id、assigned zone 和调度未变。
- 并发扫描发现 legacy fallback JSON 中仍有坐标式城邑/补给点名、草稿州郡名和旧剧本履历，需后续单独做数据文案收口。

## v3.7-preflight.52 - 命令错误与源头战报可见文案收口

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在 MapEditor 与主游戏 raw id 可见文案复扫收口之后，按人工要求继续使用并发只读子 agent 扫描命令/规则源头和 UI 展示路径中仍可能进入玩家视野的 raw 坐标、raw id、英文工程词和底层解析细节；不改变 `Command`、`RegionCommand`、`ZoneDirective`、`TheaterDirective`、record id、schema、rawValue、JSON key、命令校验、AI 决策、战斗/补给/移动/经济数值或 `RuleEngine` 执行语义。

核心更新：

- `Command.displayName` 的移动命令不再显示 `q,r`，`RuleEngine` 成功结果改为“军令已执行”。
- `RegionCommand.displayName` 不再输出 `RegionMove/RegionAttack/RegionHold/RegionResupply`、军队 id、region rawValue 或 `unknown`，改为中文动作名。
- `CommandIntentAdapterError`、`AgentCommandMappingError`、`AgentDecisionParserError` 和 `TheaterDirectiveDecoderError` 不再拼接军队 id、agent id、防区 id、州郡 id、directive id 或底层 JSON / DecodingError 详情。
- `WarCommandExecutor` 的方面军令拒绝、州郡控制权变化和推进战报不再拼 `command.displayName` 坐标，不再写“动态推进”工程口径。
- `CommandExecutor` 的行军与推进战报不再直出目标坐标。
- `SupplyRules` 的撤退战报和位置 fallback 不再直出起止坐标。
- `GeneralCommandPanelView` 与 `AppContainer` 对防区名做展示 fallback，避免 `NorthWest`、`theater_*`、`front_*` 等 raw name 进入面板或交互战报。
- `ZoneCommanderAgent` 元帅 fallback 诊断不再显示 `config.id`。
- `AgentPanelView`、`EventLogView`、`DiplomacyPanelView` 和 `TurnManager` 的 raw id 净化补齐 `marshal_*`、`mock_*`、`sovereign_*`、`strategist_*`、`diplomat_*`、`governor_staff_*`、`march_commander_*`、`general_staff_*`。
- 新增阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_command_error_visible_text_record.md`，同步 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Commands/Command.swift`
- `WWIIHexV0/Commands/RegionCommand.swift`
- `WWIIHexV0/Commands/CommandIntentAdapter.swift`
- `WWIIHexV0/Commands/WarDirective.swift`
- `WWIIHexV0/Commands/WarCommandExecutor.swift`
- `WWIIHexV0/Rules/RuleEngine.swift`
- `WWIIHexV0/Rules/CommandExecutor.swift`
- `WWIIHexV0/Rules/SupplyRules.swift`
- `WWIIHexV0/Agents/AgentCommandMapper.swift`
- `WWIIHexV0/Agents/AgentDecisionParser.swift`
- `WWIIHexV0/Agents/ZoneCommanderAgent.swift`
- `WWIIHexV0/App/AppContainer.swift`
- `WWIIHexV0/UI/GeneralCommandPanelView.swift`
- `WWIIHexV0/UI/AgentPanelView.swift`
- `WWIIHexV0/UI/EventLogView.swift`
- `WWIIHexV0/UI/DiplomacyPanelView.swift`
- `WWIIHexV0/Turn/TurnManager.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_command_error_visible_text_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse WWIIHexV0/Commands/Command.swift WWIIHexV0/Commands/RegionCommand.swift WWIIHexV0/Commands/CommandIntentAdapter.swift WWIIHexV0/Commands/WarDirective.swift WWIIHexV0/Commands/WarCommandExecutor.swift WWIIHexV0/Rules/RuleEngine.swift WWIIHexV0/Rules/CommandExecutor.swift WWIIHexV0/Rules/SupplyRules.swift WWIIHexV0/Agents/AgentCommandMapper.swift WWIIHexV0/Agents/AgentDecisionParser.swift WWIIHexV0/Agents/ZoneCommanderAgent.swift WWIIHexV0/App/AppContainer.swift WWIIHexV0/UI/GeneralCommandPanelView.swift WWIIHexV0/UI/AgentPanelView.swift WWIIHexV0/UI/EventLogView.swift WWIIHexV0/UI/DiplomacyPanelView.swift WWIIHexV0/Turn/TurnManager.swift`：通过，无输出。
- 定向残留扫描：旧 `RegionMove/RegionAttack/RegionHold/RegionResupply` 展示字符串、移动坐标展示、旧动态推进词、旧英文 directive target debugDescription、`config.id` 元帅诊断、`refreshedZone.name` 交互日志等旧可见目标无命中；剩余 `RegionMove` 命中只在类型/函数名中，不是可见文本。

未执行：

- 未跑 Xcode build、XCTest、模拟器、Probe、Smoke、Stage Regression、Dynamic Theater Regression、Full、性能测试或 app 启动；按当前 `md/test/test.md` 规则，本机默认只做轻量检查，重验证需走 GitHub Actions 或人工授权。

遗留风险：

- 本轮没有真实启动 app、执行命令、触发 AI 回合或打开战报/Agent/总管面板确认视觉效果。
- 内部 record id、agent id、zone id、region id、rawValue 和 JSON schema 仍按兼容合同保留。
- 完整 v3.7 发布候选仍需要授权构建、启动、AI 多回合、界面点击、MapEditor 操作烟测和云端结果包验收。

## v3.7-preflight.51 - MapEditor 与主游戏 raw id 可见文案复扫收口

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在复核面板与记录摘要可见文案收口之后，按人工要求使用并发只读子 agent 扫描 MapEditor 和主游戏 UI 中仍可能进入玩家视野的 raw 坐标、文件名、目录名、raw id 和工程词；不改变 JSON schema、id、rawValue、objectiveId、record id、资源文件名、导出结构、加载顺序、AI 决策、命令结构、规则数值或 `Command` / `ZoneDirective -> WarCommandExecutor -> RuleEngine` 管线。

核心更新：

- `MapEditorView` 的资源区改为“战役资料”，底图偏移输入从 `X/Y` 改为“横向偏移/纵向偏移”，底图文件名展示改为“底图：已导入”，地块坐标改为“第 X 列，第 Y 行”，“胜负点代号”改为“胜负地点标记”。
- `MapEditorViewModel` 的新建、选择、导入、保存、读取、预览、导出和扩展反馈去掉 raw 坐标、文件名、目录名和“内存”工程词；自动城池/关隘名改为“未命名城池/未命名关隘”。
- `MapEditorDocument` 的州郡/方面缺省名不再回落到 raw id，改为“未命名州郡/未命名方面”。
- `MapEditorExporter` 的未分配州郡错误、自动目标名和自动粮仓名不再暴露 raw 坐标或 raw objective id。
- `MapEditorGameResourceBridge` 的未知地形错误不再拼接 raw terrain。
- `AppContainer`、`RegionInspectorView`、`UnitInspectorView` 不再向玩家直出 `q,r` 坐标。
- `MapDisplayAdapter` 对方面和行军防区展示名做 raw id fallback，遇到空值、等于 rawValue、下划线或 `theater/front` 前缀时改用“当前方面/行军防区”。
- `AgentPanelView`、`EventLogView`、`DiplomacyPanelView` 增加通用 raw id 正则净化，覆盖 `region_*`、`theater_*`、`front_zone_*`、`obj_*` 和 `agent_*`。
- 新增阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_mapeditor_main_ui_raw_id_text_record.md`，同步 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `MapEditor/MapEditorView.swift`
- `MapEditor/MapEditorViewModel.swift`
- `MapEditor/MapEditorDocument.swift`
- `MapEditor/MapEditorExporter.swift`
- `MapEditor/MapEditorGameResourceBridge.swift`
- `WWIIHexV0/App/AppContainer.swift`
- `WWIIHexV0/SpriteKit/MapDisplayAdapter.swift`
- `WWIIHexV0/UI/RegionInspectorView.swift`
- `WWIIHexV0/UI/UnitInspectorView.swift`
- `WWIIHexV0/UI/AgentPanelView.swift`
- `WWIIHexV0/UI/EventLogView.swift`
- `WWIIHexV0/UI/DiplomacyPanelView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_mapeditor_main_ui_raw_id_text_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse MapEditor/MapEditorView.swift MapEditor/MapEditorViewModel.swift MapEditor/MapEditorDocument.swift MapEditor/MapEditorExporter.swift MapEditor/MapEditorGameResourceBridge.swift WWIIHexV0/App/AppContainer.swift WWIIHexV0/SpriteKit/MapDisplayAdapter.swift WWIIHexV0/UI/RegionInspectorView.swift WWIIHexV0/UI/UnitInspectorView.swift WWIIHexV0/UI/AgentPanelView.swift WWIIHexV0/UI/EventLogView.swift WWIIHexV0/UI/DiplomacyPanelView.swift`：通过，无输出。
- 定向固定字符串残留扫描：底图 `X/Y` 占位、坐标标签、旧内存导出提示和旧选择地块坐标提示在本轮目标源码路径中无命中。

未执行：

- 未跑 Xcode build、XCTest、模拟器、Probe、Smoke、Stage Regression、Dynamic Theater Regression、Full、性能测试或 app 启动；按当前 `md/test/test.md` 规则，本机默认只做轻量检查，重验证需走 GitHub Actions 或人工授权。

遗留风险：

- 本轮没有真实启动 app 或 MapEditor 检查界面布局、弹窗和交互效果。
- 内部 id、schema、rawValue、objectiveId、record id、资源文件名和导出文件名仍按兼容合同保留英文或 ASCII。
- 完整 v3.7 发布候选仍需要授权构建、启动、AI 多回合、界面点击、MapEditor 操作烟测和云端结果包验收。

## v3.7-preflight.50 - 复核面板与记录摘要可见文案收口

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在数据加载与导出说明可见文案收口之后，继续处理战局复核面板、MapEditor 资源面板、战报面板、朝堂面板和外交面板中仍可能进入玩家视野的发布工程口径、技术兜底词和历史记录摘要直出问题；不改变 Swift 类型名、record id、JSON schema、id、rawValue、资源文件名、加载顺序、地图数据、规则数值或 `Command` / `ZoneDirective -> WarCommandExecutor -> RuleEngine` 管线。

核心更新：

- `ReleaseChecklistView` 的当前可用、后续功能和说明文案改为玩家视角，减少“已接入、结构化、只读、审计、真实模型、观察口径”等发布工程词。
- `MapEditorView` 的“导出战局数据到内存”改为“生成战局数据预览”，“资源目录已定位”改为“默认资源已连接”，“胜负点编号”改为“胜负点代号”。
- `MapEditorGameResourceBridge` 缺资源错误不再暴露具体 JSON 文件名，改为“缺少默认战局资源”。
- `AppContainer` 的 TurnManager provider 展示名从“本地模拟朝堂”改为“朝堂系统”。
- `EventLogView` 与 `AgentPanelView` 的展示净化表把 `fallback` 显示为“备用处置”、`diagnostic` 显示为“军情说明”，补齐 `Hex` / `Hexes` / `HexTile` / `hexToTheater` 等变体，并把 raw JSON 相关展示改为“军情记录”。
- `AgentPanelView` 中缺 directive type 的方面军令摘要从“诊断”改为“军情说明”。
- `DiplomacyPanelView` 对外交事件、归附交接、善后压力、善后处置、君主理由和使者摘要统一套用可见文本净化。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_review_panel_ui_record_text_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/UI/ReleaseChecklistView.swift`
- `WWIIHexV0/UI/EventLogView.swift`
- `WWIIHexV0/UI/AgentPanelView.swift`
- `WWIIHexV0/UI/DiplomacyPanelView.swift`
- `WWIIHexV0/App/AppContainer.swift`
- `MapEditor/MapEditorView.swift`
- `MapEditor/MapEditorGameResourceBridge.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_review_panel_ui_record_text_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse WWIIHexV0/UI/ReleaseChecklistView.swift WWIIHexV0/UI/EventLogView.swift WWIIHexV0/UI/AgentPanelView.swift WWIIHexV0/UI/DiplomacyPanelView.swift WWIIHexV0/App/AppContainer.swift MapEditor/MapEditorView.swift MapEditor/MapEditorGameResourceBridge.swift`：通过，无输出。
- `git diff --check`：通过，无输出。
- 本轮改动文件尾随空白扫描：无命中。
- 本轮改动文件冲突标记扫描：行首冲突标记无命中。
- 复核面板与记录摘要工程口径残留定向扫描：旧直出目标无命中；外交面板历史摘要只命中已包裹 `displayRecordText(...)` 的净化路径。

未执行：

- 未跑 Xcode build、XCTest、模拟器、Probe、Smoke、Stage Regression、Dynamic Theater Regression、Full、性能测试或 app 启动；按当前 `md/test/test.md` 规则，本机默认只做轻量检查，重验证需走 GitHub Actions 或人工授权。

遗留风险：

- 本轮没有真实启动 app、打开战局复核、MapEditor、战报、朝堂或外交面板确认视觉效果。
- 内部 id、schema、rawValue、资源文件名、SF Symbol 名称和代码类型名仍按兼容合同保留英文。
- 完整 v3.7 发布候选仍需要授权构建、启动、AI 多回合、界面点击、MapEditor 操作烟测和云端结果包验收。

## v3.7-preflight.49 - 数据加载与导出说明可见文案收口

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在自动回合与元帅诊断兜底文案收口之后，继续处理 DataLoader 初始战报、MapEditor 导出标题和 scenario dataNotes 中可能进入玩家或验收者视野的 raw scenario id、英文标题和工程词；不改变 JSON schema、id、rawValue、资源文件名、加载顺序、胜负条件、地图数据、规则数值或 `Command` / `ZoneDirective -> WarCommandExecutor -> RuleEngine` 管线。

核心更新：

- `DataLoader` 的 MapEditor 兼容数据加载初始战报改用 `scenario.displayName`，避免直出 raw scenario id。
- `MapEditorExporter` 导出的 `RegionDataSet.displayName` 从 `"<战局名> Regions"` 改为 `"<战局名> 州郡数据"`。
- `wude_618_scenario.json` 的 `dataNotes` 去掉 `component rawValue` 工程词。
- `ardennes_v0_scenario.json` 的 `dataNotes` 去掉 `v0.34` 版本工程口径和 `hex` 英文词，改为中文“地块”。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_data_loader_mapeditor_export_text_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Data/DataLoader.swift`
- `MapEditor/MapEditorExporter.swift`
- `WWIIHexV0/Data/wude_618_scenario.json`
- `WWIIHexV0/Data/ardennes_v0_scenario.json`
- `md/prompt/v3.0-隋唐迁移/v3.7_data_loader_mapeditor_export_text_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse WWIIHexV0/Data/DataLoader.swift MapEditor/MapEditorExporter.swift`：通过，无输出。
- `jq empty WWIIHexV0/Data/wude_618_scenario.json WWIIHexV0/Data/ardennes_v0_scenario.json`：通过，无输出。
- `git diff --check`：通过，无输出。
- 本轮改动文件尾随空白扫描：无命中。
- 本轮改动文件冲突标记扫描：行首冲突标记无命中。
- 数据加载与导出说明可见英文残留定向扫描：`scenario.id` 初始战报、`(document.displayName) Regions`、`component rawValue`、`代表 hex`、`地图编辑器 v0.34` 和相关英文 dataNotes 目标残留无命中。

未执行：

- 未跑 Xcode build、XCTest、模拟器、Probe、Smoke、Stage Regression、Dynamic Theater Regression、Full、性能测试或 app 启动；按当前 `md/test/test.md` 规则，本机默认只做轻量检查，重验证需走 GitHub Actions 或人工授权。

遗留风险：

- 本轮没有真实启动 app、查看首条战报、打开 MapEditor 导出预览或覆盖保存后主游戏加载确认展示效果。
- JSON key、rawValue、id、资源文件名和内部兼容字段仍按 schema / 历史兼容合同保留英文。
- 完整 v3.7 发布候选仍需要授权构建、启动、AI 多回合、界面点击、MapEditor 操作烟测和云端结果包验收。

## v3.7-preflight.48 - 自动回合与元帅诊断兜底文案收口

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在 Agent 诊断与错误兜底文案收口之后，继续处理自动回合、元帅配置和元帅解析/编译失败路径中可能进入玩家视野的旧二战人物名、英文性格描述、工程词和底层异常兜底；不改变 prompt 合同、JSON schema、id、rawValue、record id、AI 决策、命令结构、规则执行或 `Command` / `ZoneDirective -> WarCommandExecutor -> RuleEngine` 管线。

核心更新：

- `MarshalAgentConfig.automatic` 的 legacy 元帅展示名改为“伦德施泰特 / 艾森豪威尔”，旧剧本与隋唐势力的 personality 文案改为中文。
- `MarshalAgent.run` 的元帅军令解析或编译失败诊断改用中文原因兜底，不再直接拼接任意底层异常。
- `TurnManager` 的 legacy Agent D 映射失败路径改用 `userFacingError(_:)` 包装底层错误。
- `TurnManager.userFacingDiagnostic(_:)` 补齐古德里安、元帅、行军总管、君主、schema、provider、local-model、fallback、agent、directive、diagnostic、breakthrough 等常见诊断词替换。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_auto_turn_marshal_diagnostic_fallback_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Agents/ZoneCommanderAgent.swift`
- `WWIIHexV0/Turn/TurnManager.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_auto_turn_marshal_diagnostic_fallback_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse WWIIHexV0/Agents/ZoneCommanderAgent.swift WWIIHexV0/Turn/TurnManager.swift`：通过，无输出。
- `git diff --check`：通过，无输出。
- 本轮改动文件尾随空白扫描：无命中。
- 本轮改动文件冲突标记扫描：行首冲突标记无命中。
- 自动回合与元帅诊断英文残留定向扫描：旧英文人物名、旧 personality 文案和 `localizedDescription` 在本轮 Swift 改动文件中无命中。

未执行：

- 未跑 Xcode build、XCTest、模拟器、Probe、Smoke、Stage Regression、Dynamic Theater Regression、Full、性能测试或 app 启动；按当前 `md/test/test.md` 规则，本机默认只做轻量检查，重验证需走 GitHub Actions 或人工授权。

遗留风险：

- 本轮没有真实启动 app、触发自动 AI 回合、打开 Agent 面板、查看战报面板或强制制造元帅解析失败确认展示效果。
- fenced raw JSON、prompt/schema 合同、legacy agent id、资源文件名和测试/Probe 历史英文仍按内部兼容合同保留。
- 下一批可继续处理 `DataLoader` 初始战报 raw scenario id、MapEditor 导出标题和 dataNotes 中仍可能可见的英文工程词。
- 完整 v3.7 发布候选仍需要授权构建、启动、AI 多回合、界面点击、MapEditor 操作烟测和云端结果包验收。

## v3.7-preflight.47 - Agent 诊断与错误兜底文案收口

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在 legacy 将领档案可见文本收口之后，继续处理 Agent / 战报面板、legacy Agent D 映射失败和数据加载校验失败中可能进入玩家视野的英文角色名、工程词和异常兜底；不改变 prompt 合同、JSON schema、id、rawValue、record id、AI 决策、命令结构、规则执行或 `Command` / `ZoneDirective -> WarCommandExecutor -> RuleEngine` 管线。

核心更新：

- `AgentRole.displayName` 改为“君主 / 元帅 / 行军总管”。
- `AgentPanelView` 与 `EventLogView` 的诊断净化补齐 legacy 角色、古德里安、schema/model/fallback/directive/diagnostic/breakthrough 等兜底替换。
- `CommandResultSummary.mappingFailed` 和 `AgentCommandMapper` 的 region mapping 失败路径不再直接透传任意底层英文 `localizedDescription`，优先使用中文 `LocalizedError.errorDescription`，否则给出中文通用兜底。
- `DataLoaderError`、`DataLoader` 和 `AgentDecisionParser` 的常见数据加载/校验/解析失败描述改为中文。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_agent_diagnostic_error_fallback_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Agents/GameAgent.swift`
- `WWIIHexV0/Agents/AgentDecisionParser.swift`
- `WWIIHexV0/Agents/AgentDecisionRecord.swift`
- `WWIIHexV0/Agents/AgentCommandMapper.swift`
- `WWIIHexV0/Data/ScenarioDefinition.swift`
- `WWIIHexV0/Data/DataLoader.swift`
- `WWIIHexV0/UI/AgentPanelView.swift`
- `WWIIHexV0/UI/EventLogView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_agent_diagnostic_error_fallback_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse WWIIHexV0/Agents/GameAgent.swift WWIIHexV0/Agents/AgentDecisionParser.swift WWIIHexV0/Agents/AgentDecisionRecord.swift WWIIHexV0/Agents/AgentCommandMapper.swift WWIIHexV0/Data/ScenarioDefinition.swift WWIIHexV0/Data/DataLoader.swift WWIIHexV0/UI/AgentPanelView.swift WWIIHexV0/UI/EventLogView.swift`：通过，无输出。
- `git diff --check`：通过，无输出。
- 本轮改动文件尾随空白扫描：无命中。
- 本轮改动文件冲突标记扫描：无命中。
- 诊断/异常英文残留定向扫描：`return "Ruler"`、`return "Field Marshal"`、`return "Army Commander"`、`Missing data resource:`、`Map tile count`、`Unknown terrain`、`Unknown objective`、`Input is not valid UTF-8`、`Mapping failed.`、`Move order for`、`Attack order for`、`Duplicate ` 在本轮 Swift 改动文件中无命中。

未执行：

- 未跑 Xcode build、XCTest、模拟器、Probe、Smoke、Stage Regression、Dynamic Theater Regression、Full、性能测试或 app 启动；按当前 `md/test/test.md` 规则，本机默认只做轻量检查，重验证需走 GitHub Actions 或人工授权。

遗留风险：

- 本轮没有真实启动 app、触发 legacy Agent D、打开 Agent 面板、查看战报面板或加载失败路径确认展示效果。
- `AgentPromptBuilder`、`general_agents.json.personalityPrompt`、schema 示例、record id、资源文件名和 LocalLLM prompt 仍按内部合同保留英文。
- 完整 v3.7 发布候选仍需要授权构建、启动、AI 多回合、界面点击、MapEditor 操作烟测和云端结果包验收。

## v3.7-preflight.46 - Legacy 将领档案可见文本收口

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在 legacy fallback JSON 可见文本收口之后，继续处理 legacy 将领数据和将领面板中仍会直出的英文军衔、履历和技能兜底；不改变 JSON schema、id、技能 rawValue、AI prompt、加载顺序、`Command` / `ZoneDirective -> WarCommandExecutor -> RuleEngine` 管线或规则执行结果。

核心更新：

- `generals.json` 的 legacy 将领 `rank` 和 `biography` 改为中文旧剧本文案，避免 `GeneralCommandPanelView` / `GeneralProfileView` 继续直出英文军衔和履历。
- `GeneralData.commanderConfig` 的总管展示名优先使用 `localizedName`，空值才 fallback 到 `name`，减少中文将领进入元帅摘要时显示拼音或英文正名。
- `GeneralCommandPanelView` 与 `GeneralProfileView` 复用完整技能显示映射，覆盖当前隋唐与 legacy 将领 skill raw id，避免继续显示“未知军略”。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_legacy_general_profile_text_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Data/generals.json`
- `WWIIHexV0/Agents/GeneralRegistry.swift`
- `WWIIHexV0/UI/GeneralCommandPanelView.swift`
- `WWIIHexV0/UI/GeneralProfileView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_legacy_general_profile_text_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `jq empty WWIIHexV0/Data/generals.json`：通过，无输出。
- `swiftc -parse WWIIHexV0/Agents/GeneralRegistry.swift WWIIHexV0/UI/GeneralCommandPanelView.swift WWIIHexV0/UI/GeneralProfileView.swift`：通过，无输出。
- `git diff --check`：通过，无输出。
- 本轮改动文件尾随空白扫描：无命中。
- 本轮改动文件冲突标记扫描：无命中。
- legacy 将领档案可见英文残留定向扫描：`generals.json` 的 `rank`、`biography`、`localizedName` 无英文字母命中；本轮 Swift 改动文件无 `未知军略` 命中。

未执行：

- 未跑 Xcode build、XCTest、模拟器、Probe、Smoke、Stage Regression、Dynamic Theater Regression、Full、性能测试或 app 启动；按当前 `md/test/test.md` 规则，本机默认只做轻量检查，重验证需走 GitHub Actions 或人工授权。

遗留风险：

- 本轮没有真实启动 app 或打开将领面板确认展示效果。
- legacy 将领 `name`、`general_agents.json` 的 `personalityPrompt` 和 `AgentConfiguration.guderianFallback` 的英文 fallback prompt 仍按内部兼容合同保留。
- 完整 v3.7 发布候选仍需要授权构建、启动、AI 多回合、界面点击、MapEditor 操作烟测和云端结果包验收。

## v3.7-preflight.45 - Legacy JSON 可见文本收口

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在 Legacy MockAI 与元帅解析诊断中文化之后，继续处理 legacy fallback JSON 中可能经 MapEditor 兼容路径、旧剧本加载、人工验收或数据查看进入视野的英文展示字段；不改变 JSON schema、id、rawValue、加载顺序、默认隋唐入口、`Command` / `ZoneDirective -> WarCommandExecutor -> RuleEngine` 管线或规则执行结果。

核心更新：

- `ardennes_v0_scenario.json` 的 `displayName`、`dataNotes`、`keyLocations[].name` 和 `map.tiles[].cityName` 改为中文旧剧本文案，不再显示 `MapEditor Scenario`、`Generated by MapEditor`、`City q,r` 或 `Supply q,r`。
- `ardennes_v02_regions.json` 的 `displayName` 和 `regions[].city.name` 改为中文旧剧本州郡/城邑文案。
- `unit_templates.json` 的 legacy 单位模板 `displayName` 改为中文，保留 `templateId`、`components[].type` 和权重，避免破坏旧数据兼容。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_legacy_json_visible_text_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Data/ardennes_v0_scenario.json`
- `WWIIHexV0/Data/ardennes_v02_regions.json`
- `WWIIHexV0/Data/unit_templates.json`
- `md/prompt/v3.0-隋唐迁移/v3.7_legacy_json_visible_text_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `jq empty WWIIHexV0/Data/ardennes_v0_scenario.json WWIIHexV0/Data/ardennes_v02_regions.json WWIIHexV0/Data/unit_templates.json`：通过，无输出。
- `git diff --check`：通过，无输出。
- 本轮改动文件尾随空白扫描：无命中。
- 本轮改动文件冲突标记扫描：无命中。
- legacy JSON 可见英文残留定向扫描：`MapEditor Scenario`、`Generated by MapEditor`、`Region neighbors`、`City [-0-9]`、`Supply [-0-9]`、`Panzer Division`、`Motorized Division`、`Infantry Division`、`Artillery Division`、`Anti-Tank Division`、`Garrison Division` 在本轮三份 JSON 中无命中。

未执行：

- 未跑 Xcode build、XCTest、模拟器、Probe、Smoke、Stage Regression、Dynamic Theater Regression、Full、性能测试或 app 启动；按当前 `md/test/test.md` 规则，本机默认只做轻量检查，重验证需走 GitHub Actions 或人工授权。

遗留风险：

- 本轮没有真实启动 app、MapEditor 或旧 fallback 剧本确认展示效果。
- legacy `germany` / `allies`、旧剧本 id、region id、unit id、component rawValue 和 JSON key 仍按内部兼容合同保留。
- `general_agents.json` 和 `AgentConfiguration.guderianFallback` 的内部 prompt / fallback 文案仍需后续独立语义审计。
- 完整 v3.7 发布候选仍需要授权构建、启动、AI 多回合、界面点击、MapEditor 操作烟测和云端结果包验收。

## v3.7-preflight.44 - Legacy MockAI 与元帅解析诊断中文化

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在 AI 元帅/方面军令摘要中文化之后，继续处理 legacy Agent D / MockAI 和元帅 directive 解析失败路径中可能进入 Agent 面板、战报摘要、审计记录或 fallback 诊断的英文工程口径；不改变 legacy AI 启发式、目标选择、stance rawValue、JSON schema、解析合同、`Command` / `ZoneDirective -> WarCommandExecutor -> RuleEngine` 管线或规则执行结果。

核心更新：

- `MockAICommander` 的方面军令上下文从 `mock directive(s)` 改为中文“本地模拟总管生成 N 条方面军令”。
- `MockAICommander` 默认总管名称从 `Mock Commander` 改为“本地模拟总管”。
- `MockAIClient` legacy `AgentDecisionEnvelope.intent` 和 `AgentOrder.reason` 改为中文军议说明，不再在可见审计中输出 `Bastogne`、`v0.33 deployment`、`FRONT`、`DEPTH`、`GARRISON` 等工程口径。
- `TheaterDirectiveDecoderError.errorDescription` 改为中文，避免元帅军令解析失败时经 `error.localizedDescription` 带出英文原因。
- `EventLogView.displayDiagnosticText` 对齐 Agent 面板的净化表，补上 `rawJSON`、`JSON/json`、`provider`、`WarDeploymentState`、`legacy pipeline`、小写 `agent`、`directive` 和 `diagnostic` 的中文替换。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_legacy_mockai_diagnostics_text_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Agents/MockAICommander.swift`
- `WWIIHexV0/Agents/MockAIClient.swift`
- `WWIIHexV0/Commands/WarDirective.swift`
- `WWIIHexV0/UI/EventLogView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_legacy_mockai_diagnostics_text_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse WWIIHexV0/Agents/MockAICommander.swift WWIIHexV0/Agents/MockAIClient.swift WWIIHexV0/Commands/WarDirective.swift WWIIHexV0/UI/EventLogView.swift`：通过，无输出。
- `git diff --check`：通过，无输出。
- 本轮改动文件尾随空白扫描：无命中。
- 本轮改动文件冲突标记扫描：无命中。
- Agent/AI 诊断英文残留定向扫描：`mock directive(s)`、`Mock Commander`、`Break through toward Bastogne`、`v0.33 deployment`、`FRONT unit`、`DEPTH reserve`、`GARRISON unit`、`Theater directive JSON`、`Malformed theater directive`、`issuer mismatch` 等本轮目标残留无命中。

未执行：

- 未跑 Xcode build、XCTest、模拟器、Probe、Smoke、Stage Regression、Dynamic Theater Regression、Full、性能测试或 app 启动；按当前 `md/test/test.md` 规则，本机默认只做轻量检查，重验证需走 GitHub Actions 或人工授权。

遗留风险：

- 本轮没有真实启动 app、legacy Agent D 回合、AI 自动回合、Agent 面板或战报面板确认。
- `MockAIClient` 的 `Bastogne` 目标选择器和注释仍保留作 legacy 回归行为，不作为本轮普通玩家可见输出。
- `AgentPromptBuilder`、`LocalLLMDecisionProvider`、`rawJSON` 字段名、JSON key、stance rawValue 和测试/Probe 历史英文仍按内部合同保留。
- general agent 内部 prompt、fallback prompt 和旧数据 rawValue 仍待后续独立数据切片处理。
- 完整 v3.7 发布候选仍需要授权构建、启动、AI 多回合、界面点击、MapEditor 操作烟测和云端结果包验收。

## v3.7-preflight.43 - AI 元帅/方面军令摘要中文化

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在默认数据说明和补给战报中文化之后，继续处理 `MarshalAgent -> TheaterDirective -> ZoneDirective` 链路中可能进入 AI 面板、战报摘要、审计记录或未来 raw JSON 展示的元帅意图、方面军令摘要和保底诊断英文工程口径；不改变 AI 决策策略、JSON schema、rawValue、字段名、解析合同、`Command` / `ZoneDirective -> WarCommandExecutor -> RuleEngine` 管线或规则执行结果。

核心更新：

- `TheaterCommanderPool` 生成的方面军令上下文从 `zone directive(s)` 改为中文“生成 N 条方面军令”。
- 模拟元帅写入 `TheaterDirective.rationale` 的 `Simulated marshal JSON`、`strength ratio` 和 `front status` 文案改为中文军议说明，并用 `TacticName.displayName` 展示战术名。
- 模拟元帅 `TheaterDirectiveEnvelope.summary` 从 `theater directive(s) from summarized fronts` 改为中文前线汇总摘要。
- `strategicIntent` 三种战略偏向的字符串改为中文，保留 JSON 字段名和解码合同。
- `TheaterDirectiveCompiler` 的编译后 `theaterContext` 从 `Compiled ... zone directive(s)` 改为中文“已编成 N 条方面军令”。
- 元帅势力不匹配和元帅军令解析/编译失败的 fallback 诊断改为中文，避免 `AgentDecisionRecord.errors` 继续直出 `Marshal ... fallback used` 或 `Fallback TheaterCommanderPool used`。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_ai_marshal_directive_summary_text_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Agents/ZoneCommanderAgent.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_ai_marshal_directive_summary_text_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse WWIIHexV0/Agents/ZoneCommanderAgent.swift`：通过，无输出。
- `git diff --check`：通过，无输出。
- 本轮改动文件尾随空白扫描：无命中。
- 本轮改动文件冲突标记扫描：无命中。
- AI 摘要英文残留定向扫描：`zone directive(s)`、`theater directive(s)`、`Simulated marshal JSON`、`Compiled ... zone directive`、`front status`、`strength ratio`、`Fallback TheaterCommanderPool`、`fallback used`、`Marshal directive decode`、` Commander` 在 `ZoneCommanderAgent.swift` 无命中。

未执行：

- 未跑 Xcode build、XCTest、模拟器、Probe、Smoke、Stage Regression、Dynamic Theater Regression、Full、性能测试或 app 启动；按当前 `md/test/test.md` 规则，本机默认只做轻量检查，重验证需走 GitHub Actions 或人工授权。

遗留风险：

- 本轮没有真实启动 app、AI 回合或 Agent 面板确认，只做源码级文案和轻量语法检查。
- `rawTheaterJSON` 属性名、JSON fenced 输出、`strategicIntent` 字段名、directive schema key 和 tactic rawValue 仍按内部解析合同保留。
- `MarshalAgentConfig.personality` 等内部 prompt / legacy 配置文案仍有英文，本轮未纳入普通玩家可见摘要收口。
- 完整 v3.7 发布候选仍需要授权构建、启动、AI 多回合、界面点击、MapEditor 操作烟测和云端结果包验收。

## v3.7-preflight.42 - 默认数据说明中文化

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在 MapEditor 可见文案收口之后，继续处理默认隋唐数据、数据加载入口和补给规则战报中可能进入战报、导出 JSON 或人工验收视野的英文工程说明；不改变 JSON schema、rawValue、scenario id、objective id、unit id、胜负条件、地图数据、加载顺序、补给/撤退/围困规则数值或运行时规则。

核心更新：

- `DataLoader` 的 MapEditor 兼容数据加载初始战报改为中文“已载入地图编辑器战局数据”，不再显示 `Loaded ... from MapEditor-compatible JSON`。
- `MapEditorExportMetadata.suitangDraft.dataNotes` 改为中文，保留“地块是战术权威、州郡和方面是战略聚合/初始归属”的架构边界。
- `MapEditorExportMetadata.legacyArdennes.dataNotes` 改为中文旧战局说明，避免 legacy 导出 metadata 继续写入英文说明。
- MapEditor 从补给地块派生 `keyLocations` 时，默认地点名从 `Supply q,r` 改为 `粮仓 q,r`。
- `wude_618_scenario.json` 的 `dataNotes` 改为中文，说明该数据已从 v3.2 后持续补上胜负、存档、外交、州郡经营、归附和展示层收口。
- `SupplyRules` 写入战报的补员、撤退、撤退失败、围困损耗和退却整顿事件改为中文，不再显示 `strength`、`retreated from`、`failed to retreat` 或 `encirclement attrition`。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_data_notes_visible_text_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Data/DataLoader.swift`
- `WWIIHexV0/Data/wude_618_scenario.json`
- `WWIIHexV0/Rules/SupplyRules.swift`
- `MapEditor/MapEditorExporter.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_data_notes_visible_text_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse MapEditor/MapEditorExporter.swift WWIIHexV0/Data/DataLoader.swift WWIIHexV0/Rules/SupplyRules.swift`：通过，无输出。
- `jq empty WWIIHexV0/Data/wude_618_scenario.json`：通过，无输出。
- 英文残留定向扫描：`Generated by MapEditor for the Sui-Tang`、`Generated by MapEditor v0.34`、`Region neighbors`、`Hex remains tactical authority`、`ComponentType is still`、`legacy combat bridge`、`Loaded ... MapEditor-compatible JSON`、`Supply \(`、`retreated from`、`failed to retreat`、`encirclement attrition`、`completed retreat recovery` 等本轮目标残留无命中。
- `git diff --check`：通过，无输出。
- 改动文件尾随空白扫描：无命中。
- 改动文件冲突标记扫描：无命中。

未执行：

- 未跑 Xcode build、XCTest、模拟器、Probe、Smoke、Stage Regression、Dynamic Theater Regression、Full、性能测试或 app / MapEditor 启动；按当前 `md/test/test.md` 规则，本机默认只做轻量检查，重验证需走 GitHub Actions 或人工授权。

遗留风险：

- 本轮没有验证真实 app 战报首条日志、MapEditor 导出 JSON 预览或覆盖保存后的主游戏加载效果。
- `DataLoader` 的开发校验错误仍保留若干英文技术信息，当前判断主要服务数据开发和历史测试断言，未纳入本轮普通玩家文案收口。
- 完整 v3.7 发布候选仍需要授权构建、启动、MapEditor 操作烟测、主游戏多回合验证和云端结果包验收。

## v3.7-preflight.41 - MapEditor 可见文案收口

完成日期：2026-07-06

性质：完整 v3.7 发布候选前置补洞。在本局执掌势力选择之后，继续处理 MapEditor 默认隋唐编辑入口中仍可能直出的旧势力选项、工程词、raw id、系统错误、完整路径和单位英文短标；不改变 JSON schema、rawValue、导出 key、资源文件名、主游戏规则、存档结构或运行时验证结论。

核心更新：

- `MapEditorView` 的州郡、方面和信息面板显示改为名称优先，资源目录和底图路径只显示简化名称，操作说明改为中文产品口径。
- MapEditor 的补给阵营、控制方、军队阵营和地点势力 Picker 改用 `Faction.suitangTurnOrder`，在默认隋唐编辑器 UI 隐藏 legacy 势力选项；`Faction.allCases` 本身不改，继续服务兼容解析和内部规则。
- `MapEditorViewModel` 的创建、读取、保存、导出和错误反馈改为中文泛化说明，避免把 raw id、系统错误详情或完整路径直接显示给编辑者。
- `MapEditorCanvasScene` 的单位短标改为步、骑、弩、器、守、甲、炮、机、军等中文短标。
- `MapEditorExporter` 与 `MapEditorGameResourceBridge` 的导出/资源桥错误改为中文可见说明，保留内部 schema、rawValue、objective id、unit id 和资源文件名。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_mapeditor_visible_text_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `MapEditor/MapEditorView.swift`
- `MapEditor/MapEditorViewModel.swift`
- `MapEditor/MapEditorCanvasScene.swift`
- `MapEditor/MapEditorExporter.swift`
- `MapEditor/MapEditorGameResourceBridge.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_mapeditor_visible_text_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse MapEditor/MapEditorView.swift MapEditor/MapEditorViewModel.swift MapEditor/MapEditorCanvasScene.swift MapEditor/MapEditorExporter.swift MapEditor/MapEditorGameResourceBridge.swift`：通过，无输出。
- `git diff --check`：通过，无输出。
- MapEditor 定向可见残留扫描：无 `Faction.allCases`、`Option`、`localizedDescription`、`ARM / ART / MOT / INF` 等需继续修改的可见残留；`Optional(...)`、`id: \.self`、`url.path` 等命中为 Swift 绑定、内部标识或文件选择器必要用途。
- 改动的 MapEditor 和文档文件尾随空白 / 冲突标记扫描：无命中。

未执行：

- 未跑 Xcode build、XCTest、模拟器、Probe、Smoke、Stage Regression、Dynamic Theater Regression、Full、性能测试或 app / MapEditor 启动；按当前 `md/test/test.md` 规则，本机默认只做轻量检查，重验证需走 GitHub Actions 或人工授权。

遗留风险：

- 本轮是静态文案和 Swift 语法级收口，未做真实 MapEditor 运行、点击、布局、导入导出往返或资源覆盖验证。
- 可见文案扫描不等于穷尽 UI 审计；异常数据、系统文件选择器或调试路径仍可能暴露内部字段。
- 完整 v3.7 发布候选仍需要授权构建、启动、MapEditor 操作烟测、主游戏多回合验证和云端结果包验收。

## v3.7-preflight.40 - 本局执掌势力选择

完成日期：2026-07-05

性质：完整 v3.7 发布候选前置补洞。在 UI 文案复扫收口之后，补齐总提示词要求的“玩家可选择至少一个势力”最小闭环：玩家执掌势力进入 `GameState` 与本地存档，基础设置页可切换当前局势内可玩的参战势力，通用回合阶段按 `GameState.playerFaction` 判定玩家/自动行动；不重排当前回合顺序，不绕过 `Command` / `ZoneDirective -> WarCommandExecutor -> RuleEngine`，不引入多槽位存档或完整多势力战役验收。

核心更新：

- `GameState` 新增 `playerFaction`，Codable 对旧存档做兼容默认：隋唐剧本默认唐，legacy 路径默认盟军或当前默认人控势力。
- `DataLoader` 从 scenario `playerFaction` 初始化本局执掌势力，`wude_618` 冷启动仍默认唐可玩。
- `CommandExecutor` 的通用 `.playerCommand` / `.aiCommand` 阶段推进改为对比 `state.playerFaction`，使玩家切换执掌势力后轮转判定跟随存档状态。
- `AppContainer` 改为从 `gameState.playerFaction` 读取当前玩家势力，基础设置切换会调整当前 phase、清空选择、保存本局，并在需要时继续自动回合。
- 新局和重置会保留当前偏好势力；若新局不可用则回落到当前剧本可玩势力。继续存档直接恢复 `GameState.playerFaction`。
- `GameSettingsView` 增加“执掌势力”选择，`HUDView` 和 `ReleaseChecklistView` 显示执掌势力；HUD 回合显示改为“第 N 回合，共 M 回合”。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_player_faction_selection_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Core/GameState.swift`
- `WWIIHexV0/Data/DataLoader.swift`
- `WWIIHexV0/Rules/CommandExecutor.swift`
- `WWIIHexV0/App/AppContainer.swift`
- `WWIIHexV0/UI/GameSettingsView.swift`
- `WWIIHexV0/UI/HUDView.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `WWIIHexV0/UI/ReleaseChecklistView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_player_faction_selection_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse WWIIHexV0/Core/GameState.swift WWIIHexV0/Data/DataLoader.swift WWIIHexV0/Rules/CommandExecutor.swift WWIIHexV0/App/AppContainer.swift WWIIHexV0/UI/GameSettingsView.swift WWIIHexV0/UI/HUDView.swift WWIIHexV0/UI/RootGameView.swift WWIIHexV0/UI/ReleaseChecklistView.swift`：通过，无输出。
- `git diff --check`：通过，无输出。
- `rg -n "[[:blank:]]$" ...`：无尾随空白命中。
- `rg -n "^(<<<<<<<|=======|>>>>>>>)" ...`：无冲突标记命中。
- `rg -n "v3\\.7-preflight\\.40|player_faction|执掌势力|本局执掌" ...`：命中均为本轮代码、文档和阶段记录中的预期内容。
- 针对本轮触及 UI/App 的可见残留扫描：未再命中 HUD 回合斜线；MapEditor 仍有独立可见文案残留，已记录为下一切片候选，未混入本轮势力选择改动。

未执行：

- 未跑 Xcode build、XCTest、模拟器、Probe、Smoke、Stage Regression、Dynamic Theater Regression、Full、性能测试或 app 启动；按当前 `md/test/test.md` 规则，本机默认只做轻量检查，重验证需走 GitHub Actions 或人工授权。

遗留风险：

- 本轮是最小“本局执掌势力”闭环，不等于完整多势力战役平衡或完整势力选择开局流程。
- 切换执掌势力不会重排当前 turn order；若当前行动势力不是新执掌势力，会进入自动阶段直到轮到玩家势力，设置页切换可能因此触发自动回合。
- 新增存档字段向后兼容旧存档；字段缺失或 rawValue 异常会回退默认执掌势力，旧版本 app 读取新存档未验证。
- 未做真实运行 UI 验证，设置页 picker、自动回合衔接、存档恢复和多势力切换后的完整多回合体验仍需授权运行时验证。

## v3.7-preflight.39 - UI 文案复扫收口

完成日期：2026-07-05

性质：完整 v3.7 发布候选前置补洞。在剩余 UI 文案抽样收口之后，按并发子 agent 复扫结果继续清理玩家可见的发布验收口径、规则工程口径、旧剧本 fallback、斜线分隔和 `N/M` 兵力显示；不改变存档 schema、内部审计 id、命令结构、规则执行、AI 决策、地图数据或运行时验证结论。

核心更新：

- `ReleaseChecklistView` 的“首发说明 / 已完成事项 / 待实机复核 / 基础检查”等口径改为“战局说明 / 当前可用 / 待继续观察 / 局势快照”，不再把玩家面板描述成发布或实机验收门禁。
- `AppContainer` 的存档失败、新局重置、自动回合、州郡经营、外交行动、玩家方面军令和普通军令反馈改为“当前战局 / 军令结果 / 战局判定 / 暂不可用”口径。
- `DiplomacyPanelView` 不再直出 `boundaryNote`，旧剧本势力 fallback 改为历史势力或当前战局角色，善后进度不再显示 `N/M`。
- `EventLogView` metadata 改用中文逗号；`RegionInspectorView`、`UnitInspectorView` 列表摘要改用顿号；单位提示、将领所属军队和地图单位短标不再显示 `N/M`。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_visible_ui_followup_text_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/UI/ReleaseChecklistView.swift`
- `WWIIHexV0/App/AppContainer.swift`
- `WWIIHexV0/UI/DiplomacyPanelView.swift`
- `WWIIHexV0/UI/EventLogView.swift`
- `WWIIHexV0/UI/RegionInspectorView.swift`
- `WWIIHexV0/UI/UnitInspectorView.swift`
- `WWIIHexV0/UI/UnitTooltipView.swift`
- `WWIIHexV0/UI/GeneralProfileView.swift`
- `WWIIHexV0/SpriteKit/UnitNode.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_visible_ui_followup_text_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse WWIIHexV0/UI/AgentPanelView.swift WWIIHexV0/UI/FirstTurnGuideView.swift WWIIHexV0/UI/ReleaseCandidateMenu.swift WWIIHexV0/UI/HUDView.swift WWIIHexV0/UI/GameSettingsView.swift WWIIHexV0/UI/GeneralProfileView.swift WWIIHexV0/UI/ReleaseChecklistView.swift WWIIHexV0/UI/EconomyPanelView.swift WWIIHexV0/UI/EventLogView.swift WWIIHexV0/UI/DiplomacyPanelView.swift WWIIHexV0/UI/RegionInspectorView.swift WWIIHexV0/UI/GeneralCommandPanelView.swift WWIIHexV0/UI/UnitTooltipView.swift WWIIHexV0/UI/UnitInspectorView.swift WWIIHexV0/App/AppContainer.swift WWIIHexV0/SpriteKit/UnitNode.swift`：通过，无输出。
- `git diff --check`：通过，无输出。
- `rg -n "[[:blank:]]$" ...`：无尾随空白命中。
- `rg -n "^(<<<<<<<|=======|>>>>>>>)" ...`：无冲突标记命中。
- `rg -n "首发说明|已完成事项|待实机复核|实机复核|基础检查|命令结果|命令不可用|命令被规则拒绝|规则校验|规则结算|默认剧本|旧剧本|不直接改占领|Text\\((governanceRecord|record)\\.boundaryNote\\)|[0-9]+/[0-9]+|strength\\)/\\(maxStrength|strength\\) / \\(maxStrength" ...`：无命中。
- `rg -n '"[^"]*( / | - |[A-Za-z]+/[A-Za-z]+|[0-9]+/[0-9]+)[^"]*"' ...`：无命中。

未执行：

- 未跑 Xcode build、XCTest、模拟器、Probe、Smoke、Stage Regression、Dynamic Theater Regression、Full、性能测试或 app 启动；按当前 `md/test/test.md` 规则，本机默认只做轻量检查，重验证需走 GitHub Actions 或人工授权。

遗留风险：

- 本轮是静态展示层复扫收口，不等于完整 UI 文案穷尽审计。
- 未做真实运行 UI 验证，动态字体、VoiceOver 实机读法、滚动和布局仍未确认。
- 完整发布候选仍需要授权构建、启动、界面点击烟测、观察者多回合和云端结果包验收。

## v3.7-preflight.38 - 剩余 UI 文案抽样收口

完成日期：2026-07-05

性质：完整 v3.7 发布候选前置补洞。在 App/UI 边界文案收口之后，继续抽样处理未完全覆盖的开局引导、HUD、经济、战报、外交、州郡经营、总管和单位提示里的玩家可见工程感文案；不改变存档 schema、内部审计 id、命令结构、规则执行、AI 决策、地图数据或运行时验证结论。

核心更新：

- `FirstTurnGuideView` 的“朝堂和 AI 行动”改为“朝堂自动行动”，“军令校验和规则引擎”改为“军令规则判定”，发布/构建/烟测提示改为战局复核提示。
- `FirstTurnGuideView`、`HUDView`、`AppContainer`、`ReleaseChecklistView` 的旧剧本 / 草稿 fallback 改为“当前战局”或“自定战局”，不再直出 raw id、草稿或旧版口径。
- `ReleaseCandidateMenu` / `ReleaseChecklistView` 的“发布前检查 / 发布候选检查”改为“战局复核 / 当前战局”，发布测试词改为实机复核口径。
- `AgentPanelView` 不再展开显示 `rawJSON`，`contextSummary`、`result.message`、`result.errors` 统一经过展示净化。
- `EconomyPanelView`、`EventLogView`、`DiplomacyPanelView`、`RegionInspectorView`、`GeneralCommandPanelView` 的摘要文案改用中文标点，不再使用斜线或竖线工程分隔。
- `UnitTooltipView` 的 VoiceOver 兵力读法改为“兵力 N，上限 M”。
- `GeneralProfileView` 的将领画像 fallback 改为“将 / 将领”，不再从 raw 英文 id 生成缩写。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_visible_remaining_ui_text_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/UI/FirstTurnGuideView.swift`
- `WWIIHexV0/UI/HUDView.swift`
- `WWIIHexV0/UI/EconomyPanelView.swift`
- `WWIIHexV0/UI/EventLogView.swift`
- `WWIIHexV0/UI/AgentPanelView.swift`
- `WWIIHexV0/UI/DiplomacyPanelView.swift`
- `WWIIHexV0/UI/RegionInspectorView.swift`
- `WWIIHexV0/UI/GeneralCommandPanelView.swift`
- `WWIIHexV0/UI/GeneralProfileView.swift`
- `WWIIHexV0/UI/UnitTooltipView.swift`
- `WWIIHexV0/UI/UnitInspectorView.swift`
- `WWIIHexV0/UI/ReleaseCandidateMenu.swift`
- `WWIIHexV0/UI/ReleaseChecklistView.swift`
- `WWIIHexV0/UI/GameSettingsView.swift`
- `WWIIHexV0/App/AppContainer.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_visible_remaining_ui_text_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse WWIIHexV0/UI/AgentPanelView.swift WWIIHexV0/UI/FirstTurnGuideView.swift WWIIHexV0/UI/ReleaseCandidateMenu.swift WWIIHexV0/UI/HUDView.swift WWIIHexV0/UI/GameSettingsView.swift WWIIHexV0/UI/GeneralProfileView.swift WWIIHexV0/UI/ReleaseChecklistView.swift WWIIHexV0/UI/EconomyPanelView.swift WWIIHexV0/UI/EventLogView.swift WWIIHexV0/UI/DiplomacyPanelView.swift WWIIHexV0/UI/RegionInspectorView.swift WWIIHexV0/UI/GeneralCommandPanelView.swift WWIIHexV0/UI/UnitTooltipView.swift WWIIHexV0/UI/UnitInspectorView.swift WWIIHexV0/App/AppContainer.swift WWIIHexV0/SpriteKit/UnitNode.swift`：通过，无输出。
- `git diff --check`：通过，无输出。
- `rg -n "[[:blank:]]$" ...`：无尾随空白命中。
- `rg -n "<<<<<<<|=======|>>>>>>>" ...`：无冲突标记命中。
- `rg -n "(^|[^A-Za-z0-9_])Text\\(contextSummary\\)|(^|[^A-Za-z0-9_])Text\\(rawJSON\\)|审计原文|发布前检查|发布候选|完整发布|运行时烟测|完整构建|自动化测试|模拟器|性能重测|不声称已可发布|规则引擎|军令校验|隋唐地图草稿|旧版剧本|当前会话|写入本地存档" WWIIHexV0/UI WWIIHexV0/App WWIIHexV0/SpriteKit`：无命中。
- UI 可见词正则抽样扫描：仅命中 Swift 字符串插值源码名或已净化的 `contextSummary` 展示路径，复核后无需继续修改。

未执行：

- 未跑 Xcode build、XCTest、模拟器、Probe、Smoke、Stage Regression、Dynamic Theater Regression、Full、性能测试或 app 启动；按当前 `md/test/test.md` 规则，本机默认只做轻量检查，重验证需走 GitHub Actions 或人工授权。

遗留风险：

- 本轮是抽样收口，不等于完整 UI 文案穷尽审计。
- 未做真实运行 UI 验证，动态字体、VoiceOver 实机读法、滚动和布局仍未确认。
- 完整发布候选仍需要授权构建、启动、界面点击烟测、观察者多回合和云端结果包验收。

## v3.7-preflight.37 - App/UI 边界文案收口

完成日期：2026-07-05

性质：完整 v3.7 发布候选前置补洞。在战报源头事件文案收口之后，继续处理 App 与 UI 边界仍可能露出的系统错误、provider、scenario raw id、发布检查工程词和详情面板 raw id；不改变存档 schema、内部审计 id、命令结构、规则执行、AI 决策、地图数据或运行时验证结论。

核心更新：

- `AppContainer` 的存档读取、继续、删除和自动保存失败不再把 `localizedDescription` 写入 HUD、设置、发布检查或交互日志，改用中文泛化失败说明。
- 自动回合完成日志不再显示 `AI \(provider)`、`System` 或 `MarshalDirective` 等来源字符串；命令面板不再直接显示外部 `CommandResult.message`。
- 新局交互日志使用剧本中文名，不再直出 `scenarioId`。
- `ReleaseChecklistView` 的发布检查面板改用玩家语义，收口 Command / RuleEngine、hex、Xcode / UI / build、MapEditor、GameState、旧版本标题和剧本 ID 等工程词或 raw id。
- `MapDisplayAdapter` 为州郡/军队详情补充州郡名、方面名和防区名，并让地图颜色派生保持 tile/hex 优先；`RegionInspectorView`、`UnitInspectorView` 不再显示相关 raw id。
- 末轮复核后将旧剧本 fallback 从“调试剧本”改为“旧版剧本”，未知剧本 fallback 统一为“当前剧本”。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_visible_app_ui_boundary_text_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/App/AppContainer.swift`
- `WWIIHexV0/SpriteKit/MapDisplayAdapter.swift`
- `WWIIHexV0/UI/ReleaseChecklistView.swift`
- `WWIIHexV0/UI/RegionInspectorView.swift`
- `WWIIHexV0/UI/UnitInspectorView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_visible_app_ui_boundary_text_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- 完整本轮轻量检查见最终交付记录。

未执行：

- 未跑 Xcode build、XCTest、模拟器、Probe、Smoke、Stage Regression、Dynamic Theater Regression、Full、性能测试或 app 启动；按当前 `md/test/test.md` 规则，本机默认只做轻量检查，重验证需走 GitHub Actions 或人工授权。

遗留风险：

- 本轮未做真实运行 UI 验证，发布检查面板、设置存档反馈、命令面板和详情面板的布局、滚动、动态字体和 VoiceOver 仍未确认。
- 完整发布候选仍需要授权构建、启动、界面点击烟测、观察者多回合和云端结果包验收。

## v3.7-preflight.36 - 战报源头事件文案收口

完成日期：2026-07-05

性质：完整 v3.7 发布候选前置补洞。在战报展示层和总管预览文案收口之后，继续处理规则、军令、战略同步和经济系统写入 `GameState.eventLog` 的上游 message；不改变命令结构、规则执行、战斗数值、经济数值、存档字段、日志 schema 或地图数据。

核心更新：

- `CommandExecutor` 的行军、战斗、反击、固守、准退、归附交接、回合推进、动态方面推进和 combatLog 文案中文化，不再写入 `HOLD`、`RETREATABLE`、`Turn advanced`、英文 `hex` 或 `strength / automatic retreat` 等工程词。
- `WarCommandExecutor` 的方面军令拒绝原因改用 `CommandValidationError.displayName`，前线事件改为中文，不再直出 validation rawValue、`regionId.rawValue` 或 `advancingTheaterId.rawValue`。
- `StrategicStateSynchronizer` 的州郡控制权变化事件改用 `region.name` 和中文句式。
- `EconomyRules` 的府库初始化与生产部署源头事件中文化，新生产军队展示名不再带 `createdTurn-index` 调试编号；内部 production id 保持兼容。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_visible_event_source_text_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Rules/CommandExecutor.swift`
- `WWIIHexV0/Commands/WarCommandExecutor.swift`
- `WWIIHexV0/Rules/StrategicStateSynchronizer.swift`
- `WWIIHexV0/Rules/EconomyRules.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_visible_event_source_text_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- 完整本轮轻量检查见最终交付记录。

未执行：

- 未跑 Xcode build、XCTest、模拟器、Probe、Smoke、Stage Regression、Dynamic Theater Regression、Full、性能测试或 app 启动；按当前 `md/test/test.md` 规则，本机默认只做轻量检查，重验证需走 GitHub Actions 或人工授权。

遗留风险：

- App/UI 入口仍存在存档错误、AI provider、scenario id、发布检查面板和详情面板 raw id 等玩家可见风险，已由并发只读扫描记录为下一刀候选。
- 真实战报滚动、动态字体、VoiceOver 读法和完整多回合链路未经过运行验证。
- 完整发布候选仍需要授权 Xcode build、iOS/macOS 启动、UI 点击烟测和观察者多回合验证。

## v3.7-preflight.35 - 战报与总管预览文案收口

完成日期：2026-07-05

性质：完整 v3.7 发布候选前置补洞。在 AI 诊断文案收口之后，继续处理上一轮遗留的战报 metadata、战报摘要和总管预备军令预览中的玩家可见 raw id、英文工程词和调试格式；不改变命令结构、AI 决策策略、规则执行、存档字段、日志 schema 或地图数据。

核心更新：

- `EventLogView` 的战报 metadata 不再显示 `relatedRecordId` 原始字符串，改为外交审计、局势审计或审计记录等玩家语义标签。
- `EventLogView` 的“AI 意图”改为“军议意图”，legacy `move / attack / hold / resupply` 和常见 directive / JSON / agent / command 调试意图改为中文或泛化摘要。
- `EventLogView` 普通战报正文和“本回合重点”复用展示层 formatter，对 `war_directive_*`、`player_directive_*`、`player_operation_*`、`submission_*`、`diplomacy_event_*` 等常见审计 id 做整段泛化。
- `GeneralCommandPanelView` 的预备军令摘要不再拼接 `targetRegionId.rawValue`、`sourceRegionId.rawValue` 或 `zoneId.rawValue`，改用当前目标州郡名、目标州郡、本防区州郡或防区名。
- `GeneralCommandPanelView` 的预备军令格式从斜线工程格式改为中文冒号摘要，头像 badge 在缺少本地化名称时使用中文占位，不再 fallback 到 raw `general.name`。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_visible_battle_report_command_preview_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/UI/EventLogView.swift`
- `WWIIHexV0/UI/GeneralCommandPanelView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_visible_battle_report_command_preview_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- 完整本轮轻量检查见最终交付记录。

未执行：

- 未跑 Xcode build、XCTest、模拟器、Probe、Smoke、Stage Regression、Dynamic Theater Regression、Full、性能测试或 app 启动；按当前 `md/test/test.md` 规则，本机默认只做轻量检查，重验证需走 GitHub Actions 或人工授权。

遗留风险：

- 战报正文仍可能从更早或更深层上游 message 带入未覆盖的 raw id 模式，需要后续按实际命中继续补 formatter 或上游源头。
- 真实战报滚动、动态字体、VoiceOver 读法和总管面板预备军令实际布局未经过运行验证。
- 完整发布候选仍需要授权 Xcode build、iOS/macOS 启动、UI 点击烟测和观察者多回合验证。

## v3.7-preflight.34 - 玩家可见 AI 诊断文案收口

完成日期：2026-07-05

性质：完整 v3.7 发布候选前置补洞。在外交/朝堂文案收口之后，继续清理 AI 决策面板、方面军令诊断、legacy Agent D 解析/映射错误和命令结果摘要中的玩家可见英文、raw id、工程术语和 enum rawValue；不改变命令结构、AI 决策策略、规则执行、存档字段或地图数据。

核心更新：

- `TurnManager` 的 AI 回合失败、空军令、方面军令空结果、命令拒绝、结束回合失败、太守/使者/归附交接跳过诊断和部署诊断改为中文玩家语义。
- `TurnManager.contextSummary` 不再显示 agent id 或英文 divisions/objectives，朝堂附加审计标题改为中文。
- `CommandValidationError.displayName` 成为统一校验错误中文出口，`RuleEngine` 与 `AgentDecisionRecord` 不再把 `wrongPhase`、`noPath` 等 raw case 写入 AI 面板。
- `Command.displayName` 从 `Move(...)`、`Attack(...)`、`QueueProduction(...)` 等工程格式改为中文命令摘要。
- `CommandIntentAdapterError`、`AgentDecisionParserError` 和 `AgentCommandMappingError` 的可见错误描述中文化，覆盖 legacy Agent D 失败路径。
- `AgentPanelView` 的决策者、来源、君主、朝堂步骤、重点方面、目标州郡和方面指令摘要不再直出 raw agent id、provider suffix、front zone id 或 region id，真实 raw JSON 改为折叠“审计原文”。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_visible_ai_diagnostics_text_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Turn/TurnManager.swift`
- `WWIIHexV0/UI/AgentPanelView.swift`
- `WWIIHexV0/Commands/Command.swift`
- `WWIIHexV0/Commands/CommandValidation.swift`
- `WWIIHexV0/Commands/CommandIntentAdapter.swift`
- `WWIIHexV0/Rules/RuleEngine.swift`
- `WWIIHexV0/Agents/AgentDecisionRecord.swift`
- `WWIIHexV0/Agents/AgentDecisionParser.swift`
- `WWIIHexV0/Agents/AgentCommandMapper.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_visible_ai_diagnostics_text_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- 完整本轮轻量检查见最终交付记录。

未执行：

- 未跑 Xcode build、XCTest、模拟器、Probe、Smoke、Stage Regression、Dynamic Theater Regression、Full、性能测试或 app 启动；按当前 `md/test/test.md` 规则，本机默认只做轻量检查，重验证需走 GitHub Actions 或人工授权。

遗留风险：

- AI 面板真实布局、折叠审计原文、动态字体和 VoiceOver 读法未经过运行验证。
- `AgentPanelView` 暂无 `GameState` 名称映射上下文，目标州郡和重点防区以数量/泛化名称显示。
- 战报 metadata 和总管命令预览已由 v3.7-preflight.35 继续收口；其他边界调试路径仍可能存在 raw id 或内部工程词。

## v3.7-preflight.33 - 玩家可见外交/朝堂文案收口

完成日期：2026-07-05

性质：完整 v3.7 发布候选前置补洞。在第一批 App/AI 记录、bootstrap 战报、朝堂面板和将领技能调试文案收口之后，继续清理外交面板、朝堂决策摘要、州郡/军队详情和基础可访问性入口里一批低风险玩家可见 raw/debug 文案；不改变命令、外交关系、AI 决策策略、规则执行、存档字段或地图数据。

核心更新：

- `DiplomacyPanelView` 的势力、盟从和关系显示不再直出 `blocId.rawValue` 或 country raw id，君主/谋主区不再显示 `Agent` 标签、agent id 或 front zone raw id。
- 外交动作说明去掉 `Command` / `RuleEngine` 工程词，改为“规则校验、只更新关系记录”的玩家语义。
- `DiplomacyState` 的外交摘要、legacy 盟从/国家名称、归附交接和善后摘要中的英文/hex 术语中文化。
- `RulerAgent` 写入朝堂记录的君主 rationale 和 directive context 中文化，不再把 ruler id 或 raw front zone id 写进摘要。
- `MapDisplayAdapter` 的州郡要地状态从 `None` / `controlled` 改为中文。
- `RegionInspectorView`、`UnitInspectorView`、`MapDisplayLayer` 和 `RootGameView` 收口州郡经营说明、操控状态、前线 raw id、“动态方面”标签和 `scenarioId` accessibility 暴露。
- `GeneralCommandPanelView` / `GeneralProfileView` 的未知技能 fallback 改为“未知军略”，将领命令面板头像 accessibility 从“画像”改为“头像”。
- `AgentPanelView` 标题改为“朝堂决策”，legacy order fallback 改为移动/进攻/坚守/补给，映射失败不再展示英文细节。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_visible_diplomacy_court_text_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/UI/DiplomacyPanelView.swift`
- `WWIIHexV0/Core/DiplomacyState.swift`
- `WWIIHexV0/Agents/RulerAgent.swift`
- `WWIIHexV0/SpriteKit/MapDisplayAdapter.swift`
- `WWIIHexV0/UI/RegionInspectorView.swift`
- `WWIIHexV0/UI/UnitInspectorView.swift`
- `WWIIHexV0/Core/MapDisplayLayer.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `WWIIHexV0/UI/AgentPanelView.swift`
- `WWIIHexV0/UI/GeneralCommandPanelView.swift`
- `WWIIHexV0/UI/GeneralProfileView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_visible_diplomacy_court_text_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- 完整本轮轻量检查见最终交付记录。

未执行：

- 未跑 Xcode build、XCTest、模拟器、Probe、Smoke、Stage Regression、Dynamic Theater Regression、Full、性能测试或 app 启动；按当前 `md/test/test.md` 规则，本机默认只做轻量检查，重验证需走 GitHub Actions 或人工授权。

遗留风险：

- `TurnManager` 深层 AI 诊断、`Command.displayName`、Agent 面板真实 `rawJSON`、州郡/军队详情中的部分方面/防区/州郡 raw id 仍可能在调试或边界路径显示。
- 本轮未做运行时 UI、滚动、动态字体或 VoiceOver 实测。

## v3.7-preflight.32 - 玩家可见调试文案收口（一）

完成日期：2026-07-05

性质：完整 v3.7 发布候选前置补洞。在 legacy 旧英文兜底收口之后，继续清理朝堂/战报/将领面板里第一批玩家可见的 raw/debug 文案；不改变命令、AI 决策、规则执行、存档字段或地图数据。

核心更新：

- `SubmissionPresenceSummary.presenceText` 将“hex”改为“地块”，避免外交归附实体盘点露出内部术语。
- `AppContainer` 的本地模拟 AI 来源从 `MockAI` 改为“本地模拟朝堂”，AI 空转摘要、临时总管名称、总管军令提交日志和州郡选择日志改为玩家语义，不再直接显示 `directive.type.rawValue`、`zoneId.rawValue` 或 `selectedRegionId.rawValue`。
- `StrategicStateBootstrapper` 的外交、方面、前线和行军防区 bootstrap 战报中文化。
- `DirectiveType` 新增中文 `displayName`，供玩家可见指令摘要复用。
- `AgentPanelView` 将 `Agent`、`MockAI`、`Order`、`global`、`diagnostic`、raw directive type 和无数据 placeholder JSON 收口为中文玩家语义；仅在真实存在 `rawJSON` 时显示“结构化原文”。
- `AgentDecisionRecord.mappingFailed` 的错误摘要中文化。
- `GeneralCommandPanelView` 与 `GeneralProfileView` 的将领技能 id 改为中文显示，并去掉画像 accessibility 文案里的“占位”。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_visible_debug_text_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/App/AppContainer.swift`
- `WWIIHexV0/Agents/AgentDecisionRecord.swift`
- `WWIIHexV0/Commands/WarDirective.swift`
- `WWIIHexV0/Core/StrategicStateBootstrapper.swift`
- `WWIIHexV0/UI/AgentPanelView.swift`
- `WWIIHexV0/UI/GeneralCommandPanelView.swift`
- `WWIIHexV0/UI/GeneralProfileView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_visible_debug_text_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- 完整本轮轻量检查见最终交付记录。

未执行：

- 未跑 Xcode build、XCTest、模拟器、Probe、Smoke、Stage Regression、Dynamic Theater Regression、Full、性能测试或 app 启动；按当前 `md/test/test.md` 规则，本机默认只做轻量检查，重验证需走 GitHub Actions 或人工授权。

遗留风险：

- 本轮只收口 App/AI 记录、bootstrap 战报、Agent 面板和将领技能显示；外交面板、州郡/军队详情、预备军令目标和 TurnManager 深层诊断中仍可能存在 raw id、内部工程词或英文调试文案。
- 真实 UI 布局、VoiceOver 读法和 AI 面板滚动展示未经过启动验证。

## v3.7-preflight.31 - 玩家可见旧英文兜底收口

完成日期：2026-07-05

性质：完整 v3.7 发布候选前置补洞。在发布候选静态门禁快照之后，收口少量仍可能通过玩家面板或战报露出的 legacy 英文兜底；不改 enum rawValue、存档 schema、规则数值、AI 决策或地图数据。

核心更新：

- `Faction.displayName` 的 legacy 势力从 `Germany` / `Allies` 改为 `德军（旧）` / `盟军（旧）`，避免旧剧本 fallback 或历史记录在 HUD、军队、外交、战报和发布检查面板里显示英文势力名。
- `GamePhase.displayName` 的 legacy 阶段从“AI/玩家行动（旧剧本）”收口为通用中文阶段名，避免玩家面板继续暴露旧剧本标签。
- `VictoryReason.displayName` 的 legacy 胜负原因从德军/盟军/巴斯托涅等旧题材名改为泛化旧剧本中文兜底，保留 enum case 和 rawValue 兼容。
- `HexDirection` 新增中文 `displayName`，`UnitInspectorView` 的方向集合从 E / NE / NW / W / SW / SE 改为东、东北、西北、西、西南、东南。
- `EconomyRules` 的玩家可见经济事件日志中文化，覆盖府库不足、征发入队、府库结算、自动补员、补给完成、部署完成和无安全后方地块等路径。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_visible_legacy_text_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Core/Faction.swift`
- `WWIIHexV0/Core/GamePhase.swift`
- `WWIIHexV0/Core/HexDirection.swift`
- `WWIIHexV0/Core/VictoryState.swift`
- `WWIIHexV0/UI/UnitInspectorView.swift`
- `WWIIHexV0/Rules/EconomyRules.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_visible_legacy_text_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse WWIIHexV0/Core/Faction.swift WWIIHexV0/Core/GamePhase.swift WWIIHexV0/Core/HexDirection.swift WWIIHexV0/Core/VictoryState.swift WWIIHexV0/UI/UnitInspectorView.swift WWIIHexV0/Rules/EconomyRules.swift`：通过，无输出。
- `rg -n "Germany|Allies|巴斯托涅|德军控制|盟军|旧剧本\\）|lacks resources|queued|economy:|received automatic replacements|completed .*supplies|deployed .* at|turn\\(s\\)| is ready, but no safe" WWIIHexV0/Core/Faction.swift WWIIHexV0/Core/GamePhase.swift WWIIHexV0/Core/VictoryState.swift WWIIHexV0/Rules/EconomyRules.swift WWIIHexV0/UI/UnitInspectorView.swift`：无命中。
- `rg -n "return \\\"E\\\"|return \\\"NE\\\"|return \\\"NW\\\"|return \\\"W\\\"|return \\\"SW\\\"|return \\\"SE\\\"|displayCode" WWIIHexV0/UI/UnitInspectorView.swift WWIIHexV0/Core/HexDirection.swift`：无命中。
- 完整本轮轻量检查见最终交付记录。

未执行：

- 未跑 Xcode build、XCTest、模拟器、Probe、Smoke、Stage Regression、Dynamic Theater Regression、Full、性能测试或 app 启动；按当前 `md/test/test.md` 规则，本机默认只做轻量检查，重验证需走 GitHub Actions 或人工授权。

遗留风险：

- 本轮只清理明确玩家可见的旧势力名、旧阶段/胜负原因、方向码和经济事件日志；更深层的内部类型名、legacy 数据文件和开发者诊断仍可能保留英文或二战命名。
- 真实 UI 展示、战报滚动和旧存档 fallback 未经过启动验证。

## v3.7-preflight.30 - 发布候选静态门禁快照

完成日期：2026-07-05

性质：完整 v3.7 发布候选前置补洞。在发布检查门禁拆分和 MapEditor 地点字段化编辑之后，把当前内存 `GameState` 的关键状态做成发布前检查面板里的只读静态快照；不启动 app、不跑 AI 回合、不新增运行时验证结论、不改变规则、命令、存档 schema 或地图数据。

核心更新：

- `ReleaseChecklistView` 版本更新为 `天命开唐 Agent · v3.7-preflight.30`。
- 发布前检查面板新增“静态门禁快照”，只读取当前传入的 `GameState`、本地存档标记和 `GameSaveStatus`。
- 快照显示剧本 ID、回合/阶段、行动势力、胜负状态、地图 hex/州郡/邻接、目标/地点/补给源、军队/前线、方面/防区、外交档案、军令/朝堂/外交审计记录、归附善后记录、战报记录和存档反馈。
- “代码已接入”和“运行时未验证”清单同步说明静态快照已接入，但只代表只读状态展示，不代表 Xcode build、iOS/macOS 启动、AI 多回合或 UI 点击验证通过。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_release_static_gate_snapshot_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/UI/ReleaseChecklistView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_release_static_gate_snapshot_record.md`
- `README.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

轻量检查：

- `swiftc -parse MapEditor/MapEditorDocument.swift MapEditor/MapEditorGameResourceBridge.swift MapEditor/MapEditorExporter.swift MapEditor/MapEditorViewModel.swift MapEditor/MapEditorView.swift MapEditor/MapEditorCanvasScene.swift WWIIHexV0/UI/ReleaseChecklistView.swift`：通过，无输出。
- `jq empty WWIIHexV0/Data/wude_618_scenario.json WWIIHexV0/Data/wude_618_regions.json WWIIHexV0/Data/suitang_generals.json WWIIHexV0/Data/suitang_power_profiles.json WWIIHexV0/Data/suitang_terrain_rules.json WWIIHexV0/Data/suitang_unit_templates.json`：通过，无输出。
- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj`：通过，`OK`。
- `git diff --check`：通过，无输出。
- 改动文件尾随空白扫描：无命中。
- 改动文件冲突标记扫描：无命中。
- 当前文档旧重测试口径扫描：无命中。

未执行：

- 未跑 Xcode build、XCTest、模拟器、Probe、Smoke、Stage Regression、Dynamic Theater Regression、Full、性能测试或 app 启动；按当前 `md/test/test.md` 规则，本机默认只做轻量检查，重验证需走 GitHub Actions 或人工授权。

遗留风险：

- 静态快照只证明面板能从当前 `GameState` 读取并展示字段；真实 sheet 布局、动态字体、点击入口和运行时数据变化未经过启动验证。
- 快照不是 CI artifact 验收器，也不会下载或核对 GitHub Actions 结果包。
- 完整发布候选仍需要授权 Xcode build、iOS/macOS 启动、观察者多回合、UI 点击烟测和默认资源覆盖后的主游戏加载验证。

## v3.7-preflight.29 - MapEditor 地点字段化编辑

完成日期：2026-07-05

性质：完整 v3.7 发布候选前置补洞。在 MapEditor 默认隋唐资源桥之后，把 `wude_618` scenario `keyLocations` 从只保留 metadata 推进为编辑器文档字段，可读取、编辑、删除和导出城池、关隘、粮仓、渡口、港口/海港地点；不新增水战、渡河、港口补给、移动、战斗、胜负规则或运行时验证结论。

核心更新：

- `MapEditorDocument` 新增 `MapEditorKeyLocationDraft`、`keyLocations`、`keyLocationsAreAuthoritative` 和坐标级地点抑制记录，并实现向后兼容 Codable：旧文档缺地点字段时仍可读取，导出时可继续使用 scenario metadata 兜底。
- `MapEditorGameResourceBridge.loadDefaultDocument()` 会把 `ScenarioDefinition.keyLocations` 还原到编辑器文档，默认读取 `wude_618` 后保留长安、洛阳、洛口仓、虎牢、蒲津渡、孟津渡、黎阳津、洛口津等地点字段。
- `MapEditorExporter` 导出时以 `document.keyLocations` 优先，再合并旧文档 metadata 兜底和 city / fortress / supply hex 派生地点，并继续按 id、objectiveId、coord 去重；导出会过滤当前文档不存在的地点坐标，并尊重被删除地点的坐标级抑制记录。
- `MapEditorViewModel` 在右键 inspect 选中 hex 时同步地点字段，提供保存和删除当前 hex 地点记录的最小动作；删除派生地点时会写入坐标 tombstone，避免下次导出从 city / fortress / supply 语义补回。
- `MapEditorViewModel.export()` 对 `wude_618` 文档同样传入默认场景 metadata，避免“导出 JSON 到内存”和覆盖默认资源出现不同的胜负条件、objective 点数或地点兜底结果。
- `MapEditorView` 信息面板新增地点名称、类型、势力和胜负点 ID 字段；`MapEditorCanvasScene` 在地块模式显示最小地点徽标，并把 `pass` 类型按关隘展示。
- `ReleaseChecklistView` 版本更新为 `天命开唐 Agent · v3.7-preflight.29`，并把 MapEditor 地点字段化编辑列为代码已接入。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_mapeditor_key_locations_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `MapEditor/MapEditorDocument.swift`
- `MapEditor/MapEditorGameResourceBridge.swift`
- `MapEditor/MapEditorExporter.swift`
- `MapEditor/MapEditorViewModel.swift`
- `MapEditor/MapEditorView.swift`
- `MapEditor/MapEditorCanvasScene.swift`
- `WWIIHexV0/UI/ReleaseChecklistView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_mapeditor_key_locations_record.md`

轻量检查：

- `swiftc -parse MapEditor/MapEditorDocument.swift MapEditor/MapEditorGameResourceBridge.swift MapEditor/MapEditorExporter.swift MapEditor/MapEditorViewModel.swift MapEditor/MapEditorView.swift MapEditor/MapEditorCanvasScene.swift WWIIHexV0/UI/ReleaseChecklistView.swift`：通过，无输出。
- `jq empty WWIIHexV0/Data/wude_618_scenario.json WWIIHexV0/Data/wude_618_regions.json WWIIHexV0/Data/suitang_generals.json WWIIHexV0/Data/suitang_power_profiles.json WWIIHexV0/Data/suitang_terrain_rules.json WWIIHexV0/Data/suitang_unit_templates.json`：通过，无输出。
- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj`：通过，`OK`。
- `git diff --check`：通过，无输出。
- 改动文件尾随空白扫描：无命中。
- 改动文件冲突标记扫描：无命中。
- 当前文档旧重测试口径扫描：无命中。

未执行：

- 未跑 Xcode build、XCTest、模拟器、Probe、Smoke、Stage Regression、Dynamic Theater Regression、Full、性能测试或 app / MapEditor 启动；按当前 `md/test/test.md` 规则，本机默认只做轻量检查，重验证需走 GitHub Actions 或人工授权。

遗留风险：

- MapEditor 真实右键选中、字段编辑、覆盖保存和重新加载流程未经过 macOS UI 运行验证。
- 地点字段只影响 scenario `keyLocations` 和编辑器画布标记，不实现水战、渡河、港口补给、水师或路径规则。
- 城池、关隘和粮仓仍可由 hex 语义派生；若用户通过地点删除动作抑制某坐标，导出不会再补回该坐标的派生地点，但真实 UI 操作仍未跑。
- 完整发布候选仍需要授权 Xcode build、iOS/macOS 启动、观察者多回合和默认资源覆盖后的主游戏加载验证。

## v3.7-preflight.28 - MapEditor 默认隋唐资源桥

完成日期：2026-07-05

性质：完整 v3.7 发布候选前置补洞。在主游戏默认加载 `wude_618` 已长期完成之后，把 MapEditor 默认读取/覆盖资源从阿登 JSON 对齐到隋唐默认剧本，并为默认覆盖保存增加场景元数据保护；不新增 JSON schema、规则、命令、地图运行时效果或水路地点完整编辑字段。

核心更新：

- `MapEditorGameResourceBridge` 默认资源名从 `ardennes_v0_scenario` / `ardennes_v02_regions` 改为 `wude_618_scenario` / `wude_618_regions`。
- `MapEditorGameResourceBridge.overwriteDefaultGameResources` 在覆盖默认资源前读取现有 `wude_618_scenario.json`，并把场景元数据传给导出器。
- `MapEditorExporter` 新增 `MapEditorExportMetadata`，用于保留既有 factions、maxTurns、initialPhase、playerFaction、aiFaction、victoryConditions、objectives、keyLocations 和 dataNotes。
- 默认导出会合并编辑器生成的 objective/keyLocation，并避免把已有胜负条件、objective 点数、渡口/港口地点记录清空。
- MapEditor 新建文档、模式标题、州郡/方面/军队面板、隋唐单位模板、城池/关隘自动命名和 legacy 势力显示做最小隋唐口径收口。
- `ReleaseChecklistView` 版本更新为 `天命开唐 Agent · v3.7-preflight.28`，并把 MapEditor 默认隋唐资源桥列为代码已接入。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_mapeditor_suitang_bridge_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `MapEditor/MapEditorGameResourceBridge.swift`
- `MapEditor/MapEditorExporter.swift`
- `MapEditor/MapEditorViewModel.swift`
- `MapEditor/MapEditorDocument.swift`
- `MapEditor/MapEditorView.swift`
- `WWIIHexV0/UI/ReleaseChecklistView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_mapeditor_suitang_bridge_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/flow/04_mapeditor_to_game_data.mermaid`
- `md/plan/plan.md`
- `README.md`
- `update_log.md`

验证记录：

- 本轮轻量检查记录见最终回复；未执行 Xcode / XCTest / 模拟器 / app 启动等重测试。

遗留事项：

- MapEditor 默认隋唐资源桥尚未经过真实 macOS MapEditor 启动、读取、覆盖保存和重新加载运行验证。
- 截至 v3.7-preflight.28，该版本只保留既有渡口/港口 `keyLocations` 元数据，不提供水路地点的新增、移动、删除或专用字段编辑 UI；该缺口已由后续 v3.7-preflight.29 补上最小字段化编辑。
- 默认导出保护不等同于完整发布级地图编辑器验收；Xcode build、macOS target 启动、UI 点击和默认资源覆盖后的主游戏加载仍需授权重测。
- 正式地图资产、完整发布候选运行时重测、归附交接后的忠诚/叛乱/安置实际效果和真实模型接入仍待后续。

## v3.7-preflight.27 - AI 使者/交接跳过诊断

完成日期：2026-07-05

性质：完整 v3.7 发布候选前置补洞。在 AI 使者主动外交、AI 归附实体交接和 AI 太守跳过诊断之后，把“有使者步骤但未生成外交命令”和“存在归附目标上下文但未生成交接命令”的静默空结果改为确定性诊断；不新增外交状态、命令、行动次数、规则效果或状态修改。

核心更新：

- `TurnManager.executeDiplomatCommands` 在 `diplomatCommand` 返回 nil 时写入 `diplomatSkipDiagnostics` 结果。
- 新增 `TurnManager.hasDiplomatStep`，统一朝堂使者步骤判断。
- `diplomatSkipDiagnostics` 只在朝堂存在使者步骤时输出原因；原因覆盖缺少国家档案、没有敌对势力、没有可归附目标和未达到停战阈值。
- `TurnManager.executeSubmissionHandoffCommands` 在 `submissionHandoffCommand` 返回 nil 时写入 `submissionHandoffSkipDiagnostics` 结果。
- `submissionHandoffSkipDiagnostics` 只在朝堂存在使者步骤且存在已归附目标上下文时输出原因；原因覆盖归附目标不属于当前接收方、或已没有残余军队/受控可通行 hex。
- 诊断进入 `AgentDecisionRecord.errors`，供 AI 决策面板现有错误/诊断区复盘。
- `ReleaseChecklistView` 版本更新为 `天命开唐 Agent · v3.7-preflight.27`，并把 AI 使者/交接跳过诊断列为代码已接入。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_ai_diplomat_skip_diagnostics_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Turn/TurnManager.swift`
- `WWIIHexV0/UI/ReleaseChecklistView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_ai_diplomat_skip_diagnostics_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `README.md`
- `update_log.md`

验证记录：

- 本轮轻量检查记录见最终回复；未执行 Xcode / XCTest / 模拟器 / app 启动等重测试。

遗留事项：

- AI 使者/交接跳过诊断尚未经过真实 AI/观战多回合运行验证。
- 诊断只说明本回合没有生成外交或归附交接命令的原因，不证明外交启发式、归附关系或残余实体盘点完全正确。
- 诊断不会改变外交关系、归附交接状态或善后压力，也不实现借兵、忠诚、叛乱、贡赋、俘虏、安置或长期外交状态机。
- 正式地图资产、完整发布候选运行时重测和真实模型接入仍待后续。

## v3.7-preflight.26 - AI 太守跳过诊断

完成日期：2026-07-05

性质：完整 v3.7 发布候选前置补洞。在 AI 太守主动经营、善后优先治理、善后未处置优先治理和善后完成状态提示之后，把“有太守步骤或未完成善后上下文但未生成经营命令”的静默空结果改为确定性诊断；不新增命令、行动次数、规则效果或状态修改。

核心更新：

- `TurnManager.executeGovernorCommands` 在 `governorCommand` 返回 nil 时写入 `governorSkipDiagnostics` 结果。
- 新增 `TurnManager.actionableAftermathRecord`，统一筛选最新可行动善后记录：接收方匹配、风险不是低、且善后处置尚未完成。
- `aftermathGovernorRegionIds` 复用该 helper，保证善后优先候选和跳过诊断使用同一口径。
- `governorSkipDiagnostics` 只在朝堂存在太守步骤或有未完成善后上下文时输出原因；原因覆盖无可治理州郡、无适用或可负担政策、善后记录仍有未处置州郡和候选兜底说明。
- 诊断进入 `AgentDecisionRecord.errors`，供 AI 决策面板现有错误/诊断区复盘。
- `ReleaseChecklistView` 版本更新为 `天命开唐 Agent · v3.7-preflight.26`，并把 AI 太守跳过诊断列为代码已接入。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_ai_governor_skip_diagnostics_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Turn/TurnManager.swift`
- `WWIIHexV0/UI/ReleaseChecklistView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_ai_governor_skip_diagnostics_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `README.md`
- `update_log.md`

验证记录：

- 本轮轻量检查记录见最终回复；未执行 Xcode / XCTest / 模拟器 / app 启动等重测试。

遗留事项：

- AI 太守跳过诊断尚未经过真实 AI/观战多回合运行验证。
- 诊断只说明本回合没有生成经营命令的原因，不证明太守候选评分、府库状态或每一种运行时分支都已正确。
- 诊断不会修复善后压力，也不实现忠诚、叛乱、贡赋、俘虏、安置或长期善后状态机。
- 正式地图资产、完整发布候选运行时重测和真实模型接入仍待后续。

## v3.7-preflight.25 - 发布检查门禁拆分

完成日期：2026-07-05

性质：完整 v3.7 发布候选前置补洞。在发布说明、资产边界、善后完成状态提示之后，把发布前检查面板的清单拆成代码已接入、运行时未验证和后续功能三类门禁；不新增规则、命令、运行时验证结论或发布通过声明。

核心更新：

- `ReleaseChecklistView` 版本更新为 `天命开唐 Agent · v3.7-preflight.25`。
- 发布前检查顶部状态新增“代码状态：候选接入”和“运行时门禁：未授权”，避免把代码接入等同于发布通过。
- 原“已接入”清单改为“代码已接入”，并新增发布检查门禁拆分项。
- 原“仍待确认”拆成“运行时未验证”和“后续功能”：前者承载 Xcode build、iOS/macOS 启动、UI 点击、观察者多回合、存档/AI/外交/地图截图等授权重测门禁；后者承载忠诚、叛乱、安置、水战、siege progress、真实模型接入等未来功能。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_release_gate_split_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/UI/ReleaseChecklistView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_release_gate_split_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `README.md`
- `update_log.md`

验证记录：

- 本轮轻量检查记录见最终回复；未执行 Xcode / XCTest / 模拟器 / app 启动等重测试。

遗留事项：

- 发布检查门禁拆分尚未经过真实 iOS/macOS sheet 布局、动态字体、VoiceOver 或点击验证。
- 运行时重测门禁仍未授权，不得据此声称已可发布。
- 正式地图资产、完整发布候选运行时重测、交接后的忠诚/叛乱/安置实际效果和真实模型接入仍待后续。

## v3.7-preflight.24 - 善后完成状态提示

完成日期：2026-07-05

性质：完整 v3.7 发布候选前置补洞。在善后处置审计、进度摘要和 AI 未处置优先治理之后，把最新善后记录的待处置数量和完成状态显式展示给玩家，并让 AI 在本次善后全部处置后退出该记录的特殊优先队列；不清零善后压力，不新增规则效果或 AI 行动次数。

核心更新：

- `DiplomacyState` 新增 `ungovernedAftermathRegionCount(linkedTo:affectedRegionIds:)` 和 `isAftermathGovernanceComplete(linkedTo:affectedRegionIds:)`，用于统计最新善后记录下仍未处置的受影响州郡，并判断本次善后是否所有受影响州郡都有处置记录。
- `DiplomacyPanelView` 的“善后”区新增“待处置”和“状态”，可显示 `0 处` / `已全部处置` 等只读状态。
- `TurnManager.aftermathGovernorRegionIds` 在最新善后记录已全部处置后返回空善后优先列表，让 AI 太守回到普通朝堂关注点和州郡评分候选。
- AI 太守仍每回合最多提交一条既有 `Command.governRegion`，继续经 `CommandValidator -> RuleEngine -> CommandExecutor` 执行。
- `ReleaseChecklistView` 版本更新为 `天命开唐 Agent · v3.7-preflight.24`，把善后待处置数量和完成状态列为已接入。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_submission_aftermath_completion_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Core/DiplomacyState.swift`
- `WWIIHexV0/Turn/TurnManager.swift`
- `WWIIHexV0/UI/DiplomacyPanelView.swift`
- `WWIIHexV0/UI/ReleaseChecklistView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_submission_aftermath_completion_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `README.md`
- `update_log.md`

验证记录：

- 本轮轻量检查记录见最终回复；未执行 Xcode / XCTest / 模拟器 / app 启动等重测试。

遗留事项：

- 善后完成状态提示尚未经过真实 UI 点击、存档读写或 AI/观战多回合运行验证。
- 当前只按最新一条善后记录判断完成状态，不批量处理历史善后压力。
- 完成状态只代表受影响州郡均已有处置记录，不代表善后压力被规则层清除，也不触发忠诚、叛乱、贡赋、俘虏、安置或资源变化。
- 正式地图资产、完整发布候选运行时重测和真实模型接入仍待后续。

## v3.7-preflight.23 - AI 善后未处置优先治理

完成日期：2026-07-05

性质：完整 v3.7 发布候选前置补洞。在善后处置审计和进度摘要之后，把处置记录反馈给 AI 太守候选排序；不新增命令类型，不增加 AI 行动次数，不清零善后压力或引入忠诚/叛乱/安置效果。

核心更新：

- `DiplomacyState` 新增 `governedAftermathRegionIds(linkedTo:affectedRegionIds:)` 和 `ungovernedAftermathRegionIds(linkedTo:affectedRegionIds:)`，用于区分最新善后记录下已处置 / 未处置的受影响州郡。
- `governedAftermathRegionCount` 改为复用已处置州郡 helper，保持 UI 进度摘要与 AI 排序口径一致。
- `TurnManager.aftermathGovernorRegionIds` 在最新善后记录风险不是低、且当前 AI 势力是接收方时，优先返回未产生处置记录的受影响州郡，再返回已处置但仍可治理的州郡。
- AI 太守仍每回合最多提交一条既有 `Command.governRegion`，继续经 `CommandValidator -> RuleEngine -> CommandExecutor` 执行；善后州郡仍优先尝试安民。
- `ReleaseChecklistView` 版本更新为 `天命开唐 Agent · v3.7-preflight.23`，把 AI 太守优先处理未处置善后州郡列为已接入。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_submission_aftermath_ungoverned_priority_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Core/DiplomacyState.swift`
- `WWIIHexV0/Turn/TurnManager.swift`
- `WWIIHexV0/UI/ReleaseChecklistView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_submission_aftermath_ungoverned_priority_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `README.md`
- `update_log.md`

验证记录：

- 本轮轻量检查记录见最终回复；未执行 Xcode / XCTest / 模拟器 / app 启动等重测试。

遗留事项：

- AI 善后未处置优先治理尚未经过真实 AI/观战多回合运行验证。
- 当前只按最新一条善后记录排序，不批量处理历史善后压力。
- 当前只改变候选排序，不清理或降级善后压力，不实现忠诚、叛乱、贡赋、俘虏、安置或长期善后状态机。
- 正式地图资产、完整发布候选运行时重测和真实模型接入仍待后续。

## v3.7-preflight.22 - 善后处置进度摘要

完成日期：2026-07-05

性质：完整 v3.7 发布候选前置补洞。在善后处置审计记录之后，把最新善后记录下的处置记录汇总为玩家可见进度摘要；不清零善后压力，不新增规则效果、命令类型或 AI 行动次数。

核心更新：

- `DiplomacyState` 新增 `submissionAftermathGovernanceRecords(linkedTo:)`，可按善后压力记录 id 筛选关联处置记录。
- `DiplomacyState` 新增 `governedAftermathRegionCount(linkedTo:affectedRegionIds:)`，按受影响州郡去重统计已处置州郡数量。
- `DiplomacyPanelView` 的“善后”区新增“处置进度”，显示本次善后的已处置州郡数量 / 受影响州郡数量，并继续展示最近处置摘要。
- `ReleaseChecklistView` 版本更新为 `天命开唐 Agent · v3.7-preflight.22`，把善后面板处置进度摘要列为已接入。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_submission_aftermath_governance_progress_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Core/DiplomacyState.swift`
- `WWIIHexV0/UI/DiplomacyPanelView.swift`
- `WWIIHexV0/UI/ReleaseChecklistView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_submission_aftermath_governance_progress_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `README.md`
- `update_log.md`

验证记录：

- 本轮轻量检查记录见最终回复；未执行 Xcode / XCTest / 模拟器 / app 启动等重测试。

遗留事项：

- 善后处置进度摘要尚未经过真实 UI 点击、存档读写或 AI/观战多回合运行验证。
- 当前只汇总最新一条善后压力记录，不提供历史善后记录筛选或完整处置时间线。
- 当前进度摘要只做复盘显示，不代表善后压力已被解决，也不触发忠诚、叛乱、贡赋、俘虏或安置效果。
- 正式地图资产、完整发布候选运行时重测和真实模型接入仍待后续。

## v3.7-preflight.21 - 善后处置审计记录

完成日期：2026-07-05

性质：完整 v3.7 发布候选前置补洞。在归附善后压力和 AI 善后太守优先治理之后，把既有州郡经营命令对善后州郡的处理结果沉淀为结构化审计记录；不清零善后压力，不新增忠诚、叛乱、贡赋、俘虏、安置或额外资源效果。

核心更新：

- `DiplomacyState` 新增 `SubmissionAftermathGovernanceRecord` 和 `submissionAftermathGovernanceRecords`，记录执行势力、州郡、经营政策、关联善后压力记录、回合、摘要和边界说明。
- `DiplomacyState` 的 Codable 解码对旧存档缺失 `submissionAftermathGovernanceRecords` 默认空数组，最多保留最近 80 条处置记录。
- `CommandExecutor.executeRegionGovernance` 在既有 `Command.governRegion` 成功执行后，若治理州郡属于最新 `SubmissionAftermathRecord` 且当前势力是接收方，就追加处置记录并写入 `.diplomacy` 战报。
- `DiplomacyPanelView` 的“善后”区展示当前最新善后记录是否已有本次处置记录；没有处置时显示明确空态。
- `ReleaseChecklistView` 版本更新为 `天命开唐 Agent · v3.7-preflight.21`，把善后压力州郡治理后的处置审计列为已接入。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_submission_aftermath_governance_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Core/DiplomacyState.swift`
- `WWIIHexV0/Rules/CommandExecutor.swift`
- `WWIIHexV0/UI/DiplomacyPanelView.swift`
- `WWIIHexV0/UI/ReleaseChecklistView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_submission_aftermath_governance_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `README.md`
- `update_log.md`

验证记录：

- 本轮轻量检查记录见最终回复；未执行 Xcode / XCTest / 模拟器 / app 启动等重测试。

遗留事项：

- 善后处置审计尚未经过真实 UI 点击、存档读写或 AI/观战多回合运行验证。
- 当前只关联最新一条善后压力记录，不批量回填历史善后压力，也不自动清理或降级压力。
- 当前处置记录只审计既有州郡经营命令，不实现忠诚、叛乱、贡赋、俘虏、安置或长期善后状态机。
- 正式地图资产、完整发布候选运行时重测和真实模型接入仍待后续。

## v3.7-preflight.20 - AI 善后太守优先治理

完成日期：2026-07-05

性质：完整 v3.7 发布候选前置补洞。在 v3.7-preflight.19 的归附善后压力只读记录之后，把高/需安抚善后压力接入 AI 太守经营候选排序；不新增忠诚、叛乱、贡赋、俘虏、安置或额外交接效果。

核心更新：

- `TurnManager.governorCommand` 新增善后关注来源：读取最新 `SubmissionAftermathRecord`，仅当当前 AI 势力是接收方且风险等级不是低时生效。
- 善后受影响州郡会排在普通朝堂太守关注点之前，且必须仍由当前势力控制、可通行并存在实际受控 hex。
- 善后州郡优先尝试 `RegionGovernancePolicy.pacifyPopulation`；若经营上限或府库不足，则回到既有屯田/修道/安民择优逻辑。
- AI 太守仍每回合最多提交一条 `Command.governRegion`，继续经 `CommandValidator -> RuleEngine -> CommandExecutor` 执行，结果进入 `AgentDecisionRecord.commandResults`。
- `ReleaseChecklistView` 版本更新为 `天命开唐 Agent · v3.7-preflight.20`，把 AI 善后太守优先治理列为已接入。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_submission_aftermath_governor_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Turn/TurnManager.swift`
- `WWIIHexV0/UI/ReleaseChecklistView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_submission_aftermath_governor_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `README.md`
- `update_log.md`

验证记录：

- 本轮轻量检查记录见最终回复；未执行 Xcode / XCTest / 模拟器 / app 启动等重测试。

遗留事项：

- AI 善后治理尚未经过真实 AI/观战多回合运行验证。
- 当前只读取最新一条善后记录，不批量处理历史善后压力。
- 当前只影响 AI 太守候选排序和既有经营政策选择，不实现忠诚、叛乱、贡赋、俘虏、安置或长期善后状态机。
- 正式地图资产、完整发布候选运行时重测和真实模型接入仍待后续。

## v3.7-preflight.19 - 归附善后压力记录

完成日期：2026-07-05

性质：完整 v3.7 发布候选前置补洞。在归附实体交接命令、交接审计记录和 AI 侧交接之后，补上最小善后压力只读记录，便于玩家和后续验收看到交接后的安抚/整军/治理关注点；不扩展为忠诚、叛乱、贡赋、俘虏或安置系统。

核心更新：

- `DiplomacyState` 新增 `SubmissionAftermathRiskLevel`、`SubmissionAftermathRecord` 和 `submissionAftermathRecords`，记录 turn、归附目标、接收方、关联交接记录、压力等级、转移军队/hex 数、影响州郡和边界说明。
- `DiplomacyState` 的 Codable 解码对旧存档缺失 `submissionAftermathRecords` 默认空数组，最多保留最近 80 条善后记录。
- `CommandExecutor.executeSubmissionHandoff` 在交接成功、刷新派生层并追加 `SubmissionHandoffRecord` 后，追加善后压力记录，并写入一条 `.diplomacy` 日志，`relatedRecordId` 指向该记录 id。
- `DiplomacyPanelView` 新增“善后”区，展示最近一次善后压力、摘要、回合、影响州郡数量和边界说明。
- `ReleaseChecklistView` 版本更新为 `天命开唐 Agent · v3.7-preflight.19`，把归附善后压力只读记录列为已接入。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_submission_aftermath_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Core/DiplomacyState.swift`
- `WWIIHexV0/Rules/CommandExecutor.swift`
- `WWIIHexV0/UI/DiplomacyPanelView.swift`
- `WWIIHexV0/UI/ReleaseChecklistView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_submission_aftermath_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `README.md`
- `update_log.md`

验证记录：

- 本轮轻量检查记录见最终回复；未执行 Xcode / XCTest / 模拟器 / app 启动等重测试。

遗留事项：

- 归附善后压力记录尚未经过真实 UI 点击、存档读写或 AI/观战多回合运行验证。
- 当前记录只做只读提示，不触发忠诚、叛乱、贡赋、俘虏、安置、治理效果或资源变化。
- 正式地图资产、完整发布候选运行时重测和更完整归附善后系统仍待后续。

## v3.7-preflight.18 - AI 归附实体交接

完成日期：2026-07-05

性质：完整 v3.7 发布候选前置补洞。把 v3.7-preflight.16/.17 的归附实体交接能力接入 AI 自动回合：AI 接收方在使者外交后、结束回合前，可通过统一命令管线接管已归附目标的残余实体。

核心更新：

- `TurnManager.executeDirectiveEnvelope` 在 AI 太守经营、AI 使者外交之后，新增 AI 归附交接步骤，再执行 `.endTurn`。
- 新增 `SubmissionHandoffCommandExecution`，复用 `CommandResultSummary.systemCommand` 记录 AI 交接命令结果。
- AI 每回合最多生成一条 `Command.resolveSubmissionHandoff(submitted:recipient:)`；候选目标必须已归附当前 AI 势力，且仍有未毁灭军队或可通行受控 hex。
- AI 交接仍调用 `commandHandler.execute(command, in:)`，由 `CommandValidator -> RuleEngine -> CommandExecutor` 校验和执行；被拒绝时写入 AI diagnostics。
- 交接成功后继续复用 v3.7-preflight.17 的 `SubmissionHandoffRecord` 和外交战报 `relatedRecordId`。
- `ReleaseChecklistView` 版本更新为 `天命开唐 Agent · v3.7-preflight.18`，把 AI 归附实体交接列为已接入。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_submission_ai_handoff_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Turn/TurnManager.swift`
- `WWIIHexV0/UI/ReleaseChecklistView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_submission_ai_handoff_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `README.md`
- `update_log.md`

验证记录：

- 本轮轻量检查记录见最终回复；未执行 Xcode / XCTest / 模拟器 / app 启动等重测试。

遗留事项：

- AI 归附实体交接尚未经过真实 AI/观战多回合运行验证。
- 当前 AI 每回合最多交接一个已归附目标，不做批量安置、忠诚、叛乱、贡赋、俘虏或治理善后。
- 正式地图资产、完整发布候选运行时重测和更完整归附善后事件仍待后续。

## v3.7-preflight.17 - 归附交接审计记录

完成日期：2026-07-05

性质：完整 v3.7 发布候选前置补洞。把 v3.7-preflight.16 的实际归附实体交接结果沉淀为结构化记录，便于存档、战报关联和外交面板复盘；不扩展为忠诚、叛乱、贡赋、俘虏或安置系统。

核心更新：

- `DiplomacyState` 新增 `SubmissionHandoffRecord` 和 `submissionHandoffRecords`，记录 turn、归附目标、接收方、转移军队数、转移 hex 数、影响州郡和边界说明。
- `DiplomacyState` 的 Codable 解码对旧存档缺失 `submissionHandoffRecords` 默认空数组，最多保留最近 80 条交接记录。
- `CommandExecutor.executeSubmissionHandoff` 在完成军队/hex 交接、同步派生层后追加 `SubmissionHandoffRecord`，并把外交战报的 `relatedRecordId` 指向该记录 id。
- `DiplomacyPanelView` 新增“交接”区，展示最近一次归附交接摘要、影响州郡数量、回合和边界说明。
- `ReleaseChecklistView` 版本更新为 `天命开唐 Agent · v3.7-preflight.17`，把归附交接结构化记录列为已接入。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_submission_handoff_audit_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Core/DiplomacyState.swift`
- `WWIIHexV0/Rules/CommandExecutor.swift`
- `WWIIHexV0/UI/DiplomacyPanelView.swift`
- `WWIIHexV0/UI/ReleaseChecklistView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_submission_handoff_audit_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `README.md`
- `update_log.md`

验证记录：

- 本轮轻量检查记录见最终回复；未执行 Xcode / XCTest / 模拟器 / app 启动等重测试。

遗留事项：

- 归附交接审计记录尚未经过真实 UI 点击、存档读写或 AI/观战多回合运行验证。
- 当前不删除外交 country profile、关系或历史事件记录，不处理忠诚、叛乱、贡赋、俘虏、安置或交接后治理。
- 正式地图资产、完整发布候选运行时重测和更完整归附善后事件仍待后续。

## v3.7-preflight.16 - 归附实体交接命令

完成日期：2026-07-05

性质：完整 v3.7 发布候选前置补洞。把 v3.7-preflight.15 的归附实体盘点推进为最小可执行交接：归附接收方可通过统一命令管线接管已归附目标的未毁灭军队和可通行受控 hex。

核心更新：

- `Command` 新增 `resolveSubmissionHandoff(submitted:recipient:)`，作为归附实体交接的结构化命令。
- `CommandValidator` 新增交接校验：必须处于允许命令阶段、`recipient` 必须是当前行动势力、双方必须有 country profile、当前外交状态必须证明 `submitted` 归附于 `recipient`，且目标仍有未毁灭军队或可通行受控 hex。
- `DiplomacyState` 的归附目标 helper 改为按每个 target 的最新外交事件判断当前状态；只有完全没有外交事件记录的旧存档才 fallback 到 `.submitted` 关系状态。
- `CommandExecutor` 执行交接时，把归附目标未毁灭军队改属接收方并标记本回合已行动，把归附目标可通行受控 hex 改属接收方，然后刷新 region / theater / front / deploy 派生层。
- `AppContainer` 和 `DiplomacyPanelView` 新增玩家侧“接管”入口；UI 只提交 `Command.resolveSubmissionHandoff`，不直接修改 `GameState`。
- `ReleaseChecklistView` 版本更新为 `天命开唐 Agent · v3.7-preflight.16`，把归附实体交接命令列为已接入。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_submission_handoff_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Commands/Command.swift`
- `WWIIHexV0/Commands/CommandValidation.swift`
- `WWIIHexV0/Core/DiplomacyState.swift`
- `WWIIHexV0/Rules/CommandValidator.swift`
- `WWIIHexV0/Rules/CommandExecutor.swift`
- `WWIIHexV0/Commands/WarCommandExecutor.swift`
- `WWIIHexV0/App/AppContainer.swift`
- `WWIIHexV0/UI/DiplomacyPanelView.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `WWIIHexV0/UI/ReleaseChecklistView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_submission_handoff_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `README.md`
- `update_log.md`

验证记录：

- 本轮轻量检查记录见最终回复；未执行 Xcode / XCTest / 模拟器 / app 启动等重测试。

遗留事项：

- 归附实体交接尚未经过真实 UI 点击、存档读写或 AI/观战多回合运行验证。
- 当前不删除外交 country profile、关系或历史事件记录，不处理忠诚、叛乱、贡赋、俘虏、安置或交接后治理。
- 正式地图资产、完整发布候选运行时重测和更完整归附善后事件仍待后续。

## v3.7-preflight.15 - 归附实体盘点与误判收口

完成日期：2026-07-05

性质：完整 v3.7 发布候选前置补洞。补上归附目标的只读实体盘点，并收口归附目标判定：新存档有 `DiplomacyEventRecord` 时只按事件 `target` 判断归附对象，旧存档缺事件记录时才 fallback 到对称的 `.submitted` 关系状态。

核心更新：

- `DiplomacyState` 新增 `isSubmittedTarget(_:)` 和 `submittedTargetFactions()`，集中提供归附目标判定。
- `CommandExecutor.turnOrder(in:)` 复用 `DiplomacyState.isSubmittedTarget(_:)`，避免规则层复制事件/关系 fallback 逻辑。
- 新增 `SubmissionPresenceSummary`，由 `AppContainer.submissionPresenceSummaries` 只读统计归附目标的存活军队数和受控可通行 hex 数。
- `DiplomacyPanelView` 新增“归附实体”区，显示归附目标残余实体，并说明该势力是否仍会进入通用回合轮转。
- `ReleaseChecklistView` 版本更新为 `天命开唐 Agent · v3.7-preflight.15`，把归附实体盘点列为已接入。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_submission_presence_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Core/DiplomacyState.swift`
- `WWIIHexV0/Rules/CommandExecutor.swift`
- `WWIIHexV0/App/AppContainer.swift`
- `WWIIHexV0/UI/DiplomacyPanelView.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `WWIIHexV0/UI/ReleaseChecklistView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_submission_presence_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `README.md`
- `update_log.md`

验证记录：

- 本轮轻量检查记录见最终回复；未执行 Xcode / XCTest / 模拟器 / app 启动等重测试。

遗留事项：

- 归附实体盘点尚未经过真实 UI 点击或多回合运行验证。
- 当前仍不自动转移 hex、region、军队、动态方面、前线或部署归属。
- 有实体存在时的实际地图/军队归属交接规则、更完整归附后续事件、正式地图资产和完整发布候选重测仍待后续。

## v3.7-preflight.14 - 归附空势力轮转收口

完成日期：2026-07-05

性质：完整 v3.7 发布候选前置补洞。补上归附关系后的最小生命周期收口：当某个势力已作为 `submitted` 目标记录，且当前没有存活军队、没有任何可通行受控 hex 时，不再进入通用隋唐回合轮转。该层只影响 turn order，不转移地图、州郡或军队归属。

核心更新：

- `CommandExecutor.turnOrder(in:)` 在汇总 diplomacy countries、军队和 hex controller 后，过滤“已归附且无实体存在”的势力。
- 新增保守判定 helper：优先通过 `DiplomacyEventRecord.target == faction && status == .submitted` 判断归附目标；旧存档缺事件记录时 fallback 到关系状态中的 `.submitted`。
- “实体存在”定义为至少一支未毁灭军队，或至少一个由该势力控制的可通行 hex；只要仍有实体存在，就不会跳过该势力。
- `ReleaseChecklistView` 版本更新为 `天命开唐 Agent · v3.7-preflight.14`，把“已归附且无实体存在的势力会退出通用回合轮转”列为已接入。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_submission_turn_order_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Rules/CommandExecutor.swift`
- `WWIIHexV0/UI/ReleaseChecklistView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_submission_turn_order_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `README.md`
- `update_log.md`

验证记录：

- 本轮轻量检查记录见最终回复；未执行 Xcode / XCTest / 模拟器 / app 启动等重测试。

遗留事项：

- 归附空势力跳过轮转尚未经过真实 AI/观战多回合运行验证。
- 当前仍不自动转移 hex、region、军队、动态方面、前线或部署归属。
- 有实体存在时的地图/军队归属交接规则、更完整归附后续事件、正式地图资产和完整发布候选重测仍待后续。

## v3.7-preflight.13 - 归附事件记录链

完成日期：2026-07-05

性质：完整 v3.7 发布候选前置补洞。补上外交关系变化的最小结构化事件记录，让玩家侧和 AI 侧的停战/归附命令既更新关系，也留下可回放、可关联战报的记录链；仍不自动转移 hex、region、军队、动态方面、前线或部署归属。

核心更新：

- `DiplomacyState` 新增 `DiplomacyEventRecord`，记录 turn、issuer、target、status、双方 country ids、summary 和边界说明。
- `DiplomacyState` 新增 `diplomacyEventRecords`，Codable 解码对旧存档缺字段默认空数组，最多保留最近 80 条外交事件。
- `CommandExecutor.executeDiplomacyUpdate` 在更新关系后追加外交事件记录，并把 `.diplomacy` 战报的 `relatedRecordId` 指向记录 id。
- `DiplomacyPanelView` 新增“事件”区，展示最近外交事件、回合和边界说明，明确归附当前只是关系事件，不做地图/军队交接。
- `ReleaseChecklistView` 版本更新为 `天命开唐 Agent · v3.7-preflight.13`，把归附/停战事件记录列为已接入，待确认项收敛为地图/军队归属交接规则和更完整归附后续事件。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_submission_event_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Core/DiplomacyState.swift`
- `WWIIHexV0/Rules/CommandExecutor.swift`
- `WWIIHexV0/UI/DiplomacyPanelView.swift`
- `WWIIHexV0/UI/ReleaseChecklistView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_submission_event_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `README.md`
- `update_log.md`

验证记录：

- 本轮轻量检查记录见最终回复；未执行 Xcode / XCTest / 模拟器 / app 启动等重测试。

遗留事项：

- 归附事件记录尚未经过真实 UI 点击、AI 多回合或存档读写运行验证。
- 当前归附仍只更新外交关系和事件记录，不自动转移 hex、region、军队、动态方面、前线或部署归属。
- 地图/军队归属交接规则、更完整归附后续事件、正式地图资产和完整发布候选重测仍待后续。

## v3.7-preflight.12 - AI 使者主动外交

完成日期：2026-07-05

性质：完整 v3.7 发布候选前置补洞。补上 AI/观战自动回合的最小使者外交路径，让朝堂使者在保守条件下能转化为最多一条 `Command.updateDiplomacy`，并继续经 `CommandValidator -> RuleEngine -> CommandExecutor -> DiplomacyState` 执行。

核心更新：

- `TurnManager.executeDirectiveEnvelope` 在 AI 太守经营后、执行 `.endTurn` 前调用 AI 使者外交选择器。
- AI 使者每个 AI/观战自动回合最多生成一条 `Command.updateDiplomacy`；敌方已经无存活军队且无可通行受控州郡时标记 `submitted`，己方战力、州郡或战意明显不足时向压力最高的敌对势力提出 `truce`。
- 外交目标会过滤缺失 country profile 的 faction，避免生成必然被 validator 拒绝的关系命令。
- AI 使者执行仍调用 `commandHandler.execute(command, in:)`，命令结果进入 `AgentDecisionRecord.commandResults`，被拒绝时写入 AI diagnostics。
- `RulerAgent` 的使者步骤说明更新为可在保守条件下提交停战或归附关系命令。
- `ReleaseChecklistView` 版本更新为 `天命开唐 Agent · v3.7-preflight.12`，把 AI 使者主动外交列为已接入，待确认项收敛为完整归附事件链和地图/军队归属交接规则。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_ai_diplomat_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Turn/TurnManager.swift`
- `WWIIHexV0/Agents/RulerAgent.swift`
- `WWIIHexV0/UI/ReleaseChecklistView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_ai_diplomat_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `README.md`
- `update_log.md`

验证记录：

- `swiftc -parse WWIIHexV0/Agents/AgentDecisionRecord.swift WWIIHexV0/Agents/RulerAgent.swift WWIIHexV0/Turn/TurnManager.swift WWIIHexV0/Commands/Command.swift WWIIHexV0/Commands/CommandValidation.swift WWIIHexV0/Core/DiplomacyState.swift WWIIHexV0/Core/EconomyState.swift WWIIHexV0/Core/Region.swift WWIIHexV0/Rules/CommandValidator.swift WWIIHexV0/Rules/CommandExecutor.swift WWIIHexV0/Commands/WarCommandExecutor.swift WWIIHexV0/UI/ReleaseChecklistView.swift WWIIHexV0/App/GameSaveStore.swift`：通过，无输出。
- `jq empty WWIIHexV0/Data/wude_618_scenario.json WWIIHexV0/Data/wude_618_regions.json WWIIHexV0/Data/suitang_unit_templates.json WWIIHexV0/Data/suitang_generals.json WWIIHexV0/Data/suitang_power_profiles.json WWIIHexV0/Data/suitang_terrain_rules.json`：通过，无输出。
- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj`：通过，输出 `WWIIHexV0.xcodeproj/project.pbxproj: OK`。
- `git diff --check`：通过，无输出。
- 文档/源码尾随空白扫描、真实冲突标记扫描、旧默认测试口径扫描和当前状态版本残留扫描：均无命中。
- 未执行 Xcode / XCTest / 模拟器 / app 启动等重测试。

遗留事项：

- AI 使者主动外交尚未经过真实 AI/观战多回合运行验证。
- 当前外交策略是 deterministic 保守启发式，不做同盟、借兵、贡赋、长期信任或多轮谈判。
- `submitted` 当前仍只更新外交关系，不自动转移 hex、region、军队或势力归属。
- 完整归附事件链、地图/军队归属交接规则、正式地图资产和完整发布候选重测仍待后续。

## v3.7-preflight.11 - AI 太守主动经营

完成日期：2026-07-05

性质：完整 v3.7 发布候选前置补洞。补上 AI/观战自动回合的最小太守经营路径，让朝堂太守关注点能在 AI 回合转化为最多一条 `Command.governRegion`，并继续经 `CommandValidator -> RuleEngine -> CommandExecutor` 执行。

核心更新：

- `TurnManager.executeDirectiveEnvelope` 在写入 `RulerDecisionRecord` / `CourtDecisionRecord` 后、执行 `.endTurn` 前调用 AI 太守经营选择器。
- AI 太守每个 AI/观战自动回合最多生成一条 `Command.governRegion`；优先考虑 `CourtDecisionRecord` 中太守步骤关注的州郡，再按粮仓低、道路低、治安阻力和己方驻军评分选择其他己控州郡。
- 政策选择复用 v3.7-preflight.10 的 `RegionGovernancePolicy`：粮仓低优先屯田，道路低优先修道，其他优先安民；生成命令前会检查经营上限和府库资源。
- AI 太守执行仍调用 `commandHandler.execute(command, in:)`，命令结果进入 `AgentDecisionRecord.commandResults`，被拒绝时写入 AI diagnostics。
- `CommandResultSummary` 新增 `systemCommand(...)`，用于记录非 directive、非 legacy order 的系统/Agent 命令结果。
- `ReleaseChecklistView` 版本更新为 `天命开唐 Agent · v3.7-preflight.11`，把 AI 太守主动经营列为已接入，待确认项收敛为 AI 使者主动外交、完整归附链和运行时重测。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_ai_governor_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Turn/TurnManager.swift`
- `WWIIHexV0/Agents/AgentDecisionRecord.swift`
- `WWIIHexV0/UI/ReleaseChecklistView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_ai_governor_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `README.md`
- `update_log.md`

验证记录：

- `swiftc -parse WWIIHexV0/Agents/AgentDecisionRecord.swift WWIIHexV0/Turn/TurnManager.swift WWIIHexV0/Commands/Command.swift WWIIHexV0/Commands/CommandValidation.swift WWIIHexV0/Core/EconomyState.swift WWIIHexV0/Core/Region.swift WWIIHexV0/Rules/CommandValidator.swift WWIIHexV0/Rules/CommandExecutor.swift WWIIHexV0/Commands/WarCommandExecutor.swift WWIIHexV0/UI/ReleaseChecklistView.swift WWIIHexV0/App/GameSaveStore.swift`：通过，无输出。
- `jq empty WWIIHexV0/Data/wude_618_scenario.json WWIIHexV0/Data/wude_618_regions.json WWIIHexV0/Data/suitang_unit_templates.json WWIIHexV0/Data/suitang_generals.json WWIIHexV0/Data/suitang_power_profiles.json WWIIHexV0/Data/suitang_terrain_rules.json`：通过，无输出。
- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj`：通过，输出 `WWIIHexV0.xcodeproj/project.pbxproj: OK`。
- `git diff --check`：通过，无输出。
- 文档/源码尾随空白扫描、真实冲突标记扫描、旧默认测试口径扫描和当前状态版本残留扫描：均无命中。
- 未执行 Xcode / XCTest / 模拟器 / app 启动等重测试。

遗留事项：

- AI 太守主动经营尚未经过真实 AI/观战多回合运行验证。
- 当前每个 AI 回合最多一条州郡经营命令，不做多州郡排程、长期内政规划或叛乱事件链。
- AI 使者主动外交、完整归附事件链、正式地图资产和完整发布候选重测仍待后续。

## v3.7-preflight.10 - 州郡经营与太守命令闭环

完成日期：2026-07-05

性质：完整 v3.7 发布候选前置补洞。补上最小州郡经营路径，让玩家侧“修道 / 屯田 / 安民”动作经 `Command -> CommandValidator -> RuleEngine -> CommandExecutor` 更新州郡战略字段和府库，不绕过规则系统直接改 `GameState`。

核心更新：

- `Command` 新增 `governRegion(regionId:policy:)`，用于表达州郡经营；该命令无 acting division，不参与移动/攻击/计划锁定。
- 新增 `RegionGovernancePolicy`：`repairRoads` 修道提升 `RegionNode.infrastructure`，`organizeTuntian` 屯田提升 `RegionNode.supplyValue`，`pacifyPopulation` 安民更新 `OccupationState`。
- `CommandValidator` 新增州郡经营校验：phase 必须允许命令、州郡必须存在且可通行、controller 必须是当前行动势力、州郡内必须有实际己控 hex、府库资源必须足够，且对应经营项未达上限。
- `CommandExecutor` 新增州郡经营执行：扣除当前行动势力府库资源，更新 region 战略字段，并写入太守令日志。
- `AppContainer` 新增选中州郡经营能力判断和提交方法；`RegionInspectorView` 新增“太守”动作区，通过 `submit(Command.governRegion...)` 调用规则系统。
- `WarCommandExecutor` 把州郡经营命令归为无单位命令，避免战争 directive 辅助函数漏 case。
- `ReleaseChecklistView` 版本更新为 `天命开唐 Agent · v3.7-preflight.10`，把最小州郡经营命令列为已接入。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_region_governance_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Commands/Command.swift`
- `WWIIHexV0/Commands/CommandValidation.swift`
- `WWIIHexV0/Rules/CommandValidator.swift`
- `WWIIHexV0/Rules/CommandExecutor.swift`
- `WWIIHexV0/Commands/WarCommandExecutor.swift`
- `WWIIHexV0/App/AppContainer.swift`
- `WWIIHexV0/UI/RegionInspectorView.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `WWIIHexV0/UI/ReleaseChecklistView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_region_governance_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `README.md`
- `update_log.md`

验证记录：

- `swiftc -parse WWIIHexV0/Commands/Command.swift WWIIHexV0/Commands/CommandValidation.swift WWIIHexV0/Core/EconomyState.swift WWIIHexV0/Core/Region.swift WWIIHexV0/Rules/CommandValidator.swift WWIIHexV0/Rules/CommandExecutor.swift WWIIHexV0/Commands/WarCommandExecutor.swift WWIIHexV0/App/AppContainer.swift WWIIHexV0/UI/RegionInspectorView.swift WWIIHexV0/UI/RootGameView.swift WWIIHexV0/UI/ReleaseChecklistView.swift`：通过，无输出。
- `jq empty WWIIHexV0/Data/wude_618_scenario.json WWIIHexV0/Data/wude_618_regions.json WWIIHexV0/Data/suitang_unit_templates.json WWIIHexV0/Data/suitang_generals.json WWIIHexV0/Data/suitang_power_profiles.json WWIIHexV0/Data/suitang_terrain_rules.json`：通过，无输出。
- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj`：通过，输出 `WWIIHexV0.xcodeproj/project.pbxproj: OK`。
- `git diff --check`：通过，无输出。
- 文档/源码尾随空白扫描、真实冲突标记扫描和旧默认测试口径扫描：均无命中。
- 当前状态版本残留扫描：README、flow、plan 和发布检查面板无 v3.7-preflight.9 当前状态残留；`update_log.md` 保留 v3.7-preflight.9 历史记录为预期命中。
- 未执行 Xcode / XCTest / 模拟器 / app 启动等重测试。

遗留事项：

- 州郡经营按钮尚未经过真实 iOS/macOS 点击验证。
- AI 太守还不会主动生成州郡经营命令；朝堂太守仍主要是审计记录。
- 安民当前只更新 `OccupationState`，尚未接入完整民心、天命或叛乱事件链。
- AI 使者主动外交、完整归附事件链、正式地图资产和完整发布候选重测仍待后续。

## v3.7-preflight.9 - 外交议和与纳降命令闭环

完成日期：2026-07-05

性质：完整 v3.7 发布候选前置补洞。补上最小外交/归附事件执行路径，让玩家侧“议和 / 纳降”动作经 `Command -> CommandValidator -> RuleEngine -> CommandExecutor -> DiplomacyState` 更新关系，不绕过规则系统直接改 `GameState`。

核心更新：

- `Command` 新增 `updateDiplomacy(issuer:target:status:)`，用于表达外交关系更新；该命令无 acting division，不参与移动/攻击/计划锁定。
- `CommandValidator` 新增外交校验：phase 必须允许命令、issuer 必须为当前行动势力、target 不能等于 issuer，且双方必须存在 country profile。
- `CommandExecutor` 新增外交执行：更新 `DiplomacyState` 关系并写入 `.diplomacy` 战报事件。
- `DiplomacyState` 新增 `updateRelation` helper，对 issuer / target 下所有国家 pair 更新或补建关系，设置 tension 并更新 `lastUpdatedTurn`。
- `AppContainer` 新增玩家外交目标和“议和 / 纳降”提交方法；`DiplomacyPanelView` 新增“使者”动作区，通过 `submit(Command.updateDiplomacy...)` 调用规则系统。
- `WarCommandExecutor` 把外交命令归为无单位命令，避免战争 directive 辅助函数漏 case。
- `ReleaseChecklistView` 版本更新为 `天命开唐 Agent · v3.7-preflight.9`，把最小外交议和/纳降命令列为已接入。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_diplomacy_command_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Commands/Command.swift`
- `WWIIHexV0/Commands/CommandValidation.swift`
- `WWIIHexV0/Core/DiplomacyState.swift`
- `WWIIHexV0/Rules/CommandValidator.swift`
- `WWIIHexV0/Rules/CommandExecutor.swift`
- `WWIIHexV0/Commands/WarCommandExecutor.swift`
- `WWIIHexV0/App/AppContainer.swift`
- `WWIIHexV0/UI/DiplomacyPanelView.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `WWIIHexV0/UI/ReleaseChecklistView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_diplomacy_command_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `README.md`
- `update_log.md`

验证记录：

- `swiftc -parse WWIIHexV0/Commands/Command.swift WWIIHexV0/Commands/CommandValidation.swift WWIIHexV0/Core/DiplomacyState.swift WWIIHexV0/Rules/CommandValidator.swift WWIIHexV0/Rules/CommandExecutor.swift WWIIHexV0/Commands/WarCommandExecutor.swift WWIIHexV0/App/AppContainer.swift WWIIHexV0/UI/DiplomacyPanelView.swift WWIIHexV0/UI/RootGameView.swift WWIIHexV0/UI/ReleaseChecklistView.swift`：通过，无输出。
- `jq empty WWIIHexV0/Data/wude_618_scenario.json WWIIHexV0/Data/wude_618_regions.json WWIIHexV0/Data/suitang_unit_templates.json WWIIHexV0/Data/suitang_generals.json WWIIHexV0/Data/suitang_power_profiles.json WWIIHexV0/Data/suitang_terrain_rules.json`：通过，无输出。
- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj`：通过，输出 `WWIIHexV0.xcodeproj/project.pbxproj: OK`。
- `git diff --check`：通过，无输出。
- 文档/源码尾随空白扫描、真实冲突标记扫描、旧默认测试口径扫描和当前状态版本残留扫描：均无命中。
- 未执行 Xcode / XCTest / 模拟器 / app 启动等重测试。

遗留事项：

- 外交按钮尚未经过真实 iOS/macOS 点击验证。
- 纳降当前只更新外交关系，不自动转移 hex、region、军队或势力归属，避免绕过战术权威。
- AI 使者还不会主动生成外交命令；朝堂使者仍主要是审计记录。
- 州郡经营命令、太守执行器、完整归附事件链和完整发布候选重测仍待后续。

## v3.7-preflight.8 - 发布说明与资产边界收口

完成日期：2026-07-05

性质：完整 v3.7 发布候选前置补洞。补上发布说明、地图资产边界和验证口径的玩家可见收口，不引入外部素材、asset catalog、规则变更或发布候选重测结论。

核心更新：

- `ReleaseChecklistView` 版本更新为 `天命开唐 Agent · v3.7-preflight.8`。
- 发布前检查面板新增“发布说明”，说明首发定位、当前入口和本机轻量检查 / 运行时重测口径。
- 发布前检查面板新增“资产边界”，明确城池、关隘、粮仓、渡口、港口、AI 箭头和前线墨线当前都是代码绘制或派生显示。
- 已接入清单增加发布说明、资产边界和验证口径收口；待确认项收敛为地图叠加层运行时截图检查和正式资产替换决策。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_release_notes_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/UI/ReleaseChecklistView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_release_notes_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `README.md`
- `update_log.md`

验证记录：

- `swiftc -parse WWIIHexV0/UI/ReleaseChecklistView.swift WWIIHexV0/UI/GameSettingsView.swift WWIIHexV0/UI/HUDView.swift WWIIHexV0/UI/RootGameView.swift WWIIHexV0/UI/NewGameButton.swift`：通过，无输出。
- `jq empty WWIIHexV0/Data/wude_618_scenario.json WWIIHexV0/Data/wude_618_regions.json WWIIHexV0/Data/suitang_unit_templates.json WWIIHexV0/Data/suitang_generals.json WWIIHexV0/Data/suitang_power_profiles.json WWIIHexV0/Data/suitang_terrain_rules.json`：通过，无输出。
- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj`：通过，输出 `WWIIHexV0.xcodeproj/project.pbxproj: OK`。
- `git diff --check`：通过，无输出。
- 文档/源码尾随空白扫描、真实冲突标记扫描和旧默认测试口径扫描：均无命中。
- 未执行 Xcode / XCTest / 模拟器 / app 启动等重测试。

遗留事项：

- 发布说明和资产边界尚未经过真实 iOS/macOS 面板布局验证。
- 地图叠加层仍需授权运行时截图检查；当前正式资产替换方案尚未决策。
- 外交归附、州郡经营命令、太守/使者执行器和完整发布候选重测仍待后续。

## v3.7-preflight.7 - 存档错误反馈

完成日期：2026-07-05

性质：完整 v3.7 发布候选前置补洞。补上本地存档读取、保存、删除的最小用户可见反馈，不改变存档 JSON schema、规则系统或发布候选重测状态。

核心更新：

- `GameSaveStore.swift` 新增 `GameSaveStatus`，用于表达本地存档的成功、提示和失败状态。
- `AppContainer` 新增 `saveStatus`，在启动读取、继续存档、新局自动保存、命令后自动保存、AI 后自动保存和重置删除存档时更新状态。
- 读取失败会保留“已开启默认剧本”的明确反馈；保存失败和删除失败会保留错误原因，并进入 HUD 错误提示。
- `HUDView` 在存档失败时显示 `SaveStatusBanner`，避免失败只藏在战报日志里。
- `GameSettingsView` 和 `ReleaseChecklistView` 显示当前存档反馈；发布前检查面板版本更新为 `天命开唐 Agent · v3.7-preflight.7`。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_save_feedback_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/App/GameSaveStore.swift`
- `WWIIHexV0/App/AppContainer.swift`
- `WWIIHexV0/UI/HUDView.swift`
- `WWIIHexV0/UI/GameSettingsView.swift`
- `WWIIHexV0/UI/ReleaseChecklistView.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_save_feedback_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `README.md`
- `update_log.md`

验证记录：

- `swiftc -parse WWIIHexV0/App/GameSaveStore.swift WWIIHexV0/App/AppContainer.swift WWIIHexV0/UI/HUDView.swift WWIIHexV0/UI/GameSettingsView.swift WWIIHexV0/UI/ReleaseChecklistView.swift WWIIHexV0/UI/RootGameView.swift WWIIHexV0/UI/NewGameButton.swift`：通过，无输出。
- `jq empty WWIIHexV0/Data/wude_618_scenario.json WWIIHexV0/Data/wude_618_regions.json WWIIHexV0/Data/suitang_unit_templates.json WWIIHexV0/Data/suitang_generals.json WWIIHexV0/Data/suitang_power_profiles.json WWIIHexV0/Data/suitang_terrain_rules.json`：通过，无输出。
- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj`：通过，输出 `WWIIHexV0.xcodeproj/project.pbxproj: OK`。
- `git diff --check`：通过，无输出。
- 文档/源码尾随空白扫描、真实冲突标记扫描、旧默认测试口径扫描和存档反馈过时待办扫描：均无命中。
- 未执行 Xcode / XCTest / 模拟器 / app 启动等重测试。

遗留事项：

- 存档反馈尚未经过真实 iOS/macOS sheet、HUD 和菜单交互验证。
- 当前只做单槽位 `GameState` 存档反馈，不新增多槽位、导入导出、迁移器、确认弹窗或自动重试。
- 外交归附、州郡经营命令、太守/使者执行器、正式地图资产和完整发布候选重测仍待后续。

## v3.7-preflight.6 - 前线墨线

完成日期：2026-07-05

性质：完整 v3.7 发布候选前置补洞。补上普通地图层的最小前线墨线，不代表正式地图资产、真实战线美术或完整发布候选已完成。

核心更新：

- `BoardScene` 在普通地图层叠加只读前线墨线，来源为现有 `FrontLineState` 经 `MapLayerOverlayCalculator.frontLineChains()` 生成的链。
- `.frontLine` 专用深色图层保持原有显示；新墨线只在非 `.frontLine` 图层绘制，便于玩家在地形/州郡/方面/部署图层直接看见接触线。
- 前线墨线按 `FrontLineType`、`FrontLineOperationalState` 和 `pressure` 调整宽度与颜色；包围/崩溃态追加朱色警示虚线。
- 单点接触会绘制墨色接触标记，避免短前线完全不可见。
- `ReleaseChecklistView` 更新为 `v3.7-preflight.6`，把渡口/港口、AI 计划箭头和前线墨线列为已接入最小地图显示，待办改为正式资产和运行时截图检查。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_front_ink_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/SpriteKit/BoardScene.swift`
- `WWIIHexV0/UI/ReleaseChecklistView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_front_ink_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `README.md`
- `update_log.md`

验证记录：

- `swiftc -parse WWIIHexV0/SpriteKit/BoardScene.swift WWIIHexV0/SpriteKit/MapLayerOverlayCalculator.swift WWIIHexV0/SpriteKit/MapLayerOverlayNode.swift WWIIHexV0/Core/FrontLine.swift WWIIHexV0/Core/FrontSegment.swift WWIIHexV0/Core/FrontLineState.swift WWIIHexV0/Core/FrontLineTypes.swift WWIIHexV0/UI/ReleaseChecklistView.swift`：通过，无输出。
- `jq empty WWIIHexV0/Data/wude_618_scenario.json WWIIHexV0/Data/wude_618_regions.json WWIIHexV0/Data/suitang_unit_templates.json WWIIHexV0/Data/suitang_generals.json WWIIHexV0/Data/suitang_power_profiles.json WWIIHexV0/Data/suitang_terrain_rules.json`：通过，无输出。
- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj`：通过，输出 `WWIIHexV0.xcodeproj/project.pbxproj: OK`。
- `git diff --check`：通过，无输出。
- 文档/源码尾随空白扫描、真实冲突标记扫描、旧默认测试口径扫描和过时待办精确扫描：均无命中。
- 未执行 Xcode / XCTest / 模拟器 / app 启动等重测试。

遗留事项：

- 前线墨线尚未经过真实 SpriteKit 截图检查；层级、遮挡、缩放和颜色可读性仍需授权运行时验证。
- 当前仍是由 region/front chain 推导的最小接触线，不是逐边 hex 边界、手绘资产或动画化战线。
- 外交归附、州郡经营命令、太守/使者执行器、正式地图资产和完整发布候选重测仍待后续；存档错误反馈已由 v3.7-preflight.7 补上最小用户可见状态。

## v3.7-preflight.5 - AI 计划箭头

完成日期：2026-07-05

性质：完整 v3.7 发布候选前置补洞。补上最近 AI 战区指令的最小地图计划箭头，不代表真实路径预测、AI 规则变更或完整发布候选已完成。

核心更新：

- `BoardRenderState` 新增 `recentDirectiveRecords`，由 `BoardSceneAdapter` 从 `AppContainer.lastWarDirectiveRecords` 或 `gameState.warDirectiveRecords` 最近记录提供。
- `BoardScene.drawPlannedOperations` 保留玩家计划线，并追加绘制最近 6 条非玩家 `WarDirectiveRecord`。
- AI 攻击 directive 以虚线箭头显示来源防区到目标州郡；目标优先读 `commandTarget.region`，再 fallback 到 `targetRegionIds.first`。
- AI 防御 directive 或无明确目标的记录在来源防区画防守圈。
- AI 计划使用势力色虚线，与玩家实线计划区分。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_ai_plan_arrows_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/SpriteKit/BoardSceneAdapter.swift`
- `WWIIHexV0/SpriteKit/BoardScene.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_ai_plan_arrows_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `README.md`
- `update_log.md`

验证记录：

- `swiftc -parse WWIIHexV0/SpriteKit/BoardSceneAdapter.swift WWIIHexV0/SpriteKit/BoardScene.swift WWIIHexV0/Core/WarDirectiveRecord.swift WWIIHexV0/Commands/WarDirective.swift WWIIHexV0/Core/PlayerCommandState.swift`：通过，无输出。
- 最终 Markdown、JSON、plist、冲突标记、尾随空白和 `git diff --check` 轻量检查见本轮交付记录。
- 未执行 Xcode / XCTest / 模拟器 / app 启动等重测试。

遗留事项：

- AI 虚线箭头尚未经过真实 SpriteKit 截图检查；层级、遮挡、缩放和颜色可读性仍需授权运行时验证。
- 当前只显示 directive 级来源防区和目标州郡，不画每支 AI 部队的真实路径。
- 外交归附、州郡经营命令、太守/使者执行器、正式地图资产和完整发布候选重测仍待后续；前线墨线已由 v3.7-preflight.6 补上最小显示，仍待运行时截图验证。

## v3.7-preflight.4 - 渡口和港口地图标识

完成日期：2026-07-05

性质：完整 v3.7 发布候选前置补洞。补上渡口/港口最小视觉标识，不代表水战、渡河、港口补给或完整发布候选已完成。

核心更新：

- `MapState` 新增 `MapFeatureKind`、`MapFeatureMarker` 和 `featureMarkers`，用于承载 scenario `keyLocations` 的只读运行时地点标识。
- `MapState` 自定义 Codable，旧存档缺少 `featureMarkers` 时默认解码为空数组。
- `DataLoader.makeMapState(from:)` 会把 `ScenarioDefinition.keyLocations` 映射为 `MapFeatureMarker`。
- `wude_618_scenario.json` 新增蒲津渡、孟津渡、黎阳津、洛口津 4 个水路地点；它们不进入 objective，不改变胜负规则。
- `BoardScene` 按 hex coord 把地点标识传给 `HexNode`。
- `HexNode` 对 `ferry` 绘制渡船图标，对 `port/harbor` 绘制帆船/港口图标；图标为代码绘制，不引入外部素材。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_waterway_markers_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Core/MapState.swift`
- `WWIIHexV0/Data/DataLoader.swift`
- `WWIIHexV0/Data/wude_618_scenario.json`
- `WWIIHexV0/SpriteKit/BoardScene.swift`
- `WWIIHexV0/SpriteKit/HexNode.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_waterway_markers_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `README.md`
- `update_log.md`

验证记录：

- `swiftc -parse` 针对 `MapState.swift`、`ScenarioDefinition.swift`、`DataLoader.swift`、`HexNode.swift`、`BoardScene.swift`、`BoardSceneAdapter.swift`、`MapDisplayAdapter.swift`：通过，无输出。
- `jq empty WWIIHexV0/Data/wude_618_scenario.json`：通过，无输出。
- 最终 Markdown、JSON、plist、冲突标记、尾随空白和 `git diff --check` 轻量检查见本轮交付记录。
- 未执行 Xcode / XCTest / 模拟器 / app 启动等重测试。

遗留事项：

- 渡口/港口图标尚未经过真实 SpriteKit 截图检查；遮挡、层级和不同缩放下的可读性仍需授权运行时验证。
- `featureMarkers` 当前只服务显示，不实现水路移动、渡河规则、港口补给或水师规则。
- 正式地图资产、外交归附、州郡经营命令和完整发布候选重测仍待后续；AI 计划箭头与前线墨线已由 v3.7-preflight.5 / v3.7-preflight.6 补上最小显示，仍待运行时截图验证。

## v3.7-preflight.3 - 开局引导、基础设置和发布前检查面板

完成日期：2026-07-05

性质：完整 v3.7 发布候选前置补洞。补上最小新手引导、设置入口、版本说明和发布前检查清单，不代表授权运行时重测或完整发布候选已完成。

核心更新：

- HUD 新增“筹备”菜单，提供开局引导、基础设置和发布前检查入口。
- 新增 `FirstTurnGuideView`，展示当前剧本、回合、行动势力，以及第一回合建议顺序：看大势、选军队、查州郡、交给总管、结束回合。
- 新增 `GameSettingsView`，集中切换观战模式和地图图层，并显示本地存档状态；设置页不写入存档。
- 新增 `ReleaseChecklistView`，显示 `天命开唐 Agent · v3.7-preflight.3`、当前剧本/势力/存档状态，以及已接入事项和仍待授权验证事项。
- 新增 `ReleaseCandidateMenu`，并把新 UI 文件加入 iOS/macOS 主游戏 target。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_onboarding_settings_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/UI/FirstTurnGuideView.swift`
- `WWIIHexV0/UI/GameSettingsView.swift`
- `WWIIHexV0/UI/ReleaseChecklistView.swift`
- `WWIIHexV0/UI/ReleaseCandidateMenu.swift`
- `WWIIHexV0/UI/HUDView.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `WWIIHexV0.xcodeproj/project.pbxproj`
- `md/prompt/v3.0-隋唐迁移/v3.7_onboarding_settings_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `README.md`
- `update_log.md`

验证记录：

- `swiftc -parse` 针对本轮新增/修改的 UI Swift 文件：通过，无输出。
- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj`：通过。
- 最终 Markdown、冲突标记、尾随空白和 `git diff --check` 轻量检查见本轮交付记录。
- 未执行 Xcode / XCTest / 模拟器 / app 启动等重测试。

遗留事项：

- 新增 sheet、SF Symbol、布局、动态字体、观战/图层设置交互仍需授权运行时验证。
- 发布前检查面板是静态内置清单，不是自动 CI artifact 验收器。
- 外交归附、州郡经营命令、太守/使者执行器、正式地图资产、渡口/港口图标、AI 计划箭头和完整发布候选重测仍待后续。

## v3.7-preflight.2 - 新局、继续、重置与本地自动存档

完成日期：2026-07-05

性质：完整 v3.7 发布候选前置补洞。补上本地存档和局势生命周期入口，不代表新手引导、设置、发布候选检查清单或授权运行时重测已完成。

核心更新：

- 新增 `GameSaveStore`，使用 Documents 目录下的 `WWIIHexV0-current-game.json` 保存和读取 `GameState`。
- `AppContainer.bootstrap()` 启动时优先读取本地存档；读取失败时回到默认剧本并写入交互日志。
- 玩家底层 `Command`、玩家总管 `ZoneDirective` 和 AI 回合结算后会自动保存当前 `GameState`。
- `AppContainer` 新增 `startNewGame()`、`continueSavedGame()` 和增强后的 `resetGame()`：
  - 新局：加载默认剧本并立即保存。
  - 继续：读取本地存档并刷新运行时派生状态。
  - 重置：删除本地存档并恢复默认剧本。
- HUD 入口从单一新局按钮扩展为“局势”菜单，提供新局、继续、重置；继续按钮在没有存档时禁用。
- macOS 顶部菜单改为中文“局势”，并提供结束回合、新局、继续、重置快捷入口。
- 同步阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_lifecycle_save_record.md`，以及 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/App/GameSaveStore.swift`
- `WWIIHexV0/App/AppContainer.swift`
- `WWIIHexV0/App/WWIIHexV0MacApp.swift`
- `WWIIHexV0/UI/HUDView.swift`
- `WWIIHexV0/UI/NewGameButton.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `WWIIHexV0.xcodeproj/project.pbxproj`
- `md/prompt/v3.0-隋唐迁移/v3.7_lifecycle_save_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `README.md`
- `update_log.md`

验证记录：

- `swiftc -parse` 针对 `GameSaveStore.swift`、`AppContainer.swift`、`WWIIHexV0MacApp.swift`、`HUDView.swift`、`NewGameButton.swift`、`RootGameView.swift`：通过，无输出。
- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj`：通过。
- 最终 Markdown、JSON、冲突标记、尾随空白和 `git diff --check` 轻量检查见本轮交付记录。
- 未执行 Xcode / XCTest / 模拟器 / app 启动等重测试。

遗留事项：

- 存档只覆盖 `GameState`，不覆盖当前选择、高亮、展开面板、地图图层或观察模式等临时 UI 状态。
- 未做存档版本迁移器、存档列表、多槽位、导入导出或用户确认弹窗。
- 新手引导、设置页、版本说明、发布候选检查清单、外交归附、州郡经营命令和正式地图资产仍待后续；AI 计划箭头已由 v3.7-preflight.5 补上最小显示，仍待运行时截图验证。
- 真实文件读写、macOS 菜单状态刷新和 HUD 菜单布局仍需授权运行时验证。

## v3.7-preflight - 隋唐胜负闭环最小迁移

完成日期：2026-07-05

性质：完整 v3.7 发布候选前置补洞。只把 `wude_618` 核心胜利条件接入运行时，不代表存档、新手引导、设置、发布候选或授权运行时重测已完成。

核心更新：

- `MapState` 新增按 objective id 查询目标点和控制者的 helper，避免运行时胜负判断依赖中文展示名。
- `VictoryReason` 新增隋唐胜利原因：唐克洛阳与洛口仓、洛阳隋夺潼关、唐终局守长安、终局长安失守，并提供中文 `displayName`。
- `VictoryRules.updateVictoryState` 对 `wude_618_guanzhong_luoyang` 走隋唐分支：
  - 唐控制洛阳和洛口仓即胜。
  - 洛阳隋控制潼关即胜。
  - 到 `maxTurns` 后，等待当前势力顺序的最后一个势力结束行动，再按长安控制权结算。
- 阿登 legacy 胜利规则保留在原分支，继续使用 Bastogne / St. Vith / 歼灭单位 / 德军装甲断补逻辑。
- HUD 胜负字段从只显示胜者改为显示胜者和中文胜利原因。
- 新增阶段记录 `md/prompt/v3.0-隋唐迁移/v3.7_victory_runtime_record.md`，并同步 `README.md`、`md/flow/*`、`md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Core/MapState.swift`
- `WWIIHexV0/Core/VictoryState.swift`
- `WWIIHexV0/Rules/VictoryRules.swift`
- `WWIIHexV0/UI/HUDView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.7_victory_runtime_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `README.md`
- `update_log.md`

验证记录：

- `swiftc -parse` 针对 `Faction.swift`、`HexCoord.swift`、`Terrain.swift`、`Region.swift`、`MapState.swift`、`VictoryState.swift`、`GamePhase.swift`、`GameState.swift`、`VictoryRules.swift`：通过，无输出。
- 最终 Markdown、JSON、plist、冲突标记、尾随空白和 `git diff --check` 轻量检查见本轮交付记录。
- 未执行 Xcode / XCTest / 模拟器 / app 启动等重测试。

遗留事项：

- 胜利条件仍是 `wude_618` 专属最小分支，不是通用数据驱动 victory condition interpreter。
- 终局胜负只处理核心目标点，不含天命、民心、归附、威望或多势力评分。
- 存档、新手引导、设置、发布候选检查清单、外交归附、州郡经营命令和正式地图资产仍待后续；AI 计划箭头已由 v3.7-preflight.5 补上最小显示，仍待运行时截图验证。
- 运行时 UI 布局、真实回合推进和云端构建仍需 GitHub Actions 或人工授权重测确认。

## v3.6 - 隋唐发布级 UI 视觉基底第一步

完成日期：2026-07-05

性质：发布级 UI、美术和交互收口的第一步。仍不是完整发布级地图重绘、正式图标资产、存档引导或发布候选。

核心更新：

- `PlatformStyles.swift` 新增 `SuitangDesignTokens`、`SuitangPanelProminence` 和 `View.suitangPanel(_:)`，统一绢帛底、墨色、朱印、铜色、青绿、水色、8px 圆角和 44pt 最小触控目标。
- `RootGameView` 的 HUD、地图图层 Picker、观战切换、军情入口和信息面板外框改用隋唐视觉基底。
- `MapDisplayLayer.displayName` 从 `Hex / Province / Initial / Dynamic / Front / Deploy` 改为地块、州郡、初始方面、动态方面、前线、部署。
- `HUDView` 使用旗帜标题与隋唐 elevated panel；legacy fallback 标题从 `Ardennes V0` 改为“调试剧本”。
- `NewGameButton` 改为“新局”，`[ INFO ]` 改为“军情 / 收起军情”，`Observer` 改为“观战”。
- `EventLogView`、`DiplomacyPanelView`、`CommandPanelView`、`RegionInspectorView`、`EconomyPanelView`、`AgentPanelView`、`GeneralCommandPanelView`、`UnitInspectorView`、`UnitTooltipView` 改用统一 panel 样式。
- `GeneralProfileView` 将将领档案标题、关闭按钮、生平、用兵、所属防区、亲附、忠诚、满意、特性、所属军队等玩家可见字段中文化，并复用 v3.6 视觉基底。
- `HexNode` 新增代码绘制的最小城池、关隘和粮仓图形标识，移除旧 `FORT`、`SUP A`、`SUP G` 调试标签；标识仍受现有 fog / visibility 逻辑约束。
- `BoardScene` 空态标题从 `Hex Campaign Board` 改为“战役地图”，并新增只读粮道虚线和围城圈：粮道从可见军队连向最近可达补给源，围城圈来自 `SupplyRules.isBesieged` 判定。
- 新增阶段记录 `md/prompt/v3.0-隋唐迁移/v3.6_ui_art_polish_record.md`，并同步 `md/flow/*`、`md/plan/plan.md` 与 `README.md`。

关键文件：

- `WWIIHexV0/UI/PlatformStyles.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `WWIIHexV0/UI/HUDView.swift`
- `WWIIHexV0/UI/NewGameButton.swift`
- `WWIIHexV0/UI/InfoPanelToggle.swift`
- `WWIIHexV0/UI/EventLogView.swift`
- `WWIIHexV0/UI/DiplomacyPanelView.swift`
- `WWIIHexV0/UI/CommandPanelView.swift`
- `WWIIHexV0/UI/RegionInspectorView.swift`
- `WWIIHexV0/UI/EconomyPanelView.swift`
- `WWIIHexV0/UI/AgentPanelView.swift`
- `WWIIHexV0/UI/GeneralCommandPanelView.swift`
- `WWIIHexV0/UI/UnitInspectorView.swift`
- `WWIIHexV0/UI/UnitTooltipView.swift`
- `WWIIHexV0/UI/GeneralProfileView.swift`
- `WWIIHexV0/SpriteKit/HexNode.swift`
- `WWIIHexV0/SpriteKit/BoardScene.swift`
- `WWIIHexV0/Rules/SupplyRules.swift`（只读调用，未改规则）
- `WWIIHexV0/Core/MapDisplayLayer.swift`
- `md/prompt/v3.0-隋唐迁移/v3.6_ui_art_polish_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `README.md`
- `update_log.md`

验证记录：

- `swiftc -parse` 针对 v3.6 修改的 UI / Core 显示文件：通过，无输出。
- `swiftc -parse` 针对 `HexNode.swift`、`BoardScene.swift`、`SupplyRules.swift` 和相关 SpriteKit / Core 文件：通过，无输出。
- 显眼玩家可见英文残留扫描：未再命中 `NEW GAME`、`Observer`、`[ INFO ]`、地图图层英文、将领档案英文标题等旧文案。
- 最终 Markdown、JSON、plist、冲突标记、尾随空白和 `git diff --check` 轻量检查见本轮交付记录。
- 未执行 Xcode / XCTest / 模拟器 / app 启动等重测试。

遗留事项：

- SpriteKit 地图仍未完成发布级重绘；城池、关隘、粮仓、渡口和港口当前都是代码绘制的最小标识，仍待正式资产和运行时截图验证。
- 粮道虚线和围城圈仍是直线/圆环的最小可视化，不是正式美术或真实路径逐段绘制。
- AI 计划箭头和前线墨线已由 v3.7-preflight.5 / v3.7-preflight.6 补上最小显示，仍需进一步验证它们和玩家计划、战区前线、战役复盘的可读性。
- 将领头像仍是文字占位，不是正式风格化印章或头像。
- 胜利规则、外交归附、州郡经营命令、存档/新手引导和真实模型接入仍待后续版本。
- 真实布局、动态字体、SF Symbol 可用性和运行时 UI 尚未经过授权重测。

## v3.5 - 玩家军令、州郡、外交和战报体验最小闭环

完成日期：2026-07-05

性质：玩家信息闭环与 UI 可读性最小迁移。仍不是完整州郡经营、外交执行器或发布级 UI。

核心更新：

- `EventLogView` 升级为“战报”面板，聚合朝堂姿态、AI 意图、方面军令数量、执行成功数、拒绝数和本回合重点事件。
- `RootGameView` 的 Log tab 接入 `lastAgentDecisionRecord`、`lastWarDirectiveRecords`、`latestCourtRecord`；信息 tabs 改为军队、州郡、总管、战报、粮饷、外交、AI。
- `DiplomacyPanelView` 改为隋唐中文口径，并显示最新朝堂记录中的谋主、军令数和使者摘要。
- `DiplomaticStatus.displayName` 改为中文：盟友、协同讨伐、中立、停战、称臣、归附、敌对、交战。
- `RegionInspectorView` 增加州郡重要性摘要：粮仓要地、可供征发、前线承压、敌军可见、胜负要点。
- `CommandPanelView` 改为中文军令入口：军令、固守、准退、整军、结束回合，并给出中文可用/拒绝状态。
- `AppContainer` 的主要玩家交互日志改为中文，覆盖军令执行/拒绝、AI 结算、选择地块/州郡/军队、总管军令拒绝与提交、生产拒绝等玩家可见信息。
- 新增阶段记录 `md/prompt/v3.0-隋唐迁移/v3.5_player_command_ux_record.md`，并同步 `md/flow/*`、`md/plan/plan.md` 与 `README.md`。

关键文件：

- `WWIIHexV0/App/AppContainer.swift`
- `WWIIHexV0/Core/DiplomacyState.swift`
- `WWIIHexV0/UI/EventLogView.swift`
- `WWIIHexV0/UI/DiplomacyPanelView.swift`
- `WWIIHexV0/UI/RegionInspectorView.swift`
- `WWIIHexV0/UI/CommandPanelView.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.5_player_command_ux_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `README.md`
- `update_log.md`

验证记录：

- `swiftc -parse` 针对本轮修改的 App / Core / UI Swift 文件：通过，无输出。
- `jq empty` 针对 6 个隋唐 JSON 文件：通过，无输出。
- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj`：通过。
- 冲突标记、尾随空白和 `git diff --check` 轻量检查：通过。
- 未执行 Xcode / XCTest / 模拟器 / app 启动等重测试。

遗留事项：

- 玩家仍不能执行真正的州郡经营命令，征发、屯田、修道、治安和归附安抚需要后续 `Command` / validator / executor。
- 外交面板仍是只读态势展示，停战、同盟、称臣、借兵、招降还没有执行链路。
- 战报面板未做筛选、按回合折叠或更完整的战役复盘。
- 发布级 UI、美术、地图图标、粮道线、围城圈和计划箭头在 v3.5 时仍未完成；v3.6 已开始收口 UI 基底和最小地图标识，正式资产与 AI 计划箭头仍需后续。

## v3.4 - 朝堂 AI Agent 分层与审计记录

完成日期：2026-07-05

性质：AI 上游分层与审计记录最小迁移。仍不是完整内政、外交、真实 LLM 或发布级 AI。

核心更新：

- 新增 `CourtAgent`，在现有元帅/战区 directive 之上建立君主、谋主、太守、行军总管、将领、使者的最小朝堂链路。
- `TurnManager` 在 `.marshalDirective` 和 `.zoneDirective` 两条 AI directive 路径中调用 `CourtAgent`；执行使用朝堂调整后的 `DirectiveEnvelope`，下游仍是 `ZoneDirective -> WarCommandExecutor -> RuleEngine`。
- `RulerAgent.adjust` 修正 attack / defense 塑形时丢失 focus、support、convergence、coordinated zones、maxCommittedUnits、exploitDepth、fallback、counterattack、strongpoint 等参数的问题。
- `DiplomacyState` 新增 `CourtAgentRole`、`CourtAgentStepRecord`、`CourtDecisionRecord` 和 `courtRecords`，并提供 `latestCourtRecord`、`appendCourtRecord` 与 Codable 兼容默认值。
- AI 回合执行后会把 `RulerDecisionRecord` 与 `CourtDecisionRecord` 写入 `GameState.diplomacyState`，并写入朝堂决策事件；不直接修改 hex、单位、战区、部署或外交关系。
- `AgentPanelView` 增加“朝堂链路”展示，显示每个角色的 agent id、摘要、目标方面/州郡和 directive 数；`RootGameView` 接入最新 court record。
- 新增阶段记录 `md/prompt/v3.0-隋唐迁移/v3.4_agent_court_record.md`，并同步 `md/flow/*`、`md/plan/plan.md` 与 `README.md`。

关键文件：

- `WWIIHexV0/Core/DiplomacyState.swift`
- `WWIIHexV0/Agents/RulerAgent.swift`
- `WWIIHexV0/Turn/TurnManager.swift`
- `WWIIHexV0/UI/AgentPanelView.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.4_agent_court_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `README.md`
- `update_log.md`

验证记录：

- `swiftc -parse` 针对本轮修改的 Core / Agents / Turn / UI Swift 文件：通过，无输出。
- `jq empty` 针对 6 个隋唐 JSON 文件：通过，无输出。
- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj`：通过。
- 冲突标记、尾随空白和 `git diff --check` 轻量检查：通过。
- 未执行 Xcode / XCTest / 模拟器 / app 启动等重测试。

遗留事项：

- `CourtAgent` 仍是 deterministic 最小审计层，不是真实多模型/多 prompt 协作。
- 太守内政、外交使者、归附、停战、借兵和征发执行器尚未实现。
- UI 只在 AI 面板展示朝堂链路，尚未形成完整军令、州郡、将领、战报、外交体验闭环。
- `VictoryRules`、发布级隋唐 UI、真实本地 LLM 接入仍需后续版本迁移。

## v3.3 - 军队、兵种、粮道、围城和战术规则最小迁移

完成日期：2026-07-05

性质：规则与显示兼容层迁移。仍不是发布级隋唐玩法闭环。

核心更新：

- `ComponentType` 新增隋唐兵种：骑军、弓弩、攻城器械、亲军、水师、乡兵；保留 `tank` / `motorizedInfantry` / `artillery` legacy rawValue。
- `suitang_unit_templates.json` 改用新兵种 rawValue，`DataLoader.fallbackComponents` 同步识别 `suitang_*` 模板。
- `Division` 新增机动、远程、攻城和主兵种显示 helper；AI 机动兵力、远程支援和执行器排序改读新语义。
- `SupplyRules.isBesieged` 建立最小围城判断：城池/关隘守军无粮道且敌邻接时视为断粮被围，并写围城日志。
- `CombatRules` 增加骑军平原冲击、复杂地形限制、攻城器械对城池/关隘加成和被围防御下调。
- `EconomyRules` 将资源日志映射为丁口、军械、粮草；自动补员明确排除被围守军；生产单位使用隋唐兵种 component。
- HUD、UnitInspector、UnitTooltip、UnitNode、EconomyPanel、RegionInspector、AgentPanel、GeneralCommandPanel、`GamePhase.displayName`、`BaseTerrain.displayName` 做最小隋唐显示迁移。
- 新增阶段记录 `md/prompt/v3.0-隋唐迁移/v3.3_war_rules_record.md`，并同步 `md/flow/*` 与 `md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Core/Division.swift`
- `WWIIHexV0/Core/SupplyState.swift`
- `WWIIHexV0/Core/EconomyState.swift`
- `WWIIHexV0/Core/Terrain.swift`
- `WWIIHexV0/Core/GamePhase.swift`
- `WWIIHexV0/Data/DataLoader.swift`
- `WWIIHexV0/Data/suitang_unit_templates.json`
- `WWIIHexV0/Rules/CombatRules.swift`
- `WWIIHexV0/Rules/SupplyRules.swift`
- `WWIIHexV0/Rules/EconomyRules.swift`
- `WWIIHexV0/Commands/WarDirective.swift`
- `WWIIHexV0/Commands/WarCommandExecutor.swift`
- `WWIIHexV0/Agents/ZoneCommanderAgent.swift`
- `WWIIHexV0/UI/HUDView.swift`
- `WWIIHexV0/UI/UnitInspectorView.swift`
- `WWIIHexV0/UI/UnitTooltipView.swift`
- `WWIIHexV0/UI/EconomyPanelView.swift`
- `WWIIHexV0/UI/RegionInspectorView.swift`
- `WWIIHexV0/UI/AgentPanelView.swift`
- `WWIIHexV0/UI/GeneralCommandPanelView.swift`
- `WWIIHexV0/SpriteKit/UnitNode.swift`
- `md/prompt/v3.0-隋唐迁移/v3.3_war_rules_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

验证记录：

- `jq empty WWIIHexV0/Data/suitang_unit_templates.json`：通过，无输出。
- `swiftc -parse` 针对本轮修改的 Core / Data / Rules / Commands / Agents / UI / SpriteKit Swift 文件：通过，无输出。
- 最终 Markdown 和 diff 轻量检查见本轮交付记录。
- 未执行 Xcode / XCTest / 模拟器 / app 启动等重测试。

遗留事项：

- 围城仍是派生式最小规则，没有 siege progress、士气、破城、投降或归附状态。
- `VictoryRules` 仍是阿登语义，`wude_618` 的胜负条件仍需后续版本接入运行时。
- 旧 Agent D、旧 sample state、旧测试和阿登 fallback 仍保留二战兼容命名。
- 本轮未做 Xcode 编译，SwiftUI/SpriteKit 符号可用性仍需云端或授权重测确认。

## v3.2 - 隋唐地图、剧本数据和默认入口

完成日期：2026-07-04

性质：默认数据与加载入口迁移。仍不是发布级隋唐玩法闭环。

核心更新：

- 新增 `wude_618_guanzhong_luoyang` 剧本：10x9、90 hex、36 region、7 个隋唐势力、19 支初始军队。
- 新增隋唐数据文件：scenario、regions、unit templates、generals、power profiles、terrain rules。
- `DataLoader.loadInitialGameState()` 优先加载 `wude_618_scenario` / `wude_618_regions`，失败时保留阿登 fallback。
- `loadGameState(...)` 新增可选 unit template / general registry 资源名参数，并保持 MapEditor 临时导出目录的 fallback 兼容。
- `AppContainer.bootstrap()` 根据 scenario 选择 general registry，`wude_618` 默认玩家势力为唐。
- HUD / board accessibility / SpriteKit 空态去掉主要阿登硬编码标题。
- 新增 JSON 已加入 iOS 和 macOS 主游戏 resource phase。
- 新增阶段记录 `md/prompt/v3.0-隋唐迁移/v3.2_scenario_map_record.md`，并同步 `md/flow/*` 与 `md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Data/wude_618_scenario.json`
- `WWIIHexV0/Data/wude_618_regions.json`
- `WWIIHexV0/Data/suitang_unit_templates.json`
- `WWIIHexV0/Data/suitang_generals.json`
- `WWIIHexV0/Data/suitang_power_profiles.json`
- `WWIIHexV0/Data/suitang_terrain_rules.json`
- `WWIIHexV0/Data/DataLoader.swift`
- `WWIIHexV0/App/AppContainer.swift`
- `WWIIHexV0/UI/HUDView.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `WWIIHexV0/SpriteKit/BoardScene.swift`
- `WWIIHexV0.xcodeproj/project.pbxproj`
- `md/prompt/v3.0-隋唐迁移/v3.2_scenario_map_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

验证记录：

- `jq empty` 针对 6 个新增 JSON：通过，无输出。
- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj`：通过。
- `swiftc -parse` 针对本轮修改的 Data / App / UI / SpriteKit 入口文件：通过，无输出。
- 最终 Markdown 和 diff 轻量检查见本轮交付记录。
- 未执行 Xcode / XCTest / 模拟器 / app 启动等重测试。

遗留事项：

- `VictoryRules` 仍是阿登语义；`wude_618` 胜利条件目前只在 JSON 中记录，运行时消费需后续迁移。
- `ComponentType` 仍是 legacy 二战枚举；隋唐兵种当前只是模板显示与权重映射。
- MapEditor 默认桥仍指向阿登资源，后续迁移需要同步旧测试口径。
- 旧测试仍大量假设默认启动为阿登；本轮未修改或运行测试。
- `RegionNode` 仍不能表达真正 nil controller 的战略 region，地方中立语义需后续 schema / Faction 策略。

## v3.1 - 多势力、外交关系和通用回合阶段最小迁移

完成日期：2026-07-04

性质：源码兼容层迁移。默认剧本仍是阿登，不表示 v3.x 隋唐玩法闭环完成。

核心更新：

- `Faction` 新增隋唐势力：唐、洛阳隋、瓦岗、夏、薛秦、刘武周、东突厥；保留 `germany/allies` legacy 兼容。
- `GamePhase` 新增 `playerCommand` / `aiCommand`，保留 `germanAI` / `alliedPlayer` legacy 阶段。
- `DiplomacyState` 新增 `relationStatus`、`isHostile`、`canAttack`、`isFriendly`，并可为隋唐势力生成初始 country / bloc。
- 核心规则层的敌对判断从 `.opponent` 迁移到 `DiplomacyState`：攻击校验、ZOC、补给通行、安全撤退、region 压力、前线 `factionB` 推导、AI 摘要和战术目的地排序均改为关系判断。
- App / TurnManager / UI 入口支持 generic phase：玩家输入使用 `phase.allowsPlayerInput`，AI 执行支持 `phase.allowsAIExecution`。
- SpriteKit 和 MapEditor 覆盖新增势力的基础颜色和中文名。
- 新增阶段记录 `md/prompt/v3.0-隋唐迁移/v3.1_powers_diplomacy_record.md`，并同步 `md/flow/*` 与 `md/plan/plan.md`。

关键文件：

- `WWIIHexV0/Core/Faction.swift`
- `WWIIHexV0/Core/GamePhase.swift`
- `WWIIHexV0/Core/DiplomacyState.swift`
- `WWIIHexV0/Rules/CommandExecutor.swift`
- `WWIIHexV0/Rules/CommandValidator.swift`
- `WWIIHexV0/Rules/SupplyRules.swift`
- `WWIIHexV0/Rules/RegionSupplyRules.swift`
- `WWIIHexV0/Rules/RegionCombatRules.swift`
- `WWIIHexV0/Rules/FrontLineManager.swift`
- `WWIIHexV0/Commands/WarCommandExecutor.swift`
- `WWIIHexV0/App/AppContainer.swift`
- `WWIIHexV0/Turn/TurnManager.swift`
- `WWIIHexV0/Agents/AgentContexts.swift`
- `WWIIHexV0/Agents/RulerAgent.swift`
- `WWIIHexV0/Agents/ZoneCommanderAgent.swift`
- `WWIIHexV0/SpriteKit/TerrainStyle.swift`
- `MapEditor/MapEditorView.swift`
- `md/prompt/v3.0-隋唐迁移/v3.1_powers_diplomacy_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/plan/plan.md`
- `update_log.md`

验证记录：

- `swiftc -parse` 针对本轮改动的 Core / Rules / Commands / Agents / App / Turn Swift 文件：通过，无输出。
- `swiftc -parse` 针对本轮改动的 UI / MapEditor / SpriteKit Swift 文件：通过，无输出。
- 最终 Markdown 和 diff 轻量检查见本轮交付记录。
- 未执行 Xcode / XCTest / 模拟器 / app 启动等重测试。

遗留事项：

- `wude_618` 隋唐默认剧本数据已由 v3.2 接入；后续仍需 Xcode / CI 验证真实启动路径。
- player faction 选择尚未进入 `GameState`；generic phase 当前默认 `tang/allies` 为人类控制入口。
- 胜利条件和生产/兵种仍是二战语义，需 v3.2-v3.3 继续迁移。
- 测试文件仍大量使用 `germany/allies` 和二战语义，本轮未修改测试。

## v3.0 - 隋唐迁移审计、兼容层和题材合同

完成日期：2026-07-04

性质：迁移入口文档阶段，不是业务源码迁移，不表示默认剧本、UI 或运行时已完成隋唐化。

核心更新：

- 新增 `md/prompt/v3.0-隋唐迁移/v3.0_audit_and_contract.md`，完成 v3.0 硬编码审计、二元阵营假设扫描、迁移词汇表、状态/命令/势力/阶段/data schema/AI Agent 合同、P0-P3 优先级、风险清单和 v3.1 入口提示词草案。
- 在 `md/plan/plan.md` 中把“当前首轮建议”更新为“当前首轮结果与下一步”，明确 v3.0 审计合同已落地，下一轮可进入 v3.1。
- 在 `md/flow/flow.md` 和 `md/flow/flowchart.md` 增加 v3.0 隋唐迁移审计入口说明，强调当前真实运行时仍是 WWII / Ardennes，后续迁移仍必须守住 hex 权威和统一规则入口。

关键文件：

- `md/prompt/v3.0-隋唐迁移/v3.0_audit_and_contract.md`
- `md/plan/plan.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `update_log.md`

验证记录：

- 本轮只做 Markdown 文档改动。
- 轻量检查结果见本轮最终交付记录。
- 未执行 Xcode / XCTest / 模拟器 / app 启动等重测试。

遗留事项：

- v3.1 应从 `Faction` 多势力兼容、`GamePhase` 通用阶段、`DiplomacyState` 敌我关系、`CommandValidator` / `CommandExecutor` 二元阶段解除开始。
- 默认剧本仍是阿登；隋唐 `wude_618` 剧本应放到 v3.2。
- README / AGENTS 项目身份仍应等真实源码和默认数据迁移达到对应状态后再改。

## 历史维护记录 - v3.0 隋唐迁移 md 大纲

完成日期：2026-07-04

性质：文档大纲整理，不是业务功能实现，不表示 v3.0 代码迁移已完成。

核心更新：

- 根据 `md/prompt/v3.0-隋唐迁移/codex-v3.0-隋末唐初aiagent历史策略迁移总提示词.md`，将旧 `md/plan/plan.md` 的二战 v0.x 后续计划改为隋末唐初 v3.0-v3.8 迁移大纲。
- 明确最终产品目标、首发剧本方向、迁移铁律、二战语义替换方向、v3.0-v3.8 阶段路线、推荐多 Agent 分工、文档落点和首轮 v3.0 审计建议。
- 明确本轮只改 md 大纲，不改源码、不更新 README / AGENTS 项目身份、不伪装为正式 v3.0 完成。

关键文件：

- `md/plan/plan.md`
- `update_log.md`

验证记录：

- `rg -n "[[:blank:]]+$" update_log.md md/plan/plan.md`：无命中。
- `rg -n "<{7}|={7}|>{7}" update_log.md md/plan/plan.md`：无命中。
- `git diff --check`：通过，无输出。
- 未执行 Xcode / XCTest / 模拟器 / app 启动等重测试。

遗留事项：

- `md/prompt/v3.0-隋唐迁移/v3.0_audit_and_contract.md` 已在后续 v3.0 记录中补齐。
- README 与 AGENTS 的项目身份仍应等真实源码、默认数据和 UI 迁移达到对应状态后再同步更新。

## 历史维护记录 - main 直推与云端验证流程

完成日期：2026-07-04

性质：协作流程制度变更，不是业务功能或业务质量版本。

核心更新：

- 明确 Agent A/B/C 召唤规则和最终回复身份标识。
- 将默认协作流程升级为 `main` 直推：Agent B 本机轻量检查、commit、push 到 `origin/main`，触发 GitHub Actions。
- 将默认重验证迁移到云端：本机不主动跑 Xcode / XCTest / 模拟器 / 性能类重验证。
- 新增 Agent C 云端结果包验收规则：用 `gh auth login` 下载未加密 artifact，核对 manifest、JUnit/摘要、主日志、failure summary、run id、run attempt 和 `origin/main` 最新 commit。
- 新增 `.github/workflows/ci-results.yml`，用于在 `main` push 和手动触发时运行静态检查与 Xcode build，并上传 CI 结果包。
- 补齐缺失的 `md/prompt/README.md`，记录云端阶段 prompt 要求。

关键文件：

- `AGENTS.md`
- `README.md`
- `md/test/test.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/prompt/README.md`
- `.github/workflows/ci-results.yml`

验证记录：

- 本机只运行轻量检查；云端重验证由 GitHub Actions 执行。
- 若无法完成 push、workflow 或 artifact 下载，必须在交付中记录阻塞，不能伪造云端验收。

遗留事项：

- Agent C 只验收 `origin/main` 最新 commit 对应 run 和 artifact。
- 云端失败时，默认由 Agent B 在 `main` 上追加修复 commit 后重新 push，不做未授权回滚。

## v0 - 六角格测试板

完成日期：2026-06-14 至 2026-06-15

核心更新：

- 建立 iOS 二战回合制战棋原型，技术栈为 Swift + SwiftUI + SpriteKit。
- 创建阿登测试战场，使用 11x9 左右的 axial hex 地图。
- 落地地形、移动、战斗、占领、补给、包围、胜利条件、回合流程。
- 建立德军 MockAI 将领 `guderian`，按局势摘要生成结构化命令，再经规则系统校验执行。
- 建立 SwiftUI HUD、命令面板、事件日志、单位详情和 SpriteKit 六角格渲染。

关键系统：

- `Core/HexCoord.swift`
- `Core/MapState.swift`
- `Core/Division.swift`
- `Rules/RuleEngine.swift`
- `Rules/MovementRules.swift`
- `Rules/CombatRules.swift`
- `Rules/SupplyRules.swift`
- `Rules/VictoryRules.swift`
- `SpriteKit/BoardScene.swift`
- `UI/RootGameView.swift`

备注：

- v0 的核心边界是“可玩测试板”，不做空军、海军、经济、生产、外交、多级指挥链和真实 LLM。
- 后续所有版本都必须保留 hex 作为战术层权威。

## v0.1 - strength、撤退与补员

完成日期：2026-06-15 前后

核心更新：

- `Division` 战斗模型升级为 `strength/maxStrength`，保留 `hp/maxHP` 兼容。
- 战斗伤害从 HP 语义转向兵力语义，后续明确不恢复 organization。
- 引入撤退状态与 `RetreatMode`：`retreatable` 可自动撤退，`hold` 获得防御加成。
- 撤退失败会施加额外惩罚；无补给、包围会影响战斗与回合损耗。
- `resupply/rest` 能恢复兵力。
- UI 和日志补充 Strength、Retreating、combat/retreat/reinforce/encircle/supply 分类。

关键系统：

- `Core/Division.swift`
- `Rules/CombatRules.swift`
- `Rules/SupplyRules.swift`
- `Rules/RuleEngine.swift`
- `UI/UnitInspectorView.swift`
- `UI/HUDView.swift`

备注：

- v0.1 最终模型只看兵力，不引入 organization。
- `HOLD` 防御约 +20%，`RETREATABLE` 在单次损失比例达到阈值时自动撤退。

## Agent D - AI/Agent 决策管线

完成日期：2026-06-15

核心更新：

- 打捞并恢复早期 Agent D 管线，修复此前异常删除。
- 建立 `DecisionProvider` 协议，为 MockAI 与未来本地 LLM 共用。
- 建立 `AgentContext` / `AgentContextBuilder`，只传 Codable 摘要，不暴露 UI/SpriteKit 对象。
- 建立 `AgentDecisionEnvelope` / `AgentOrder` JSON schema。
- 建立 parser、command mapper、decision record 与 AI 决策展示面板。
- `TurnManager` 负责德军 AI 回合编排，`AppContainer.runAIIfNeeded()` 接入启动流程。

关键系统：

- `Agents/DecisionProvider.swift`
- `Agents/AgentContexts.swift`
- `Agents/AgentDecision.swift`
- `Agents/AgentDecisionParser.swift`
- `Agents/AgentCommandMapper.swift`
- `Agents/MockAIClient.swift`
- `Agents/LocalLLMDecisionProvider.swift`
- `Turn/TurnManager.swift`
- `UI/AgentPanelView.swift`
- `Tests/AgentPipelineTests.swift`

备注：

- Agent D 是重要历史管线，但 v0.37 后默认战争 AI 主路径已改为 ZoneDirective。
- 后续不得删除 Legacy Agent D；只能隔离、退役或作为回归参考。

## v0.2 - Region 战略层叠加

完成日期：2026-06-15 至 2026-06-16

核心更新：

- 明确废弃旧版“用 province 替换 hex”的方案，改为 Region 战略层叠加。
- `MapState` 同时持有 hex 与 region：`regions`、`hexToRegion`、`regionEdges`。
- 新增 `RegionId`、`RegionNode`、`RegionEdge`、`RegionGraph` 与校验错误类型。
- 建立阿登 v0.2 省份数据：17 省、41 边、99 hex 全覆盖、零重叠。
- `DataLoader` 加载 `ardennes_v02_regions.json` 并反向填充 `HexTile.regionId`。
- 新增 Region 规则层：移动、战斗、占领、补给、视野、胜利、pathfinder、rule system。
- 新增 `RegionCommand`、`CommandIntentAdapter`、AgentOrder schema v2，支持 region 命令与 hex 命令互转。
- UI 增加 `MapDisplayAdapter`、Region overlay 与 `RegionInspectorView`，hex 仍为唯一渲染对象。

关键系统：

- `Core/Region.swift`
- `Core/MapState.swift`
- `Data/RegionDataSet.swift`
- `Data/ardennes_v02_regions.json`
- `Rules/RegionRuleSystem.swift`
- `Rules/RegionMovementRules.swift`
- `Rules/RegionCombatRules.swift`
- `Rules/RegionOccupationRules.swift`
- `Rules/RegionSupplyRules.swift`
- `Rules/RegionVisibilityRules.swift`
- `Rules/RegionVictoryRules.swift`
- `Commands/RegionCommand.swift`
- `Commands/CommandIntentAdapter.swift`
- `SpriteKit/MapDisplayAdapter.swift`
- `UI/RegionInspectorView.swift`

验证记录：

- v0.2 Agent 6 验收：132 tests, 0 failures。
- 关键覆盖：RegionGraph、ArdennesV02Data、Region rules、Agent region command、MapDisplayAdapter、Board interaction、RuleEngineCore。

备注：

- v0.2 达成 Hex x Region 双轨架构稳定状态。
- 技术债：中立省 owner/controller 为 null 时仍回退到 `.allies`，因为 `Faction` 暂无 neutral case。

## v0.21 - 界面优化与重置流程

完成日期：2026-06-16

核心更新：

- 新增 `InfoPanelToggle`，信息面板默认收起，通过 `[ INFO ]` 展开。
- 新增 `UnitTooltipView`，右下角固定展示选中单位摘要。
- 新增 `NewGameButton` 与 `AppContainer.resetGame()`，支持重载初始地图/单位/Region 并清空选择与日志。
- `RootGameView` 在常规、竖屏、横屏布局中接入 Info toggle 与单位 tooltip。
- 任务 6 zoom 按设计跳过，保留固定放大 hex 与 camera drag。

关键系统：

- `UI/InfoPanelToggle.swift`
- `UI/UnitTooltipView.swift`
- `UI/NewGameButton.swift`
- `UI/RootGameView.swift`
- `UI/HUDView.swift`
- `App/AppContainer.swift`

验证记录：

- 135 tests, 0 failures。
- `swiftc -parse`、`plutil -lint`、`git diff --check` 通过。
- 模拟器烟测通过，截图记录为 `/tmp/wwiihex_v021_smoke2.png`。

## v0.31 - Theater 战区系统

完成日期：2026-06-17

核心更新：

- 新增战区数据结构：`TheaterId`、`TheaterNode`、`TheaterState`、支援请求和 AI 摘要。
- 新增 `TheaterSystem`，从 v0.2 Region 生成四个固定战区。
- 建立 `hex -> region -> theater` 映射与控制比例/胜利点聚合。
- 引入 70% 控制阈值，用于战区扩张正式化、退役和单位池重分配。
- 在 `GameState` 中加入 `theaterState`，兼容旧存档解码。
- `DataLoader` 在加载 Region 后自动生成 v0.31 四战区。

关键系统：

- `Core/Theater.swift`
- `Rules/TheaterSystem.swift`
- `Core/GameState.swift`
- `Data/DataLoader.swift`
- `Tests/TheaterSystemTests.swift`

验证记录：

- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj` 通过。
- 全量测试：146 tests, 0 failures。

备注：

- v0.31 不做 FrontLine、自动布防、攻势规划、LLM 决策、UI 重构或战斗/hex 规则改动。

## v0.32 - FrontLine 前线层

完成日期：2026-06-17

核心更新：

- 新增前线模型：`FrontLine`、`FrontSegment`、`RegionFrontState`、`FrontLineState`。
- 新增 `FrontLineManager`，支持 turn rebuild 与 event-driven dirty update。
- 建立 `enemyNeighborCache`，简化包围识别。
- 单战区面对多敌战区时，仍暴露一条主 `FrontLine` 给 AI/UI 聚合使用。
- `GameState` 增加 `frontLineState` 并兼容旧存档 empty。
- `DataLoader` 初始加载 Region/Theater 后生成 FrontLine。

关键系统：

- `Core/FrontLine.swift`
- `Core/FrontSegment.swift`
- `Core/RegionFrontState.swift`
- `Core/FrontLineState.swift`
- `Rules/FrontLineManager.swift`
- `Tests/FrontLineCreationTests.swift`
- `Tests/FrontLineUpdateTests.swift`
- `Tests/MultiEnemyFrontTests.swift`

验证记录：

- v0.32 专项测试：9 tests, 0 failures。
- 全量测试：155 tests, 0 failures。
- `project.pbxproj` lint 通过。

备注：

- v0.32 未改 UI、SpriteKit、AI agent、LLM、命令系统、RegionGraph 或 TheaterSystem 结构。

## v0.33 - WarDeployment 部署层

完成日期：2026-06-17

核心更新：

- 新增 `FrontZone`、`FrontZoneSegment`、`WarDeploymentState` 与 `WarDeploymentManager`。
- 从 v0.31 Theater 生成 v0.33 `FrontZone`。
- 建立 region 粒度前线 segment 与 `FRONT / DEPTH / GARRISON` 三层单位池。
- 支持推进、崩溃、战区消亡与事件更新。
- dirty region + neighbor zone 局部重建，避免每次全图前线扫描。
- 新增前线、segment、部署、战争演化和局部更新性能测试。

关键系统：

- `Core/FrontZone.swift`
- `Core/FrontZoneSegment.swift`
- `Core/WarDeploymentState.swift`
- `Core/WarDeploymentTypes.swift`
- `Rules/WarDeploymentManager.swift`
- `Tests/WarDeploymentFrontLineTests.swift`
- `Tests/WarDeploymentSegmentTests.swift`
- `Tests/WarDeploymentDeploymentTests.swift`
- `Tests/WarEvolutionTests.swift`

验证记录：

- v0.33 选定测试：13 tests, 0 failures。
- 全量测试：168 tests, 0 failures。
- `plutil -lint` 通过。

备注：

- v0.33 未改 UI/SpriteKit、AI/LLM/命令系统，也未引入复杂路径搜索。

## v0.331 - v0.31 至 v0.33 总测试

完成日期：2026-06-18

核心更新：

- 对 v0.31 战区、v0.32 前线、v0.33 部署进行阶段集成测试。
- 清理和巩固测试 fixture，使战区、前线、部署三层能稳定共同回归。
- 优化探针检测，准备后续地图编辑器和战争命令系统接入。

关键系统：

- `Tests/TheaterSystemTests.swift`
- `Tests/FrontLine*Tests.swift`
- `Tests/WarDeployment*Tests.swift`
- `Tests/Stage035CampaignSimulationTests.swift`

备注：

- 本阶段主要是集成验收和测试基线整理，不是新玩法版本。

## v0.34 - 地图编辑器

完成日期：2026-06-18 至 2026-06-19

核心更新：

- 在 `MapEditor/` 下加入项目专属地图编辑器骨架。
- 使用 SwiftUI 管理工具面板，SpriteKit 管理六角格交互视口。
- 编辑器直接导出项目自有 `ScenarioDefinition` 与 `RegionDataSet` JSON，不再引入 Tiled 中间件。
- 新增 macOS 独立 target `MapEditorMac`。
- 支持地块、省份、战区、初始部队编辑。
- `DataLoader` 增加任意文件名加载入口和 MapEditor 输出专用加载路径。
- 地形补充 `hill`，并同步 `terrain_rules.json`、颜色和 inspector 显示。

关键系统：

- `MapEditor/MapEditorDocument.swift`
- `MapEditor/MapEditorHexMath.swift`
- `MapEditor/MapEditorExporter.swift`
- `MapEditor/MapEditorViewModel.swift`
- `MapEditor/MapEditorCanvasScene.swift`
- `MapEditor/MapEditorView.swift`
- `MapEditor/MapEditorMacApp.swift`
- `MapEditor/MapEditorGameResourceBridge.swift`
- `Tests/MapEditorOutputTests.swift`

验证记录：

- `MapEditorOutputTests` 覆盖编辑器输出到 `GameState` 的集成链路。

## v0.341 - macOS 独立编辑器

完成日期：2026-06-18

核心更新：

- 新增 `MapEditorMac` target，作为独立 macOS app 运行。
- 默认窗口适配宽屏/全屏地图编辑。
- 左侧 SwiftUI split panel 管理地图、模式、参数、文件操作。
- 右侧 SpriteKit canvas 渲染六角格。
- 支持鼠标拖拽连续涂色、滚轮/触控板缩放、右键/中键/Option+左键平移。
- 默认工作流读写 `WWIIHexV0/Data/ardennes_v0_scenario.json` 与 `ardennes_v02_regions.json`。

备注：

- MapEditor 不接入 iOS 主入口，避免污染游戏 app 启动流程。

## v0.342 - 地图编辑器中文化与显式编辑流

完成日期：2026-06-18

核心更新：

- 地图编辑器左侧面板改为中文。
- 模式拆成：地块、省份、战区、部队。
- 各模式采用统一 `添加 / 删除 / 完成 / 取消` 显式编辑会话。
- 切换模式会取消当前编辑会话，避免误操作。
- 分层显示只突出当前模式相关数据。
- `MapEditorOutputTests.testEditorSessionActionsReflectInGameState` 覆盖地块、省份、战区、部队完整编辑与导出读取。

## v0.343 - 地图编辑器视口稳定、稀疏扩图与快捷键

完成日期：2026-06-18

核心更新：

- 平移改用 view-space 指针增量，避免 camera 移动导致拖动抖动。
- 滚轮/触控板缩放以鼠标所在 scene point 为锚点，减少视口漂移。
- `MapEditorDocument.contains(_:)` 改为判断实际存在 hex，支持稀疏地图。
- 地块模式新增扩展地块动作，允许在已有 hex 邻位生成新 hex。
- 删除 hex 会清理该 hex 上的初始部队，并移除空 region/theater assignment。
- region/theater 名称由 UI 输入，内部 ID 自动递增。
- 新增快捷键：`N` 添加，`M` 完成。

验证记录：

- `MapEditorOutputTests` 扩展覆盖自动 ID、邻接扩展、虚空造地失败、删除清理、平移/缩放数学。

## v0.344 - 地图编辑器交互修复、信息面板与底图层

完成日期：2026-06-19

核心更新：

- macOS 画布改用 `NSViewRepresentable + SKView`，直接接收 `keyDown`。
- 修复 SpriteKit 抢焦点后 SwiftUI `Button.keyboardShortcut` 不稳定的问题。
- 滚轮缩放与水平/Shift 滚轮平移接入 `SKView.scrollWheel`。
- 右键短按选择 hex，并在左侧信息面板展示/编辑坐标、地形、道路、region、theater 信息。
- Region/Theater 颜色改用固定高对比色板按 ID hash 取色。
- 新增编辑器底图层：导入图片、设置透明度、缩放和位置；底图不写入游戏 JSON。

验证记录：

- `MapEditorOutputTests` 扩展覆盖快捷键、右键信息选择、名称保存、底图文档状态与移动增量。

## v0.351 - 初步战争命令系统

完成日期：2026-06-19

核心更新：

- 新增战争指令协议：`DirectiveEnvelope` / `ZoneDirective`。
- 新增 `WarCommandExecutor`，将 zone 级 attack/defend 意图翻译为底层 `Command`。
- 新增 `MockAICommander`，按兵力比阈值输出 attack/defend。
- AI 指令与玩家命令最终都走 `RuleEngine` / `CommandValidator` 校验执行。
- 为后续 LLM 输出 JSON 指令预留协议层。

关键系统：

- `Commands/WarDirective.swift`
- `Commands/WarCommandExecutor.swift`
- `Agents/MockAICommander.swift`
- `Core/WarDirectiveRecord.swift`
- `Tests/CommandSystemTests.swift`

备注：

- v0.351 只是初级战争命令，不做复杂战术、撤退命令、装甲差异化或真实 LLM。

## v0.352 - 新管线唯一化、观察者模式与分层 UI

完成日期：2026-06-19

核心更新：

- 新增/强化 `WarPipelineMode.zoneDirective`，默认战争 AI 走新 ZoneDirective 管线。
- Legacy Agent D 保留但不作为默认战争 AI 主路径。
- 引入观察者模式，支持双方由 AI 自动对战，但回合推进仍受玩家操作控制。
- 新增 `WarDirectiveRecord`，记录 directive、结果、诊断和 UI 回放信息。
- UI 支持 hex/province/theater/frontLine 等图层切换。
- `MockAICommander` attack 阈值从 1.5 调整到 1.2，使战局更容易推进。

关键系统：

- `Core/WarPipelineMode.swift`
- `Turn/TurnManager.swift`
- `App/AppContainer.swift`
- `Core/WarDirectiveRecord.swift`
- `Core/MapDisplayLayer.swift`
- `SpriteKit/MapLayerOverlayNode.swift`
- `SpriteKit/MapLayerOverlayCalculator.swift`

## v0.353 - 默认地图验收与归属权威重构

完成日期：2026-06-19

核心更新：

- 默认地图接入真实战局模拟验收。
- 确立 hex controller 为归属权威。
- region controller、theater 控制比例、补给站归属改为从 hex controller 派生。
- 避免继续依赖静态阵营标签判断动态占领结果。
- 观察者模式下新地图可用于战争模拟和回归测试。

关键系统：

- `Rules/OccupationRules.swift`
- `Rules/StrategicStateSynchronizer.swift`
- `Rules/TheaterSystem.swift`
- `Rules/RegionOccupationRules.swift`
- `Tests/ObserverModeIntegrationTests.swift`
- `Tests/Stage035CampaignSimulationTests.swift`

备注：

- 本阶段是后续 v0.354/v0.355 修复“AI 不动、联动不及时、占领不对称”的地基。

## v0.354 - 联动修复、拒绝率治理与玩家/AI 对称性

完成日期：2026-06-19 至 2026-06-20

核心更新：

- 修复占领后 region、theater、frontline、visibility 不在同一回合联动的问题。
- 修复 ZOC 友军穿越误判，避免友军互相阻挡。
- 定位“德军若干回合后不动”的真实病灶：推进过深的部队被部署层误判为 garrison，从前线兵力池消失。
- 统一玩家与 AI 的占领判定入口，避免 AI 能占玩家地、玩家不能占 AI 地的不对称。
- 改善 RuleEngine 拒绝率诊断，避免非法命令被静默吞掉。

关键系统：

- `Rules/OccupationRules.swift`
- `Rules/StrategicStateSynchronizer.swift`
- `Rules/WarDeploymentManager.swift`
- `Rules/CommandValidator.swift`
- `Commands/WarCommandExecutor.swift`
- `Tests/WarEvolutionTests.swift`
- `Tests/ObserverModeIntegrationTests.swift`

备注：

- v0.354 期间有多轮 debug 与修复提交，包括 `v0.354 优化1`、`v0.354修复`、`0.354debug`。

## v0.355 - 动态/初始战区分离、前线 UI 与观察者收尾

完成日期：2026-06-20 至 2026-06-23

核心更新：

- 正式分离 `TheaterState.initialSnapshot` 与运行时动态战区状态。
- 修复战区阵营身份不能从动态控制比例反推的问题。
- 图层拆分为 `hex`、`province`、`initialTheater`、`dynamicTheater`、`frontLine`。
- 前线 overlay 改为按 `FrontSegment` 连线绘制。
- 观察者模式开关接入主界面 UI。
- 执行 20 回合观察者模式模拟与阶段分析，记录 directive、拒绝原因、省份换手和补给/包围趋势。

关键系统：

- `Core/Theater.swift`
- `Core/MapDisplayLayer.swift`
- `SpriteKit/MapLayerOverlayNode.swift`
- `SpriteKit/MapLayerOverlayCalculator.swift`
- `UI/RootGameView.swift`
- `Tests/Stage035CampaignSimulationTests.swift`
- `Tests/Stage0355DynamicTheaterTests.swift`

验证记录：

- 历史记录显示 v0.355 阶段曾达到 Probe 9/0、Smoke 4/0、Stage Regression 63/0、Full 198/0。
- 20 回合观察者模拟：57 条 directive，拒绝率约 10%，主要拒绝原因为移动力不足与无路径。

备注：

- 文档 `0.355-迄今概览.md` 记录该阶段架构总结与后续注意事项。

## v0.356 - 默认资源一致性与前线 UI 修正

完成日期：2026-06-24

核心更新：

- DEBUG 下 `DataLoader` 优先读取源码 `WWIIHexV0/Data/*.json`，避免编辑器覆盖保存后游戏仍读取旧 bundle 资源。
- 新增默认资源一致性测试，确保编辑器 document、导出 JSON、游戏加载后的 `hexToRegion`、`regionToTheater`、`tile.regionId`、`region.name` 一致。
- 前线 UI 改为在我方动态战区侧绘制，用 `segment.regionA` 内接敌 hex 的中心点连线。
- 不同 theater 前线使用固定不同基色。
- 每个 segment 单独绘制，并在 segment 起点加分隔符，避免被看成一整条红线。

验证记录：

- 定向 MapEditorOutputTests + Stage0355DynamicTheaterTests：10 tests, 0 failures。
- Probe：9 tests, 0 failures。
- Smoke：4 tests, 0 failures。
- Full regression：200 tests, 0 failures。
- `git diff --check` 通过。

备注：

- 如果模拟器中仍运行旧 app 进程，需要重新运行 app 才会读到 DEBUG 源码 JSON。

## v0.357 - 地图视角、开局单位与前线 UI 修正

完成日期：2026-06-24

核心更新：

- 修复地图编辑器与游戏内视角上下颠倒/不一致问题。
- 修复部队初始部署异常与跨阵营战区问题。
- 修正开局不应立即让 AI 自动行动的行为，开局应先显示真实初始部队状态。
- 继续优化前线 UI，使动态战区、segment 与视觉表达一致。

关键系统：

- `MapEditor/*`
- `Data/DataLoader.swift`
- `App/AppContainer.swift`
- `SpriteKit/MapLayerOverlayNode.swift`
- `Tests/Stage0355DynamicTheaterTests.swift`

## v0.358 - 动态 hex 战区语义收口

完成日期：2026-06-24

核心更新：

- 确认核心语义：`regionToTheater` 是初始/基础战区映射，`hexToTheater` 是运行时动态战区权威。
- 单位占领一个 hex 只推进该 hex 的动态战区归属，不能把整个 region 拖入进攻方 theater。
- 部署层同步引入/强化 `hexToFrontZone`，避免 region 粒度误判 FRONT/DEPTH/GARRISON。
- 前线改按动态 hex 邻接生成，测试 fixture 必须构造真实相邻 hex，不能只声明 region 邻接。
- AI target、WarDeployment、overlay、probe 和 stage tests 同步适配动态 hex 语义。

关键系统：

- `Core/Theater.swift`
- `Core/WarDeploymentState.swift`
- `Rules/TheaterSystem.swift`
- `Rules/FrontLineManager.swift`
- `Rules/WarDeploymentManager.swift`
- `Tests/Stage0355DynamicTheaterTests.swift`
- `Probes/WWIIHexV0ProbeTests.swift`

备注：

- 这是 v0.3 主线的重要铁律：运行时动态战区跟 hex 走，不跟 region 走。

## v0.359 - 前线 UI 优化

完成日期：2026-06-25

核心更新：

- 继续优化前线 overlay 的可读性。
- 强化不同战区/不同 segment 的视觉区分。
- 保留 encirclement/collapsing 等警示状态的红色与加粗表达。
- 使前线 UI 更接近真实动态战区接触，而不是静态 region/theater 边界。

关键系统：

- `SpriteKit/MapLayerOverlayNode.swift`
- `SpriteKit/MapLayerOverlayCalculator.swift`
- `UI/RootGameView.swift`

## v0.3510 - 颜色优化

完成日期：2026-06-25

核心更新：

- 优化地图分层 UI 的颜色表达。
- 强化 province、initialTheater、dynamicTheater、frontLine 等 layer 的辨识度。
- 避免相邻 region/theater 颜色过近导致误判。

关键系统：

- `SpriteKit/TerrainStyle.swift`
- `SpriteKit/MapLayerOverlayNode.swift`
- `SpriteKit/MapLayerOverlayCalculator.swift`

备注：

- 该版本号沿用提交历史中的 `v0.3510`，语义上属于 v0.35x UI 收尾序列，不是 v0.351 的子补丁。

## v0.3511 - UI 修复优化

完成日期：2026-06-25

核心更新：

- 继续修复和优化主游戏 UI。
- 配合 v0.359/v0.3510 的颜色和前线显示调整，改善可读性。
- 为 v0.36 命令层扩展前的界面状态收口。

关键系统：

- `UI/*`
- `SpriteKit/*`

备注：

- 该版本号同样来自提交历史，属于 v0.35x 收尾序列。

## v0.36 - 命令层扩展与多将领 MockAI

完成日期：2026-06-25

核心更新：

- `ZoneDirective` 扩展 `CommandCategory`、`TacticName`、`DirectiveTarget`。
- 新增 `ZoneCommanderAgent`，每个动态战区可由独立将领 agent 生成 directive。
- 新增 `BinaryTacticClassifier`，在 `standardAttack` 与 `holdPosition` 之间做初步分类。
- 新增 `TheaterCommanderPool`，为动态战区提供将领配置，未知新战区使用 fallback commander。
- `WarDirectiveRecord` 增加 category、tactic、commanderAgentId、commandTarget 等字段，便于回放和审计。
- `MockAICommander` 转为兼容 facade，不作为未来扩展主入口。
- 修复旧测试 fixture，使其符合 v0.358 动态 hex 邻接语义。

关键系统：

- `Commands/WarDirective.swift`
- `Commands/WarCommandExecutor.swift`
- `Core/WarDirectiveRecord.swift`
- `Agents/ZoneCommanderAgent.swift`
- `Agents/MockAICommander.swift`
- `Turn/TurnManager.swift`
- `App/AppContainer.swift`
- `Tests/CommandSystemTests.swift`
- `Probes/WWIIHexV0ProbeTests.swift`

验证记录：

- Probe：17 tests, 0 failures。
- Stage Regression：63 tests, 0 failures。
- Full Regression：213 tests, 0 failures。
- 静态检查：`plutil`、`xmllint`、`jq`、`git diff --check` 通过。

备注：

- `AttackIntensity` 字段仍存在，但没有实际分流执行逻辑。
- 战区互助接口仍无调用方。
- 真 LLM 尚未接入。

## v0.37 - 命令层统一整合

完成日期：2026-06-27

核心更新：

- 默认战争 AI 路径收口为：

```text
TheaterCommanderPool -> ZoneCommanderAgent -> ZoneDirective -> WarCommandExecutor -> RuleEngine -> WarDirectiveRecord
```

- 移除 `TurnManager` 中 `MockAICommander` fallback，避免默认路径语义模糊。
- `.zoneDirective` 分支只通过显式 `commanderPool` 或 `TheaterCommanderPool.automatic(for:)` 产生 envelope。
- Legacy Agent D 只在显式 `.legacyAgentOrder` 或测试回归中使用。
- 保留 `MockAICommander` 作兼容/阈值行为测试用途，但不再作为 `TurnManager` 默认备用入口。
- 确认 `WarCommandExecutor.execute(_ directive:in:)` 不依赖具体 `ZoneCommanderAgent` 实例，手写合法 `ZoneDirective` 可直接执行。
- 新增 v0.37 手写 directive 探针，为 v0.4 玩家 UI 共用命令管线预留后端能力。
- 决定将撤退命令、突破/闪电战、装甲差异化、`AttackIntensity` 实际分流推迟到 1.x。

关键系统：

- `Turn/TurnManager.swift`
- `Commands/WarCommandExecutor.swift`
- `Commands/WarDirective.swift`
- `Agents/ZoneCommanderAgent.swift`
- `Agents/MockAICommander.swift`
- `Core/WarDirectiveRecord.swift`
- `Tests/CommandSystemTests.swift`
- `Probes/WWIIHexV0ProbeTests.swift`

验证记录：

- Probe：18 tests, 0 failures。
- CommandSystemTests：15 tests, 0 failures。
- Stage Regression：69 tests, 0 failures。
- Full Regression：226 tests, 0 failures。

备注：

- v0.37 是命令层地基工程，不新增玩法机制。
- v0.4 可以在此基础上接玩家聊天/命令 UI，但必须继续共用 `ZoneDirective -> WarCommandExecutor -> RuleEngine`。

## v0.5 - 元帅层、模拟 LLM JSON 与决策链规范化

完成日期：2026-07-04

目标分支：`v0.5-marshal-decision-chain`

分支审计：本轮开始时创建并切换过该分支；后续轻量审计中当前 checkout 先后显示为 `v0.9-ruler-diplomacy`、`v0.4-generals-command-ui-resume`、`v1.1-macos-main-game`、`v1.0-ui-ai-playtest` 等非 v0.5 分支，且工作树已有多批其他版本未提交改动。用户同意切换后，当前 checkout 已确认回到 `v0.5-marshal-decision-chain`；合并前仍必须审查 dirty worktree 中非 v0.5 文件归属和文件级冲突。

核心更新：

- 新增元帅层 `MarshalAgent`，在战区将军上游读取降维战场摘要并产出战役级意图。
- 默认战争 AI 管线升级为：

```text
MarshalAgent
  -> MarshalBattlefieldSummarizer
  -> SimulatedMarshalLLMClient
  -> TheaterDirectiveDecoder
  -> TheaterDirectiveCompiler
  -> ZoneDirective
  -> WarCommandExecutor
  -> RuleEngine
```

- 新增 `TheaterDirectiveEnvelope` / `TheaterDirective` 作为 v0.5 LLM-facing JSON schema。
- 新增 `TheaterDirectiveDecoder`，支持 fenced JSON 提取、`JSONDecoder` 解码、schemaVersion / issuer / turn / faction / zone / region / tactic-category 校验。
- 新增 `SimulatedMarshalLLMClient`，只模拟 LLM 接口和 JSON 输出，不接真实网络、本地模型或云端 API。
- 新增 `TheaterDirectiveCompiler`，把元帅意图降级为现有 `ZoneDirective`；缺失或失败时 fallback 到 `TheaterCommanderPool`。
- `WarPipelineMode` 新增 `.marshalDirective`，`AppContainer` 和 `TurnManager` 默认使用该模式；旧 `.zoneDirective` 和 `.legacyAgentOrder` 仍保留为显式路径。
- `TurnManager` 抽出公共 `executeDirectiveEnvelope`，确保元帅链路和旧将军池链路共享同一执行、记录和 endTurn 逻辑。
- v0.5 收口时移除 v0.9 旁支曾插入的 `RulerAgent` 塑形调用；当前 `.marshalDirective` 与显式 `.zoneDirective` 都不写统治者记录，统治者仅作为后续上游预留。
- 新增实现记录文档，详细写明本分支算法、边界、fallback 和轻量验证。

关键系统：

- `WWIIHexV0/Commands/WarDirective.swift`
- `WWIIHexV0/Agents/ZoneCommanderAgent.swift`
- `WWIIHexV0/Turn/TurnManager.swift`
- `WWIIHexV0/Core/WarPipelineMode.swift`
- `WWIIHexV0/App/AppContainer.swift`
- `md/prompt/anti生成/v0.5/anti/0.50_v0.5_marshal_implementation_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `README.md`

验证记录：

- `git rev-parse --abbrev-ref HEAD`：`v0.5-marshal-decision-chain`。
- 轻量单文件语法检查通过：
  - `swiftc -parse WWIIHexV0/Commands/WarDirective.swift`
  - `swiftc -parse WWIIHexV0/Agents/ZoneCommanderAgent.swift`
  - `swiftc -parse WWIIHexV0/Turn/TurnManager.swift`
  - `swiftc -parse WWIIHexV0/App/AppContainer.swift`
  - `swiftc -parse WWIIHexV0/Core/WarPipelineMode.swift`
- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj`：OK。
- `jq empty` 已通过：
  - `WWIIHexV0/Data/ardennes_v02_regions.json`
  - `WWIIHexV0/Data/general_agents.json`
  - `WWIIHexV0/Data/generals.json`
  - `WWIIHexV0/Data/terrain_rules.json`
  - `WWIIHexV0/Data/unit_templates.json`
- 文档尾随空白扫描：无命中。
- 旧默认测试口径扫描（`AGENTS.md`、`md/flow/flow.md`）：无命中。
- Cabinet/Minister 旧污染源码扫描：无命中。
- v0.5 当前文档与 `TurnManager` 的 `RulerAgent` 默认接入残留扫描：无命中。
- `git diff --check`：通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前 `AGENTS.md` 与 `md/test/test.md` 规定默认只做轻量检查，且本轮用户明确禁止跑 Xcode。

备注：

- 本轮没有恢复历史回退的 `CabinetState`、`DirectiveBoard`、`MinisterDecisionProvider`、`RulerDirectiveFactory`、`national_cabinet.json` 或部长系统。
- 统治者层仅作为未来元帅上游预留方向，不在 v0.5 当前实现中落地。
- 当前工作树还存在不属于本 v0.5 核心目标的高级战术、外交、经济、UI 和地图编辑器方向未提交改动；v0.5 实现选择兼容现有工作树，不回滚其他改动。

## v0.8 - 初级经济、生产、城市、地形与补兵

完成日期：2026-07-04

目标分支：`codex/v0.8-economy-production`

分支审计：本轮早期创建 v0.8 分支曾因 `.git` 写入权限受限失败；期间当前 checkout 先后观察到其他版本分支，且工作树已有多批其他版本未提交改动。最终已通过受控审批成功创建 `codex/v0.8-economy-production`，但创建后仍观察到外部 checkout 漂移。因此本记录描述当前工作树中的 v0.8 经济系统实现，合并前必须重新确认当前分支、分支基点、文件级冲突、public API 冲突和 Xcode project 引用。

核心更新：

- 新增 `EconomyState`，建立 faction 级 manpower、industry、supplies 总账、生产队列、上回合收入/维护费/补员消耗。
- 新增 `EconomyRules`，从真实己方 hex 控制证据、region 城市、工厂、基础设施和补给值聚合收入。
- `GameState` 增加 `economyState`，旧存档缺失时 fallback `.empty`。
- `StrategicStateBootstrapper` 与 `RuleEngine` 在需要时 bootstrap 经济总账，保证旧状态第一次执行命令也有经济账本。
- `Command` 新增 `queueProduction(kind:)`，经 `CommandValidator` 检查 phase 和资源，经 `CommandExecutor` 调 `EconomyRules.queueProduction` 预付成本并入队。
- `CommandExecutor.executeEndTurn` 增加 active faction 经济结算：收入、战略补给维护费、短缺降级、自动补兵、生产队列推进和完成部署。
- 自动补兵只处理本阵营、未毁灭、未撤退、supplied、非敌邻、strength 未满的单位，每回合每单位最多恢复 2 strength，按兵种权重扣资源。
- 生产完成单位只能部署到本方控制、passable、空置、非敌邻，且位于首都、城镇/大都会、工厂、高基建、高补给 region 或 supply source 的后方 hex；找不到安全部署点时订单保留。
- `BaseTerrain`、`MovementRules`、`CombatRules` 增加地形加成：装甲进困难地形额外移动成本，装甲攻击平原加成，攻击困难地形惩罚，步兵在森林/城市/堡垒防御加成。
- 新增 `EconomyPanelView`，`RootGameView` 接入 Economy tab，`HUDView` 展示经济摘要，Region inspector 展示城市等级和经济产出。
- `project.pbxproj` 当前已有 `EconomyState.swift`、`EconomyRules.swift`、`EconomyPanelView.swift` 引用，未新增重复 UUID。
- 新增 v0.8 实现记录，详细写明规则算法、接入点、非目标、轻量检查和风险。

关键系统：

- `WWIIHexV0/Core/EconomyState.swift`
- `WWIIHexV0/Rules/EconomyRules.swift`
- `WWIIHexV0/Core/GameState.swift`
- `WWIIHexV0/Core/StrategicStateBootstrapper.swift`
- `WWIIHexV0/Commands/Command.swift`
- `WWIIHexV0/Rules/CommandValidator.swift`
- `WWIIHexV0/Rules/CommandExecutor.swift`
- `WWIIHexV0/Rules/RuleEngine.swift`
- `WWIIHexV0/Core/Terrain.swift`
- `WWIIHexV0/Rules/MovementRules.swift`
- `WWIIHexV0/Rules/CombatRules.swift`
- `WWIIHexV0/UI/EconomyPanelView.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `WWIIHexV0/UI/HUDView.swift`
- `WWIIHexV0/SpriteKit/MapDisplayAdapter.swift`
- `WWIIHexV0/UI/RegionInspectorView.swift`
- `md/prompt/anti生成/v0.8/anti/0.80_v0.8_economy_implementation_record.md`
- `md/prompt/anti生成/v0.8/anti/0.80_overall_analysis_report.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`

验证记录：

- 轻量 Swift parse 通过：
  - 核心规则集合，含 `EconomyState.swift`、`EconomyRules.swift`、`GameState.swift`、`Command.swift`、`CommandValidator.swift`、`CommandExecutor.swift`、`RuleEngine.swift`、`StrategicStateBootstrapper.swift`、`MovementRules.swift`、`CombatRules.swift` 等。
  - 核心规则集合 + `PlatformStyles.swift` + `EconomyPanelView.swift`。
  - 核心规则集合 + `MapDisplayAdapter.swift` + `PlatformStyles.swift` + `EconomyPanelView.swift` + `HUDView.swift` + `RegionInspectorView.swift`。
- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj`：通过。
- `jq empty WWIIHexV0/Data/ardennes_v02_regions.json`：通过。
- 改动文档尾随空白检查：通过。
- 旧默认测试口径残留检查：通过。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full / 性能测试；原因是当前规范和用户要求均禁止本轮主动跑 Xcode 与重测试。

备注：

- v0.8 不接真实 LLM 经济部长、不做完整商品价格网、不恢复 organization、不做空军/海军/战略轰炸/工厂损毁。
- `RegionDataSet.toRegions()` 仍有历史 fallback：owner/controller 缺失最终落到 `.allies`。v0.8 经济收入已加真实 hex 控制守卫，但数据层中立语义建议后续单独修。
- 当前 AI 不会主动排产；规则层已支持 active faction 通过统一 `Command` 排产，AI 经济策略留后续版本。

## v1.0 - UI / AI / 初版试玩收口

完成日期：2026-07-04

分支：`v1.0-ui-ai-playtest`

分支审计：续接收尾时当前 checkout 曾显示为 `v1.1-macos-main-game`，切回 `v1.0-ui-ai-playtest` 后又在轻量检查期间漂到 `v0.9-ruler-diplomacy` 和 `v0.5-marshal-decision-chain`。`v1.0-ui-ai-playtest` 分支已存在且与当前基线一致；交付前最后一次即时核对显示当前分支为 `v1.0-ui-ai-playtest`。由于当前工作树存在外部 checkout 漂移风险，合并前必须重新做分支与冲突审查。

核心更新：

- 创建并切换到 1.0 分支，围绕主游戏 UI、MockAI 行为、轻量性能和试玩记录做收口。
- `AgentPanelView` 接入 `WarDirectiveRecord`，AI tab 现在展示 zone、directive type、tactic、成功/拒绝命令数、目标 region 和 diagnostics。
- `EventLogView` 改为 `LogDisplayEntry` 展示模型，最近 60 条日志每条只计算一次分类，并补充 diplomacy 日志分类。
- `BoardScene.drawUnits` 缓存单位显示 hex 后排序，部署图层复用同一个 `WarDeploymentManager` 计算 role。
- `WarCommandExecutor` 开始解释 `AttackIntensity.infiltration`，无显式投入上限时限制默认投入单位数；佯攻/袭扰保留低投入策略。
- `PlatformStyles` 补充跨平台面板样式；Economy / Diplomacy 面板收口到跨平台背景和更可读字号。
- 新增 1.0 分支实现记录，写明 UI、性能、MockAI、试玩观察点、风险和未跑重测试原因。

关键系统：

- `WWIIHexV0/UI/PlatformStyles.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `WWIIHexV0/UI/AgentPanelView.swift`
- `WWIIHexV0/UI/EventLogView.swift`
- `WWIIHexV0/UI/EconomyPanelView.swift`
- `WWIIHexV0/UI/DiplomacyPanelView.swift`
- `WWIIHexV0/SpriteKit/BoardScene.swift`
- `WWIIHexV0/Commands/WarCommandExecutor.swift`
- `md/prompt/anti生成/v1.0/anti/1.00_v1.0_ui_ai_playtest_implementation_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`

验证记录：

- `git branch --show-current`：切回后曾返回 `v1.0-ui-ai-playtest`，但后续轻量检查期间又返回 `v0.9-ruler-diplomacy` 和 `v0.5-marshal-decision-chain`；分支漂移未完全消除。
- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj`：OK。
- `jq empty WWIIHexV0/Data/ardennes_v02_regions.json`：通过，无输出。
- `jq empty WWIIHexV0/Data/generals.json`：通过，无输出。
- `git diff --check`：通过，无输出。
- `rg -n "[[:blank:]]+$" AGENTS.md README.md update_log.md md/test/test.md md/flow/flow.md md/flow/flowchart.md md/prompt/anti生成/v1.0/anti/1.00_v1.0_ui_ai_playtest_implementation_record.md`：无命中。
- `rg -n "默认先跑|默认 Probe|Probe -> Smoke|Stage Regression -> Full|代码改动按 .*Probe" AGENTS.md md/flow/flow.md`：无命中。
- 冲突标记扫描（AGENTS.md、README.md、update_log.md、md/flow、WWIIHexV0、MapEditor）：无命中。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full / 性能测试；原因是 `AGENTS.md`、`md/test/test.md` 和用户要求均禁止本轮主动跑重测试。

备注：

- 本轮并发子 agent 中 UI 只读定位完成，AI / 性能子 agent 因外部 503 失败，主线程接回实现。
- 当前工作树仍含 v0.5 / v0.7 / v1.1 等方向未提交改动，合并前必须做文件级、public API、schema、Xcode project 和文档口径冲突审查。

## v0.9 - 统治者、多国家、阵营集团与初步外交状态

完成日期：2026-07-04

分支：`v0.9-ruler-diplomacy`

核心更新：

- 新增 `DiplomacyState`，在 `GameState` 中保存国家、阵营集团、国家间外交关系和统治者决策记录。
- 新增 `CountryProfile`、`DiplomaticBloc`、`DiplomaticRelation`、`DiplomaticStatus`、`RulerStrategicPosture`、`RulerDecisionRecord` 等数据结构。
- 开局外交种子：
  - Germany 规则阵营：`German Reich`，`Axis`，`ruler_germany`。
  - Allies 规则阵营：`United States`、`United Kingdom`、`Belgium`，`Allied Coalition`，主统治者 `ruler_allies`。
  - 同阵营关系为 `allied`，跨阵营关系为 `atWar`。
- 新增 `RulerAgent`：读取外交、前线、部署、历史战争指令记录，生成 `RulerStrategicSnapshot`，选择 `offensive` / `defensive` / `coalitionMaintenance` / `stabilizeFront` 姿态。
- `RulerAgent` 只塑形 `DirectiveEnvelope`：
  - offensive：攻击强度提升为 `allOut`，按 region priority 重排目标。
  - defensive：攻击 directive 转为 `holdLine` 防御 directive。
  - coalitionMaintenance：提高防御预备队。
  - stabilizeFront：降低 `allOut` 为 `limitedCounter`，或采用 `flexible` 防御。
- `TurnManager` 在 `.marshalDirective` 与显式 `.zoneDirective` 路径中执行 `applyRuler`，写入 `RulerDecisionRecord` 和 `.diplomacy` 日志后，再交给 `WarCommandExecutor -> RuleEngine`。
- `DataLoader` 和 `StrategicStateBootstrapper` 会为新局或旧存档补齐外交状态。
- 新增 `DiplomacyPanelView`，`RootGameView` 增加 `Diplomacy` 面板，`AgentPanelView` 展示最近统治者 posture / focus。
- `GameLogCategory` 新增 `diplomacy`。
- 修复 `RulerStrategicSnapshot` 静态去重调用；修复 `hostileCountryIds(to:)` 在多盟友共享同一敌国时重复计数的问题。
- 新增 v0.9 实现记录，详细写明本分支算法、边界、冲突情况和未跑重测试原因。

关键系统：

- `WWIIHexV0/Core/DiplomacyState.swift`
- `WWIIHexV0/Agents/RulerAgent.swift`
- `WWIIHexV0/Core/GameState.swift`
- `WWIIHexV0/Core/StrategicStateBootstrapper.swift`
- `WWIIHexV0/Data/DataLoader.swift`
- `WWIIHexV0/Core/GameLogEntry.swift`
- `WWIIHexV0/Turn/TurnManager.swift`
- `WWIIHexV0/UI/DiplomacyPanelView.swift`
- `WWIIHexV0/UI/AgentPanelView.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `WWIIHexV0.xcodeproj/project.pbxproj`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `README.md`
- `md/prompt/anti生成/v0.9/anti/0.90_v0.9_ruler_diplomacy_implementation_record.md`

验证记录：

- `git branch --show-current`：`v0.9-ruler-diplomacy`。
- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj`：OK。
- `jq empty WWIIHexV0/Data/ardennes_v02_regions.json`：通过，无输出。
- `jq empty WWIIHexV0/Data/generals.json`：通过，无输出。
- `rg -n "[[:blank:]]+$" AGENTS.md README.md update_log.md md/test/test.md md/flow/flow.md md/flow/flowchart.md md/prompt/anti生成/v0.9/anti/0.90_v0.9_ruler_diplomacy_implementation_record.md`：无命中。
- `rg -n "默认先跑|默认 Probe|Probe -> Smoke|Stage Regression -> Full|代码改动按 .*Probe" AGENTS.md md/flow/flow.md`：无命中。
- 冲突标记扫描（README.md、update_log.md、md/flow、v0.9 实现记录与相关 Swift 文件）：无命中。
- `swiftc -parse WWIIHexV0/Core/DiplomacyState.swift WWIIHexV0/Agents/RulerAgent.swift WWIIHexV0/UI/DiplomacyPanelView.swift`：通过，无输出。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / app 启动 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范与本轮用户要求均禁止主动跑 Xcode 和重测试。

备注：

- 本轮尝试把国家/外交、AI 管线、文档三块拆给子 Agent 并行，但子 Agent 调用返回 503，没有可用产物；最终由主 Agent 在当前分支内完成实现和整合。
- 当前工作树已有 v0.5 元帅层、经济层、v1.1 macOS target、地图编辑器和 UI 等未提交改动；v0.9 选择兼容当前源码，不回滚其他改动。合并前仍需做文件级冲突审查。
- 多国家当前是战略身份层，底层规则阵营仍是 `Faction.germany` / `Faction.allies`。后续若要国家级参战、中立、投降、宣战或外交行动，需要先设计国家级权限和命令入口。

## v1.1 - 主游戏 macOS target

完成日期：2026-07-04

分支：`v1.1-macos-main-game`

核心更新：

- 新增独立主游戏 macOS app target `WWIIHexV0Mac`，区别于既有 iOS 主游戏 target `WWIIHexV0` 和地图编辑器 target `MapEditorMac`。
- 新增 macOS 主入口 `WWIIHexV0MacApp`，复用 `AppContainer.bootstrap()` 与 `RootGameView(container:)`，默认窗口 1440x900，最小内容区域 1200x760。
- `WWIIHexV0Mac` resource phase 接入主游戏默认 JSON：`ardennes_v0_scenario.json`、`ardennes_v02_regions.json`、`general_agents.json`、`generals.json`、`terrain_rules.json`、`unit_templates.json`。
- `BoardSceneView` 增加 macOS `NSViewRepresentable` 分支，用 `BoardEventSKView` 承载 `BoardScene`，iOS 继续使用 `UIViewRepresentable` 分支。
- `BoardScene` 增加 macOS 鼠标点击、拖拽平移、滚轮/触控板缩放；点击仍只回调 `onHexTapped`，后续由 `AppContainer.handleBoardTap -> RuleEngine` 处理。
- 新增 `PlatformStyles`，将主游戏 UI 的 `Color(.systemBackground)` / `Color(.tertiarySystemBackground)` 替换为 iOS/macOS 条件背景色。
- 因当前工作树已有经济、外交、统治者、将领 registry 等源码引用，`project.pbxproj` 同步把这些已被引用的支持文件和 `generals.json` 接入相关 target phase，但本轮不改这些业务逻辑。
- 新增 v1.1 实现记录，详细写明 target 设计、输入桥接算法、资源加载、轻量检查和风险。

关键系统：

- `WWIIHexV0.xcodeproj/project.pbxproj`
- `WWIIHexV0/App/WWIIHexV0MacApp.swift`
- `WWIIHexV0/SpriteKit/BoardScene.swift`
- `WWIIHexV0/SpriteKit/BoardSceneView.swift`
- `WWIIHexV0/UI/PlatformStyles.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `md/prompt/anti生成/v1.1/anti/1.10_v1.1_macos_main_game_implementation_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `README.md`

验证记录：

- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj` 通过。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / macOS app 启动 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前规范与用户要求均禁止本轮主动跑 Xcode 和重测试。

备注：

- v1.1 是平台承载和输入桥接分支，不改变 `Command` / `ZoneDirective` / `WarCommandExecutor` / `RuleEngine` 规则权威链路。
- 当前工作树存在多条其他方向的未提交改动；v1.1 选择兼容当前源码引用并记录风险，不回滚其他人改动。

## v0.7 - 高级战术与命令扩展

完成日期：2026-07-04

目标分支：`v0.7-tactical-upgrade`

分支审计：本轮曾创建并切换到 `v0.7-tactical-upgrade`，但连续接力时当前 checkout 多次显示为其他分支，且工作树已有多批 v0.5 / v1.0 / v1.1 / UI / 经济 / 外交方向未提交改动。按项目规则，本轮未回滚这些改动；合并前必须重新确认分支归属和文件级冲突。

核心更新：

- `TacticName` 扩展为进攻 8 类、防御 4 类：
  - 进攻：`standardAttack`、`blitzkrieg`、`spearhead`、`breakthrough`、`pincerMovement`、`fireCoverage`、`feint`、`guerrillaWarfare`。
  - 防御：`holdPosition`、`elasticDefense`、`defenseInDepth`、`lastStand`。
- `AttackParameters` 新增 `focusRegionId`、`supportRegionIds`、`convergenceRegionId`、`coordinatedZoneIds`、`maxCommittedUnits`、`exploitDepth`，支持定点突破、钳形会师、投入上限和纵深目标意图。
- `DefenseParameters` 新增 `fallbackRegionIds`、`counterattackRegionIds`、`strongpointRegionIds`、`maxFrontCommitment`，支持弹性防御、纵深防御和死守口径。
- `TheaterDirective` 新增 `convergenceRegionId` / `coordinatedZoneIds`，并补自定义 decode，旧 JSON 缺字段时仍兼容。
- `TheaterDirectiveDecoder` 校验 convergence region 和 coordinated zone 存在性，继续校验 tactic/category 一致性。
- `BinaryTacticClassifier` 从二元分类升级为读取兵力比、机动兵力、炮兵支援、纵深预备队、压力和补给警告的战术分类器。
- `TacticConditionChecker` 从恒 true 改为按战术最低条件放行：机动战术要求机动单位，火力覆盖要求炮兵/远程单位，佯攻要求前线单位，纵深防御要求 depth 预备队。
- `WarCommandExecutor` 新增 `AttackTacticProfile`，按战术控制单位来源、机动优先、炮兵优先、只攻击不推进、弱点聚焦、深目标候选、非矛头单位 hold 和投入上限。
- 定点突破弱点评分落地：

```text
enemyStrength 越低越优先
terrain.movementCost 越低越优先
region 内有 road 越优先
city.victoryPoints + supplyValue + factories 越高越优先
guerrillaWarfare 额外参考 infrastructure
```

- `defenseInDepth` 新增独立执行路径：一线 `allowRetreat`，保留预备队，其余 depth 机动单位尝试反击，否则向 fallback / strongpoint 防御地形移动。
- `fireCoverage` 落地为炮兵/远程优先、能打则打、无目标则 hold，不主动推进。
- `feint` 落地为少量前线单位牵制，默认约 1/3 前线投入。
- `blitzkrieg` / `spearhead` 落地为机动优先、集中弱点、可使用 depth 单位，非矛头前线单位 hold。
- `pincerMovement` 落地为 convergence / coordinated 数据层和单 zone 执行器 profile；多 zone 会师由元帅层或人工下发多条 directive，包围效果交给动态战区/前线/补给派生。
- `MockAICommander` 保留新增 attack 参数，避免 allOut 包装时丢失 focus/convergence/coordinated 字段。
- 新增 v0.7 实现记录文档，详细写明算法、边界、冲突风险和轻量检查口径。

关键系统：

- `WWIIHexV0/Commands/WarDirective.swift`
- `WWIIHexV0/Commands/WarCommandExecutor.swift`
- `WWIIHexV0/Agents/ZoneCommanderAgent.swift`
- `WWIIHexV0/Agents/MockAICommander.swift`
- `md/prompt/anti生成/v0.7/anti/0.70_v0.7_tactical_upgrade_implementation_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- `md/flow/03_ai_zone_directive_pipeline.mermaid`
- `README.md`

验证记录：

- 轻量单文件语法检查通过：
  - `swiftc -parse WWIIHexV0/Commands/WarDirective.swift`
  - `swiftc -parse WWIIHexV0/Commands/WarCommandExecutor.swift`
  - `swiftc -parse WWIIHexV0/Agents/ZoneCommanderAgent.swift`
  - `swiftc -parse WWIIHexV0/Agents/MockAICommander.swift`

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前 `AGENTS.md` 与 `md/test/test.md` 规定默认只做轻量检查，且本轮用户明确禁止跑 Xcode。

遗留风险：

- 未做运行时战局验证，战术效果和 AI 行为只通过源码与轻量 parse 检查确认语法层可用。
- 当前工作树混有其他版本改动，合并前必须做文件/API/schema/文档冲突检查。

## v0.4 - 将军养成初步、将军 UI 与玩家双轨命令

完成日期：2026-07-04

目标分支：`v0.4-generals-command-ui-final`

分支审计：本轮从一个已混入 v0.9 / v0.5 / v1.x 外部未提交改动的工作树创建 0.4 续作分支。期间 checkout 又被外部切到 `codex/v0.8-economy-production`，最终已重新固定到 `v0.4-generals-command-ui-final`。按项目规则，本轮没有回滚外部改动；只在当前分支继续补齐 0.4 将军和玩家命令链路。合并前必须重新审查 project、public API、JSON schema 和文档口径冲突。

核心更新：

- 新增实体将军数据链：`generals.json`、`GeneralData`、`GeneralRegistry`、`GeneralDispatcher`。
- `RegionNodeDefinition` / MapEditor region draft 支持 `assignedGeneralId`，默认阿登 region JSON 已给蒙哥马利、魏刚、古德里安、里布写入初始种子。
- `FrontZone` 增加 `generalAssignment`，记录将军 id、HQ region、辖下 division、忠诚、满意度和玩家干预次数。
- `WarDeploymentState.preservingGeneralAssignments` 与 AppContainer 刷新逻辑保留/补齐将军分配，避免部署层重建后将军丢失。
- `TheaterCommanderPool` 在 AppContainer 构造时可由 `GeneralDispatcher.commanderPool` 使用真实将军配置，缺失时仍 fallback 到自动 commander。
- 新增 `PlayerCommandState` 和 `PlayerPlannedOperation`，保存本回合微操锁和玩家战区计划。
- 玩家微操 move/attack/hold/resupply/allowRetreat 成功后锁定该师，降低所属将军满意度并增加干预次数；结束回合或阵营/回合变化时清空锁。
- `WarCommandExecutor.execute` 新增兼容参数 `excluding excludedDivisionIds`，在进攻、防御、纵深防御和非矛头 hold 阶段跳过玩家微操部队。
- `AppContainer` 新增玩家宏观将军命令：`Hold Line` 生成 defense `ZoneDirective`，`Attack Region` 根据当前选中敌方 region 和相邻玩家 FrontZone 生成 attack `ZoneDirective`，执行后不自动结束回合。
- 新增 `GeneralCommandPanelView` 与 `GeneralProfileView`，展示将军头像占位、军衔、风格、技能、履历、忠诚/满意度、HQ 状态、辖下部队和计划操作。
- `RootGameView` 新增 `General` tab，Unit tab 也嵌入将军命令面板。
- `BoardScene` 根据 `PlayerPlannedOperation` 画进攻箭头/防御圆环，`UnitNode` 对本回合玩家微操单位画金色圈。
- `WarDirectiveRecord` 记录玩家宏观指令结果，AI 面板与日志可继续共用同一复盘数据。

关键系统：

- `WWIIHexV0/Data/generals.json`
- `WWIIHexV0/Agents/GeneralRegistry.swift`
- `WWIIHexV0/Core/GeneralAssignment.swift`
- `WWIIHexV0/Core/PlayerCommandState.swift`
- `WWIIHexV0/Core/FrontZone.swift`
- `WWIIHexV0/Core/WarDeploymentState.swift`
- `WWIIHexV0/Data/DataLoader.swift`
- `WWIIHexV0/Data/RegionDataSet.swift`
- `MapEditor/MapEditorDocument.swift`
- `MapEditor/MapEditorExporter.swift`
- `MapEditor/MapEditorGameResourceBridge.swift`
- `WWIIHexV0/App/AppContainer.swift`
- `WWIIHexV0/Commands/WarCommandExecutor.swift`
- `WWIIHexV0/UI/GeneralCommandPanelView.swift`
- `WWIIHexV0/UI/GeneralProfileView.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `WWIIHexV0/SpriteKit/BoardScene.swift`
- `WWIIHexV0/SpriteKit/UnitNode.swift`
- `WWIIHexV0.xcodeproj/project.pbxproj`
- `md/prompt/anti生成/0.4/v0.4_generals_command_ui_branch_record.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`

验证记录：

- `jq empty WWIIHexV0/Data/generals.json` 通过。
- `jq empty WWIIHexV0/Data/ardennes_v02_regions.json` 通过。
- `plutil -lint WWIIHexV0.xcodeproj/project.pbxproj` 通过，输出 `OK`。
- `git diff --check` 通过。
- 文档尾随空白检查无匹配。
- 单文件轻量 parse 通过：`PlayerCommandState.swift`、`GeneralAssignment.swift`、`GeneralRegistry.swift`、`GeneralCommandPanelView.swift`、`GeneralProfileView.swift`、`WarCommandExecutor.swift`、`AppContainer.swift`、`BoardScene.swift`、`UnitNode.swift`、`RootGameView.swift`。

未跑：

- 未跑 Xcode / XCTest / 模拟器 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full；原因是当前 `AGENTS.md`、`md/test/test.md` 和用户要求均禁止本轮主动跑 Xcode 与重测试。

遗留风险：

- 未做运行时 UI 点击和 SpriteKit 视觉验证，按钮行为、sheet 展示、计划线位置仍需后续人工或授权轻量运行确认。
- 当前工作树混有其他版本改动，合并前必须重新做文件/API/schema/project 冲突审查。

## 历史维护记录

以下提交不作为正式 v 版本，但影响项目资料完整性：

- 2026-06-15：重整 `md` 目录，添加 README，补充 v0.1-v1.0 提示词。
- 2026-06-15：打捞 Agent D 与误删代码，恢复 AI 决策管线。
- 2026-06-15：记录 v0.5 擅自编程与回退资料，保留为历史警示；当前主线不得引入 Cabinet/StrategicDirective/Minister 污染。
- 2026-06-18：整理文档结构，将已完成阶段文档迁入 `md/prompt/...（已完成）`。
- 2026-06-24 至 2026-06-25：补充 0.36 提示词、0.355 截止分析、20 回合文档更新。
- 2026-06-27：创建 `AGENT.md`，写入后续 Codex 接手项目时的架构、测试、文档维护和交付规则。
- 2026-07-04：更新当前协作规范：默认禁止 Xcode / XCTest / 模拟器 / 性能类重测试，只做轻量语法/格式检查；新增多版本分支、并发子 Agent 和合并前冲突检查规则。关键文件：`AGENTS.md`、`md/test/test.md`、`md/flow/flow.md`、`README.md`、`md/prompt/v0.f/fable-5-重构优化总提示词.md`。
- 2026-07-04：新增拿破仑战争迁移总提示词，规划 v3.0-v3.8 从 WWIIHexV0 迁移为 AI Agent 驱动拿战游戏的版本路线、最终发布效果、并发子 Agent 分工、轻量检查和风险边界。关键文件：`md/prompt/v3.0-拿战迁移/codex-v3.0-拿战aiagent迁移总提示词.md`。
- 2026-07-04：新增明末迁移总提示词，规划 v4.0-v4.8 从 WWIIHexV0 迁移为 AI Agent 驱动明末历史策略游戏的产品目标、版本路线、最终发布效果、并发子 Agent 分工、轻量检查和风险边界。关键文件：`md/prompt/v4.0-明末迁移/codex-v4.0-明末aiagent迁移总提示词.md`。
- 2026-07-04：新增唐宋迁移总提示词，规划 v5.0-v5.9 从 WWIIHexV0 迁移为 AI Agent 驱动唐宋时代历史策略游戏的首发剧本、产品目标、架构边界、版本路线、并发子 Agent 分工、轻量检查和发布验收标准。关键文件：`md/prompt/v5.0-唐宋迁移/codex-v5.0-唐宋aiagent历史策略迁移总提示词.md`。
- 2026-07-04：新增现代战争迁移总提示词，规划 v6.0-v6.10 从 WWIIHexV0 迁移为 AI Agent 驱动现代联合指挥策略游戏的首发虚构剧本、ISR/EW/火力/无人系统闭环、版本路线、并发子 Agent 分工、轻量检查和发布验收标准。为避免与既有 v5.0 唐宋/维多利亚迁移文档冲突，现代战争路线使用 v6.0 起始版本。关键文件：`md/prompt/v6.0-现代战争迁移/codex-v6.0-现代战争aiagent迁移总提示词.md`。
