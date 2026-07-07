# 项目 Markdown 大纲：隋末唐初 AI Agent 历史策略迁移

> 本文件是项目 md 层的路线大纲，依据 `md/prompt/v3.0-隋唐迁移/codex-v3.0-隋末唐初aiagent历史策略迁移总提示词.md` 整理。它不是实现记录，也不表示 v3.x 代码已经完成。实际开发仍以 `AGENTS.md`、`update_log.md`、`md/flow/flow.md`、`md/flow/flowchart.md`、`md/test/test.md` 和各阶段 prompt 为准。

## 1. 当前项目判断

当前工程仍是 `WWIIHexV0`：Swift + SwiftUI + SpriteKit 的二战 hex 战棋骨架，已具备成熟的 hex 战术层、region 战略聚合、动态战区、前线、部署、命令管线、经济草案、外交草案、将领草案、元帅决策链、macOS 入口和地图编辑器方向。

当前主链路：

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
  -> ZoneDirective
  -> WarCommandExecutor
  -> RuleEngine
  -> StrategicStateSynchronizer
  -> UI overlay / 日志 / WarDirectiveRecord
```

迁移目标不是换皮，而是逐步把该骨架迁移成可发布的 AI Agent 驱动隋末唐初历史策略游戏。正式完成身份迁移前，README 和 AGENTS 的项目总览仍可保留当前真实状态，不能把审计或提示词当作已完成版本。

## 2. 最终产品目标

暂定产品名：`天命开唐 Agent`。英文工作名可用 `Mandate Agent Hex` 或 `Sui Tang Agent Hex`，最终名称由人工确认。

首发剧本建议：

```text
id: wude_618_guanzhong_luoyang
displayName: 武德元年：关中河洛争衡
时间范围：617-619 的抽象战役窗口，以 618 为开局题面
地图范围：关中、河东、河洛、河北南部、淮北/河南局部、陇右入口
```

首发体验目标：

- 打开应用直接进入可玩的历史战役地图，不做营销落地页。
- 地图规模约 90-160 个 hex、25-45 个州郡 region、6-10 个方面/行军道。
- 主要势力包括唐、洛阳隋/王世充、瓦岗、窦建德、薛举/薛仁杲、刘武周/宋金刚、东突厥和中立地方势力。
- 首版优先保证 `power_tang` 可玩，其他势力由 AI Agent 驱动。
- 玩家既可微操军队，也可通过将领/军令面板下达固守、进军、合围、截粮、围城、驰援等宏观命令。
- AI Agent 只能输出结构化 directive，经 decoder / validator / compiler 后进入统一规则系统。
- UI 视觉转向隋唐历史战棋质感：绢帛/山水地图底色、墨线地形、青绿河流、朱印势力标识、铜色/玉色点缀、军旗、城池、关隘、粮仓、渡口图标。
- 发布候选需要完整闭环：开局、选势力、看州郡、选军队、进军、战斗、围城/占领、粮草消耗、AI 回合、外交或归附事件、战报复盘、胜负判断。

## 3. 迁移铁律

- `HexTile.controller` 和 `Division.coord` 是战术层权威。
- Region 只做州郡/郡县/仓城/关隘的战略聚合，不替代 hex。
- `regionToTheater` 只作初始/基础方面归属和地图编辑器种子。
- `hexToTheater` 是运行时动态方面权威；突破一个 hex 只能推进该 hex。
- `hexToFrontZone` 是部署层动态归属权威；`regionToFrontZone` 只能作 dominant / fallback。
- 玩家、AI、聊天命令和 MockAI 都必须落到 `Command` / `ZoneDirective`，再经 `WarCommandExecutor`、`CommandValidator`、`RuleEngine` 执行。
- Legacy Agent D 保留作回归参考，默认战争 AI 主路径不得退回旧管线。
- 不恢复 organization；当前战斗核心仍是 strength、retreat、supply、encirclement。
- 不一次性大规模重命名类型；先做兼容层、审计和迁移合同。
- 不让任何 Agent 直接改 `GameState`、`HexTile.controller`、`Division.coord`、`regionToTheater`、`hexToTheater` 或 `hexToFrontZone`。
- 未获人工授权，不跑 `xcodebuild build/test`、模拟器、Probe、Smoke、Stage Regression、Dynamic Theater Regression、Full、性能测试或 app 启动。

## 4. 语义替换方向

短期可保留源码兼容名，但玩家可见语义必须逐步隋唐化：

| 当前二战语义 | 迁移目标语义 |
|---|---|
| `Faction.germany/allies` | 多势力体系，短期 enum 扩展，长期 `PowerId` / `Faction` 兼容桥 |
| `GamePhase.germanAI/alliedPlayer` | 通用 playerCommand / aiCommand / resolution 或 active power phase |
| `Division` | 军队、部曲、军团、守军、行军队 |
| tank / motorizedInfantry / infantry / artillery | 步卒、骑兵、弓弩、攻城器械、守军、水师 |
| manpower / industry / supplies | 丁口、钱帛/军械、粮草 |
| Theater | 方面、行军道、总管府、军区 |
| FrontZone | 行军防区、方面军防区、总管辖区 |
| Region | 州郡、郡县、仓城、关隘 |
| RulerAgent | 君主 / 天命 Agent |
| MarshalAgent | 谋主 / 大总管 / 军师 Agent |
| Ardennes JSON | 隋末唐初剧本 JSON |

新增或强化的隋唐语义：

- 天命、正朔、民心。
- 粮仓、粮道、仓城。
- 围城、守城、破城。
- 州郡治理、治安、征发。
- 归附、降伏、倒戈。
- 东突厥边境压力、借兵或外交威胁。

## 5. v3.0-v3.8 版本路线

| 版本 | 主题 | 主要交付 | 非目标 |
|---|---|---|---|
| v3.0 | 迁移审计、兼容层和题材合同 | 新增 `v3.0_audit_and_contract.md`；硬编码扫描；迁移词汇表；接口合同；风险清单 | 不做大范围重命名，不实现完整隋唐玩法 |
| v3.1 | 多势力、外交关系和通用回合阶段 | 支持唐、洛阳隋、瓦岗、窦建德、薛举、刘武周、东突厥、中立；清除 `.opponent` 核心依赖；阶段显示通用化 | 不一次性重写全部 faction 架构 |
| v3.2 | 隋唐地图、剧本数据和默认入口 | `wude_618` 默认剧本；隋唐 region / unit / general / power JSON；主游戏默认优先加载隋唐路径 | 不追求完整中国地图和所有势力；MapEditor 深度编辑字段后续迁移 |
| v3.3 | 军队、兵种、粮道、围城和战术规则 | 步卒/骑兵/弓弩/器械显示与规则；粮仓/粮道；围城最小闭环；战术名称隋唐化 | 不引入复杂士气、全量水战或大规模新规则 |
| v3.4 | 君主、谋主、行军总管、太守、将领 AI Agent 分层 | Sovereign / Strategist / Governor / MarchCommander / General / Diplomat 的结构化 directive 链路 | Agent 不直接执行命令，不接真实网络模型 |
| v3.5 | 玩家军令、州郡经营、外交和战报体验 | 军令、州郡、将领、战报、外交闭环；拒绝原因可见 | UI 不绕过规则系统 |
| v3.6 | 发布级 UI、美术和交互收口 | 隋唐视觉系统、设计 token、地图图层、军牌/城池/粮道/前线表达 | 不用版权不明素材，不做 landing page |
| v3.7-preflight | 胜负闭环最小迁移 | `wude_618` 长安、洛阳、洛口仓、潼关胜利目标接入 `VictoryRules`；HUD 展示原因 | 不冒充完整发布候选，不改占领/战区权威 |
| v3.7-preflight.2 | 新局、继续、重置和本地自动存档 | `GameSaveStore` 保存/读取 `GameState`；HUD/macOS 菜单提供新局/继续/重置；命令和 AI 后自动保存 | 不保存 UI 临时态，不冒充完整发布候选 |
| v3.7-preflight.3 | 开局引导、设置和发布前检查面板 | HUD 筹备菜单；开局引导、基础设置、版本说明和发布前检查清单 | 只改 UI/文档，不冒充授权运行时发布候选 |
| v3.7-preflight.4 | 渡口和港口地图标识 | `MapState.featureMarkers` 承载 `keyLocations`；地图绘制渡船/帆船图标 | 只做显示，不实现水战、渡河或港口补给规则 |
| v3.7-preflight.5 | AI 计划箭头 | `BoardRenderState.recentDirectiveRecords`；最近非玩家 directive 绘制虚线箭头/防守圈 | 只读复盘记录，不改变 AI 决策或规则 |
| v3.7-preflight.6 | 前线墨线 | 普通地图层从 `FrontLineState` 绘制墨色接触线和朱色警示虚线 | 只读前线派生状态，不改变战区/部署/规则 |
| v3.7-preflight.7 | 存档错误反馈 | `GameSaveStatus`、HUD 失败提示、设置/发布检查面板显示存档反馈 | 不改存档 JSON schema，不做多槽位或导入导出 |
| v3.7-preflight.8 | 发布说明与资产边界 | 发布检查面板显示首发定位、资产边界和验证口径；记录代码绘制/派生显示范围 | 不引入外部素材，不改规则或存档 schema |
| v3.7-preflight.9 | 外交议和与纳降命令 | `Command.updateDiplomacy` 经 `RuleEngine` 更新 `DiplomacyState`；外交面板提供议和/纳降入口 | 只改外交关系，不直接转移 hex、region 或军队 |
| v3.7-preflight.10 | 州郡经营与太守命令 | `Command.governRegion` 经 `RuleEngine` 更新 `RegionNode` 战略字段和府库；州郡面板提供修道/屯田/安民入口 | 只改 region/economy，不直接改 hex、theater、front、deploy 或军队 |
| v3.7-preflight.11 | AI 太守主动经营 | AI/观战自动回合最多生成一条 `Command.governRegion`，经 `RuleEngine` 执行修道、屯田或安民 | 不直接改 region/hex/unit/theater/front/deploy，不处理 AI 外交 |
| v3.7-preflight.12 | AI 使者主动外交 | AI/观战自动回合最多生成一条 `Command.updateDiplomacy`，经 `RuleEngine` 执行停战或归附关系更新 | 只改外交关系，不直接转移 hex、region、军队或部署 |
| v3.7-preflight.13 | 归附事件记录链 | `Command.updateDiplomacy` 执行后追加 `DiplomacyEventRecord`，外交战报关联记录 id，外交面板显示最近事件 | 只记录关系事件，不直接转移 hex、region、军队或部署 |
| v3.7-preflight.14 | 归附空势力轮转收口 | 已归附且无存活军队、无可通行受控 hex 的势力退出通用隋唐回合轮转 | 只改 turn order，不直接转移 hex、region、军队或部署 |
| v3.7-preflight.15 | 归附实体盘点与误判收口 | `DiplomacyState` 统一归附目标判定；外交面板显示归附目标残余军队和受控可通行 hex | 只读盘点，不直接转移 hex、region、军队或部署 |
| v3.7-preflight.16 | 归附实体交接命令 | `Command.resolveSubmissionHandoff` 经 `RuleEngine` 接管归附目标未毁灭军队和可通行受控 hex | 不处理外交档案清理、忠诚、叛乱或多回合善后 |
| v3.7-preflight.17 | 归附交接审计记录 | `SubmissionHandoffRecord` 记录交接结果，外交战报关联记录 id，外交面板展示最近交接 | 不处理忠诚、叛乱、贡赋、俘虏、安置或交接后治理 |
| v3.7-preflight.18 | AI 归附实体交接 | AI 回合在使者外交后最多执行一条 `Command.resolveSubmissionHandoff`，结果进入 AI command results | 不做批量交接、忠诚、叛乱、贡赋、俘虏、安置或治理善后 |
| v3.7-preflight.19 | 归附善后压力记录 | 交接成功后生成 `SubmissionAftermathRecord`，外交日志关联记录 id，外交面板展示善后压力 | 只读提示，不触发忠诚、叛乱、安置、治理效果或资源变化 |
| v3.7-preflight.20 | AI 善后太守优先治理 | AI 太守优先考虑最新高/需安抚善后压力州郡，仍通过 `Command.governRegion` 执行 | 不新增忠诚、叛乱、安置、资源变化或额外交接效果 |
| v3.7-preflight.21 | 善后处置审计记录 | 治理最新善后州郡后生成 `SubmissionAftermathGovernanceRecord`，外交面板展示处置摘要 | 不清零压力，不新增忠诚、叛乱、安置或额外资源变化 |
| v3.7-preflight.22 | 善后处置进度摘要 | 外交面板按最新善后记录显示已处置州郡数量 / 受影响州郡数量 | 只读复盘摘要，不清零压力，不新增规则效果 |
| v3.7-preflight.23 | AI 善后未处置优先治理 | AI 太守优先治理最新善后记录中尚未产生处置记录的受影响州郡 | 只改候选排序，不新增命令、行动次数或规则效果 |
| v3.7-preflight.24 | 善后完成状态提示 | 外交面板显示待处置数量 / 完成状态，AI 在全部处置后退出该善后特殊优先队列 | 只改只读摘要和候选排序收口，不清零压力或新增规则效果 |
| v3.7-preflight.25 | 发布检查门禁拆分 | 发布前检查面板区分代码已接入、运行时未验证和后续功能 | 只改 UI/文档，不新增规则、命令或运行时验证结论 |
| v3.7-preflight.26 | AI 太守跳过诊断 | 朝堂太守步骤或未完成善后上下文存在但未生成经营命令时写入确定性诊断 | 只补诊断，不新增命令、行动次数或治理效果 |
| v3.7-preflight.27 | AI 使者/交接跳过诊断 | 朝堂使者步骤存在但未生成外交命令、或有归附上下文但未生成交接命令时写入确定性诊断 | 只补诊断，不新增外交状态、行动次数或交接效果 |
| v3.7-preflight.28 | MapEditor 默认隋唐资源桥 | 默认读取/覆盖 `wude_618_scenario` 和 `wude_618_regions`；导出保留既有胜负条件、objective 点数和水路地点元数据 | 不新增水路地点编辑字段，不改变 JSON schema 或规则管线 |
| v3.7-preflight.29 | MapEditor 地点字段化编辑 | `MapEditorDocument.keyLocations`；右键信息面板编辑名称、类型、势力和 objectiveId；导出文档地点优先并支持坐标级抑制 | 不新增水战、渡河、港口补给、移动、战斗或胜负规则 |
| v3.7-preflight.30 | 发布候选静态门禁快照 | 发布前检查面板只读当前 `GameState`，展示剧本、回合、地图、地点、军队、战线、外交、审计、善后和存档状态 | 不启动 app，不跑 AI 回合，不代表运行时验收或 CI artifact 验收 |
| v3.7-preflight.31 | 玩家可见旧英文兜底收口 | legacy 势力、阶段/胜负原因 displayName、军队方向码和经济事件日志中文化 | 不改 rawValue、存档 schema、规则数值、AI 决策或地图数据 |
| v3.7-preflight.32 | 玩家可见调试文案收口（一） | App/AI 记录、bootstrap 战报、朝堂面板和将领技能显示的第一批 raw/debug 文案中文化 | 不改命令、AI 决策、规则执行、存档字段或地图数据 |
| v3.7-preflight.33 | 玩家可见外交/朝堂文案收口 | 外交面板、君主决策摘要、州郡/军队详情和基础可访问性入口继续清理 raw id、英文 fallback 与工程术语 | 不改外交关系、命令结构、AI 决策策略、规则执行、存档字段或地图数据 |
| v3.7-preflight.34 | 玩家可见 AI 诊断文案收口 | AI 面板、方面军令诊断、命令结果摘要和 legacy Agent D 失败路径继续清理 raw id、英文 fallback、provider suffix 与工程术语 | 不改命令结构、AI 决策策略、规则执行、存档字段或地图数据 |
| v3.7-preflight.35 | 战报与总管预览文案收口 | 战报 metadata、军议意图、战报重点摘要和总管预备军令预览继续清理 raw id 与工程格式 | 不改日志 schema、命令结构、AI 决策策略、规则执行、存档字段或地图数据 |
| v3.7-preflight.36 | 战报源头事件文案收口 | 规则、军令、战略同步和经济源头事件继续中文化，减少 raw id、validation rawValue、英文工程词和生产调试编号进入战报 | 不改命令结构、规则执行、战斗/经济数值、日志 schema、存档字段或地图数据 |
| v3.7-preflight.37 | App/UI 边界文案收口 | 存档反馈、自动回合、命令面板、发布检查和详情面板继续清理系统错误、provider、scenario raw id 和工程词 | 不改存档 schema、内部审计 id、命令结构、规则执行、AI 决策或地图数据 |
| v3.7-preflight.38 | 剩余 UI 文案抽样收口 | 开局引导、HUD、战局复核、朝堂面板、经济、战报、外交、州郡经营、总管和单位提示继续清理 AI/Xcode、scenario fallback、raw JSON 和工程分隔符 | 只做抽样展示层收口，不改规则、命令、存档 schema、内部 id、地图数据或运行时验证结论 |
| v3.7-preflight.39 | UI 文案复扫收口 | 战局复核、App 反馈、外交边界说明、战报 metadata、单位兵力和地图短标继续清理发布验收口径、规则工程口径、旧剧本 fallback、斜线与 `N/M` | 只做展示层 formatter 收口，不改规则、命令、存档 schema、内部 id、地图数据或运行时验证结论 |
| v3.7-preflight.40 | 本局执掌势力选择 | `GameState.playerFaction` 进入存档；基础设置选择当前局势可玩势力；通用 phase 按执掌势力判定玩家/自动行动 | 不做完整多势力平衡，不重排当前回合，不绕过规则管线 |
| v3.7-preflight.41 | MapEditor 可见文案收口 | 默认隋唐编辑器的势力 picker、状态反馈、导出错误、路径显示和地图单位短标中文化 | 不改 JSON schema、rawValue、导出 key、资源文件名、主游戏规则或运行时验证结论 |
| v3.7-preflight.42 | 默认数据说明与补给战报中文化 | 默认隋唐 dataNotes、MapEditor 导出说明、派生粮仓地点名、数据加载初始战报和补给撤退事件中文化 | 不改 JSON schema、rawValue、加载顺序、胜负条件、地图数据或规则数值 |
| v3.7-preflight.43 | AI 元帅/方面军令摘要中文化 | 元帅意图、方面军令摘要、编译上下文、模拟元帅 rationale 和 fallback 诊断中文化 | 不改 AI 决策、JSON schema、rawValue、解析合同、RuleEngine 或命令执行 |
| v3.7-preflight.44 | Legacy MockAI 与元帅解析诊断中文化 | legacy MockAI intent/reason、本地模拟总管摘要、元帅 directive 解码错误和战报诊断净化中文化 | 不改 legacy heuristic、stance rawValue、JSON schema、解析合同、RuleEngine 或命令执行 |
| v3.7-preflight.45 | Legacy JSON 可见文本收口 | 旧 fallback 场景名、dataNotes、城邑/补给点名和 legacy 单位模板 displayName 中文化 | 不改 JSON schema、id、rawValue、加载顺序、默认隋唐入口、RuleEngine 或命令执行 |
| v3.7-preflight.46 | Legacy 将领档案可见文本收口 | legacy 将领军衔/履历中文化，总管展示名优先 localizedName，技能 raw id 显示映射补齐 | 不改 JSON schema、id、skill rawValue、AI prompt、RuleEngine 或命令执行 |
| v3.7-preflight.47 | Agent 诊断与错误兜底文案收口 | Agent 角色 displayName、面板诊断净化、legacy 映射失败和数据加载校验失败中文化 | 不改 prompt、JSON schema、rawValue、record id、AI 决策、RuleEngine 或命令执行 |
| v3.7-preflight.48 | 自动回合与元帅诊断兜底文案收口 | 自动元帅展示名/personality、legacy 映射失败和元帅解析/编译失败诊断中文化 | 不改 prompt、JSON schema、rawValue、record id、AI 决策、RuleEngine 或命令执行 |
| v3.7-preflight.49 | 数据加载与导出说明可见文案收口 | DataLoader 初始战报、MapEditor 州郡数据标题和 scenario dataNotes 工程词中文化 | 不改 JSON schema、id、rawValue、加载顺序、地图数据、RuleEngine 或命令执行 |
| v3.7-preflight.50 | 复核面板与记录摘要可见文案收口 | 战局复核、MapEditor、战报、朝堂和外交面板减少发布/工程口径并净化历史摘要 | 不改内部 id、schema、rawValue、导出结构、AI 决策、RuleEngine 或命令执行 |
| v3.7-preflight.51 | MapEditor 与主游戏 raw id 可见文案复扫收口 | MapEditor 坐标/文件名/导出工程词、主游戏详情坐标、方面防区 raw name 和记录摘要 raw id 净化 | 不改内部 id、schema、rawValue、objectiveId、导出结构、AI 决策、RuleEngine 或命令执行 |
| v3.7-preflight.52 | 命令错误与源头战报可见文案收口 | 命令展示名、错误兜底、源头战报、总管防区展示和 raw agent id 净化 | 不改命令结构、record id、schema、rawValue、AI 决策、规则数值或执行语义 |
| v3.7-preflight.53 | 总管与将领档案防区展示名 raw id 收口 | 自动总管展示名和将领档案所属防区展示 fallback，不直出 raw 防区 id/name | 不改内部 id、assigned zone、front zone schema、AI 决策、命令结构或规则语义 |
| v3.7-preflight.54 | legacy fallback 数据展示文案收口 | legacy 场景、地点、州郡、城邑和将领履历展示名去草稿/坐标/旧剧本口径 | 不改 JSON key、id、rawValue、coord、faction、templateId、schema、加载顺序或规则语义 |
| v3.7-preflight.55 | legacy fallback 单位与防区展示文案收口 | legacy 初始单位名、阿登场景名/dataNotes 和阿登 region 防区名去泛化/预检/州郡口径 | 不改 JSON key、id、rawValue、coord、faction、templateId、schema、加载顺序或规则语义 |
| v3.7-preflight.56 | legacy static fallback 目标兼容与展示文案收口 | 静态阿登地点/目标/单位/胜负原因中文化，legacy 规则和 MockAI 目标查找改为 objective id 优先 | 不改 objective id、胜负阈值、行动策略、存档字段或命令管线 |
| v3.7-preflight.57 | legacy LLM prompt 语言收口 | 旧 LocalLLM prompt、JSON 示例值和古德里安 fallback 配置中文化，减少英文 intent/reason 回流 | 不改 JSON schema、command type、agent id、rawValue、解析合同、AI 决策结构或命令管线 |
| v3.7-preflight.58 | 外交面板名称与记录净化收口 | 外交面板势力/盟从名称走展示 helper，未知英文 fallback 回落中文势力名，记录摘要补齐内部词和审计 id 净化 | 不改外交关系、命令结构、record id、存档 schema、AI 决策或规则执行 |
| v3.7-preflight.59 | 战报意图屏蔽与中文分类收口 | 战报面板屏蔽 v3.x/复合 intent，前置审计 id 净化，补齐中文撤退/补员/围困/战斗/粮道分类关键词 | 不改日志 schema、事件来源、record id、AI 决策、命令结构或规则执行 |
| v3.7-preflight.60 | MapEditor 导出元数据 fallback 收口 | 未知自定义文档默认隋唐草稿，明确 legacy / Ardennes / WWII 才阿登 | 不改 schema、keyLocations 合并规则、主游戏加载或运行时规则 |
| v3.7-preflight.61 | AI 诊断净化口径对齐 | `TurnManager` 源头诊断和 `AgentPanelView` 展示净化统一 model / legacy pipeline / RuleEngine 等口径，补齐常见审计 id | 不改记录 schema、AI 决策、prompt、命令、规则或运行时 |
| v3.7-preflight.62 | legacy 总管配置中文兜底 | `general_agents.json` 中 `guderian` 展示字段中文化，`GameAgent(definition:)` 保留旧数据窄口径兜底 | 不改 JSON schema、id、rawValue、command style、命令解析合同、AI 决策或规则 |
| v3.7-preflight.63 | legacy prompt 内部编号分层收口 | `AgentPromptBuilder` 中文摘要不混 raw id，内部编号单独列出，保留 JSON type 合同 | 不改 parser、schema key、id/rawValue、命令结构、AI 决策或规则 |
| v3.7-preflight.64 | legacy prompt 直通文本净化 | `AgentPromptBuilder` 近期战报和玩家意图进入 prompt 前先做局部净化 | 不改存储、展示 sanitizer、内部编号、parser、命令结构、AI 决策或规则 |
| v3.7-preflight.65 | legacy prompt 决策者身份净化 | `AgentPromptBuilder.systemPrompt` 决策者展示名化，personality 走局部净化，sample agent 中文化 | 不改 schema agentId、parser、命令结构、AI 决策或规则 |
| v3.7-preflight.66 | legacy MockAI stance 文案收口 | `MockAIClient` 生成的 `AgentOrder.stance` 英文自由文本中文化 | 不改 AgentOrderType、内部 id、目标选择、MockAI 策略或规则 |
| v3.7-preflight.67 | legacy prompt 工程说明词收口 | `AgentPromptBuilder` 面向 LocalLLM 的 hex/schema/Markdown 说明转为中文结构化军令口径 | 不改 JSON 字段、type rawValue、内部编号、parser、mapper 或规则 |
| v3.7-preflight.68 | 模拟元帅输出纯 JSON 收口 | `SimulatedMarshalLLMClient` 直接返回纯 `TheaterDirectiveEnvelope` JSON，decoder 仍兼容 fenced JSON | 不改 TheaterDirective schema、decoder 校验、元帅策略、fallback、命令编译或规则 |
| v3.7-preflight.69 | UI/战报/外交记录净化 helper 对齐 | `AgentPanelView`、`EventLogView`、`DiplomacyPanelView` 统一先清 raw id 再替换工程词 / 模型词 | 不改 UI 布局、记录 schema、日志来源、AI 决策、命令结构或规则 |
| v3.7-preflight.70 | legacy 将领与朝堂记录可见文案复扫 | legacy 将领 prompt、技能展示、朝堂 rationale 和结构化军令标题继续去工程/旧题材词 | 不改 id、rawValue、rawJSON 字段、record schema、AI 决策、命令结构或规则 |
| v3.7-preflight.71 | CommandPanel 命令消息展示净化 | `CommandPanelView` 显示 `lastCommandMessage` 前先清 raw id，再替换工程词 / 模型词 / hex 词 | 不改 AppContainer 状态存储、交互日志、Command / CommandResult schema、校验逻辑、AI 决策或规则 |
| v3.7-preflight.72 | 单位详情与提示 legacy 单位名展示收口 | `UnitInspectorView` / `UnitTooltipView` 展示单位名前先净化旧 fallback 单位词，并同步 VoiceOver label | 不改 Division.name、JSON、templateId、rawValue、存档 schema、AI 决策、命令结构或规则 |
| v3.7-preflight.73 | 州郡详情 legacy 地名与目标名展示收口 | `RegionInspectorView` 展示州郡、城邑、方面、防区、要地和驻军名前先净化 legacy 地名 / raw id | 不改 region/hex/objective/division 存储、JSON、objectiveId、keyLocations、胜负规则、AI 决策或规则 |
| v3.7-preflight.74 | 将领与总管面板 legacy 文案复扫收口 | `GeneralProfileView` / `GeneralCommandPanelView` 展示将领、军衔、履历、防区、军队和目标名前先净化 legacy 文案 / raw id | 不改 GeneralData、FrontZone、Division.name、PlayerPlannedOperation、JSON、rawValue、存档、AI 决策或规则 |
| v3.7-preflight.75 | MapDisplayAdapter / SpriteKit 地图展示入口 legacy 文案收口 | `MapDisplayAdapter` 输出地图标签、objective 前先净化 legacy 文案 / raw id，详情面板既有 id / faction 展示做局部兜底 | 不改地图 JSON、状态字段结构、objective id、keyLocations、动态权威、AI 决策或规则 |
| v3.7-preflight.76 | MapEditor 选择器与状态消息 legacy 文案收口 | `MapEditorView` 州郡 / 方面选择器和 `MapEditorViewModel` 地点状态消息显示前先净化 legacy 文案 / raw id | 不改 MapEditor 文档、导出 JSON、id / rawValue、默认资源桥、主游戏加载、AI 决策或规则 |
| v3.7-preflight.77 | AppContainer 交互日志与存档反馈 legacy 文案收口 | `AppContainer` 存档、选择、军队、州郡、防区、外交 / 归附命令标题和 fallback 总管名称显示前先净化 legacy 文案 / raw id | 不改存档 schema、GameLogEntry、Command 合同、数据层名称、AI 决策或规则 |
| v3.7-preflight.78 | GameLogEntry 源头战报 legacy 文案收口 | `GameLogEntry.init(...)` 保存 message 前净化 appendEvent / 直接构造路径的 legacy 文案 / raw id | 不改 eventLog schema、relatedRecordId、规则数值、命令执行、数据层名称或 AI 决策 |
| v3.7-preflight.79 | legacy LocalLLM prompt 临时编号别名收口 | `AgentPromptBuilder` prompt 展示名净化，并用临时编号替代真实 id；`LocalLLMDecisionProvider` 解析后回填真实 id | 不改 AgentDecision schema、JSON 字段名、type rawValue、parser / mapper、默认 AI 主链路或规则 |
| v3.7-preflight.80 | legacy fallback 行军总管配置收口 | `guderian` fallback 和 legacy marshal config 中性化，模拟军议 id 前缀从 `marshal_` 改为 `command_` | 不改 marshal / directive schema、Faction enum、JSON 数据、命令管线、规则或存档 |
| v3.7-preflight.81 | 朝堂/外交实际记录 id 展示净化收口 | 补齐真实 `ruler_*_turn_*`、`court_*_turn_*`、`court_<turn>_*`、`diplomacy_<turn>_*` 展示净化，并修正敌对国家计数文案 | 不改记录 id、Codable schema、relatedRecordId、外交判定、命令管线、规则或存档 |
| v3.7-preflight.82 | 行军总管可见称谓净化收口 | `Field Marshal` / `Guderian` 可见显示统一为行军总管 / 历史总管，并补齐 directive/order/agent id 展示净化 | 不改 rawValue、provider suffix、record id、schema、命令管线、规则或存档 |
| v3.7-preflight.83 | 源头 legacy 中文势力/国家/地名净化收口 | `TurnManager`、`DiplomacyState`、`GameLogEntry` 源头展示文本补齐旧中文势力、旧国家、旧地名、旧单位词和工程词净化 | 不改数据、rawValue、record id、schema、命令管线、规则或存档 |
| v3.7-preflight.84 | 将领档案/总管军令称谓净化对齐 | `GeneralProfileView` / `GeneralCommandPanelView` 统一 Field Marshal / Guderian 展示口径并净化空单位名 fallback | 不改 GeneralData、Division.name、AgentRole rawValue、JSON、命令管线、规则或存档 |
| v3.7-preflight.85 | fallback JSON 可见数据文本收口 | `ardennes_v0_scenario`、`ardennes_v02_regions`、`unit_templates`、`generals` 的可见展示字段改为迁移期中性口径 | 不改 JSON key、id、rawValue、schema、坐标、faction、templateId、加载顺序、命令管线、规则或存档 |
| v3.7-preflight.86 | 源码层 legacy 可见兜底文本收口 | `Faction.displayName`、`VictoryReason.displayName`、`DataLoader` 旧战局校验错误改为迁移期中性口径 | 不改 enum rawValue、JSON schema、id、兼容查找、胜负判定、加载顺序、命令管线、规则或存档 |
| v3.7-preflight.87 | 静态 GameState/MapState fallback 可见文本收口 | `GameState.initial()` 与 `MapState.ardennesV0()` 最后兜底的单位、地点、目标和初始化战报改为中性口径 | 不改 scenario id、objective id、faction、坐标、地形、补给源、胜负规则、加载顺序、命令管线或存档 |
| v3.7-preflight.88 | legacy objective lookup 字面量收口 | `VictoryRules`、`RegionVictoryRules`、`MockAIClient` 的旧 fallback 目标查找改为 objective id 优先加中性旧战局名 fallback | 不改 objective id、胜负阈值、AI 策略、`VictoryState` 字段、`VictoryReason` case、命令管线或存档 |
| v3.7-preflight.89 | RegionVictoryRules 隋唐胜负摘要对齐 | `RegionRuleSystem` 使用的 region 层胜负摘要按 `scenarioId` 分支，`wude_618` 读取洛阳、洛口仓、潼关和长安 objective id | 不改主 `VictoryRules` 执行路径、`GameState.victoryState`、胜负阈值、命令管线或存档 |
| v3.7-preflight.90 | 共享隋唐胜负 evaluator 收口 | `VictoryAssessment` 表达评估结果，规则层 `Wude618VictoryEvaluator` 集中维护默认隋唐胜负判断，`VictoryRules` 与 `RegionVictoryRules` 复用 | 不新增文件，不改 Xcode project、objective id、胜负阈值、命令管线、AI 决策或存档 |
| v3.7-preflight.91 | 指令结果语义化固守判定收口 | `CommandResultSummary.commandKind` 记录命令语义，`ZoneCommanderAgent` 最近静态防御判定不再依赖 `Hold` 展示文本 | 不改 Command case、directive schema、AI tactic 阈值、规则执行或存档主结构 |
| v3.7-preflight.92 | 阶段与旧总管展示口径收口 | `GamePhase.displayName` 自动阶段显示为朝堂行动 / 朝堂军令，legacy `general_agents.json` 展示名改为历史总管 | 不改 GamePhase rawValue、legacy id、势力 rawValue、单位 id、AI 决策、命令管线、规则或存档 |
| v3.7-preflight.93 | 自动总管默认指挥风格收口 | `ZoneCommanderAgent.defaultConfig(for:)` 按多势力映射生成默认指挥风格，并与 `AppContainer` 口径对齐 | 不改 directive schema、命令管线、规则执行、AI 阈值、战术选择函数、势力 rawValue 或存档 |
| v3.7-preflight.94 | 默认指挥风格共享 helper 收口 | `ZoneCommanderAgentConfig.CommandStyle.defaultForFaction(_:)` 集中维护默认风格映射，两处生成入口复用 | 不改 CommandStyle case、rawValue、Codable、AI 阈值、命令管线、规则或存档 |
| v3.7-preflight.95 | DataLoader 场景阶段兜底收口 | 无效 `initialPhase` 时 legacy 阿登走 `.alliedPlayer`，隋唐/自定义走 `.playerCommand`，并复用同一 phase 派生 active faction 和初始日志 | 不改 GamePhase rawValue、合法 JSON、命令管线、规则或存档 |
| v3.7-preflight.96 | legacy phase 存档规范化收口 | `GamePhase.normalized` 集中规范化旧 phase，加载、校验、推进和自动回合复用同一口径 | 不改 GamePhase rawValue、Codable、合法阿登推进、命令 schema、规则或存档 |
| v3.7-preflight.97 | 动态方面推进势力兜底收口 | `WarCommandExecutor.applyStrategicAdvance` 不再把异常缺 zone 的推进势力兜底为 `.germany`，改为 zone faction / 行动军队推断，缺失则跳过并记录 | 不改 hex 占领、动态 theater/front/deploy 权威、同步器、命令 schema、规则或存档 |
| v3.7-preflight.98 | RegionDataSet owner/controller 兜底收口 | 非 legacy region 数据缺 owner 时抛出校验错误，只有明确旧战局保留 `.allies` 兼容 fallback | 不改 JSON schema、region 聚合、hex 权威、命令管线、规则或存档 |
| v3.7-preflight.99 | 场景语义与胜负 fallback 门禁收口 | `ScenarioSemantics` 集中判断 legacy / wude_618 / 隋唐草稿 / 未知自定义场景，默认势力和胜负 fallback 复用同一语义门禁 | 不改 Faction rawValue、GamePhase rawValue、旧战局兼容、默认隋唐胜负 evaluator、命令管线或存档 |
| v3.7-preflight.100 | MapEditor 非法 unit faction 导入诊断收口 | 默认资源导入遇到坏 `unit.faction` 时跳过坏 unit 并记录诊断，状态消息显示跳过数量和原因 | 不改 JSON schema、合法 unit faction、主游戏加载顺序、命令管线、规则或存档 |
| v3.7 | 发布候选收口 | 默认剧本、完整发布说明、授权运行时验证、CI/artifact 验收口径 | 未授权重测试前不声称已可发布 |
| v3.8 | 真实本地 LLM / 可插拔模型接入 | 可插拔模型接口、离线 fallback、AI 面板展示模型来源和解析失败 | 不提交 API key、模型路径或个人机器路径 |

## 6. 推荐 Agent 分工

每轮最多并发 3-5 个子 Agent，主 Agent 必须先定公共接口合同和文件边界。

| Agent | 主要范围 | 职责 |
|---|---|---|
| History / Data Agent | `WWIIHexV0/Data/*.json`、`ScenarioDefinition.swift`、`DataLoader.swift` | 隋唐剧本、势力、州郡、人物、胜利条件数据 |
| Rules Agent | `WWIIHexV0/Core/`、`Commands/`、`Rules/` | 多势力、敌我关系、粮草、围城、兵种与规则抽象 |
| AI Agent | `WWIIHexV0/Agents/`、`Turn/` | 君主、谋主、总管、太守、将领、使者 Agent 分层 |
| UI / Art Agent | `WWIIHexV0/UI/`、`SpriteKit/`、assets | 隋唐视觉系统、地图图层、军令和战报交互 |
| MapEditor Agent | `MapEditor/` | 编辑器术语、隋唐地图节点和导出字段兼容 |
| Docs / QA Agent | `README.md`、`update_log.md`、`md/flow/`、`md/test/test.md`、`md/prompt/v3.0-隋唐迁移/` | 文档一致性、轻量检查、风险记录 |

并发后必须检查：

- 是否多个 Agent 改同一文件。
- public API、类型名、枚举 case、JSON key 是否分叉。
- 是否出现 `Faction`、`PowerId`、`CountryId` 三套概念混乱。
- `project.pbxproj` 是否重复引用、缺引用或 UUID 冲突。
- 是否有人绕过 `RuleEngine` 修改状态。
- `hexToTheater`、`hexToFrontZone`、`regionToTheater` 权威边界是否被写错。
- README、`md/flow/*`、阶段记录、`update_log.md` 口径是否一致。

## 7. 文档落点

每个版本完成后至少更新：

- `update_log.md`
- `md/flow/flow.md`
- `md/flow/flowchart.md`
- 当前版本实现记录，例如 `md/prompt/v3.0-隋唐迁移/v3.0_audit_and_contract.md`

当项目身份正式从 WWII 迁移到隋唐后，再更新：

- `AGENTS.md` 的项目总览和基本规则。
- `README.md` 的项目定位、架构图和当前进度。

本轮如果只是大纲调整，应只作为历史维护记录写入 `update_log.md`，不能伪装成 v3.0 已完成。

## 8. 当前首轮结果与下一步

当前已新增 v3.0-v3.7-preflight.100 迁移记录：

- `md/prompt/v3.0-隋唐迁移/v3.0_audit_and_contract.md`
- `md/prompt/v3.0-隋唐迁移/v3.1_powers_diplomacy_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.2_scenario_map_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.3_war_rules_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.4_agent_court_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.5_player_command_ux_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.6_ui_art_polish_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_victory_runtime_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_lifecycle_save_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_onboarding_settings_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_waterway_markers_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_ai_plan_arrows_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_front_ink_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_save_feedback_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_release_notes_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_diplomacy_command_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_region_governance_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_ai_governor_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_ai_diplomat_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_submission_event_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_submission_turn_order_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_submission_presence_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_submission_handoff_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_submission_handoff_audit_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_submission_ai_handoff_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_submission_aftermath_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_submission_aftermath_governor_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_submission_aftermath_governance_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_submission_aftermath_governance_progress_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_submission_aftermath_ungoverned_priority_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_submission_aftermath_completion_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_release_gate_split_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_ai_governor_skip_diagnostics_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_ai_diplomat_skip_diagnostics_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_mapeditor_suitang_bridge_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_mapeditor_key_locations_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_release_static_gate_snapshot_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_visible_legacy_text_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_visible_debug_text_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_visible_diplomacy_court_text_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_visible_ai_diagnostics_text_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_visible_battle_report_command_preview_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_visible_event_source_text_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_visible_app_ui_boundary_text_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_visible_remaining_ui_text_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_visible_ui_followup_text_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_player_faction_selection_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_mapeditor_visible_text_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_data_notes_visible_text_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_ai_marshal_directive_summary_text_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_legacy_mockai_diagnostics_text_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_legacy_json_visible_text_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_legacy_general_profile_text_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_agent_diagnostic_error_fallback_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_auto_turn_marshal_diagnostic_fallback_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_data_loader_mapeditor_export_text_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_review_panel_ui_record_text_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_mapeditor_main_ui_raw_id_text_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_command_error_visible_text_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_zone_display_name_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_legacy_data_display_text_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_legacy_unit_region_display_text_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_legacy_static_fallback_objective_text_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_legacy_llm_prompt_language_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_diplomacy_panel_name_sanitizer_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_event_log_intent_category_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_mapeditor_export_metadata_fallback_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_agent_panel_diagnostic_sanitizer_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_legacy_general_agent_config_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_legacy_prompt_internal_id_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_legacy_prompt_passthrough_sanitizer_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_legacy_prompt_agent_identity_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_legacy_mockai_stance_text_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_legacy_prompt_schema_wording_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_marshal_pure_json_output_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_ui_record_sanitizer_helper_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_legacy_general_court_visible_text_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_command_panel_message_text_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_legacy_unit_detail_tooltip_text_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_legacy_region_detail_location_objective_text_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_legacy_general_panel_record_summary_text_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_map_display_adapter_spritekit_legacy_text_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_mapeditor_selector_status_text_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_appcontainer_interaction_text_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_event_log_source_sanitizer_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_agent_prompt_alias_sanitizer_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_legacy_marshal_fallback_config_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_court_diplomacy_record_id_sanitizer_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_marshal_visible_title_sanitizer_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_source_legacy_chinese_text_sanitizer_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_general_panel_title_sanitizer_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_legacy_fallback_json_visible_data_text_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_legacy_source_fallback_visible_text_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_legacy_static_fallback_source_text_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_legacy_objective_lookup_text_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_region_victory_suitang_alignment_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_shared_victory_evaluator_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_command_result_semantic_kind_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_phase_legacy_agent_display_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_agent_default_command_style_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_command_style_helper_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_dataloader_phase_fallback_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_legacy_phase_normalization_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_dynamic_theater_faction_fallback_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_region_dataset_ownership_fallback_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_scenario_semantics_victory_gating_record.md`
- `md/prompt/v3.0-隋唐迁移/v3.7_mapeditor_unit_faction_import_diagnostic_record.md`

v3.0 文档完成了硬编码扫描、二元阵营假设审计、迁移词汇表、兼容层合同、P0/P1/P2/P3 优先级、风险清单和 v3.1 入口提示词草案。v3.1 已做最小代码迁移：`Faction` 增加隋唐势力，`GamePhase` 增加 `playerCommand/aiCommand`，核心敌对判断迁入 `DiplomacyState`。v3.2 已新增 `wude_618_guanzhong_luoyang` 默认剧本数据、36 个州郡 region、隋唐 unit templates / generals / power profiles，并让主游戏默认优先加载 `wude_618`。v3.3 已新增隋唐 `ComponentType` 语义、更新 `suitang_unit_templates`、加入围城派生判断、攻城/骑军战斗修正、粮草补员限制和主要面板隋唐显示。v3.4 已接入 `CourtAgent / RulerAgent` 朝堂分层，在 AI directive 执行前记录君主、谋主、太守、行军总管、将领、使者步骤，并把 `RulerDecisionRecord` / `CourtDecisionRecord` 写入 `DiplomacyState`。v3.5 已增强玩家侧信息闭环：战报摘要、外交中文化、州郡价值提示、军令入口和交互日志中文化。v3.6 已完成发布级 UI 收口第一步：新增 `SuitangDesignTokens` 和 `suitangPanel`，统一 HUD、图层、军情入口、常用面板与将领档案视觉基底，清理显眼英文调试文案，并在 `HexNode` / `BoardScene` 加入最小城池、关隘、粮仓、粮道和围城地图标识。v3.7-preflight 已把 `wude_618` 长安、洛阳、洛口仓、潼关胜利目标接入 `VictoryRules`，并让 HUD 显示胜者与中文原因。v3.7-preflight.2 已加入 `GameSaveStore` 本地 JSON 自动存档，启动优先继续存档，HUD/macOS 菜单提供新局、继续和重置。v3.7-preflight.3 已新增 HUD 筹备菜单、开局引导、基础设置和发布前检查面板，作为完整发布候选前置 UI。v3.7-preflight.4 已新增 `MapState.featureMarkers`，把 scenario `keyLocations` 转为地图只读地点标识，并绘制蒲津渡、孟津渡、黎阳津和洛口津图标。v3.7-preflight.5 已把最近非玩家 `WarDirectiveRecord` 绘制为 AI 虚线计划箭头或防守圈。v3.7-preflight.6 已在普通地图层从 `FrontLineState` 绘制最小前线墨线和包围/崩溃态朱色警示虚线。v3.7-preflight.7 已新增 `GameSaveStatus` 和 `AppContainer.saveStatus`，让本地存档读取、保存、删除反馈进入 HUD、基础设置和发布检查面板。v3.7-preflight.8 已把首发定位、资产边界和验证口径收进发布前检查面板，并明确当前地图标识仍是代码绘制或派生显示。v3.7-preflight.9 已新增 `Command.updateDiplomacy`，让外交面板“议和 / 纳降”通过 `RuleEngine` 更新 `DiplomacyState`，不直接转移战术占领或军队归属。v3.7-preflight.10 已新增 `Command.governRegion`，让州郡面板“修道 / 屯田 / 安民”通过 `RuleEngine` 更新道路仓储、粮仓或治安顺从，并扣除府库资源，不直接改变 hex、军队、动态方面或行军防区。v3.7-preflight.11 已让 AI/观战自动回合在朝堂记录后最多生成一条 `Command.governRegion`，仍经 `RuleEngine` 执行太守经营，不直接修改 region、hex、军队、动态方面或行军防区。v3.7-preflight.12 已让 AI/观战自动回合在保守条件下最多生成一条 `Command.updateDiplomacy`，仍经 `RuleEngine` 执行停战或归附关系更新，不直接转移 hex、region、军队或部署。v3.7-preflight.13 已让外交关系变化生成 `DiplomacyEventRecord` 并关联外交战报，外交面板可显示最近事件和边界说明；归附仍只作为关系事件，不直接执行地图或军队交接。v3.7-preflight.14 已让已归附且无存活军队、无可通行受控 hex 的势力退出通用隋唐回合轮转；v3.7-preflight.15 已让外交面板盘点归附目标残余军队和受控可通行 hex，并把归附目标判定收口到 `DiplomacyState` helper；v3.7-preflight.16 已新增 `Command.resolveSubmissionHandoff`，让归附接收方经 `RuleEngine` 接管归附目标未毁灭军队和可通行受控 hex；v3.7-preflight.17 已新增 `SubmissionHandoffRecord`，让归附交接结果进入存档、外交战报关联和外交面板复盘；v3.7-preflight.18 已让 AI 接收方在 AI 回合最多执行一条归附实体交接命令；v3.7-preflight.19 已新增 `SubmissionAftermathRecord`，让归附交接后的善后压力进入存档、外交日志关联和外交面板复盘；v3.7-preflight.20 已让 AI 太守优先治理最新高/需安抚善后压力州郡，仍经 `Command.governRegion` 和 `RuleEngine` 执行；v3.7-preflight.21 已让治理最新善后州郡后生成 `SubmissionAftermathGovernanceRecord` 处置审计记录；v3.7-preflight.22 已让外交面板显示本次善后处置进度摘要；v3.7-preflight.23 已让 AI 太守优先治理最新善后记录中尚未处置的州郡；v3.7-preflight.24 已让外交面板显示待处置数量和完成状态，并让 AI 在本次善后全部处置后退出该记录的特殊优先队列；v3.7-preflight.25 已让发布前检查面板明确区分代码已接入、运行时未验证和后续功能；v3.7-preflight.26 已让 AI 太守未生成经营命令时记录确定性跳过原因；v3.7-preflight.27 已让 AI 使者和归附交接未生成命令时记录确定性跳过原因；v3.7-preflight.28 已把 MapEditor 默认资源桥切到 `wude_618_scenario` / `wude_618_regions`，并让默认覆盖保存保留既有场景元数据和水路地点记录；v3.7-preflight.29 已把 MapEditor `keyLocations` 做成可读取、编辑、删除和导出的地点字段；v3.7-preflight.30 已把发布前检查面板升级为当前 `GameState` 静态门禁快照；v3.7-preflight.31 已收口 legacy 势力、旧阶段/胜负原因、军队方向码和经济事件日志的玩家可见旧英文兜底；v3.7-preflight.32 已收口第一批 App/AI 记录、bootstrap 战报、朝堂面板和将领技能显示的玩家可见调试文案；v3.7-preflight.33 已收口外交面板、君主决策摘要、州郡/军队详情和基础可访问性入口中的一批 raw id、英文 fallback 与工程术语；v3.7-preflight.34 已收口 AI 面板、方面军令诊断、命令结果摘要和 legacy Agent D 失败路径中的一批 raw id、英文 fallback、provider suffix、工程术语和校验 rawValue；v3.7-preflight.35 已收口战报 metadata、军议意图、战报重点摘要和总管预备军令预览中的一批 raw id 与工程格式；v3.7-preflight.36 已收口规则、军令、战略同步和经济源头事件中的一批 raw id、validation rawValue、英文工程词和生产调试编号；v3.7-preflight.37 已收口存档反馈、自动回合、命令面板、发布检查和详情面板中的系统错误、provider、scenario raw id 与工程词；v3.7-preflight.38 已抽样收口开局引导、HUD、经济、战报、外交、州郡经营、总管和单位提示中的 AI/Xcode、scenario fallback 和工程分隔符；v3.7-preflight.39 已复扫收口战局复核、App 反馈、外交边界说明、战报 metadata、单位兵力和地图短标中的发布验收口径、规则工程口径、旧剧本 fallback、斜线与 N/M 显示；v3.7-preflight.40 已让 `GameState.playerFaction` 进入本局状态和本地存档，基础设置可选择当前局势内可玩的执掌势力，通用 `.playerCommand` / `.aiCommand` 阶段推进按 `state.playerFaction` 判定；v3.7-preflight.41 已收口 MapEditor 默认隋唐编辑入口的可见旧势力选项、工程词、raw id、系统错误、完整路径和单位英文短标，且不改变 JSON schema、rawValue 或主游戏规则；v3.7-preflight.42 已收口默认隋唐 dataNotes、MapEditor 导出说明、派生粮仓地点名、数据加载初始战报和补给撤退事件中的可见英文工程口径；v3.7-preflight.43 已收口 AI 元帅意图、方面军令摘要、编译上下文、模拟元帅 rationale 和 fallback 诊断中的可见英文工程口径。

v3.7-preflight.44-.95 已连续收口 legacy 可见文案、记录净化、胜负摘要共享、命令结果语义化、阶段/总管展示口径、自动总管默认风格、默认风格共享 helper 和 DataLoader 场景阶段兜底。v3.7-preflight.96 已让 `GamePhase.normalized` 集中规范化旧 phase 存档语义，加载、App 状态切换、命令校验、回合推进和自动回合判断复用同一口径，合法 legacy 阿登阶段仍保留，隋唐或自定义脏 phase 会落到通用玩家/朝堂军令阶段，且不改 GamePhase rawValue、Codable、命令 schema、规则或存档字段。v3.7-preflight.97 已让 `WarCommandExecutor.applyStrategicAdvance` 不再把异常缺 zone 的动态方面推进势力静默兜底为旧东路势力，改为 zone faction / 行动军队推断，缺失则跳过并记录原因。v3.7-preflight.98 已让非 legacy `RegionDataSet` 缺 owner 时抛出校验错误，不再静默兜底旧西路势力。v3.7-preflight.99 已用 `ScenarioSemantics` 收口默认场景语义和胜负 fallback 门禁。v3.7-preflight.100 已让 MapEditor 默认资源导入遇到非法 unit faction 时跳过坏 unit 并生成可见诊断。

下一轮如果继续 v3.7 发布候选前置或进入完整 v3.7，建议执行顺序：

1. 读 `AGENTS.md`、`update_log.md`、`md/flow/flow.md`、`md/flow/flowchart.md`、`md/test/test.md`、v3.0 总提示词。
2. 读 `md/prompt/v3.0-隋唐迁移/v3.0_audit_and_contract.md`、`v3.1_powers_diplomacy_record.md`、`v3.2_scenario_map_record.md`、`v3.3_war_rules_record.md`、`v3.4_agent_court_record.md`、`v3.5_player_command_ux_record.md`、`v3.6_ui_art_polish_record.md`、`v3.7_victory_runtime_record.md`、`v3.7_lifecycle_save_record.md`，以及 `.88-.100` 最新记录：`v3.7_legacy_objective_lookup_text_record.md`、`v3.7_region_victory_suitang_alignment_record.md`、`v3.7_shared_victory_evaluator_record.md`、`v3.7_command_result_semantic_kind_record.md`、`v3.7_phase_legacy_agent_display_record.md`、`v3.7_agent_default_command_style_record.md`、`v3.7_command_style_helper_record.md`、`v3.7_dataloader_phase_fallback_record.md`、`v3.7_legacy_phase_normalization_record.md`、`v3.7_dynamic_theater_faction_fallback_record.md`、`v3.7_region_dataset_ownership_fallback_record.md`、`v3.7_scenario_semantics_victory_gating_record.md`、`v3.7_mapeditor_unit_faction_import_diagnostic_record.md`。
3. 审计工作树和分支，不回滚用户改动。
4. v3.7 发布候选前置说明、外交/州郡命令、AI 太守/使者/交接、归附善后记录、多轮玩家可见文案、记录 id 净化、胜负摘要共享、默认指挥风格、legacy phase 规范化、动态方面推进势力兜底、RegionDataSet owner 校验、场景语义门禁和 MapEditor 非法 unit faction 导入诊断已基本完成；下一步优先从正式地图资产/截图复核、完整发布候选运行时与 CI artifact 验收、善后实际规则、水战/港口补给、真实模型接入中切片。
5. 保证 UI 仍只读取状态或提交 `Command` / `ZoneDirective`，不得把规则写入 View 或直接修改 `GameState`。
6. 只跑 `md/test/test.md` 允许的轻量检查；重验证交给云端或人工授权。

如需复查审计结果，可用扫描命令：

```sh
rg -n "germany|allies|Ardennes|Panzer|Bastogne|Division|German AI|Allied Player|Marshal|Ruler|Faction\\.opponent" WWIIHexV0 MapEditor README.md md
rg -n "enum Faction|enum GamePhase|struct Division|enum ComponentType|EconomyResources|DiplomacyState|GeneralData|ZoneDirective|WarCommandExecutor|RuleEngine" WWIIHexV0
```

轻量检查建议：

```sh
rg -n "[[:blank:]]+$" AGENTS.md README.md update_log.md md/test/test.md md/flow/flow.md md/flow/flowchart.md md/prompt/v3.0-隋唐迁移 md/plan/plan.md
rg -n "<{7}|={7}|>{7}" AGENTS.md README.md update_log.md md/test/test.md md/flow WWIIHexV0 MapEditor
git diff --check
```
