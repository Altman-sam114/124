# Codex v3.0-v3.8+ 总提示词：隋末唐初 AI Agent 历史策略迁移与后续迭代

> 本文是交给后续实现 Agent 的总提示词。它不是单轮代码实现记录，而是 v3.0 起的迁移路线、当前交接状态、后续迭代队列、并发边界和验收标准。执行前必须先读 `AGENTS.md`、`update_log.md`、`md/flow/flow.md`、`md/flow/flowchart.md`、`md/test/test.md` 和本文件。不要凭旧记忆、旧 prompt 或题材想象直接改代码。

---

## 0. 当前项目判断

你接手的是 `WWIIHexV0`，当前代码不是早期空壳，而是一个已经有成熟战棋骨架、动态战区、命令管线、地图编辑器、经济草案、外交草案、将领草案、元帅决策链和 macOS 入口方向的 Swift + SwiftUI + SpriteKit 工程。

当前主链路大致是：

```text
MapEditor / JSON 数据
  -> DataLoader
  -> GameState
  -> HexTile.controller + Division.coord
  -> Region 聚合
  -> EconomyState 收入 / 生产 / 补员
  -> Initial Theater snapshot + runtime hexToTheater
  -> FrontLine 动态 hex 接触
  -> WarDeployment hexToFrontZone + FRONT/DEPTH/GARRISON
  -> MarshalAgent / TheaterDirective JSON
  -> TheaterDirectiveDecoder / TheaterDirectiveCompiler
  -> CourtAgent / RulerAgent 朝堂塑形与审计
  -> Governor / Diplomat / Submission handoff 辅助命令候选
  -> ZoneDirective
  -> WarCommandExecutor
  -> RuleEngine
  -> CommandValidator
  -> CommandExecutor
  -> VictoryRules / Wude618VictoryEvaluator
  -> StrategicStateSynchronizer
  -> UI overlay / 日志 / WarDirectiveRecord / CourtDecisionRecord / DiplomacyEventRecord
```

必须尊重这些事实：

- `HexTile.controller` 和 `Division.coord` 是战术层权威。
- `RegionNode.controller` 是从 region 内 hex controller 聚合出来的战略快照。
- `regionToTheater` 是初始/基础战区归属，不是运行时推进层。
- `hexToTheater` 是运行时动态战区权威。
- `hexToFrontZone` 是部署层动态归属权威。
- 玩家、AI、聊天命令和 MockAI 都必须落到 `Command` / `ZoneDirective`，再经 `WarCommandExecutor`、`CommandValidator`、`RuleEngine` 执行。
- 旧 Agent D 保留作回归参考，默认战争 AI 主路径不得退回旧管线。
- 当前源码仍保留 legacy 兼容名和值：`Faction.germany/allies`、`GamePhase.germanAI/alliedPlayer`、`Division`、旧阿登 JSON、部分旧胜负字段和旧测试语义。这些是兼容层，不等于新主路径；玩家可见路径已经过多轮 v3.7-preflight 收口，后续只能按扫描结果小步清理，不得直接删除兼容 rawValue / schema。
- 如果发现当前工作树存在未提交改动、旧草案残留或与 `update_log.md` 不一致的记录，必须先按 `AGENTS.md` 审计来源和范围；不要默认把它们视为当前路线，也不要回滚他人改动。

迁移目标不是换皮，不是把 Germany 改成 Tang、Allies 改成 Sui，而是把现有引擎逐步迁移为一个可发布的 AI Agent 驱动隋末唐初历史策略游戏。

### 0.1 当前交接状态（v3.7-preflight.108）

截至 `update_log.md` 的最新 v 版本记录和顶部当前交接记录，隋唐迁移已经不是 v3.0 初始审计阶段，而是推进到 `v3.7-preflight.108`：

- v3.1 已完成多势力兼容、通用阶段和外交关系入口。
- v3.2 已接入默认 `wude_618_guanzhong_luoyang` 数据，主游戏和 MapEditor 默认桥优先隋唐路径，旧阿登路径仅作 fallback / 回归兼容。
- v3.3 已完成隋唐兵种、粮草/围城最小规则和主要显示迁移。
- v3.4 已接入 `CourtAgent` / `RulerAgent` 朝堂塑形和审计记录；默认战争 AI 不退回旧 Agent D 主路径。
- v3.5 已形成玩家军令、州郡、外交、战报的最小信息闭环。
- v3.6 已接入 `SuitangDesignTokens`、地图最小历史视觉、粮道、围城、前线墨线和 AI 计划箭头。
- v3.7-preflight 已连续补齐胜负、本地存档、引导/设置、外交/州郡命令、AI 太守/使者、归附交接、善后记录、MapEditor 隋唐桥和大量玩家可见 legacy 文案收口。
- v3.7-preflight.89-.108 已把隋唐胜负摘要共享化、命令结果固守判断语义化，收口阶段/legacy 总管展示口径，让自动方面总管默认指挥风格与多势力映射对齐，抽出共享默认风格 helper，让 DataLoader 无效 phase 兜底不再回到 legacy AI 阶段，集中规范化 legacy phase 存档语义，让 `WarCommandExecutor` 动态方面推进不再把异常缺 zone 路径静默兜底到旧东路势力，让 `RegionDataSet.toRegions()` 不再把任意缺省 owner/controller 静默兜底到旧西路势力，用 `ScenarioSemantics` 收口默认场景语义与胜负 fallback 门禁，让 MapEditor 导入坏 unit faction 时不再静默落到旧 `.allies`，让归附交接后的善后风险写入受影响州郡治安/顺从状态，让治安/顺从折算后续贡赋收入效率，让渡口/港口/海港地点减免粮道跨河补给成本，让 MapEditor 默认资源读写不再丢失 tile `riverEdges`，提供 MapEditor 河边绘制/擦除入口，让己控渡口/港口/海港作为战术补给投送点，让默认 `wude_618` 四个水路地点自身 hex 均有非空 `riverEdges`，并让己控渡口/港口/海港降低相邻跨河移动成本。

后续 Agent 不能把下方 v3.0-v3.7 路线当作“尚未开始”的待办清单。它们是历史路线和架构合同；当前实际工作应优先从“v3.7+ 剩余风险与 v3.8+ 队列”中切片，并以当前源码和轻量检查结果为准。若 `md/flow/*`、`update_log.md` 或阶段记录仍停留在更早口径，下一轮必须先把文档同步列为切片的一部分，不能让总提示词单独领先核心流程文档。

### 0.2 v3.7+ / v3.8+ 当前候选队列

后续小步实现优先从以下队列切片，保持单轮文件范围清晰，禁止把多个高风险方向混在一轮。本队列不是全量待办；每轮只能选一项或一个明确子问题，先定位根因，再更新源码、文档和轻量检查记录。§5 只作历史架构合同，不是待办；Agent B 每轮只能从“当前可执行队列”或人工新目标中选择一个未关闭切片。已关闭 P 项不得重复实现，只能在运行时重测、云端失败或源码复扫重新命中时复查。

已关闭风险：

- P0 数据 fallback：已由 v3.7-preflight.98 收口。`WWIIHexV0/Data/RegionDataSet.swift` 的 `toRegions()` 现在会对非 legacy 数据缺 owner 抛出数据校验错误；只有明确旧战局 RegionDataSet 才保留 `.allies` 兼容 fallback。后续仅在运行时/云端验证中复查默认隋唐、旧战局和坏 region JSON 加载诊断。
- P1 动态战区推进 fallback：已由 v3.7-preflight.97 收口。`WWIIHexV0/Commands/WarCommandExecutor.swift` 现在优先按 advancing zone 推断推进势力，异常缺 zone 时回退实际行动军队，两者都缺失时跳过本次动态方面推进并记录原因，不再静默兜底旧东路势力。后续仅在运行时/云端验证中复查 directive move、异常缺 zone 和旧阿登兼容路径。
- P2-a 场景语义 helper：已由 v3.7-preflight.99 收口。`ScenarioSemantics` 集中判断明确 legacy、明确 `wude_618`、隋唐草稿和未知自定义场景；`DataLoader`、`GameState`、`AgentConfiguration` 和 `AppContainer` 复用该 helper，不再各自散落默认玩家 / AI / agent 势力推断。
- P2-b 胜负 fallback gating：已由 v3.7-preflight.99 收口。`VictoryRules` / `RegionVictoryRules` 只有明确旧战局才走 legacy Bastogne / St Vith fallback，隋唐草稿和未知自定义场景保持未决，不静默套用旧胜负规则。
- P3 MapEditor 导入 fallback：已由 v3.7-preflight.100 收口。`MapEditorGameResourceBridge.makeDocument` 解析默认游戏资源时，非法 unit faction 不再静默落到旧 `.allies`；导入会跳过坏 unit，生成 `MapEditorGameResourceImportDiagnostic`，并由 `MapEditorViewModel` 在读取默认资源状态消息中说明跳过原因。
- 归附善后治安/顺从压力：已由 v3.7-preflight.101 部分收口。`CommandExecutor.executeSubmissionHandoff` 生成 `SubmissionAftermathRecord` 后，会按风险等级调整受影响州郡 `OccupationState.resistance` / `compliance`；安民等既有州郡经营可抵消该压力。完整忠诚、叛乱、俘虏、安置系统仍待后续独立切片。
- 归附善后贡赋效率：已由 v3.7-preflight.102 部分收口。`EconomyRules.income(for:map:)` 会按受控州郡 `OccupationState` 折算贡赋效率，高抵抗降低丁口、军械、粮草收入，安民提高顺从后自然恢复。完整忠诚、叛乱、俘虏、安置系统仍待后续独立切片。
- 渡口港口粮道补给减免：已由 v3.7-preflight.103 部分收口。`SupplyRules.supplyPathCost` 跨河计算粮道成本时，若跨河两端任一 hex 有 `MapFeatureKind.ferry` / `port` / `harbor`，该段补给渡河额外成本免除。完整水战、港口补给源和更细水域控制仍待后续独立切片。
- MapEditor 河边数据往返保存：已由 v3.7-preflight.104 收口。`MapEditorHex` 保存 `riverEdges`，默认资源桥导入 scenario tile 河边，`MapEditorExporter` 稳定写回；不新增河流编辑 UI，不自动镜像邻接边，不改运行时河流规则。
- MapEditor 河边编辑入口：已由 v3.7-preflight.105 收口。地块模式可绘制/擦除当前 hex 的指定 `riverEdges`，画布显示蓝色河边，信息面板列出方向；不自动镜像邻接边，不改运行时河流规则、默认 JSON 或 schema。
- 受控渡口港口补给投送点：已由 v3.7-preflight.106 部分收口。`SupplyRules` 内部把己方控制的 `ferry` / `port` / `harbor` marker 坐标并入补给 anchor，用于单位补给线、安全撤退和撤退排序；不写入 `MapState.supplySources`，不改省级补给、部署点、经济新兵落点、移动、战斗或水战。
- 默认水路地点河边资产：已由 v3.7-preflight.107 收口。默认 `wude_618_scenario.json` 让蒲津渡、孟津渡、黎阳津和洛口津自身 hex 均有非空 `riverEdges`，可被既有跨河补给与移动渡河规则消费；不改 JSON schema、运行时规则或邻边镜像策略。
- 受控渡口港口移动渡河减免：已由 v3.7-preflight.108 部分收口。`MovementRules.shortestPaths` 的内部 state-aware 成本函数会在非道路跨 `riverEdges` 行军时检查两端己控 `ferry` / `port` / `harbor`，命中则免除该段渡河额外移动成本；不改公开纯地形 `movementCost`、命令、补给、战斗、水战或部署点。

当前可执行队列：

- 正式地图资产、图标资产和运行时截图复核：首屏必须是可玩地图，不是说明页或营销页。
- 完整忠诚、叛乱、俘虏、安置等归附善后实际规则；治安/顺从压力已由 v3.7-preflight.101 落地，贡赋效率已由 v3.7-preflight.102 落地。
- 完整水战、港口补给源、港口部署点与粮道扩展规则；渡口/港口粮道补给减免已由 v3.7-preflight.103 落地，MapEditor 河边数据往返保存已由 v3.7-preflight.104 落地，河边绘制/擦除入口已由 v3.7-preflight.105 落地，受控渡口/港口补给投送点已由 v3.7-preflight.106 落地，默认水路地点河边资产已由 v3.7-preflight.107 补录，受控渡口/港口移动渡河减免已由 v3.7-preflight.108 落地。
- 云端验收闭环：凡 Agent B push `main` 后，Agent C 必须按 `md/test/test.md` 下载并核对 GitHub Actions 未加密 CI 结果包、manifest、JUnit/摘要、日志、run id 和 run attempt；这不是可选发布功能。
- 真实本地 LLM / 可插拔模型接入；必须继续走结构化 directive、decoder、validator 和规则系统。

### 0.3 单轮切片交付模板

后续每轮实现只能选择一个清晰切片。Agent B 开始写代码前，必须在阶段记录或交接说明中写明以下内容；如果本轮只是 Agent A 提示词设计，也必须把这些字段写进给 Agent B 的提示词。

```text
切片 ID：
来源：§0.2 队列 / 人工新目标 / 云端退回问题。
当前基线：origin/main 最新 commit、update_log.md 顶部状态、当前源码和 git status。
目标：
非目标：
允许修改文件：
只读参考文件：
禁止项：
实现步骤：
轻量检查：
文档同步：
验收标准：
预期风险：
完成后交付：commit、push origin main、记录 GitHub Actions run 状态；本机重测试未授权则明确不跑。
```

每轮开始先用精确 `rg` 或源码定位命令确认该切片风险仍存在；完成后用同一组扫描或更强证据说明旧风险已消失。完成某个 P 项后，必须同步更新本文件 §0.2：移除、降级或标注“已由 v3.7-preflight.xx 收口”，避免下一轮重复处理。

新增阶段记录文件必须纳入提交。如果 `update_log.md`、README、`md/flow/*` 或本文件已经引用未跟踪文件，不得 push 漏掉这些记录。

### 0.4 当前 P 项切片建议

这些建议只用于下一轮拆任务，不替代源码审计。每轮仍要重新确认命中和风险。

- P0 `RegionDataSet.toRegions()`：已由 v3.7-preflight.98 收口。后续只需在运行时重测中关注默认隋唐 region 数据、旧战局 fallback 数据和自定义坏 region JSON 的加载诊断。
- P1 `WarCommandExecutor.applyStrategicAdvance`：已由 v3.7-preflight.97 收口。后续只需在运行时重测中关注 directive move 推进、异常缺 zone 场景和旧阿登兼容路径。
- P2-a `ScenarioSemantics` 最小切片：已由 v3.7-preflight.99 收口。后续只需在运行时重测中关注默认隋唐、明确旧战局、隋唐草稿和未知自定义场景的默认 phase / player faction / agent faction。
- P2-b 胜负 fallback gating 最小切片：已由 v3.7-preflight.99 收口。后续只需在运行时重测中关注明确旧战局胜负仍兼容、隋唐正式剧本仍走 `Wude618VictoryEvaluator`、未知自定义保持未决。
- P3 MapEditor 非法 unit faction 最小切片：已由 v3.7-preflight.100 收口。后续只需在 MapEditor 导入重测中关注默认隋唐资源是否无诊断读取、坏 unit faction 是否被跳过并在状态消息中说明原因。

### 0.5 总提示词维护与冻结标准

本文件的职责是维护长期架构合同、当前交接状态、当前候选队列、并发边界、检查边界和交付模板。它不再承载每一轮 v3.7-preflight 的流水记录；单轮实现细节、扫描命中、轻量检查结果和未验证风险应写入对应阶段记录、`update_log.md`、`md/flow/*` 或 Agent A 给 Agent B 的切片提示词。

后续只在这些情况修改本文件：

- 当前交接状态或 §0.2 / §0.4 队列发生变化，需要避免下一轮重复处理。
- `AGENTS.md`、`md/test/test.md`、`md/prompt/README.md` 的工作流、云端验收或检查边界改变。
- 新增长期架构合同、权威边界、并发规则或交付模板。
- 发现本文件与当前源码、`update_log.md`、`md/flow/*` 存在会误导后续 Agent 的冲突。

除上述情况外，不要继续扩写历史路线、产品愿景或单轮记录。完成某个 P 项后，优先更新 §0.2 / §0.4 的状态和对应阶段记录；不要把完整实现过程追加进本总提示词。若 §0.2 队列清空、A/B/C 工作流一致、轻量检查边界明确、历史路线只作为归档合同存在，本文件即可视为阶段性冻结版；后续只做状态维护。

---

## 1. 最终产品目标

暂定产品名：`天命开唐 Agent`。英文工作名可用 `Mandate Agent Hex` 或 `Sui Tang Agent Hex`，最终名称由人工确认。

最终首发体验应达到以下效果：

1. 打开应用后直接进入可玩的历史战役地图，不做营销落地页。
2. 首发剧本建议选择 `武德元年 618：关中河洛争衡`，覆盖关中、河东、河洛、河北南部、淮北一带的抽象战役地图。
3. 首发地图规模控制在约 90-160 个 hex、25-45 个州郡 region、6-10 个方面/行军道，保证可玩、可调、可发布。
4. 主要势力建议：
   - `power_tang`：李渊/李世民集团，核心长安、太原、关中。
   - `power_luoyang_sui`：洛阳隋廷/王世充方向，核心洛阳、虎牢、河洛。
   - `power_wagang`：李密瓦岗，核心洛口仓、荥阳、河南北部。
   - `power_xia`：窦建德河北集团，核心洺州、河北平原。
   - `power_qin_xue`：薛举/薛仁杲陇右方向，作为关中西线压力。
   - `power_liu_wuzhou`：刘武周/宋金刚北线方向，可与突厥关联。
   - `power_tujue`：东突厥，首版可做边境压力或外交/援军，不必全图展开。
   - `neutral`：中立州郡、地方豪强、未归附城池。
5. 玩家可选择至少一个势力，首发建议先保证 `power_tang` 可玩；其他势力由 AI Agent 驱动。
6. 地图以 hex 为战术权威，以州郡/仓城/关隘为战略聚合层，以行军道/总管府/方面为 AI 调度层。
7. 玩家既能微操军队，也能通过将领/军令面板下达宏观命令：固守、进军、合围、截粮、围城、驰援。
8. AI Agent 不直接改 `GameState`。君主、谋主、行军总管、太守、将领、外交使者等 Agent 只能输出结构化 directive，经 decoder / validator / compiler 后落到统一规则系统。
9. UI 视觉要脱离二战调试原型，形成隋唐历史战棋质感：
   - 绢帛/山水地图底色，但不能整屏单一米色。
   - 墨线地形、青绿河流、朱印势力标识、铜色/玉色 UI 点缀、军旗、城池、关隘、粮仓、渡口图标。
   - 部队棋子能区分步卒、骑兵、弓弩、攻城器械、守军、水师。
   - 战线、进军箭头、围城圈、粮道虚线和 AI 计划必须可读。
10. UI 第一屏核心是地图和行动，不是说明文案；玩家进入后能立即看见当前势力、回合、资源、可行动军队、战线和军令入口。
11. 发布前主游戏 UI、默认数据、日志、面板不能有主要二战残留：Germany、Allies、Ardennes、Panzer、Bastogne、Division 等不得出现在玩家可见路径中。
12. 发布候选必须有一个完整闭环：开局、选择势力、查看州郡、选择军队、进军、战斗、围城/占领、粮草消耗、AI 回合、外交或归附事件、战报复盘、胜负判断。

---

## 2. 迁移总原则

### 2.1 保留的工程骨架

必须保留并迁移这些成熟资产：

- Hex 坐标、移动、攻击、占领、视野、补给落点的战术权威。
- Region 战略聚合层，不替代 hex。
- 动态战区、前线、部署层从 hex 和单位位置派生的关系。
- `Command` / `ZoneDirective` / `WarCommandExecutor` / `RuleEngine` 统一执行管线。
- `WarDirectiveRecord`、`AgentDecisionRecord`、后续外交记录等审计/复盘机制。
- MapEditor 的稀疏 hex、region、theater、unit 编辑和导出能力。
- iOS 主游戏、macOS 主游戏、macOS 地图编辑器的方向。
- 当前模拟 LLM / MockAI fallback 思路：真实模型不可用时仍能 deterministic 地推进游戏。

### 2.2 必须替换或抽象的二战语义

按版本逐步替换这些题材绑定点：

- `Faction.germany/allies`：迁移为多势力体系。短期可扩展 enum，长期目标是数据驱动 `PowerId` / `Faction` 兼容桥。
- `GamePhase.germanAI/alliedPlayer`：迁移为通用 `playerCommand` / `aiCommand` / `resolution` 或基于 active power 的 phase，不再写死德军/盟军。
- `Division`：源码可短期保留兼容名，但玩家可见语义必须是军队、部曲、军团、守军或行军队。
- `ComponentType.tank/motorizedInfantry/infantry/artillery`：迁移为步卒、骑兵、弓弩、攻城器械、守军、水师等。
- `EconomyResources.manpower/industry/supplies`：短期显示映射为丁口/钱帛或军械/粮草；长期可拆出更贴合古代的资源结构。
- `Theater`：UI 显示为方面、行军道、总管府或军区。
- `FrontZone`：UI 显示为行军防区、方面军防区或总管辖区。
- `Region`：UI 显示为州郡、郡县、仓城、关隘，不叫 province。
- `RulerAgent`：迁移为君主/天命 Agent。
- `MarshalAgent`：迁移为谋主/大总管/军师 Agent。
- `GeneralData`：迁移为历史人物数据，含统率、武勇、谋略、政务、威望、忠诚、野心、性格、技能。
- 阿登 JSON：迁移为隋末唐初剧本 JSON。
- 地图编辑器术语：地块、州郡、方面、军队/将领、城池、粮仓、渡口、关隘。

### 2.3 必须新增或强化的隋唐语义

以下是长期产品语义目标，只有被人工目标或 §0.2 切片选中时才进入实现；首发可控实现，不追求一次性完整模拟：

- `Mandate / Legitimacy`：天命、正朔、民心，影响归附、征兵、外交态度和胜利评价。
- `Granary / Supply`：粮仓、粮道、仓城。洛口仓、长安、洛阳、太原等应成为战略节点。
- `Siege`：围城/守城/破城。城池和关隘不应只是普通地形。
- `Governance`：州郡治理、治安、民心、征发。首版可只影响收入和叛乱风险记录。
- `Defection / Submission`：归附、降伏、倒戈。首版可作为外交/事件结果，不要直接绕过规则占领 hex。
- `Tujue Pressure`：东突厥边境压力、借兵或威胁。首版可以 off-map 事件和外交 modifier 表达。

### 2.4 不能做的事

- 不要一次性大规模重命名所有类型再凭感觉修编译。先做兼容层和迁移合同，再分版本替换。
- 不要让任何 Agent 直接修改 `HexTile.controller`、`Division.coord`、`regionToTheater`、`hexToTheater` 或 `hexToFrontZone`。
- 不要把 region 当战术权威；进军、攻击、围城、占领仍必须落到 hex。
- 不要把完整中国地图、所有 617-626 年势力、真实谱系、所有外交内政一次性塞进首版。
- 不要使用受版权保护的影视、游戏、绘画头像、图标或 UI 资产。可用自制、生成、公共领域或明确授权素材。
- 不要硬编码真实 LLM API key、模型路径、网络端点。真实模型接入单独版本处理。
- 未获人工授权，不跑 `xcodebuild build/test`、模拟器、Probe、Smoke、Stage Regression、Full、性能测试或 app 启动。

---

## 3. 历史与玩法定位

### 3.1 首发剧本

推荐首发剧本：

```text
id: wude_618_guanzhong_luoyang
displayName: 武德元年：关中河洛争衡
时间范围：617-619 的抽象战役窗口，以 618 为开局题面
地图范围：关中、河东、河洛、河北南部、淮北/河南局部、陇右入口
核心冲突：唐据长安，洛阳仍为正朔重镇，瓦岗控制仓城，河北窦建德坐大，西北和北线威胁压迫关中
```

关键州郡和节点建议：

- 长安、大兴城、渭北、潼关、华阴、弘农、蓝田。
- 太原、晋阳、河东、霍邑、蒲坂。
- 洛阳、偃师、虎牢、函谷、洛口仓、荥阳。
- 黎阳仓、汲郡、邺城/河北南缘、洺州方向。
- 扶风、陇西入口、浅水原/陇右方向。
- 淮阳/汝南/江淮入口可作为地图边缘势力触点。

首版不要追求精确地理比例，优先保证：

- 战线关系清楚。
- 粮仓和关隘有战略意义。
- 各势力开局目标明确。
- hex 数量能支撑移动、围城、合围、补给。

### 3.2 玩法支柱

1. **战术推进**：军队在 hex 上移动、攻击、驻守、撤退、占领。
2. **州郡经营**：州郡聚合人口、钱粮、军械、粮仓、民心、胜利点。
3. **粮道与围城**：补给链和仓城决定进攻可持续性。
4. **多势力外交**：敌我关系不是二元，归附、同盟、停战、称臣、借兵可后续扩展。
5. **AI Agent 决策**：君主定大战略，谋主分解目标，行军总管/将领输出战区行动，太守处理州郡事务。
6. **审计与复盘**：玩家能看到 AI 为什么打虎牢、为什么截粮、为什么退守潼关。

---

## 4. 多 Agent 并发工作流

本节的“主 Agent / 子 Agent”只描述单轮内部并发拆分，不替代 `AGENTS.md` 的 Agent A/B/C 工作流。Agent B 负责实现、轻量检查、commit 和 push；Agent C 负责 `origin/main` 最新 commit 的正式云端 artifact 验收。子 Agent 不得自行 push、改变远端 `main` 或宣布正式验收。

主 Agent 负责本轮总体架构、接口合同、冲突整合和内部交付判断。子 Agent 只能在明确边界内并发，不得同时改同一 public API 或同一文件。

### 4.1 并发前主 Agent 必做

1. 读完 `AGENTS.md`、`update_log.md`、`md/flow/flow.md`、`md/flow/flowchart.md`、`md/test/test.md` 和本文件。
2. 审计工作树：

```sh
git branch --show-current
git status --short
rg -n "Germany|Allies|Ardennes|Panzer|Bastogne|German AI|Allied Player" WWIIHexV0/UI WWIIHexV0/SpriteKit WWIIHexV0/Data MapEditor README.md
rg -n "enum Faction|enum GamePhase|struct Division|enum ComponentType|EconomyResources|DiplomacyState|GeneralData|ZoneDirective|WarCommandExecutor|RuleEngine" WWIIHexV0
```

历史 prompt、`update_log.md` 和阶段记录中的 legacy 命中只作背景，不自动形成待办。`Division`、`MarshalAgent`、`RulerAgent`、`germany/allies` rawValue 等源码兼容名只有进入玩家可见路径、破坏隋唐主路径或造成 fallback 语义错误时才处理。

3. 写出本轮实际版本目标、非目标和文件边界。
4. 定义公共接口合同。没有接口合同前，不要让多个子 Agent 同时改 `Core/`、`Commands/`、`Rules/`。
5. 明确 `WWIIHexV0.xcodeproj/project.pbxproj` 只能由主 Agent 或唯一指定的 Project Agent 修改。
6. 明确默认不跑重测试；只能跑 `md/test/test.md` 允许的轻量检查。

### 4.2 推荐子 Agent 分工

每轮最多并发 3-5 个子 Agent。优先减少冲突，不追求数量。

#### History / Data Agent

范围：

- `WWIIHexV0/Data/*.json`
- `WWIIHexV0/Data/ScenarioDefinition.swift`
- `WWIIHexV0/Data/RegionDataSet.swift`
- `WWIIHexV0/Data/DataLoader.swift`
- 只读 `Core/Faction.swift`、`Core/Terrain.swift`

职责：

- 设计隋末唐初首发剧本数据。
- 建立势力、州郡、地形、单位模板、人物/将领、胜利条件数据。
- 保证 JSON id 使用 ASCII/pinyin，例如 `power_tang`、`region_changan`、`general_li_shimin`。
- 中文只放在 `displayName`、`localizedName`、`biography`、`description` 等展示字段。
- 不追求百科全书式完整历史，优先服务可玩性和架构清晰。

禁止：

- 不改 `RuleEngine`。
- 不改 SwiftUI/SpriteKit 视觉。
- 不改 project 文件，除非主 Agent 明确指定。

#### Rules Agent

范围：

- `WWIIHexV0/Core/`
- `WWIIHexV0/Commands/`
- `WWIIHexV0/Rules/`

职责：

- 将二元阵营、二战单位、二战补给经济迁移为隋唐多势力可用规则抽象。
- 保持 `Command` / `ZoneDirective` / `WarCommandExecutor` / `RuleEngine` 统一入口。
- 落地围城、粮道、士气、兵种差异时先给最小可运行版本。
- 保证中立/地方豪强不会被 fallback 到某个玩家势力。

禁止：

- 不改 UI 大布局。
- 不新增真实网络 LLM 调用。
- 不让外交或归附直接绕过 hex 占领规则。

#### AI Agent

范围：

- `WWIIHexV0/Agents/`
- `WWIIHexV0/Turn/`
- 只读 `Core/Commands/Rules`

职责：

- 设计并实现君主、谋主、行军总管、太守、将领、外交使者 Agent 分层。
- 所有输出必须是 Codable JSON / directive。
- 上游 Agent 只能调整战略姿态、目标优先级、资源倾向或 directive envelope，不能直接执行底层命令。
- 失败时必须 deterministic fallback，不执行半成品 JSON。

禁止：

- 不直接改 `GameState`。
- 不绕过 `WarCommandExecutor`。
- 不硬编码外部模型密钥或路径。

#### UI / Art Agent

范围：

- `WWIIHexV0/UI/`
- `WWIIHexV0/SpriteKit/`
- asset catalog 如存在或由主 Agent 创建

职责：

- 迁移为隋唐视觉系统。
- 建立共享设计 token：字体、颜色、材料、间距、线宽、动效、势力色。
- 地图、军队、将领、城池、关隘、粮道、战线、战报都要有发布级可读性。
- 保持第一屏是可玩的地图体验，不做 landing page。

要求：

- 44pt 最小触控目标。
- 文本不能溢出或互相遮挡。
- 大列表用 `LazyVStack` / `LazyHStack`。
- 复杂面板拆成独立 View，不继续膨胀 `RootGameView`。
- 避免单一米色、单一暗蓝或单一紫色主题；绢帛色只能作底，必须有墨色、朱印、青绿、铜色和势力色形成层次。

禁止：

- 不把规则写进 View。
- 不让 SpriteKit 直接改 `GameState`。
- 不使用商业游戏/影视素材。

#### MapEditor Agent

范围：

- `MapEditor/`
- 只读 `Data/` schema

职责：

- 将编辑器术语迁移为地块、州郡、方面/行军道、军队/将领。
- 支持隋唐地形、城池、关隘、渡口、粮仓、港口、初始将领和势力归属。
- 保持导出仍为项目自有 `ScenarioDefinition` + `RegionDataSet` JSON。

禁止：

- 不破坏主游戏 JSON 加载格式。
- 不把编辑器底图写入游戏 JSON。

#### Docs / QA Agent

范围：

- `README.md`
- `update_log.md`
- `md/flow/`
- `md/test/test.md`
- `md/prompt/v3.0-隋唐迁移/`

职责：

- 同步核心逻辑文档和阶段记录。
- 做轻量检查与冲突扫描。
- 记录未跑重测试的风险。
- 检查所有阶段文档是否一致，不允许 README、flow、prompt 各说一套。

### 4.3 并发整合规则

子 Agent 完成后，主 Agent 必须检查：

- 是否多个子 Agent 改了同一文件。
- 是否出现 public API、类型名、枚举 case、JSON key 分叉。
- 是否出现 `Faction`、`PowerId`、`CountryId` 三套概念混乱。
- 是否出现 `project.pbxproj` 重复引用、缺失引用或 UUID 冲突。
- 是否有人绕过 `RuleEngine` 修改状态。
- 是否有人把 `regionToTheater` 写成运行时推进权威。
- 是否有人把 `hexToTheater`、`hexToFrontZone` 的动态权威边界写错。
- 是否出现 README、`md/flow/*`、阶段记录、`update_log.md` 口径不一致。

没有完成这些检查前，不得声称“多 Agent 工作可合并”。

### 4.4 子 Agent 固定输出格式

每个子 Agent 交回结果时必须使用下面格式，不得只写自然语言结论。只读 explorer 也要写“实际修改文件：无”。

```text
子 Agent 名称 / 范围：
实际读取文件：
实际修改文件：
新增 / 修改的 public API、enum case、JSON key、schema 字段：
与其他 Agent 潜在重叠：
已跑轻量检查及结果：
未跑检查及原因：
文档需同步点：
遗留风险：
建议主 Agent 整合检查项：
```

主 Agent 整合并发结果时，最终交付中至少说明：

- 文件级重叠检查结论。
- public API / enum / JSON schema 分叉检查结论。
- `project.pbxproj` 引用检查结论；若本轮未涉及项目文件，也要写明未涉及。
- `Command` / `ZoneDirective` / `WarCommandExecutor` / `RuleEngine` 管线未被绕过的检查结论。
- `hexToTheater` / `hexToFrontZone` / `regionToTheater` 权威边界未被改错的检查结论。
- README、`md/flow/*`、阶段记录、`update_log.md` 版本口径一致性结论。

---

## 5. 版本路线

本节是历史归档和架构合同，不是 Agent B 的默认实现任务清单。v3.0-v3.7 已经是完成过的历史路线；其中的“目标 / 推荐文件 / 验收”用于理解当时设计边界，不代表当前应重做。当前仓库规则以 `AGENTS.md` 为准：默认在 `main` 上小步提交和云端验证，不再按下面的历史阶段标签新建工作分支，除非人工明确授权。后续 Agent 应从 §0.2 的当前队列或人工新目标切片，不得回到 v3.0-v3.7 重做已完成路线。除非人工明确指定历史补录，不要阅读本节后直接实现其中目标；当前执行入口只有 §0.2 / §0.4 或人工新目标。

### v3.0：迁移审计、兼容层和题材合同

历史阶段标签：`v3.0-suitang-audit-contract`

目标：

- 建立隋末唐初迁移的工程合同。
- 找出所有二战硬编码、二元阵营假设和 UI 文案残留。
- 明确哪些源码名短期保留兼容，哪些玩家可见文案必须立即替换。
- 不急着实现完整隋唐玩法。

范围：

- 新增阶段记录：`md/prompt/v3.0-隋唐迁移/v3.0_audit_and_contract.md`。
- 新增迁移词汇表和命名约定：
  - `Faction` 当前源码兼容名，目标语义为势力。
  - `Division` 当前源码兼容名，目标显示为军队/部曲。
  - `Theater` 显示为方面/行军道/总管府。
  - `Region` 显示为州郡/郡县。
  - `FrontZone` 显示为行军防区。
  - `EconomyResources.manpower/industry/supplies` 显示为丁口/钱帛或军械/粮草。
- 只抽出显示名和审计清单，不做大范围重命名。

推荐并发：

- Docs / QA Agent：硬编码扫描、审计表、迁移词汇表。
- UI Agent：只读定位 UI 硬编码和布局风险。
- Rules Agent：只读定位 `Faction.opponent`、二元 switch、兵种耦合。

验收：

- 有完整审计清单。
- 有隋唐迁移词汇表。
- 有版本拆分和风险清单。
- 没有大范围重命名导致不确定风险。

### v3.1：多势力、外交关系和通用回合阶段

历史阶段标签：`v3.1-suitang-powers-diplomacy`

目标：

- 从二元 `germany/allies` 迁移到多势力隋唐架构。
- 首版至少支持唐、洛阳隋/王世充、瓦岗、窦建德、薛举/薛仁杲、刘武周、东突厥、中立。
- 清除核心逻辑对 `.opponent` 的依赖。
- 将 `GamePhase.germanAI/alliedPlayer` 迁移为通用阶段或建立兼容显示层。

设计建议：

1. 审计 `Faction` 的所有使用点。
2. 短期发布优先时，可扩展 `Faction` enum：
   - `tang`
   - `luoyangSui`
   - `wagang`
   - `xia`
   - `qinXue`
   - `liuWuzhou`
   - `tujue`
   - `neutral`
3. 长期更好方案是引入 `PowerId`，让 `Faction` 变为兼容桥；但不要一轮内强行改完整项目。
4. 移除或弃用 `Faction.opponent`。多势力敌我必须来自 `DiplomacyState` / `PowerRelation`。
5. `DiplomacyState` 迁移为：
   - allied / vassal / neutral / hostile / atWar / truce / submitted
   - legitimacy、mandate、prestige、trust、tribute 可后续增加。
6. `CommandValidator`、`OccupationRules`、`SupplyRules`、`TheaterSystem`、`WarDeploymentManager` 必须用关系判断敌我，不再假设只有两个阵营。
7. `neutral` 或无 controller 的 hex 不能被错误算给某个势力。

推荐文件：

- `WWIIHexV0/Core/Faction.swift`
- `WWIIHexV0/Core/GamePhase.swift`
- `WWIIHexV0/Core/DiplomacyState.swift`
- `WWIIHexV0/Core/GameState.swift`
- `WWIIHexV0/Data/ScenarioDefinition.swift`
- `WWIIHexV0/Data/DataLoader.swift`
- `WWIIHexV0/Rules/CommandValidator.swift`
- `WWIIHexV0/Rules/OccupationRules.swift`
- `WWIIHexV0/Rules/StrategicStateSynchronizer.swift`

推荐并发：

- Rules Agent：势力和敌我判断迁移。
- Data Agent：势力 profile JSON 草案。
- AI Agent：只读确认 agent config 对多势力的影响。
- Docs / QA Agent：文档和检查。

验收：

- 多势力可以被 JSON 表达。
- 敌我判断不再依赖 `.opponent`。
- 中立州郡不会被错误算给某个势力。
- 玩家和 AI 的命令校验仍对称。
- 阶段显示不再出现 German AI / Allied Player。

### v3.2：隋唐地图、剧本数据和地图编辑器迁移

历史阶段标签：`v3.2-suitang-scenario-map`

目标：

- 建立第一张可玩隋末唐初剧本地图。
- 保留 MapEditor 导出链路。
- 默认新局加载隋唐剧本，而不是阿登。

默认数据文件建议：

```text
WWIIHexV0/Data/wude_618_scenario.json
WWIIHexV0/Data/wude_618_regions.json
WWIIHexV0/Data/suitang_unit_templates.json
WWIIHexV0/Data/suitang_generals.json
WWIIHexV0/Data/suitang_power_profiles.json
WWIIHexV0/Data/suitang_terrain_rules.json
```

地形与节点建议：

- plain -> 平原
- farmland -> 田畴，若 schema 暂不支持可先用 plain + region resource 表达
- forest -> 林地
- hill / mountain -> 丘陵 / 山地
- city -> 城池
- fortress -> 关隘 / 坚城
- river -> 黄河 / 渭水 / 洛水 / 汾水等
- road -> 官道
- pass -> 关口，若 schema 暂不支持可用 fortress + mountain 表达
- granary -> 粮仓，首版可用 supply source / region supplyValue 表达
- ferry / port -> 渡口 / 水津，水战可后置

MapEditor 迁移：

- province 文案改为州郡。
- theater 文案改为方面/行军道。
- unit 文案改为军队/将领。
- supply source 文案改为粮仓/补给点。
- 支持 `assignedGeneralId` 显示为将领。
- 支持城池、关隘、渡口、粮仓、港口字段；如果 schema 暂不支持，先记录后置，不要塞进无关字段。

推荐并发：

- History / Data Agent：新 JSON 和 DataLoader 默认入口。
- MapEditor Agent：编辑器中文术语和导出字段兼容。
- UI Agent：地图层显示名和 accessibility label。
- Docs / QA Agent：同步 flow 和 README 草案。

验收：

- 默认新局加载 `wude_618` 路径。
- `MapEditorExporter` 可以导出隋唐语义地图而不丢 region/theater/unit。
- 默认数据不再出现阿登主剧本名。
- 所有 id 使用 ASCII，展示名可为中文。

### v3.3：军队、兵种、粮道、围城和战术规则

历史阶段标签：`v3.3-suitang-war-rules`

目标：

- 把二战单位和战术转换为隋末唐初规则。
- 保留 hex 战术权威和统一命令管线。
- 首版规则要可解释、可调参，不追求复杂模拟。

单位模型建议：

- 源码可短期保留 `Division`，但 UI 显示必须是军队/部曲/营。
- `ComponentType` 迁移为：
  - `infantry`：步卒
  - `cavalry`：骑兵
  - `archer`：弓弩
  - `siegeEngine`：攻城器械
  - `guard`：亲军/禁军，可后置
  - `naval`：水师，可后置
  - `militia`：乡兵/义军，可后置
- stats 可保留 attack/defense/movement/range/vision。
- morale / fatigue / grainCarry 可后置；首版可用 strength + supplyState 兼容。

战术映射建议：

- `standardAttack` -> 正攻
- `spearhead` -> 突骑破阵
- `breakthrough` -> 破阵 / 破关
- `pincerMovement` -> 合围
- `fireCoverage` -> 弓弩压制 / 投石压制
- `feint` -> 佯动
- `guerrillaWarfare` -> 袭扰 / 截粮
- `holdPosition` -> 固守
- `elasticDefense` -> 诱敌退守
- `defenseInDepth` -> 守关层防
- `lastStand` -> 死守

新增或迁移规则：

- 粮草：`SupplyRules` 保留基础，展示为粮道/粮草。
- 粮仓：supply source 显示为粮仓，洛口仓、长安、洛阳、太原等有战略补给价值。
- 围城：城池/关隘 hex 或 region 被敌邻接且粮道断绝时，防御、恢复、士气下降；占领仍必须从 hex 执行。
- 士气：首版可从日志和战斗修正开始，不强制一轮加字段。
- 兵种差异：骑兵平原机动，弓弩 range，器械对城池/关隘有效，山地/关隘限制骑兵。
- 将领影响：首版可通过 `GeneralAssignment` 的 skill 调整 tactic 选择或小幅战斗修正，不能跳过规则。

推荐文件：

- `WWIIHexV0/Core/Division.swift`
- `WWIIHexV0/Core/SupplyState.swift`
- `WWIIHexV0/Core/EconomyState.swift`
- `WWIIHexV0/Rules/CombatRules.swift`
- `WWIIHexV0/Rules/MovementRules.swift`
- `WWIIHexV0/Rules/SupplyRules.swift`
- `WWIIHexV0/Rules/EconomyRules.swift`
- `WWIIHexV0/Rules/CommandValidator.swift`
- `WWIIHexV0/Commands/WarDirective.swift`
- `WWIIHexV0/Commands/WarCommandExecutor.swift`
- `WWIIHexV0/Agents/ZoneCommanderAgent.swift`

推荐并发：

- Rules Agent：军队、战斗、粮草、围城。
- AI Agent：战术分类器隋唐化。
- Data Agent：unit templates。
- UI Agent：只做术语显示，不做大 UI。

验收：

- 玩家和 AI 的移动、攻击、防守、补给仍经 `RuleEngine`。
- 围城和粮草日志能被解释。
- 战术名称在 UI 和 `WarDirectiveRecord` 中隋唐化。
- 没有二战兵种显示残留。

### v3.4：君主、谋主、行军总管、太守、将领 AI Agent 分层

历史阶段标签：`v3.4-suitang-agent-court`

目标：

- 构建真正有隋末唐初味道的 AI Agent 层级。
- Agent 之间可以协作，但最终都必须输出结构化 directive。
- 让 AI 行为可审计、可回放、可调参。

推荐层级：

```text
SovereignAgent 君主 / 天命
  -> 决定总战略：入关、守洛、据河北、联突厥、争粮仓、招降纳叛

StrategistAgent 谋主 / 军师
  -> 把总战略变成方面目标：取虎牢、守潼关、断洛口仓、驰援太原

GovernorAgent 太守 / 州郡官
  -> 处理州郡内政：征发、屯田、修道、治安、补给、归附安抚

MarchCommanderAgent 行军总管 / 大将
  -> 把方面目标变为 ZoneDirective：进军、防守、佯动、合围、围城、截粮

GeneralAgent 将领
  -> 影响具体战术偏好、军队选择和风险承受

DiplomatAgent 使者 / 谋臣
  -> 输出外交提案：同盟、停战、称臣、讨伐、借兵、招降
```

执行链路要求：

```text
SovereignAgent / StrategistAgent / GovernorAgent / DiplomatAgent
  -> StrategicDirectiveEnvelope 或 TheaterDirectiveEnvelope
  -> decoder / validator / compiler
  -> ZoneDirective / Command
  -> WarCommandExecutor / RuleEngine
  -> WarDirectiveRecord / AgentDecisionRecord / Diplomacy record
```

结构化输出要求：

- 所有 Agent 输出必须 Codable。
- 所有外部模型输出必须 fenced JSON 或纯 JSON，由 decoder 校验。
- decoder 必须校验 schemaVersion、turn、issuerId、power/faction、zone、region、tactic。
- decoder 失败时走安全 fallback，不执行半成品。
- Agent prompt 中不能要求模型直接修改状态。

Agent 个性建议：

- 李渊：稳健、重政治合法性、重关中安全。
- 李世民：进取、善集中兵力、偏好机动穿插和关键决战。
- 刘文静/裴寂：可作为谋主风格差异，前者进取，后者守成。
- 王世充：守洛阳、重政治操弄、偏好坚城防御和离间。
- 李密：瓦岗机动强、争粮仓、易冒进。
- 窦建德：河北稳健、民心/义军凝聚，偏好稳扎稳打。
- 薛举/薛仁杲：陇右强攻，偏好快速压迫关中。
- 刘武周/宋金刚：北线骑兵，偏好突袭太原和截断河东。
- 东突厥：以威胁、借兵、边境压力为主，首版不必完整战术微操。

推荐并发：

- AI Agent：Agent schema、prompt builder、fallback。
- Rules Agent：外交/内政 directive 的 validator 和 executor 边界。
- UI Agent：AI 决策复盘面板显示层。
- Docs / QA Agent：更新 flowchart。

验收：

- AI 回合能解释“君主想要什么、谋主选哪里、行军总管做了什么”。
- 玩家能在 AI 面板看到结构化摘要、编译后的 directive、命令结果和拒绝原因；raw JSON 仅限开发 / 审计模式或折叠诊断区。
- Agent 决策失败不会破坏回合。
- 仍未绕过 `RuleEngine`。

### v3.5：玩家军令、州郡经营、外交和战报体验

历史阶段标签：`v3.5-suitang-player-command-ux`

目标：

- 让玩家不是只点单位移动，而是能通过历史策略界面理解和操控局势。
- 形成“军令、州郡、将领、战报、外交”闭环。

玩家操作应包括：

- 选择军队：移动、攻击、固守、允许撤退、补给/整军。
- 选择州郡：查看控制比例、粮草、民心、城池/关隘、驻军、收入。
- 选择将领/方面：下达固守、进军、围城、合围、截粮、驰援。
- 查看外交：敌我关系、停战、归附、突厥压力、正朔/天命。
- 查看战报：本回合行动、占领变化、围城进展、粮草警告、AI 决策摘要。

边界：

- UI 只提交 `Command` 或 `ZoneDirective`。
- 玩家宏观军令也必须经过 `WarCommandExecutor`。
- 州郡经营命令如征发/屯田/修道可后置；若实现，必须走 `Command` + validator。

推荐文件：

- `WWIIHexV0/App/AppContainer.swift`
- `WWIIHexV0/UI/RootGameView.swift`
- `WWIIHexV0/UI/CommandPanelView.swift`
- `WWIIHexV0/UI/RegionInspectorView.swift`
- `WWIIHexV0/UI/GeneralCommandPanelView.swift`
- `WWIIHexV0/UI/EventLogView.swift`
- `WWIIHexV0/UI/AgentPanelView.swift`
- `WWIIHexV0/UI/EconomyPanelView.swift`
- `WWIIHexV0/UI/DiplomacyPanelView.swift`

验收：

- 玩家能在 1-2 次点击内找到当前可行动军队和结束回合。
- 选择州郡能看懂为什么它重要。
- 将领军令有清楚的目标、可执行条件和结果反馈。
- 拒绝原因不静默吞掉。

### v3.6：发布级 UI、美术和交互收口

历史阶段标签：`v3.6-suitang-ui-art-polish`

目标：

- 把当前工程从开发调试界面提升到可发布演示界面。
- 不靠说明文字堆叠，而靠地图、面板、状态、动效让玩家理解当前战局。

视觉方向：

- 主地图：绢帛/古地图质感，但不要整屏单一米色。用地形色、势力旗色、墨线、朱印、青绿河流和铜色 UI 形成层次。
- 势力：每个势力有旗色、印章图标、简短称号。
- 城池：城市、关隘、粮仓、渡口、港口有不同图标。
- 部队：棋子/军牌区分步、骑、弓、器械、守军，显示 strength、行动状态、粮草警告。
- 将领：头像或风格化印章、姓名、字/称号、统率/武勇/谋略/政务/威望、忠诚、野心、技能。
- 战线：用墨线/朱线表现敌我接触，用箭头表现计划行动，用粮道虚线表现补给。
- 战报：用简洁列表展示关键行动、拒绝原因、占领变化、外交事件。

主界面布局建议：

```text
顶部：回合、当前势力、资源、天命/民心、胜利状态、结束回合
中央：SpriteKit 战场地图，全屏优先
左侧或底部：选中对象摘要，移动端可折叠
右侧或底部：军令 / 州郡 / 将领 / 战报 / 外交 / AI tabs
地图上：选中、可移动、可攻击、计划线、前线、粮道、围城状态
```

SwiftUI 要求：

- 建立 `SuitangDesignTokens` 或类似共享设计常量。
- 44pt 最小触控区。
- 使用系统控件和 `Label`，图标优先，不用解释性文字堆满界面。
- 避免 body 内重复排序、过滤、JSON 格式化。
- 大列表用 Lazy 容器。
- 复杂面板拆成独立 View。
- 不引入第三方框架，除非人工确认。

SpriteKit 要求：

- 地图必须在 iOS 和 macOS 都可缩放、平移、点击。
- 文字不能重叠到不可读。
- 单位和城池图标有稳定尺寸，不因状态变化造成跳动。
- 图层切换清晰：地形、州郡、势力、方面、前线、粮道、AI 计划。

推荐并发：

- UI Agent：SwiftUI 面板、设计 token。
- SpriteKit Agent：地图绘制、单位、图层、箭头。
- Data/Art Agent：头像占位、旗帜、图标资源和 asset catalog。
- Docs / QA Agent：截图检查清单和未跑重测试风险。

验收：

- 主游戏第一屏不再像调试板。
- 主要 UI 无二战文案残留。
- 移动端和 macOS 布局都有明确约束。
- UI 只读状态，操作仍走 `AppContainer` 和规则系统。

### v3.7：存档、新手引导、设置和发布候选

历史阶段标签：`v3.7-suitang-release-candidate`

目标：

- 从“能跑的迁移版”收口到“可发布候选版”。
- 补齐玩家初次体验、错误恢复、存档、版本说明和发布前检查。

历史发布候选目标曾要求具备：

- App 名称、图标、默认剧本、主界面、基础设置。
- 新局 / 继续 / 重置。
- 一个完整可玩剧本。
- AI 回合不会卡死或静默失败。
- 玩家可理解的命令反馈。
- 关键 JSON 数据可解析。
- README 和 flow 文档准确描述当前隋唐架构。
- `update_log.md` 记录 v3.0-v3.7 每版完成内容、关键文件、轻量检查和未跑重测试。

发布前需要人工授权的本机 / 人工运行时重验证：

- Xcode build。
- iOS Simulator 或真机启动。
- macOS target 启动。
- 至少 10-20 回合观察者模式。
- 基础 UI 点击烟测。
- 性能体感检查。

GitHub Actions 结果包核对不是可选发布功能：凡 Agent B push `main` 后，Agent C 必须按 `AGENTS.md` 和 `md/test/test.md` 下载并核对最新 run 的未加密 artifact、manifest、JUnit/摘要、日志、run id、run attempt 和 commit。

在未获授权前，不得声称“已可发布”。只能写“发布候选代码和文档已准备，运行时验证未授权，风险未验证”。

### v3.8：真实本地 LLM / 可插拔模型接入

历史阶段标签：`v3.8-suitang-local-llm`

目标：

- 在 deterministic Mock / 模拟 LLM 稳定后，再接入真实本地模型或可插拔模型接口。
- 保持离线可运行和失败 fallback。

要求：

- 不提交 API key、模型路径、个人机器路径。
- 模型不可用时回退 MockAI。
- 所有模型输出仍走 JSON decoder / validator。
- 模型 prompt 只能要求输出 directive，不允许要求直接改状态。
- AI 面板默认显示结构化摘要、模型来源、解析错误和 fallback 原因；raw JSON 仅限开发/审计模式或折叠诊断区。

---

## 6. 数据 schema 方向

实际实现可沿用现有结构，但必须在阶段文档写明哪些字段是兼容旧名、哪些字段已经隋唐化。

### 势力

```json
{
  "id": "power_tang",
  "displayName": "唐",
  "rulerName": "李渊",
  "shortName": "唐",
  "capitalRegionId": "region_changan",
  "rulerAgentId": "sovereign_li_yuan",
  "bannerAsset": "banner_tang",
  "primaryColor": "#8A1F1F",
  "secondaryColor": "#D6B15E",
  "legitimacy": 68,
  "mandate": 62,
  "warSupport": 76
}
```

### 将领

```json
{
  "id": "general_li_shimin",
  "name": "Li Shimin",
  "localizedName": "李世民",
  "courtesyName": "",
  "rank": "秦王",
  "faction": "tang",
  "commandStyle": "bold",
  "attributes": {
    "command": 96,
    "valor": 82,
    "strategy": 94,
    "governance": 78,
    "prestige": 92
  },
  "skills": ["mobile_warfare", "decisive_battle", "morale"],
  "biography": "善用骑兵机动与集中决战，适合承担关中外线攻势。",
  "preferredRegionIds": ["region_changan", "region_hedong", "region_luoyang"],
  "baseLoyalty": 90,
  "baseSatisfaction": 82
}
```

### 州郡

```json
{
  "id": "region_luoyang",
  "name": "洛阳",
  "owner": "luoyangSui",
  "controller": "luoyangSui",
  "terrain": "city",
  "city": {
    "name": "洛阳",
    "victoryPoints": 7,
    "isCapital": true
  },
  "infrastructure": 6,
  "supplyValue": 6,
  "resources": [
    { "type": "grain", "amount": 5 },
    { "type": "craft", "amount": 3 }
  ],
  "coreOf": ["luoyangSui", "tang"]
}
```

### Agent directive 示例

```json
{
  "schemaVersion": 1,
  "turn": 3,
  "issuerId": "strategist_liu_wenjing",
  "power": "tang",
  "posture": "offensive",
  "rationale": "洛口仓为河洛粮道关键，夺取后可削弱洛阳守势。",
  "directives": [
    {
      "zoneId": "zone_guanzhong_east",
      "type": "attack",
      "tactic": "pincerMovement",
      "targetRegionIds": ["region_hulao", "region_luokou_granary"],
      "focusRegionId": "region_hulao",
      "intensity": "limitedCounter"
    }
  ]
}
```

---

## 7. 文档更新要求

每个版本完成后至少更新：

- `update_log.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- 当前版本实现记录，例如：
  - `md/prompt/v3.0-隋唐迁移/v3.0_audit_and_contract.md`
  - `md/prompt/v3.0-隋唐迁移/v3.1_powers_diplomacy_record.md`
  - `md/prompt/v3.0-隋唐迁移/v3.2_scenario_map_record.md`

当项目身份正式从 WWII 迁移到隋唐后，才更新：

- `AGENTS.md` 的项目总览和基本规则。

`README.md` 的当前进度、架构口径和验证状态应随实际源码行为同步更新；`AGENTS.md` 的项目身份和基本规则变更需人工明确授权。

不要在只完成提示词或审计时伪装成正式版本完成。

---

## 8. 轻量检查要求

执行任何版本前必须读 `md/test/test.md`。当前默认只允许轻量检查。

通用允许项；以下是本阶段建议的轻量文本检查模板，若与 `md/test/test.md` 冲突，以 `md/test/test.md` 为准。轻量检查优先针对本轮改动文件执行；只有文档同步、并发整合或冲突扫描需要时，才扩大到相关目录。禁止用本机 Xcode/build/test 替代云端验证。

```sh
rg -n "[[:blank:]]+$" AGENTS.md README.md update_log.md md/test/test.md md/flow/flow.md md/flow/flowchart.md md/prompt/v3.0-隋唐迁移
rg -n "<{7}|={7}|>{7}" AGENTS.md README.md update_log.md md/test/test.md md/flow WWIIHexV0 MapEditor
git diff --check
```

JSON 改动：

```sh
jq empty WWIIHexV0/Data/wude_618_scenario.json
jq empty WWIIHexV0/Data/wude_618_regions.json
jq empty WWIIHexV0/Data/suitang_unit_templates.json
jq empty WWIIHexV0/Data/suitang_generals.json
jq empty WWIIHexV0/Data/suitang_power_profiles.json
```

project 改动：

```sh
plutil -lint WWIIHexV0.xcodeproj/project.pbxproj
```

Swift 轻量 parse：

```sh
swiftc -parse path/to/ChangedFile.swift
```

如果 Swift 文件依赖 SwiftUI、SpriteKit、跨文件类型或 SDK 导致单文件 parse 不可靠，立即停止，记录“未做语法检查，需授权 Xcode build 确认”，不要扩大为全项目构建。

如果 `jq`、`swiftc`、`xmllint` 等轻量工具不存在，记录“工具缺失，未执行该项”，不得改跑全项目构建或本机重测试替代。

禁止默认执行：

- `xcodebuild build`
- `xcodebuild test`
- `xcodebuild build-for-testing`
- `xcrun simctl`
- Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full
- 模拟器启动
- app 启动
- 性能测试

---

## 9. 验收总标准

每个阶段最终回复必须包含：

1. 完成了什么。
2. 改了哪些关键文件。
3. 跑了哪些轻量检查，具体结果是什么。
4. 哪些重测试没跑，原因是什么。
5. 还剩什么风险或下一步。

v3.7 发布候选的最终验收额外要求：

- 主 UI 和默认数据无主要二战残留。
- 默认剧本是隋唐剧本。
- 多势力关系不依赖二元 `opponent`。
- AI Agent 决策可追踪到 JSON、directive、command result。
- 玩家命令和 AI 命令仍共用规则管线。
- MapEditor 能维护隋唐地图语义。
- 文档与代码口径一致。
- 如果没有人工授权重测试，必须明确“运行时发布风险未验证”。

---

## 10. 给执行 Agent 的起步指令

请按下面顺序开始，不要跳步：

1. 阅读 `AGENTS.md`、`update_log.md`、`md/flow/flow.md`、`md/flow/flowchart.md`、`md/test/test.md`、本文件。
2. 读取当前源码中与目标版本有关的文件，不凭旧记忆修改。
3. 先做当前工作树和分支审计，不回滚用户改动。
4. 除非人工明确要求历史补录，不得把 v3.0-v3.7 历史路线当成待办重做。
5. 从 §0.2 当前候选队列或人工新目标中选择一个清晰切片；先确认相关历史记录与源码一致。
6. 需要并发时，主 Agent 先给子 Agent 分文件边界和输出格式；并发子 Agent 只属于单轮内部拆分，默认不建候选分支，不 push。
7. 子 Agent 完成后，主 Agent 做冲突整合检查。
8. 只跑 `md/test/test.md` 允许的轻量检查。
9. 同步文档。
10. 最终回复按项目交付格式写清楚结果、检查和风险。

`md/prompt/README.md` 是通用摘要；若与 `AGENTS.md` 或本文件有详略差异，Agent A/B/C 仍必须按 `AGENTS.md` 执行角色职责。尤其是 Agent C 完成云端 artifact 核对后，仍需按 `AGENTS.md` 更新 `md/flow/*`，必要时更新 `update_log.md`。

本迁移任务的核心难点不是写更多功能，而是守住三条线：

- 规则权威线：所有行动仍归 `RuleEngine`。
- 状态权威线：hex 和动态映射不能被战略层反向覆盖。
- Agent 审计线：AI 输出必须结构化、可验证、可回放。
