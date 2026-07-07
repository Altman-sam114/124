# WWIIHexV0 — iOS / macOS AI 战略战棋骨架

> **当前状态：v0.5 元帅决策链分支骨架 + v3.7-preflight.102 隋末唐初迁移前置收口。** 主游戏默认优先加载 `wude_618_guanzhong_luoyang` 隋唐剧本，失败时 fallback legacy 阿登资源；战争 AI 主链路是 `MarshalAgent -> TheaterDirectiveDecoder -> TheaterDirectiveCompiler -> CourtAgent / RulerAgent -> ZoneDirective -> WarCommandExecutor -> RuleEngine`。当前已完成多势力兼容、默认隋唐数据、兵种/粮道/围城最小迁移、朝堂审计、玩家信息闭环、UI/地图视觉基底、胜负闭环、本地存档、外交/州郡经营命令、AI 太守/使者/归附交接、善后记录链、发布检查静态门禁、多轮玩家可见文案收口、本局执掌势力选择、MapEditor 隋唐资源桥与可见文案收口、默认数据说明和补给战报中文化、AI 元帅/方面军令摘要中文化、Legacy MockAI 与元帅解析诊断中文化、legacy fallback JSON 可见文本收口、legacy 将领档案可见文本和技能显示收口、Agent 诊断/错误兜底文案收口、自动回合与元帅诊断兜底文案收口、数据加载与导出说明可见文案收口、复核面板与记录摘要可见文案收口、MapEditor 与主游戏 raw id 可见文案复扫收口、命令错误与源头战报可见文案收口、总管与将领档案防区展示名 raw id 收口、legacy fallback 数据展示文案收口、legacy fallback 单位与防区展示文案收口、legacy static fallback 目标兼容与展示文案收口、legacy LLM prompt 语言收口、外交面板名称和记录净化收口、战报意图屏蔽与中文分类收口、MapEditor 导出元数据 fallback 收口、AI 诊断净化口径对齐、legacy 总管配置中文兜底、legacy prompt 内部编号分层收口、legacy prompt 直通文本净化、legacy prompt 决策者身份净化、legacy MockAI stance 文案收口、legacy prompt 工程说明词收口、模拟元帅输出纯 JSON 收口、UI/战报/外交记录净化 helper 顺序与词表对齐、legacy 将领与朝堂记录可见文案复扫、CommandPanel 命令消息展示净化收口、单位详情与提示 legacy 单位名展示收口、州郡详情 legacy 地名与目标名展示收口、将领与总管面板 legacy 可见文案复扫收口、MapDisplayAdapter / SpriteKit 地图展示入口 legacy 文案收口、MapEditor 选择器与状态消息 legacy 文案收口、AppContainer 交互日志与存档反馈 legacy 文案收口、GameLogEntry 源头战报 legacy 文案收口、legacy LocalLLM prompt 临时编号别名收口、legacy fallback 行军总管配置收口、朝堂/外交实际记录 id 展示净化收口、行军总管可见称谓净化收口、源头 legacy 中文势力/国家/地名展示净化收口、将领档案/总管军令称谓净化对齐、fallback JSON 可见数据文本收口、源码层 legacy 可见兜底文本收口、静态 GameState / MapState fallback 可见文本收口、legacy objective lookup 字面量收口、RegionVictoryRules 隋唐胜负摘要对齐、共享隋唐胜负 evaluator 收口、指令结果语义化固守判定收口，阶段与旧总管展示口径收口，自动总管默认指挥风格收口，默认指挥风格共享 helper 收口，DataLoader 场景阶段兜底收口，legacy phase 存档规范化收口，动态方面推进势力兜底收口，RegionDataSet owner/controller 兜底收口，ScenarioSemantics 场景语义与胜负 fallback 门禁收口，MapEditor 非法 unit faction 导入诊断收口，归附善后治安压力落地，以及归附善后贡赋效率落地。正式地图资产、交接后的完整忠诚/叛乱/俘虏/安置实际效果、更完整朝堂决策、授权构建/启动/多回合运行验证和云端结果包验收仍未完成。

---

## 项目定位

本工程仍保留 `WWIIHexV0` 历史项目名和 Swift + SwiftUI + SpriteKit 技术骨架。当前目标是在不破坏已有 hex 战术权威、region 战略聚合、动态战区、前线、部署和统一命令管线的前提下，逐步迁移为可发布的隋末唐初 AI Agent 历史策略游戏。

首发迁移目标暂定为 `天命开唐 Agent`，默认剧本是 `武德元年：关中河洛争衡`。玩家默认执掌唐，也可在基础设置中选择当前局势内可玩的势力；其他势力由本地 AI / 朝堂链路推进。

---

## 核心边界

```text
MapEditor / JSON 数据
  -> DataLoader
  -> GameState
  -> HexTile.controller + Division.coord
  -> Region 聚合
  -> EconomyState
  -> Initial Theater snapshot + runtime hexToTheater
  -> FrontLine 动态 hex 接触
  -> WarDeployment hexToFrontZone
  -> MarshalAgent / CourtAgent / RulerAgent
  -> ZoneDirective
  -> WarCommandExecutor
  -> RuleEngine
  -> StrategicStateSynchronizer
  -> UI / EventLog / 审计记录
```

必须持续遵守：

- Hex 是战术权威：单位位置、移动、攻击、真实占领、视野、补给落点以 hex 为准。
- Region 是战略聚合层：资源、人力、补给、胜利点、控制比例从 hex 状态聚合，不替代 hex。
- `regionToTheater` 是初始/基础方面归属和 MapEditor 种子，不是运行时推进层。
- `hexToTheater` 是运行时动态方面权威；突破一个 hex 只能推进该 hex。
- `hexToFrontZone` 是部署层动态归属权威；`regionToFrontZone` 只能作 dominant / fallback。
- 玩家、AI、聊天命令和 MockAI 都必须落到 `Command` / `ZoneDirective`，再经 `WarCommandExecutor`、`CommandValidator`、`RuleEngine` 执行。
- Legacy Agent D 管线保留作回归参考，默认战争 AI 主路径不得退回旧管线。
- 不恢复 organization；当前战斗核心仍是 strength、retreat、supply、encirclement。

---

## 技术栈

| 层级 | 技术 |
|---|---|
| 平台 | iOS；另有 macOS 主游戏与 MapEditor 方向 |
| 语言 | Swift |
| UI | SwiftUI |
| 地图渲染 | SpriteKit |
| 数据 | JSON scenario / region / unit template / general / terrain rule |
| AI | 本地模拟 LLM / MockAI fallback，结构化 directive，经规则系统执行 |

---

## 目录结构

```text
WWIIHexV0/
├── Core/          核心数据模型：GameState、MapState、Faction、Division 等
├── Commands/      Command、ZoneDirective、校验与意图适配
├── Rules/         RuleEngine、CommandExecutor、SupplyRules、VictoryRules 等
├── Agents/        MarshalAgent、CourtAgent、RulerAgent、ZoneCommanderAgent、记录与解析
├── Turn/          TurnManager：AI/观战自动回合编排
├── SpriteKit/     BoardScene、HexNode、UnitNode、地图叠加层
├── UI/            HUD、战报、外交、州郡、军令、设置、发布检查等面板
├── App/           AppContainer、GameSaveStore、App 入口
├── Data/          默认隋唐 JSON 与 legacy 阿登 fallback 资源
├── Probes/        历史探针测试，当前默认不执行
└── Tests/         历史测试，当前默认不执行

MapEditor/
├── MapEditorDocument.swift
├── MapEditorView.swift
├── MapEditorViewModel.swift
├── MapEditorExporter.swift
└── MapEditorGameResourceBridge.swift
```

---

## 当前完成进度

### v3.7-preflight.102：归附善后贡赋效率落地

- `EconomyRules.income(for:map:)` 聚合受控州郡收入时，会按 `OccupationState` 计算贡赋效率。
- 抵抗会折减丁口、军械、粮草收入；顺从提高会恢复效率，但不超过既有基础产出。
- 边界：不新增命令、存档字段、叛军单位、额外归属转移、忠诚、俘虏或安置系统；完整归附善后实际规则仍待后续独立切片。

### v3.7-preflight.101：归附善后治安压力落地

- `CommandExecutor.executeSubmissionHandoff` 在生成 `SubmissionAftermathRecord` 后，会按风险等级提高受影响州郡的治安压力并降低顺从。
- 善后压力落地会追加外交战报，提示哪些州郡治安承压，需要太守安民或整修支撑。
- 边界：不新增命令、存档字段、叛军单位、额外归属转移、贡赋、俘虏、忠诚或安置系统；完整归附善后实际规则仍待后续独立切片。

### v3.7-preflight.100：MapEditor 非法 unit faction 导入诊断收口

- `MapEditorGameResourceBridge.makeDocument` 导入默认游戏资源时，非法 `unit.faction` 不再静默 fallback 到 `.allies`。
- 坏 unit 会被跳过并生成 `MapEditorGameResourceImportDiagnostic`，`MapEditorViewModel` 会在默认资源读取状态中提示跳过数量和原因。
- 边界：不改 JSON schema、合法 unit faction、默认资源文件名、主游戏加载顺序、命令管线、规则执行或存档字段。

### v3.7-preflight.99：场景语义与胜负 fallback 门禁收口

- 新增共享 `ScenarioSemantics`，集中判断明确旧战局、明确 `wude_618`、隋唐草稿和未知自定义场景。
- `DataLoader`、`GameState`、`AgentConfiguration`、`AppContainer`、`VictoryRules` 和 `RegionVictoryRules` 复用该语义门禁；未知自定义场景不再静默套用旧默认势力或旧胜负 fallback。
- 边界：不改合法 JSON、`Faction` rawValue、`GamePhase` rawValue、旧战局兼容、默认隋唐胜负 evaluator、命令管线或存档 schema。

### v3.7-preflight.98：RegionDataSet owner/controller 兜底收口

- `RegionDataSet.toRegions()` 对非 legacy 数据缺 owner 改为抛出数据校验错误，不再把任意缺省州郡静默 fallback 到 `.allies`。
- 明确旧战局 RegionDataSet 仍保留 `.allies` 兼容 fallback；`controller` 缺省继续回退 owner。
- 边界：不改 JSON schema、不新增 neutral、不改 region 聚合、hex 权威、命令管线、规则执行或存档字段。

### v3.7-preflight.97：动态方面推进势力兜底收口

- `WarCommandExecutor.applyStrategicAdvance` 不再在缺失 advancing zone faction 时把动态方面推进势力兜底为 `.germany`。
- 推进势力现在优先来自 `frontZones[advancingZoneId].faction`，异常缺 zone 时回退实际行动军队；两者都无法确认时跳过本次动态方面推进并记录原因。
- 边界：不改 hex 占领、`hexToTheater` / `hexToFrontZone` 权威、同步器主逻辑、命令 schema、规则数值、AI 决策或存档字段。

### v3.7-preflight.96：legacy phase 存档规范化收口

- `GamePhase` 新增按 `activeFaction` / `playerFaction` 规范化旧阶段的 helper，保留合法 legacy 阿登阶段，脏存档或自定义隋唐场景会落回通用 `playerCommand` / `aiCommand`。
- `GameState` 解码、`AppContainer` 启动/继续/新局/切换执掌势力、玩家交互守卫、`CommandValidator`、`CommandExecutor` 和 `TurnManager` 复用同一 phase 规范化口径。
- 边界：不改 `GamePhase` case/rawValue/Codable、合法阿登双势力回合推进、命令 schema、规则数值、AI 决策或存档字段。

### v3.7-preflight.95：DataLoader 场景阶段兜底收口

- `DataLoader` 现在先按场景解析一次初始阶段，再复用到 `GameState.phase`、`activeFaction` 和初始战报 phase。
- 无效 `initialPhase` 时，legacy 阿登场景仍 fallback 到 `.alliedPlayer`，隋唐或未知自定义场景 fallback 到 `.playerCommand`。
- 无效 `playerFaction` 时，legacy 阿登 fallback `.allies`，隋唐或未知自定义场景 fallback `.tang`，避免自定义隋唐路径回到 legacy 阵营口径。
- 边界：不改合法 JSON、`GamePhase` case/rawValue、旧阿登显式阶段、命令管线、规则执行、AI 决策或存档 schema。

### v3.7-preflight.94：默认指挥风格共享 helper 收口

- `ZoneCommanderAgentConfig.CommandStyle.defaultForFaction(_:)` 集中维护自动方面总管默认指挥风格映射。
- `TheaterCommanderPool.defaultConfig(for:)` 和 `AppContainer.buildCommanderPool(state:registry:)` 不再各自维护重复 switch，统一调用共享 helper。
- 边界：不改 `CommandStyle` case、rawValue、Codable、`.cautious` case、AI 阈值、directive schema、命令管线、规则执行、势力 rawValue 或存档格式。

### v3.7-preflight.93：自动总管默认指挥风格收口

- `ZoneCommanderAgent.defaultConfig(for:)` 不再用 `.germany` 二元判断决定自动方面总管默认指挥风格，改为按多势力映射选择 `.aggressive` / `.balanced`。
- 默认风格与 `AppContainer` 默认配置口径对齐：旧东路势力、唐、瓦岗、薛秦、刘武周默认主动；旧西路势力、洛阳隋、夏、东突厥默认均衡。
- 边界：不改 directive schema、命令管线、规则执行、AI 阈值、战术选择函数、势力 rawValue 或存档格式；重复映射维护风险已在 v3.7-preflight.94 收口。

### v3.7-preflight.92：阶段与旧总管展示口径收口

- `GamePhase.displayName` 的自动行动阶段从 `AI 行动` / `AI 军令` 改为 `朝堂行动` / `朝堂军令`，HUD、引导、命令面板和 legacy prompt 自由文本继续使用玩家语义。
- `general_agents.json` 中 legacy `guderian` 配置的展示名改为“历史总管”，保留 `guderian` id、`.germany` rawValue、legacy 单位 id 和 `breakthrough` command style。
- 边界：不改 `GamePhase` rawValue、Codable、回合推进、自动行动判定、JSON schema、DataLoader 校验、AI 决策、命令管线、规则或存档。

### v3.7-preflight.91：指令结果语义化固守判定收口

- `CommandResultSummary` 新增可选 `commandKind`，新生成的 AI / directive / 系统命令结果会记录命令语义，不再只保存展示名。
- `ZoneCommanderAgent` 的最近静态防御判断改为读取 `commandKind == .hold`，不再依赖旧英文 `Hold` 或当前中文“坚守”展示文本。
- 边界：不改 `Command` case、命令显示名、directive schema、AI tactic 选择阈值、规则执行或 Xcode project。

### v3.7-preflight.90：共享隋唐胜负 evaluator 收口

- 新增 `VictoryAssessment`，并在规则层新增 `Wude618VictoryEvaluator`，集中维护默认隋唐剧本洛阳、洛口仓、潼关和终局长安胜负判断。
- `VictoryRules` 和 `RegionVictoryRules` 共同复用 `Wude618VictoryEvaluator`，避免主胜负状态和 region 分析摘要分叉。
- 边界：不改 legacy fallback 胜负规则、objective id、地图数据、胜负阈值、命令管线、AI 决策、存档格式或 Xcode project。

### v3.7-preflight.89：RegionVictoryRules 隋唐胜负摘要对齐

- `RegionVictoryRules.assessVictory(in:)` 按 `scenarioId` 分支：默认 `wude_618_guanzhong_luoyang` 使用洛阳、洛口仓、潼关、长安 objective id 生成 region 层胜负摘要。
- legacy fallback 摘要仍保留旧 objective id 和中性目标名兼容，不影响旧回归路径。
- 边界：不改 `VictoryRules` 主胜负执行路径、`GameState.victoryState`、`VictoryState` 字段、objective id、胜负阈值、命令管线或存档格式。

### v3.7-preflight.88：legacy objective lookup 字面量收口

- `VictoryRules` / `RegionVictoryRules` 的旧 fallback 胜负目标查找改为 objective id 优先，并只 fallback 到中性“旧战局要地甲 / 旧战局要地乙”展示名。
- `MockAIClient` 的旧回归目标查找同样改为 id 优先加中性目标名 fallback，注释和局部变量去旧战役地名口径。
- 边界：不改 objective id、胜负阈值、AI 策略、`VictoryState` 存档字段、`VictoryReason` case、命令管线或存档格式。

### v3.7-preflight.87：静态 fallback 源码可见文本收口

- `GameState.initial()` 的最后兜底单位名和初始化战报改为中性旧战局口径。
- `MapState.ardennesV0()` 的最后兜底城邑、要塞和 objective 展示名改为中性旧战局口径。
- 边界：不改 scenario id、objective id、faction、坐标、地形、补给源、胜负规则、加载顺序、命令管线或存档字段。

### v3.7-preflight.86：源码层 legacy 可见兜底文本收口

- `Faction.displayName` 的 legacy 势力显示改为“旧剧本东路势力 / 旧剧本西路势力”，避免 HUD、发布检查或错误反馈直出旧题材势力名。
- `VictoryReason.displayName` 的 legacy 胜负原因改为中性旧战局目标、主力和断粮口径，保留 enum case / rawValue 兼容。
- `DataLoader` 的旧战局补给源和代理配置校验错误改为中性描述；边界：不改 enum rawValue、JSON schema、id、兼容查找、胜负判定、加载顺序、命令管线、规则或存档。

### v3.7-preflight.85：fallback JSON 可见数据文本收口

- `ardennes_v0_scenario.json` 的 legacy fallback 场景名、dataNotes、初始单位名、地点名、粮站名和 map cityName 改为中性旧战局口径。
- `ardennes_v02_regions.json` 的 legacy fallback 数据集名、region 名和 city 名补齐中性展示文本。
- `unit_templates.json` 与 `generals.json` 的旧单位模板展示名、将领可见名、军衔和履历改为迁移期中性称谓；边界：不改 JSON key、id、rawValue、schema、坐标、加载顺序、命令管线、规则或存档。

### v3.7-preflight.84：将领档案/总管军令称谓净化对齐

- `GeneralProfileView` 与 `GeneralCommandPanelView` 的 `Field Marshal` 展示统一为“行军总管”，对齐 Agent / 战报 / 外交面板口径。
- 将领档案和总管军令中的 `Guderian / 古德里安` 展示从“旧剧本将领”统一为“历史总管”。
- 空单位名 fallback 改用 legacy 势力展示净化，避免将领相关面板在极端旧数据下直出旧势力名；边界：不改 `GeneralData`、`Division.name`、`AgentRole` rawValue、JSON、命令管线、规则或存档。

### v3.7-preflight.83：源头 legacy 中文势力/国家/地名展示净化收口

- `TurnManager` 的自动回合失败、方面军令诊断和错误展示净化补齐 legacy 中文势力、旧国家、旧地名、旧单位词和英文势力词。
- `DiplomacyState` 的外交事件、归附交接、善后压力和善后处置摘要改走展示 helper，旧国家中文名在摘要中统一为“旧剧本国家”。
- `GameLogEntry` 源头战报净化补齐 `Guderian`、`Field Marshal`、`Germany`、`Allies`、`rawJSON`、`schema`、`provider` 等残留词；边界：不改数据、rawValue、schema、命令管线、规则或存档。

### v3.7-preflight.82：行军总管可见称谓净化收口

- `AgentPanelView` 的 `MarshalDirective` 来源显示从“元帅军议”改为“军议”，`AgentRole.fieldMarshal.displayName` 改为“行军总管”。
- `AgentPanelView`、`EventLogView`、`DiplomacyPanelView` 的 `Field Marshal` 展示净化统一为“行军总管”，外交记录里的裸 `Guderian` 统一为“历史总管”。
- `CommandPanelView` / `EventLogView` 补齐 `directive_*command_*`、`order_*` 和朝堂 agent 前缀记录展示净化；边界：不改 rawValue、provider suffix、record id、schema、命令管线、规则或存档。

### v3.7-preflight.81：朝堂/外交实际记录 id 展示净化收口

- `TurnManager` 在 `courtRecord.summary` 进入 `parsedIntent`、战报事件和朝堂步骤展示文本前先做展示净化。
- `AgentPanelView`、`DiplomacyPanelView`、`EventLogView`、`CommandPanelView`、`GameLogEntry` 和 `AgentPromptBuilder` 补齐真实 `ruler_*_turn_*`、`court_*_turn_*`、`court_<turn>_*`、`diplomacy_<turn>_*` 记录 id 的展示净化。
- `DiplomacyState.summary(for:)` 把“敌对关系 N 条”修正为“敌对国家 N 个”，匹配实际去重国家计数；边界：不改记录 id、Codable schema、`relatedRecordId`、外交判定、命令管线、规则或存档。

### v3.7-preflight.80：legacy fallback 行军总管配置收口

- `GameAgent.guderian(from:state:)` 和 `guderianFallback` 不再把旧 Guderian / Germany / `ger_*` 默认单位作为可见 fallback 指挥官配置。
- `MarshalAgentConfig.automatic` 的 legacy `.germany` / `.allies` 分支改为中性“旧剧本势力行军总管”，模拟军议 directive id 前缀从 `marshal_` 改为 `command_`。
- 边界：不改 `MarshalAgentConfig`、`MarshalBattlefieldSummary`、`MarshalLLMClient`、`DirectiveEnvelope` / `TheaterDirectiveEnvelope` schema、Faction enum、JSON 数据、命令管线、规则或存档格式。

### v3.7-preflight.79：legacy LocalLLM prompt 临时编号别名收口

- `AgentPromptBuilder` 的势力、目标、军队、州郡和编号旁说明名进入 prompt 前先做展示净化，补齐 legacy 势力名、旧地名、旧单位词、模型/工程词和 `objective_*` raw id。
- `AgentPromptAliasBook` 把 prompt 中可选取的 `divisionId` / `targetDivisionId` / `toRegionId` / `agentId` 值显示为“军队一 / 敌军一 / 州郡一 / 本地决策者”等临时编号，`LocalLLMDecisionProvider` 解析后再回填真实 id。
- 边界：不改 `AgentDecisionEnvelope` / `AgentOrder` schema、JSON 字段名、type rawValue、parser / mapper、命令结构、AI 默认主链路、规则或存档格式。

### v3.7-preflight.78：GameLogEntry 源头战报 legacy 文案收口

- `GameLogEntry.init(...)` 对写入 `message` 的文本做源头展示净化，覆盖 Rules / Commands / Data / Core 等 `appendEvent` 和直接 `GameLogEntry(...)` 构造路径。
- 净化清理常见审计 id、raw id、legacy 势力名、旧地名和旧题材单位词，避免 `gameState.eventLog` 绕过 `AppContainer` 交互日志净化。
- 边界：不改 `GameState.eventLog` 字段结构、`GameLogEntry` schema、`relatedRecordId` 合同、规则数值、命令执行、数据层名称、JSON、AI 决策或存档格式。

### v3.7-preflight.77：AppContainer 交互日志与存档反馈 legacy 文案收口

- `AppContainer` 的存档载入、继续、自动保存、新局、切换执掌势力、军队点击、州郡经营拒绝、地图选择和总管防区提交消息改走局部展示 helper。
- 展示 helper 清理 legacy 势力名、旧地名、旧单位词和常见 raw id；fallback 临时总管 / 自动总管名称也复用同一口径。
- `submit(_:)` 的交互日志在 AppContainer 层净化外交 / 归附命令标题，不改 `Command.displayName` 合同。
- 边界：不改 `GameState`、存档 schema、`GameLogEntry`、`Command`、`Division.name`、`RegionNode.name`、`FrontZone.name`、JSON、id / rawValue、AI 决策、命令结构或规则执行。

### v3.7-preflight.76：MapEditor 选择器与状态消息 legacy 文案收口

- `MapEditorView` 的“当前州郡”“当前方面”下拉项改走 `MapEditorViewModel.displayName(for:)`，不再直接显示 document 中的 raw name。
- `MapEditorViewModel` 的 display helper 清理常见 raw id、legacy 地名、旧势力词和旧“战区”口径；创建州郡、创建方面、保存地点、删除地点状态消息显示前先净化。
- 边界：不改 `MapEditorDocument`、导出 JSON、id / rawValue、默认资源桥、MapEditor 存储 schema、主游戏数据加载、地图规则、AI、命令或运行时状态。

### v3.7-preflight.75：MapDisplayAdapter / SpriteKit 地图展示入口 legacy 文案收口

- `MapDisplayAdapter` 在 `cityName`、`fortressName` 和 objective name 进入 SpriteKit 地图标签或详情 UI 前做展示净化。
- 展示 helper 清理常见 raw id、legacy 地名、防区词和旧势力词；`RegionInspectorView`、`UnitInspectorView` 对既有 region / theater / front zone id 与 legacy faction display 做局部兜底，不扩展 adapter 状态合同。
- 边界：不改 `HexDisplayState`、`RegionInspectorState`、`UnitInspectorStrategicState` 字段结构，不改 JSON、rawValue、地图数据、objective id、keyLocations、`hexToTheater`、`hexToFrontZone`、AI、命令或规则。

### v3.7-preflight.74：将领与总管面板 legacy 文案复扫收口

- `GeneralProfileView` / `GeneralCommandPanelView` 的将领名、军衔、履历、防区名、所属军队、目标州郡和 accessibility 文案进入局部展示 helper。
- 展示 helper 清理 `general_*`、`agent_*`、`commander_*`、`front_zone_*`、`theater_*`、`region_*`、`division_*`、`unit_*` 等 raw id，并把 legacy 将领名、旧军阶、旧地名和旧兵种词转为迁移前置口径。
- 边界：不改 `GeneralData`、`GeneralAssignment`、`FrontZone`、`Division.name`、`PlayerPlannedOperation`、JSON、rawValue、存档、AI 决策、命令结构或规则。

### v3.7-preflight.73：州郡详情 legacy 地名与目标名展示收口

- `RegionInspectorView` 的州郡名、城邑名、方面名、防区名、要地名和驻军列表不再原样直出上游名称，改为局部展示 helper 兜底。
- 展示 helper 清理 `region_*`、`theater_*`、`front_zone_*`、`obj_*`、`hex_*`、`division_*`、`unit_*` 等 raw id，并把 legacy 地名 / 旧题材词转为发布前置口径。
- 边界：不改 region / hex / objective / division 存储、JSON、id、rawValue、objectiveId、keyLocations、胜负规则、地图数据、AI 决策、命令结构、规则执行或运行时状态。

### v3.7-preflight.72：单位详情与提示 legacy 单位名展示收口

- `UnitInspectorView` 的单位标题不再原样显示 `division.name`，改为本地展示 helper，清理 legacy 单位 raw id 和旧题材兵种词。
- `UnitTooltipView` 的可见标题与 VoiceOver `accessibilityLabel` 同步使用相同展示名，避免辅助功能继续读出旧 fallback 单位名。
- 边界：不改 `Division.name` 存储、JSON、templateId、rawValue、存档 schema、兵种显示权威、AI 决策、命令结构、规则执行或运行时状态。

### v3.7-preflight.71：CommandPanel 命令消息展示净化收口

- `CommandPanelView` 不再原样显示 `lastCommandMessage`，改为先清理常见 raw id，再替换 `Command`、`RuleEngine`、`JSON`、`schema`、`pipeline`、`AI/LLM`、模型品牌词和 hex 工程词。
- 该层作为命令面板最后一道展示兜底，避免后续上游诊断或交互消息把工程词、模型词或内部审计 id 直出给玩家。
- 边界：不改 `AppContainer.lastCommandMessage` 存储、交互日志、`Command` case、`CommandResult` schema、校验逻辑、AI 决策、命令结构、规则执行或运行时状态。

### v3.7-preflight.70：legacy 将领与朝堂记录可见文案复扫

- legacy `guderian` 配置和 fallback prompt 的“装甲突破 / 装甲部队”展示口径改为“破阵突击 / 突击部队”，保留内部 id。
- 朝堂使者 rationale 去掉“AI 自动回合”，结构化军令记录标题去掉 `JSON` 字样。
- `DiplomacyPanelView` 记录净化词表补齐旧军语、legacy 将领名和 `breakthrough` 等展示兜底。
- 边界：不改 rawValue、record schema、`rawJSON` 字段、AI 决策、命令结构、规则执行或运行时状态。

### v3.7-preflight.69：UI/战报/外交记录净化 helper 对齐

- `EventLogView` 和 `DiplomacyPanelView` 的展示净化顺序对齐 `AgentPanelView`：先清理 raw id，再做工程词、模型词和记录词替换。
- 三处 helper 补齐 `AI`、`LLM`、模型品牌词、`rawJson`、`raw JSON`、`Provider`、`Schema`、`record`、`Legacy Pipeline` 和裸 `pipeline` 等展示兜底。
- 边界：不改 UI 布局、记录 schema、日志来源、AI 决策、命令结构、规则执行或运行时状态。

### v3.7-preflight.68：模拟元帅输出纯 JSON 收口

- `SimulatedMarshalLLMClient` 生成的 `TheaterDirectiveEnvelope` 不再主动包裹 Markdown 代码围栏，改为直接返回纯 JSON 字符串。
- `TheaterDirectiveDecoder` 仍保留 fenced JSON 和纯 JSON 双兼容，外部模型合同不变。
- 边界：不改 `TheaterDirectiveEnvelope` / `TheaterDirective` 字段、schema version、decoder 校验、元帅策略、fallback、命令编译、规则执行或运行时状态。

### v3.7-preflight.67：legacy prompt 工程说明词收口

- `AgentPromptBuilder.systemPrompt` 中面向模型的工程说明词继续中文化，`hex` 改为“六角格”，`schema / Markdown` 说明改为结构化输出和排版标记口径。
- `AgentPromptBuilder.userPrompt` 的编号说明与格式标题改为结构化军令语义，减少 legacy LocalLLM 把工程词回写到 `intent`、`reason`、`stance` 的诱导。
- 边界：保留 `responseFormat: "json_object"`、JSON key、`schemaVersion`、`agentId`、`turn`、内部编号字段和 `move`、`attack`、`hold`、`resupply` type 合同值。

### v3.7-preflight.66：legacy MockAI stance 文案收口

- `MockAIClient` 生成的 `AgentOrder.stance` 从英文标签改为中文短语。
- 覆盖整补、火力支援、突破、沿路推进、固守、前线整补、收紧包围、前线进攻、纵深驰援、驻防和战役预备等姿态。
- 边界：只改 `stance` 自由文本，不改 `AgentOrderType`、内部 id、目标选择、决策排序、规则或运行时状态。

### v3.7-preflight.65：legacy prompt 决策者身份净化

- `AgentPromptBuilder.systemPrompt` 的“决策者”不再直接显示 raw `context.agentId`，`guderian` 显示为“古德里安”，其他内部 id 泛化为“本地军议决策者”。
- `AgentPromptBuilder.systemPrompt` 的“性格”改走 prompt-local 净化，避免英文 personality 或工程词进入系统提示层。
- `GameAgent.sample` 的默认 personality prompt 和 traits 改为中文。
- 边界：JSON schema 中的 raw `agentId` 保留不变，继续满足 legacy parser 的 agent mismatch 校验。

### v3.7-preflight.64：legacy prompt 直通文本净化

- `AgentPromptBuilder` 的近期战报和玩家意图进入 legacy LocalLLM prompt 前会先做局部净化。
- 净化覆盖常见审计 id、raw 地块/州郡/方面/军队/命令 id，以及 `RuleEngine`、`MockAI`、`local-model`、`rawJSON` 等工程词。
- 内部编号表和 JSON schema 不参与该净化，仍保留 parser / mapper 必需的 id、key 和 type rawValue。
- 边界：只改 legacy prompt 自由文本入口，不改展示 sanitizer、解析合同、命令结构、AI 决策、规则或运行时状态。

### v3.7-preflight.63：legacy prompt 内部编号分层收口

- `AgentPromptBuilder` 的中文战场摘要不再混写 `division.id`、`regionId.rawValue` 或相邻州郡 rawValue。
- 解析必须使用的 `divisionId`、`targetDivisionId` 和 `toRegionId` 单独放入“内部编号”小节，避免诱导模型在 `intent`、`reason`、`stance` 里复述内部编号。
- JSON schema 示例占位改为中文说明，但保留 `type` 的 `move`、`attack`、`hold`、`resupply` 合同值，避免破坏 legacy parser。
- 边界：只改 legacy LocalLLM prompt 文案结构，不改解析合同、命令结构、AI 决策、规则或运行时状态。

### v3.7-preflight.62：legacy 总管配置中文兜底

- `general_agents.json` 中 legacy `guderian` 的展示名和 personality prompt 改为中文，避免旧配置优先加载时把英文总管名或英文作战偏好带回 legacy LocalLLM 上下文。
- `GameAgent(definition:)` 对 `guderian` 保留窄口径代码兜底，旧 bundle 或旧数据仍会显示“古德里安”和中文作战偏好。
- `breakthrough` command style 仅在 `AgentPersonality.traits` 展示层映射为“突破”，数值判断仍读取原始 `definition.commandStyle`。
- 边界：不改 JSON schema、id、rawValue、command style、辖下单位 id、命令解析合同、AI 决策、规则或运行时状态。

### v3.7-preflight.61：AI 诊断净化口径对齐

- `TurnManager.userFacingDiagnostic` 与 `AgentPanelView` 的诊断净化与战报口径对齐，`model`、`legacy pipeline`、`RuleEngine` 等内部词改为军议来源、备用军议路径和军令校验。
- 古德里安旧总管名回落为“历史总管”，避免旧二战专名继续进入玩家可见诊断。
- 常见审计 id 正则补齐到源头诊断和 AI 面板，包括方面军令、玩家军令、归附交接、外交记录、地块、军队和命令 id。
- 边界：只改源头诊断与 AI 面板展示层 sanitizer，不改记录 schema、AI 决策、prompt、命令、规则或运行时状态。

### v3.7-preflight.60：MapEditor 导出元数据 fallback 收口

- `MapEditorExportMetadata.inferred(for:)` 不再让未知自定义文档默认落到 legacy 阿登元数据。
- 只有明确 legacy / Ardennes / WWII / 阿登 / 旧战局文档才使用 `.legacyArdennes`，其他未知文档默认使用隋唐草稿 metadata。
- 默认覆盖保存仍优先读取当前 `wude_618_scenario` 的 metadata，不改变 keyLocations 合并和派生语义。
- 边界：只改 metadata fallback 推断，不改 JSON schema、MapEditor 文档字段、DataLoader、规则或运行时。

### v3.7-preflight.59：战报意图屏蔽与中文分类收口

- 战报面板的军议意图屏蔽扩展到 v3.x 版本号和复合 snake_case intent，避免原始工程字符串直出。
- 审计 record id 净化前移到统一 sanitizer，避免普通词替换后形成半清洗文本。
- 战报分类补齐撤退、补员、围困、战斗、粮道等中文关键词，让已中文化日志不再默认降级为“事件”。
- 边界：只改战报展示层 formatter 和分类兜底，不改日志 schema、事件来源、record id、AI 决策、规则或命令管线。

### v3.7-preflight.58：外交面板名称与记录净化收口

- 外交面板势力列表和盟从列表改走 `countryDisplayName` / `blocDisplayName`，避免直接显示数据层英文 `name`。
- 未知国家或盟从名称含拉丁字母时回落到势力中文展示名，降低 legacy 或新增数据直出英文的风险。
- 外交记录摘要净化补齐 intent、reason、source、command、directive、RuleEngine、MockAI、model、Guderian 和常见审计 id。
- 边界：只改展示层 helper 和 formatter，不改外交关系、命令结构、record id、存档 schema、AI 决策、规则或命令管线。

### v3.7-preflight.57：legacy LLM prompt 语言收口

- 旧 `AgentPromptBuilder` 的 system/user prompt 改为中文，并要求 `intent`、`reason`、`stance` 摘要中文输出。
- prompt 中的任务、命令说明、战场摘要、补给、近期战报和玩家意图说明中文化。
- `guderianFallback` 展示名和 personality prompt 中文化，避免数据加载失败时英文总管名或英文偏好进入记录。
- 边界：保留 JSON schema、command type、agent id、rawValue、解析合同、AI 决策结构、规则和命令管线。

### v3.7-preflight.56：legacy static fallback 目标兼容与展示文案收口

- 静态 `MapState.ardennesV0()` / `GameState.initial()` 的 legacy 阿登地点、目标、单位和初始化战报中文化。
- 阿登胜负判断与 legacy MockAI 目标选择优先按 objective id 查找，避免前序展示名中文化后只按英文名匹配失效。
- legacy 胜负原因从旧题材可见词改为中性旧战局口径。
- 边界：保留英文地点名作为旧数据兼容查找值，不改 objective id、胜负阈值、行动策略、存档字段或命令管线。

### v3.7-preflight.55：legacy fallback 单位与防区展示文案收口

- legacy fallback `initialUnits[].name` 不再使用“师 N”，改为按阵营和兵种区分的德军/盟军单位展示名。
- legacy fallback 场景展示名和 dataNotes 去掉“预检”口径，改为“阿登战局”。
- legacy fallback region 展示名从隋唐“州郡”口径改为阿登“防区/战区分区”口径。
- 边界：只改 JSON 展示字段，不改 id、rawValue、schema、坐标、faction、templateId、加载顺序、规则或命令管线。

### v3.7-preflight.54：legacy fallback 数据展示文案收口

- legacy fallback 场景展示名、dataNotes、地点名、地块 cityName 和州郡/城邑展示名不再使用草稿名或坐标式命名。
- legacy 将领履历去掉“旧剧本/装甲总管/集团军总管”等迁移痕迹，并修正“博克”展示名。
- 边界：只改 JSON 展示字段，不改 id、rawValue、schema、坐标、faction、templateId、加载顺序、规则或命令管线。

### v3.7-preflight.53：总管与将领档案防区展示名 raw id 收口

- 本地模拟总管和自动总管配置展示名不再拼接 `zone.id.rawValue`。
- 将领档案“所属防区”不再直接显示 `zone.name`，遇到 raw 防区名时回落为玩家语义。
- 内部 `id`、`assignedZoneId`、front zone schema、AI 决策和命令执行保持不变。

### v3.7-preflight.52：命令错误与源头战报可见文案收口

- 命令展示名、州郡命令展示名和 RuleEngine 成功消息不再直出坐标、region rawValue、军队 id 或英文工程词。
- 元帅军令解码错误、命令意图适配错误和 legacy Agent 映射错误改为泛化中文原因，不再拼接底层 JSON/DecodingError 详情或 raw id。
- 行军、撤退、方面军令拒绝、州郡控制权变化和推进战报去掉 `q,r` 坐标与“动态推进”工程口径。
- 总管面板和玩家交互日志对防区名做 fallback，避免 raw theater/front 名称进入玩家视野。
- Agent、战报、外交面板和 TurnManager 诊断净化补齐 `marshal_*`、`mock_*`、`sovereign_*` 等 raw agent id。
- 边界：只改可见字符串和展示净化，不改命令结构、record id、schema、rawValue、AI 决策、规则数值或执行语义。

### v3.7-preflight.51：MapEditor 与主游戏 raw id 可见文案复扫收口

- MapEditor 底图、信息、地点、状态和导出错误文案去掉 raw 坐标、文件名、目录名、raw objective id 和“内存”工程词。
- 州郡/方面缺省名改为“未命名州郡/未命名方面”，避免 MapEditor picker 或信息面板回落显示 raw id。
- 主游戏选择日志、州郡详情和军队详情不再直出 `q,r` 坐标；方面/行军防区名遇到 raw id 时回落为玩家语义。
- 战报、朝堂和外交记录摘要补充 `region_*`、`theater_*`、`front_zone_*`、`obj_*`、`agent_*` 通用 raw id 净化。
- 边界：只改可见字符串和展示净化，不改内部 id、schema、rawValue、objectiveId、资源文件名、导出结构、AI 决策、规则或命令管线。

### v3.7-preflight.50：复核面板与记录摘要可见文案收口

- 战局复核面板的当前可用、后续功能和说明文案改为玩家视角，减少发布工程口径。
- MapEditor 资源面板和资源缺失错误不再显示“导出到内存”、资源目录或具体 JSON 文件名。
- 战报与朝堂面板把 fallback/diagnostic/raw JSON/Hex 变体净化为备用处置、军情说明、军情记录和地块/方面归属。
- 外交面板对历史事件、交接、善后、君主理由和使者摘要套用可见文本净化。
- 边界：只改可见字符串和展示净化，不改内部 id、schema、rawValue、导出结构、AI 决策、规则或命令管线。

### v3.7-preflight.49：数据加载与导出说明可见文案收口

- DataLoader 的 MapEditor 兼容数据加载初始战报改用剧本展示名，避免直出 raw scenario id。
- MapEditor 导出的州郡数据集标题从英文 `Regions` 改为中文“州郡数据”。
- 默认隋唐与 legacy scenario 的 dataNotes 去掉 `component rawValue`、版本号工程口径和 `hex` 英文词。
- 边界：只改可见日志、导出标题和说明文案，不改 JSON schema、rawValue、id、加载顺序、地图数据、规则或命令管线。

### v3.7-preflight.48：自动回合与元帅诊断兜底文案收口

- legacy 自动元帅展示名改为伦德施泰特、艾森豪威尔，旧剧本与隋唐势力 personality 文案改为中文。
- 元帅解析/编译失败和 legacy Agent D 映射失败路径改用中文兜底，不再直接透传任意底层异常。
- `TurnManager` 诊断净化补齐元帅、行军总管、君主、schema、provider、fallback、directive、diagnostic、breakthrough 等工程词。
- 边界：只改展示层、配置展示文案和错误包装，不改 prompt、JSON schema、rawValue、record id、AI 决策、规则或命令管线。

### v3.7-preflight.47：Agent 诊断与错误兜底文案收口

- Agent 角色显示名改为君主、元帅、行军总管，避免公开 displayName 继续返回英文。
- Agent 面板和战报面板的诊断净化补齐 legacy 角色、古德里安、schema/model/fallback/directive/diagnostic 等工程词。
- legacy Agent D 映射失败、解析失败和数据加载校验失败的常见错误描述改为中文兜底。
- 边界：只改展示层和错误包装，不改 prompt、JSON schema、rawValue、record id、AI 决策、规则或命令管线。

### v3.7-preflight.46：Legacy 将领档案可见文本收口

- legacy 将领 `rank` 和 `biography` 改为中文，避免将领面板直出英文军衔和履历。
- 总管配置展示名优先使用 `localizedName`，将领技能 raw id 在总管面板和将领档案中统一映射为中文。
- 边界：只改展示字段和展示映射，不改 JSON schema、id、技能 rawValue、AI prompt、规则或命令管线。

### v3.7-preflight.45：Legacy JSON 可见文本收口

- 旧阿登 fallback 场景和 region 数据中的 `MapEditor Scenario`、`City q,r`、`Supply q,r` 等展示字段改为中文。
- legacy 单位模板 `displayName` 改为中文，保留 template id、component rawValue 和权重。
- 边界：只改 JSON 展示字段，不改 schema、id、rawValue、加载顺序、默认隋唐入口、规则或命令管线。

### v3.7-preflight.44：Legacy MockAI 与元帅解析诊断中文化

- `MockAICommander` 和 legacy `MockAIClient` 的可见上下文、意图和 reason 改为中文。
- 元帅 directive 解码错误改为中文，战报诊断净化补齐 rawJSON、provider、legacy pipeline、directive 等工程词替换。
- 边界：只改可见诊断和审计文案，不改 legacy AI 启发式、stance rawValue、JSON schema、解析合同、命令执行或规则管线。

### v3.7-preflight.43：AI 元帅/方面军令摘要中文化

- `ZoneCommanderAgent` 中元帅意图、方面军令摘要、编译上下文和 fallback 诊断改为中文。
- 模拟元帅 rationale 使用中文军议说明和 `TacticName.displayName`，不再直出 `Simulated marshal JSON`、`front status` 或 tactic rawValue。
- 边界：只改可见摘要和审计文案，不改 AI 决策、JSON schema、rawValue、解析合同、命令执行或规则管线。

### v3.7-preflight.42：默认数据说明与补给战报中文化

- `DataLoader` 的 MapEditor 兼容数据加载初始战报改为中文。
- `wude_618_scenario.json` 的 `dataNotes` 改为中文。
- MapEditor 隋唐与 legacy 导出 metadata 的 `dataNotes` 改为中文。
- MapEditor 派生补给地点名从 `Supply q,r` 改为 `粮仓 q,r`。
- `SupplyRules` 的补员、撤退、撤退失败、围困损耗和退却整顿事件改为中文战报。
- 边界：只改数据说明、导出说明和事件文案，不改 JSON schema、rawValue、加载顺序、胜负条件、地图数据或规则数值。

### v3.7-preflight.41：MapEditor 可见文案收口

- MapEditor 默认隋唐编辑入口收口旧势力选项、工程词、raw id、系统错误、完整路径和单位英文短标。
- 势力 Picker 使用 `Faction.suitangTurnOrder`，隐藏 legacy 势力选项；不改 `Faction.allCases` 兼容语义。
- 州郡、方面、地点、资源、导出和错误反馈使用中文产品语义。

### v3.7-preflight.40：本局执掌势力选择

- `GameState.playerFaction` 进入运行时状态和本地存档。
- 基础设置可选择当前局势内可玩的执掌势力。
- 通用 `.playerCommand` / `.aiCommand` 阶段推进按 `state.playerFaction` 判定。
- 不重排当前回合顺序，不做完整多势力平衡。

### v3.7-preflight.31-.39：玩家可见文案连续收口

- legacy 势力、阶段/胜负原因、经济事件、App/AI 记录、外交/朝堂摘要、AI 诊断、战报 metadata、总管预览、源头事件、App/UI 边界、剩余 UI 抽样和复扫文案持续中文化。
- 重点收口 raw id、英文 fallback、provider suffix、规则工程口径、发布验收口径、斜线分隔和 `N/M` 显示。
- 这些版本只改展示文案、formatter 和辅助读法，不改命令、规则、存档 schema 或地图数据。

### v3.7-preflight.28-.30：MapEditor 与发布检查

- MapEditor 默认读取/覆盖 `wude_618_scenario` 与 `wude_618_regions`。
- MapEditor 文档显式保存 `keyLocations`，可编辑城池、关隘、粮仓、渡口、港口/海港地点字段。
- 发布检查面板升级为当前 `GameState` 静态门禁快照。

### v3.7-preflight.9-.27：外交、州郡经营、归附与善后

- 玩家侧 `Command.updateDiplomacy`、`Command.governRegion` 接入统一规则管线。
- AI/观战自动回合可保守生成太守经营、使者外交、归附实体交接。
- 归附事件、空势力轮转、实体盘点、交接审计、善后压力、善后治理记录、进度摘要、完成状态和跳过诊断已接入。
- 善后治安压力和贡赋效率已接入；忠诚、叛乱、俘虏、安置等实际善后效果仍待后续。

### v3.7-preflight.1-.8：胜负、存档、引导、地图叠加

- `VictoryRules` 消费 `wude_618` 长安、洛阳、洛口仓、潼关胜利目标。
- `GameSaveStore` 支持本地 JSON 自动存档，新局/继续/重置入口已接入。
- HUD 筹备菜单、开局引导、基础设置和发布检查面板已接入。
- 渡口/港口标识、AI 计划箭头、普通地图层前线墨线、存档错误反馈和发布说明/资产边界已接入。

### v3.0-v3.6：迁移基础

- v3.0 审计合同和迁移词汇表。
- v3.1 多势力 enum、通用 phase、外交敌对判断。
- v3.2 默认 `wude_618` 数据。
- v3.3 兵种、粮道、围城和战术显示最小迁移。
- v3.4 朝堂 AI 分层审计。
- v3.5 玩家军令、州郡、外交和战报信息闭环。
- v3.6 隋唐视觉 token、统一 panel、显眼英文调试文案清理和最小地图标识。

---

## 验证规则

当前工作流默认不跑本机 Xcode / XCTest / 模拟器 / 性能测试 / Probe / Smoke / Stage Regression / Dynamic Theater Regression / Full。允许的本机检查以 `md/test/test.md` 为准，通常包括：

- 改动 Swift 文件的 `swiftc -parse`。
- 改动 JSON 文件的 `jq empty`。
- `git diff --check`。
- 尾随空白、冲突标记和定向残留文本扫描。

重验证默认交给 GitHub Actions 在 `origin/main` 上执行，并由 Agent C 下载未加密结果包复核。

---

## 当前未完成风险

- 未做真实 iOS/macOS 启动、MapEditor 点击、导入导出往返、覆盖保存后主游戏加载、多回合观察者验证或云端 artifact 验收。
- 正式地图资产、图标资产和运行时截图检查尚未完成。
- 归附后的治安压力和贡赋效率已有最小规则；忠诚、叛乱、俘虏、安置等实际规则仍未实现。
- DataLoader 的部分开发校验错误、legacy 人物英文正名和内部 prompt 仍保留英文技术信息，主要服务兼容与历史回归参考。
- 完整 v3.7 发布候选仍需要授权构建、运行、交互烟测和 CI 结果包验收。
