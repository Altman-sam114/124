# WWIIHexV0 核心流程文档（v3.7-preflight.103 隋唐迁移）

> 本文是项目当前核心逻辑的接手文档。目标不是复述历史设计，而是按当前代码真实链路说明：数据如何进入游戏，hex / region / theater / front / deploy 如何派生，主游戏和地图编辑器如何共同维护同一套地图语义，AI / 玩家命令如何落到规则系统。

资料依据：`AGENTS.md`、`README.md`、`update_log.md`、`md/test/test.md`、v0.355/v0.36/v0.37 阶段文档、v3.0-v3.7 隋唐迁移阶段记录、最近 git 记录，以及当前源码中的 `Core/`、`Rules/`、`Commands/`、`Agents/`、`Turn/`、`App/`、`SpriteKit/`、`UI/`、`MapEditor/` 与关键测试。

---

## 0. 一句话总览

当前主链路是：

```text
MapEditor / JSON 数据
  -> DataLoader
  -> GameState
  -> Hex controller / Division coord
  -> Region 聚合
  -> EconomyState 收入 / 生产 / 补员
  -> Initial Theater snapshot + runtime hexToTheater
  -> FrontLine 动态 hex 接触
  -> WarDeployment hexToFrontZone + FRONT/DEPTH/GARRISON
  -> MarshalAgent / TheaterDirective JSON
  -> TheaterDirectiveDecoder
  -> TheaterDirectiveCompiler
  -> CourtAgent / RulerAgent 朝堂塑形与审计
  -> ZoneCommanderAgent fallback / 手写 ZoneDirective
  -> WarCommandExecutor
  -> RuleEngine
  -> CommandExecutor
  -> VictoryRules
  -> StrategicStateSynchronizer
  -> UI overlay / 日志 / WarDirectiveRecord
```

当前协作与验证主链路是：

```text
人工目标 / a:b:c 角色召唤
  -> Agent A 写版本化提示词
  -> Agent B 在 main 上实现
  -> 本机轻量检查
  -> commit + push origin main
  -> GitHub Actions 云端 build / 静态检查
  -> 未加密 CI 结果包
  -> Agent C 下载并核对 manifest / JUnit / 日志 / run 信息
  -> 通过则更新核心文档；失败则退回 Agent B 在 main 追加修复 commit
```

最关键的铁律：

- `HexTile.controller` 和 `Division.coord` 是战术层权威。
- `RegionNode.controller` 是从 region 内 hex controller 加权聚合出来的战略快照。
- `regionToTheater` 是初始/基础战区归属，不是运行时推进层。
- `hexToTheater` 是运行时动态战区权威。
- `hexToFrontZone` 是部署层动态归属权威。
- `EconomyState` 是 faction 级经济总账；收入来自受控 region、城市、工厂、基础设施和补给值，但战术占领仍以 hex 为准。
- 玩家、AI、后续聊天命令最终都必须经过 `Command` / `ZoneDirective -> WarCommandExecutor -> RuleEngine`，不能直接改 `GameState`。
- v3.4 默认战争 AI 上游是 `MarshalAgent -> TheaterDirective JSON -> TheaterDirectiveDecoder -> TheaterDirectiveCompiler -> CourtAgent / RulerAgent`，下游执行收口到 `ZoneDirective -> WarCommandExecutor -> RuleEngine`。
- 朝堂层只塑形和审计 `DirectiveEnvelope`，写入 `RulerDecisionRecord` / `CourtDecisionRecord`；它不直接生成底层 `Command`，也不直接修改 hex、单位、战区、部署或外交关系。
- 协作验证层以 `main` 直推和 GitHub Actions 结果包为准；本机默认只跑轻量检查，Agent C 不再只凭文字汇报验收。

### 0.1 v3.0-v3.7-preflight.103 隋唐迁移状态

当前已存在隋末唐初迁移总提示词、v3.0 审计合同、v3.1 最小兼容迁移记录、v3.2 默认数据迁移记录、v3.3 战争规则迁移记录、v3.4 朝堂 AI 分层记录、v3.5 玩家体验记录、v3.6 UI 收口记录，以及 v3.7-preflight 至 v3.7-preflight.103 的发布候选前置记录。最近阶段已完成 RegionVictoryRules 隋唐胜负摘要对齐、共享隋唐胜负 evaluator 收口、指令结果语义化固守判定收口、阶段与旧总管展示口径收口、自动总管默认指挥风格收口、默认指挥风格共享 helper 收口、DataLoader 场景阶段兜底收口、legacy phase 存档规范化收口、动态方面推进势力兜底收口、RegionDataSet owner/controller 兜底收口、ScenarioSemantics 场景语义和胜负 fallback 门禁收口、MapEditor 非法 unit faction 导入诊断收口、归附善后治安压力落地、归附善后贡赋效率落地，以及渡口港口粮道补给减免落地：

- `md/prompt/v3.0-隋唐迁移/codex-v3.0-隋末唐初aiagent历史策略迁移总提示词.md`
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

这表示项目已完成 v3.0 文档合同，并在 v3.1 做了最小代码迁移：`Faction` 现在可 Codable 表达唐、洛阳隋、瓦岗、夏、薛秦、刘武周、东突厥；`GamePhase` 新增 `playerCommand` / `aiCommand`；核心敌对判断新增 `DiplomacyState.isHostile` / `canAttack`，生产主路径不再直接依赖 `.opponent`。

v3.2 已新增 `wude_618_guanzhong_luoyang` 默认剧本数据，并让主游戏启动优先加载 `wude_618_scenario` / `wude_618_regions`。该数据包含 90 个 hex、36 个 region、7 个隋唐势力、19 支初始军队，以及隋唐 unit template、general registry、power profile 和 terrain rule 文件。若新数据加载失败，`DataLoader` 仍 fallback 到阿登路径，避免破坏旧调试入口。

v3.3 已做最小战争规则和显示迁移：`ComponentType` 可直接表达骑军、弓弩、攻城器械、亲军、水师、乡兵；`suitang_unit_templates.json` 已改用新 component rawValue；`SupplyRules.isBesieged` 从城池/关隘、敌邻接和粮道状态派生围城；战术、HUD、军队/州郡/经济/AI 面板显示改为隋唐口径。围城仍不是独立权威状态，不会绕过 hex 占领或 `RuleEngine`。

v3.4 已把朝堂 AI 分层接入战争 AI directive 上游：`CourtAgent` 调用 `RulerAgent` 选择君主姿态并调整 `DirectiveEnvelope`，同时记录君主、谋主、太守、行军总管、将领和使者步骤。`TurnManager` 在 `.marshalDirective` 和 `.zoneDirective` 路径都会写入 `RulerDecisionRecord` 与 `CourtDecisionRecord`。这些记录先用于塑形、审计和 UI 展示；v3.7-preflight.11/.12 起，太守和使者记录会在 AI 回合被保守转化为 `Command.governRegion` 或 `Command.updateDiplomacy`，仍经 `RuleEngine` 执行。

v3.5 已做玩家信息闭环最小迁移：战报面板聚合朝堂姿态、AI 意图、方面军令执行/拒绝统计和重点事件；外交面板显示中文关系、朝堂和使者摘要；州郡面板显示粮仓、征发、前线压力、敌军和胜负要点；军令面板和主要交互日志改为中文。该版本仍只读取现有状态和记录，不新增内政或外交执行器。

v3.6 已完成发布级 UI 收口的第一步：`SuitangDesignTokens` 与 `View.suitangPanel(_:)` 提供统一绢帛、墨色、朱印、铜色、青绿和水色基底；HUD、图层选择、军情入口、常用面板和将领档案改用统一 panel 样式；`NEW GAME`、`Observer`、`[ INFO ]`、地图图层英文和将领档案英文标题等显眼玩家文案已中文化。`HexNode` 已用代码绘制最小城池、关隘和粮仓标识，并移除旧 `FORT`、`SUP A`、`SUP G` 调试标签。`BoardScene` 已用现有 `SupplyRules` 和可见单位 placement 绘制最小粮道虚线与围城圈。该版本仍不新增规则、外部素材或大规模 SpriteKit 地图重绘。

v3.7-preflight 已把 `wude_618_guanzhong_luoyang` 的核心胜利条件接入运行时：`VictoryRules` 会按 objective id 读取长安、洛阳、洛口仓和潼关的 hex 控制者；唐控制洛阳与洛口仓即胜，洛阳隋夺取潼关即胜，终局最后一个势力行动结束后按长安控制权结算。HUD 的胜负字段会显示胜者和中文胜利原因。旧阿登胜利规则仍保留 legacy 分支。

v3.7-preflight.2 已补上本地自动存档和局势生命周期入口：`GameSaveStore` 使用 Documents 下的 JSON 文件保存 `GameState`；`AppContainer.bootstrap()` 优先读取本地存档，失败时 fallback 默认剧本；玩家命令、总管 `ZoneDirective` 和 AI 回合结算后自动保存；HUD 与 macOS 菜单提供新局、继续和重置。该层只保存/加载 `GameState`，不直接修改 hex、单位、战区、部署或规则。

v3.7-preflight.3 已补上最小发布候选前置 UI：HUD “筹备”菜单可打开开局引导、基础设置和发布前检查面板；开局引导只读当前剧本/回合/势力并提示第一回合操作顺序；基础设置复用现有观战模式和地图图层 setter，不写入存档；发布前检查面板列出已接入事项、仍待授权验证事项和 `天命开唐 Agent · v3.7-preflight.3` 版本说明。该层不新增规则，不直接修改 `GameState`。

v3.7-preflight.4 已把 scenario `keyLocations` 转为 `MapState.featureMarkers`，并对 `ferry`、`port`、`harbor` 绘制最小渡船/帆船图标；`wude_618` 新增蒲津渡、孟津渡、黎阳津和洛口津。`featureMarkers` 是显示数据，旧存档缺字段时默认空数组，不参与水战、移动、补给或胜负规则。

v3.7-preflight.5 已把最近 AI `WarDirectiveRecord` 通过 `BoardRenderState.recentDirectiveRecords` 传入地图；`BoardScene` 会把最近 6 条非玩家 directive 画成势力色虚线箭头或防守圈。该层只读 directive 记录，不改变 AI 决策、执行器或规则。

v3.7-preflight.6 已在普通地图层叠加最小前线墨线：`BoardScene` 从 `FrontLineState` 经 `MapLayerOverlayCalculator.frontLineChains()` 读取接触线，在非 `.frontLine` 图层绘制墨色线、单点接触标记，以及包围/崩溃态朱色警示虚线。该层只读前线派生状态，不改变战区、部署、单位、占领或规则。

v3.7-preflight.7 已补上最小本地存档错误反馈：`GameSaveStatus` 表达保存/读取/删除的成功、提示或失败状态，`AppContainer.saveStatus` 在启动读取、继续、自动保存和重置删除时更新；HUD 只在失败时显示 `SaveStatusBanner`，基础设置和发布前检查面板显示完整存档反馈。该层不改变存档 JSON schema，不改变 `GameState` 规则语义。

v3.7-preflight.8 已把发布说明、资产边界和验证口径收进发布前检查面板：`ReleaseChecklistView` 显示首发定位、当前入口、本机轻量检查 / 运行时重测边界，并明确城池、关隘、粮仓、渡口、港口、AI 箭头和前线墨线仍是代码绘制或派生显示。该层不引入外部素材或 asset catalog，不改变地图、命令、AI、存档、胜负、补给、移动或战斗规则。

v3.7-preflight.9 已把最小外交议和/纳降动作接入统一命令管线：`Command.updateDiplomacy` 由 `CommandValidator` 校验当前行动势力和双方 country profile，再由 `CommandExecutor` 更新 `DiplomacyState.relations` 并写入 `.diplomacy` 战报；`DiplomacyPanelView` 的“议和 / 纳降”按钮通过 `AppContainer.submit` 进入 `RuleEngine`。该层只改变外交关系，不直接转移 hex、region、unit、theater 或 deploy 权威。

v3.7-preflight.10 已把最小州郡经营动作接入统一命令管线：`Command.governRegion` 支持修道、屯田和安民，由 `CommandValidator` 校验当前行动势力、己方实际控制州郡、府库资源和经营上限，再由 `CommandExecutor` 扣除府库并更新 `RegionNode.infrastructure`、`supplyValue` 或 `occupationState`；`RegionInspectorView` 的“太守”动作区通过 `AppContainer.submit` 进入 `RuleEngine`。该层只改变 region 战略字段和 `EconomyState` 府库，不直接改变 hex controller、unit、theater、front 或 deploy 权威。

v3.7-preflight.11 已把 AI 太守主动经营接入 AI 回合：`TurnManager.executeDirectiveEnvelope` 在朝堂记录写入后、`endTurn` 前，为 AI/观战自动回合最多生成一条 `Command.governRegion`。候选州郡优先使用 `CourtDecisionRecord` 太守步骤关注点，再按粮仓、道路、治安和己方驻军评分排序；政策仍使用 v3.7-preflight.10 的修道、屯田、安民，并交给 `commandHandler.execute` / `RuleEngine` 校验和执行。该层不直接修改 region、hex、unit、theater、front 或 deploy，只通过命令结果进入 `AgentDecisionRecord`。

v3.7-preflight.12 已把 AI 使者主动外交接入 AI 回合：`TurnManager.executeDirectiveEnvelope` 在 AI 太守经营后、`endTurn` 前，为 AI/观战自动回合最多生成一条 `Command.updateDiplomacy`。使者只在保守条件下行动：敌方已经无存活军队且无可通行受控州郡时标记 `submitted`；己方战力、州郡或战意明显不足时向压力最高的敌对势力提出 `truce`。该层只更新 `DiplomacyState` 关系并记录命令结果，不直接转移 hex、region、unit、theater、front 或 deploy 权威。

v3.7-preflight.13 已把最小归附事件记录链接入外交命令：`CommandExecutor.executeDiplomacyUpdate` 更新关系后会追加 `DiplomacyEventRecord`，并把 `.diplomacy` 战报的 `relatedRecordId` 指向该记录。`DiplomacyPanelView` 会展示最近外交事件和边界说明。该层仍只记录关系事件，不直接转移 hex、region、unit、theater、front 或 deploy 权威。

v3.7-preflight.14 已把归附空势力轮转收口接入通用回合顺序：`CommandExecutor.turnOrder(in:)` 会过滤已经作为 `submitted` 目标记录、且没有存活军队、没有可通行受控 hex 的势力。该层只影响 turn order，不直接转移 hex、region、unit、theater、front 或 deploy 权威。

v3.7-preflight.15 已把归附目标判定收口到 `DiplomacyState.isSubmittedTarget(_:)` / `submittedTargetFactions()`：有新事件记录时只按 `DiplomacyEventRecord.target` 判断归附目标，旧存档缺事件记录时才 fallback 到 `.submitted` 关系状态。`AppContainer.submissionPresenceSummaries` 只读统计归附目标的存活军队和可通行受控 hex，`DiplomacyPanelView` 展示这些实体是否会让归附势力继续进入回合轮转。该层只做盘点和说明，不直接转移 hex、region、unit、theater、front 或 deploy 权威。

v3.7-preflight.16 已把最小归附实体交接接入统一命令管线：`Command.resolveSubmissionHandoff` 由 `CommandValidator` 校验当前行动接收方、外交归附关系和残余实体存在，再由 `CommandExecutor` 把归附目标未毁灭军队与可通行受控 hex 交给接收方，并刷新 region / theater / front / deploy 派生层。该层不删除外交档案、关系或事件记录，不处理贡赋、忠诚、叛乱、俘虏或安置。

v3.7-preflight.17 已把归附实体交接结果写入结构化审计记录：`DiplomacyState` 保存 `SubmissionHandoffRecord`，`CommandExecutor.executeSubmissionHandoff` 完成交接后追加记录并把外交战报 `relatedRecordId` 指向该记录，`DiplomacyPanelView` 展示最近交接摘要、回合、影响州郡数量和边界说明。该层只审计已完成交接，不新增忠诚、叛乱、贡赋、俘虏、安置或交接后治理。

v3.7-preflight.18 已把 AI 归附实体交接接入 AI 自动回合：`TurnManager.executeDirectiveEnvelope` 在 AI 太守经营和 AI 使者外交后、`.endTurn` 前，最多生成一条 `Command.resolveSubmissionHandoff`。候选目标必须已归附当前 AI 势力，且仍有未毁灭军队或可通行受控 hex；命令仍由 `CommandValidator -> RuleEngine -> CommandExecutor` 校验执行，结果进入 `AgentDecisionRecord.commandResults`。该层不做批量交接、忠诚、叛乱、贡赋、俘虏、安置或交接后治理。

v3.7-preflight.19 已把归附交接后的善后压力写入复盘记录：`DiplomacyState` 保存 `SubmissionAftermathRecord`，`CommandExecutor.executeSubmissionHandoff` 在追加交接审计记录后追加善后压力记录，并写入一条 `.diplomacy` 日志；`DiplomacyPanelView` 展示最近善后压力、回合、影响州郡数量和边界说明。v3.7-preflight.101 起压力会落到治安/顺从，v3.7-preflight.102 起会进一步影响后续贡赋效率；仍不触发完整忠诚、叛乱、俘虏、安置或额外归属转移。

v3.7-preflight.20 已把归附善后压力接入 AI 太守经营优先级：`TurnManager.governorCommand` 会读取最新 `SubmissionAftermathRecord`，当当前 AI 势力是接收方且压力等级为高或需安抚时，把受影响州郡排在普通朝堂太守关注点之前；候选州郡仍必须由当前势力控制且有实际受控 hex，命令仍是每回合最多一条 `Command.governRegion` 并经 `RuleEngine` 校验执行。善后州郡优先尝试安民，府库不足或经营上限不满足时回到既有屯田/修道择优；该层不新增忠诚、叛乱、贡赋、俘虏、安置或额外交接效果。

v3.7-preflight.21 已把善后治理结果写入结构化处置审计：`DiplomacyState` 保存 `SubmissionAftermathGovernanceRecord`，`CommandExecutor.executeRegionGovernance` 在既有 `Command.governRegion` 成功执行后，若治理州郡属于最新善后压力记录且当前势力是接收方，就追加处置记录并写入外交日志；`DiplomacyPanelView` 会展示当前善后是否已有本次处置。该层只审计既有州郡经营命令，不清零善后压力，不新增忠诚、叛乱、贡赋、俘虏、安置、资源变化或额外交接效果。

v3.7-preflight.22 已把善后处置记录汇总为只读进度摘要：`DiplomacyState` 可按善后记录筛选 `SubmissionAftermathGovernanceRecord`，并按受影响州郡统计已处置数量；`DiplomacyPanelView` 在“善后”区展示本次处置进度，例如 `1/3 处`。该层只改善复盘可读性，不清零善后压力，不新增规则效果、额外资源变化、命令类型或 AI 行动次数。

v3.7-preflight.23 已把处置进度反馈给 AI 太守候选排序：`DiplomacyState` 可按最新善后记录区分已处置 / 未处置受影响州郡，`TurnManager.aftermathGovernorRegionIds` 会把未处置州郡排在已处置州郡之前。AI 仍每回合最多提交一条既有 `Command.governRegion`，仍经 `RuleEngine` 执行；该层只影响候选顺序，不新增命令类型、忠诚、叛乱、贡赋、俘虏、安置、资源变化或额外行动次数。

v3.7-preflight.24 已把最新善后记录的待处置数量和完成状态补进外交面板：`DiplomacyState` 可统计未处置州郡数量，并判断本次善后是否所有受影响州郡都有处置记录；`TurnManager.aftermathGovernorRegionIds` 在本次善后已全部处置后不再把该记录作为特殊优先来源。该层只改善复盘和候选队列收口，不清零善后压力，不删除审计记录，不新增忠诚、叛乱、贡赋、俘虏、安置、资源变化或命令效果。

v3.7-preflight.25 已把发布前检查面板拆成更明确的发布门禁视图：`ReleaseChecklistView` 显示 `代码状态：候选接入` 和 `运行时门禁：未授权`，并把清单分为“代码已接入”“运行时未验证”和“后续功能”。该层只改 UI 和文档，不改变规则、命令、AI、存档、地图数据或运行时验证结论。

v3.7-preflight.26 已把 AI 太守未生成经营命令时的静默空结果改为确定性诊断：当朝堂存在太守步骤，或存在未完成的高/需安抚善后上下文，但 `TurnManager.governorCommand` 没有返回 `Command.governRegion` 时，`AgentDecisionRecord.errors` 会记录跳过原因，例如没有可治理州郡、没有可用或可负担政策、对应善后记录仍有多少州郡未处置。该层只补诊断，不新增命令类型，不增加 AI 行动次数，不改变州郡经营校验、消耗或效果。

v3.7-preflight.27 已把 AI 使者和归附交接未生成命令时的静默空结果改为确定性诊断：当朝堂存在使者步骤，但 `TurnManager.diplomatCommand` 没有返回 `Command.updateDiplomacy` 时，`AgentDecisionRecord.errors` 会记录缺少国家档案、无敌对目标、无可归附目标或未达到停战阈值等原因；当存在已归附目标上下文但没有生成 `Command.resolveSubmissionHandoff` 时，会记录目标不属于当前接收方或没有残余军队/受控可通行 hex 等原因。该层只补诊断，不新增外交状态，不增加 AI 行动次数，不改变外交或交接命令的校验、消耗或执行效果。

v3.7-preflight.28 已把 MapEditor 默认资源桥从阿登 JSON 切到 `wude_618_scenario` / `wude_618_regions`：编辑器读取和覆盖保存默认指向隋唐剧本，导出器新增 `MapEditorExportMetadata`，覆盖默认资源时保留既有势力列表、回合配置、胜负条件、objective 点数、渡口/港口 `keyLocations` 和 data notes；编辑器默认文档、模式标题、州郡/方面/军队面板、隋唐单位模板和城池/关隘命名也同步收口。该层只迁移默认桥和最小编辑器口径，不新增水路地点编辑字段，不改变 JSON schema、主游戏加载、规则或动态战区权威。

v3.7-preflight.29 已把 scenario `keyLocations` 变成 MapEditor 文档字段：默认读取 `wude_618` 时会还原城池、关隘、粮仓、渡口、港口和海港地点；右键信息面板可编辑名称、类型、势力和 objectiveId；导出时以文档地点字段优先，旧文档缺字段时仍用 `.28` metadata 保护兜底。该层只改变 MapEditor 文档、UI 和导出语义，不新增水战、渡河、港口补给、移动、战斗、胜负规则或运行时验证结论。

v3.7-preflight.30 已把发布前检查面板升级为静态门禁快照：`ReleaseChecklistView` 会只读当前 `GameState`、本地存档状态和 `GameSaveStatus`，显示剧本、回合阶段、行动势力、胜负状态、地图/地点/军队/前线/方面/防区计数、外交与审计记录、善后记录、战报数量和存档反馈。该层不启动 app、不跑 AI 回合、不执行 Xcode / 模拟器验证、不下载 CI artifact，也不改变规则、命令、存档 schema、地图数据或运行时验证结论。

v3.7-preflight.31 已收口一组玩家可见旧英文兜底：`Faction.displayName` 对 legacy 势力显示为 `德军（旧）` / `盟军（旧）`；`GamePhase.displayName` 去掉 legacy 阶段的“旧剧本”玩家可见标签；`VictoryReason.displayName` 把德军/盟军/巴斯托涅等旧胜负原因改成泛化旧剧本中文兜底；`HexDirection.displayName` 给军队详情提供中文方向；`EconomyRules` 的征发、府库结算、补员和部署事件日志改为中文。该层不改 enum rawValue、存档 schema、规则数值、AI 决策或地图数据，内部类型名和 legacy 数据仍按历史兼容保留。

v3.7-preflight.32 已收口第一批玩家可见调试文案：`AppContainer` 的本地模拟 AI 来源、AI 空转摘要、总管军令提交、州郡选择和归附实体盘点不再显示 `MockAI`、raw directive type、raw zone id、raw region id 或英文 hex；`StrategicStateBootstrapper` 的初始化战报改为中文；`AgentPanelView` 的 Agent/Order/global/diagnostic 兜底、指令类型和无数据 raw JSON 占位改为玩家语义；将领技能 id 在总管军令和将领档案面板显示为中文特性名。该层只改显示文案，不改命令、AI 决策、规则执行、存档字段或地图数据。

v3.7-preflight.33 已继续收口玩家可见外交/朝堂文案：`DiplomacyPanelView` 的势力、盟从、关系、君主和谋主区不再直出 country/bloc/front zone raw id、`Agent` 标签或 agent id；`DiplomacyState` 与 `RulerAgent` 写入的外交摘要、归附交接、善后压力和君主决策 rationale 中文化；州郡要地状态、军队操控状态、前线摘要、地图图层名、地图 accessibility、未知将领技能 fallback 和朝堂决策标题继续改为玩家语义。该层只改显示文案和记录摘要，不改外交关系、命令结构、AI 决策策略、规则执行、存档字段或地图数据。

v3.7-preflight.34 已继续收口玩家可见 AI 诊断文案：`TurnManager` 的 AI 失败、空军令、命令拒绝、太守/使者/归附交接跳过和部署诊断中文化；`CommandValidationError.displayName` 成为统一中文校验错误出口；`RuleEngine`、`AgentDecisionRecord`、`Command.displayName`、legacy Agent D 解析/映射错误和 `AgentPanelView` 展示层不再默认直出英文命令格式、provider suffix、raw agent id、front zone id、region id 或 enum rawValue。该层只改展示文案和可见诊断，不改命令结构、AI 决策策略、规则执行、存档字段或地图数据。

v3.7-preflight.35 已继续收口战报与总管预览文案：`EventLogView` 的战报 metadata 不再直出 `relatedRecordId`，军议意图和战报重点摘要会对 legacy intent、工程词和常见审计 id 做中文或泛化展示；`GeneralCommandPanelView` 的预备军令不再显示 region/front zone raw id 或斜线工程格式。该层只改展示层文案和 formatter，不改日志 schema、命令结构、AI 决策策略、规则执行、存档字段或地图数据。

v3.7-preflight.36 已继续收口战报源头事件文案：`CommandExecutor`、`WarCommandExecutor`、`StrategicStateSynchronizer` 和 `EconomyRules` 写入事件日志的行军、战斗、军令拒绝、州郡控制权、动态方面、前线、府库初始化和生产部署事件改为中文玩家语义，默认不再写入 validation rawValue、region/theater raw id、英文战斗工程词或生产展示名调试编号。该层只改源头事件文案和展示名，不改命令结构、规则执行、战斗/经济数值、日志 schema、存档字段或地图数据。

v3.7-preflight.37 已继续收口 App/UI 边界文案：`AppContainer` 的存档失败、自动回合、命令面板和新局交互日志不再直出系统错误、provider 或 scenario raw id；`ReleaseChecklistView` 的发布检查文案改用玩家语义；`MapDisplayAdapter` 为详情面板提供州郡名、方面名和防区名，并让地图颜色派生保持 tile/hex 优先，`RegionInspectorView` / `UnitInspectorView` 不再显示相关 raw id。该层只改展示文案和只读 UI state，不改存档 schema、内部审计 id、命令结构、规则执行、AI 决策、地图数据或运行时验证结论。

v3.7-preflight.38 已继续抽样收口剩余 UI 文案：`FirstTurnGuideView`、`HUDView`、`AppContainer` 和 `ReleaseChecklistView` 不再显示 AI / Xcode / 发布测试词、调试剧本 fallback、草稿口径或未知 scenario raw id；`ReleaseCandidateMenu` / `ReleaseChecklistView` 的发布候选入口改为战局复核；`AgentPanelView` 不再展开显示 raw JSON，context / command result / error 文案统一净化；`EconomyPanelView`、`EventLogView`、`DiplomacyPanelView`、`RegionInspectorView`、`UnitInspectorView`、`GeneralCommandPanelView` 的摘要文案改用中文标点；`UnitTooltipView` 的 VoiceOver 兵力读法改为“兵力 N，上限 M”，`GeneralProfileView` 不再从 raw 英文 id 生成画像缩写。该层只改展示层字符串和辅助读法，不改存档 schema、内部审计 id、命令结构、规则执行、AI 决策、地图数据或运行时验证结论。

v3.7-preflight.39 已按并发子 agent 复扫结果继续收口 UI 文案：`ReleaseChecklistView` 的发布验收口径改为战局说明、当前可用、待继续观察和局势快照；`AppContainer` 的默认剧本、命令结果、规则校验和规则结算反馈改为当前战局、军令结果和战局判定；`DiplomacyPanelView` 不再直出 `boundaryNote`，旧剧本 fallback 改为历史势力或当前战局角色；战报 metadata、州郡摘要、兵种摘要、单位提示、将领所属军队和地图单位短标继续收口斜线、横线和 `N/M` 显示。该层只改展示层字符串、formatter 和辅助读法，不改存档 schema、内部审计 id、命令结构、规则执行、AI 决策、地图数据或运行时验证结论。

v3.7-preflight.40 已补齐最小本局执掌势力选择：`GameState.playerFaction` 进入运行时状态和本地存档，旧存档缺字段或字段 rawValue 异常时按 scenario / active faction 兼容默认，继续存档会规范到当前局势可选势力；`DataLoader` 从 scenario `playerFaction` 初始化，`wude_618` 冷启动默认唐；基础设置可选择当前局势内可玩的势力，HUD 和战局复核显示执掌势力；通用回合推进按 `state.playerFaction` 判定 `.playerCommand` / `.aiCommand`。该层不重排当前回合顺序，不做完整多势力平衡，不绕过 `Command` / `ZoneDirective -> WarCommandExecutor -> RuleEngine`。

v3.7-preflight.41 已继续收口 MapEditor 可见文案：默认隋唐编辑入口的势力 Picker 改用 `Faction.suitangTurnOrder` 隐藏 legacy 势力选项，州郡/方面/地点/资源/导出/错误反馈改为中文产品语义，路径显示简化，地图单位短标改为中文。该层只改 MapEditor 展示文案、状态反馈、错误说明和短标，不改 JSON schema、rawValue、导出 key、资源文件名、主游戏规则或运行时验证结论。

v3.7-preflight.42 已继续收口默认数据说明与补给战报：`DataLoader` 的 MapEditor 兼容数据加载初始战报改为中文，`wude_618_scenario.json` 与 MapEditor 导出 metadata 的 dataNotes 改为中文，派生补给地点名从 `Supply q,r` 改为 `粮仓 q,r`，`SupplyRules` 的补员、撤退、撤退失败、围困损耗和退却整顿事件改为中文战报。该层只改数据说明、导出说明和事件文案，不改 JSON schema、rawValue、加载顺序、胜负条件、地图数据或规则数值。

v3.7-preflight.43 已继续收口 AI 元帅/方面军令摘要：`ZoneCommanderAgent` 中模拟元帅 rationale、`TheaterDirectiveEnvelope.summary`、`strategicIntent` 字符串、编译后 `theaterContext`、方面军令数量摘要和元帅 fallback 诊断改为中文。该层只改 `MarshalAgent / TheaterDirective -> WarDirectiveRecord / AgentDecisionRecord -> AgentPanelView / EventLogView` 可能消费的可见摘要和审计文案，不改 AI 决策、JSON schema、rawValue、解析合同、命令执行或规则管线。

v3.7-preflight.44 已继续收口 legacy MockAI 与元帅解析诊断：`MockAICommander` 的本地模拟方面军令摘要和默认总管名称中文化，`MockAIClient` 的 legacy intent/reason 中文化，`TheaterDirectiveDecoderError` 改为中文错误说明，`EventLogView` 的诊断净化表补齐 rawJSON、provider、legacy pipeline、directive 等工程词。该层只改旧 Agent D / MockAI 和元帅解析失败路径的可见诊断与审计文案，不改 legacy AI 启发式、stance rawValue、JSON schema、解析合同、命令执行或规则管线。

v3.7-preflight.45 已继续收口 legacy fallback JSON 可见文本：`ardennes_v0_scenario.json` 和 `ardennes_v02_regions.json` 的旧 MapEditor 场景名、dataNotes、城邑/补给点展示名改为中文，`unit_templates.json` 的 legacy 单位模板 displayName 改为中文。该层只改旧 fallback 数据展示字段，不改 JSON key、id、rawValue、加载顺序、默认隋唐入口、MapEditor 导出合同、命令执行或规则管线。

v3.7-preflight.46 已继续收口 legacy 将领档案可见文本：`generals.json` 的旧将领军衔和履历改为中文，`GeneralData.commanderConfig` 优先使用 `localizedName` 作为总管展示名，`GeneralCommandPanelView` 和 `GeneralProfileView` 补齐当前隋唐与 legacy 将领技能 raw id 的中文映射。该层只改展示字段和展示映射，不改 JSON schema、id、技能 rawValue、AI prompt、加载顺序、命令执行或规则管线。

v3.7-preflight.47 已继续收口 Agent 诊断与错误兜底文案：`AgentRole.displayName` 改为中文，`AgentPanelView` 和 `EventLogView` 的诊断净化补齐 legacy 角色、古德里安、schema/model/fallback/directive/diagnostic 等工程词，legacy Agent D 映射失败、解析失败和数据加载校验失败的常见错误描述改为中文。该层只改展示层和错误包装，不改 prompt、JSON schema、rawValue、record id、AI 决策、命令执行或规则管线。

v3.7-preflight.48 已继续收口自动回合与元帅诊断兜底文案：`MarshalAgentConfig.automatic` 的 legacy 元帅展示名和旧剧本/隋唐势力 personality 改为中文，`MarshalAgent.run` 的元帅解析或编译失败诊断改用中文原因兜底，`TurnManager` 的 legacy 映射失败路径和诊断净化补齐元帅、行军总管、君主、schema/provider/fallback/directive/diagnostic/breakthrough 等工程词替换。该层只改展示配置和错误包装，不改 prompt、JSON schema、rawValue、record id、AI 决策、命令执行或规则管线。

v3.7-preflight.49 已继续收口数据加载与导出说明可见文案：`DataLoader` 的 MapEditor 兼容数据加载初始战报改用剧本展示名，`MapEditorExporter` 导出的州郡数据集标题改为中文，`wude_618_scenario.json` 和 `ardennes_v0_scenario.json` 的 dataNotes 去掉 `component rawValue`、版本工程口径和 `hex` 英文词。该层只改可见日志、导出标题和说明文案，不改 JSON schema、id、rawValue、资源文件名、加载顺序、胜负条件、地图数据、规则数值或命令管线。

v3.7-preflight.50 已继续收口复核面板与记录摘要可见文案：战局复核面板、MapEditor 资源面板、战报面板、朝堂面板和外交面板减少“已接入、结构化、只读、审计、诊断、保底、导出到内存、资源目录、真实模型”等工程口径；历史外交/善后/朝堂摘要展示前会做可见文本净化。该层只改展示字符串和展示净化，不改内部 id、schema、rawValue、资源文件名、导出结构、AI 决策、命令执行或规则管线。

v3.7-preflight.51 已继续收口 MapEditor 与主游戏 raw id 可见文案：MapEditor 底图、信息、地点、状态和导出错误不再直出 raw 坐标、文件名、目录名、raw objective id 或“内存”工程词，州郡/方面缺省名不再回落到 raw id；主游戏选择日志、州郡详情和军队详情不再直出 q/r 坐标，方面/行军防区展示名遇到 raw id 时回落为玩家语义，战报、朝堂和外交记录摘要补齐通用 raw id 净化。该层只改展示字符串和展示净化，不改内部 id、schema、rawValue、objectiveId、资源文件名、导出结构、AI 决策、命令执行或规则管线。

v3.7-preflight.52 已继续收口命令错误与源头战报可见文案：命令展示名、州郡命令展示名、RuleEngine 成功消息、命令意图适配错误、元帅军令解码错误、legacy 映射错误、行军/撤退/推进/拒绝/控制权变化战报、总管防区展示和诊断 raw agent id 净化都改为玩家语义，不再直出 raw 坐标、raw id、英文工程词或底层解析详情。该层只改展示字符串和展示净化，不改命令结构、record id、schema、rawValue、AI 决策、规则数值或执行语义。

v3.7-preflight.53 已继续收口总管与将领档案防区展示名：`MockAICommander` 和 `TheaterCommanderPool` 的自动总管配置展示名不再拼接 `zone.id.rawValue`，`GeneralProfileView` 的“所属防区”不再直接显示 `zone.name`，遇到 raw 防区名时回落为玩家语义。该层只改展示名 fallback，不改内部 id、assigned zone、front zone schema、AI 决策、命令结构、规则数值或执行语义。

v3.7-preflight.54 已继续收口 legacy fallback 数据展示文案：`ardennes_v0_scenario.json` 的场景展示名、dataNotes、keyLocations 和 tile `cityName` 去掉草稿名与坐标式命名，`ardennes_v02_regions.json` 的数据集名、region name 和 city name 去掉“旧剧本/新省份/城邑坐标”口径，`generals.json` 的 legacy 将领履历去掉“旧剧本总管/装甲总管/集团军总管”并修正博克展示名。该层只改 JSON 展示字段，不改 id、rawValue、coord、faction、templateId、objective kind、schema、加载顺序、规则或命令管线。

v3.7-preflight.55 已继续收口 legacy fallback 单位与防区展示文案：`ardennes_v0_scenario.json` 的初始单位名按阵营和兵种改为中文展示，legacy 场景展示名和 dataNotes 使用阿登战局口径，`ardennes_v02_regions.json` 的 region / city 名称改为阿登防区语义。该层只改 JSON 展示字段，不改 id、rawValue、coord、faction、templateId、schema、加载顺序、规则或命令管线。

v3.7-preflight.56 已继续收口 legacy static fallback 目标兼容与展示文案：静态 `MapState.ardennesV0()`、`GameState.initial()`、legacy 胜负原因和 MockAI 目标选择使用中文展示名；阿登目标判断优先按 objective id 查找，再兼容中文和英文展示名。该层只改展示文案和 legacy 兼容查找，不改 objective id、胜负阈值、行动策略、存档字段或命令管线。

v3.7-preflight.57 已继续收口 legacy LLM prompt 语言：`AgentPromptBuilder` 的 system/user prompt、JSON 示例值和 `guderianFallback` 展示配置改为中文，并要求 `intent`、`reason`、`stance` 摘要使用中文。该层保留 JSON schema、command type、agent id、rawValue、解析合同、AI 决策结构、规则和命令管线。

v3.7-preflight.58 已收口外交面板势力与盟从列表中的数据层英文名称直出风险：势力和盟从列表统一走展示 helper，未知英文 fallback 回落到势力中文展示名；外交记录摘要净化补齐 intent、reason、source、command、directive、RuleEngine、MockAI、model、Guderian 和常见审计 id。该层只改 `DiplomacyPanelView` 展示 helper 和 formatter，不改外交关系、命令结构、record id、存档 schema、AI 决策或规则执行。

v3.7-preflight.59 已收口战报面板的结构化意图和中文战报分类：`displayedIntent` 会屏蔽 v3.x 版本诊断和复合 snake_case intent，审计 record id 净化前移到统一 sanitizer，常见 raw id 前缀补齐，旧二战专名和工程口径进一步转为玩家语义；`.event` fallback 分类补齐中文撤退、补员、围困、战斗和粮道关键词。该层只改 `EventLogView` 展示 helper 和分类兜底，不改日志 schema、事件来源、record id、AI 决策、命令结构或规则执行。

v3.7-preflight.60 已收口 MapEditor 普通导出 metadata fallback：`MapEditorExportMetadata.inferred(for:)` 只有在文档 id 或展示名明确含 legacy / Ardennes / WWII / 阿登 / 旧战局时才返回 `.legacyArdennes`，未知自定义文档默认使用 `.suitangDraft`，避免普通新地图误导出旧阵营、旧 phase 或旧 dataNotes。该层只改 metadata 推断口径，不改 MapEditor 文档 schema、keyLocations 合并规则、主游戏加载、运行时规则或命令管线。

v3.7-preflight.61 已收口 AI 诊断净化口径：`TurnManager.userFacingDiagnostic` 和 `AgentPanelView` 将 `model`、`legacy pipeline`、`RuleEngine`、`Guderian` 等内部词与战报面板统一为军议来源、备用军议路径、军令校验和历史总管，并补齐常见审计 id 正则净化。该层只改源头诊断与 AI 面板展示 helper，不改记录 schema、AI 决策、prompt、命令结构、规则执行或运行时状态。

v3.7-preflight.62 已收口 legacy 总管配置中文兜底：`general_agents.json` 中 `guderian` 的展示名和 personality prompt 改为中文，`GameAgent(definition:)` 对旧 bundle 或旧数据继续提供“古德里安”和中文作战偏好的窄口径兜底，`breakthrough` 仅在 traits 展示层映射为“突破”。该层不改 JSON schema、id、rawValue、command style、辖下单位 id、命令解析合同、AI 决策、规则执行或运行时状态。

v3.7-preflight.63 已收口 legacy prompt 内部编号分层：`AgentPromptBuilder` 的战场摘要改为中文名称优先，解析必须使用的 `divisionId`、`targetDivisionId`、`toRegionId` 单独列入内部编号小节，schema 示例占位改为中文说明，同时保留 `type` 的 `move`、`attack`、`hold`、`resupply` rawValue 合同。该层只改 legacy LocalLLM prompt 文案结构，不改解析合同、命令结构、AI 决策、规则执行或运行时状态。

v3.7-preflight.64 已收口 legacy prompt 直通文本净化：`AgentPromptBuilder` 会先净化近期战报和玩家意图再拼入 legacy LocalLLM prompt，自由文本区覆盖常见审计 id、raw 地块/州郡/方面/军队/命令 id 和 `RuleEngine`、`MockAI`、`local-model`、`rawJSON` 等工程词；内部编号表和 JSON schema 不参与净化。该层只改 legacy prompt 自由文本入口，不改展示 sanitizer、解析合同、命令结构、AI 决策、规则执行或运行时状态。

v3.7-preflight.65 已收口 legacy prompt 决策者身份净化：`AgentPromptBuilder.systemPrompt` 的“决策者”不再直出 raw `context.agentId`，`guderian` 显示为“古德里安”，其他内部 id 泛化为“本地军议决策者”；“性格”改走 prompt-local 净化，`GameAgent.sample` 默认 personality 也改为中文。该层保留 JSON schema 中的 raw `agentId` 以满足 parser 校验，不改解析合同、命令结构、AI 决策、规则执行或运行时状态。

v3.7-preflight.66 已收口 legacy MockAI stance 文案：`MockAIClient` 生成的 `AgentOrder.stance` 从英文标签改为中文短语，覆盖整补、火力支援、突破、推进、固守、前线行动、纵深驰援、驻防和战役预备等姿态。该层只改 `stance` 自由文本，不改 `AgentOrderType`、内部 id、目标选择、决策排序、规则执行或运行时状态。

v3.7-preflight.67 已收口 legacy prompt 工程说明词：`AgentPromptBuilder` 面向 LocalLLM 的系统提示和格式说明把 `hex`、`schema`、`Markdown`、`JSON schema` 等工程说明转为六角格、结构化输出、排版标记和结构化军令口径。该层保留 `responseFormat: "json_object"`、JSON 字段名、schema version、agent id、turn、内部编号、`move`、`attack`、`hold`、`resupply` 和 parser / mapper 合同，不改 AI 决策、规则执行或运行时状态。

v3.7-preflight.68 已收口模拟元帅输出格式：`SimulatedMarshalLLMClient` 编码 `TheaterDirectiveEnvelope` 后直接返回纯 JSON 字符串，不再主动包裹 Markdown 代码围栏；`TheaterDirectiveDecoder` 仍兼容 fenced JSON 和纯 JSON。该层只改内置模拟客户端输出包装，不改 `TheaterDirectiveEnvelope` / `TheaterDirective` schema、decoder 校验、元帅策略、fallback、命令编译、规则执行或运行时状态。

v3.7-preflight.69 已收口 UI/战报/外交记录净化 helper：`AgentPanelView`、`EventLogView` 和 `DiplomacyPanelView` 均先清理 raw id，再替换工程词、模型词和记录词；三处词表补齐 `AI`、`LLM`、模型品牌词、`rawJson`、`raw JSON`、`Provider`、`Schema`、`record`、`Legacy Pipeline` 和裸 `pipeline` 等展示兜底。该层只改展示 helper，不改 UI 布局、记录 schema、日志来源、AI 决策、命令结构、规则执行或运行时状态。

v3.7-preflight.70 已收口 legacy 将领与朝堂记录可见文案：legacy `guderian` 配置和 fallback prompt 去掉“装甲突破 / 装甲部队”展示口径，`armor_expert` / `armor_theory` 显示为“突击战法”，朝堂使者 rationale 去掉“AI 自动回合”，结构化军令记录标题去掉 `JSON` 字样，外交记录净化词表补齐旧军语和 legacy 将领名。该层只改自由文本和展示 helper，不改内部 id、rawValue、`rawJSON` 字段、记录 schema、AI 决策、命令结构、规则执行或运行时状态。

v3.7-preflight.71 已收口 CommandPanel 命令消息展示净化：`CommandPanelView` 显示 `lastCommandMessage` 前先清理常见 raw id，再替换 `Command`、`RuleEngine`、`JSON`、`schema`、`pipeline`、`AI/LLM`、模型品牌词和 hex 工程词。该层只改命令面板展示 helper，不改 `AppContainer.lastCommandMessage` 存储、交互日志、`Command` case、`CommandResult` schema、校验逻辑、AI 决策、命令结构、规则执行或运行时状态。

v3.7-preflight.72 已收口单位详情与提示 legacy 单位名展示：`UnitInspectorView` 和 `UnitTooltipView` 显示单位名前先做局部展示净化，把旧 fallback 的“德军 / 盟军 / 装甲 / 摩托化 / 炮兵 / 步兵 / 师”和常见单位 raw id 转为发布前置口径；tooltip 的 VoiceOver label 同步使用同一展示名。该层只改两个单位面板的展示 helper，不改 `Division.name` 存储、JSON、templateId、rawValue、存档 schema、兵种显示权威、AI 决策、命令结构、规则执行或运行时状态。

v3.7-preflight.73 已收口州郡详情 legacy 地名与目标名展示：`RegionInspectorView` 的州郡名、城邑名、方面名、防区名、要地名和驻军列表显示前先做局部展示净化，清理常见地名 / 目标 raw id 与 legacy 地名。该层只改州郡详情展示 helper，不改 region / hex / objective / division 存储、JSON、id、rawValue、objectiveId、keyLocations、胜负规则、地图数据、AI 决策、命令结构、规则执行或运行时状态。

v3.7-preflight.74 已收口将领与总管面板 legacy 文案：`GeneralProfileView` 和 `GeneralCommandPanelView` 的将领名、军衔、履历、防区名、所属军队、目标州郡和 accessibility 文案显示前先做局部展示净化，清理常见将领 / 防区 / 州郡 / 军队 raw id 与 legacy 将领、旧地名、旧兵种词。该层只改两个面板的展示 helper，不改 `GeneralData`、`GeneralAssignment`、`FrontZone`、`Division.name`、`PlayerPlannedOperation`、JSON、rawValue、存档、AI 决策、命令结构、规则执行或运行时状态。

v3.7-preflight.75 已收口 MapDisplayAdapter / SpriteKit 地图展示入口 legacy 文案：`MapDisplayAdapter` 在 `HexDisplayState.cityName` / `fortressName` 和 `RegionInspectorState.objectiveNames` 进入地图标签或详情面板前做局部展示净化；`RegionInspectorView` / `UnitInspectorView` 对既有 region / theater / front zone id 与 legacy faction display 做局部兜底，避免为展示名扩展 inspector state 合同。该层只改展示值，不改 `HexDisplayState`、`RegionInspectorState`、`UnitInspectorStrategicState` 字段结构、地图 JSON、objective id、keyLocations、`RegionNode` / `HexTile` / `Objective` 存储、动态方面 / 防区权威、AI 决策、命令结构、规则执行或运行时状态。

v3.7-preflight.76 已收口 MapEditor 选择器与状态消息 legacy 文案：`MapEditorView` 的“当前州郡”“当前方面”下拉项显示前先走 `MapEditorViewModel.displayName(for:)`，创建州郡、创建方面、保存地点、删除地点状态消息中的名称也先做局部展示净化。该层只改 MapEditor 可见展示值，不改 `MapEditorDocument`、导出 JSON、id / rawValue、默认资源桥、MapEditor 存储 schema、主游戏数据加载、地图规则、AI、命令或运行时状态。

v3.7-preflight.77 已收口 AppContainer 交互日志与存档反馈 legacy 文案：`AppContainer` 的存档载入、继续、自动保存、新局、切换执掌势力、军队点击、州郡经营拒绝、地图选择、总管防区提交和 fallback 总管名称显示前先走局部展示 helper；外交 / 归附命令标题在 AppContainer 展示层净化，不改 `Command.displayName` 合同。该层只改可见展示值，不改 `GameState`、存档 schema、`GameLogEntry`、`Command`、`Division.name`、`RegionNode.name`、`FrontZone.name`、JSON、id / rawValue、AI 决策、命令结构或规则执行。

v3.7-preflight.78 已收口 GameLogEntry 源头战报 legacy 文案：`GameLogEntry.init(...)` 会在保存 `message` 前净化常见审计 id、raw id、legacy 势力名、旧地名和旧题材单位词，覆盖 Rules / Commands / Data / Core 等 `appendEvent` 与直接 `GameLogEntry(...)` 构造路径。该层只改玩家可见日志消息，不改 `GameState.eventLog` 字段结构、`GameLogEntry` schema、`relatedRecordId` 合同、规则数值、命令执行、数据层名称、JSON、AI 决策或存档格式。

v3.7-preflight.79 已收口 legacy LocalLLM prompt 临时编号别名：`AgentPromptBuilder` 会在 prompt 中净化势力、目标、军队、州郡和编号旁说明名，并用“军队一 / 敌军一 / 州郡一 / 本地决策者”等临时编号替代真实 id；`LocalLLMDecisionProvider` 解析后用同一本别名表回填真实 id。该层只改旧 LocalLLM prompt 与解析后适配，不改 `AgentDecisionEnvelope` / `AgentOrder` schema、JSON 字段名、type rawValue、parser / mapper、命令结构、默认战争 AI 主链路、规则或存档格式。

v3.7-preflight.80 已收口 legacy fallback 行军总管配置：`GameAgent.guderian(from:)` 和 `guderianFallback` 不再把旧 Guderian / Germany / `ger_*` 默认单位作为可见 fallback 指挥官配置；`MarshalAgentConfig.automatic` 的 legacy `.germany` / `.allies` 分支改为中性“旧剧本势力行军总管”；模拟军议 directive id 前缀从 `marshal_` 改为 `command_`。该层只改 fallback 配置和可见诊断口径，不改 marshal / directive schema、Faction enum、JSON 数据、命令管线、规则或存档格式。

v3.7-preflight.81 已收口朝堂/外交实际记录 id 展示净化：`TurnManager` 在 `courtRecord.summary` 进入 parsedIntent、战报事件和朝堂步骤展示文本前先做展示净化；`AgentPanelView`、`DiplomacyPanelView`、`EventLogView`、`CommandPanelView`、`GameLogEntry` 和 `AgentPromptBuilder` 补齐真实 `ruler_*_turn_*`、`court_*_turn_*`、`court_<turn>_*`、`diplomacy_<turn>_*` 记录 id 的展示净化；`DiplomacyState.summary(for:)` 把“敌对关系 N 条”修正为“敌对国家 N 个”。该层只改展示文案和 prompt 输入净化，不改记录 id、Codable schema、`relatedRecordId`、外交判定、命令管线、规则或存档。

v3.7-preflight.82 已收口行军总管可见称谓净化：`AgentPanelView` 的 `MarshalDirective` 来源显示从“元帅军议”改为“军议”，`AgentPanelView`、`EventLogView`、`DiplomacyPanelView` 的 `Field Marshal` 展示净化统一为“行军总管”，`DiplomacyPanelView` 的裸 `Guderian` 改为“历史总管”，`CommandPanelView` / `EventLogView` 补齐 `directive_*command_*`、`order_*` 和朝堂 agent 前缀记录净化，`AgentRole.fieldMarshal.displayName` 改为“行军总管”。该层只改展示文案和展示净化，不改 rawValue、provider suffix、record id、schema、命令管线、规则或存档。

v3.7-preflight.83 已收口源头 legacy 中文势力/国家/地名展示净化：`TurnManager` 的自动回合失败、方面军令诊断和错误兜底补齐旧中文势力、旧国家、旧地名、旧单位词和英文势力词净化；`DiplomacyState` 外交事件、归附交接、善后压力和善后处置摘要改走展示 helper；`GameLogEntry` 源头战报补齐英文角色、势力和工程词净化。该层只改源头展示文本与净化词表，不改数据、rawValue、record id、Codable schema、命令管线、规则或存档。

v3.7-preflight.84 已收口将领档案/总管军令称谓净化对齐：`GeneralProfileView` 与 `GeneralCommandPanelView` 的 `Field Marshal` 展示统一为“行军总管”，`Guderian / 古德里安` 展示统一为“历史总管”，空单位名 fallback 先净化 legacy 势力显示。该层只改将领相关面板展示净化，不改 `GeneralData`、`Division.name`、`AgentRole` rawValue、JSON、命令管线、规则或存档。

v3.7-preflight.85 已收口 fallback JSON 可见数据文本：`ardennes_v0_scenario.json` 的场景名、dataNotes、初始单位名、地点名、粮站名和 map `cityName` 改为中性旧战局口径；`ardennes_v02_regions.json` 的数据集名、region 名和 city 名补齐中性展示；`unit_templates.json` 与 `generals.json` 的 legacy 模板展示名、将领可见名、军衔和履历改为迁移期中性称谓。该层只改 fallback JSON 可见字段，不改 JSON key、id、rawValue、schema、坐标、faction、templateId、加载顺序、命令管线、规则或存档。

v3.7-preflight.86 已收口源码层 legacy 可见兜底文本：`Faction.displayName` 的旧势力展示改为“旧剧本东路势力 / 旧剧本西路势力”；`VictoryReason.displayName` 的 legacy 胜负原因改为中性旧战局目标、主力和断粮口径；`DataLoader` 的旧战局补给源和代理配置校验错误改为中性描述。该层只改展示文案和错误描述，不改 enum rawValue、JSON schema、id、兼容查找、胜负判定、加载顺序、命令管线、规则或存档。

v3.7-preflight.87 已收口静态 fallback 源码可见文本：`GameState.initial()` 的最后兜底单位名和初始化战报改为中性旧战局口径；`MapState.ardennesV0()` 的最后兜底城邑、要塞和 objective 展示名改为中性旧战局口径。该层只改静态 fallback 展示名和战报文本，不改 scenario id、objective id、faction、坐标、地形、补给源、胜负规则、加载顺序、命令管线或存档字段。

v3.7-preflight.88 已收口 legacy objective lookup 字面量：`VictoryRules`、`RegionVictoryRules` 和 `MockAIClient` 的旧 fallback 目标查找改为 legacy objective id 优先，并只 fallback 到中性旧战局目标名；私有函数、注释和本轮触及局部变量去旧战役地名口径。该层不改 objective id、胜负阈值、AI 行动策略、`VictoryState` 存档字段、`VictoryReason` case、命令管线或存档格式。

v3.7-preflight.89 已对齐 `RegionVictoryRules` 的隋唐胜负摘要：`RegionRuleSystem.analyze(_:)` 使用的 region 层胜负评估现在按 `scenarioId` 分支，默认 `wude_618_guanzhong_luoyang` 读取洛阳、洛口仓、潼关和长安 objective id；legacy fallback 摘要仍保留旧 objective id 与中性目标名兼容。该层不改主 `VictoryRules.updateVictoryState(in:)` 执行路径、`GameState.victoryState`、胜负阈值、命令管线或存档格式。

v3.7-preflight.90 已抽出共享隋唐胜负 evaluator：`VictoryAssessment` 表达只读评估结果，规则层 `Wude618VictoryEvaluator` 集中维护默认隋唐剧本胜负判断，`VictoryRules` 与 `RegionVictoryRules` 均复用该 evaluator。该层不新增文件，不改 Xcode project，不改 objective id、地图数据、胜负阈值、命令管线、AI 决策或存档格式。

v3.7-preflight.91 已收口指令结果语义化固守判定：`CommandResultSummary` 新增可选 `commandKind` 记录命令语义，`ZoneCommanderAgent.hasRecentStaticDefense` 改为按 `.hold` 语义判断上一轮是否静态防御，不再依赖旧英文 `Hold` 或中文展示名。该层不改 `Command` case、directive schema、AI tactic 阈值、规则执行或 Xcode project。

v3.7-preflight.92 已收口阶段与旧总管展示口径：`GamePhase.displayName` 的自动行动阶段显示为“朝堂行动 / 朝堂军令”，`general_agents.json` 中 legacy `guderian` 配置展示名改为“历史总管”。该层不改 `GamePhase` rawValue、Codable、回合推进、自动行动判定、legacy id、势力 rawValue、单位 id、command style、AI 决策、命令管线、规则或存档。

v3.7-preflight.93 已收口自动总管默认指挥风格：`ZoneCommanderAgent.defaultConfig(for:)` 不再用 `.germany` 二元判断决定自动方面总管风格，而是按多势力映射与 `AppContainer` 默认配置口径对齐。该层不改 directive schema、命令管线、规则执行、AI 阈值、战术选择函数、势力 rawValue 或存档格式；重复映射维护风险已在 v3.7-preflight.94 通过共享 helper 收口。

v3.7-preflight.94 已收口默认指挥风格共享 helper：`ZoneCommanderAgentConfig.CommandStyle.defaultForFaction(_:)` 统一维护自动方面总管默认风格映射，`TheaterCommanderPool.defaultConfig(for:)` 与 `AppContainer.buildCommanderPool(state:registry:)` 均调用该 helper，不再各自维护重复 switch。该层不改 `CommandStyle` case、rawValue、Codable、`.cautious` case、AI 阈值、directive schema、命令管线、规则执行、势力 rawValue 或存档格式。

v3.7-preflight.95 已收口 `DataLoader` 场景阶段兜底：`loadGameState(scenario:regionData:)` 先解析一次 scenario-aware initial phase，再派生 active faction、`GameState.phase` 和初始日志 phase；无效 phase 时 legacy 阿登 fallback `.alliedPlayer`，隋唐或未知自定义场景 fallback `.playerCommand`；无效 player faction 时 legacy 阿登 fallback `.allies`，隋唐或未知自定义场景 fallback `.tang`。该层不改合法 JSON、`GamePhase` case/rawValue、旧阿登显式阶段、命令管线、规则执行、AI 决策或存档 schema。

v3.7-preflight.96 已收口 legacy phase 存档规范化：`GamePhase` 集中提供按 active faction / player faction 规范化旧阶段的 helper，`GameState` 解码、`AppContainer` 启动与切换执掌势力、`CommandValidator`、`CommandExecutor` 和 `TurnManager` 复用同一 phase 判断；合法 legacy 阿登 `.germanAI` / `.alliedPlayer` 仍保留原双势力推进，自定义或隋唐脏 phase 会落到通用 `.playerCommand` / `.aiCommand`。该层不改 `GamePhase` rawValue、Codable、命令 schema、规则数值、AI 决策或存档字段。

v3.7-preflight.97 已收口动态方面推进势力兜底：`WarCommandExecutor.applyStrategicAdvance` 不再在异常缺少 advancing zone faction 时把 `TheaterSystem.expandDynamicTheater` 的推进势力静默落到 `.germany`。推进势力优先取 `frontZones[advancingZoneId].faction`，异常缺 zone 时回退实际行动军队；两者都缺失时跳过本次动态方面推进并记录原因。该层不改 hex 占领、`hexToTheater` / `hexToFrontZone` 权威、同步器主逻辑、命令 schema、规则数值、AI 决策或存档字段。

v3.7-preflight.98 已收口 RegionDataSet owner/controller 兜底：`RegionDataSet.toRegions()` 对非 legacy 数据缺 owner 抛出数据校验错误，controller 仍按既有语义缺省回退 owner；只有明确旧战局 RegionDataSet 才保留 `.allies` 兼容 fallback。该层不新增 neutral，不改 JSON schema，不改变 hex / region / theater / front / deploy 权威边界。

v3.7-preflight.99 已收口场景语义和胜负 fallback 门禁：`ScenarioSemantics` 集中判断明确旧战局、明确 `wude_618`、隋唐草稿和未知自定义场景；`DataLoader`、`GameState`、`AgentConfiguration` 和 `AppContainer` 复用该 helper 推断默认 phase、玩家势力、AI 势力、自动总管势力和可选势力。`VictoryRules` / `RegionVictoryRules` 只有明确旧战局才走 legacy Bastogne / St Vith fallback，隋唐草稿和未知自定义场景保持未决。该层不改 JSON schema、objective id、胜负阈值、AI 决策、命令管线或动态权威。

v3.7-preflight.100 已收口 MapEditor 非法 unit faction 导入 fallback：`MapEditorGameResourceBridge.makeDocument` 导入默认游戏资源时不再把无法识别的 `unit.faction` 静默落到旧 `.allies`，而是跳过该坏 unit 并生成 `MapEditorGameResourceImportDiagnostic`；`MapEditorViewModel.loadDefaultGameResources()` 会把跳过数量和原因写入状态消息。该层不改主游戏 `DataLoader`、`Faction` enum、JSON schema、MapEditor 导出 schema、命令管线、规则执行或动态权威。

v3.7-preflight.101 已让归附善后压力从复盘记录落到州郡治安/顺从状态：`CommandExecutor.executeSubmissionHandoff` 生成 `SubmissionAftermathRecord` 后，会按风险等级调整受影响州郡的 `OccupationState.resistance` / `compliance`，并追加外交战报提示治安承压。该层复用既有州郡经营“安民”来抵消压力，不新增命令、存档字段、忠诚、叛乱、贡赋、俘虏、安置模型或额外归属转移。

v3.7-preflight.102 已把归附善后压力接入贡赋效率：`EconomyRules.income(for:map:)` 聚合受控州郡丁口、军械、粮草收入时，会按 `RegionNode.occupationState` 折算贡赋效率。高抵抗会压低收入，顺从提高会恢复效率但不超过基础产出；因此 v3.7-preflight.101 的善后压力会影响后续府库收入，既有“安民”治理会自然恢复贡赋效率。该层不新增命令、存档字段、忠诚、叛乱、俘虏、安置模型或额外归属转移。

v3.7-preflight.103 已把渡口/港口地点接入粮道补给：`SupplyRules.supplyPathCost(from:to:for:in:)` 跨 `riverEdges` 计算补给路径成本时，若跨河两端任一 hex 有 `MapFeatureKind.ferry` / `port` / `harbor`，该段补给渡河额外成本免除；普通跨河补给仍保留原本额外成本。该层不改移动、战斗、水师、水战、港口补给源、JSON schema、命令管线或存档字段。

仍未完成的迁移边界：README / AGENTS 项目身份仍按真实工程历史保留，完整天命/民心、水战、siege progress、真实多模型协作、归附交接后的完整忠诚/叛乱/俘虏/安置实际效果、正式地图资产替换决策、完整 UI 文案穷尽审计和完整发布候选运行时重测流程尚未迁移。

迁移期间必须继续守住本文既有权威边界：hex 是战术权威，动态 theater/front/deploy 从 hex 与单位位置派生，玩家和 AI 行动仍统一进入 `Command` / `ZoneDirective -> WarCommandExecutor -> RuleEngine`。

---

## 1. 核心状态对象

### 1.1 GameState

源码：`WWIIHexV0/Core/GameState.swift`

`GameState` 是运行时总状态，主要字段：

```text
scenarioId
turn / maxTurns
activeFaction
playerFaction
phase
map: MapState
theaterState: TheaterState
frontLineState: FrontLineState
warDeploymentState: WarDeploymentState
economyState: EconomyState
diplomacyState: DiplomacyState
divisions: [Division]
victoryState
eventLog
warDirectiveRecords
playerCommandState
```

状态含义：

- `map` 保存地图、hex、region、补给源和目标点。
- `playerFaction` 保存本局玩家执掌势力，v3.7-preflight.40 起进入本地存档；旧存档缺字段或字段值异常时按剧本默认唐或 legacy 人控势力回落。
- `divisions` 保存所有单位。单位当前位置在 `Division.coord`，不是 region 或 theater。
- `theaterState` 保存初始战区快照与运行时动态战区。
- `frontLineState` 从动态战区相邻 hex 派生。
- `warDeploymentState` 从动态战区/前线/单位位置派生，供 AI 调度单位。
- `economyState` 保存 manpower、industry、supplies、生产队列、上回合收入/维护费/补员消耗，不直接改变战术占领权。
- `diplomacyState` 保存 faction 到 country / bloc / relation 的映射。v3.1 起，攻击、ZOC、补给通行、region 压力、AI 摘要等敌对判断应优先使用 `DiplomacyState.isHostile` / `canAttack`。
- v3.7-preflight.9 起，玩家侧议和/纳降用 `Command.updateDiplomacy` 更新 `DiplomacyState.relations`；该命令仍经 `CommandValidator` 和 `RuleEngine`，不会直接改战术占领或单位归属。
- v3.7-preflight.10 起，玩家侧修道/屯田/安民用 `Command.governRegion` 更新州郡战略字段和府库；该命令仍经 `CommandValidator` 和 `RuleEngine`，不会直接改 hex 占领、单位位置、动态方面或部署归属。
- v3.7-preflight.11 起，AI/观战自动回合的太守层可在 `endTurn` 前最多提交一条 `Command.governRegion`；该命令仍经 `CommandValidator` 和 `RuleEngine`，不会直接改 hex 占领、单位位置、动态方面或部署归属。
- v3.7-preflight.12 起，AI/观战自动回合的使者层可在 `endTurn` 前最多提交一条 `Command.updateDiplomacy`；该命令仍经 `CommandValidator` 和 `RuleEngine`，不会直接改 hex 占领、region、军队、动态方面或部署归属。
- v3.7-preflight.13 起，外交关系变化会追加 `DiplomacyEventRecord` 并关联 `.diplomacy` 战报；归附记录仍只是事件审计，不会直接改 hex 占领、region、军队、动态方面或部署归属。
- v3.7-preflight.14 起，已归附且无存活军队、无可通行受控 hex 的势力会退出通用隋唐回合轮转；该收口只改变 turn order，不直接改 hex 占领、region、军队、动态方面或部署归属。
- v3.7-preflight.15 起，归附目标判定统一由 `DiplomacyState` helper 提供；外交面板会只读盘点归附目标的存活军队和受控可通行 hex，说明其是否仍进入回合轮转，不直接执行归属交接。
- v3.7-preflight.16 起，归附接收方可通过 `Command.resolveSubmissionHandoff` 接管归附目标未毁灭军队和可通行受控 hex；执行后仍由同步器和 bootstrapper 刷新 region、动态方面、前线与部署。
- v3.7-preflight.17 起，归附交接完成后会追加 `SubmissionHandoffRecord` 并关联外交战报；外交面板只读展示最近交接记录和边界说明。
- v3.7-preflight.18 起，AI 接收方会在 AI 回合最多提交一条 `Command.resolveSubmissionHandoff`，仍经 `RuleEngine` 执行并进入 AI command results。
- v3.7-preflight.19 起，归附交接成功后会追加 `SubmissionAftermathRecord` 善后压力记录，并关联外交日志供外交面板复盘；v3.7-preflight.101 起，该压力会按风险等级写入受影响州郡 `OccupationState`；v3.7-preflight.102 起，`OccupationState` 会影响后续府库收入贡赋效率。
- v3.7-preflight.20 起，AI 太守会在后续 AI 回合优先考虑最新高/需安抚善后压力记录的受影响州郡，仍只提交既有 `Command.governRegion`。
- v3.7-preflight.21 起，既有州郡经营命令治理最新善后州郡后会追加 `SubmissionAftermathGovernanceRecord` 处置审计记录。
- v3.7-preflight.22 起，外交面板会按最新善后记录显示已处置州郡数量和总受影响州郡数量。
- v3.7-preflight.23 起，AI 太守会优先治理最新善后记录中尚未产生处置记录的受影响州郡。
- v3.7-preflight.24 起，外交面板会显示最新善后的待处置数量和完成状态，AI 太守在本次善后全部处置后不再特殊优先该记录。
- v3.7-preflight.25 起，发布前检查面板会区分代码已接入、运行时未验证和后续功能，避免把候选接入状态误写成发布通过。
- v3.7-preflight.26 起，AI 太守在有朝堂太守步骤或未完成善后上下文但没有生成经营命令时，会写入确定性跳过诊断。
- v3.7-preflight.27 起，AI 使者在有朝堂使者步骤但没有生成外交命令时会写入确定性跳过诊断；存在已归附目标但没有生成交接命令时，也会写入接收方或残余实体诊断。
- v3.7-preflight.28 起，MapEditor 默认读取和覆盖保存 `wude_618` 隋唐资源，覆盖默认资源时保留既有场景元数据和水路地点记录。
- v3.7-preflight.29 起，MapEditor 文档显式保存 `keyLocations`，右键信息面板可编辑地点名称、类型、势力和 objectiveId，导出时以文档地点字段优先。
- v3.7-preflight.103 起，渡口、港口、海港地点可免除相邻跨河粮道的补给渡河额外成本，仍不改变移动或战斗。
- v3.7-preflight.100 起，默认资源桥导入 `scenario.initialUnits` 时，非法 unit faction 会被跳过并写入导入诊断，不再静默落到旧 `.allies`。
- v3.7-preflight.101 起，归附交接后的善后风险会实际提高受影响州郡治安压力并降低顺从，仍不触发完整忠诚、叛乱、俘虏或安置系统。
- v3.7-preflight.102 起，治安/顺从会折算受控州郡贡赋效率，高抵抗降低丁口、军械、粮草收入，安民后随顺从恢复。
- v3.7-preflight.30 起，发布前检查面板显示当前 `GameState` 静态门禁快照，但仍不等同于运行时验证或 CI artifact 验收。
- v3.7-preflight.31 起，legacy 势力名、旧阶段/胜负原因、军队方向和经济事件日志的玩家可见兜底已中文化。
- v3.7-preflight.32 起，App/AI 记录、bootstrap 战报、朝堂面板和将领技能显示中的第一批玩家可见调试文案已中文化或隐藏无数据占位。
- v3.7-preflight.33 起，外交面板、朝堂决策摘要、州郡/军队详情和基础可访问性入口中的一批 raw id、英文 fallback 与工程术语已收口为玩家语义。
- v3.7-preflight.34 起，AI 决策面板、方面军令诊断、命令结果摘要和 legacy Agent D 失败路径中的一批英文诊断、工程术语、provider suffix、raw agent id / front zone id / region id 和校验 rawValue 已收口为玩家语义。
- v3.7-preflight.35 起，战报 metadata、战报重点摘要和总管预备军令预览中的一批 raw record id、region/front zone id 和斜线工程格式已收口为玩家语义。
- v3.7-preflight.40 起，`playerFaction` 是当前玩家执掌势力权威；通用回合阶段推进由 `CommandExecutor` 对比 `state.activeFaction` 和 `state.playerFaction`，基础设置切换只改变本局执掌判定和必要 phase，不直接执行战术命令。
- v3.7-preflight.87 起，`GameState.initial()` 最后 fallback 的静态单位名和初始化战报只保留中性旧战局展示口径；scenario id、unit id、faction、坐标、加载顺序、规则和存档字段不变。
- `eventLog` 给 UI 和调试看。
- `warDirectiveRecords` 记录战争指令执行回放，供 v0.36+ 后续接 LLM / 聊天命令审计。

v3.1 后 `Faction` 同时包含 legacy 二战势力和隋唐势力。legacy `germany/allies`、`germanAI/alliedPlayer` 仍用于旧阿登路径；隋唐新路径应使用 `playerCommand/aiCommand` 和 `DiplomacyState` 关系判断。`Faction.opponent` 只保留为兼容旧代码的 convenience，不再作为新主逻辑入口。

### 1.2 MapState / Hex

源码：`WWIIHexV0/Core/MapState.swift`、`WWIIHexV0/Core/Terrain.swift`

`MapState` 的底层是 hex：

```text
width / height
tiles: [HexCoord: HexTile]
supplySources: [SupplySource]
objectives: [Objective]
regions: [RegionId: RegionNode]
hexToRegion: [HexCoord: RegionId]
regionEdges: Set<RegionEdge>
```

`HexTile` 关键字段：

```text
coord
baseTerrain
hasRoad
riverEdges
controller: Faction?
cityName / fortressName
isPassable
regionId: RegionId?
```

当前语义：

- v3.7-preflight.87 起，`MapState.ardennesV0()` 最后 fallback 的静态城邑、要塞和 objective 展示名只保留中性旧战局口径；objective id、坐标、faction、地形、补给源、胜负规则和存档字段不变。

- `HexCoord` 是 axial q/r 坐标，移动、攻击、距离、邻接都基于 hex。
- `HexTile.controller` 是真实占领权威；中立 hex 的 controller 为 `nil`。
- `HexTile.regionId` 是聚合标记，不参与寻路/战斗权威判断。
- `MapState.region(for:)` 优先读 `hexToRegion`，fallback 读 `tile.regionId`。
- `MapState.supplySources(for:)` 会通过 `controllingFaction(for:)` 判断补给源当前归属，优先看 supply hex 的 controller，再 fallback region controller，再 fallback 原始 supply faction。

### 1.3 Region

源码：`WWIIHexV0/Core/Region.swift`

`RegionNode` 是省份/区块规则层：

```text
id / name
owner
controller
terrain
neighbors
displayHexes
representativeHex
city
infrastructure / supplyValue / factories / resources
coreOf
occupationState
isPassable
```

当前语义：

- Region 是战略聚合层，不替代 hex。
- `displayHexes` 声明该 region 覆盖哪些 hex。
- `representativeHex` 是 UI 和某些 region->hex 转换的默认点。
- `neighbors` / `regionEdges` 是省份邻接图，但 v0.358 后不能单独拿它判断动态前线。前线必须看真实 hex 邻接。
- `RegionNode.controller` 不是直接推进权威。它由 `RegionOccupationRules.aggregateControl` 从 hex controller 加权派生。

### 1.4 Theater

源码：`WWIIHexV0/Core/Theater.swift`、`WWIIHexV0/Rules/TheaterSystem.swift`

`TheaterState` 关键字段：

```text
initialSnapshot: TheaterInitialSnapshot?
theaters: [TheaterId: TheaterNode]
hexToTheater: [HexCoord: TheaterId]
regionToTheater: [RegionId: TheaterId]
lastUpdatedTurn
```

`TheaterNode` 关键字段：

```text
id / name / status
regionIds
neighborTheaterIds
controllingFaction
controlRatios
victoryPointArea
frontWeight
unitIds
supportEligibleUnitIds
spilloverPolicy
recentThreats
```

当前语义必须分清三件事：

1. `initialSnapshot.regionToTheater`
   - 开局时捕获。
   - 只读初始战区布局。
   - UI 的 `initialTheater` 图层读取这里。
   - 地图编辑器导出的 region->theater assignment 会进入这里。

2. `regionToTheater`
   - 当前基础/初始战区单位。
   - 作为动态战区生成、合并、formalization、退役的参照。
   - 不代表运行时推进结果。
   - 不允许“占领一个 hex 后把整个 region 的 `regionToTheater` 改掉”。

3. `hexToTheater`
   - 运行时动态战区权威。
   - 单位突破进入某个 hex 后，只把这个 hex 改到进攻方动态战区。
   - 前线、动态战区图层、部署层都应以它为准。

`TheaterSystem.updateTheaters` 的派生刷新包括：

```text
seedMissingHexAssignments
  -> 给未填的 hexToTheater 填基础 regionToTheater
rebuildDynamicRegionMembership
  -> TheaterNode.regionIds 变为“该动态战区当前覆盖到的 region 集合”
rebuildNeighborTheaters
  -> 按 hexToTheater 的真实 hex 邻接生成战区邻接
assignUnits
  -> 按单位所在 hex 的 dynamicTheaterId 分配 theater.unitIds
calculateMetrics
  -> 按动态 theater 内 hex controller 计算 controlRatios / controllingFaction / frontWeight
```

`formalizationThreshold` 当前默认 0.70。它用于 formalized / provisional 状态判断，不阻止前线按单个 hex 推进。

### 1.5 FrontLine

源码：`WWIIHexV0/Core/FrontLine.swift`、`WWIIHexV0/Core/FrontSegment.swift`、`WWIIHexV0/Core/FrontLineState.swift`、`WWIIHexV0/Rules/FrontLineManager.swift`

`FrontLineState` 关键字段：

```text
frontLines: [FrontLineId: FrontLine]
regionStates: [RegionId: RegionFrontState]
enemyNeighborCache: [RegionId: [RegionId]]
dirtyRegionIds
diagnostics
```

`FrontLine`：

```text
id
theaterId
opposingTheaterIds
factionA / factionB
segments: [FrontSegment]
type: normal / breakthrough / encirclement
state: stable / pressured / collapsing 等
```

`FrontSegment`：

```text
regionA
regionB
edgeType
pressureLevel
supplyImpact
isEncirclementCandidate
```

当前前线生成逻辑：

```text
对每个 active theater:
  对 theater.regionIds 中的每个 region:
    只看该 region 内 dynamicTheaterId == theater.id 的 hex
    扫描这些 hex 的六向邻接 hex
    如果邻接 hex 属于另一个 dynamic theater
       且对方 theater 的 sourceFaction 不是 friendlyFaction:
         形成 enemy region 接触
         生成 FrontSegment(regionA: friendly region, regionB: enemy region)
```

重要结论：

- 前线不是 region 边界。
- 前线不是 initial theater 边界。
- 前线不是 `regionToTheater` 的邻接。
- 前线是真实动态战区 hex 接触。
- 同一个 region 被两个动态战区切开时，允许出现 `regionA == regionB` 的突破前线。这是 v0.358 后确认的合法状态。
- `FrontLine.type == .breakthrough` 的一个来源是：segment 的 `regionA` 仍由敌方 region controller 控制，但已有我方动态 theater hex 突入。

### 1.6 WarDeployment / FrontZone

源码：`WWIIHexV0/Core/WarDeploymentState.swift`、`WWIIHexV0/Core/FrontZone.swift`、`WWIIHexV0/Core/FrontZoneSegment.swift`、`WWIIHexV0/Rules/WarDeploymentManager.swift`

`WarDeploymentState` 关键字段：

```text
frontZones: [FrontZoneId: FrontZone]
hexToFrontZone: [HexCoord: FrontZoneId]
regionToFrontZone: [RegionId: FrontZoneId]
dirtyRegionIds
diagnostics
```

`FrontZone`：

```text
id / name
faction
regionIds
neighbors
frontSegments
unitsFront
unitsDepth
unitsGarrison
pressure
state
isCoreZone
```

当前部署层权威：

- `hexToFrontZone` 是动态部署归属权威。
- `regionToFrontZone` 是 dominant / fallback，不是突破推进权威。
- `FrontZoneId` 当前通常复用 `TheaterId.rawValue`。
- `WarDeploymentManager.advanceHex` 只推进一个 hex 的 zone 归属。
- `DeploymentLayer` / `UnitDeploymentRole` 当前落地为：
  - `frontUnit`
  - `depthUnit`
  - `garrisonUnit`

单位分配逻辑要点：

```text
每个 division:
  先按 division.coord 查 hexToFrontZone，fallback regionToFrontZone
  如果该 zone.faction == division.faction:
    使用该 zone
  否则如果所在 region 周边有己方 zone:
    分到相邻己方 zone
  否则 fallback 到该 faction 的 primary combat zone

  如果 hex 接触敌 zone
     或 assignedZoneId != 当前 hex zoneId
     或所在 hex controller != assignedZone.faction:
       unitsFront
  否则如果 zone.isCoreZone 或 region 有 city/factory/core:
       unitsGarrison
  否则:
       unitsDepth
```

这层是 AI 调度能否“看见部队”的关键。历史上的“AI 看起来不动”根因之一就是突破后的单位被误判成 garrison，从 `unitsFront` 调度池消失。现在前线/敌区/敌控 hex 会强制把这种单位归到 front。

### 1.7 朝堂 AI 审计层

源码：`WWIIHexV0/Core/DiplomacyState.swift`、`WWIIHexV0/Agents/RulerAgent.swift`、`WWIIHexV0/Turn/TurnManager.swift`

v3.4 起，默认战争 AI directive 路径接入最小朝堂层。它位于元帅/战区 directive 与执行层之间：

```text
MarshalAgent / TheaterCommanderPool
  -> DirectiveEnvelope
  -> CourtAgent.deliberate
  -> RulerAgent.adjust
  -> adjusted DirectiveEnvelope
  -> WarCommandExecutor
  -> RuleEngine
```

`DiplomacyState` 保存两类 AI 审计记录：

```text
rulerRecords: [RulerDecisionRecord]
courtRecords: [CourtDecisionRecord]
```

`RulerDecisionRecord` 记录君主姿态、重点方面、目标州郡、攻击阈值倾向、预备队倾向和理由。`CourtDecisionRecord` 记录朝堂步骤：君主、谋主、太守、行军总管、将领、使者。`AgentPanelView` 读取 `latestCourtRecord` 展示朝堂链路。

当前边界：

- 朝堂层只调整 `DirectiveEnvelope` 中的 `ZoneDirective`，不直接生成底层 `Command`。
- 朝堂层不能绕过 `WarCommandExecutor` / `RuleEngine`。
- 朝堂层不能直接修改 `HexTile.controller`、`Division.coord`、`regionToTheater`、`hexToTheater` 或 `hexToFrontZone`。
- v3.7-preflight.10 后玩家侧太守经营可通过 `Command.governRegion` 执行；v3.7-preflight.11 后 AI 太守会在 AI/观战自动回合最多生成一条 `Command.governRegion`，仍交给 `RuleEngine` 校验执行。
- v3.7-preflight.9 后玩家侧使者可通过 `Command.updateDiplomacy` 执行议和/纳降；v3.7-preflight.12 后 AI 使者会在保守条件下最多生成一条停战或归附关系命令；v3.7-preflight.13 后外交关系变化会生成 `DiplomacyEventRecord` 并关联战报；v3.7-preflight.14 后已归附且无实体存在的势力会退出通用回合轮转；v3.7-preflight.15 后外交面板会盘点归附目标残余实体；v3.7-preflight.16 后归附接收方可通过 `Command.resolveSubmissionHandoff` 接管残余军队和可通行受控 hex，仍交给 `RuleEngine` 校验执行；v3.7-preflight.17 后交接结果会生成 `SubmissionHandoffRecord` 并关联外交战报；v3.7-preflight.18 后 AI 接收方会在 AI 回合最多执行一条归附实体交接命令；v3.7-preflight.19 后交接成功会生成 `SubmissionAftermathRecord` 善后压力记录；v3.7-preflight.101 后善后压力会写入受影响州郡治安/顺从状态；v3.7-preflight.20 后 AI 太守会把高/需安抚善后州郡纳入优先经营候选；v3.7-preflight.21 后治理这些善后州郡会生成 `SubmissionAftermathGovernanceRecord` 处置审计记录；v3.7-preflight.22 后外交面板会汇总本次善后处置进度；v3.7-preflight.23 后 AI 太守会优先治理尚未处置的善后州郡；v3.7-preflight.24 后外交面板会显示待处置数量和完成状态，AI 太守在全部处置后不再特殊优先该善后记录；v3.7-preflight.25 后发布检查面板会把代码接入、运行时门禁和后续功能拆开展示；v3.7-preflight.26 后 AI 太守跳过经营时会把原因写入诊断；v3.7-preflight.27 后 AI 使者和归附交接跳过行动时也会把原因写入诊断；v3.7-preflight.28 后 MapEditor 默认资源桥对齐到 `wude_618` 并保留既有场景元数据；v3.7-preflight.29 后 MapEditor 可字段化维护 scenario `keyLocations`；v3.7-preflight.30 后发布检查面板可展示当前 `GameState` 静态门禁快照；v3.7-preflight.31 后部分 legacy 势力名、阶段、胜负原因和事件日志显示兜底已中文化；v3.7-preflight.32 后第一批 App/AI 记录、bootstrap 战报、朝堂面板和将领技能调试文案已中文化；v3.7-preflight.33 后外交/朝堂面板、记录摘要、详情面板和可访问性入口的一批 raw/debug 文案已收口；v3.7-preflight.34 后 AI 诊断、命令结果摘要和 legacy Agent D 失败路径的一批英文/工程词已收口；v3.7-preflight.35 后战报 metadata、战报重点摘要和总管预备军令预览的一批 raw/debug 文案已收口。
- 元帅 JSON 解码失败时仍先使用 `TheaterCommanderPool` fallback，再进入朝堂层审计和塑形，不执行半成品 JSON。

### 1.8 EconomyState / EconomyRules

源码：`WWIIHexV0/Core/EconomyState.swift`、`WWIIHexV0/Rules/EconomyRules.swift`

v0.8 新增初级回合经济层。它是 faction 级总账，不是第三套地图权威。

`EconomyState`：

```text
ledgers: [Faction: FactionEconomyLedger]
lastResolvedTurn
```

`FactionEconomyLedger`：

```text
faction
stockpile: EconomyResources
lastIncome
lastUpkeep
lastReinforcementSpend
productionQueue: [ProductionOrder]
lastUpdatedTurn
```

`EconomyResources` 只包含三项：

```text
manpower
industry
supplies
```

收入算法：

```text
对 faction 控制且 passable 的每个 region:
  如果该 region 没有任何真实己方控制 hex，跳过
  cityLevel = EconomyRules.cityLevel(region, map)
  coreBonus = region.coreOf 为空或包含 faction ? 1 : 0
  manpower = max(1, cityLevel.manpowerGrowth + coreBonus * 4 + infrastructure)
  industry = max(0, factories + cityLevel.industryValue + infrastructure / 3)
  supplies = max(1, supplyValue * 3 + factories + infrastructure / 2)
```

城市等级不是单独 JSON schema，当前从既有字段推导：

- capital、victoryPoints >= 5 或 factories >= 5 -> `metropolis`。
- victoryPoints >= 2、factories >= 2 或 supplyValue >= 3 -> `town`。
- 有 city / fortress / factory 但不满足上面条件 -> `village`。
- 没有城市、堡垒或工厂信号 -> `none`。

生产队列由 `Command.queueProduction(kind:)` 进入规则系统：

```text
EconomyPanelView
  -> AppContainer.queueProduction
  -> Command.queueProduction
  -> RuleEngine
  -> CommandValidator.validateProduction
  -> CommandExecutor.executeQueueProduction
  -> EconomyRules.queueProduction
```

排产时预付资源，完成时才部署单位或发放 supply stockpile。完成单位只能放到本方控制、passable、空置、非敌邻，且位于首都、城镇/大都会、工厂、高基建、高补给 region 或 supply source 的后方 hex。找不到安全部署点时订单保留到下回合继续尝试。

自动补员在 active faction 结束回合时发生，只处理：

```text
本阵营
未毁灭
未撤退
supplied
strength < maxStrength
不与敌军相邻
```

每个单位每回合最多恢复 2 strength，并按装甲、摩托化、火炮权重扣 manpower / industry / supplies。v0.8 不恢复 organization。

---

## 2. 数据启动流程

### 2.1 默认启动路径

源码：`WWIIHexV0/Data/DataLoader.swift`、`WWIIHexV0/App/AppContainer.swift`

主入口：

```text
AppContainer.bootstrap()
  -> DataLoader().loadInitialGameState()
  -> RuleEngine()
  -> GameAgent.guderian(...)
  -> StrategicStateBootstrapper().bootstrapIfNeeded(...)
  -> TurnManager(... commanderPool: buildCommanderPool(state: bootstrappedState))
  -> AppContainer(...)
```

`DataLoader.loadInitialGameState()` 当前优先走 v3.2 隋唐默认 JSON：

```text
loadGameState(
  scenarioName: "wude_618_scenario",
  regionName: "wude_618_regions",
  unitTemplatesName: "suitang_unit_templates",
  generalRegistryName: "suitang_generals"
)
```

如果 v3.2 数据加载失败，才 fallback 到编辑器兼容阿登 JSON：

```text
loadGameState(
  scenarioName: "ardennes_v0_scenario",
  regionName: "ardennes_v02_regions"
)
```

如果阿登 JSON 也失败，最后 fallback 到老的 `GameState.initial()` + v0.2 region 叠加路径。

### 2.2 loadGameState 的完整链条

源码：`WWIIHexV0/Data/DataLoader.swift`

```text
loadScenarioDefinition(named:)
loadRegionDataSet(named:)
  -> makeMapState(from: scenario)
     - ScenarioTileDefinition -> HexTile
     - tile.controller 字符串转 Faction；"neutral" 转 nil
     - tile.regionId 写入 HexTile.regionId
     - supply source / objective 写入 MapState
  -> apply(regionData, to: map)
     - regionData.toRegions()
     - regionData.toHexToRegion()
     - regionData.toRegionEdges()
     - 反填 HexTile.regionId
     - validateRegionGraph()
  -> RegionOccupationRules().mapByAggregatingControllers(in: map)
     - 从 hex controller 派生 region controller
  -> makeDivisions(from: scenario.initialUnits)
     - 优先使用传入的 unit template resource
     - 缺失时 fallback 到 legacy component 规则，保证 MapEditor 临时导出仍可加载
  -> makeTheaterState(map, regionData, divisions, turn)
     - 优先使用 regionData.regions[].theaterId
     - 没有 assignment 时使用 TheaterSystem.makeInitialFixedTheaters
     - TheaterSystem.updateTheaters seed hexToTheater 并刷新派生字段
     - capture initialSnapshot
  -> FrontLineManager.makeInitialState(...)
  -> WarDeploymentManager.makeInitialState(...)
  -> assignGenerals(...)
     - 优先使用传入的 general registry resource
     - 缺失时 fallback 到 empty registry
  -> GameState(...)
```

DEBUG 下资源读取优先源码目录 `WWIIHexV0/Data/*.json`，不是旧 bundle。旧 simulator 进程不会自动重载，改默认地图后需要重新运行 app。

### 2.3 StrategicStateBootstrapper

源码：`WWIIHexV0/Core/StrategicStateBootstrapper.swift`

它有两个用途：

1. `bootstrapIfNeeded`
   - 只补缺失层。
   - 先用 `EconomyRules.bootstrapIfNeeded` 为旧状态补 faction 经济总账。
   - 如果 state 有 region 但缺 theater/front/deployment，会从当前 map/divisions 生成。
   - App 初始化、命令提交后会用它兜底。

2. `refreshRuntimeState`
   - 强制刷新运行时派生层。
   - 先聚合 region controller。
   - 强制 `TheaterSystem.updateTheaters(force: true)`。
   - 重新 `FrontLineManager.makeInitialState`。
   - 重新 `WarDeploymentState.bootstrapFrontZones`。
   - AI 行动前会调用，确保指令读取的是当前动态层。

---

## 3. 地图编辑器流程

### 3.1 MapEditorDocument

源码：`MapEditor/MapEditorDocument.swift`

编辑器自己的文档模型：

```text
id / displayName
width / height
hexes: [HexCoord: MapEditorHex]
regions: [RegionId: MapEditorRegionDraft]
theaters: [TheaterId: MapEditorTheaterDraft]
regionTheaterAssignments: [RegionId: TheaterId]
initialUnits: [MapEditorUnitDraft]
keyLocations: [MapEditorKeyLocationDraft]
keyLocationsAreAuthoritative: Bool
suppressedKeyLocationCoordKeys: Set<String>
backgroundImage
```

四种编辑模式：

```text
hexPainter         地块
regionBuilder      州郡
theaterAssignment  方面
unitPlanner        军队
```

编辑动作：

```text
idle
adding
deleting
```

地块工具：

```text
paint   覆盖已有 hex
extend  在已有 hex 邻位扩展稀疏地图
```

关键行为：

- `MapEditorDocument.contains(_:)` 判断实际存在的 hex，支持稀疏地图。
- `addHex(at:)` 只能在已有 hex 邻位扩展，避免凭空造孤岛。
- `deleteHex(at:)` 会删除该 hex 上初始部队；如果某 region 已无 hex，会删除 region 和 theater assignment。
- `deleteHex(at:)` / `resetHex(at:)` 会删除该 hex 上的独立地点记录，并写入坐标级地点抑制记录。
- `resize` 会裁剪外部 hex、清理无效 region assignment、越界单位、越界地点记录和越界地点抑制记录。
- v3.7-preflight.29 起，`keyLocations` 保存 scenario 地点字段；旧文档缺该字段时仍可解码，`keyLocationsAreAuthoritative` 为 false 时导出器会用现有 scenario metadata 兜底。
- `suppressedKeyLocationCoordKeys` 记录用户删除或重置过的地点坐标，阻止导出器从 metadata 或 city / fortress / supply hex 语义重新补回该坐标。
- 底图 `backgroundImage` 只存在编辑器文档，不写入游戏 JSON。

### 3.2 编辑会话

源码：`MapEditor/MapEditorViewModel.swift`

典型流程：

```text
选择 mode
  -> beginAdding / beginDeleting
  -> 点击或拖拽 canvas
  -> applyPrimaryAction(at:)
  -> stage 或直接编辑
  -> finishEditing
  -> commitPendingRegion / commitPendingTheater / commitPendingUnits
```

不同模式行为：

- `hexPainter`
  - adding + paint：写 terrain、road、controller、supply。
  - adding + extend：尝试在相邻空位生成 plain hex。
  - deleting：删除 hex。

- `regionBuilder`
  - adding：把点击 hex 先放进 `pendingRegionHexes`，完成时统一 assign 到选中或新建 region。
  - deleting / erase：把 hex 的 regionId 清空。

- `theaterAssignment`
  - 点击 hex 后先取该 hex 的 regionId。
  - adding：把 region 放进 `pendingTheaterRegions`，完成时统一 assign 到选中或新建 theater。
  - deleting：清除 region 的 theater assignment。

- `unitPlanner`
  - adding：点击 hex 放入 `pendingUnitHexes`，完成时按模板、阵营、朝向、HP 生成初始单位。
  - 同一 hex 新 stamp 会先删除原单位。
  - deleting / erase：删除该 hex 上初始单位。

- 右键信息面板
  - 可改选中 hex 的州郡/方面名称。
  - v3.7-preflight.29 起，可保存或删除该 hex 的地点名称、类型、势力和 objectiveId。

快捷键：

- `N`：添加。
- `M`：完成。

### 3.3 导出链路

源码：`MapEditor/MapEditorExporter.swift`

导出产物：

```text
ScenarioDefinition JSON
RegionDataSet JSON
```

导出前校验：

- 所有 hex 必须有 regionId，否则 `unassignedHex`。
- 所有被引用 region 必须在 `document.regions` 里定义。
- 每个导出的 region 必须至少有一个 hex，否则 `emptyRegion`。

`ScenarioDefinition` 写入：

- map width/height/isSparse。
- 每个 `MapEditorHex` 写为 `ScenarioTileDefinition`。
- terrain / road / controller / city / fortress / supply / objective / regionId。
- factions、initialTurn、initialPhase、playerFaction、aiFaction。
- v3.7-preflight.28 起，`MapEditorExportMetadata` 会为默认隋唐导出保留既有 factions、maxTurns、initialPhase、playerFaction、aiFaction、victoryConditions、objectives 点数、`keyLocations` 和 dataNotes。
- v3.7-preflight.60 起，普通自定义文档未传 metadata 时默认使用隋唐草稿口径；只有明确 legacy / Ardennes / WWII / 阿登 / 旧战局文档才推断为 legacy 阿登 metadata。
- v3.7-preflight.29 起，`document.keyLocations` 会写入 `ScenarioDefinition.keyLocations` 并作为合并 base；`keyLocationsAreAuthoritative == false` 时再合入 metadata `keyLocations`，旧文档缺字段会解码为 false；city / fortress / supply hex 派生地点始终作为补齐来源，三者按 id / objectiveId / coord 去重。
- 导出地点时会过滤当前文档不存在的坐标，并跳过 `suppressedKeyLocationCoordKeys` 中的坐标，避免删除派生地点后又被 city / fortress / supply 语义补回。
- `initialUnits` 从 `MapEditorUnitDraft` 写入。
- 底图不写入。

`RegionDataSet` 写入：

```text
hexToRegion:
  每个 hex 的 coord key -> regionId

regions:
  每个 MapEditorRegionDraft -> RegionNodeDefinition
  theaterId = document.regionTheaterAssignments[draft.id]
  displayHexes = 属于该 region 的 hex
  representativeHex = displayHexes 几何中心最近 hex
  terrain = region 内 dominant terrain
  city = 第一处 city / fortress / city terrain
  neighbors = 从 hex 邻接自动推导

edges:
  从跨 region hex 邻接自动推导
  两侧 hex 都有 road 时 hasRoad = true

supplySources / objectives:
  从对应 hex 自动归到 region
```

重要：region 邻接和 edge 不是人工手填权威，而是在导出时从真实 hex 邻接推导。这和运行时前线必须看 hex 邻接是一致的。

### 3.4 默认资源桥

源码：`MapEditor/MapEditorGameResourceBridge.swift`

默认读写路径：

```text
WWIIHexV0/Data/wude_618_scenario.json
WWIIHexV0/Data/wude_618_regions.json
```

v3.7-preflight.28 后 MapEditor 默认资源桥已与主游戏默认入口对齐到 `wude_618`。阿登 JSON 仍作为 legacy fallback 和历史回归参考保留，但编辑器“读取默认隋唐资源 / 覆盖保存为游戏资源”不再默认写阿登文件。

覆盖默认隋唐资源时，`MapEditorGameResourceBridge` 会读取现有 `wude_618_scenario.json` 的场景元数据并传给 `MapEditorExporter`。导出器会保留既有势力列表、回合配置、胜负条件、objective 点数和 data notes；v3.7-preflight.29 后若 `keyLocationsAreAuthoritative == false` 才继续用 metadata `keyLocations` 兜底，旧文档缺字段会解码为 false。`document.keyLocations` 始终优先，city / fortress / supply hex 派生地点仍会补齐未显式设置或未抑制的坐标。这样避免保存一次编辑器数据就把 `wude_618` 退回 legacy `alliedPlayer` / `germany` / 空胜负条件口径，同时允许编辑器实际修改渡口/港口等地点记录。

v3.7-preflight.29 后，MapEditor 右栏“导出 JSON 到内存”对 `wude_618` 文档也会通过 `MapEditorGameResourceBridge.exportMetadata(for:)` 传入默认场景 metadata，避免内存导出和覆盖默认资源在胜负条件、objective 点数或地点兜底上分叉。

当前限制：地点字段只影响 scenario `keyLocations` 和 MapEditor 画布标记，不新增水战、渡河、港口补给、移动、战斗或胜负规则。

流程：

```text
loadDefaultDocument()
  -> 读取默认 ScenarioDefinition + RegionDataSet
  -> makeDocument(...)
     - scenario tile -> MapEditorHex
     - regionData.toHexToRegion 优先填 regionId
     - region definitions -> MapEditorRegionDraft
     - region theaterId -> regionTheaterAssignments
     - scenario initialUnits -> MapEditorUnitDraft
       - 非法 unit faction -> 跳过该 unit + MapEditorGameResourceImportDiagnostic
     - scenario keyLocations -> MapEditorKeyLocationDraft

loadDefaultDocumentResult()
  -> 返回 MapEditorDocument
  -> 返回导入诊断供 MapEditorViewModel 状态消息展示

overwriteDefaultGameResources(document:)
  -> 读取现有 wude_618 scenario 元数据
  -> MapEditorExporter.export(... 固定默认隋唐文件名, metadata: ...)
     - document.keyLocations 优先
     - keyLocationsAreAuthoritative == false 时 metadata.keyLocations 兜底
     - city / fortress / supply hex 派生地点补齐未显式设置的坐标
  -> 写回 WWIIHexV0/Data
```

相关测试确认：

- 编辑器 document、导出 JSON、游戏加载后的 `hexToRegion` / `regionToTheater` / `tile.regionId` / `region.name` 必须一致。
- 游戏和编辑器 hex layout 的垂直方向必须一致。
- 默认开局单位不能出现在敌对初始 theater 中。
- App bootstrap 不应自动跑 AI 或移动开局单位。

---

## 4. 主游戏 UI 与输入流程

### 4.1 AppContainer

源码：`WWIIHexV0/App/AppContainer.swift`

`AppContainer` 是 SwiftUI 和规则层之间的中介。它持有：

```text
@Published gameState
selectedUnitId / selectedHex / selectedRegionId
movementHighlights / attackHighlights
interactionLog
lastCommandMessage
lastAgentDecisionRecord
lastWarDirectiveRecords
observerModeEnabled
mapDisplayLayer
```

玩家提交命令：

```text
submit(command)
  -> commandHandler.execute(command, in: gameState)
  -> StrategicStateBootstrapper.bootstrapIfNeeded(result.state)
  -> lastCommandMessage = commandPanelMessage(for: result)
  -> appendInteractionEvent(...)
  -> refreshSelectionAfterStateChange()
  -> runAIIfNeeded()
```

点击地图：

```text
handleBoardTap(coord)
  -> selectedHex = coord
  -> selectedRegionId = MapDisplayAdapter.regionId(for: coord)
  -> 如果已有己方可行动单位选中，且点击处有敌军:
       submit(.attack)
     else 如果点击处有单位:
       handleDivisionTap
     else 如果已有己方可行动单位选中:
       submit(.move)
     else:
       清空选择
```

玩家可行动单位必须满足：

- 非 observer mode。
- 单位属于 `playerFaction`。
- 当前 activeFaction 是 `playerFaction`。
- 当前 phase 允许玩家输入，即 `phase.allowsPlayerInput`。
- 未行动。

### 4.2 RootGameView

源码：`WWIIHexV0/UI/RootGameView.swift`

主界面元素：

- `BoardSceneView`：SpriteKit 地图。
- `HUDView`：回合、当前势力、阶段、资源、胜负、局势菜单和结束回合。
- `GameSaveStore`：本地 JSON 存取 `GameState`；`AppContainer` 在启动、命令执行、总管军令和 AI 结算后调用。
- `MapDisplayLayer` segmented picker：
  - 地块
  - 州郡
  - 初始方面
  - 动态方面
  - 前线
  - 部署
- “观战” toggle。
- “军情 / 收起军情”面板，内含：
  - 军队
  - 州郡
  - 总管
  - 战报
  - 粮饷
  - 外交
  - 朝堂
- `UnitTooltipView`。

当前开局不会在 `RootGameView` 自动 `.task { runAIIfNeeded() }`。AI 行动由 `advanceOrRunAI()` 或命令提交后的 `runAIIfNeeded()` 触发。

### 4.3 v1.1 主游戏 macOS target

源码：

- `WWIIHexV0/App/WWIIHexV0MacApp.swift`
- `WWIIHexV0/SpriteKit/BoardSceneView.swift`
- `WWIIHexV0/SpriteKit/BoardScene.swift`
- `WWIIHexV0/UI/PlatformStyles.swift`

v1.1 新增独立 macOS 主游戏 target：

```text
WWIIHexV0Mac
  -> WWIIHexV0MacApp
  -> AppContainer.bootstrap()
  -> RootGameView(container:)
  -> BoardSceneView
  -> BoardScene
```

这个 target 和既有 target 的边界：

- `WWIIHexV0`：iOS 主游戏 target。
- `WWIIHexV0Mac`：macOS 主游戏 target。
- `MapEditorMac`：macOS 地图编辑器 target，不是主游戏入口。

`WWIIHexV0Mac` 复用主游戏数据和规则，不新增一套 mac 专用规则。resource phase 包含：

```text
ardennes_v0_scenario.json
ardennes_v02_regions.json
wude_618_scenario.json
wude_618_regions.json
general_agents.json
generals.json
suitang_generals.json
terrain_rules.json
suitang_terrain_rules.json
unit_templates.json
suitang_unit_templates.json
suitang_power_profiles.json
```

DEBUG 下 `DataLoader` 仍优先读源码目录 `WWIIHexV0/Data/*.json`；bundle resources 是 release / fallback 路径。

`BoardSceneView` 现在有平台分支：

```text
iOS:
  UIViewRepresentable
  -> SKView
  -> BoardScene touch input

macOS:
  NSViewRepresentable
  -> BoardEventSKView
  -> BoardScene mouse / scroll / magnify input
```

macOS 输入桥接逻辑：

```text
鼠标点击
  -> BoardScene.mouseDown / mouseUp
  -> layout.pixelToHex
  -> onHexTapped(coord)
  -> AppContainer.handleBoardTap

鼠标拖拽
  -> BoardScene.mouseDragged
  -> camera.position 更新
  -> clampCamera

滚轮 / 触控板缩放
  -> BoardEventSKView.scrollWheel / magnify
  -> scene.convertPoint(fromView:)
  -> BoardScene.handleScrollWheel / handleMagnify
  -> zoomCamera(anchor:)
  -> clampCamera
```

注意：macOS 点击仍只进入 `AppContainer.handleBoardTap`。移动、攻击、结束回合和 AI 行动仍由 `RuleEngine` / `WarCommandExecutor` 处理；v1.1 不允许通过 AppKit 或 SpriteKit 直接修改 `GameState`。

---

## 5. 命令执行流程

### 5.1 Command / RuleEngine

源码：`WWIIHexV0/Commands/Command.swift`、`WWIIHexV0/Rules/RuleEngine.swift`、`WWIIHexV0/Rules/CommandValidator.swift`、`WWIIHexV0/Rules/CommandExecutor.swift`

底层 `Command` 当前包括：

```text
move(divisionId, destination)
attack(attackerId, targetId)
hold(divisionId)
allowRetreat(divisionId)
resupply(divisionId)
queueProduction(kind)
endTurn
```

执行总入口：

```text
RuleEngine.execute(command, in: state)
  -> EconomyRules.bootstrapIfNeeded(state)
  -> CommandValidator.validate(command, in: preparedState)
  -> invalid: 返回 CommandResult，state 不变
  -> valid: CommandExecutor.execute(command, in: preparedState)
```

### 5.2 校验规则

`CommandValidator` 的关键校验：

移动：

```text
phaseAllowsCommands
division exists
division.faction == activeFaction
division 未行动、未撤退、canAct
destination 在地图内
destination passable
destination 没有其他单位
忽略 movement 的最短路径 cost <= division.movement
真实 shortestPath 存在
```

攻击：

```text
attacker 可行动
target exists
target.faction != attacker.faction
distance <= attacker.range
```

恢复/姿态：

```text
phase 合法
division exists
faction 匹配 activeFaction
未行动、未毁灭、未撤退
```

结束回合：

```text
phaseAllowsCommands
```

生产排队：

```text
phaseAllowsCommands
active faction economy ledger 有足够 manpower / industry / supplies
```

### 5.3 移动与占领

`CommandExecutor.executeMove` 真实链路：

```text
记录 origin
sourceZoneId = warDeploymentState.zoneId(for: origin)
更新 facing
division.coord = destination
division.hasActed = true

if OccupationRules.canOccupy(division, destination, state):
  tile.controller = division.faction
  map.setTile(tile)

  if destinationRegionId && sourceZoneId:
    applyStrategicAdvance(
      regionId: destinationRegionId,
      hex: destination,
      sourceZoneId: sourceZoneId,
      faction: division.faction
    )

  StrategicStateSynchronizer.synchronizeAfterOccupationChange(
    affectedRegionIds: [destinationRegionId]
  )

appendEvent("moved")
```

`OccupationRules.canOccupy` 很小，但非常关键：

```text
tile exists
tile.isCapturable
tile.controller != division.faction
destination 没有其他单位
```

注意：

- 只有移动会触发占领。
- 攻击造成伤害/撤退/消灭，不会自动把攻击者推进到目标 hex。
- 移动进敌控空 hex 时，先改 hex controller，再同步战略层。
- 移动进有敌单位的 hex 会在 validator 被 `destinationOccupied` 拒绝。

### 5.4 动态战区推进

`CommandExecutor.applyStrategicAdvance` 的语义：

```text
advancingTheaterId = TheaterId(sourceZoneId.rawValue)
如果 theater 不存在，return
如果 destination hex 已经属于 advancingTheater，return
如果 shouldAdvanceDynamicTheater == false，return

advancingFaction =
  frontZones[sourceZoneId].faction
  或 acting division faction
  否则跳过本次 dynamic theater advance 并记录原因

TheaterSystem.expandDynamicTheater(
  breakthroughHex: destination,
  advancingTheaterId,
  faction: advancingFaction
)

oldZoneId = warDeploymentState.zoneId(for: destination)
如果 oldZoneId != sourceZoneId:
  WarDeploymentManager.advanceHex(destination, from: oldZoneId, to: sourceZoneId)

appendEvent("Hex q,r reassigned to dynamic theater ...")
```

`shouldAdvanceDynamicTheater` 当前判断：

- 如果目标 hex 当前 zone 属于其他 faction，则可以推进。
- 否则如果目标 hex controller 不是本方，也可以推进。
- 否则不推进。

这确保动态推进是 hex 级，不会把整个 region 拉走。

### 5.5 Region / Theater / Front / Deploy 同步

源码：`WWIIHexV0/Rules/StrategicStateSynchronizer.swift`

占领变化后：

```text
RegionOccupationRules.aggregateControl(in: &state)
  -> changedRegionIds

affected = affectedRegionIds + changedRegionIds

TheaterSystem.updateTheaters(force: true)

FrontLineManager.update(
  events:
    changed -> regionControllerChanged
    unchanged -> occupationChanged
)

WarDeploymentManager.update(
  events: affected.map(regionControllerChanged)
)

可选写 region owner change event
```

Region controller 聚合权重：

- 每个已控制 hex 基础权重 1。
- `representativeHex` 加 region city VP。
- city / fortress / city terrain / fortress terrain 再加权。
- 中立 hex 不计入。
- 并列第一时不改 region controller。

### 5.6 攻击、撤退、补给、结束回合

攻击流程：

```text
计算 attackDamage
attacker.hasActed = true
attacker.facing = 面向 defender
对 defender 扣 strength
resolveCombatResult
  -> retreatable 且 lossRatio >= 0.35 时 shouldRetreat
  -> hold 模式追加损失
  -> encircled 且撤退触发追加损失
  -> destroyed 则 removeDivision + victory record
如果 defender 没撤退且可反击:
  defender counterattack
  attacker 也可能撤退/毁灭
```

结束回合：

```text
SupplyRules.updateSupplyStates
EconomyRules.resolveFactionTurn(for: activeFaction)
  -> 收入入账
  -> 支付战略补给维护费
  -> 粮草库存短缺时 supplied 单位降为 lowSupply
  -> 安全后方自动补员；v3.3 起被围城池/关隘守军不能自动补员
  -> 推进生产队列并部署完成单位
SupplyRules.advanceRetreats
SupplyRules.applyEncirclementAttrition
VictoryRules.updateVictoryState
  -> wude_618_guanzhong_luoyang:
     唐控制洛阳 + 洛口仓即胜
     洛阳隋控制潼关即胜
     终局最后一个势力行动结束后按长安控制权结算
  -> legacy Ardennes:
     Bastogne / St. Vith / eliminated units / German armor supply

legacy activeFaction:
  germany + germanAI -> allies + alliedPlayer
  allies + alliedPlayer -> germany + germanAI, turn += 1

generic activeFaction:
  playerCommand / aiCommand
  -> 按当前状态实际势力集合和 Faction.suitangTurnOrder 推进
  -> state.playerFaction 默认进入 playerCommand
  -> 其他势力默认进入 aiCommand

resetActionsForActiveFaction
StrategicStateBootstrapper.refreshRuntimeState
appendEvent("Turn advanced ...")
```

### 5.4 v3.3 兵种、粮道和围城最小规则

源码：`WWIIHexV0/Core/Division.swift`、`WWIIHexV0/Core/SupplyState.swift`、`WWIIHexV0/Rules/CombatRules.swift`、`WWIIHexV0/Rules/SupplyRules.swift`、`WWIIHexV0/Rules/EconomyRules.swift`

v3.3 起，`ComponentType` 同时保留 legacy 二战 rawValue 和新增隋唐兵种 rawValue。当前可直接表达：

```text
infantry        -> 步卒
cavalry         -> 骑军
archer          -> 弓弩
siegeEngine     -> 攻城器械
guard           -> 亲军
naval           -> 水师
militia         -> 乡兵

tank / motorizedInfantry / artillery
  -> legacy rawValue，保留给阿登数据和旧测试兼容
```

`Division` 仍是源码兼容名，但 UI 显示为军队/兵种；规则通过 helper 判断：

```text
hasCavalryShock    -> 平原冲击、复杂地形限制、机动排序
isMobileForce      -> ZoneCommanderAgent / WarCommandExecutor 选择机动单位
hasRangedSupport   -> 弓弩压制、远程支援评分
hasSiegeCapability -> 攻城器械对城池/关隘加成
primaryComponentType / unitKindDisplayName -> UI 军牌和检查器显示
```

围城是派生判断，不是新的占领权威：

```text
SupplyRules.isBesieged(division)
  条件：
    1. division 所在 hex / region 代表点是城池或关隘
    2. 该 division 无己方粮道
    3. 邻接 hex 有外交敌对单位
  结果：
    supplyState 归入 encircled
    写入围城日志
    CombatRules 下调被围守军防御
    EconomyRules 不给被围守军自动补员
```

城池/关隘被围不会直接改变 `HexTile.controller`，也不会直接改变 `RegionNode.controller`、`hexToTheater` 或 `hexToFrontZone`。破城、占领和动态推进仍必须通过 `Command` / `ZoneDirective -> WarCommandExecutor -> RuleEngine`，再由 `StrategicStateSynchronizer` 刷新战略层。

---

## 6. AI / 战争指令流程

### 6.1 当前默认元帅决策链

源码：`WWIIHexV0/Turn/TurnManager.swift`、`WWIIHexV0/Agents/ZoneCommanderAgent.swift`、`WWIIHexV0/Commands/WarDirective.swift`、`WWIIHexV0/Commands/WarCommandExecutor.swift`

历史 v0.5 引入了元帅决策链；当前 main 默认 AI 主路径继续保留并扩展为以下链路：

```text
AppContainer.runAIIfNeeded
  -> runAISequence
  -> TurnManager.runAITurn(... pipelineMode: .marshalDirective)
  -> MarshalAgent.resolve
  -> MarshalBattlefieldSummarizer.summary
  -> SimulatedMarshalLLMClient.completeTheaterDirectiveJSON
  -> TheaterDirectiveDecoder.parse
  -> TheaterDirectiveCompiler.compile
  -> CourtAgent.deliberate
  -> RulerAgent.adjust
  -> DirectiveEnvelope / ZoneDirective
  -> WarCommandExecutor.execute(directive, in: state)
  -> RuleEngine.execute(Command)
  -> WarDirectiveRecord
  -> RulerDecisionRecord / CourtDecisionRecord
  -> RuleEngine.execute(.endTurn)
```

`MarshalAgent` 是元帅层，不是单位，也不是新规则执行器。它只读取降维摘要并输出 `TheaterDirectiveEnvelope` JSON：

```text
TheaterDirectiveEnvelope
  schemaVersion = 5
  issuerId / turn / faction
  strategicIntent
  directives: [TheaterDirective]

TheaterDirective
  zoneId
  category offense/defense
  tactic
  priority
  targetTheaterId
  weightedRegions / focusRegionId / supportRegionIds
  reserveBias
  intensity / maxCommittedUnits / exploitDepth
  rationale
```

`TheaterDirectiveDecoder` 负责从模拟 LLM 文本中提取纯 JSON 或 fenced JSON，使用 `JSONDecoder` 解码，并校验 schemaVersion、issuerId、turn、faction、zone 存在性、zone 阵营、region id、target theater/front zone 与 tactic/category 一致性。解码或校验失败时，不执行半成品 JSON，`MarshalAgent` fallback 到 `TheaterCommanderPool`。

`TheaterDirectiveCompiler` 把元帅意图降级到现有 `ZoneDirective`：

- offense -> `ZoneDirective.attack`，保留 target theater、weighted/focus/support regions、intensity、maxCommittedUnits、exploitDepth。
- defense -> `ZoneDirective.defend`，把 reserveBias 转成 targetReserves，把 focus/weighted regions 转成 strongpointRegionIds，把 supportRegionIds 转成 fallbackRegionIds。
- 某个 zone 没有元帅 directive 或编译失败时，使用 `TheaterCommanderPool` 给该 zone 的旧 directive。

v3.4 后，`CourtAgent` 在执行前读取 `DirectiveEnvelope` 并写出朝堂审计：

- 君主层调用 `RulerAgent.adjust`，按姿态调整攻防强度、预备队倾向和部分目标排序，同时保留元帅编译出的 focus/support/convergence/coordinated/maxCommitted/exploit 等字段。
- 谋主层记录 `TheaterDirectiveEnvelope.strategicIntent` 或 fallback 方面目标。
- 太守层记录补给、围城和州郡治理关注点；玩家侧经营已由 `Command.governRegion` 执行，AI 太守会在 `TurnManager.executeDirectiveEnvelope` 的朝堂记录之后尝试生成一条 `Command.governRegion`。
- 行军总管层记录将下发的 `ZoneDirective` 数量和目标。
- 将领层记录战术偏好，不直接选择底层 `Command`。
- 使者层记录 `DiplomacyState.summary`；玩家侧外交已由 `Command.updateDiplomacy` 执行，AI 使者会在 `TurnManager.executeDirectiveEnvelope` 的太守经营之后尝试生成一条保守外交关系命令。

最终执行由 `TurnManager.executeDirectiveEnvelope` 统一完成。`.marshalDirective` 和显式 `.zoneDirective` 共享同一段 CourtAgent 塑形、WarCommandExecutor 执行、WarDirectiveRecord 记录、Ruler/Court 审计记录、AI 太守经营命令尝试、AI 使者外交命令尝试和 endTurn 推进逻辑。

Legacy Agent D 仍存在，但只在显式 `.legacyAgentOrder` 分支运行：

```text
AgentContextBuilder
  -> DecisionProvider
  -> AgentDecisionParser
  -> AgentCommandMapper
  -> RuleEngine
```

默认不得把 Legacy 管线接回战争 AI 主路径。

v0.37 直接将军池路径仍可显式使用：

```text
TurnManager.runAITurn(... pipelineMode: .zoneDirective)
  -> TheaterCommanderPool.envelope
  -> ZoneCommanderAgent.makeDirective
  -> DirectiveEnvelope
  -> CourtAgent.deliberate
  -> WarCommandExecutor
```

### 6.2 AI 触发条件

`AppContainer.shouldRunAI`：

```text
phase 先按 activeFaction / playerFaction 规范化

playerFaction:
  observerModeEnabled && phase 允许当前 activeFaction 自动行动

其他 activeFaction:
  phase == .aiCommand 或 legacy 兼容阶段规范化后允许自动行动
```

`runAISequence`：

- 非 observer mode：最多跑 1 个 AI step。
- observer mode：最多跑 2 个 AI step，因此一次按钮推进可让当前 AI 阵营行动，若回合切到另一个 AI 控制阵营，也继续行动一次。

### 6.3 ZoneCommanderAgent 如何做决策

`TheaterCommanderPool` 会对当前 faction 的每个有 `frontSegments` 的 `FrontZone` 生成 directive。

每个 zone：

```text
visibleEnemyStrengthByRegion
friendlyFrontStrength
mobileFriendlyStrength
artillerySupportStrength
friendlyDepthStrength
pressure / supplyWarningCount
hasContestedForwardPresence
hasRecentStaticDefense
  -> BinaryTacticClassifier.classify
```

`BinaryTacticClassifier`：

```text
ratio = friendlyStrength / visibleEnemyStrength
如果 visibleEnemyStrength == 0，则 ratio = friendlyStrength
styleBoost:
  aggressive +0.15
  balanced 0
  cautious -0.15

shouldAttack =
  adjustedRatio >= attackThreshold(默认 1.2)
  或 hasContestedForwardPresence
  或 hasStaticDefense
```

分类结果：

- offense：
  - `blitzkrieg` / 疾骑突进：机动兵力占比高且 adjustedRatio >= 1.65。
  - `spearhead` / 突骑破阵：机动兵力可用，adjustedRatio >= 1.35，且有可见敌 region；用于定点矛头。
  - `breakthrough` / 破阵：adjustedRatio >= 1.35，向弱点突破。
  - `fireCoverage` / 弓弩压制：弓弩、投石或其他远程支援可用但优势不足，先火力覆盖。
  - `feint` / 佯动：优势不足但需要牵制时少量佯攻。
  - `guerrillaWarfare` / 袭扰截粮：机动兵力可用、敌 region 多、优势有限时袭扰纵深。
  - `standardAttack` / 正攻：普通进攻 fallback。
- defense：
  - `lastStand` / 死守：极端劣势、无纵深预备队且压力高时死守。
  - `defenseInDepth` / 守关层防：有纵深预备队且压力/劣势明显时纵深防御。
  - `elasticDefense` / 诱敌退守：压力、补给警告或劣势时弹性防御。
  - `holdPosition` / 固守：普通防御 fallback。

`TacticConditionChecker` 不再恒放行：疾骑突进/袭扰截粮要求机动单位，弓弩压制要求远程支援单位，佯攻要求前线单位，纵深防御要求 depth 预备队；不满足条件会降级为 `holdPosition`。

进攻 directive：

```text
ZoneDirective(
  zoneId,
  attack: AttackParameters(
    targetTheaterId,
    weightedRegions,
    intensity,
    focusRegionId,
    supportRegionIds,
    convergenceRegionId,
    coordinatedZoneIds,
    maxCommittedUnits,
    exploitDepth
  ),
  category: .offense,
  tactic: blitzkrieg / spearhead / breakthrough / pincerMovement / fireCoverage / feint / guerrillaWarfare / standardAttack,
  commandTarget: .region(focusRegionId) 或 .theater(target)
)
```

定点突破目标选择：

```text
priorityRegions =
  focusRegionId
  + commandTarget.region
  + convergenceRegionId
  + weightedRegions
  + supportRegionIds

若 tactic weakPointFocus:
  对候选 region 评分：
    enemyStrength 越低越优先
    terrain.movementCost 越低越优先
    region 内有 road 越优先
    city victoryPoints + supplyValue + factories + infrastructure 越高越优先
  最优 region 放到候选首位
```

钳形攻势数据层：

```text
pincerMovement 使用 convergenceRegionId + coordinatedZoneIds
每个 zone 仍各自编译成一条 ZoneDirective
执行器只推进本 zone 成功移动的具体 hex
会师/包围效果仍交给补给、前线、动态战区同步派生
```

防御 directive：

```text
ZoneDirective(
  zoneId,
  defense: DefenseParameters(
    targetReserves,
    stance,
    fallbackRegionIds,
    counterattackRegionIds,
    strongpointRegionIds,
    maxFrontCommitment
  ),
  category: .defense,
  tactic: holdPosition / elasticDefense / defenseInDepth / lastStand,
  commandTarget: .theater(self)
)
```

`AttackIntensity` 仍是参数字段；v0.7/v1.0 的真实分流主要由 `tactic` 决定。v1.0 已把 `.infiltration` 解释为默认低投入上限，但执行器不绕过 `RuleEngine` 给强度加直接伤害。

### 6.4 WarCommandExecutor 如何翻译指令

入口：

```swift
func execute(_ directive: ZoneDirective, in state: GameState) -> WarCommandExecutionResult
```

它不需要 `ZoneCommanderAgent` 实例，不需要 issuer。手写合法 `ZoneDirective` 可以直接执行，这是 v0.4 玩家命令 UI / 聊天命令要复用的后端能力。

执行路由：

```text
如果 directive.tactic 存在:
  standardAttack / blitzkrieg / spearhead / breakthrough / pincerMovement / fireCoverage / feint / guerrillaWarfare
    -> executeAttack(tactic)
  holdPosition / elasticDefense / defenseInDepth / lastStand
    -> executeDefense(tactic)
否则按 parameters:
  attack -> executeAttack
  defend -> executeDefense
```

防御翻译：

```text
zone 必须存在且有 frontSegments
lastStand:
  不保留 depth，全力 holdLine
elasticDefense:
  stance 强制 flexible，前线单位优先 allowRetreat
defenseInDepth:
  前线单位 allowRetreat
  保留 targetReserves 个 depth 预备队
  其余 depth 机动单位优先反击可见敌军，否则向 fallback/strongpoint region 移动
普通防御:
  unitIds = unitsFront + 部分 unitsDepth（保留 targetReserves）
对每个可行动单位:
  找 lightestFrontRegion
  如果单位已在该 region:
    holdLine -> .hold
    flexible -> .allowRetreat
  否则如果能找到 tacticalDestination:
    .move
  否则:
    hold / allowRetreat
  run(command, fallback: hold)
```

进攻翻译：

```text
zone 必须存在
targetZoneId = AttackParameters.targetTheaterId.rawValue
segments = 指向 targetZone 的 frontSegments，若为空则用全部 frontSegments

按 tactic 得到 AttackTacticProfile:
  blitzkrieg / spearhead:
    includeDepthUnits = true
    mobileOnlyWhenAvailable = true
    weakPointFocus = true
    holdNonCommittedFront = true
  breakthrough:
    includeDepthUnits = true
    weakPointFocus = true
  pincerMovement:
    includeDepthUnits = true
    mobileOnlyWhenAvailable = true
    convergenceRegionId 可作为深目标
  fireCoverage:
    artilleryFirst = true
    attackOnly = true；没有射程目标则 hold，不主动推进
  feint:
    只投入 maxCommittedUnits 或默认约 1/3 前线单位
  guerrillaWarfare:
    mobileOnlyWhenAvailable = true
    allowDeepTarget = true
    默认只投入约半数前线+纵深单位

attackingUnitIds =
  unitsFront
  + profile.includeDepthUnits ? unitsDepth : unitsFront 为空时 fallback unitsDepth
  -> 过滤可行动单位
  -> 需要时优先机动单位
  -> 按 artillery / mobile / attack / movement / strength 排序
  -> 应用 maxCommittedUnits

对每个可行动单位:
  targetEnemyRegion =
    focus / commandTarget.region / convergence / weighted / support 中仍相邻或允许深目标的 region
    或 front segment 相邻敌 region
    weakPointFocus 时用敌军强度、地形、道路、战略价值重排
  如果射程内有 visible enemy division:
    .attack
  否则如果 fireCoverage:
    .hold
  否则如果能找到 tacticalDestination:
    .move
  否则:
    .hold
  run(command, fallback: hold)
```

`run` 包装层会：

- 先记录 acting division 的 logical source zone。
- 调 `RuleEngine.execute(command, in: state)`。
- 如果被拒绝，写日志；如果原命令非法但 fallback hold 合法，则执行 fallback。
- 成功后做防御性同步：
  - 计算 affected region。
  - 尝试 `applyDirectiveOccupation`（通常普通 `CommandExecutor` 已处理过）。
  - 尝试 `applyStrategicAdvance`（确保 directive move 也推进 dynamic theater）。
  - `StrategicStateSynchronizer.synchronizeAfterOccupationChange`。
  - 记录 region owner change / front change event。

TurnManager 外层会为每条 directive 生成 `WarDirectiveRecord`：

```text
issuerId
turn
faction
zoneId
directiveType
targetRegionIds
commandResults
diagnostics
category
tactic
commanderAgentId
commandTarget
```

直接调用 `WarCommandExecutor.execute` 不会自动写 `WarDirectiveRecord`；记录职责在 `TurnManager.runDirectiveTurn` 外层。

---

## 7. UI / 地图显示流程

### 7.1 BoardScene

源码：`WWIIHexV0/SpriteKit/BoardScene.swift`

绘制顺序：

```text
drawTiles
drawLayerOverlay
drawRegionOverlays（仅 hex layer）
drawRoads
drawRivers
drawUnits（frontLine layer 隐藏单位）
```

点击：

```text
touchesEnded
  -> layout.pixelToHex(point)
  -> state.map.contains(coord)
  -> onHexTapped(coord)
```

平移：

- 触摸移动 camera。
- `clampCamera` 限制在地图边界附近。

### 7.2 MapDisplayAdapter

源码：`WWIIHexV0/SpriteKit/MapDisplayAdapter.swift`

职责：

- hex -> region 查询。
- 视野判断。
- 单位显示位置/堆叠。
- Region inspector state。
- Unit inspector strategic state。

Inspector 中关键字段：

```text
selectedHexController
selectedHexDynamicTheaterId
selectedHexFrontZoneId
theaterId = dominantDynamicTheaterId(region)
frontZoneId = dominantDynamicFrontZoneId(region)
frontPressure
friendlyDivisions
visibleEnemyDivisions
```

单位 strategic state：

```text
coord
regionId
dynamicTheaterId
frontLineIds
frontZoneId
deploymentRole
```

### 7.3 MapDisplayLayer

源码：`WWIIHexV0/Core/MapDisplayLayer.swift`、`WWIIHexV0/SpriteKit/MapLayerOverlayCalculator.swift`、`WWIIHexV0/SpriteKit/MapLayerOverlayNode.swift`

当前 layer：

```text
hex
province
initialTheater
dynamicTheater
frontLine
deployment
```

bucket 来源：

| Layer | 数据来源 |
|---|---|
| `hex` | 每个 hex 自己 |
| `province` | `map.region(for: hex)` |
| `initialTheater` | `theaterState.initialSnapshot?.regionToTheater[regionId]` |
| `dynamicTheater` | `theaterState.dynamicTheaterId(for: hex, map:)` |
| `frontLine` | `frontLineState.regionStates[regionId].frontLines` |
| `deployment` | 该 hex 上单位的 `WarDeploymentManager.deploymentRole` |

前线 overlay 的线段来源：

```text
frontLineSegments()
  -> 遍历 FrontLine.segments
  -> friendlyBoundaryHexes(
       friendlyRegionId: segment.regionA,
       enemyRegionId: segment.regionB,
       friendlyTheaterId: frontLine.theaterId
     )
  -> 只取 friendly region 内、且 dynamicTheaterId == friendly theater 的 hex
  -> 这些 hex 必须邻接 enemy region 中另一个 dynamic theater 的 hex
  -> 用这些 friendly hex center 画线
```

这意味着前线视觉画在我方动态战区侧，不画敌我中间共用边，也不画初始 theater 边界。

`frontLineChains()` 会把相邻 hex 点串成拓扑链。不同 segment 起点有分隔符，多敌 theater 接触会加 dashed overlay。

---

## 8. 关键链路示例

### 8.1 玩家移动占领一个敌控空 hex

```text
玩家点击己方单位
  -> AppContainer.selectDivision
  -> MovementRules 生成 movementHighlights

玩家点击敌控空 hex
  -> AppContainer.submit(.move)
  -> RuleEngine.validate(move)
  -> CommandExecutor.executeMove
     - division.coord = destination
     - tile.controller = division.faction
     - TheaterSystem.expandDynamicTheater 只推进 destination hex
     - WarDeploymentManager.advanceHex 只推进 destination hex 的 FrontZone
     - StrategicStateSynchronizer
       - RegionOccupationRules 聚合 region controller
       - TheaterSystem.updateTheaters
       - FrontLineManager.update dirty region
       - WarDeploymentManager.update dirty region
  -> AppContainer.bootstrapIfNeeded
  -> UI 刷新 dynamic theater / front / deployment overlay
  -> 如果现在轮到 AI，则 runAIIfNeeded
```

不得发生：

- 不得把 destination 所在整个 region 的 `regionToTheater` 改成进攻方。
- 不得绕过 `OccupationRules.canOccupy`。
- 不得只改 region controller 而不改 hex controller。

### 8.2 AI 进攻一个前线 zone

```text
用户点下一回合 / AI faction active
  -> AppContainer.runAIIfNeeded
  -> StrategicStateBootstrapper.refreshRuntimeState
  -> TurnManager.runAITurn(.zoneDirective)
  -> TheaterCommanderPool 选出该 faction 有 frontSegments 的 FrontZone
  -> ZoneCommanderAgent 计算兵力比/可见敌军/前沿存在
  -> 生成 standardAttack ZoneDirective
  -> WarCommandExecutor.execute
     - 找 zone.unitsFront
     - 选 targetEnemyRegion
     - 能打则 attack，不能打则 move，不能 move 则 hold
     - 每个 command 都走 RuleEngine
     - 同步占领/动态战区/前线/部署
  -> TurnManager 写 WarDirectiveRecord
  -> RuleEngine.execute(.endTurn)
  -> AppContainer 写 lastAgentDecisionRecord / lastWarDirectiveRecords
```

AI 看到的前线单位池来自 `WarDeploymentState`。如果某单位没有进入 `unitsFront` / `unitsDepth`，该 zone 的 AI 就不会调度它。

### 8.3 地图编辑器改默认地图后进入游戏

```text
MapEditorGameResourceBridge.loadDefaultDocument
  -> 读现有 scenario + region JSON
  -> 用户编辑 hex / region / theater / unit
  -> overwriteDefaultGameResources
     - MapEditorExporter.export
       - 校验所有 hex 有 region
       - 从 hex 邻接推导 region neighbors / edges
       - 写 scenario JSON
       - 写 region JSON
     - 覆盖 WWIIHexV0/Data 默认资源

重新运行游戏 app
  -> DataLoader DEBUG 优先读源码 JSON
  -> loadGameState
  -> map / regions / theater initialSnapshot / front / deploy 全部重建
```

注意：已经启动的旧 simulator app 不会自动重新加载默认 JSON。

---

## 9. 调试断点与排查顺序

遇到“AI 不动、前线不对、地图不一致、占领不同步、拒绝率异常”时，按这条链查，不要直接改大块逻辑：

```text
1. 数据加载
   - DataLoader 是否读的是源码 JSON 还是旧 bundle？
   - ScenarioDefinition tiles / initialUnits 是否正确？
   - RegionDataSet.hexToRegion / regions[].theaterId 是否正确？
   - map.validateRegionGraph() 是否为空？

2. Hex 层
   - Division.coord 是否真的变化？
   - HexTile.controller 是否真的变化？
   - 目标 hex 是否被其他单位占据？
   - OccupationRules.canOccupy 是否允许？

3. Region 层
   - state.map.region(for: hex) 是否正确？
   - RegionOccupationRules.aggregateControl 后 region.controller 是否改变？
   - 是否出现权重并列导致 controller 不变？

4. Theater 层
   - initialSnapshot.regionToTheater 是否保持不变？
   - regionToTheater 是否被错误当成动态推进层？
   - hexToTheater[destination] 是否只改了目标 hex？
   - dynamicTheaterId(for:) 是否 fallback 到 regionToTheater 造成误读？

5. Front 层
   - FrontLineManager 是否扫描到真实相邻 hex？
   - fixture 是否只写了 Region.neighbors 但没有真实 hex 邻接？
   - split region 是否需要允许 regionA == regionB？
   - frontLineState.diagnostics.updatedRegionIds 是否包含目标 region？

6. Deploy 层
   - hexToFrontZone[destination] 是否更新？
   - regionToFrontZone 是否只是 dominant/fallback？
   - 单位为什么是 front/depth/garrison？
   - zone.unitsFront 是否包含应该行动的单位？

7. Directive 层
   - TheaterCommanderPool 是否为该 faction 生成 directive？
   - ZoneCommanderAgent 是否因为 zone.frontSegments 为空而返回 nil？
   - visibleEnemyStrength / friendlyFrontStrength 是否合理？
   - tactic/category 是否被记录？

8. Executor / RuleEngine 层
   - WarCommandExecutor.generatedCommands 是否为空？
   - CommandValidator 拒绝原因是什么？
   - fallback hold 是否执行？
   - WarDirectiveRecord.diagnostics 是否记录了拒绝？

9. UI 层
   - 当前 MapDisplayLayer 读的是 initial 还是 dynamic？
   - frontLine overlay 是否画在 friendlyBoundaryHexes？
   - observerMode 是否导致玩家不能选中行动单位？
```

---

## 10. 当前已知边界

- 真 LLM 尚未接入；当前只用 `SimulatedMarshalLLMClient` 模拟纯 JSON 输出，decoder 仍兼容 fenced JSON 和纯 JSON。
- 默认 AI 上游已是 `MarshalAgent -> TheaterDirectiveEnvelope -> TheaterDirectiveDecoder -> TheaterDirectiveCompiler -> CourtAgent / RulerAgent`，下游执行必须是 `ZoneDirective -> WarCommandExecutor -> RuleEngine`。
- 元帅层不能直接输出底层 `Command`，不能直接修改地图、单位、hex controller 或动态战区权威。
- 朝堂层塑形和审计 `DirectiveEnvelope`；v3.7-preflight.9 已有玩家侧议和/纳降命令，v3.7-preflight.10 已有玩家侧州郡经营命令，v3.7-preflight.11 已有 AI 太守主动经营，v3.7-preflight.12 已有 AI 使者主动外交，v3.7-preflight.13 已有最小归附事件记录链，v3.7-preflight.14 已有归附空势力轮转收口，v3.7-preflight.15 已有归附实体盘点和事件 target 判定收口，v3.7-preflight.16 已有最小归附实体交接命令，v3.7-preflight.17 已有归附交接审计记录，v3.7-preflight.18 已有 AI 归附实体交接，v3.7-preflight.19 已有归附善后压力记录，v3.7-preflight.101 已有归附善后治安/顺从压力落地，v3.7-preflight.102 已有归附善后贡赋效率落地，v3.7-preflight.20 已有 AI 善后太守优先治理，v3.7-preflight.21 已有善后处置审计记录，v3.7-preflight.22 已有善后处置进度摘要，v3.7-preflight.23 已有 AI 善后未处置优先治理，v3.7-preflight.24 已有善后完成状态提示，v3.7-preflight.25 已有发布检查门禁拆分，v3.7-preflight.26 已有 AI 太守跳过诊断，v3.7-preflight.27 已有 AI 使者/归附交接跳过诊断，v3.7-preflight.28 已有 MapEditor 默认隋唐资源桥，v3.7-preflight.29 已有 MapEditor 地点字段化编辑，v3.7-preflight.30 已有发布候选静态门禁快照，v3.7-preflight.31 已有玩家可见旧英文兜底收口，v3.7-preflight.32 已有玩家可见调试文案第一批收口，v3.7-preflight.33 已有玩家可见外交/朝堂文案收口，v3.7-preflight.34 已有玩家可见 AI 诊断文案收口，v3.7-preflight.35 已有战报与总管预览文案收口，但借兵、完整忠诚/叛乱/俘虏/安置效果、更完整归附后续事件、水战/渡河/港口补给规则仍待后续。
- v3.5 战报、外交、州郡摘要是信息闭环基础；v3.7-preflight.9 / .10 已分别补上玩家外交和州郡经营的 `Command` / validator / executor 最小闭环。
- v3.6 只建立 SwiftUI 视觉基底、中文化收口和最小 SpriteKit 城池/关隘/粮仓/粮道/围城标识；v3.7-preflight.4 已补渡口/港口最小图标，v3.7-preflight.5 已补 AI 计划箭头，v3.7-preflight.6 已补普通地图层前线墨线，v3.7-preflight.8 已把这些标识的资产边界写入发布前检查；这些地图叠加层和真实运行时布局仍未重测。
- 当前 main 直推流程中，若工作树已有未提交改动或并发子 Agent 产物，合并前需要按 `AGENTS.md` 单独审查文件归属、public API、schema 和文档口径冲突。
- `AttackIntensity.infiltration` 已在 `WarCommandExecutor` 中解释为默认低投入上限；`.limitedCounter` 和 `.allOut` 仍主要依赖 tactic profile 与显式 `maxCommittedUnits`。
- `TacticConditionChecker` 当前总是允许现有战术。
- 战区互助接口 `requestSupport` / `getAvailableForces` / `notifyThreat` 有模型但没有主流程调用方。
- 攻击不会自动占领目标 hex，只有移动会占领。
- Legacy Agent D 管线仍保留，不应删除，也不应默认接回主战争 AI。
- `RegionCommand` / AgentOrder v2 仍可桥接到 hex command，但当前默认战争 AI 是 ZoneDirective。
- 地图编辑器的 theater assignment 是初始战区划分，不是运行时动态战区脚本。
- 历史回退的 Cabinet/Minister/StrategicDirective 管线仍不得恢复；v0.5 当前实现没有把内阁或部长塞进 `GameState`。

---

## 11. 轻量检查入口与历史回归参考

检查规范以 `md/test/test.md` 为准。当前默认不跑 Xcode / XCTest / 模拟器 / 性能类验证，只做轻量语法、格式和配置检查。

历史上这些回归曾用于守住核心语义，但现在只作只读参考，不作为每轮默认执行项：

- Probe：`WWIIHexV0Probes`
  - 数据启动、region graph、theater、frontline、deployment。
  - v0.358 动态 hex 战区推进。
  - v0.36 tactic/directive。
  - v0.37 手写 directive issuer-agnostic 执行。
- Dynamic Theater Regression：`WWIIHexV0Tests/Stage0355DynamicTheaterTests`
  - 守住 `regionToTheater` 不动态推进、`hexToTheater` 单 hex 推进、split region front、deployment split。
- MapEditor：`WWIIHexV0Tests/MapEditorOutputTests`
  - 守住编辑器输出与游戏加载一致、默认资源一致、视角一致、开局不自动 AI。
- Stage Regression：
  - Theater / FrontLine / WarDeployment / CommandSystem / Agent / Observer / LayeredMap。

默认允许的检查方向：

- 文档改动：尾随空白、旧测试口径残留、人工阅读一致性。
- JSON 改动：对改动文件运行 `jq empty`。
- Xcode project / scheme 改动：运行 `plutil -lint` 或 `xmllint --noout`。
- 少量 Swift 改动：仅在不会触发全项目构建时，对直接改动文件做单文件语法检查。

多分支或多子 Agent 并发后，即使不跑测试，也必须检查文件重叠、public API 分叉、数据 schema 分叉、Xcode project 冲突和文档口径冲突。未完成冲突检查前，不得声称候选分支可合并。

---

## 12. v1.0 UI / AI / Playtest 分支收口

v1.0 分支名：`v1.0-ui-ai-playtest`。

该分支不改变战术权威和命令权威，只让当前主游戏更适合人工初版试玩和后续调参：

```text
GameState / WarDirectiveRecord / EventLog
  -> RootGameView
  -> HUD + Info tabs
  -> AgentPanelView 展示净化后的决策摘要 / command results / zone directives
  -> EventLogView 展示最近 60 条分类日志

BoardScene
  -> 缓存 unit display hex
  -> 排序绘制单位
  -> deployment 图层复用 WarDeploymentManager 计算 role

Marshal / ZoneDirective
  -> AttackParameters.intensity
  -> WarCommandExecutor.attackTacticProfile
  -> infiltration 低投入上限
  -> RuleEngine 仍是唯一执行权威
```

算法变化：

- AI 面板从只展示 `AgentDecisionRecord` 扩展为同时展示 `WarDirectiveRecord`，每条 directive 可看到 zone、attack/defend、tactic、命令成功/拒绝数量和目标 region；当前展示层会净化 context、command result 和 error 文案，不再展开 raw JSON。
- 日志面板用 `LogDisplayEntry` 保存 entry + category，避免 body 内对同一条日志重复分类。
- 单位绘制先缓存 `unitDisplayHex` 再排序，避免 comparator 重复计算。
- `AttackIntensity.infiltration` 在无显式 `maxCommittedUnits` 时默认只投入约半数前线/纵深候选单位，避免渗透/袭扰全线压上。

试玩观察重点：

- UI：HUD、Info tabs、Economy、Diplomacy、AI panel 是否可读。
- 地图：hex/province/initial/dynamic/front/deploy 图层是否清晰。
- AI：净化摘要、zone directive、diagnostics 是否能解释 AI 回合。
- 规则：玩家和 AI 行动是否仍能追溯到 `CommandResultSummary` / `WarDirectiveRecord`。
- 性能体感：地图拖动、图层切换、日志面板滚动是否有明显卡顿。

当前限制：

- 未跑 Xcode / XCTest / 模拟器 / 性能测试。
- 当前工作树含多版本未提交改动，v1.0 合并前必须重新审查 `project.pbxproj`、Swift 新文件引用、AI schema 和文档版本口径。

---

## 13. v0.4 将军养成、将军 UI 与玩家双轨命令

v0.4 分支名：`v0.4-generals-command-ui-final`。

该分支把 0.41-0.48 的将军与玩家命令链路收口到当前代码，仍保持命令权威不变：

```text
Data/generals.json
  -> DataLoader.loadGeneralRegistry
  -> GeneralRegistry / GeneralDispatcher
  -> FrontZone.generalAssignment
  -> AppContainer.selectedGeneral*
  -> GeneralCommandPanelView / GeneralProfileView

玩家微操单位
  -> AppContainer.submit(Command)
  -> RuleEngine
  -> PlayerCommandState.micromanagedDivisionIds
  -> WarCommandExecutor.execute(... excluding: lockedIds)

玩家宏观将军命令
  -> GeneralCommandPanelView 按钮
  -> AppContainer 组装 ZoneDirective
  -> WarCommandExecutor
  -> RuleEngine
  -> WarDirectiveRecord + PlayerPlannedOperation
  -> BoardScene 计划线 / 金色微操单位圈
```

核心算法：

- 将军数据：`GeneralData` 从 `generals.json` 读取，包含阵营、军衔、倾向、技能、头像占位、履历、偏好 theater/region、忠诚和满意度基线。
- 初始分配：`RegionNodeDefinition.assignedGeneralId` 可由地图 JSON / MapEditor 写入。`DataLoader` 在生成 `WarDeploymentState` 后收集 region 种子，调用 `GeneralDispatcher.assignGenerals`。
- 指派规则：
  1. 如果 FrontZone 已有合法同阵营 `generalAssignment`，保留该将军，只刷新 `assignedDivisionIds`。
  2. 否则优先使用该 zone 下 region 的 `assignedGeneralId`。
  3. 再按将军 `preferredTheaterIds` / `preferredRegionIds` 匹配。
  4. 最后从同阵营未占用将军池取第一名；没有可用将军时安全空岗。
- HQ 逻辑：不生成占格子的 HQ 单位。`GeneralAssignment.hqRegionId` 指向战区内友方城市或最大 region，`GeneralDispatcher.isHQUnderAttack` 通过 region controller 判断 HQ 是否被夺。
- 将军养成初步：`GeneralAssignment` 保存 `loyalty`、`satisfaction`、`interventionCount`。玩家直接微操某个将军辖下单位时，记录干预次数并轻微降低满意度。
- 微操锁：玩家在己方 phase 对具体师执行 move/attack/hold/resupply/allowRetreat 后，该师 id 写入 `PlayerCommandState.micromanagedDivisionIds`。本回合玩家再下达战区宏观命令时，`WarCommandExecutor.execute(... excluding:)` 会跳过这些师，避免同一回合被将军指令覆盖。`endTurn` 或 active faction / turn 改变时清空锁。
- 半自动指令：`GeneralCommandPanelView` 的 `Hold Line` 生成 defense `ZoneDirective`，`Attack Region` 根据当前选中敌方 region 和相邻玩家 FrontZone 生成 attack `ZoneDirective`，直接复用 `WarCommandExecutor -> RuleEngine`，不通过 `TurnManager.runDirectiveTurn`，因此不会自动结束玩家回合。
- 记录与反馈：玩家宏观命令写入 `WarDirectiveRecord` 和 `PlayerPlannedOperation`。`BoardScene` 只读 `PlayerCommandState.plannedOperations`，画源 region 到目标 region 的箭头；防御命令画源点圆环。玩家微操锁定单位在 `UnitNode` 上显示金色底圈。
- UI：`RootGameView` 新增 `General` tab，Unit tab 也嵌入 `GeneralCommandPanelView`。`GeneralProfileView` 用 sheet 展示将军身份、履历、技能、忠诚/满意度、干预次数、HQ 状态和辖下部队。

边界：

- v0.4 不让将军或 UI 直接修改 `GameState` 战术权威；所有行动仍要走 `Command` / `ZoneDirective -> WarCommandExecutor -> RuleEngine`。
- v0.4 没有实现真正抗命、政变、完整 RPG 成长树或真实 LLM 聊天解析；当前是忠诚/满意度和干预次数的可视化与数据底座。
- v0.4 没有做自由手绘前线。采用 region 锚点法：选择战区/目标 region 后自动画箭头，符合 0.44 文档中的移动端妥协方案。
- 历史备注：该 v0.4 记录曾提示当时工作树混有 v0.5、v0.7、v0.9、v1.x 外部改动。当前协作以 `main` 直推和本轮 `git status` / diff 为准；合并或推送前仍必须重新做文件/API/schema/project 冲突审查。

---

## 14. 协作云端闭环

本节是流程制度，不代表业务功能升级。

默认协作链路：

```text
人工目标
  -> Agent A 写版本化提示词
  -> Agent B 基于最新 origin/main 在 main 上实现
  -> 本机轻量检查
  -> commit + push origin main
  -> GitHub Actions 运行静态检查和 Xcode build
  -> 上传未加密 CI 结果包
  -> Agent C 下载结果包并核对 manifest / JUnit / 日志
  -> 通过：更新 flow / update_log
  -> 失败：退回 Agent B 在 main 上追加修复 commit
```

关键规则：

- `main` 是默认唯一上传、提交、推送和云端验证分支。
- 本轮不引入 `smalldata_test`、`develop`、`codeb/...`、候选分支或 PR 合并制度。
- Agent B 本机只跑 `md/test/test.md` 允许的轻量检查；Xcode build 等重验证由 GitHub Actions 执行。
- `.github/workflows/ci-results.yml` 负责生成 `ci-artifact-manifest.json`、`ci-failure-summary.md`、`xcodebuild.log`、`junit.xml` 和可用时的 `.xcresult`。
- Agent C 必须用 `gh auth login` 后下载 `origin/main` 最新 commit 对应 artifact，核对 `branch`、`commitSha`、`runId`、`runAttempt`；不能验收旧 run 或只验收 Agent B 文字说明。
- 云端失败时不默认回滚，按退回清单在 `main` 追加修复 commit 后重新 push。
