# Combat HUD Collapse and Primary Focus Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (\`- [ ]\`) syntax for tracking.

**Goal:** Add independently persistent Party and Alerts collapse controls to the combat HUD, preserve complete runtime truth and robust focus/accessibility behavior, and unify focused primary-action styling across Living Forge surfaces.

**Architecture:** Party/Alerts collapse remains HUD presentation state initialized from schema-v3 settings; CombatHudProjection retains complete immutable combat truth and exposes only pure summary accessors. HUD emits one typed preference signal, Main alone persists it through PartyForgeSettingsStore, and the existing responsive/focus/modal systems are extended without altering Batch 1 recruit binding. Primary/Start focus parity is corrected in canonical theme resources and LivingForgeThemeCatalog, never per screen.

**Tech Stack:** Godot 4.7.1 stable mono, typed GDScript, Godot Theme/StyleBoxFlat resources, ConfigFile-backed PartyForgeSettingsStore, PowerShell, Git worktrees, existing focused/unit/integration/schema-2 visual runners.

## Global Constraints

- Work only in \`F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\combat-hud-collapse-primary-focus\` on \`feat/combat-hud-collapse-primary-focus\`.
- Approved design authority is \`docs/superpowers/specs/2026-08-31-combat-hud-collapse-primary-focus-design.md\` at \`c4e29e7537eb700fc2b6c58d0b1afe619f0d8ac1\`.
- Preserve every user-owned worktree and untracked/generated file; never clean, delete, move, reset, or overwrite them.
- Do not fetch, rebase, merge, push, modify \`main\`, or present reconciliation/integration as authorized.
- The combat HUD has two independent collapsible regions: Party and Alerts.
- Persist exact schema-v3 Boolean fields \`hud_party_collapsed\` and \`hud_alerts_collapsed\`; first-run, schema-1 migration, schema-2 migration, missing, and malformed states default to expanded (\`false\`).
- Preserve character-HUD dark-panel opacity, including its 50% default, bounds, migration behavior, and high-contrast semantics.
- Keep collapse preference out of \`RunRulesSnapshot\`, runtime/combat authorities, recovery/replay truth, randomization, and \`CombatHudViewModel.build()\` inputs.
- Preserve Batch 1 \`_refresh_after_actor_binding()\`, \`_flush_actor_binding_refresh()\`, and \`_has_unbound_party_actor()\` behavior and prove no transient \`COMBAT_HUD_UNAVAILABLE\` during recruitment.
- Each Party/Alerts header and \`AlertsTrayAction\` is a real focusable Button with an actual post-layout minimum of 48 by 48 pixels.
- Party collapse controls LeaderCard, Experience, and PartyRegion together; Alerts collapse controls ExpandedAlerts and Overflow.
- Collapsed semantic state uses icon/shape plus text, never color alone.
- New alerts while collapsed update summaries without expanding, stealing focus, or disrupting modal focus ownership.
- Reduced-motion mode creates no collapse tween; no auto-hide or edge popover is permitted.
- \`LivingForgePrimaryButton\` and \`LivingForgeStartButton\` share a filled focused background, explicit focus font color, and semantic focus ring with text contrast at or above 4.5:1 in normal and high-contrast modes.
- No art acquisition/production, geometry, character model, body-hide region, Blender, camera, preview-depth, gameplay balance, seed/randomization, class weighting, onboarding, tactic/gambit, or unrelated UI change.
- Every production slice uses RED/GREEN TDD, focused verification, independent review, and a bounded local commit.
- Intentional rejection-path diagnostics are acceptable only with the exact PASS marker and process exit 0; any parser, loader, import, script, crash, \`TEST_FAILURE\`, or unexpected \`COMBAT_HUD_UNAVAILABLE\` diagnostic fails the gate.
- Exact-head visual evidence, fresh tracked-only qualification, independent reviews, and Jacob's explicit visual approval are required before any reconciliation or integration request.

---

## File and Responsibility Map

### Settings boundary

- Modify \`scripts/settings/party_forge_settings.gd\`: schema version, supported prior-version constants, two Boolean fields, copy/normalization ownership.
- Modify \`scripts/settings/party_forge_settings_store.gd\`: typed schema 1/2/3 load, expanded migration defaults, exact two-field atomic save.
- Modify \`tests/unit/test_party_forge_settings.gd\`: defaults, copy, migration, round-trip, malformed/missing/future schema, save failure, opacity retention.

### Runtime truth boundary

- Modify \`scripts/ui/hud/combat_hud_projection.gd\`: pure defensive leader/severity summary accessors only; no collapse fields.
- Modify \`tests/unit/test_combat_hud_projection.gd\`: exact leader/count/precedence/clear/copy contracts.
- Modify \`tests/unit/test_combat_hud_view_model.gd\`: prove current deterministic alert order feeds the summary accessors unchanged.

### HUD presentation boundary

- Modify \`scenes/ui/hud.tscn\`: PartyHeader, AlertRegion/Header, AlertsTrayAction, non-interactive visual children, stable existing content paths.
- Modify \`scripts/ui/hud.gd\`: independent state, header presentation, persistent tray entry, preference signal, focus suspension/restoration, disclosure motion, layout reflow.
- Modify \`tests/unit/test_combat_hud.gd\`: state, visibility, summaries, dynamic refresh, focus eligibility, opacity and recruit-defer preservation.

### Persistence composition boundary

- Modify \`scripts/game/main.gd\`: connect HUD preference signal, save a settings copy, update authoritative in-memory settings only after success.
- Modify \`tests/unit/test_main_wiring.gd\`: signal wiring, exact-field persistence, successful reload, failed-save behavior, later-run restore.

### Responsive/input/accessibility boundary

- Modify \`scripts/ui/hud/combat_hud_responsive_layout.gd\`: measured Party header reservation while preserving existing optional-call compatibility.
- Modify \`tests/unit/test_combat_hud_responsive_layout.gd\`: header-height fit calculations and retained party thresholds.
- Modify \`tests/integration/combat_hud_input_runner.gd\`: authentic mouse/keyboard/controller toggles, focus restoration/fallback, tray/modal ownership.
- Modify \`tests/integration/combat_hud_party_scale_runner.gd\`: 1/6/7/20/24 party geometry in four collapse combinations.
- Modify \`tests/integration/combat_loop_responsive_runner.gd\`: viewport/UI/Text matrices and alert budgets.
- Modify \`tests/integration/combat_loop_accessibility_runner.gd\`: 48px targets, semantic names, hidden-descendant exclusion, icon+text, reduced motion.

### Theme boundary

- Modify \`data/ui/living_forge/living_forge_theme.tres\`: canonical normal primary focused fill/font/ring.
- Modify \`data/ui/living_forge/living_forge_high_contrast_theme.tres\`: canonical high-contrast primary focused fill/font/ring.
- Modify \`scripts/ui/living_forge/living_forge_theme_catalog.gd\`: copy the complete primary state contract to Start and scale both.
- Modify \`tests/unit/test_living_forge_theme.gd\`: focused text/ring contrast and Primary/Start semantic parity.
- Modify \`tests/unit/test_class_selection_panel.gd\`, \`test_terminal_extraction_panel.gd\`, \`test_run_result_panel.gd\`, \`test_level_up_targeting_ui.gd\`, and \`test_living_forge_components.gd\`: real-screen/control inheritance, with no local overrides.

### Qualification boundary

- Modify \`tests/integration/living_forge_combat_loop_visual_evidence_runner.gd\`: expand the schema-2 contract from 45 to 58 exact captures.
- Replace exact contents under \`docs/validation/screenshots/living-forge-combat-loop/\`: 58 PNGs plus schema-2 manifest bound to the clean candidate source head.
- Create \`docs/verification/2026-08-31-combat-hud-collapse-primary-focus.md\`: exact commands, hashes, markers, reviews, drift, rollback, and approval status.

## Fixed Cross-Task Interfaces

These names and types are authoritative throughout this plan:

~~~gdscript
# scripts/settings/party_forge_settings.gd
const SCHEMA_VERSION := 3
const SUPPORTED_SCHEMA_VERSIONS: Array[int] = [1, 2, 3]
var hud_party_collapsed := false
var hud_alerts_collapsed := false

# scripts/ui/hud/combat_hud_projection.gd
const NO_ALERT_SEVERITY := -1
func leader() -> PartyMemberHudProjection
func alert_count_for(severity: CombatAlertProjection.Severity) -> int
func highest_alert_severity() -> int
func highest_severity_alert() -> CombatAlertProjection

# scripts/ui/hud.gd
signal collapse_preferences_changed(party_collapsed: bool, alerts_collapsed: bool)
func party_collapsed() -> bool
func alerts_collapsed() -> bool
func apply_collapse_preferences(party_value: bool, alerts_value: bool) -> void
func restore_focus_descriptor(descriptor: Dictionary, allow_global_fallback: bool = true) -> bool

# scripts/game/main.gd
func _on_hud_collapse_preferences_changed(party_collapsed: bool, alerts_collapsed: bool) -> void

# scripts/ui/hud/combat_hud_responsive_layout.gd
static func resolve(
	viewport_size: Vector2i,
	ui_scale_percent: int,
	text_scale_percent: int,
	party_count: int,
	party_header_height: float = 0.0,
) -> Metrics
~~~

No later task may rename, widen, or repurpose these interfaces without returning to the approved design/plan gate.

## Per-Task Review Protocol

Before each Task 1-8 commit, an independent code reviewer must inspect only that task's bounded diff against the approved spec and fixed interfaces. A finding returns to the task's RED assertion and minimal GREEN repair; rerun the named focused gates and obtain an APPROVED verdict before committing. Task 9 separates requirements, code-quality, automated-evidence, UI/UX, and Jacob verdicts.

### Task 1: Settings Schema v3 and Safe Migration

**Files:**

- Modify: \`scripts/settings/party_forge_settings.gd:6-90\`
- Modify: \`scripts/settings/party_forge_settings_store.gd:1-119\`
- Test: \`tests/unit/test_party_forge_settings.gd:1-356\`

**Interfaces:**

- Consumes: existing schema-2 opacity field and atomic ConfigFile promotion.
- Produces: \`SCHEMA_VERSION = 3\`, \`SUPPORTED_SCHEMA_VERSIONS = [1, 2, 3]\`, \`hud_party_collapsed: bool\`, and \`hud_alerts_collapsed: bool\`.

- [ ] **Step 1: Add exact RED settings cases**

Add \`_test_hud_collapse_preferences()\` to the suite run list and implement:

~~~gdscript
func _test_hud_collapse_preferences(failures: Array[String]) -> void:
	var defaults := PartyForgeSettings.new()
	TestAssertions.equal([defaults.hud_party_collapsed, defaults.hud_alerts_collapsed], [false, false], "HUD regions default expanded", failures)
	var copied := defaults.copy()
	copied.hud_party_collapsed = true
	copied.hud_alerts_collapsed = true
	TestAssertions.equal([copied.hud_party_collapsed, copied.hud_alerts_collapsed], [true, true], "copy retains independent HUD collapse preferences", failures)

	var store := PartyForgeSettingsStore.new()
	var path := "user://party_forge_settings_hud_collapse_v3.cfg"
	TestAssertions.equal(store.save_settings(copied, path), "", "schema-three HUD preferences save", failures)
	var loaded := store.load_settings(path)
	TestAssertions.equal([loaded.schema_version, loaded.hud_party_collapsed, loaded.hud_alerts_collapsed], [3, true, true], "schema-three HUD preferences round trip", failures)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	for version: int in [1, 2]:
		path = "user://party_forge_settings_hud_collapse_v%d.cfg" % version
		var legacy := ConfigFile.new()
		legacy.set_value("settings", "schema_version", version)
		legacy.set_value("settings", "character_hud_background_opacity_percent", 35)
		legacy.save(path)
		loaded = store.load_settings(path)
		TestAssertions.equal([loaded.schema_version, loaded.hud_party_collapsed, loaded.hud_alerts_collapsed], [3, false, false], "schema %d migrates HUD regions expanded" % version, failures)
		TestAssertions.equal(loaded.character_hud_background_opacity_percent, 50 if version == 1 else 35, "schema %d preserves the exact opacity migration contract" % version, failures)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	path = "user://party_forge_settings_hud_collapse_malformed.cfg"
	var malformed := ConfigFile.new()
	malformed.set_value("settings", "schema_version", 3)
	malformed.set_value("settings", "hud_party_collapsed", "true")
	malformed.set_value("settings", "hud_alerts_collapsed", 1)
	malformed.save(path)
	loaded = store.load_settings(path)
	TestAssertions.equal([loaded.hud_party_collapsed, loaded.hud_alerts_collapsed], [false, false], "malformed HUD collapse values fail expanded", failures)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
~~~

Extend the existing failed-promotion test so a previously saved \`[true, false]\` pair survives a rejected replacement.

- [ ] **Step 2: Run RED**

~~~powershell
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
& $godot --headless --path (Get-Location).Path --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_party_forge_settings.gd
~~~

Expected: exit 1 and \`TEST_SUMMARY: FAIL\` because the schema and two properties do not exist. No parser or script error is acceptable.

- [ ] **Step 3: Implement the minimal schema/store change**

In \`PartyForgeSettings\`, replace the schema constants, add the two fields, and copy them:

~~~gdscript
const SCHEMA_VERSION := 3
const SUPPORTED_SCHEMA_VERSIONS: Array[int] = [1, 2, 3]

var hud_party_collapsed := false
var hud_alerts_collapsed := false

func copy() -> PartyForgeSettings:
	var result := PartyForgeSettings.new()
	result.hud_party_collapsed = hud_party_collapsed
	result.hud_alerts_collapsed = hud_alerts_collapsed
	return result
~~~

Insert the two new assignments immediately before the existing `return result`; leave every pre-existing copy assignment byte-identical.

In the store, validate against \`SUPPORTED_SCHEMA_VERSIONS\`, read only typed schema-3 values, and always write both:

~~~gdscript
if loaded_version not in PartyForgeSettings.SUPPORTED_SCHEMA_VERSIONS:
	push_error("PARTY_FORGE_SETTINGS_VERSION_ERROR path=%s version=%d supported=%d" % [path, loaded_version, PartyForgeSettings.SCHEMA_VERSION])
	return result
result.schema_version = PartyForgeSettings.SCHEMA_VERSION
if loaded_version >= 3:
	var party_collapsed_value: Variant = config.get_value(SECTION, "hud_party_collapsed", false)
	var alerts_collapsed_value: Variant = config.get_value(SECTION, "hud_alerts_collapsed", false)
	result.hud_party_collapsed = bool(party_collapsed_value) if typeof(party_collapsed_value) == TYPE_BOOL else false
	result.hud_alerts_collapsed = bool(alerts_collapsed_value) if typeof(alerts_collapsed_value) == TYPE_BOOL else false

config.set_value(SECTION, "hud_party_collapsed", normalized.hud_party_collapsed)
config.set_value(SECTION, "hud_alerts_collapsed", normalized.hud_alerts_collapsed)
~~~

Keep the existing \`loaded_version >= 2\` opacity branch unchanged.

- [ ] **Step 4: Run GREEN and retained settings gates**

~~~powershell
& $godot --headless --path (Get-Location).Path --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_party_forge_settings.gd tests/unit/test_settings_screen.gd tests/unit/test_run_rules_policies.gd
~~~

Expected: exit 0 and \`TEST_SUMMARY: PASS (0 failures)\`; schema 1/2 migration, opacity, settings screen, and run-rule isolation remain green.

- [ ] **Step 5: Review and commit**

Verify no \`RunRulesSnapshot\` or gameplay file changed, then:

~~~powershell
git diff --check
git add -- scripts/settings/party_forge_settings.gd scripts/settings/party_forge_settings_store.gd tests/unit/test_party_forge_settings.gd
git commit -m "feat: persist combat HUD collapse preferences"
~~~

### Task 2: Pure Projection Summary Accessors

**Files:**

- Modify: \`scripts/ui/hud/combat_hud_projection.gd:1-114\`
- Test: \`tests/unit/test_combat_hud_projection.gd:1-60\`
- Test: \`tests/unit/test_combat_hud_view_model.gd:1-248\`

**Interfaces:**

- Consumes: defensively owned \`_members\` and \`_all_alerts\`.
- Produces: the four fixed projection accessors and \`NO_ALERT_SEVERITY\`; no persisted/collapse property.

- [ ] **Step 1: Add exact RED projection cases**

Create a projection with a leader, follower, two critical alerts, one downed alert, and one dead alert. Assert:

~~~gdscript
var leader := projection.leader()
TestAssertions.equal([leader.member_id, leader.display_name, leader.health, leader.max_health], [1, "Mira", 72.0, 100.0], "summary exposes defensive leader truth", failures)
TestAssertions.equal([
	projection.alert_count_for(CombatAlertProjection.Severity.CRITICAL),
	projection.alert_count_for(CombatAlertProjection.Severity.DOWNED),
	projection.alert_count_for(CombatAlertProjection.Severity.DEAD),
], [2, 1, 1], "summary counts every exact severity", failures)
TestAssertions.equal(projection.highest_alert_severity(), CombatAlertProjection.Severity.DEAD, "dead outranks downed and critical", failures)
TestAssertions.equal(projection.highest_severity_alert().stable_id, &"dead:004", "highest summary selects the first exact highest-severity alert", failures)
leader.display_name = "mutated"
TestAssertions.equal(projection.leader().display_name, "Mira", "leader accessor returns a defensive copy", failures)
~~~

Add an empty-alert projection assertion: highest severity is \`NO_ALERT_SEVERITY\`, highest alert is null, and every count is zero. In the view-model suite, assert the current ordered \`all_alerts\` set produces the same highest accessor without changing its existing order.

- [ ] **Step 2: Run RED**

~~~powershell
& $godot --headless --path (Get-Location).Path --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_combat_hud_projection.gd tests/unit/test_combat_hud_view_model.gd
~~~

Expected: exit 1 and missing-method failures for \`leader\`, \`alert_count_for\`, \`highest_alert_severity\`, and \`highest_severity_alert\`.

- [ ] **Step 3: Implement pure accessors**

~~~gdscript
const NO_ALERT_SEVERITY := -1

func leader() -> PartyMemberHudProjection:
	for member: PartyMemberHudProjection in _members:
		if member != null and member.is_leader:
			return member.copy()
	return null

func alert_count_for(severity: CombatAlertProjection.Severity) -> int:
	var count := 0
	for alert: CombatAlertProjection in _all_alerts:
		if alert != null and alert.severity == severity:
			count += 1
	return count

func highest_alert_severity() -> int:
	var highest := NO_ALERT_SEVERITY
	for alert: CombatAlertProjection in _all_alerts:
		if alert != null and _severity_rank(alert.severity) > _severity_rank(highest):
			highest = alert.severity
	return highest

func highest_severity_alert() -> CombatAlertProjection:
	var highest := highest_alert_severity()
	if highest == NO_ALERT_SEVERITY:
		return null
	for alert: CombatAlertProjection in _all_alerts:
		if alert != null and alert.severity == highest:
			return alert.copy()
	return null

static func _severity_rank(severity: int) -> int:
	match severity:
		CombatAlertProjection.Severity.DEAD: return 3
		CombatAlertProjection.Severity.DOWNED: return 2
		CombatAlertProjection.Severity.CRITICAL: return 1
	return 0
~~~

Do not modify \`CombatHudViewModel.build()\` parameters or add collapse state to either runtime class.

- [ ] **Step 4: Run GREEN**

~~~powershell
& $godot --headless --path (Get-Location).Path --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_combat_hud_projection.gd tests/unit/test_combat_hud_view_model.gd
~~~

Expected: exit 0 and \`TEST_SUMMARY: PASS (0 failures)\`; existing complete-alert ordering and defensive-copy tests remain green.

- [ ] **Step 5: Review and commit**

~~~powershell
git diff --check
git add -- scripts/ui/hud/combat_hud_projection.gd tests/unit/test_combat_hud_projection.gd tests/unit/test_combat_hud_view_model.gd
git commit -m "feat: derive combat HUD collapse summaries"
~~~

### Task 3: HUD Header Skeleton and Independent State

**Files:**

- Modify: \`scenes/ui/hud.tscn:31-230\`
- Modify: \`scripts/ui/hud.gd:1-180,296-377\`
- Test: \`tests/unit/test_combat_hud.gd:1-435\`

**Interfaces:**

- Consumes: schema-v3 settings fields and existing stable content node paths.
- Produces: \`collapse_preferences_changed\`, the three fixed public HUD methods, \`PartyHeader\`, \`AlertRegion/Header\`, and \`AlertRegion/AlertsTrayAction\`.

- [ ] **Step 1: Add RED scene/state tests**

Add assertions after a configured real HUD fixture:

~~~gdscript
var party_header := hud.get_node_or_null("Margin/CombatStatus/PartyHeader") as Button
var alerts_header := hud.get_node_or_null("Margin/CombatStatus/AlertRegion/Header") as Button
var tray_action := hud.get_node_or_null("Margin/CombatStatus/AlertRegion/AlertsTrayAction") as Button
TestAssertions.truthy(party_header != null and alerts_header != null and tray_action != null, "HUD exposes both headers and persistent tray action", failures)
TestAssertions.truthy(party_header.focus_mode == Control.FOCUS_ALL and alerts_header.focus_mode == Control.FOCUS_ALL, "both headers are focusable", failures)
hud.apply_collapse_preferences(true, false)
TestAssertions.equal([hud.party_collapsed(), hud.alerts_collapsed()], [true, false], "Party collapses independently", failures)
TestAssertions.falsy((hud.get_node("Margin/CombatStatus/LeaderCard") as Control).visible, "Party collapse hides leader", failures)
TestAssertions.falsy((hud.get_node("Margin/CombatStatus/Experience") as Control).visible, "Party collapse hides XP", failures)
TestAssertions.falsy((hud.get_node("Margin/CombatStatus/PartyRegion") as Control).visible, "Party collapse hides roster", failures)
TestAssertions.truthy((hud.get_node("Margin/CombatStatus/AlertRegion/ExpandedAlerts") as Control).visible, "Party collapse leaves Alerts expanded", failures)
~~~

Also configure with saved \`[false, true]\`, assert only alert cards/Overflow are hidden, call \`apply_visual_settings()\`, and assert the 50% member-card background contract remains unchanged.

- [ ] **Step 2: Run RED**

~~~powershell
& $godot --headless --path (Get-Location).Path --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_combat_hud.gd
~~~

Expected: exit 1 because the three nodes, signal, and state API are absent.

- [ ] **Step 3: Add exact scene nodes**

Add a direct \`PartyHeader\` Button before LeaderCard and two AlertRegion controls before ExpandedAlerts:

~~~ini
[node name="PartyHeader" type="Button" parent="Margin/CombatStatus"]
custom_minimum_size = Vector2(424, 48)
layout_mode = 0
offset_left = 16.0
offset_top = 16.0
offset_right = 440.0
offset_bottom = 64.0
focus_mode = 2
theme_type_variation = &"LivingForgeSecondaryButton"
text = ""
accessibility_name = "Party expanded"

[node name="Content" type="HBoxContainer" parent="Margin/CombatStatus/PartyHeader"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2

[node name="DisclosureGlyph" type="Label" parent="Margin/CombatStatus/PartyHeader/Content"]
layout_mode = 2
text = "▾"
mouse_filter = 2

[node name="Summary" type="Label" parent="Margin/CombatStatus/PartyHeader/Content"]
layout_mode = 2
size_flags_horizontal = 3
text = "PARTY"
autowrap_mode = 2
mouse_filter = 2

[node name="LeaderHealth" type="ProgressBar" parent="Margin/CombatStatus/PartyHeader/Content"]
visible = false
custom_minimum_size = Vector2(96, 16)
layout_mode = 2
show_percentage = false
mouse_filter = 2

[node name="Header" type="Button" parent="Margin/CombatStatus/AlertRegion"]
custom_minimum_size = Vector2(272, 48)
focus_mode = 2
theme_type_variation = &"LivingForgeSecondaryButton"
text = ""
accessibility_name = "Alerts expanded"

[node name="AlertsTrayAction" type="Button" parent="Margin/CombatStatus/AlertRegion"]
visible = false
custom_minimum_size = Vector2(192, 48)
focus_mode = 0
theme_type_variation = &"LivingForgeSecondaryButton"
text = "VIEW ALL ALERTS (0)"
accessibility_name = "View all combat alerts"

[node name="Content" type="HBoxContainer" parent="Margin/CombatStatus/AlertRegion/Header"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
mouse_filter = 2

[node name="DisclosureGlyph" type="Label" parent="Margin/CombatStatus/AlertRegion/Header/Content"]
layout_mode = 2
text = "▾"
mouse_filter = 2

[node name="Summary" type="Label" parent="Margin/CombatStatus/AlertRegion/Header/Content"]
layout_mode = 2
size_flags_horizontal = 3
text = "ALERTS · ALL CLEAR"
autowrap_mode = 2
mouse_filter = 2
~~~

- [ ] **Step 4: Implement independent state without persistence**

Add the fixed signal/API and internal setters:

~~~gdscript
signal collapse_preferences_changed(party_collapsed: bool, alerts_collapsed: bool)

var _party_collapsed := false
var _alerts_collapsed := false

func party_collapsed() -> bool:
	return _party_collapsed

func alerts_collapsed() -> bool:
	return _alerts_collapsed

func apply_collapse_preferences(party_value: bool, alerts_value: bool) -> void:
	_set_party_collapsed(party_value, false)
	_set_alerts_collapsed(alerts_value, false)

func _set_party_collapsed(value: bool, user_initiated: bool) -> void:
	if _party_collapsed == value:
		return
	_party_collapsed = value
	for path: NodePath in [^"Margin/CombatStatus/LeaderCard", ^"Margin/CombatStatus/Experience", ^"Margin/CombatStatus/PartyRegion"]:
		(get_node(path) as Control).visible = not value
	_present_region_headers()
	if user_initiated:
		collapse_preferences_changed.emit(_party_collapsed, _alerts_collapsed)

func _set_alerts_collapsed(value: bool, user_initiated: bool) -> void:
	if _alerts_collapsed == value:
		return
	_alerts_collapsed = value
	var expanded := get_node("Margin/CombatStatus/AlertRegion/ExpandedAlerts") as Control
	var overflow := get_node("Margin/CombatStatus/AlertRegion/Overflow") as BaseButton
	expanded.visible = not value
	if value:
		overflow.visible = false
		overflow.disabled = true
		overflow.focus_mode = Control.FOCUS_NONE
	elif current_projection != null:
		_apply_alert_budget()
	_present_region_headers()
	if user_initiated:
		collapse_preferences_changed.emit(_party_collapsed, _alerts_collapsed)
~~~

Connect both header \`pressed\` signals in \`_ensure_control_connections()\`. In \`configure()\` and \`apply_visual_settings()\`, call \`apply_collapse_preferences(settings.hud_party_collapsed, settings.hud_alerts_collapsed)\` after setting \`settings\`. Add a bounded \`_present_region_headers()\` that initially owns only expanded/collapsed labels; Task 5 fills runtime summaries.

- [ ] **Step 5: Run GREEN and Batch 1 regression**

~~~powershell
& $godot --headless --path (Get-Location).Path --quit-after 420 --script res://tests/focused_test_runner.gd -- tests/unit/test_combat_hud.gd tests/unit/test_party_forge_settings.gd
& $godot --headless --path (Get-Location).Path --quit-after 900 --script res://tests/integration/level_up_commit_flow_runner.gd
~~~

Expected: unit \`TEST_SUMMARY: PASS (0 failures)\`, \`LEVEL_UP_COMMIT_FLOW_SUMMARY: PASS (0 failures)\`, both exit 0, and no transient \`COMBAT_HUD_UNAVAILABLE\`.

- [ ] **Step 6: Review and commit**

~~~powershell
git diff --check
git add -- scenes/ui/hud.tscn scripts/ui/hud.gd tests/unit/test_combat_hud.gd
git commit -m "feat: add collapsible combat HUD regions"
~~~

### Task 4: Main-Owned Preference Persistence

**Files:**

- Modify: \`scripts/game/main.gd:68-74,1002-1035,2192-2201\`
- Test: \`tests/unit/test_main_wiring.gd:1-2302\`

**Interfaces:**

- Consumes: HUD \`collapse_preferences_changed(bool, bool)\`, \`saved_settings\`, \`settings_store\`, and \`settings_path\`.
- Produces: exact Main handler \`_on_hud_collapse_preferences_changed(bool, bool) -> void\`.

- [ ] **Step 1: Add RED composition tests**

Use a unique settings path and real HUD signal:

~~~gdscript
var persisted := PartyForgeSettings.new()
persisted.hud_party_collapsed = false
persisted.hud_alerts_collapsed = false
TestAssertions.equal(PartyForgeSettingsStore.new().save_settings(persisted, main.settings_path), "", "fixture saves expanded preferences", failures)
main.saved_settings = persisted.copy()
main.call("_wire_static_ui")
hud.collapse_preferences_changed.emit(true, false)
var loaded := PartyForgeSettingsStore.new().load_settings(main.settings_path)
TestAssertions.equal([loaded.hud_party_collapsed, loaded.hud_alerts_collapsed], [true, false], "Main persists exact HUD pair", failures)
TestAssertions.equal([main.saved_settings.hud_party_collapsed, main.saved_settings.hud_alerts_collapsed], [true, false], "Main replaces authoritative settings after successful save", failures)
~~~

Inject \`PartyForgeSettingsStore.new(func(_temporary, _target): return ERR_CANT_CREATE)\`, emit \`[false, true]\`, and assert the prior file and \`main.saved_settings\` remain \`[true, false]\` while HUD session state remains \`[false, true]\`.

- [ ] **Step 2: Run RED**

~~~powershell
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_main_wiring.gd
~~~

Expected: exit 1 because Main does not connect or implement the persistence handler.

- [ ] **Step 3: Implement Main-only persistence**

In \`_wire_static_ui()\`:

~~~gdscript
if not hud.is_connected("collapse_preferences_changed", _on_hud_collapse_preferences_changed):
	hud.connect("collapse_preferences_changed", _on_hud_collapse_preferences_changed)
~~~

Add:

~~~gdscript
func _on_hud_collapse_preferences_changed(party_collapsed: bool, alerts_collapsed: bool) -> void:
	if settings_store == null:
		push_error("PARTY_FORGE_SETTINGS_SAVE_ERROR reason=settings store is missing")
		return
	var candidate := saved_settings.copy() if saved_settings != null else PartyForgeSettings.new()
	candidate.hud_party_collapsed = party_collapsed
	candidate.hud_alerts_collapsed = alerts_collapsed
	var save_error := settings_store.save_settings(candidate, settings_path)
	if not save_error.is_empty():
		push_error(save_error)
		return
	saved_settings = settings_store.load_settings(settings_path).copy()
~~~

Do not call \`HUD.apply_visual_settings()\` here: the authentic header already changed session presentation, and a failed save intentionally leaves that session state visible.

- [ ] **Step 4: Run GREEN and settings-application regressions**

~~~powershell
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_main_wiring.gd tests/unit/test_party_forge_settings.gd tests/unit/test_settings_screen.gd
~~~

Expected: exit 0 and \`TEST_SUMMARY: PASS (0 failures)\`; intentional save-failure diagnostics are captured by the tests and do not become uncaught script errors.

- [ ] **Step 5: Review and commit**

~~~powershell
git diff --check
git add -- scripts/game/main.gd tests/unit/test_main_wiring.gd
git commit -m "feat: persist combat HUD region toggles"
~~~

### Task 5: Collapsed Summaries, Persistent Tray Access, and Dynamic Refresh

**Files:**

- Modify: \`scenes/ui/hud.tscn:31-230\`
- Modify: \`scripts/ui/hud.gd:296-530,610-620\`
- Test: \`tests/unit/test_combat_hud.gd:1-435\`
- Test: \`tests/unit/test_combat_hud_view_model.gd:1-248\`

**Interfaces:**

- Consumes: Task 2 projection accessors and Task 3 header/tray nodes.
- Produces: exact runtime summary copy, icon/text state, and one shared tray-opening path.

- [ ] **Step 1: Add RED summary/dynamic tests**

For a six-member projection containing critical, downed, and dead members, collapse both regions and assert:

~~~gdscript
var party_copy := (hud.get_node("Margin/CombatStatus/PartyHeader/Content/Summary") as Label).text
var alerts_copy := (hud.get_node("Margin/CombatStatus/AlertRegion/Header/Content/Summary") as Label).text
TestAssertions.truthy("PARTY · 6 MEMBERS" in party_copy and "LEADER" in party_copy and "STATE DEAD" in party_copy and "DEAD 1" in party_copy and "DOWNED 1" in party_copy and "CRITICAL 1" in party_copy, "Party summary exposes exact complete truth", failures)
TestAssertions.truthy("ALERTS 3" in alerts_copy and "DEAD" in alerts_copy, "Alerts summary exposes exact highest severity", failures)
var tray_action := hud.get_node("Margin/CombatStatus/AlertRegion/AlertsTrayAction") as Button
TestAssertions.truthy(tray_action.visible and tray_action.focus_mode == Control.FOCUS_ALL and tray_action.text == "VIEW ALL ALERTS (3)", "collapsed tray action remains direct and exact", failures)
~~~

Heal every member and assert \`ALERTS · ALL CLEAR\`, hidden/disabled/\`FOCUS_NONE\` tray action, and no stale severity. While Alerts remains collapsed, damage a healthy member and assert summary/tray update without expansion and without focus change. Recruit a Frost Mage through the existing real binding fixture and assert the Party count updates with no captured \`COMBAT_HUD_UNAVAILABLE\`.

- [ ] **Step 2: Run RED**

~~~powershell
& $godot --headless --path (Get-Location).Path --quit-after 420 --script res://tests/focused_test_runner.gd -- tests/unit/test_combat_hud.gd tests/unit/test_combat_hud_view_model.gd
~~~

Expected: exit 1 because header runtime copy, semantic icons, and persistent tray behavior are not implemented.

- [ ] **Step 3: Implement deterministic header presentation**

Add one semantic icon and one all-clear glyph to each header content row:

~~~tscn
[node name="StateIcon" type="TextureRect" parent="Margin/CombatStatus/PartyHeader/Content"]
visible = false
custom_minimum_size = Vector2(24, 24)
layout_mode = 2
expand_mode = 3
stretch_mode = 5
mouse_filter = 2

[node name="AllClearGlyph" type="Label" parent="Margin/CombatStatus/PartyHeader/Content"]
visible = false
layout_mode = 2
text = "✓"
mouse_filter = 2

[node name="StateIcon" type="TextureRect" parent="Margin/CombatStatus/AlertRegion/Header/Content"]
visible = false
custom_minimum_size = Vector2(24, 24)
layout_mode = 2
expand_mode = 3
stretch_mode = 5
mouse_filter = 2

[node name="AllClearGlyph" type="Label" parent="Margin/CombatStatus/AlertRegion/Header/Content"]
visible = true
layout_mode = 2
text = "✓"
mouse_filter = 2
~~~

Set the exact visual child order to `DisclosureGlyph`, `StateIcon`, `AllClearGlyph`, `Summary`, `LeaderHealth` for Party and `DisclosureGlyph`, `StateIcon`, `AllClearGlyph`, `Summary` for Alerts.

Add these exact constants and helpers:

~~~gdscript
const CRITICAL_STATE_ICON: Texture2D = preload("res://assets/ui/living_forge/icons/tabler-3.46.0/alert-triangle.svg")
const DOWNED_STATE_ICON: Texture2D = preload("res://assets/ui/living_forge/icons/party-forge/downed.svg")
const DEAD_STATE_ICON: Texture2D = preload("res://assets/ui/living_forge/icons/party-forge/dead.svg")

func _severity_label(severity: int) -> String:
	match severity:
		CombatAlertProjection.Severity.DEAD: return "DEAD"
		CombatAlertProjection.Severity.DOWNED: return "DOWNED"
		CombatAlertProjection.Severity.CRITICAL: return "CRITICAL"
	return "ALL CLEAR"

func _severity_icon(severity: int) -> Texture2D:
	match severity:
		CombatAlertProjection.Severity.DEAD: return DEAD_STATE_ICON
		CombatAlertProjection.Severity.DOWNED: return DOWNED_STATE_ICON
		CombatAlertProjection.Severity.CRITICAL: return CRITICAL_STATE_ICON
	return null

func _present_state_cue(icon: TextureRect, all_clear_glyph: Label, severity: int) -> void:
	icon.texture = _severity_icon(severity)
	icon.visible = icon.texture != null
	all_clear_glyph.visible = severity == CombatHudProjection.NO_ALERT_SEVERITY

func _party_accessibility_name() -> String:
	if current_projection == null:
		return "Party unavailable"
	var leader := current_projection.leader()
	var leader_copy := "No leader"
	if leader != null:
		leader_copy = "Leader %s, health %d of %d" % [leader.display_name, roundi(leader.health), roundi(leader.max_health)]
	return "Party, %d members, %s, highest severity %s, dead %d, downed %d, critical %d, %s" % [
		current_projection.members.size(),
		leader_copy,
		_severity_label(current_projection.highest_alert_severity()),
		current_projection.alert_count_for(CombatAlertProjection.Severity.DEAD),
		current_projection.alert_count_for(CombatAlertProjection.Severity.DOWNED),
		current_projection.alert_count_for(CombatAlertProjection.Severity.CRITICAL),
		"collapsed" if _party_collapsed else "expanded",
	]

func _alerts_accessibility_name() -> String:
	if current_projection == null or current_projection.all_alerts.is_empty():
		return "Alerts, all clear, %s" % ("collapsed" if _alerts_collapsed else "expanded")
	var highest := current_projection.highest_severity_alert()
	return "Alerts, %d, highest severity %s, %s, %s" % [
		current_projection.all_alerts.size(),
		_severity_label(highest.severity),
		highest.summary,
		"collapsed" if _alerts_collapsed else "expanded",
	]

func _present_region_headers() -> void:
	var party_header := get_node("Margin/CombatStatus/PartyHeader") as Button
	var alerts_header := get_node("Margin/CombatStatus/AlertRegion/Header") as Button
	var tray_action := get_node("Margin/CombatStatus/AlertRegion/AlertsTrayAction") as Button
	var party_summary := "PARTY"
	var alerts_summary := "ALERTS · ALL CLEAR"
	var highest_severity := CombatHudProjection.NO_ALERT_SEVERITY
	if current_projection != null:
		var leader := current_projection.leader()
		var dead := current_projection.alert_count_for(CombatAlertProjection.Severity.DEAD)
		var downed := current_projection.alert_count_for(CombatAlertProjection.Severity.DOWNED)
		var critical := current_projection.alert_count_for(CombatAlertProjection.Severity.CRITICAL)
		highest_severity = current_projection.highest_alert_severity()
		if leader != null:
			party_summary = "PARTY · %d MEMBERS · LEADER %s · STATE %s · DEAD %d · DOWNED %d · CRITICAL %d" % [current_projection.members.size(), leader.display_name.to_upper(), _severity_label(highest_severity), dead, downed, critical]
			var health := get_node("Margin/CombatStatus/PartyHeader/Content/LeaderHealth") as ProgressBar
			health.max_value = leader.max_health
			health.value = leader.health
			health.visible = _party_collapsed
		var highest := current_projection.highest_severity_alert()
		if highest != null:
			alerts_summary = "ALERTS %d · %s · %s" % [current_projection.all_alerts.size(), _severity_label(highest.severity), highest.summary]
		tray_action.visible = not current_projection.all_alerts.is_empty()
		tray_action.disabled = not tray_action.visible
		tray_action.focus_mode = Control.FOCUS_ALL if tray_action.visible else Control.FOCUS_NONE
		tray_action.text = "VIEW ALL ALERTS (%d)" % current_projection.all_alerts.size()
	party_header.accessibility_name = _party_accessibility_name()
	alerts_header.accessibility_name = _alerts_accessibility_name()
	(get_node("Margin/CombatStatus/PartyHeader/Content/Summary") as Label).text = party_summary
	(get_node("Margin/CombatStatus/AlertRegion/Header/Content/Summary") as Label).text = alerts_summary
	_present_state_cue(get_node("Margin/CombatStatus/PartyHeader/Content/StateIcon") as TextureRect, get_node("Margin/CombatStatus/PartyHeader/Content/AllClearGlyph") as Label, highest_severity)
	_present_state_cue(get_node("Margin/CombatStatus/AlertRegion/Header/Content/StateIcon") as TextureRect, get_node("Margin/CombatStatus/AlertRegion/Header/Content/AllClearGlyph") as Label, highest_severity)
~~~

Call \`_present_region_headers()\` after every successful \`_refresh_projection()\`, after content rebuild/presentation, and after state changes. Do not call it from the invalid-authority path with stale projection.

- [ ] **Step 4: Share the complete tray route**

~~~gdscript
func _on_overflow_pressed() -> void:
	_open_alert_tray(get_node("Margin/CombatStatus/AlertRegion/Overflow") as Control)

func _on_alerts_tray_action_pressed() -> void:
	_open_alert_tray(get_node("Margin/CombatStatus/AlertRegion/AlertsTrayAction") as Control)

func _open_alert_tray(return_focus: Control) -> void:
	if current_projection == null or current_projection.all_alerts.is_empty():
		return
	(get_node("CombatAlertTray") as CombatAlertTray).open(current_projection.all_alerts, return_focus)
~~~

Connect \`AlertsTrayAction.pressed\` in \`_ensure_control_connections()\`. Extend \`focus_descriptor_for()\`, \`restore_focus_descriptor()\`, and \`_named_focus_control()\` with named control \`&"alerts_tray_action"\`.

- [ ] **Step 5: Run GREEN and dynamic invariants**

~~~powershell
& $godot --headless --path (Get-Location).Path --quit-after 420 --script res://tests/focused_test_runner.gd -- tests/unit/test_combat_hud.gd tests/unit/test_combat_hud_projection.gd tests/unit/test_combat_hud_view_model.gd
& $godot --headless --path (Get-Location).Path --quit-after 900 --script res://tests/integration/level_up_commit_flow_runner.gd
~~~

Expected: both commands exit 0; unit \`TEST_SUMMARY: PASS (0 failures)\`; commit-flow PASS; no transient unavailable marker; collapsed Alerts remains collapsed through health/recruit refresh.

- [ ] **Step 6: Review and commit**

~~~powershell
git diff --check
git add -- scenes/ui/hud.tscn scripts/ui/hud.gd tests/unit/test_combat_hud.gd tests/unit/test_combat_hud_view_model.gd
git commit -m "feat: present collapsed combat HUD summaries"
~~~

### Task 6: Focus Restoration, Controller Traversal, Accessibility, and Reduced Motion

**Files:**

- Modify: \`scripts/ui/hud.gd:37-44,204-275,780-980\`
- Modify: \`tests/unit/test_combat_hud.gd:1-435\`
- Modify: \`tests/integration/combat_hud_input_runner.gd:1-467\`
- Modify: \`tests/integration/combat_loop_accessibility_runner.gd:1-689\`

**Interfaces:**

- Consumes: existing stable focus descriptors, Task 3 headers, Task 5 tray action, \`LivingForgeTokens.motion_ms()\`, and existing modal ownership.
- Produces: region-local focus descriptors/mode suspension and glyph-only motion.

- [ ] **Step 1: Add RED focus/input/accessibility scenarios**

Extend the input runner with authentic actions:

1. Mouse-click PartyHeader while a roster member is focused: collapse moves focus to PartyHeader; mouse-click/accept again restores the exact member.
2. Keyboard Enter on Alerts Header while an alert Inspect action is focused: collapse focuses Header; Enter restores exact Inspect when still valid.
3. Resolve that alert while collapsed: expansion falls to the first surviving alert action, then Overflow, or Header for all-clear.
4. Controller D-pad reaches PartyHeader, Alerts Header, and AlertsTrayAction; controller accept toggles/opens; controller Cancel closes the tray to AlertsTrayAction.
5. Open tray/Inspector/Ledger, refresh collapsed summaries behind the modal, and prove focus remains in the topmost modal.
6. Hidden leader/roster/alert/overflow descendants have no focus owner, cannot be reached, and are absent from the accessibility exposure helper.
7. With \`reduced_motion = true\`, header activation creates no active disclosure Tween and reaches the final glyph rotation in the same frame.

Add a unit assertion that programmatic \`apply_collapse_preferences()\` never steals existing modal or external focus.

- [ ] **Step 2: Run RED**

~~~powershell
& $godot --headless --path (Get-Location).Path --quit-after 420 --script res://tests/focused_test_runner.gd -- tests/unit/test_combat_hud.gd
& $godot --headless --path (Get-Location).Path --quit-after 1200 --script res://tests/integration/combat_hud_input_runner.gd
& $godot --path (Get-Location).Path --rendering-method gl_compatibility --quit-after 1200 --script res://tests/integration/combat_loop_accessibility_runner.gd
~~~

Expected: RED names focus restoration, traversal, hidden eligibility, and reduced-motion gaps; no parser/script failure.

- [ ] **Step 3: Implement region-local focus suspension**

Add:

~~~gdscript
const REGION_PARTY: StringName = &"party"
const REGION_ALERTS: StringName = &"alerts"
var _collapsed_focus_descriptors := {REGION_PARTY: {}, REGION_ALERTS: {}}
var _collapsed_focus_modes := {REGION_PARTY: [], REGION_ALERTS: []}
var _disclosure_tweens: Dictionary = {}

func _region_content_roots(region: StringName) -> Array[Control]:
	if region == REGION_PARTY:
		return [
			get_node("Margin/CombatStatus/LeaderCard") as Control,
			get_node("Margin/CombatStatus/Experience") as Control,
			get_node("Margin/CombatStatus/PartyRegion") as Control,
		]
	return [
		get_node("Margin/CombatStatus/AlertRegion/ExpandedAlerts") as Control,
		get_node("Margin/CombatStatus/AlertRegion/Overflow") as Control,
	]

func _suspend_region_focus(region: StringName) -> void:
	var entries: Array = []
	for root: Control in _region_content_roots(region):
		var controls: Array[Control] = [root]
		for node: Node in root.find_children("*", "Control", true, false):
			if node is Control:
				controls.append(node as Control)
		for control: Control in controls:
			if control.focus_mode != Control.FOCUS_NONE:
				entries.append({"control": control, "focus_mode": control.focus_mode})
				control.focus_mode = Control.FOCUS_NONE
	_collapsed_focus_modes[region] = entries

func _restore_region_focus_modes(region: StringName) -> void:
	for entry: Dictionary in _collapsed_focus_modes[region] as Array:
		var control := entry.get("control") as Control
		if control != null and is_instance_valid(control):
			control.focus_mode = int(entry.get("focus_mode", Control.FOCUS_NONE))
	_collapsed_focus_modes[region] = []

func _region_header(region: StringName) -> Button:
	if region == REGION_PARTY:
		return get_node("Margin/CombatStatus/PartyHeader") as Button
	return get_node("Margin/CombatStatus/AlertRegion/Header") as Button

func _region_contains_control(region: StringName, control: Control) -> bool:
	if control == null or not is_instance_valid(control):
		return false
	for root: Control in _region_content_roots(region):
		if control == root or root.is_ancestor_of(control):
			return true
	return false

func _prepare_region_collapse(region: StringName, user_initiated: bool) -> void:
	if user_initiated and not _child_modal_owns_focus():
		var owner := _hud_viewport().gui_get_focus_owner() as Control
		if _region_contains_control(region, owner):
			_collapsed_focus_descriptors[region] = focus_descriptor_for(owner)
			_region_header(region).grab_focus()
	_suspend_region_focus(region)

func _finish_region_expand(region: StringName, user_initiated: bool) -> void:
	_restore_region_focus_modes(region)
	if user_initiated:
		call_deferred("_restore_region_focus", region)

func _restore_region_focus(region: StringName) -> void:
	if _child_modal_owns_focus():
		return
	var descriptor := _collapsed_focus_descriptors.get(region, {}) as Dictionary
	if not descriptor.is_empty() and restore_focus_descriptor(descriptor, false):
		return
	if region == REGION_PARTY and current_projection != null:
		var leader := current_projection.leader()
		if leader != null and _focus_member(leader.member_id, &"leader_anchor"):
			return
		for member: PartyMemberHudProjection in current_projection.members:
			if _focus_member(member.member_id, &"roster_member"):
				return
	elif region == REGION_ALERTS and current_projection != null:
		for alert: CombatAlertProjection in current_projection.visible_alerts:
			if _grab_valid_focus(_alert_action_control(alert.stable_id, &"inspect")):
				return
		if _grab_valid_focus(get_node("Margin/CombatStatus/AlertRegion/Overflow") as Control):
			return
	_grab_valid_focus(_region_header(region))
~~~

Change \`restore_focus_descriptor()\` to the fixed optional-argument signature. When \`allow_global_fallback\` is \`false\`, return \`false\` at the point where the current method would fall through to Overflow, a neighboring alert, a party member, or \`_focus_named_safe_control()\`; exact descriptor resolution remains unchanged. Existing one-argument callers retain current behavior.

In each \`_set_*_collapsed()\` method, call \`_prepare_region_collapse(region, user_initiated)\` immediately before hiding content when \`value\` is \`true\`; call \`_finish_region_expand(region, user_initiated)\` immediately after revealing content when \`value\` is \`false\`. After any collapsed roster or alert rebuild, call \`_restore_region_focus_modes(region)\` and then \`_suspend_region_focus(region)\` so each live control is stored exactly once.

- [ ] **Step 4: Implement glyph-only motion**

~~~gdscript
func _present_disclosure(region: StringName, glyph: Label, collapsed: bool) -> void:
	var target_rotation := 0.0 if collapsed else PI / 2.0
	var prior := _disclosure_tweens.get(region) as Tween
	if prior != null and prior.is_valid():
		prior.kill()
	if settings == null or settings.reduced_motion:
		glyph.rotation = target_rotation
		_disclosure_tweens.erase(region)
		return
	var tween := create_tween()
	_disclosure_tweens[region] = tween
	tween.tween_property(glyph, "rotation", target_rotation, float(LivingForgeTokens.motion_ms(&"focus", false)) / 1000.0)
~~~

Content visibility remains atomic; no content-position/opacity tween is permitted.

- [ ] **Step 5: Run GREEN**

~~~powershell
& $godot --headless --path (Get-Location).Path --quit-after 420 --script res://tests/focused_test_runner.gd -- tests/unit/test_combat_hud.gd
& $godot --headless --path (Get-Location).Path --quit-after 1200 --script res://tests/integration/combat_hud_input_runner.gd
& $godot --path (Get-Location).Path --rendering-method gl_compatibility --quit-after 1200 --script res://tests/integration/combat_loop_accessibility_runner.gd
~~~

Expected: unit PASS, \`COMBAT_HUD_INPUT_SUMMARY: PASS\`, \`COMBAT_LOOP_ACCESSIBILITY_SUMMARY: PASS\`, all exit 0.

- [ ] **Step 6: Review and commit**

Independently inspect every focus-mode mutation against terminal modal suspension and dynamic member/alert rebuilds, then:

~~~powershell
git diff --check
git add -- scripts/ui/hud.gd tests/unit/test_combat_hud.gd tests/integration/combat_hud_input_runner.gd tests/integration/combat_loop_accessibility_runner.gd
git commit -m "fix: preserve combat HUD collapse focus"
~~~

### Task 7: Responsive Layout and Text150 Matrices

**Files:**

- Modify: \`scripts/ui/hud/combat_hud_responsive_layout.gd:1-92\`
- Modify: \`scripts/ui/hud.gd:296-377,481-530\`
- Modify: \`scenes/ui/hud.tscn:31-230\`
- Test: \`tests/unit/test_combat_hud_responsive_layout.gd:1-105\`
- Test: \`tests/integration/combat_hud_party_scale_runner.gd:1-379\`
- Test: \`tests/integration/combat_loop_responsive_runner.gd:1-973\`

**Interfaces:**

- Consumes: fixed five-argument \`CombatHudResponsiveLayout.resolve()\` and measured header minimum sizes.
- Produces: contained, non-overlapping expanded/collapsed geometry at every supported scale.

- [ ] **Step 1: Add RED pure-layout cases**

For viewport \`1280x720\`, party 24, UI/Text pairs \`[80,150]\`, \`[100,150]\`, and \`[150,150]\`, compare header heights 0 and 72:

~~~gdscript
var without_header := CombatHudResponsiveLayout.resolve(Vector2i(1280, 720), ui, text, 24, 0.0)
var with_header := CombatHudResponsiveLayout.resolve(Vector2i(1280, 720), ui, text, 24, 72.0)
TestAssertions.equal(with_header.mode, CombatHudResponsiveLayout.Mode.COMPACT, "Text150 with header remains compact", failures)
TestAssertions.truthy(with_header.visible_member_count <= without_header.visible_member_count, "header reservation never overstates visible members", failures)
TestAssertions.truthy(with_header.visible_member_count >= 1 and with_header.page_count >= 1, "header reservation remains bounded", failures)
~~~

Retain existing no-fifth-argument calls to prove default compatibility.

- [ ] **Step 2: Add RED integration matrices**

Exercise parties 1, 6, 7, 20, 24; alerts 0, 1, 3, 7; collapse states \`[false,false]\`, \`[true,false]\`, \`[false,true]\`, \`[true,true]\`; viewports 1280x720, 1920x1080, 2560x1440, 3440x1440; and supported UI/Text stress corners. Assert:

- both headers and tray action are contained and at least 48x48 when visible;
- collapsed summary labels and leader health bar are enclosed;
- Party header/leader/XP/roster never overlap timer or Alerts;
- Alerts header/tray/cards/Overflow never overlap each other;
- Text150 wraps rather than clips;
- exact alert budget and compact paging remain truthful.

- [ ] **Step 3: Run RED**

~~~powershell
& $godot --headless --path (Get-Location).Path --quit-after 420 --script res://tests/focused_test_runner.gd -- tests/unit/test_combat_hud_responsive_layout.gd
& $godot --path (Get-Location).Path --rendering-method gl_compatibility --quit-after 1200 --script res://tests/integration/combat_hud_party_scale_runner.gd
& $godot --path (Get-Location).Path --rendering-method gl_compatibility --quit-after 1200 --script res://tests/integration/combat_loop_responsive_runner.gd
~~~

Expected: RED identifies exact header reservation, containment, or alert-budget gaps.

- [ ] **Step 4: Implement measured reservation/reflow**

Extend \`resolve()\` and both height calculations:

~~~gdscript
static func resolve(viewport_size: Vector2i, ui_scale_percent: int, text_scale_percent: int, party_count: int, party_header_height: float = 0.0) -> Metrics:
	var normalized_ui_scale := _normalized_scale(ui_scale_percent)
	var normalized_text_scale := _normalized_scale(text_scale_percent)
	var normalized_party_count := clampi(party_count, 1, MAX_PARTY_COUNT)
	var rich_card_size := _resolved_rich_card_size(normalized_ui_scale, normalized_text_scale)
	var rich_columns := _rich_columns(viewport_size, rich_card_size)
	var reserved_header := maxf(party_header_height, 0.0)
	var rich := normalized_party_count <= 6 and _rich_followers_fit(viewport_size, normalized_party_count - 1, rich_card_size, rich_columns, reserved_header)
	var visible := normalized_party_count if rich else clampi(_compact_visible_count(viewport_size, normalized_ui_scale, normalized_text_scale, reserved_header), 1, normalized_party_count)
	var pages := maxi(1, ceili(float(normalized_party_count) / float(visible)))
	return Metrics.create(Mode.RICH if rich else Mode.COMPACT, visible, rich_columns if rich else _compact_columns(viewport_size), pages)

static func _rich_followers_fit(viewport_size: Vector2i, follower_count: int, card_size: Vector2, columns: int, party_header_height: float) -> bool:
	if follower_count <= 0:
		return true
	var available_width := maxf(1.0, float(viewport_size.x) * 0.5 - PARTY_REGION_HORIZONTAL_INSET)
	var available_height := _available_party_height(viewport_size, PARTY_REGION_VERTICAL_INSET, party_header_height)
	var used_columns := mini(columns, follower_count)
	var rows := ceili(float(follower_count) / float(columns))
	var required_width := card_size.x * used_columns + RICH_HORIZONTAL_SEPARATION * maxi(0, used_columns - 1)
	var required_height := card_size.y * rows + RICH_VERTICAL_SEPARATION * maxi(0, rows - 1)
	return required_width <= available_width and required_height <= available_height

static func _compact_visible_count(viewport_size: Vector2i, ui_scale_percent: int, text_scale_percent: int, party_header_height: float) -> int:
	var ui_scale := float(ui_scale_percent) / 100.0
	var text_scale := float(text_scale_percent) / 100.0
	var row_scale := maxf(ui_scale, text_scale)
	var available_height := _available_party_height(viewport_size, 132.0 * ui_scale, party_header_height)
	var row_height := 84.0 * row_scale
	var rows := clampi(floori(available_height / row_height), MIN_COMPACT_ROWS, MAX_COMPACT_ROWS)
	if viewport_size.y <= 720 and text_scale_percent >= 150:
		rows = mini(rows, 3)
	return rows * _compact_columns(viewport_size)

static func _available_party_height(viewport_size: Vector2i, base_inset: float, party_header_height: float) -> float:
	return maxf(1.0, float(viewport_size.y) - base_inset - maxf(party_header_height, 0.0) - LivingForgeTokens.spacing(&"standard"))
~~~

In HUD, measure \`PartyHeader.get_combined_minimum_size().y\`, pass it to \`resolve()\`, place LeaderCard below header plus standard gap, then retain the current leader -> Experience -> PartyRegion chain. Measure Alert Header and optional AlertsTrayAction rows before calculating ExpandedAlerts/Overflow budget.

- [ ] **Step 5: Run GREEN and performance retention**

~~~powershell
& $godot --headless --path (Get-Location).Path --quit-after 420 --script res://tests/focused_test_runner.gd -- tests/unit/test_combat_hud_responsive_layout.gd tests/unit/test_combat_hud.gd
& $godot --path (Get-Location).Path --rendering-method gl_compatibility --quit-after 1200 --script res://tests/integration/combat_hud_party_scale_runner.gd
& $godot --path (Get-Location).Path --rendering-method gl_compatibility --quit-after 1200 --script res://tests/integration/combat_loop_responsive_runner.gd
& $godot --path (Get-Location).Path --rendering-method gl_compatibility --quit-after 1200 --script res://tests/integration/combat_loop_performance_runner.gd
~~~

Expected: focused unit PASS; party-scale, responsive, and performance summary markers PASS; all exit 0.

- [ ] **Step 6: Review and commit**

~~~powershell
git diff --check
git add -- scripts/ui/hud/combat_hud_responsive_layout.gd scripts/ui/hud.gd scenes/ui/hud.tscn tests/unit/test_combat_hud_responsive_layout.gd tests/integration/combat_hud_party_scale_runner.gd tests/integration/combat_loop_responsive_runner.gd
git commit -m "fix: reflow collapsible combat HUD"
~~~

### Task 8: Shared Primary/Start Focus Theme Parity

**Files:**

- Modify: \`data/ui/living_forge/living_forge_theme.tres:130-175,280-295\`
- Modify: \`data/ui/living_forge/living_forge_high_contrast_theme.tres:130-175,280-300\`
- Modify: \`scripts/ui/living_forge/living_forge_theme_catalog.gd:10-130\`
- Test: \`tests/unit/test_living_forge_theme.gd:210-545\`
- Test: \`tests/unit/test_class_selection_panel.gd:1-180\`
- Test: \`tests/unit/test_terminal_extraction_panel.gd:1-470\`
- Test: \`tests/unit/test_run_result_panel.gd:1-280\`
- Test: \`tests/unit/test_level_up_targeting_ui.gd:1-420\`
- Test: \`tests/unit/test_living_forge_components.gd:330-380\`

**Interfaces:**

- Consumes: semantic \`surface_inset\`, \`ember_primary\`, \`focus_outline\`, existing scale/cache behavior, and real scene theme variations.
- Produces: identical semantic focus signatures for Primary and Start with >=4.5:1 focused text contrast.

- [ ] **Step 1: Replace old outline-only assertions with RED parity assertions**

For normal/high-contrast resolved themes and every supported UI/Text scale:

~~~gdscript
for variation: StringName in [&"LivingForgePrimaryButton", &"LivingForgeStartButton"]:
	var focus := theme.get_stylebox(&"focus", variation) as StyleBoxFlat
	TestAssertions.truthy(focus != null and focus.is_draw_center_enabled(), "%s focus owns a filled center" % variation, failures)
	TestAssertions.truthy(theme.has_color(&"font_focus_color", variation), "%s owns explicit focus text color" % variation, failures)
	var ratio := _contrast_ratio(theme.get_color(&"font_focus_color", variation), focus.bg_color)
	TestAssertions.truthy(ratio >= 4.5, "%s focused text contrast is >=4.5:1 (actual %.3f)" % [variation, ratio], failures)
	TestAssertions.equal(focus.bg_color, theme.get_color(&"surface_inset", &"LivingForgeSemantic"), "%s uses semantic inset focus fill" % variation, failures)
	TestAssertions.equal(focus.border_color, theme.get_color(&"focus_outline", &"LivingForgeSemantic"), "%s uses semantic focus ring" % variation, failures)
~~~

Assert Primary and Start focus geometry/color/font signatures match but are distinct duplicated StyleBox instances. In real-screen tests, focus Start Run, Confirm Extraction, Accept Consequence, run-result Confirm/Retry, level-up Confirm/Retry Offers, and a ForgeActionBar primary; assert each resolves the shared variation contract and has no local focus/font override.

- [ ] **Step 2: Run RED**

~~~powershell
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_living_forge_theme.gd tests/unit/test_class_selection_panel.gd tests/unit/test_terminal_extraction_panel.gd tests/unit/test_run_result_panel.gd tests/unit/test_level_up_targeting_ui.gd tests/unit/test_living_forge_components.gd
~~~

Expected: exit 1 because Primary is outline-only/no explicit focus font in the normal resource and Start currently diverges.

- [ ] **Step 3: Correct both canonical resources**

For each \`Style_primary_focus\`, set:

~~~ini
draw_center = true
bg_color = Color(0.03137255, 0.05098039, 0.07058824, 1)
border_width_left = 4
border_width_top = 4
border_width_right = 4
border_width_bottom = 4
border_color = Color(0.972549, 0.9490196, 0.8745098, 1)
~~~

Use high-contrast token values \`surface_inset = Color(0.0627451, 0.09411765, 0.1254902, 1)\` and \`focus_outline = Color(1,1,1,1)\`, retaining its 5px high-contrast ring. Add \`LivingForgePrimaryButton/colors/font_focus_color\` equal to each resource's \`ember_primary\`.

- [ ] **Step 4: Replace Start-only configuration with shared parity**

Rename \`_configure_start_button()\` to \`_configure_primary_action_variations()\`, call it from \`resolve()\`, and implement:

~~~gdscript
static func _configure_primary_action_variations(theme: Theme) -> void:
	theme.set_type_variation(&"LivingForgeStartButton", &"Button")
	for slot: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus"]:
		var source := theme.get_stylebox(slot, &"LivingForgePrimaryButton")
		if source != null:
			theme.set_stylebox(slot, &"LivingForgeStartButton", source.duplicate())
	for color_name: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color", &"font_focus_color"]:
		theme.set_color(color_name, &"LivingForgeStartButton", theme.get_color(color_name, &"LivingForgePrimaryButton"))
	var font := theme.get_font(&"font", &"LivingForgePrimaryButton")
	if font != null:
		theme.set_font(&"font", &"LivingForgeStartButton", font)
	theme.set_font_size(&"font_size", &"LivingForgeStartButton", theme.get_font_size(&"font_size", &"LivingForgePrimaryButton"))
~~~

Keep both variations in \`_STYLEBOX_SLOTS\` and \`_FONT_SIZE_TYPES\`; no scene-specific override is added.

- [ ] **Step 5: Run GREEN and representative screen runners**

~~~powershell
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_living_forge_theme.gd tests/unit/test_class_selection_panel.gd tests/unit/test_terminal_extraction_panel.gd tests/unit/test_run_result_panel.gd tests/unit/test_level_up_targeting_ui.gd tests/unit/test_living_forge_components.gd
& $godot --path (Get-Location).Path --rendering-method gl_compatibility --quit-after 1200 --script res://tests/integration/run_setup_lobby_panel_runner.gd
& $godot --path (Get-Location).Path --rendering-method gl_compatibility --quit-after 1200 --script res://tests/integration/level_up_five_card_geometry_runner.gd
& $godot --path (Get-Location).Path --rendering-method gl_compatibility --quit-after 1200 --script res://tests/integration/combat_loop_responsive_runner.gd
~~~

Expected: focused unit PASS and all three real-screen runner PASS markers, exit 0.

- [ ] **Step 6: Review and commit**

~~~powershell
git diff --check
git add -- data/ui/living_forge/living_forge_theme.tres data/ui/living_forge/living_forge_high_contrast_theme.tres scripts/ui/living_forge/living_forge_theme_catalog.gd tests/unit/test_living_forge_theme.gd tests/unit/test_class_selection_panel.gd tests/unit/test_terminal_extraction_panel.gd tests/unit/test_run_result_panel.gd tests/unit/test_level_up_targeting_ui.gd tests/unit/test_living_forge_components.gd
git commit -m "fix: unify primary action focus styling"
~~~

### Task 9: Exact-Head Visual Qualification, Fresh Full Suite, and Approval Gate

**Files:**

- Modify: \`tests/integration/living_forge_combat_loop_visual_evidence_runner.gd:1-1187\`
- Replace: \`docs/validation/screenshots/living-forge-combat-loop/manifest.json\`
- Replace: exact PNG set under \`docs/validation/screenshots/living-forge-combat-loop/\`
- Create: \`docs/verification/2026-08-31-combat-hud-collapse-primary-focus.md\`

**Interfaces:**

- Consumes: clean committed Tasks 1-8 candidate, existing schema-2 fingerprint/hash contract, all focused runner markers.
- Produces: exact 58-capture manifest/evidence set, fresh tracked-only suite evidence, independent verdicts, and a stopped Jacob approval gate.

- [ ] **Step 1: Revalidate drift and stop on unapproved overlap**

~~~powershell
$expectedBase = 'b837c91954231ba808d2338b4bcc82efde720c84'
git status --porcelain=v1
git rev-parse --abbrev-ref HEAD
git rev-parse HEAD
git rev-parse main
git rev-parse origin/main
git worktree list --porcelain
~~~

Expected before qualification: clean tracked/index state on \`feat/combat-hud-collapse-primary-focus\`. If local \`main\` or \`origin/main\` moved from \`$expectedBase\`, or shared-file overlap exists, stop and request explicit reconciliation authority. Do not run a merge/rebase/push command under this plan's current authorization.

- [ ] **Step 2: Expand the visual contract through RED**

Append these exact 13 captures to the existing ordered 45, producing exactly 58:

| File | State | Focus | Viewport/settings |
|---|---|---|---|
| hud-party-collapsed-6-clear.png | Party collapsed, six healthy members | hud:party_header | 1920x1080, UI100/Text100 |
| hud-party-collapsed-24-severity.png | Party collapsed, 24 members with dead/downed/critical counts | hud:party_header | 1920x1080, UI100/Text100 |
| hud-alerts-collapsed-dead-focus.png | Alerts collapsed with DEAD highest summary | hud:alerts_header | 1920x1080, UI100/Text100 |
| hud-alerts-collapsed-all-clear.png | Alerts collapsed, ALL CLEAR | hud:alerts_header | 1920x1080, UI100/Text100 |
| hud-both-collapsed-720p-text-150.png | Both collapsed Text150 stress | hud:party_header | 1280x720, UI100/Text150 |
| hud-both-collapsed-high-contrast.png | Both collapsed high contrast | hud:alerts_header | 1920x1080, high contrast |
| hud-alerts-collapsed-controller-tray-focus.png | Collapsed Alerts direct tray action | hud:alerts_tray_action | 1920x1080, simulated controller |
| hud-both-collapsed-reduced-motion.png | Both collapsed settled reduced motion | hud:party_header | 1920x1080, reduced motion |
| lobby-start-run-primary-focus.png | Start Run shared focus style | lobby:start | 1920x1080, keyboard |
| extraction-confirm-primary-focus.png | Confirm Extraction shared focus style | extraction:confirm | 1920x1080, keyboard |
| extraction-consequence-primary-focus.png | Accept Consequence shared focus style | extraction:acknowledge | 1920x1080, keyboard |
| level-up-confirm-primary-focus.png | Level-up Confirm shared focus style | level_up:confirm | 1920x1080, keyboard |
| result-primary-retry-focus.png | Result Retry Resolution shared focus style | result:retry_resolution | 1920x1080, keyboard |

Extend focus-target validation with those exact names and assert every focused primary action resolves the shared filled style and >=4.5:1 calculated contrast. Update exact-count assertions from 45 to 58.

Run validate-only before capture:

~~~powershell
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
& $godot --path (Get-Location).Path --rendering-method gl_compatibility --quit-after 900 --script res://tests/integration/living_forge_combat_loop_visual_evidence_runner.gd -- --validate-only
~~~

Expected RED: exit nonzero and \`LIVING_FORGE_COMBAT_LOOP_VISUAL_SUMMARY: FAIL\` naming the absent exact 58-file contract; validation mode writes nothing.

- [ ] **Step 3: Run all owning automated gates**

~~~powershell
$focused = @(
	'tests/unit/test_party_forge_settings.gd',
	'tests/unit/test_combat_hud_projection.gd',
	'tests/unit/test_combat_hud_view_model.gd',
	'tests/unit/test_combat_hud_responsive_layout.gd',
	'tests/unit/test_combat_hud.gd',
	'tests/unit/test_main_wiring.gd',
	'tests/unit/test_living_forge_theme.gd',
	'tests/unit/test_class_selection_panel.gd',
	'tests/unit/test_terminal_extraction_panel.gd',
	'tests/unit/test_run_result_panel.gd',
	'tests/unit/test_level_up_targeting_ui.gd',
	'tests/unit/test_living_forge_components.gd'
)
& $godot --headless --path (Get-Location).Path --quit-after 1200 --script res://tests/focused_test_runner.gd -- $focused
$runners = @(
	@('res://tests/integration/level_up_commit_flow_runner.gd','LEVEL_UP_COMMIT_FLOW_SUMMARY: PASS'),
	@('res://tests/integration/combat_hud_input_runner.gd','COMBAT_HUD_INPUT_SUMMARY: PASS'),
	@('res://tests/integration/combat_hud_party_scale_runner.gd','COMBAT_HUD_PARTY_SCALE_SUMMARY: PASS'),
	@('res://tests/integration/combat_loop_responsive_runner.gd','COMBAT_LOOP_RESPONSIVE_SUMMARY: PASS'),
	@('res://tests/integration/combat_loop_accessibility_runner.gd','COMBAT_LOOP_ACCESSIBILITY_SUMMARY: PASS'),
	@('res://tests/integration/combat_loop_performance_runner.gd','COMBAT_LOOP_PERFORMANCE_SUMMARY: PASS'),
	@('res://tests/integration/run_setup_lobby_panel_runner.gd','RUN_SETUP_LOBBY_PANEL_SUMMARY: PASS'),
	@('res://tests/integration/level_up_five_card_geometry_runner.gd','LEVEL_UP_FIVE_CARD_SUMMARY: PASS')
)
foreach ($runner in $runners) {
	$output = (& $godot --path (Get-Location).Path --rendering-method gl_compatibility --quit-after 1800 --script $runner[0] 2>&1 | Out-String)
	$output
	if ($LASTEXITCODE -ne 0 -or -not $output.Contains($runner[1])) { throw "Runner failed: $($runner[0])" }
}
~~~

Expected: focused \`TEST_SUMMARY: PASS (0 failures)\`; every exact runner marker present; every process exits 0; no unexpected diagnostic.

- [ ] **Step 4: Commit the evidence harness candidate**

~~~powershell
git diff --check
git add -- tests/integration/living_forge_combat_loop_visual_evidence_runner.gd
git commit -m "test: extend collapsible HUD visual contract"
git status --porcelain=v1
~~~

Expected: clean worktree after a harness-only commit. Record this exact commit as the source candidate for cold qualification and screenshots.

- [ ] **Step 5: Run fresh tracked-only cold import and full suite**

~~~powershell
$candidate = (git rev-parse HEAD).Trim()
$coldRoot = Join-Path ([IO.Path]::GetTempPath()) ("party-forge-hud-collapse-" + [guid]::NewGuid().ToString('N'))
$sourceRoot = Join-Path $coldRoot 'source'
$archive = Join-Path $coldRoot 'source.zip'
New-Item -ItemType Directory -Path $sourceRoot -Force | Out-Null
git archive --format=zip --output=$archive $candidate
Expand-Archive -LiteralPath $archive -DestinationPath $sourceRoot
$env:APPDATA = Join-Path $coldRoot 'AppData\Roaming'
$env:LOCALAPPDATA = Join-Path $coldRoot 'AppData\Local'
New-Item -ItemType Directory -Path $env:APPDATA,$env:LOCALAPPDATA -Force | Out-Null
$importOutput = (& $godot --headless --editor --path $sourceRoot --import --quit-after 600 2>&1 | Out-String)
$importExit = $LASTEXITCODE
$testOutput = (& $godot --headless --path $sourceRoot --quit-after 7200 --script res://tests/test_runner.gd 2>&1 | Out-String)
$testExit = $LASTEXITCODE
$importOutput
$testOutput
if ($importExit -ne 0) { throw "Cold import failed: $importExit" }
if ($testExit -ne 0 -or -not $testOutput.Contains('TEST_SUMMARY: PASS (262 suites)')) { throw "Cold full suite failed: $testExit" }
if ($testOutput -match 'TEST_FAILURE|SCRIPT ERROR|Parse Error|loader error|access violation') { throw 'Unexpected cold-suite diagnostic' }
~~~

Expected: import exit 0; \`TEST_SUMMARY: PASS (262 suites)\`; test exit 0; no parser/loader/import/script/crash diagnostic. Record \`$candidate\`, paths, outputs, and exits in the new verification report. The temporary directory is outside the repository; preserve it until the report is committed and reviewed.

- [ ] **Step 6: Capture the exact 58-file schema-2 set**

From the same clean committed candidate:

~~~powershell
& $godot --path (Get-Location).Path --rendering-method gl_compatibility --quit-after 2400 --script res://tests/integration/living_forge_combat_loop_visual_evidence_runner.gd
~~~

Expected: \`LIVING_FORGE_COMBAT_LOOP_VISUAL_SUMMARY: PASS\`, exit 0, exactly 58 declared PNGs, 58 unique SHA-256 hashes, no extra/stale PNG, schema version 2, exact candidate source-head binding, exact capture-contract SHA-256, renderer/window metadata, and source fingerprint integrity.

- [ ] **Step 7: Obtain three independent reviews**

1. Requirements reviewer maps every approved spec acceptance criterion to code/test/evidence and returns PASS or exact gaps.
2. Code-quality reviewer inspects Tasks 1-8 plus the harness for typed interfaces, focus lifetime, modal ownership, save failure, runtime-truth isolation, Batch 1 regression, and shared theme behavior.
3. UI/UX reviewer inspects all 58 PNGs at original resolution, explicitly checking Party/Alerts hierarchy, 24-member density, critical/downed/dead/all-clear semantics, Text150, normal/high contrast, reduced motion, controller focus, persistent tray access, Start Run, extraction, result, and level-up primary focus parity.

Any finding returns to its owning task through a new failing assertion and minimal GREEN fix. After any code/harness change, repeat Steps 3-7 from a new clean committed candidate and regenerate all 58 captures; never patch screenshot bytes.

- [ ] **Step 8: Record and commit qualification evidence**

Write \`docs/verification/2026-08-31-combat-hud-collapse-primary-focus.md\` with exact source candidate, evidence commit parent, commands/exits/markers, 58-file/hash inventory, manifest/fingerprint checks, reviewer identities/verdicts, live main drift, preserved untracked counts, physical-controller status, rollback instructions, and \`Jacob visual approval: PENDING\`.

~~~powershell
git diff --check
git status --short
git add -- tests/integration/living_forge_combat_loop_visual_evidence_runner.gd docs/validation/screenshots/living-forge-combat-loop docs/verification/2026-08-31-combat-hud-collapse-primary-focus.md
git commit -m "test: qualify collapsible combat HUD"
git status --porcelain=v1
~~~

Expected: clean feature worktree; evidence manifest remains bound to the exact recorded source candidate; no unrelated file is staged.

- [ ] **Step 9: Stop for Jacob's visual approval**

Present the exact 58-capture set and keep automated, requirements-review, code-quality, UI/UX, and Jacob verdicts separate. Do not run post-approval qualification, reconciliation, integration, merge, push, branch deletion, or cleanup.

## Later Reconciliation and Integration Gate

This section is a gate, not current authorization:

1. After Jacob visually approves the exact candidate, re-read local \`main\`, \`origin/main\`, feature HEAD, worktree dirt, and shared-file overlap.
2. If Main moved, obtain explicit authorization before reconciling it into the feature branch. Preserve both Main's newer authority and this batch; independently review every shared-file resolution.
3. From the reconciled clean committed head, rerun owning gates, fresh tracked-only import/full suite, all 58 exact-head captures, manifest validation, and independent reviews.
4. Obtain a renewed Jacob visual approval if reconciliation changes any rendered or focus behavior.
5. Integration into \`main\` and any push require a separate explicit approval. This plan supplies no authorized merge or push command.

## Rollback Checkpoints

- Tasks 1-8 each end in a focused local commit; revert only the rejected slice plus dependent later slices, never reset or clean the worktree.
- Before schema-v3 integration, rollback is branch-local. After schema-v3 settings have shipped, retain schema-3 read compatibility or provide an explicitly approved downgrade migration so saved settings do not become unreadable.
- If a collapse defect appears, preserve complete \`CombatHudProjection\` truth and revert only presentation/settings composition; never compensate in combat/runtime state.
- If theme parity regresses a real screen, revert the shared theme task and its evidence rather than adding per-screen patches.
- Generated evidence is immutable to its recorded source candidate; a changed candidate always receives a complete new 58-file set and manifest.
