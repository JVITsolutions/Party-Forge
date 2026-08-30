extends SceneTree

const SCREENSHOT_ROOT := "res://docs/validation/screenshots/living-forge-combat-loop"
const MANIFEST_NAME := "manifest.json"
const MANIFEST_SCHEMA_VERSION := 2
const VERIFICATION_PATH := "docs/verification/2026-08-29-living-forge-hud-level-up-results.md"
const RUNNER_PATH := "tests/integration/living_forge_combat_loop_visual_evidence_runner.gd"
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const LEVEL_UP_SCENE := preload("res://scenes/ui/level_up_panel.tscn")
const EXTRACTION_SCENE := preload("res://scenes/ui/run_result/terminal_extraction_panel.tscn")
const RESULT_SCENE := preload("res://scenes/ui/run_result_panel.tscn")
const PAUSE_SCENE := preload("res://scenes/ui/run_pause_menu.tscn")
const LOBBY_SCENE := preload("res://scenes/ui/run_setup/run_setup_lobby_panel.tscn")
const ARENA_SCENE := preload("res://scenes/arena/arena.tscn")

const CAPTURES: Array[String] = [
	"hud-no-alert-rich-1.png",
	"hud-rich-6-three-alerts.png",
	"hud-compact-7.png",
	"hud-compact-20-overflow.png",
	"hud-compact-24-final-member-focus.png",
	"hud-alert-tray-focus.png",
	"hud-alert-inspect-return.png",
	"hud-alert-ledger-return.png",
	"level-up-direct-and-targeted.png",
	"level-up-recipient-24.png",
	"extraction-automatic-selected-lost.png",
	"result-victory-current-truth.png",
	"result-defeat-losses.png",
	"result-resolution-interrupted.png",
	"result-terminal-save-interrupted.png",
	"result-projection-interrupted.png",
	"result-automatic-overflow-recovery.png",
	"combat-loop-720p-text-150.png",
	"combat-loop-720p-ui-150-text-150.png",
	"combat-loop-720p-ui-80-text-150.png",
	"combat-loop-1440p.png",
	"combat-loop-ultrawide.png",
	"combat-loop-high-contrast.png",
	"combat-loop-reduced-motion.png",
	"combat-loop-ui-scale-150.png",
	"combat-loop-controller-focus.png",
	"combat-loop-mouse-hover.png",
	"result-pending-terminal-save.png",
	"result-pending-terminal-refresh.png",
	"result-pending-resolution.png",
	"result-pending-projection.png",
	"result-pending-protection.png",
	"result-pending-terminal-completion.png",
	"result-finalized-receipt-clear-error.png",
	"result-finalized-committed-refresh-retry-only.png",
	"result-terminal-refresh-interrupted.png",
	"pause-abandon-committed-refresh.png",
	"restart-lobby-valid-preselection.png",
	"restart-lobby-unresolved-selection.png",
	"hud-alert-720p-ui-150-text-150.png",
	"level-up-confirmation-safe-focus.png",
	"extraction-pending-focus.png",
	"extraction-detail-720p-ui-150-text-150.png",
	"result-expanded-detail-ui-150-text-150.png",
	"result-expanded-detail-ui-80-text-150.png",
]

const CAPTURE_STATES: Array[String] = [
	"one-member rich HUD with no alerts",
	"six-member rich HUD with three expanded alerts",
	"seven-member compact HUD threshold",
	"twenty-member compact HUD with alert overflow",
	"twenty-four-member compact HUD with final member focused",
	"complete alert tray with Close focused",
	"alert Inspect round trip with exact initiating focus restored",
	"alert Ledger round trip with exact initiating focus restored",
	"five level-up offers containing direct and targeted scopes",
	"twenty-four-member recipient picker with final recipient focused",
	"typed automatic selected and lost extraction truth",
	"finalized victory recap from current durable truth",
	"finalized defeat recap with truthful Lost row focused",
	"durable resolution interruption with Retry Resolution",
	"terminal save interruption with Retry Terminal Save",
	"accepted-resolution projection interruption with Retry Results",
	"automatic-only Recovery Overflow confirmation with safe Cancel",
	"720p HUD at text scale 150",
	"720p HUD at UI 150 and text 150",
	"720p HUD at UI 80 and text 150",
	"1440p production Arena combat composition",
	"ultrawide production Arena combat composition",
	"high-contrast production Arena HUD",
	"reduced-motion settled production Arena HUD",
	"HUD at UI scale 150",
	"simulated-controller HUD focus",
	"mouse-hover HUD state",
	"pending terminal-state save",
	"pending terminal recovery refresh",
	"pending durable run resolution",
	"pending result projection",
	"pending displaced-gear protection",
	"pending terminal completion",
	"finalized terminal action failed before receipt clear",
	"receipt already cleared and committed refresh retry only",
	"terminal recovery refresh interruption",
	"committed active-run Abandon refresh retry only",
	"valid restart intent preselects prior class",
	"unresolved restart intent requires explicit class selection",
	"720p alert HUD at UI 150 and text 150",
	"targeted level-up confirmation with safe Cancel focused",
	"pending extraction with item actions excluded and Show Auto focused",
	"720p extraction detail at UI 150 and text 150",
	"720p expanded result detail at UI 150 and text 150",
	"720p expanded result detail at UI 80 and text 150",
]

const CAPTURE_FOCUS_TARGETS: Array[String] = [
	"none", "none", "none", "none", "member:24",
	"alert_tray:close", "alert:inspect", "alert:ledger",
	"upgrade_card:1", "recipient:24", "extraction:visual-result-selected",
	"result:return_to_forge", "result:lost_row", "result:retry_resolution",
	"result:retry_terminal_save", "result:retry_projection", "confirmation:cancel",
	"hud:member", "hud:member", "member:24", "none", "hud:overflow",
	"hud:alert_inspect", "none", "hud:overflow", "hud:member", "hud:hover",
	"none", "none", "none", "none", "none", "none",
	"result:return_to_forge", "result:return_to_forge", "result:retry_terminal_refresh",
	"pause:retry_return_to_forge", "lobby:mage", "lobby:first_class",
	"hud:alert_inspect", "confirmation:cancel", "extraction:show_auto",
	"extraction_detail:close", "result:expanded_row", "result:expanded_row",
]

# Metadata is index-aligned with CAPTURES so each filename is declared exactly once.
const CAPTURE_METADATA: Array[Dictionary] = [
	{"surface":"hud","width":1920,"height":1080,"ui":100,"text":100,"contrast":false,"motion":false,"input":"none"},
	{"surface":"hud","width":1920,"height":1080,"ui":100,"text":100,"contrast":false,"motion":false,"input":"none"},
	{"surface":"hud","width":1920,"height":1080,"ui":100,"text":100,"contrast":false,"motion":false,"input":"none"},
	{"surface":"hud","width":1920,"height":1080,"ui":100,"text":100,"contrast":false,"motion":false,"input":"none"},
	{"surface":"hud","width":1920,"height":1080,"ui":100,"text":100,"contrast":false,"motion":false,"input":"keyboard"},
	{"surface":"hud-alert-tray","width":1920,"height":1080,"ui":100,"text":100,"contrast":false,"motion":false,"input":"keyboard"},
	{"surface":"hud-alert-tray","width":1920,"height":1080,"ui":100,"text":100,"contrast":false,"motion":false,"input":"keyboard"},
	{"surface":"hud-alert-tray","width":1920,"height":1080,"ui":100,"text":100,"contrast":false,"motion":false,"input":"simulated_controller"},
	{"surface":"level-up","width":1920,"height":1080,"ui":100,"text":100,"contrast":false,"motion":true,"input":"keyboard"},
	{"surface":"level-up-recipient","width":1920,"height":1080,"ui":100,"text":100,"contrast":false,"motion":true,"input":"keyboard"},
	{"surface":"extraction","width":1920,"height":1080,"ui":100,"text":100,"contrast":false,"motion":true,"input":"keyboard"},
	{"surface":"result","width":1920,"height":1080,"ui":100,"text":100,"contrast":false,"motion":false,"input":"keyboard"},
	{"surface":"result","width":1920,"height":1080,"ui":100,"text":100,"contrast":false,"motion":false,"input":"keyboard"},
	{"surface":"result","width":1920,"height":1080,"ui":100,"text":100,"contrast":false,"motion":false,"input":"keyboard"},
	{"surface":"result","width":1920,"height":1080,"ui":100,"text":100,"contrast":false,"motion":false,"input":"keyboard"},
	{"surface":"result","width":1920,"height":1080,"ui":100,"text":100,"contrast":false,"motion":false,"input":"keyboard"},
	{"surface":"result","width":1920,"height":1080,"ui":100,"text":100,"contrast":false,"motion":false,"input":"keyboard"},
	{"surface":"hud","width":1280,"height":720,"ui":100,"text":150,"contrast":false,"motion":false,"input":"keyboard"},
	{"surface":"hud","width":1280,"height":720,"ui":150,"text":150,"contrast":false,"motion":false,"input":"keyboard"},
	{"surface":"hud","width":1280,"height":720,"ui":80,"text":150,"contrast":false,"motion":false,"input":"keyboard"},
	{"surface":"hud","width":2560,"height":1440,"ui":100,"text":100,"contrast":false,"motion":false,"input":"none"},
	{"surface":"hud","width":3440,"height":1440,"ui":100,"text":100,"contrast":false,"motion":false,"input":"none"},
	{"surface":"hud","width":1920,"height":1080,"ui":100,"text":100,"contrast":true,"motion":false,"input":"keyboard"},
	{"surface":"hud","width":1920,"height":1080,"ui":100,"text":100,"contrast":false,"motion":true,"input":"keyboard"},
	{"surface":"hud","width":1920,"height":1080,"ui":150,"text":100,"contrast":false,"motion":false,"input":"keyboard"},
	{"surface":"hud","width":1920,"height":1080,"ui":100,"text":100,"contrast":false,"motion":false,"input":"simulated_controller"},
	{"surface":"hud","width":1920,"height":1080,"ui":100,"text":100,"contrast":false,"motion":false,"input":"mouse"},
	{"surface":"result","width":1920,"height":1080,"ui":100,"text":100,"contrast":false,"motion":false,"input":"none"},
	{"surface":"result","width":1920,"height":1080,"ui":100,"text":100,"contrast":false,"motion":false,"input":"none"},
	{"surface":"result","width":1920,"height":1080,"ui":100,"text":100,"contrast":false,"motion":false,"input":"none"},
	{"surface":"result","width":1920,"height":1080,"ui":100,"text":100,"contrast":false,"motion":false,"input":"none"},
	{"surface":"result","width":1920,"height":1080,"ui":100,"text":100,"contrast":false,"motion":false,"input":"none"},
	{"surface":"result","width":1920,"height":1080,"ui":100,"text":100,"contrast":false,"motion":false,"input":"none"},
	{"surface":"result","width":1920,"height":1080,"ui":100,"text":100,"contrast":false,"motion":false,"input":"keyboard"},
	{"surface":"result","width":1920,"height":1080,"ui":100,"text":100,"contrast":false,"motion":false,"input":"keyboard"},
	{"surface":"result","width":1920,"height":1080,"ui":100,"text":100,"contrast":false,"motion":false,"input":"keyboard"},
	{"surface":"pause","width":1920,"height":1080,"ui":100,"text":100,"contrast":false,"motion":false,"input":"keyboard"},
	{"surface":"restart-lobby","width":1920,"height":1080,"ui":100,"text":100,"contrast":false,"motion":false,"input":"keyboard"},
	{"surface":"restart-lobby","width":1920,"height":1080,"ui":100,"text":100,"contrast":false,"motion":false,"input":"keyboard"},
	{"surface":"hud","width":1280,"height":720,"ui":150,"text":150,"contrast":false,"motion":false,"input":"keyboard"},
	{"surface":"level-up-confirmation","width":1920,"height":1080,"ui":100,"text":100,"contrast":false,"motion":true,"input":"keyboard"},
	{"surface":"extraction","width":1920,"height":1080,"ui":100,"text":100,"contrast":false,"motion":true,"input":"keyboard"},
	{"surface":"extraction-detail","width":1280,"height":720,"ui":150,"text":150,"contrast":false,"motion":true,"input":"keyboard"},
	{"surface":"result-detail","width":1280,"height":720,"ui":150,"text":150,"contrast":false,"motion":false,"input":"keyboard"},
	{"surface":"result-detail","width":1280,"height":720,"ui":80,"text":150,"contrast":false,"motion":false,"input":"keyboard"},
]

const SOURCE_INPUT_PATHS: Array[String] = [
	RUNNER_PATH,
	"scenes/ui/hud.tscn", "scripts/ui/hud.gd", "scripts/ui/hud/combat_hud_view_model.gd", "scripts/ui/hud/combat_hud_responsive_layout.gd",
	"scripts/ui/hud/combat_alert_tray.gd", "scripts/ui/hud/combat_member_inspect_panel.gd",
	"scenes/ui/hud/combat_alert_tray.tscn", "scenes/ui/hud/combat_member_inspect_panel.tscn",
	"scenes/ui/living_forge/components/forge_party_member_card.tscn", "scripts/ui/living_forge/components/forge_party_member_card.gd",
	"scenes/ui/living_forge/components/forge_party_member_marker.tscn", "scripts/ui/living_forge/components/forge_party_member_marker.gd",
	"scenes/ui/living_forge/components/forge_alert_card.tscn", "scripts/ui/living_forge/components/forge_alert_card.gd",
	"scenes/ui/level_up_panel.tscn", "scripts/ui/level_up_panel.gd", "scenes/ui/upgrade_card.tscn", "scripts/ui/upgrade_card.gd",
	"scenes/ui/upgrade_recipient_picker.tscn", "scripts/ui/upgrade_recipient_picker.gd", "scenes/ui/upgrade_tooltip_panel.tscn", "scripts/ui/upgrade_tooltip_panel.gd",
	"scenes/ui/run_result/terminal_extraction_panel.tscn", "scripts/ui/run_result/terminal_extraction_panel.gd", "scripts/ui/run_result/terminal_extraction_projection.gd",
	"scenes/ui/living_forge/components/forge_extraction_item_card.tscn", "scripts/ui/living_forge/components/forge_extraction_item_card.gd", "scenes/ui/storage/item_tooltip_panel.tscn", "scripts/ui/storage/item_tooltip_panel.gd",
	"scenes/ui/run_result_panel.tscn", "scripts/ui/run_result_panel.gd", "scripts/ui/run_result/run_result_view_model.gd", "scripts/ui/run_result/run_result_projection.gd",
	"scripts/ui/run_result/run_recap_entry_projection.gd", "scripts/ui/run_result/run_recap_section_projection.gd", "scripts/ui/run_result/run_result_party_member_projection.gd",
	"scenes/ui/run_pause_menu.tscn", "scripts/ui/run_pause_menu.gd",
	"scenes/ui/run_setup/run_setup_lobby_panel.tscn", "scripts/ui/class_selection_panel.gd", "scripts/ui/run_setup/run_setup_lobby_view_model.gd", "scripts/ui/run_setup/run_setup_restart_intent.gd",
	"scripts/equipment/loadout_compatibility_service.gd", "scripts/equipment/loadout_compatibility_projection.gd", "data/equipment/core_equipment_catalog.tres", "data/items/core_item_foundation_catalog.tres",
	"scenes/arena/arena.tscn",
	"scripts/ui/living_forge/living_forge_theme_catalog.gd", "scripts/ui/living_forge/living_forge_tokens.gd",
	"data/ui/living_forge/living_forge_theme.tres", "data/ui/living_forge/living_forge_high_contrast_theme.tres",
]

class EvidenceRun:
	extends Node
	var seconds := 125.0
	func elapsed_time() -> float: return seconds

class ResultEvidenceFixture:
	extends RefCounted
	var snapshot: RunTerminalSnapshot
	var profile: ProfileState
	var resolution: RunResolutionResult

class HudEvidenceFixture:
	extends RefCounted
	var party: PartyManager
	var context: PlayerRunContext
	var experience: ExperienceSystem
	var actors: Array[Node3D] = []
	var health_by_member: Dictionary = {}
	var run: EvidenceRun
	var settings: PartyForgeSettings

var _failures: Array[String] = []
var _entries: Array[Dictionary] = []
var _captured: Dictionary = {}
var _started_unix := 0
var _sequence := 44000


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_started_unix = int(Time.get_unix_time_from_system())
	_assert(CAPTURES.size() == 45, "capture contract declares exactly 45 files")
	_assert(CAPTURE_METADATA.size() == CAPTURES.size(), "every capture has exact viewport/settings metadata")
	_assert(CAPTURE_STATES.size() == CAPTURES.size() and CAPTURE_FOCUS_TARGETS.size() == CAPTURES.size(), "every capture has exact state and focus metadata")
	_assert(_unique_strings(CAPTURES).size() == CAPTURES.size(), "capture names are globally unique")
	if "--validate-only" in OS.get_cmdline_user_args():
		_validate_existing_evidence()
		_finish()
		return
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i.ZERO
	_assert(RenderingServer.get_current_rendering_method() == "gl_compatibility", "capture uses OpenGL Compatibility")
	_assert(_capture_source_is_clean(), "capture source is the exact clean committed harness head except generated evidence output")
	if not _failures.is_empty():
		_finish()
		return
	var absolute_root := ProjectSettings.globalize_path(SCREENSHOT_ROOT)
	_assert(DirAccess.make_dir_recursive_absolute(absolute_root) == OK, "evidence directory is available")
	_assert_no_extra_pngs(false)
	if not _failures.is_empty():
		_finish()
		return
	print("LIVING_FORGE_COMBAT_LOOP_VISUAL_CAPTURE_START files=%d" % CAPTURES.size())
	await _capture_all()
	_write_manifest()
	_validate_existing_evidence(true)
	_finish()


func _capture_all() -> void:
	await _capture_hud(0, 1, 0)
	await _capture_hud(1, 6, 3)
	await _capture_hud(2, 7, 0)
	await _capture_hud(3, 20, 6)
	await _capture_hud(4, 24, 0, &"final_member")
	await _capture_hud(5, 12, 6, &"tray")
	await _capture_hud_modal_return(6, false)
	await _capture_hud_modal_return(7, true)
	await _capture_level_up(8, &"offers")
	await _capture_level_up(9, &"recipient")
	await _capture_extraction(10, &"selection")
	await _capture_result_state(11, &"victory")
	await _capture_result_state(12, &"defeat")
	await _capture_result_state(13, &"resolution")
	await _capture_result_state(14, &"save")
	await _capture_result_state(15, &"projection")
	await _capture_result_state(16, &"automatic")
	await _capture_hud(17, 12, 4, &"member_focus")
	await _capture_hud(18, 20, 6, &"member_focus")
	await _capture_hud(19, 24, 5, &"final_member")
	await _capture_hud(20, 6, 2)
	await _capture_hud(21, 20, 6, &"overflow")
	await _capture_hud(22, 6, 3, &"alert_focus")
	await _capture_hud(23, 7, 2)
	await _capture_hud(24, 12, 4, &"overflow")
	await _capture_hud(25, 7, 2, &"controller")
	await _capture_hud(26, 6, 1, &"mouse")
	for index: int in range(27, 33):
		await _capture_result_state(index, &"pending", index - 27)
	await _capture_result_state(33, &"receipt_error")
	await _capture_result_state(34, &"committed_refresh")
	await _capture_result_state(35, &"refresh")
	await _capture_pause_abandon(36)
	await _capture_restart_lobby(37, true)
	await _capture_restart_lobby(38, false)
	await _capture_hud(39, 6, 4, &"alert_focus")
	await _capture_level_up(40, &"confirmation")
	await _capture_extraction(41, &"pending")
	await _capture_extraction(42, &"detail")
	await _capture_result_state(43, &"expanded")
	await _capture_result_state(44, &"expanded")


func _capture_hud(index: int, count: int, alert_count: int, mode: StringName = &"") -> void:
	paused = false
	var metadata := CAPTURE_METADATA[index]
	_apply_window(metadata)
	var backdrop := _battlefield_backdrop()
	var fixture := _hud_fixture(count, alert_count, _settings_for(metadata))
	var hud := HUD_SCENE.instantiate() as HUD
	root.add_child(hud)
	_configure_active_run_hud(hud, fixture)
	await _frames(6)
	_assert(hud.current_projection != null and hud.current_projection.members.size() == count and hud.current_projection.all_alerts.size() == alert_count, "%s renders exact authoritative party/alert counts" % CAPTURES[index])
	_assert((hud.get_node("Margin/CombatStatus/PartyRegion/RichRoster") as Control).visible == (count <= 6) and (hud.get_node("Margin/CombatStatus/PartyRegion/CompactRoster") as Control).visible == (count >= 7), "%s renders the exact rich/compact threshold" % CAPTURES[index])
	_assert((hud.get_node("Margin/CombatStatus/AlertRegion/Overflow") as Button).visible == (alert_count > 3), "%s renders exact overflow availability" % CAPTURES[index])
	var controls := _hud_member_controls(hud)
	if mode == &"final_member":
		_assert(bool(hud.call(&"_focus_member", count)), "%s focuses the exact final member" % CAPTURES[index])
	elif mode == &"tray":
		var overflow := hud.get_node("Margin/CombatStatus/AlertRegion/Overflow") as Button
		_assert(overflow.visible, "%s has overflow alerts" % CAPTURES[index])
		overflow.pressed.emit()
		await _frames(3)
		var close := hud.get_node("CombatAlertTray/Overlay/Frame/Layout/Close") as Button
		close.grab_focus()
		_assert(close.has_focus(), "%s focuses the tray Close boundary" % CAPTURES[index])
	elif mode == &"overflow":
		(hud.get_node("Margin/CombatStatus/AlertRegion/Overflow") as Button).grab_focus()
	elif mode == &"alert_focus":
		var action := _first_alert_action(hud, &"inspect")
		if action != null: action.grab_focus()
		_assert(action != null and action.has_focus(), "%s focuses an exact alert action" % CAPTURES[index])
	elif mode == &"controller":
		if not controls.is_empty(): controls[0].grab_focus()
		await _joy_button(JOY_BUTTON_DPAD_RIGHT)
	elif mode == &"mouse":
		if not controls.is_empty(): await _mouse_motion(controls[-1].get_global_rect().get_center())
	elif mode == &"member_focus":
		if not controls.is_empty(): controls[mini(1, controls.size() - 1)].grab_focus()
	await _capture(index)
	hud.free()
	backdrop.free()
	await _frames(2)
	_cleanup_hud_fixture(fixture)


func _capture_hud_modal_return(index: int, ledger_route: bool) -> void:
	paused = false
	var metadata := CAPTURE_METADATA[index]
	_apply_window(metadata)
	var backdrop := _battlefield_backdrop()
	var fixture := _hud_fixture(12, 8, _settings_for(metadata))
	if ledger_route:
		(fixture.health_by_member[2] as HealthComponent).apply_damage(1000.0)
	var hud := HUD_SCENE.instantiate() as HUD
	root.add_child(hud)
	_configure_active_run_hud(hud, fixture)
	var game_run := GameRun.new()
	root.add_child(game_run)
	game_run.start_run()
	var ledger: CharacterLedger
	if ledger_route:
		ledger = (load("res://scenes/ui/ledger/character_ledger.tscn") as PackedScene).instantiate() as CharacterLedger
		root.add_child(ledger)
		ledger.configure(game_run, fixture.party, GameCatalog.load_defaults(), func(member_id: int) -> Dictionary: return _ledger_health(fixture, member_id), [], null, Callable(fixture.context, "progression_for"), fixture.context)
		ledger.closed.connect(func(_return_focus: Control, descriptor: Dictionary) -> void: hud.restore_focus_descriptor(descriptor))
		hud.ledger_requested.connect(func(member_id: int, return_focus: Control) -> void: ledger.open_for_member(member_id, &"stats", return_focus, hud.focus_descriptor_for(return_focus)))
	else:
		hud.inspect_requested.connect(func(member_id: int, return_focus: Control) -> void: hud.open_inspector_for_member(member_id, return_focus))
	await _frames(5)
	var overflow := hud.get_node("Margin/CombatStatus/AlertRegion/Overflow") as Button
	overflow.pressed.emit()
	await _frames(3)
	var action := _first_tray_action(hud, &"ledger" if ledger_route else &"inspect")
	_assert(action != null, "%s resolves the authentic alert action" % CAPTURES[index])
	if action != null:
		action.grab_focus()
		action.pressed.emit()
		await _frames(3)
		if ledger_route and ledger != null:
			ledger.close()
		else:
			(hud.get_node("CombatMemberInspectPanel") as CombatMemberInspectPanel).close()
		await _frames(3)
		_assert(action.has_focus(), "%s restores exact initiating action focus" % CAPTURES[index])
	await _capture(index)
	if ledger != null: ledger.free()
	hud.free()
	backdrop.free()
	game_run.free()
	paused = false
	await _frames(2)
	_cleanup_hud_fixture(fixture)


func _capture_level_up(index: int, mode: StringName) -> void:
	paused = false
	var metadata := CAPTURE_METADATA[index]
	_apply_window(metadata)
	var catalog := GameCatalog.load_defaults()
	var party := _party(24 if mode != &"offers" else 6, catalog)
	var panel := LEVEL_UP_SCENE.instantiate() as LevelUpPanel
	root.add_child(panel)
	panel.configure(catalog, UpgradeApplicationService.new(), func(_member_id: int) -> Vector2: return Vector2(100.0, 100.0))
	panel.configure_visual_settings(_settings_for(metadata))
	panel.configure_reduced_motion(true)
	var choices: Array[UpgradeChoice]
	if mode == &"offers":
		choices = [
			UpgradeChoice.authored(catalog.upgrade_by_id(&"vanguard_wall")),
			UpgradeChoice.authored(catalog.upgrade_by_id(&"vitality")),
			UpgradeChoice.authored(catalog.upgrade_by_id(&"precision")),
			UpgradeChoice.authored(catalog.upgrade_by_id(&"tempered_armor")),
			UpgradeChoice.authored(catalog.upgrade_by_id(&"fleetfoot")),
		]
	else:
		choices = [UpgradeChoice.authored(catalog.upgrade_by_id(&"vitality"))]
	panel.show_choices(choices, party)
	await _frames(5)
	if mode == &"offers":
		var visible_cards := 0
		for child: Node in (panel.get_node("Frame/Content/Offer/CardsScroll/Cards") as Container).get_children():
			if child is UpgradeCard and child.is_visible_in_tree(): visible_cards += 1
		_assert(visible_cards == 5, "%s renders five exact typed offers" % CAPTURES[index])
	if mode != &"offers":
		var card := panel.get_node("Frame/Content/Offer/CardsScroll/Cards/Card1") as UpgradeCard
		card.activated.emit(card.bound_choice_key())
		await _frames(4)
		var member_24 := panel.get_node("Frame/Content/Recipient/Content/RecipientsScroll/Rows/Member_24") as Button
		member_24.grab_focus()
		(panel.get_node("Frame/Content/Recipient/Content/RecipientsScroll") as ScrollContainer).ensure_control_visible(member_24)
		await _frames(3)
		_assert((panel.get_node("Frame/Content/Recipient") as Control).visible and member_24.has_focus(), "%s renders and reaches recipient 24" % CAPTURES[index])
		if mode == &"confirmation":
			member_24.pressed.emit()
			await _frames(3)
			var cancel := panel.get_node("Frame/Content/Confirmation/Actions/Cancel") as Button
			_assert(cancel.has_focus(), "%s defaults confirmation to safe Cancel" % CAPTURES[index])
	await _capture(index)
	panel.free()
	party.free()
	await _frames(2)


func _capture_extraction(index: int, mode: StringName) -> void:
	paused = false
	var metadata := CAPTURE_METADATA[index]
	_apply_window(metadata)
	var panel := EXTRACTION_SCENE.instantiate() as TerminalExtractionPanel
	root.add_child(panel)
	panel.apply_visual_settings(_settings_for(metadata))
	var fixture := _result_fixture(8, 22, RunTerminalSnapshot.Outcome.VICTORY)
	_assert(fixture.snapshot != null and fixture.profile != null and fixture.resolution != null and fixture.resolution.ok(), "%s has a complete typed extraction fixture" % CAPTURES[index])
	if fixture.snapshot == null or fixture.profile == null or fixture.resolution == null or not fixture.resolution.ok():
		panel.free()
		await _frames(2)
		return
	var policy := fixture.resolution.accepted_extraction as RunExtractionProjection
	var projection := TerminalExtractionViewModel.new().build(policy, fixture.snapshot.resolution_source, fixture.profile)
	_assert(projection.valid and projection.automatic_count == 2 and projection.selected_count == 2 and projection.lost_count == 22 and projection.eligible_items.size() == 24, "%s uses typed automatic, selected, and lost terminal truth" % CAPTURES[index])
	panel.present(projection)
	await _frames(5)
	var cards := _extraction_cards(panel)
	var eligible_cards := _eligible_extraction_cards(panel)
	_assert(cards.size() == 26, "%s renders the exact 2 automatic plus 24 eligible extraction cards" % CAPTURES[index])
	_assert(eligible_cards.size() == 24, "%s renders every typed eligible extraction item in the eligible scope" % CAPTURES[index])
	if mode == &"pending":
		panel.set_pending(true)
		await _frames(3)
		_assert((panel.get_node("Frame/Content/Pending") as Control).visible, "%s renders the production pending operation cue" % CAPTURES[index])
		var item_action_enabled := false
		for card: Button in cards:
			var inspect := card.get_node("Inspect") as Button
			if (card.visible and not card.disabled) or (inspect.visible and not inspect.disabled):
				item_action_enabled = true
		_assert(not item_action_enabled, "%s excludes every item-card and Inspect action while pending" % CAPTURES[index])
	elif mode == &"detail":
		var anchor := eligible_cards[-1] if not eligible_cards.is_empty() else null
		if anchor != null:
			panel.show_detail(projection.eligible_items[-1], anchor)
			await _frames(3)
			(panel.get_node("ItemTooltipDetail/Frame/Close") as Button).grab_focus()
			_assert((panel.get_node("ItemTooltipDetail") as Control).visible, "%s renders the real extraction detail surface" % CAPTURES[index])
	else:
		var selected_anchor := _eligible_extraction_card(panel, "visual-result-selected")
		if selected_anchor != null: selected_anchor.grab_focus()
	await _capture(index)
	panel.free()
	await _frames(2)


func _capture_result_state(index: int, mode: StringName, pending_kind := 0) -> void:
	paused = false
	var metadata := CAPTURE_METADATA[index]
	_apply_window(metadata)
	var panel := RESULT_SCENE.instantiate() as RunResultPanel
	root.add_child(panel)
	var outcome := RunTerminalSnapshot.Outcome.DEFEAT if mode == &"defeat" else RunTerminalSnapshot.Outcome.VICTORY
	var fixture := _result_fixture(8 if mode in [&"victory", &"expanded"] else 4, 8 if mode == &"defeat" else 3, outcome)
	_assert(fixture.snapshot != null and fixture.profile != null and fixture.resolution != null and fixture.resolution.ok(), "%s has a complete typed result fixture" % CAPTURES[index])
	if fixture.snapshot == null or fixture.profile == null or fixture.resolution == null or not fixture.resolution.ok():
		panel.free()
		await _frames(2)
		return
	var view_model := RunResultViewModel.new()
	var finalized_result := view_model.build(fixture.snapshot, fixture.resolution, fixture.profile, [])
	_assert(finalized_result.ok(), "%s builds finalized fixture" % CAPTURES[index])
	if not finalized_result.ok():
		panel.free()
		await _frames(2)
		return
	var finalized := finalized_result.projection
	var projected: RunResultProjection
	var projection_result: RunResultProjectionResult
	match mode:
		&"victory", &"defeat", &"expanded": projected = finalized
		&"save": projection_result = view_model.terminal_save_interrupted(fixture.snapshot, "Terminal record could not be saved. Retry Terminal Save.")
		&"refresh": projection_result = view_model.terminal_refresh_interrupted(fixture.snapshot, "Terminal state was saved, but recovery could not refresh. Retry Terminal Recovery.")
		&"resolution":
			var resolution_reason := "Resolution was interrupted before durable acceptance. Retry Resolution."
			projection_result = view_model.resolution_interrupted(fixture.snapshot, resolution_reason, _durable_resolution_safety(fixture, resolution_reason))
		&"projection": projection_result = view_model.projection_interrupted(fixture.snapshot, fixture.resolution, "Accepted results could not be rebuilt. Retry Results.")
		&"automatic": projected = _automatic_overflow_projection(view_model, fixture)
		&"pending": projection_result = view_model.pending(fixture.snapshot, pending_kind)
		&"receipt_error": projection_result = view_model.finalized_action_interrupted(finalized, "Return to Forge could not clear the terminal record. Choose a terminal action to retry.")
		&"committed_refresh": projection_result = view_model.finalized_committed_refresh_interrupted(finalized, "The terminal record was cleared, but the profile could not refresh. Retry Return to Forge.", &"ReturnToForge")
		_: projected = finalized
	if projection_result != null:
		projected = _projection_from(projection_result, CAPTURES[index])
	_assert(projected != null and projected.valid(), "%s has a valid typed result projection" % CAPTURES[index])
	if projected == null or not projected.valid():
		panel.free()
		await _frames(2)
		return
	projected = projected.with_visual_settings(_settings_for(metadata))
	panel.present(projected, &"ReturnToForge" if mode in [&"receipt_error", &"committed_refresh"] else &"")
	await _frames(5)
	var visible_actions := _visible_result_actions(panel)
	if mode == &"pending":
		_assert(visible_actions.is_empty() and not (panel.get_node("Frame/Content/Body") as Control).visible, "%s exposes no premature recap or action" % CAPTURES[index])
	elif mode in [&"victory", &"defeat", &"expanded"]:
		_assert(visible_actions == ["RestartRun", "ReturnToForge", "QuitApplication"] and (panel.get_node("Frame/Content/Body") as Control).visible, "%s exposes finalized truth and exact exits" % CAPTURES[index])
	elif mode == &"save": _assert(visible_actions == ["RetryTerminalSave"], "%s exposes only Retry Terminal Save" % CAPTURES[index])
	elif mode == &"refresh": _assert(visible_actions == ["RetryTerminalRefresh"], "%s exposes only Retry Terminal Recovery" % CAPTURES[index])
	elif mode == &"resolution":
		_assert(visible_actions == ["RetryResolution", "OpenArmoury", "ReturnToForge", "QuitApplication"], "%s exposes the exact durable recovery action set" % CAPTURES[index])
		_assert((panel.get_node("Frame/Content/Footer/Actions/RetryResolution") as Button).has_focus(), "%s retains safe Retry Resolution focus" % CAPTURES[index])
	elif mode == &"projection": _assert(visible_actions == ["RetryProjection"], "%s exposes only Retry Results" % CAPTURES[index])
	elif mode == &"receipt_error": _assert(visible_actions == ["RestartRun", "ReturnToForge", "QuitApplication"], "%s preserves all finalized actions because receipt clear did not commit" % CAPTURES[index])
	if mode == &"automatic":
		(panel.get_node("Frame/Content/Footer/Actions/ProtectDisplacedGear") as Button).pressed.emit()
		await _frames(3)
		_assert((panel.get_node("Frame/Content/Confirmation/Content/Actions/Cancel") as Button).has_focus(), "%s opens Recovery Overflow confirmation on safe Cancel" % CAPTURES[index])
	elif mode == &"defeat":
		var lost_row := _result_row(panel, &"loot", "Lost")
		if lost_row != null: lost_row.grab_focus()
		_assert(lost_row != null and lost_row.has_focus(), "%s focuses the truthful Lost row" % CAPTURES[index])
	elif mode == &"expanded":
		var rows := _result_rows(panel)
		if not rows.is_empty():
			var row := rows[-1]
			row.grab_focus()
			row.pressed.emit()
			await _frames(4)
	if mode == &"committed_refresh":
		_assert(_visible_result_actions(panel) == ["ReturnToForge"] and (panel.get_node("Frame/Content/Footer/Actions/ReturnToForge") as Button).has_focus(), "%s exposes one exact committed refresh retry" % CAPTURES[index])
	await _capture(index)
	panel.free()
	await _frames(2)


func _capture_pause_abandon(index: int) -> void:
	paused = false
	var metadata := CAPTURE_METADATA[index]
	_apply_window(metadata)
	var backdrop := _battlefield_backdrop()
	var fixture := _hud_fixture(6, 3, _settings_for(metadata))
	var hud := HUD_SCENE.instantiate() as HUD
	root.add_child(hud)
	_configure_active_run_hud(hud, fixture)
	var game_run := GameRun.new()
	root.add_child(game_run)
	game_run.start_run()
	var menu := PAUSE_SCENE.instantiate() as RunPauseMenu
	root.add_child(menu)
	menu.configure(game_run, func() -> bool: return false)
	_assert(menu.open(), "committed Abandon fixture opens the production pause menu")
	menu.present_abandon_committed_refresh_error("Run abandoned, but the profile could not refresh. Retry Return to Forge.")
	await _frames(4)
	var retry := menu.get_node("Overlay/AbandonCommittedError/Panel/Content/RetryReturnToForge") as Button
	_assert(retry.visible and retry.has_focus(), "committed Abandon exposes and focuses only Retry Return to Forge")
	await _capture(index)
	menu.free()
	hud.free()
	backdrop.free()
	game_run.free()
	paused = false
	await _frames(2)
	_cleanup_hud_fixture(fixture)


func _capture_restart_lobby(index: int, valid_intent: bool) -> void:
	paused = false
	var metadata := CAPTURE_METADATA[index]
	_apply_window(metadata)
	var catalog := GameCatalog.load_defaults()
	var profile := ProfileState.new_profile("restart-profile", "Restart Review", 1000)
	profile.prologue_state = ProfileState.PrologueState.COMPLETED
	var intent := RunSetupRestartIntent.create(profile.profile_id if valid_intent else "missing-profile", &"mage" if valid_intent else &"fighter", "" if valid_intent else "Previous run selection is unavailable. Choose a class to begin your run.")
	var compatibility: LoadoutCompatibilityProjection
	if valid_intent:
		compatibility = LoadoutCompatibilityService.new().project(profile, catalog.class_by_id(&"mage"), GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
		_assert(compatibility != null and compatibility.valid and compatibility.selected_class_id == &"mage" and compatibility.incompatible_items.is_empty(), "%s builds typed compatible Mage loadout truth" % CAPTURES[index])
	var projection := RunSetupLobbyViewModel.build(profile, catalog, &"", &"", compatibility, "", false, intent)
	var panel := LOBBY_SCENE.instantiate() as ClassSelectionPanel
	root.add_child(panel)
	panel.configure(catalog)
	panel.present(projection)
	panel.open(panel.selection_focus(&"mage") if valid_intent else null)
	panel.apply_viewport_size(Vector2(int(metadata.width), int(metadata.height)))
	await _frames(6)
	_assert(panel.selected_class_id() == (&"mage" if valid_intent else &""), "%s keeps exact restart selection truth" % CAPTURES[index])
	if valid_intent:
		var mage := panel.selection_focus(&"mage") as Button
		var start := panel.action_focus(&"start") as Button
		_assert(projection.state == RunSetupLobbyProjection.State.READY and mage != null and mage.has_focus() and start != null and not start.disabled, "%s presents stable READY Mage preselection with Start enabled" % CAPTURES[index])
	await _capture(index)
	panel.free()
	await _frames(2)


func _hud_fixture(count: int, alert_count: int, settings: PartyForgeSettings) -> HudEvidenceFixture:
	_sequence += 1
	var catalog := GameCatalog.load_defaults()
	var party := _party(count, catalog)
	party.configure_identity(_sequence, catalog.generic_name_pool)
	var context := PlayerRunContext.new()
	var context_error := context.configure(StringName("visual-%d" % _sequence), 0, ProfileState.new_profile("visual-profile-%d" % _sequence, "Visual", 1000), _sequence, party, 100)
	_assert(context_error.is_empty(), "HUD evidence configures a typed run context: %s" % context_error)
	var experience := ExperienceSystem.new()
	experience.configure_context(context, 1)
	var result := HudEvidenceFixture.new()
	result.party = party
	result.context = context
	result.experience = experience
	result.run = EvidenceRun.new()
	result.settings = settings
	for member_id: int in range(1, count + 1):
		var actor := Node3D.new()
		var health := HealthComponent.new()
		health.name = "HealthComponent"
		actor.add_child(health)
		health.configure(100.0, member_id == 1, 8.0, 0.5, member_id == 1)
		if member_id <= alert_count: health.apply_damage(80.0)
		_assert(context.bind_actor(member_id, actor), "HUD evidence binds exact actor %d" % member_id)
		result.actors.append(actor)
		result.health_by_member[member_id] = health
	return result


func _configure_active_run_hud(hud: HUD, fixture: HudEvidenceFixture) -> void:
	var lobby := hud.get_node("ClassSelection") as ClassSelectionPanel
	lobby.close()
	hud.configure(fixture.run, fixture.party, fixture.experience, fixture.context, fixture.settings)
	_assert(not lobby.is_open(), "standalone active-run HUD closes the embedded run-setup lobby")
	_assert((hud.get_node("Margin") as Control).visible, "standalone active-run HUD exposes the production combat margin")


func _party(count: int, catalog: GameCatalog) -> PartyManager:
	var party := PartyManager.new()
	party.configure_capacity(PartyCapacityPolicy.new(count))
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	party.members[0].character_name = "Asha"
	for member_id: int in range(2, count + 1):
		var recruited := party.recruit(catalog.class_by_id([&"fighter", &"ranger", &"mage"][member_id % 3]))
		_assert(recruited, "evidence recruits exact party member %d" % member_id)
		if not recruited: break
		party.members[-1].character_name = "Member %02d" % member_id
	return party


func _result_fixture(member_count: int, lost_count: int, outcome: RunTerminalSnapshot.Outcome) -> ResultEvidenceFixture:
	var result := ResultEvidenceFixture.new()
	var profile_id := "visual-result-profile"
	var run_id := &"visual-result-run"
	var run_seed := 44771
	var run_player_id := &"visual-result-player"
	var automatic_id := "visual-result-automatic"
	var automatic_two_id := "visual-result-automatic-two"
	var selected_id := "visual-result-selected"
	var selected_two_id := "visual-result-selected-two"
	var protected_id := "visual-result-protected"
	var protected_two_id := "visual-result-protected-two"
	var run_items: Array[ItemInstance] = [
		_result_item(automatic_id, 0, &"forge_vanguard_sword", profile_id, run_seed, run_player_id, false),
		_result_item(automatic_two_id, 1, &"forge_vanguard_helmet", profile_id, run_seed, run_player_id, false),
		_result_item(selected_id, 2, &"forge_vanguard_hammer", profile_id, run_seed, run_player_id, false),
		_result_item(selected_two_id, 3, &"forge_vanguard_hammer", profile_id, run_seed, run_player_id, false),
	]
	var inventory_slots: Dictionary = {0:selected_id,1:selected_two_id}
	var eligible: Array[ExtractionSelection] = [
		ExtractionSelection.create(selected_id, &"run-inventory", 0),
		ExtractionSelection.create(selected_two_id, &"run-inventory", 1),
	]
	var lost_ids: Array[String] = []
	for index: int in lost_count:
		var item_id := "visual-result-lost-%02d" % (index + 1)
		run_items.append(_result_item(item_id, index + 4, &"forge_vanguard_hammer", profile_id, run_seed, run_player_id, false))
		inventory_slots[index + 2] = item_id
		eligible.append(ExtractionSelection.create(item_id, &"run-inventory", index + 2))
		lost_ids.append(item_id)
	var run_state := ItemOwnershipState.create(String(run_player_id), ItemRegistry.new(run_items), [
		ItemSlotContainer.create(&"run-inventory", ItemSlotContainer.RUN_INVENTORY, String(run_player_id), 40, inventory_slots),
		ItemSlotContainer.create(&"run-equipment-001", ItemSlotContainer.RUN_MEMBER_EQUIPMENT, String(run_player_id), EquipmentSlotIndex.capacity(), {0:automatic_two_id,9:automatic_id}),
	])
	var run_state_error := run_state.validate(GameCatalog.EQUIPMENT_CATALOG, GameCatalog.ITEM_FOUNDATION_CATALOG)
	_assert(run_state_error.is_empty(), "result evidence run item state is valid: %s" % run_state_error)
	if not run_state_error.is_empty(): return result
	var source_members: Array[Dictionary] = []
	var terminal_members: Array[RunTerminalPartyMemberSnapshot] = []
	for member_id: int in range(1, member_count + 1):
		var class_id := &"fighter" if member_id == 1 else (&"ranger" if member_id % 2 == 0 else &"mage")
		var class_label := "Fighter" if class_id == &"fighter" else ("Ranger" if class_id == &"ranger" else "Mage")
		source_members.append({"member_id":member_id,"class_id":String(class_id),"is_leader":member_id == 1})
		terminal_members.append(RunTerminalPartyMemberSnapshot.create(member_id, "Asha" if member_id == 1 else "Member %02d" % member_id, class_id, class_label, member_id == 1, member_id + 6))
	var attributes: Dictionary = {}
	for attribute_id: StringName in ClassGrowthDefinition.CORE_ATTRIBUTE_IDS: attributes[String(attribute_id)] = 10.0
	var source_result := RunResolutionSource.from_dictionary({
		"schema_version":RunResolutionSource.SCHEMA_VERSION,"profile_id":profile_id,"run_id":String(run_id),"run_seed":run_seed,"run_player_id":String(run_player_id),
		"leader_member_id":1,"party_members":source_members,"item_state":run_state.to_dictionary(),"leader_class_id":"fighter","leader_core_attributes":attributes,
	})
	_assert(source_result.ok(), "result evidence source captures typed run truth")
	if not source_result.ok(): return result
	var snapshot_result := RunTerminalSnapshot.create(outcome, 125.0, profile_id, run_id, run_seed, run_player_id, 1, terminal_members, source_result.source)
	_assert(snapshot_result.ok(), "result evidence snapshot captures typed terminal truth")
	if not snapshot_result.ok(): return result
	var retained_items: Array[ItemInstance] = [run_items[0],run_items[1],run_items[2],run_items[3]]
	var protected := _result_item(protected_id, 50, &"forge_vanguard_helmet", profile_id, run_seed, run_player_id, true)
	var protected_two := _result_item(protected_two_id, 51, &"forge_vanguard_sword", profile_id, run_seed, run_player_id, true)
	retained_items.append(protected)
	retained_items.append(protected_two)
	var profile := ProfileState.new_profile(profile_id, "Result Truth", 1000)
	profile.inventory_columns = 2
	profile.leader_loadout_class_id = "fighter"
	profile.item_records = ItemRegistry.new(retained_items).to_dictionary()
	profile.leader_loadout = ItemSlotContainer.create(&"leader-loadout", ItemSlotContainer.PROFILE_LEADER_EQUIPMENT, profile_id, EquipmentSlotIndex.capacity(), {0:automatic_two_id,9:automatic_id}).to_dictionary()
	profile.stash_tabs = [ItemSlotContainer.create(&"stash-tab-000", ItemSlotContainer.PROFILE_STASH_TAB, profile_id, 100, {0:selected_id,1:selected_two_id}).to_dictionary()]
	profile.terminal_recovery_overflow = ItemSlotContainer.create(ItemSlotContainer.TERMINAL_RECOVERY_OVERFLOW_ID, ItemSlotContainer.PROFILE_TERMINAL_RECOVERY_OVERFLOW, profile_id, EquipmentSlotIndex.capacity(), {0:protected_id,9:protected_two_id}).to_dictionary()
	var accepted := RunExtractionProjection.create([automatic_id,automatic_two_id], eligible, [selected_id,selected_two_id], lost_ids, 2, [])
	var resolution := RunResolutionResult.success(profile, false, accepted, [protected_id,protected_two_id])
	_assert(resolution.ok(), "result evidence has an accepted typed durable resolution")
	if not resolution.ok(): return result
	result.snapshot = snapshot_result.snapshot
	result.profile = profile
	result.resolution = resolution
	return result


func _result_item(instance_id: String, sequence: int, base_id: StringName, profile_id: String, run_seed: int, run_player_id: StringName, permanent: bool) -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = instance_id
	item.base_definition_id = base_id
	item.item_level = 12
	item.rarity_id = &"common"
	item.origin = {"issuer_namespace":"profile:%s" % profile_id if permanent else "run:%s:%d:%s" % [profile_id,run_seed,run_player_id],"seed":run_seed,"sequence":sequence,"source":"living_forge_combat_loop_visual_evidence"}
	return item


func _cleanup_hud_fixture(fixture: HudEvidenceFixture) -> void:
	for actor: Node3D in fixture.actors:
		if is_instance_valid(actor): actor.free()
	if fixture.experience != null and is_instance_valid(fixture.experience): fixture.experience.free()
	if fixture.party != null and is_instance_valid(fixture.party): fixture.party.free()
	if fixture.run != null and is_instance_valid(fixture.run): fixture.run.free()
	fixture.context = null


func _ledger_health(fixture: HudEvidenceFixture, member_id: int) -> Dictionary:
	var health := fixture.health_by_member.get(member_id) as HealthComponent
	return {} if health == null else {"current":health.current_health,"maximum":health.max_health,"is_downed":health.is_downed,"is_dead":health.is_dead,"component":health}


func _automatic_overflow_projection(view_model: RunResultViewModel, fixture: ResultEvidenceFixture) -> RunResultProjection:
	var evaluation := RunResolutionEvaluation.create(fixture.resolution.accepted_extraction, 2, 0, 0, "automatic-only blocked", RunResolutionEvaluation.FailureCategory.STASH_AUTOMATIC_ONLY, "Automatic retained items need 2 more destination slots.")
	var preflight := RunResolutionPreflightResult.from_evaluation(evaluation)
	var record_result := RunTerminalRecoveryRecord.create(RunTerminalRecoveryRecord.Stage.RESOLUTION_INTERRUPTED, fixture.snapshot, [], "terminal-resolution:visual", ["displaced-a", "displaced-b"], preflight.player_reason)
	_assert(record_result.ok(), "automatic-only evidence builds a valid durable RESOLUTION_INTERRUPTED record")
	var safety := RunTerminalRecoverySafetyResult.success(record_result.record) if record_result.ok() else RunTerminalRecoverySafetyResult.failure(record_result.error)
	return _projection_from(view_model.resolution_interrupted(fixture.snapshot, preflight.player_reason, safety, preflight), "automatic-only Recovery Overflow")


func _durable_resolution_safety(fixture: ResultEvidenceFixture, reason: String) -> RunTerminalRecoverySafetyResult:
	var selected: Array[String] = fixture.resolution.accepted_extraction.selected_item_ids
	var record_result := RunTerminalRecoveryRecord.create(RunTerminalRecoveryRecord.Stage.RESOLUTION_INTERRUPTED, fixture.snapshot, selected, "terminal-resolution:visual", [], reason)
	_assert(record_result.ok(), "resolution evidence builds a valid durable RESOLUTION_INTERRUPTED safety record")
	return RunTerminalRecoverySafetyResult.success(record_result.record) if record_result.ok() else RunTerminalRecoverySafetyResult.failure(record_result.error)


func _projection_from(result: RunResultProjectionResult, label: String) -> RunResultProjection:
	_assert(result != null and result.ok(), "%s projection constructor succeeds" % label)
	return result.projection if result != null and result.ok() else null


func _settings_for(metadata: Dictionary) -> PartyForgeSettings:
	var settings := PartyForgeSettings.new()
	settings.ui_scale_percent = int(metadata.ui)
	settings.text_scale_percent = int(metadata.text)
	settings.high_contrast = bool(metadata.contrast)
	settings.reduced_motion = bool(metadata.motion)
	return settings


func _apply_window(metadata: Dictionary) -> void:
	root.size = Vector2i(int(metadata.width), int(metadata.height))


func _capture(index: int) -> void:
	await _frames(5)
	_assert_declared_focus(index)
	var metadata := CAPTURE_METADATA[index]
	var image := root.get_texture().get_image()
	_assert(image != null and not image.is_empty(), "%s returns rendered pixels" % CAPTURES[index])
	if image == null or image.is_empty(): return
	_assert(image.get_size() == Vector2i(int(metadata.width), int(metadata.height)), "%s has exact declared dimensions" % CAPTURES[index])
	_assert(_image_is_nonblank(image), "%s is nonblank" % CAPTURES[index])
	var path := ProjectSettings.globalize_path(SCREENSHOT_ROOT.path_join(CAPTURES[index]))
	_assert(image.save_png(path) == OK, "%s saves" % CAPTURES[index])
	if not FileAccess.file_exists(path): return
	var hash := _sha256(FileAccess.get_file_as_bytes(path))
	_assert(hash.length() == 64, "%s has SHA-256" % CAPTURES[index])
	_captured[CAPTURES[index]] = hash
	var fixture_kind := _fixture_kind_for(metadata)
	_entries.append({"file":CAPTURES[index],"sha256":hash,"width":image.get_width(),"height":image.get_height(),"state":CAPTURE_STATES[index],"surface":metadata.surface,"fixture_kind":fixture_kind,"focus_target":CAPTURE_FOCUS_TARGETS[index],"settings":{"ui_scale_percent":metadata.ui,"text_scale_percent":metadata.text,"high_contrast":metadata.contrast,"reduced_motion":metadata.motion},"input_mode":metadata.input})


func _assert_declared_focus(index: int) -> void:
	var target := CAPTURE_FOCUS_TARGETS[index]
	var owner := root.gui_get_focus_owner() as Control
	if target == "none":
		_assert(owner == null, "%s has no undeclared focus owner" % CAPTURES[index])
		return
	if target == "hud:hover":
		var hover_visible := false
		for node: Node in get_nodes_in_group(&"combat_hud_member"):
			var hover := node.get_node_or_null("HoverPlate") as Control
			if hover != null and hover.is_visible_in_tree(): hover_visible = true
		_assert(hover_visible, "%s has a real visible HUD hover plate" % CAPTURES[index])
		return
	_assert(owner != null and owner.is_visible_in_tree(), "%s has a live declared focus owner %s" % [CAPTURES[index], target])
	if owner == null: return
	match target:
		"member:24": _assert(int(owner.get_meta(&"member_id", 0)) == 24 and owner.is_in_group(&"combat_hud_member"), "%s focuses exact Member 24" % CAPTURES[index])
		"hud:member": _assert(owner.is_in_group(&"combat_hud_member"), "%s focuses a real HUD member control" % CAPTURES[index])
		"hud:overflow": _assert(owner.name == &"Overflow", "%s focuses exact HUD overflow" % CAPTURES[index])
		"hud:alert_inspect", "alert:inspect": _assert(owner.name == &"Inspect", "%s focuses exact alert Inspect" % CAPTURES[index])
		"alert:ledger": _assert(owner.name == &"Ledger", "%s focuses exact alert Ledger" % CAPTURES[index])
		"alert_tray:close": _assert(owner.name == &"Close" and "CombatAlertTray" in String(owner.get_path()), "%s focuses alert tray Close" % CAPTURES[index])
		"upgrade_card:1": _assert(owner.name == &"Card1", "%s focuses first real upgrade card" % CAPTURES[index])
		"recipient:24": _assert(owner.name == &"Member_24", "%s focuses exact recipient 24" % CAPTURES[index])
		"extraction:visual-result-selected": _assert(String(owner.get_meta(&"item_id", "")) == "visual-result-selected", "%s focuses exact selected extraction item" % CAPTURES[index])
		"extraction:show_auto": _assert(owner.name == &"AutomaticList", "%s focuses the safe Show Auto summary filter while pending" % CAPTURES[index])
		"extraction_detail:close": _assert(owner.name == &"Close" and "ItemTooltipDetail" in String(owner.get_path()), "%s focuses extraction detail Close" % CAPTURES[index])
		"result:return_to_forge": _assert(owner.name == &"ReturnToForge", "%s focuses safe Return to Forge" % CAPTURES[index])
		"result:lost_row": _assert(owner.get_meta(&"recap_section_id", &"") == &"loot" and String(owner.get_meta(&"recap_entry_label", "")) == "Lost", "%s focuses truthful Lost recap row" % CAPTURES[index])
		"result:retry_resolution": _assert(owner.name == &"RetryResolution", "%s focuses Retry Resolution" % CAPTURES[index])
		"result:retry_terminal_save": _assert(owner.name == &"RetryTerminalSave", "%s focuses Retry Terminal Save" % CAPTURES[index])
		"result:retry_projection": _assert(owner.name == &"RetryProjection", "%s focuses Retry Results" % CAPTURES[index])
		"result:retry_terminal_refresh": _assert(owner.name == &"RetryTerminalRefresh", "%s focuses Retry Terminal Recovery" % CAPTURES[index])
		"confirmation:cancel": _assert(owner.name == &"Cancel", "%s focuses safe confirmation Cancel" % CAPTURES[index])
		"pause:retry_return_to_forge": _assert(owner.name == &"RetryReturnToForge", "%s focuses committed Abandon retry" % CAPTURES[index])
		"lobby:mage": _assert(owner.name == &"Class_mage", "%s focuses preselected Mage" % CAPTURES[index])
		"lobby:first_class": _assert(String(owner.name).begins_with("Class_"), "%s focuses a real explicit class choice" % CAPTURES[index])
		"result:expanded_row": _assert(owner.has_meta(&"recap_section_id") and (owner.get_node_or_null("Detail") as Control).visible, "%s focuses a real expanded recap row" % CAPTURES[index])
		_: _assert(false, "%s has an unhandled focus target %s" % [CAPTURES[index], target])


func _write_manifest() -> void:
	var expected := CAPTURES.duplicate()
	expected.sort()
	var actual: Array[String] = []
	var unique_hashes: Dictionary = {}
	for name: Variant in _captured.keys(): actual.append(String(name))
	actual.sort()
	_assert(actual == expected and _entries.size() == CAPTURES.size(), "current run captured the exact 45-member contract before manifest write")
	for index: int in _entries.size():
		var entry := _entries[index]
		_assert(String(entry.get("file", "")) == CAPTURES[index], "current-run entry order is exact at index %d" % index)
		unique_hashes[String(entry.get("sha256", ""))] = true
	_assert(unique_hashes.size() == CAPTURES.size(), "current run has 45 unique capture hashes before manifest write")
	if not _failures.is_empty(): return
	var manifest := {"schema_version":MANIFEST_SCHEMA_VERSION,"run_id":"%d-%d" % [OS.get_process_id(),_started_unix],"captured_at_utc":Time.get_datetime_string_from_system(true,true),"source_head":_source_head(),"source_tree_fingerprint":_source_fingerprint(),"capture_contract_sha256":_capture_contract_sha256(),"renderer":_renderer_metadata(),"window_mode":"windowed","capture_environment":{"hud_backdrop":"res://scenes/arena/arena.tscn","camera":"deterministic evidence camera"},"entries":_entries}
	var path := ProjectSettings.globalize_path(SCREENSHOT_ROOT.path_join(MANIFEST_NAME))
	var file := FileAccess.open(path, FileAccess.WRITE)
	_assert(file != null, "schema-2 manifest opens for writing")
	if file != null:
		file.store_string(JSON.stringify(manifest, "  ") + "\n")
		file.close()


func _validate_existing_evidence(require_fresh := false) -> void:
	var manifest_path := ProjectSettings.globalize_path(SCREENSHOT_ROOT.path_join(MANIFEST_NAME))
	_assert(FileAccess.file_exists(manifest_path), "exact schema-2 manifest exists")
	_assert_no_extra_pngs(true)
	if not FileAccess.file_exists(manifest_path): return
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	var manifest := value as Dictionary if value is Dictionary else {}
	_assert(int(manifest.get("schema_version", 0)) == MANIFEST_SCHEMA_VERSION, "manifest schema version is exactly 2")
	_assert(String(manifest.get("source_head", "")) == _source_head(), "manifest source head matches exact candidate Git head")
	var manifest_fingerprint := manifest.get("source_tree_fingerprint", {}) as Dictionary
	var current_fingerprint := _source_fingerprint()
	_assert(
		String(manifest_fingerprint.get("algorithm", "")) == String(current_fingerprint.get("algorithm", ""))
		and String(manifest_fingerprint.get("method", "")) == String(current_fingerprint.get("method", ""))
		and int(manifest_fingerprint.get("path_count", -1)) == int(current_fingerprint.get("path_count", -2))
		and String(manifest_fingerprint.get("sha256", "")) == String(current_fingerprint.get("sha256", ""))
		and JSON.stringify(manifest_fingerprint.get("inputs", [])) == JSON.stringify(current_fingerprint.get("inputs", [])),
		"manifest source fingerprint matches declared current source inputs",
	)
	_assert(String(manifest.get("capture_contract_sha256", "")) == _capture_contract_sha256(), "manifest capture contract hash matches all 45 exact specifications")
	_assert(JSON.stringify(manifest.get("renderer", {})) == JSON.stringify(_renderer_metadata()), "manifest renderer metadata matches current renderer")
	_assert(String(manifest.get("window_mode", "")) == "windowed", "manifest declares windowed capture")
	_assert(manifest.get("capture_environment", {}) == {"hud_backdrop":"res://scenes/arena/arena.tscn","camera":"deterministic evidence camera"}, "manifest declares the production Arena HUD contrast field")
	var entries := manifest.get("entries", []) as Array
	_assert(entries.size() == CAPTURES.size(), "manifest has exactly 45 entries")
	var hashes: Dictionary = {}
	for index: int in CAPTURES.size():
		if index >= entries.size(): break
		var entry := entries[index] as Dictionary
		var metadata := CAPTURE_METADATA[index]
		var name := CAPTURES[index]
		_assert(String(entry.get("file", "")) == name, "manifest entry %d has exact ordered filename" % index)
		_assert(int(entry.get("width", 0)) == int(metadata.width) and int(entry.get("height", 0)) == int(metadata.height), "%s has exact viewport metadata" % name)
		_assert(String(entry.get("surface", "")) == String(metadata.surface) and String(entry.get("input_mode", "")) == String(metadata.input), "%s has exact surface/input metadata" % name)
		var expected_fixture_kind := _fixture_kind_for(metadata)
		_assert(String(entry.get("fixture_kind", "")) == expected_fixture_kind, "%s has exact production fixture metadata" % name)
		_assert(String(entry.get("state", "")) == CAPTURE_STATES[index] and String(entry.get("focus_target", "")) == CAPTURE_FOCUS_TARGETS[index], "%s has exact state and focus-target metadata" % name)
		var settings := entry.get("settings", {}) as Dictionary
		_assert(int(settings.get("ui_scale_percent", 0)) == int(metadata.ui) and int(settings.get("text_scale_percent", 0)) == int(metadata.text) and bool(settings.get("high_contrast", false)) == bool(metadata.contrast) and bool(settings.get("reduced_motion", false)) == bool(metadata.motion), "%s has exact settings metadata" % name)
		var path := ProjectSettings.globalize_path(SCREENSHOT_ROOT.path_join(name))
		_assert(FileAccess.file_exists(path), "%s exists" % name)
		if not FileAccess.file_exists(path): continue
		var hash := _sha256(FileAccess.get_file_as_bytes(path))
		_assert(hash == String(entry.get("sha256", "")) and hash.length() == 64, "%s hash matches current nonempty bytes" % name)
		var decoded := Image.load_from_file(path)
		_assert(decoded != null and not decoded.is_empty() and decoded.get_size() == Vector2i(int(metadata.width), int(metadata.height)), "%s decodes to exact declared PNG dimensions" % name)
		_assert(not hashes.has(hash), "%s has a globally unique hash" % name)
		hashes[hash] = true
		if require_fresh: _assert(int(FileAccess.get_modified_time(path)) >= _started_unix, "%s is from the current capture run" % name)
	_assert(hashes.size() == CAPTURES.size(), "all 45 captures have globally unique nonempty hashes")


func _assert_no_extra_pngs(require_complete: bool) -> void:
	var directory := DirAccess.open(SCREENSHOT_ROOT)
	_assert(directory != null, "evidence directory exists")
	if directory == null: return
	var actual: Array[String] = []
	for file_name: String in directory.get_files(): actual.append(file_name)
	actual.sort()
	var expected: Array[String] = CAPTURES.duplicate()
	expected.append(MANIFEST_NAME)
	expected.sort()
	_assert(directory.get_directories().is_empty(), "evidence directory contains no undeclared subdirectories")
	if require_complete:
		_assert(actual == expected, "evidence directory has exact manifest and PNG path set with no old or extra file")
	else:
		for file_name: String in actual: _assert(file_name in expected, "evidence directory rejects undeclared file: %s" % file_name)


func _source_head() -> String:
	var output: Array = []
	var code := OS.execute("git", PackedStringArray(["-C", ProjectSettings.globalize_path("res://"), "rev-parse", "HEAD"]), output, true)
	_assert(code == 0 and not output.is_empty(), "source HEAD resolves")
	return String(output[0]).strip_edges() if code == 0 and not output.is_empty() else "unresolved"


func _source_fingerprint() -> Dictionary:
	var records: Array[Dictionary] = []
	var root_path := ProjectSettings.globalize_path("res://")
	for relative_path: String in SOURCE_INPUT_PATHS:
		var absolute_path := root_path.path_join(relative_path)
		_assert(FileAccess.file_exists(absolute_path), "declared fingerprint input exists: %s" % relative_path)
		if FileAccess.file_exists(absolute_path): records.append({"path":relative_path,"sha256":_sha256(FileAccess.get_file_as_bytes(absolute_path))})
	records.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left.path) < String(right.path))
	var context := HashingContext.new()
	_assert(context.start(HashingContext.HASH_SHA256) == OK, "source fingerprint initializes")
	for record: Dictionary in records:
		var path := String(record.path)
		var hash := String(record.sha256)
		_assert(context.update(("%d:%s%d:%s\n" % [path.length(),path,hash.length(),hash]).to_utf8_buffer()) == OK, "source fingerprint hashes %s" % path)
	return {"algorithm":"sha256","method":"Sorted explicit Task 14 source paths; SHA-256 a length-prefixed path/file-SHA record stream.","path_count":records.size(),"sha256":context.finish().hex_encode(),"inputs":records}


func _renderer_metadata() -> Dictionary:
	return {"method":RenderingServer.get_current_rendering_method(),"device_vendor":RenderingServer.get_video_adapter_vendor(),"device_name":RenderingServer.get_video_adapter_name(),"display_server":DisplayServer.get_name()}


func _capture_contract_sha256() -> String:
	var context := HashingContext.new()
	_assert(context.start(HashingContext.HASH_SHA256) == OK, "capture contract hash initializes")
	for index: int in CAPTURES.size():
		var metadata := CAPTURE_METADATA[index]
		var fields: Array[String] = [
			CAPTURES[index], CAPTURE_STATES[index], str(metadata.width), str(metadata.height),
			str(metadata.ui), str(metadata.text), str(metadata.contrast), str(metadata.motion),
			String(metadata.input), CAPTURE_FOCUS_TARGETS[index], _fixture_kind_for(metadata), String(metadata.surface),
		]
		var canonical := ""
		for field: String in fields: canonical += "%d:%s" % [field.length(), field]
		canonical += "\n"
		_assert(context.update(canonical.to_utf8_buffer()) == OK, "capture contract hashes index %d" % index)
	return context.finish().hex_encode()


func _fixture_kind_for(metadata: Dictionary) -> String:
	return "production_arena" if String(metadata.surface).begins_with("hud") or String(metadata.surface) == "pause" else "production_scene"


func _capture_source_is_clean() -> bool:
	var output: Array = []
	var repository_root := ProjectSettings.globalize_path("res://")
	var tracked_output: Array = []
	var tracked_code := OS.execute("git", PackedStringArray(["-C",repository_root,"ls-files","--error-unmatch",RUNNER_PATH]), tracked_output, true)
	if tracked_code != 0: return false
	var diff_code := OS.execute("git", PackedStringArray(["-C",repository_root,"diff","--quiet","HEAD","--",RUNNER_PATH]), [], true)
	if diff_code != 0: return false
	var code := OS.execute("git", PackedStringArray(["-C",repository_root,"status","--porcelain=v1","--untracked-files=all"]), output, true)
	if code != 0: return false
	for raw_line: String in String("".join(output)).split("\n", false):
		if raw_line.length() < 4: continue
		var path := raw_line.substr(3).strip_edges().replace("\\", "/")
		if " -> " in path: path = path.get_slice(" -> ", 1)
		if path.begins_with("docs/validation/screenshots/living-forge-combat-loop/"): continue
		return false
	return true


func _battlefield_backdrop() -> Node3D:
	var arena := ARENA_SCENE.instantiate() as Node3D
	root.add_child(arena)
	var camera := Camera3D.new()
	camera.name = "VisualEvidenceCamera"
	camera.position = Vector3(0.0, 18.0, 22.0)
	camera.fov = 52.0
	arena.add_child(camera)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	camera.current = true
	return arena


func _hud_member_controls(hud: HUD) -> Array[Control]:
	var result: Array[Control] = []
	for node: Node in get_nodes_in_group(&"combat_hud_member"):
		if node is Control and hud.is_ancestor_of(node): result.append(node as Control)
	return result


func _first_alert_action(hud: HUD, action: StringName) -> Button:
	var stack := hud.get_node("Margin/CombatStatus/AlertRegion/ExpandedAlerts") as Container
	for child: Node in stack.get_children():
		var button := child.get_node_or_null("Surface/Content/Actions/%s" % ("Inspect" if action == &"inspect" else "Ledger")) as Button
		if button != null and button.visible and not button.disabled: return button
	return null


func _first_tray_action(hud: HUD, action: StringName) -> Button:
	var tray := hud.get_node("CombatAlertTray") as CombatAlertTray
	var stack := tray.get_node("Overlay/Frame/Layout/Scroll/Alerts") as Container
	for child: Node in stack.get_children():
		var button := child.get_node_or_null("Surface/Content/Actions/%s" % ("Inspect" if action == &"inspect" else "Ledger")) as Button
		if button != null and button.visible and not button.disabled: return button
	return null


func _extraction_cards(panel: TerminalExtractionPanel) -> Array[Button]:
	var result: Array[Button] = []
	for node: Node in panel.find_children("*", "ForgeExtractionItemCard", true, false):
		if not String(node.get_meta(&"item_id", "")).is_empty(): result.append(node as Button)
	result.sort_custom(func(left: Button, right: Button) -> bool: return String(left.get_meta(&"item_id", "")) < String(right.get_meta(&"item_id", "")))
	return result


func _eligible_extraction_cards(panel: TerminalExtractionPanel) -> Array[Button]:
	var result: Array[Button] = []
	var scope := panel.get_node("Frame/Content/Body/Sections/Eligible/Sections") as Control
	for node: Node in scope.find_children("*", "ForgeExtractionItemCard", true, false):
		if not String(node.get_meta(&"item_id", "")).is_empty(): result.append(node as Button)
	result.sort_custom(func(left: Button, right: Button) -> bool: return String(left.get_meta(&"item_id", "")) < String(right.get_meta(&"item_id", "")))
	return result


func _eligible_extraction_card(panel: TerminalExtractionPanel, item_id: String) -> Button:
	for card: Button in _eligible_extraction_cards(panel):
		if String(card.get_meta(&"item_id", "")) == item_id:
			return card
	return null


func _result_rows(panel: RunResultPanel) -> Array[Button]:
	var result: Array[Button] = []
	for node: Node in panel.find_children("*", "Button", true, false):
		if node.has_meta(&"recap_section_id"): result.append(node as Button)
	return result


func _result_row(panel: RunResultPanel, section_id: StringName, label: String) -> Button:
	for row: Button in _result_rows(panel):
		if row.get_meta(&"recap_section_id", &"") == section_id and String(row.get_meta(&"recap_entry_label", "")) == label: return row
	return null


func _visible_result_actions(panel: RunResultPanel) -> Array[String]:
	var result: Array[String] = []
	for child: Node in panel.get_node("Frame/Content/Footer/Actions").get_children():
		if child is Button and (child as Button).visible: result.append(child.name)
	return result


func _image_is_nonblank(image: Image) -> bool:
	var first := image.get_pixel(0, 0)
	for y: int in range(0, image.get_height(), maxi(1, image.get_height() / 24)):
		for x: int in range(0, image.get_width(), maxi(1, image.get_width() / 24)):
			var sample := image.get_pixel(x, y)
			if absf(sample.r-first.r)+absf(sample.g-first.g)+absf(sample.b-first.b)+absf(sample.a-first.a) > 0.025: return true
	return false


func _sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK or context.update(bytes) != OK: return ""
	return context.finish().hex_encode()


func _unique_strings(values: Array[String]) -> Dictionary:
	var result: Dictionary = {}
	for value: String in values: result[value] = true
	return result


func _mouse_motion(position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = position - root.get_mouse_position()
	root.push_input(event, true)
	await process_frame


func _joy_button(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	var release := event.duplicate() as InputEventJoypadButton
	release.pressed = false
	root.push_input(release, true)
	await process_frame


func _frames(count: int) -> void:
	for _index: int in count: await process_frame


func _assert(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)


func _finish() -> void:
	paused = false
	if _failures.is_empty():
		print("LIVING_FORGE_COMBAT_LOOP_VISUAL_SUMMARY: PASS")
		quit(0)
		return
	for failure: String in _failures: push_error("LIVING_FORGE_COMBAT_LOOP_VISUAL_FAILURE: %s" % failure)
	print("LIVING_FORGE_COMBAT_LOOP_VISUAL_SUMMARY: FAIL (%d failures)" % _failures.size())
	quit(1)
