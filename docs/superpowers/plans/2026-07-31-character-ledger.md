# Character Ledger and Run Pause Menu Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a full-screen, data-backed Character Ledger with Stats and Current Upgrades pages, a Coming Soon Equipment and Inventory tab, controller-ready navigation, and a separate minimal run pause menu.

**Architecture:** A `CharacterLedger` shell owns pause state, player context, member selection, page registration, and input. Independent page scenes consume a read-only `LedgerDataProvider`; page availability is resolved through descriptor Resources and a replaceable feature gate. The run pause menu is a separate CanvasLayer and routes confirmed Quit Run through `PartyForgeMain`.

**Tech Stack:** Godot 4.7.1, typed GDScript, Godot Resources and TSCN scenes, InputMap, the existing `tests/test_runner.gd` harness, and the connected Godot editor for live verification.

## Global Constraints

- Work in an isolated Git worktree and preserve the user's dirty `main` checkout.
- Do not modify `scripts/ui/hud.gd`, `scripts/game/game_run.gd`, `scripts/ui/run_result_panel.gd`, or `docs/superpowers/plans/2026-07-29-party-forge-godot-handbook.md`; those paths contain unrelated user changes in `main`.
- Do not change current party-cap gameplay, implement local multiplayer, or implement dynamic camera merging.
- Human-player party-slot accounting remains a documented future invariant, not production behavior in this milestone.
- Stats pages must read `PartyManager.stats_for()` and `ResolvedStatSnapshot.breakdown()`; no UI-only combat formulas.
- UI code must not inspect private party or member dictionaries.
- Equipment and Inventory is **Coming Soon** under the current provider; functional equipment, persistence, unlocks, and Developer Mode are separate milestones.
- The run pause menu provides functional Resume and Quit Run, a Coming Soon Settings control, and no save behavior.
- Use Godot containers and anchors; do not place full-screen UI using physical-screen coordinates.
- Preserve projectile tuning, stat/class/upgrade foundations, GodotSteam, handbook content, and unrelated UID metadata.
- Use `apply_patch` for source edits. Do not use Godot scene-save operations that rewrite unrelated Resources.
- Every task follows RED, GREEN, full-suite verification, `git diff --check`, and a focused commit.
- Intentional negative-test `push_error` output is allowed only when the runner exits `0` and prints `TEST_SUMMARY: PASS`.

## File and Responsibility Map

### Foundation

- `scripts/ui/ledger/ledger_page_definition.gd` — stable page metadata and availability states.
- `scripts/ui/ledger/ledger_page_catalog.gd` — duplicate-safe ordering and validation.
- `scripts/ui/ledger/ledger_feature_gate.gd` — current provider and Developer Preview hook.
- `scripts/ui/ledger/ledger_player_context.gd` — per-local-player member, page, focus, and opener state.
- `scripts/ui/ledger/run_pause_lease.gd` — restores the pause condition owned by a modal.
- `tools/configure_ledger_inputs.gd` — reproducibly configures keyboard and controller InputMap actions.

### Read-only presentation data

- `scripts/ui/ledger/ledger_data_provider.gd` — member, stat, detail, and applicable-upgrade records.
- `scripts/progression/upgrade_presentation_service.gd` — adds owned-upgrade detail formatting without changing offered-upgrade behavior.

### Character Ledger UI

- `scripts/ui/ledger/character_ledger_page.gd` — page interface base.
- `scripts/ui/ledger/character_ledger.gd` — shell, tabs, member rail, pause, page state, and input.
- `scripts/ui/ledger/stats_ledger_page.gd` — contextual stat groups and source details.
- `scripts/ui/ledger/upgrades_ledger_page.gd` — applicable upgrades and details.
- `scripts/ui/ledger/ledger_responsive_layout.gd` — deterministic desktop/compact layout policy.
- `scenes/ui/ledger/character_ledger.tscn` — full-screen shell.
- `scenes/ui/ledger/stats_ledger_page.tscn` — center stat sheet and right detail pane.
- `scenes/ui/ledger/upgrades_ledger_page.tscn` — center upgrade list and right detail pane.
- `data/ui/ledger_pages/*.tres` — Stats, Current Upgrades, Equipment and Inventory, and the default catalog.

### Run pause UI and integration

- `scripts/ui/run_pause_menu.gd` — Resume, Settings Coming Soon, Quit Run confirmation, and input.
- `scenes/ui/run_pause_menu.tscn` — full-screen pause overlay.
- `scripts/game/main.gd` — configures both overlays and owns the current front-end return route.
- `scenes/game/main.tscn` — instances both overlays above the existing HUD.

### Tests and documentation

- `tests/unit/test_character_ledger_foundation.gd`
- `tests/unit/test_ledger_data_provider.gd`
- `tests/unit/test_character_ledger_shell.gd`
- `tests/unit/test_stats_ledger_page.gd`
- `tests/unit/test_upgrades_ledger_page.gd`
- `tests/unit/test_run_pause_menu.gd`
- `tests/unit/test_ledger_responsive_input.gd`
- `tests/unit/test_main_wiring.gd`
- `tests/unit/test_responsive_ui.gd`
- `docs/handbook/10-party-forge-architecture-reference.md`
- `docs/development/GODOT_SKILL_CANDIDATES.md`

---

### Task 1: Page contracts, player context, pause ownership, and InputMap

**Files:**
- Create: `scripts/ui/ledger/ledger_page_definition.gd`
- Create: `scripts/ui/ledger/ledger_page_catalog.gd`
- Create: `scripts/ui/ledger/ledger_feature_gate.gd`
- Create: `scripts/ui/ledger/ledger_player_context.gd`
- Create: `scripts/ui/ledger/run_pause_lease.gd`
- Create: `tools/configure_ledger_inputs.gd`
- Modify: `project.godot`
- Test: `tests/unit/test_character_ledger_foundation.gd`

**Interfaces:**
- Produces: `LedgerPageDefinition.State`
- Produces: `LedgerPageDefinition.validate() -> PackedStringArray`
- Produces: `LedgerPageCatalog.valid_pages(gate: LedgerFeatureGate) -> Array[LedgerPageDefinition]`
- Produces: `LedgerFeatureGate.resolve(definition: LedgerPageDefinition) -> LedgerPageDefinition.State`
- Produces: `LedgerPlayerContext.ensure_valid_member(party: PartyManager, preferred_member_id: int = 0) -> int`
- Produces: `RunPauseLease.acquire(tree: SceneTree) -> void`
- Produces: `RunPauseLease.release(tree: SceneTree) -> void`

- [ ] **Step 1: Write the failing foundation suite**

Create `tests/unit/test_character_ledger_foundation.gd`:

```gdscript
extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_page_validation_and_order(failures)
	_test_gate_states(failures)
	_test_context_fallback(failures)
	_test_pause_lease(failures)
	_test_input_actions(failures)
	return failures

func _test_page_validation_and_order(failures: Array[String]) -> void:
	var stats := LedgerPageDefinition.new()
	stats.id = &"stats"
	stats.label = "Stats"
	stats.display_order = 20
	stats.development_state = LedgerPageDefinition.State.AVAILABLE
	stats.page_scene = PackedScene.new()
	var upgrades := LedgerPageDefinition.new()
	upgrades.id = &"upgrades"
	upgrades.label = "Current Upgrades"
	upgrades.display_order = 10
	upgrades.development_state = LedgerPageDefinition.State.AVAILABLE
	upgrades.page_scene = PackedScene.new()
	var catalog := LedgerPageCatalog.new()
	catalog.pages = [stats, upgrades]
	var ordered := catalog.valid_pages(LedgerFeatureGate.new())
	TestAssertions.equal(ordered.map(func(page: LedgerPageDefinition) -> StringName: return page.id), [&"upgrades", &"stats"], "ledger pages sort deterministically", failures)
	catalog.pages.append(stats)
	TestAssertions.truthy(catalog.validate().any(func(message: String) -> bool: return "duplicate page id stats" in message), "duplicate page IDs are grep-friendly", failures)

func _test_gate_states(failures: Array[String]) -> void:
	var definition := LedgerPageDefinition.new()
	definition.id = &"equipment_inventory"
	definition.label = "Equipment & Inventory"
	definition.development_state = LedgerPageDefinition.State.DEVELOPER_PREVIEW
	var player_gate := LedgerFeatureGate.new(false)
	var developer_gate := LedgerFeatureGate.new(true)
	TestAssertions.equal(player_gate.resolve(definition), LedgerPageDefinition.State.HIDDEN, "player gate hides developer preview", failures)
	TestAssertions.equal(developer_gate.resolve(definition), LedgerPageDefinition.State.AVAILABLE, "developer gate exposes implemented preview", failures)
	definition.feature_id = &"equipment"
	TestAssertions.equal(LedgerFeatureGate.new(true, [&"equipment"]).resolve(definition), LedgerPageDefinition.State.AVAILABLE, "known feature preserves developer preview", failures)
	definition.feature_id = &""
	for state: int in [LedgerPageDefinition.State.HIDDEN, LedgerPageDefinition.State.COMING_SOON, LedgerPageDefinition.State.AVAILABLE]:
		definition.development_state = state
		TestAssertions.equal(player_gate.resolve(definition), state, "ordinary page state %d remains stable" % state, failures)

func _test_context_fallback(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var context := LedgerPlayerContext.new(0)
	context.selected_member_id = 999
	TestAssertions.equal(context.ensure_valid_member(party), party.members[0].member_id, "missing selection falls back to controlled or first member", failures)

func _test_pause_lease(failures: Array[String]) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	tree.paused = false
	var lease := RunPauseLease.new()
	lease.acquire(tree)
	TestAssertions.truthy(tree.paused, "lease pauses an active run", failures)
	lease.release(tree)
	TestAssertions.truthy(not tree.paused, "lease restores an active run", failures)
	tree.paused = true
	lease.acquire(tree)
	lease.release(tree)
	TestAssertions.truthy(tree.paused, "lease preserves an existing pause", failures)
	tree.paused = false

func _test_input_actions(failures: Array[String]) -> void:
	for action: StringName in [&"character_ledger", &"pause_menu", &"ledger_previous_page", &"ledger_next_page"]:
		TestAssertions.truthy(InputMap.has_action(action), "InputMap exposes %s" % action, failures)
	var ledger_events := InputMap.action_get_events(&"character_ledger")
	TestAssertions.truthy(ledger_events.any(func(event: InputEvent) -> bool: return event is InputEventKey and event.physical_keycode == KEY_TAB), "Tab opens the ledger", failures)
	TestAssertions.truthy(ledger_events.any(func(event: InputEvent) -> bool: return event is InputEventJoypadButton and event.button_index == JOY_BUTTON_BACK), "controller Back opens the ledger", failures)
	var pause_events := InputMap.action_get_events(&"pause_menu")
	TestAssertions.truthy(pause_events.any(func(event: InputEvent) -> bool: return event is InputEventJoypadButton and event.button_index == JOY_BUTTON_START), "controller Start opens pause", failures)
```

- [ ] **Step 2: Import and run the suite to verify RED**

Run:

```powershell
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
$project = (Get-Location).Path
& $godot --headless --path $project --editor --quit-after 2
& $godot --headless --path $project --script res://tests/test_runner.gd
```

Expected: nonzero test exit or `TEST_SUMMARY: FAIL`; the new ledger classes and actions do not exist.

- [ ] **Step 3: Implement the page, gate, context, and pause types**

Create `scripts/ui/ledger/ledger_page_definition.gd`:

```gdscript
class_name LedgerPageDefinition
extends Resource

enum State { HIDDEN, COMING_SOON, DEVELOPER_PREVIEW, AVAILABLE }

@export var id: StringName
@export var label: String
@export var page_scene: PackedScene
@export var display_order := 0
@export var feature_id: StringName
@export var unlock_id: StringName
@export var unavailable_text := ""
@export var development_state := State.HIDDEN

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty():
		errors.append("PARTY_FORGE_LEDGER_ERROR page=<empty> reason=id is empty")
	if label.strip_edges().is_empty():
		errors.append("PARTY_FORGE_LEDGER_ERROR page=%s reason=label is empty" % id)
	if development_state in [State.AVAILABLE, State.DEVELOPER_PREVIEW] and page_scene == null:
		var source_path := resource_path if not resource_path.is_empty() else "<runtime>"
		errors.append("PARTY_FORGE_LEDGER_ERROR page=%s resource=%s reason=implemented page scene is missing" % [id, source_path])
	if development_state == State.COMING_SOON and unavailable_text.strip_edges().is_empty():
		errors.append("PARTY_FORGE_LEDGER_ERROR page=%s reason=coming soon explanation is empty" % id)
	return errors
```

Create `scripts/ui/ledger/ledger_feature_gate.gd`:

```gdscript
class_name LedgerFeatureGate
extends RefCounted

var expose_developer_preview := false
var known_feature_ids: Array[StringName] = []
var known_unlock_ids: Array[StringName] = []

func _init(
	developer_access := false,
	supported_features: Array[StringName] = [],
	supported_unlocks: Array[StringName] = []
) -> void:
	expose_developer_preview = developer_access
	known_feature_ids = supported_features.duplicate()
	known_unlock_ids = supported_unlocks.duplicate()

func resolve(definition: LedgerPageDefinition) -> LedgerPageDefinition.State:
	if definition == null:
		return LedgerPageDefinition.State.HIDDEN
	if not definition.feature_id.is_empty() and definition.feature_id not in known_feature_ids:
		push_error("PARTY_FORGE_LEDGER_ERROR page=%s reason=unknown feature %s" % [definition.id, definition.feature_id])
		return LedgerPageDefinition.State.HIDDEN
	if not definition.unlock_id.is_empty() and definition.unlock_id not in known_unlock_ids:
		push_error("PARTY_FORGE_LEDGER_ERROR page=%s reason=unknown unlock %s" % [definition.id, definition.unlock_id])
		return LedgerPageDefinition.State.HIDDEN
	if definition.development_state == LedgerPageDefinition.State.DEVELOPER_PREVIEW:
		return LedgerPageDefinition.State.AVAILABLE if expose_developer_preview else LedgerPageDefinition.State.HIDDEN
	return definition.development_state
```

Create `scripts/ui/ledger/ledger_page_catalog.gd`:

```gdscript
class_name LedgerPageCatalog
extends Resource

@export var pages: Array[LedgerPageDefinition] = []

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen: Dictionary = {}
	for page: LedgerPageDefinition in pages:
		if page == null:
			errors.append("PARTY_FORGE_LEDGER_ERROR page=<null> reason=definition is missing")
			continue
		if seen.has(page.id):
			errors.append("PARTY_FORGE_LEDGER_ERROR page=%s reason=duplicate page id %s" % [page.id, page.id])
			continue
		seen[page.id] = true
		errors.append_array(page.validate())
	return errors

func valid_pages(gate: LedgerFeatureGate) -> Array[LedgerPageDefinition]:
	var result: Array[LedgerPageDefinition] = []
	var seen: Dictionary = {}
	for page: LedgerPageDefinition in pages:
		if page == null or seen.has(page.id):
			continue
		seen[page.id] = true
		if not page.validate().is_empty():
			continue
		if gate.resolve(page) != LedgerPageDefinition.State.HIDDEN:
			result.append(page)
	result.sort_custom(func(left: LedgerPageDefinition, right: LedgerPageDefinition) -> bool:
		if left.display_order == right.display_order:
			return String(left.id) < String(right.id)
		return left.display_order < right.display_order
	)
	return result
```

Create `scripts/ui/ledger/ledger_player_context.gd`:

```gdscript
class_name LedgerPlayerContext
extends RefCounted

var local_player_id := 0
var selected_member_id := 0
var active_page_id: StringName = &"stats"
var last_focus_path := NodePath()
var opened_by_player_id := 0

func _init(player_id := 0) -> void:
	local_player_id = player_id
	opened_by_player_id = player_id

func ensure_valid_member(party: PartyManager, preferred_member_id: int = 0) -> int:
	if party == null or party.members.is_empty():
		selected_member_id = 0
		return 0
	if party.member_by_id(selected_member_id) != null:
		return selected_member_id
	if preferred_member_id > 0 and party.member_by_id(preferred_member_id) != null:
		selected_member_id = preferred_member_id
	else:
		selected_member_id = party.members[0].member_id
	return selected_member_id
```

Create `scripts/ui/ledger/run_pause_lease.gd`:

```gdscript
class_name RunPauseLease
extends RefCounted

var _active := false
var _was_paused := false

func acquire(tree: SceneTree) -> void:
	if _active or tree == null:
		return
	_active = true
	_was_paused = tree.paused
	tree.paused = true

func release(tree: SceneTree) -> void:
	if not _active or tree == null:
		return
	tree.paused = _was_paused
	_active = false

func is_active() -> bool:
	return _active
```

- [ ] **Step 4: Configure reproducible keyboard and controller actions**

Create `tools/configure_ledger_inputs.gd`:

```gdscript
extends SceneTree

func _initialize() -> void:
	_set_action(&"character_ledger", [_key(KEY_TAB), _key(KEY_I), _button(JoyButton.BACK)])
	_set_action(&"pause_menu", [_key(KEY_ESCAPE), _button(JoyButton.START)])
	_set_action(&"ledger_previous_page", [_button(JoyButton.LEFT_SHOULDER)])
	_set_action(&"ledger_next_page", [_button(JoyButton.RIGHT_SHOULDER)])
	ProjectSettings.save()
	print("PARTY_FORGE_LEDGER_INPUTS_OK")
	quit(0)

func _set_action(action: StringName, events: Array) -> void:
	ProjectSettings.set_setting("input/%s" % action, {
		"deadzone": 0.2,
		"events": events,
	})

func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	return event

func _button(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	return event
```

Run:

```powershell
& $godot --headless --path $project --script res://tools/configure_ledger_inputs.gd
```

Expected: exit `0`, `PARTY_FORGE_LEDGER_INPUTS_OK`, and serialized actions in `project.godot`.

- [ ] **Step 5: Import and verify GREEN**

Run:

```powershell
& $godot --headless --path $project --editor --quit-after 2
& $godot --headless --path $project --script res://tests/test_runner.gd
git diff --check
```

Expected: exit `0`, `TEST_SUMMARY: PASS`, no unexpected script errors, and diff check exit `0`.

- [ ] **Step 6: Commit the foundation**

```powershell
git add project.godot tools/configure_ledger_inputs.gd scripts/ui/ledger tests/unit/test_character_ledger_foundation.gd
git commit -m "feat: add character ledger foundations"
```

---

### Task 2: Read-only member, stat, and applicable-upgrade data

**Files:**
- Create: `scripts/ui/ledger/ledger_data_provider.gd`
- Modify: `scripts/progression/upgrade_presentation_service.gd`
- Test: `tests/unit/test_ledger_data_provider.gd`

**Interfaces:**
- Consumes: `LedgerPlayerContext`, `PartyManager`, `GameCatalog`
- Produces: `LedgerDataProvider.configure(party: PartyManager, catalog: GameCatalog, health_provider: Callable) -> void`
- Produces: `LedgerDataProvider.member_rows() -> Array[Dictionary]`
- Produces: `LedgerDataProvider.stat_rows(member_id: int, show_all: bool = false) -> Array[Dictionary]`
- Produces: `LedgerDataProvider.stat_detail(member_id: int, stat_id: StringName) -> Dictionary`
- Produces: `LedgerDataProvider.upgrade_rows(member_id: int) -> Array[Dictionary]`
- Produces: `LedgerDataProvider.upgrade_detail(row: Dictionary) -> Dictionary`
- Produces: `UpgradePresentationService.owned_tooltip(...) -> Dictionary`

- [ ] **Step 1: Write failing provider tests**

Create `tests/unit/test_ledger_data_provider.gd` with these assertions:

```gdscript
extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var health := HealthComponent.new()
	health.current_health = 200.0
	health.max_health = 260.0
	var provider := LedgerDataProvider.new()
	provider.configure(party, catalog, func(_member_id: int) -> Dictionary:
		return {"current": 200.0, "maximum": 260.0, "is_downed": false, "is_dead": false, "component": health}
	)

	var members := provider.member_rows()
	TestAssertions.equal(members.size(), 1, "provider returns only current members", failures)
	TestAssertions.equal(members[0].health_current, 200.0, "provider uses runtime health", failures)
	var health_changes: Array[int] = []
	provider.data_changed.connect(func(member_id: int) -> void: health_changes.append(member_id))
	health.health_changed.emit(190.0, 260.0)
	TestAssertions.equal(health_changes, [1], "runtime health signals refresh the affected member", failures)

	var normal_ids := provider.stat_rows(1).map(func(row: Dictionary) -> StringName: return row.stat_id)
	TestAssertions.truthy(&"physical_damage" in normal_ids, "fighter shows physical damage", failures)
	TestAssertions.truthy(&"fire_damage" not in normal_ids, "fighter hides irrelevant fire damage", failures)
	var fire_source := StatModifierSource.create(
		&"test_fire",
		&"test",
		"Test Fire",
		1,
		[StatModifier.create(&"fire_damage", StatModifier.Operation.INCREASED, 0.25, &"test_fire", "Test Fire")],
	)
	party.add_member_source(1, fire_source)
	var modified_ids := provider.stat_rows(1).map(func(row: Dictionary) -> StringName: return row.stat_id)
	TestAssertions.truthy(&"fire_damage" in modified_ids, "modifier-caused specialized stat remains visible", failures)
	TestAssertions.truthy(&"lightning_damage" in provider.stat_rows(1, true).map(func(row: Dictionary) -> StringName: return row.stat_id), "Show All exposes complete registry", failures)
	var detail := provider.stat_detail(1, &"fire_damage")
	TestAssertions.equal(detail.sources.size(), 2, "detail contains base and named source", failures)

	UpgradeApplicationService.apply(&"vitality", catalog, party, 1)
	party.upgrade_party_stat(&"damage")
	var upgrades := provider.upgrade_rows(1)
	TestAssertions.truthy(upgrades.any(func(row: Dictionary) -> bool: return row.id == &"vitality" and row.ownership == "Personal"), "personal upgrade is listed", failures)
	TestAssertions.truthy(upgrades.any(func(row: Dictionary) -> bool: return row.id == &"party_damage" and row.ownership == "Party"), "foundational party rank is listed", failures)
	health.free()
	return failures
```

- [ ] **Step 2: Run RED**

Run import and the full runner. Expected: failure because `LedgerDataProvider` and `owned_tooltip` do not exist.

- [ ] **Step 3: Add owned-upgrade formatting without changing offer formatting**

Append to `UpgradePresentationService`:

```gdscript
static func owned_tooltip(
	definition: UpgradeDefinition,
	rank: int,
	stats: StatCatalog,
	keywords: KeywordCatalog
) -> Dictionary:
	var content := tooltip(definition, rank, stats, keywords)
	content["rank_text"] = "Rank %d / %d" % [rank, definition.max_rank]
	return content
```

Do not change `tooltip()` or its existing `"Offered rank"` output; existing level-up tests depend on it.

- [ ] **Step 4: Implement the provider**

Create `scripts/ui/ledger/ledger_data_provider.gd` with this public shape and algorithms:

```gdscript
class_name LedgerDataProvider
extends RefCounted

signal data_changed(member_id: int)
signal party_changed

const GROUP_ORDER: Array[StringName] = [&"overview", &"offense", &"defense", &"resistances", &"utility"]

var party: PartyManager
var catalog: GameCatalog
var health_provider: Callable
var _health_components: Dictionary = {}

func configure(manager: PartyManager, game_catalog: GameCatalog, runtime_health: Callable) -> void:
	_disconnect_party()
	party = manager
	catalog = game_catalog
	health_provider = runtime_health
	if party != null:
		party.member_added.connect(_on_member_added)
		party.stats_changed.connect(_on_stats_changed)
		party.upgrades_changed.connect(_on_upgrades_changed)
		party.class_rank_changed.connect(_on_class_rank_changed)
		party.active_traits_changed.connect(_on_traits_changed)

func member_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if party == null:
		return rows
	for member: PartyMemberState in party.members:
		var health: Dictionary = health_provider.call(member.member_id) if health_provider.is_valid() else {}
		_observe_health_component(member.member_id, health.get("component") as HealthComponent)
		rows.append({
			"member_id": member.member_id,
			"character_name": member.character_name,
			"class_name": member.class_definition.display_name,
			"class_color": member.class_definition.color,
			"class_rank": party.get_class_rank(member.class_definition.id),
			"role_name": UpgradePresentationService.role_name(member.class_definition.role),
			"health_current": float(health.get("current", 0.0)),
			"health_maximum": float(health.get("maximum", 0.0)),
			"is_downed": bool(health.get("is_downed", false)),
			"is_dead": bool(health.get("is_dead", false)),
			"traits": member.class_definition.traits.duplicate(),
			"capabilities": member.capability_tags.duplicate(),
		})
	return rows

func stat_rows(member_id: int, show_all := false) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var snapshot := party.stats_for(member_id) if party != null else null
	if snapshot == null:
		return rows
	for definition: StatDefinition in PartyManager.STAT_CATALOG.all():
		var breakdown := snapshot.breakdown(definition.id)
		if not show_all and not _is_visible(definition, snapshot, breakdown):
			continue
		rows.append({
			"stat_id": definition.id,
			"group_id": definition.ui_group,
			"display_name": definition.display_name,
			"value": snapshot.value(definition.id, definition.default_value),
			"formatted_value": definition.format_value(snapshot.value(definition.id, definition.default_value)),
			"keyword_id": definition.keyword_id,
			"sort_key": "%02d|%s" % [_group_index(definition.ui_group), definition.display_name],
		})
	rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return left.sort_key < right.sort_key)
	return rows

func stat_detail(member_id: int, stat_id: StringName) -> Dictionary:
	var definition := PartyManager.STAT_CATALOG.definition(stat_id)
	var snapshot := party.stats_for(member_id) if party != null else null
	if definition == null or snapshot == null:
		return {"title": "Missing definition: %s" % stat_id, "sources": []}
	var keyword := catalog.keywords.definition(definition.keyword_id) if catalog != null and catalog.keywords != null else null
	return {
		"title": definition.display_name,
		"value_text": definition.format_value(snapshot.value(stat_id, definition.default_value)),
		"description": keyword.explanation if keyword != null else "Missing definition: %s" % definition.keyword_id,
		"cap_text": _cap_text(definition),
		"sources": snapshot.breakdown(stat_id),
	}

func upgrade_rows(member_id: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var member := party.member_by_id(member_id) if party != null else null
	if member == null or catalog == null:
		return rows
	for definition: UpgradeDefinition in catalog.upgrades:
		var owner_id := member_id if definition.is_single_recipient() else 0
		var rank := party.upgrade_rank(definition.id, owner_id)
		if rank <= 0 or not definition.is_member_eligible(member):
			continue
		rows.append(_authored_upgrade_row(definition, rank))
	for stat_id: StringName in PartyManager.PARTY_STAT_IDS:
		var rank := party.party_stat_rank(stat_id)
		if rank > 0:
			rows.append(_party_stat_row(stat_id, rank))
	for trait_id: StringName in member.class_definition.traits:
		if party.active_tier(trait_id) > 0:
			rows.append(_trait_row(trait_id))
	rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return left.sort_key < right.sort_key)
	return rows

func upgrade_detail(row: Dictionary) -> Dictionary:
	var definition := row.get("definition") as UpgradeDefinition
	if definition != null:
		var content := UpgradePresentationService.owned_tooltip(definition, int(row.rank), PartyManager.STAT_CATALOG, catalog.keywords)
		content["ownership"] = row.get("ownership", "")
		content["applicability"] = row.get("applicability", "")
		return content
	return {
		"title": row.get("display_name", ""),
		"rank_text": row.get("rank_text", ""),
		"ownership": row.get("ownership", ""),
		"description": row.get("description", ""),
		"effect_lines": row.get("effect_lines", []),
		"applicability": row.get("applicability", ""),
		"eligibility_text": row.get("applicability", ""),
		"inheritance_text": "",
		"keyword_lines": [],
	}
```

Add these private helpers in the same file:

```gdscript
func _is_visible(definition: StatDefinition, snapshot: ResolvedStatSnapshot, breakdown: Array[Dictionary]) -> bool:
	var has_modifier_source := breakdown.size() > 1
	if definition.visibility == StatDefinition.Visibility.UNIVERSAL:
		return true
	if definition.visibility == StatDefinition.Visibility.CAPABILITY:
		return has_modifier_source or definition.capability_tags.any(
			func(tag: StringName) -> bool: return tag in snapshot.capabilities
		)
	return has_modifier_source or not is_equal_approx(
		snapshot.value(definition.id, definition.default_value),
		definition.default_value
	)

func _group_index(group_id: StringName) -> int:
	var index := GROUP_ORDER.find(group_id)
	return index if index >= 0 else GROUP_ORDER.size()

func _cap_text(definition: StatDefinition) -> String:
	var parts := PackedStringArray()
	if definition.has_minimum:
		parts.append("Minimum %s" % definition.format_value(definition.minimum))
	if definition.has_maximum:
		parts.append("Maximum %s" % definition.format_value(definition.maximum))
	return " · ".join(parts)

func _authored_upgrade_row(definition: UpgradeDefinition, rank: int) -> Dictionary:
	var ownership := "Personal"
	var order := 0
	match definition.scope:
		UpgradeDefinition.Scope.CLASS_SPECIFIC:
			ownership = "Class"
			order = 1
		UpgradeDefinition.Scope.PARTY:
			ownership = "Party"
			order = 2
		UpgradeDefinition.Scope.TRAIT:
			ownership = "Trait"
			order = 3
	return {
		"id": definition.id,
		"display_name": definition.display_name,
		"rank": rank,
		"rank_text": "Rank %d / %d" % [rank, definition.max_rank],
		"ownership": ownership,
		"description": definition.description,
		"applicability": "Applies to %s." % ownership.to_lower(),
		"definition": definition,
		"sort_key": "%02d|%s" % [order, definition.display_name],
	}

func _party_stat_row(stat_id: StringName, rank: int) -> Dictionary:
	var definition := PartyManager.STAT_CATALOG.definition(stat_id)
	var stat_name := definition.display_name if definition != null else String(stat_id).capitalize()
	var bonus := party.party_stat_multiplier(stat_id) - 1.0
	return {
		"id": StringName("party_%s" % stat_id),
		"display_name": "Party %s" % stat_name,
		"rank": rank,
		"rank_text": "Rank %d / %d" % [rank, party.upgrade_tuning.party_stat_max_rank],
		"ownership": "Party",
		"description": "A foundational party upgrade affecting every current member.",
		"effect_lines": ["%g%% increased %s." % [bonus * 100.0, stat_name]],
		"applicability": "Applies to the whole current party.",
		"definition": null,
		"sort_key": "02|Party %s" % stat_name,
	}

func _trait_row(trait_id: StringName) -> Dictionary:
	var definition := party.trait_definition(trait_id)
	var display_name := definition.display_name if definition != null else String(trait_id).capitalize()
	var tier := party.active_tier(trait_id)
	var mastery := party.trait_upgrade_rank(trait_id)
	return {
		"id": StringName("active_trait_%s" % trait_id),
		"display_name": display_name,
		"rank": mastery,
		"rank_text": "Tier %d · Mastery %d" % [tier, mastery],
		"ownership": "Trait",
		"description": "An active party-composition synergy.",
		"effect_lines": ["Current value: %g" % party.effective_trait_value(trait_id)],
		"applicability": "Applies because the selected character has the %s trait." % display_name,
		"definition": null,
		"sort_key": "03|%s" % display_name,
	}

func _on_member_added(member: PartyMemberState) -> void:
	party_changed.emit()
	data_changed.emit(member.member_id)

func _on_stats_changed(member_id: int) -> void:
	data_changed.emit(member_id)

func _on_upgrades_changed() -> void:
	data_changed.emit(0)

func _on_class_rank_changed(_class_id: StringName, _rank: int) -> void:
	data_changed.emit(0)

func _on_traits_changed(_tiers: Dictionary) -> void:
	data_changed.emit(0)

func _observe_health_component(member_id: int, component: HealthComponent) -> void:
	if component == null or not is_instance_valid(component):
		return
	if _health_components.get(member_id) == component:
		return
	_disconnect_health(member_id)
	_health_components[member_id] = component
	component.health_changed.connect(Callable(self, "_on_health_changed").bind(member_id))
	component.downed.connect(Callable(self, "_on_health_state_changed").bind(member_id))
	component.revived.connect(Callable(self, "_on_health_state_changed").bind(member_id))
	component.died.connect(Callable(self, "_on_health_state_changed").bind(member_id))

func _on_health_changed(_current: float, _maximum: float, member_id: int) -> void:
	data_changed.emit(member_id)

func _on_health_state_changed(member_id: int) -> void:
	data_changed.emit(member_id)

func _disconnect_health(member_id: int) -> void:
	var component := _health_components.get(member_id) as HealthComponent
	_health_components.erase(member_id)
	if component == null or not is_instance_valid(component):
		return
	var callbacks := [
		[component.health_changed, Callable(self, "_on_health_changed").bind(member_id)],
		[component.downed, Callable(self, "_on_health_state_changed").bind(member_id)],
		[component.revived, Callable(self, "_on_health_state_changed").bind(member_id)],
		[component.died, Callable(self, "_on_health_state_changed").bind(member_id)],
	]
	for pair: Array in callbacks:
		var signal_value: Signal = pair[0]
		var callback: Callable = pair[1]
		if signal_value.is_connected(callback):
			signal_value.disconnect(callback)

func _disconnect_party() -> void:
	for member_id: Variant in _health_components.keys():
		_disconnect_health(int(member_id))
	if party == null:
		return
	var connections := [
		[party.member_added, Callable(self, "_on_member_added")],
		[party.stats_changed, Callable(self, "_on_stats_changed")],
		[party.upgrades_changed, Callable(self, "_on_upgrades_changed")],
		[party.class_rank_changed, Callable(self, "_on_class_rank_changed")],
		[party.active_traits_changed, Callable(self, "_on_traits_changed")],
	]
	for connection: Array in connections:
		var signal_value: Signal = connection[0]
		var callback: Callable = connection[1]
		if signal_value.is_connected(callback):
			signal_value.disconnect(callback)
```

Do not access `_party_upgrade_ranks`, `_party_upgrade_definitions`, `_party_upgrade_sources`, `_upgrade_ranks`, or `_modifier_sources`.

- [ ] **Step 5: Verify GREEN and commit**

Run import, full suite, and `git diff --check`. Expected: `TEST_SUMMARY: PASS`.

```powershell
git add scripts/ui/ledger/ledger_data_provider.gd scripts/progression/upgrade_presentation_service.gd tests/unit/test_ledger_data_provider.gd
git commit -m "feat: expose ledger presentation data"
```

---

### Task 3: Character Ledger shell, page Resources, and party rail

**Files:**
- Create: `scripts/ui/ledger/character_ledger_page.gd`
- Create: `scripts/ui/ledger/character_ledger.gd`
- Create: `scripts/ui/ledger/stats_ledger_page.gd`
- Create: `scripts/ui/ledger/upgrades_ledger_page.gd`
- Create: `scenes/ui/ledger/character_ledger.tscn`
- Create: `scenes/ui/ledger/stats_ledger_page.tscn`
- Create: `scenes/ui/ledger/upgrades_ledger_page.tscn`
- Create: `data/ui/ledger_pages/stats.tres`
- Create: `data/ui/ledger_pages/current_upgrades.tres`
- Create: `data/ui/ledger_pages/equipment_inventory.tres`
- Create: `data/ui/ledger_pages/default_ledger_pages.tres`
- Test: `tests/unit/test_character_ledger_shell.gd`

**Interfaces:**
- Consumes: Task 1 foundation and Task 2 provider.
- Produces: `CharacterLedger.configure(run: GameRun, party: PartyManager, catalog: GameCatalog, health_provider: Callable, initial_contexts: Array[LedgerPlayerContext] = []) -> void`
- Produces: `CharacterLedger.open_for_player(local_player_id: int = 0) -> bool`
- Produces: `CharacterLedger.close() -> void`
- Produces: `CharacterLedger.is_open() -> bool`
- Produces: `CharacterLedger.refresh() -> void`
- Produces: `CharacterLedger.activate_page(page_id: StringName) -> bool`
- Produces: `CharacterLedger.select_member(member_id: int) -> bool`

- [ ] **Step 1: Write the failing shell suite**

Create `tests/unit/test_character_ledger_shell.gd`:

```gdscript
extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var ledger := (load("res://scenes/ui/ledger/character_ledger.tscn") as PackedScene).instantiate() as CharacterLedger
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var run := GameRun.new()
	run.start_run()
	ledger.configure(run, party, catalog, func(_member_id: int) -> Dictionary:
		return {"current": 260.0, "maximum": 260.0, "is_downed": false, "is_dead": false}
	)
	TestAssertions.truthy(ledger.open_for_player(), "ledger opens during running state", failures)
	TestAssertions.truthy((Engine.get_main_loop() as SceneTree).paused, "ledger pauses gameplay", failures)
	TestAssertions.equal((ledger.get_node("Overlay/Frame/Layout/Body/PartyScroll/PartyEntries") as Container).get_child_count(), 1, "rail shows only current members", failures)
	TestAssertions.truthy(ledger.activate_page(&"current_upgrades"), "available page activates", failures)
	TestAssertions.equal(ledger.get("context").selected_member_id, 1, "selected member persists across pages", failures)
	TestAssertions.truthy(not ledger.activate_page(&"equipment_inventory"), "Coming Soon page cannot activate", failures)
	TestAssertions.truthy("Coming Soon" in (ledger.get_node("Overlay/Frame/Layout/Status") as Label).text, "Coming Soon activation explains itself", failures)
	for member_id: int in range(2, 8):
		party.members.append(PartyMemberState.new(member_id, catalog.class_by_id(&"fighter"), false, "Extra %d" % member_id))
	ledger.refresh()
	TestAssertions.equal((ledger.get_node("Overlay/Frame/Layout/Body/PartyScroll/PartyEntries") as Container).get_child_count(), 7, "scrolling rail supports exceptional party sizes above six", failures)
	ledger.close()
	TestAssertions.truthy(not (Engine.get_main_loop() as SceneTree).paused, "closing restores gameplay", failures)
	ledger.free()
	return failures
```

- [ ] **Step 2: Run RED**

Run import and full tests. Expected: new scene and class load failures.

- [ ] **Step 3: Add the page base and minimal page scripts**

Create `scripts/ui/ledger/character_ledger_page.gd`:

```gdscript
class_name CharacterLedgerPage
extends Control

var provider: LedgerDataProvider
var context: LedgerPlayerContext

func configure(data_provider: LedgerDataProvider, player_context: LedgerPlayerContext) -> void:
	provider = data_provider
	context = player_context

func activate() -> void:
	visible = true
	refresh()

func deactivate() -> void:
	visible = false

func refresh() -> void:
	pass

func initial_focus() -> Control:
	return null
```

Create `scripts/ui/ledger/stats_ledger_page.gd`:

```gdscript
class_name StatsLedgerPage
extends CharacterLedgerPage

func refresh() -> void:
	(get_node("Content/Title") as Label).text = "Character Stats"

func initial_focus() -> Control:
	return get_node("Content/Title") as Control
```

Create `scripts/ui/ledger/upgrades_ledger_page.gd`:

```gdscript
class_name UpgradesLedgerPage
extends CharacterLedgerPage

func refresh() -> void:
	(get_node("Content/Title") as Label).text = "Current Upgrades"

func initial_focus() -> Control:
	return get_node("Content/Title") as Control
```

Tasks 4 and 5 replace these minimal page bodies with the complete implementations.

- [ ] **Step 4: Create the page scenes and Resources**

Create these exact node contracts:

```text
StatsLedgerPage (Control, full rect, StatsLedgerPage)
└── Content (VBoxContainer, full rect)
    ├── Title (Label, "Character Stats")
    └── EmptyState (Label, "Select a party member.")

UpgradesLedgerPage (Control, full rect, UpgradesLedgerPage)
└── Content (VBoxContainer, full rect)
    ├── Title (Label, "Current Upgrades")
    └── EmptyState (Label, "No upgrades acquired yet.")
```

Create page `.tres` Resources:

```text
stats: id=stats, label=Stats, order=10, state=AVAILABLE, scene=stats_ledger_page.tscn
current_upgrades: id=current_upgrades, label=Current Upgrades, order=20, state=AVAILABLE, scene=upgrades_ledger_page.tscn
equipment_inventory: id=equipment_inventory, label=Equipment & Inventory, order=30,
                     state=COMING_SOON, unavailable_text="Coming Soon"
default_ledger_pages: LedgerPageCatalog containing the three definitions
```

- [ ] **Step 5: Implement the shell scene and script**

Create this scene contract:

```text
CharacterLedger (CanvasLayer, visible=false, process_mode=ALWAYS, CharacterLedger)
└── Overlay (Control, full rect, mouse_filter=STOP)
    ├── Dimmer (ColorRect, full rect)
    └── Frame (PanelContainer, full rect with safe margins)
        └── Layout (VBoxContainer)
            ├── Tabs (HBoxContainer)
            ├── Body (SplitContainer)
            │   ├── PartyScroll (ScrollContainer)
            │   │   └── PartyEntries (GridContainer, columns=1)
            │   └── PageHost (Control)
            └── Status (Label)
```

Implement `CharacterLedger` so that:

- It preloads `default_ledger_pages.tres`.
- `configure()` creates one `LedgerDataProvider`, indexes the supplied contexts by `local_player_id`, creates context `0` when the collection is empty, and creates page instances for AVAILABLE definitions. This milestone renders only the context selected by `open_for_player()`; it does not create multiplayer panes or device routing.
- `refresh()` rebuilds the member rail from `provider.member_rows()`, preserves a valid selection through `context.ensure_valid_member(party)`, and refreshes the active page. The rail remains inside `PartyScroll`, so seven or more current members remain reachable without changing the current gameplay cap.
- Tabs are normal focusable Buttons. COMING_SOON buttons stay focusable, but activation only writes the descriptor explanation to `Status`.
- HIDDEN definitions do not create a tab.
- `open_for_player()` permits RUNNING, LEVEL_UP, and BOSS only, requires a nonempty party, acquires `RunPauseLease`, selects a valid member, refreshes rail/pages, and focuses the active page or first member button.
- `close()` stores focus, releases the lease, hides the CanvasLayer, and clears `Status`.
- `select_member()` rejects unknown IDs and refreshes the active page.
- `activate_page()` rejects Coming Soon and unavailable IDs and preserves the prior active page. For a valid switch it calls `deactivate()` on the previous page, updates `context.active_page_id`, then calls `activate()` on the new page.
- `_unhandled_input()` toggles on `character_ledger`, closes on `ui_cancel` only while the ledger is open, and cycles only AVAILABLE pages on the two ledger page actions. When the ledger is closed it leaves `ui_cancel` unhandled so `RunPauseMenu` can own Escape/Menu behavior.
- Every handled event calls `get_viewport().set_input_as_handled()`.
- Provider signals refresh only the affected member or party rail.
- Missing/duplicate required pages call `push_error()` with `PARTY_FORGE_LEDGER_ERROR`.

- [ ] **Step 6: Verify GREEN and commit**

Run import, full suite, and diff check.

```powershell
git add scripts/ui/ledger scenes/ui/ledger data/ui/ledger_pages tests/unit/test_character_ledger_shell.gd
git commit -m "feat: add modular character ledger shell"
```

---

### Task 4: Complete the Stats page and real modifier details

**Files:**
- Modify: `scripts/ui/ledger/stats_ledger_page.gd`
- Modify: `scenes/ui/ledger/stats_ledger_page.tscn`
- Modify: `data/stats/core_stats.tres`
- Test: `tests/unit/test_stats_ledger_page.gd`

**Interfaces:**
- Consumes: `LedgerDataProvider.member_rows()`, `stat_rows()`, and `stat_detail()`.
- Produces: `StatsLedgerPage.set_show_all(enabled: bool) -> void`
- Produces: `StatsLedgerPage.select_stat(stat_id: StringName) -> bool`

- [ ] **Step 1: Write the failing Stats page suite**

Create a suite that configures the page with a Fighter provider and asserts:

```gdscript
var page := (load("res://scenes/ui/ledger/stats_ledger_page.tscn") as PackedScene).instantiate() as StatsLedgerPage
var context := LedgerPlayerContext.new(0)
context.selected_member_id = 1
page.configure(provider, context)
page.refresh()
TestAssertions.truthy("Fighter" in (page.get_node("Layout/Header/Identity") as Label).text, "header identifies selected class", failures)
TestAssertions.truthy(page.has_stat(&"physical_damage"), "fighter shows relevant physical stat", failures)
TestAssertions.truthy(not page.has_stat(&"fire_damage"), "fighter hides irrelevant fire stat", failures)
page.set_show_all(true)
TestAssertions.truthy(page.has_stat(&"fire_damage"), "Show All reveals fire stat", failures)
TestAssertions.truthy(page.select_stat(&"armor"), "armor detail opens", failures)
TestAssertions.truthy("Armor" in (page.get_node("Layout/Content/DetailPanel/Detail/Title") as Label).text, "detail shows canonical stat title", failures)
TestAssertions.truthy("Base" in (page.get_node("Layout/Content/DetailPanel/Detail/Sources") as Label).text, "detail lists resolver base source", failures)
```

- [ ] **Step 2: Run RED**

Expected: node contract and complete Stats methods are absent.

- [ ] **Step 3: Build the approved split-sheet scene**

Replace the temporary scene body with:

```text
StatsLedgerPage
└── Layout (VBoxContainer, full rect)
    ├── Header (VBoxContainer)
    │   ├── Identity (Label)
    │   └── TraitsAndCapabilities (Label)
    └── Content (SplitContainer)
        ├── StatSide (VBoxContainer)
        │   ├── ShowAll (CheckButton, "Show All Stats")
        │   └── StatScroll (ScrollContainer)
        │       └── Groups (VBoxContainer)
        └── DetailPanel (PanelContainer)
            └── Detail (VBoxContainer)
                ├── Title (Label)
                ├── Value (Label)
                ├── Description (Label, autowrap)
                ├── Cap (Label)
                └── Sources (Label, autowrap)
```

- [ ] **Step 4: Implement contextual groups and detail selection**

Implement `refresh()` to:

- Read the selected member row and render name, class, rank, role, health, traits, and capabilities.
- Clear only generated group/row controls.
- Create group headings in provider order.
- Create one focusable Button per stat with `display_name` left and `formatted_value` right.
- Connect both `pressed` and `focus_entered` to `select_stat(stat_id)`.
- Preserve the selected stat when it remains visible; otherwise select the first row.
- Return the first stat Button from `initial_focus()`.

Implement `select_stat()` to format source rows:

```gdscript
func _source_line(row: Dictionary) -> String:
	var operation := int(row.get("operation", -1))
	var label := str(row.get("source_label", row.get("source_id", "Unknown")))
	var value := float(row.get("value", 0.0))
	match operation:
		-1: return "%s: %s" % [label, _number(value)]
		StatModifier.Operation.FLAT: return "%s: %+g flat" % [label, value]
		StatModifier.Operation.INCREASED: return "%s: %+g%% increased" % [label, value * 100.0]
		StatModifier.Operation.REDUCED: return "%s: %+g%% reduced" % [label, value * 100.0]
		StatModifier.Operation.MORE: return "%s: %+g%% more" % [label, value * 100.0]
		StatModifier.Operation.LESS: return "%s: %+g%% less" % [label, value * 100.0]
		_: return "%s: %g" % [label, value]
```

Do not calculate an armor estimate in this task. The current combat model has no shared reference-hit helper; omitting the estimate obeys the spec's rule against UI-only approximations.

- [ ] **Step 5: Separate resistance registry grouping**

In `data/stats/core_stats.tres`, change only these four definitions from `ui_group = &"defense"` to `ui_group = &"resistances"`:

- `fire_resistance`
- `cold_resistance`
- `lightning_resistance`
- `chaos_resistance`

Add an assertion that Show All groups those rows under Resistances.

- [ ] **Step 6: Verify GREEN and commit**

```powershell
& $godot --headless --path $project --editor --quit-after 2
& $godot --headless --path $project --script res://tests/test_runner.gd
git diff --check
git add scripts/ui/ledger/stats_ledger_page.gd scenes/ui/ledger/stats_ledger_page.tscn data/stats/core_stats.tres tests/unit/test_stats_ledger_page.gd
git commit -m "feat: add resolved character stats page"
```

---

### Task 5: Complete Current Upgrades and Coming Soon behavior

**Files:**
- Modify: `scripts/ui/ledger/upgrades_ledger_page.gd`
- Modify: `scenes/ui/ledger/upgrades_ledger_page.tscn`
- Modify: `scripts/ui/ledger/character_ledger.gd`
- Test: `tests/unit/test_upgrades_ledger_page.gd`

**Interfaces:**
- Consumes: `LedgerDataProvider.upgrade_rows()` and `upgrade_detail()`.
- Produces: `UpgradesLedgerPage.select_upgrade(upgrade_id: StringName) -> bool`
- Produces: one collapsed row per applicable upgrade source.

- [ ] **Step 1: Write the failing Upgrades page suite**

The suite must:

1. Initialize Fighter.
2. Apply Vitality twice to member 1.
3. Apply one party damage rank.
4. Configure and refresh the page.
5. Assert Vitality appears once with `Rank 2`.
6. Assert Party Damage appears for the selected member.
7. Assert an unrelated Mage signature is absent.
8. Select Vitality and assert the right panel contains its definition and keywords.
9. Configure a fresh party and assert `No upgrades acquired yet.` is visible.

Use actual catalog Resources and `UpgradeApplicationService.apply()`; do not fabricate UI-only upgrade definitions for the main assertions.

- [ ] **Step 2: Run RED**

Expected: the temporary Upgrades page cannot build rows or details.

- [ ] **Step 3: Build the Upgrades split-sheet scene**

```text
UpgradesLedgerPage
└── Layout (VBoxContainer, full rect)
    ├── Header (Label, "Current Upgrades")
    └── Content (SplitContainer)
        ├── UpgradeSide (VBoxContainer)
        │   ├── EmptyState (Label)
        │   └── UpgradeScroll (ScrollContainer)
        │       └── UpgradeRows (VBoxContainer)
        └── DetailPanel (PanelContainer)
            └── Detail (VBoxContainer)
                ├── Title (Label)
                ├── Rank (Label)
                ├── Ownership (Label)
                ├── Description (Label, autowrap)
                ├── Effects (Label, autowrap)
                ├── Applicability (Label, autowrap)
                └── Keywords (Label, autowrap)
```

- [ ] **Step 4: Implement applicable rows and details**

`refresh()` must:

- Clear generated rows.
- Call `provider.upgrade_rows(context.selected_member_id)`.
- Show EmptyState only for an empty result.
- Create one focusable Button per returned row.
- Render display name, rank text, and ownership badge.
- Store the row by ID in a private dictionary.
- Connect `pressed` and `focus_entered` to `select_upgrade()`.
- Preserve the selected ID if still present.

`select_upgrade()` must:

- Reject unknown IDs without clearing the current detail.
- Call `provider.upgrade_detail(row)`.
- Populate every right-pane label.
- Use `Missing definition: <id>` for an absent keyword returned by the presentation service.

- [ ] **Step 5: Verify Coming Soon focus and activation**

Extend the suite to instantiate the full ledger and assert:

- Equipment and Inventory has a visible tab.
- The tab is focusable.
- Direct activation returns false.
- Active page stays Current Upgrades.
- Status reads `Equipment & Inventory: Coming Soon`.
- Page-cycle actions skip the Coming Soon descriptor.

- [ ] **Step 6: Verify GREEN and commit**

```powershell
& $godot --headless --path $project --editor --quit-after 2
& $godot --headless --path $project --script res://tests/test_runner.gd
git diff --check
git add scripts/ui/ledger/upgrades_ledger_page.gd scripts/ui/ledger/character_ledger.gd scenes/ui/ledger/upgrades_ledger_page.tscn tests/unit/test_upgrades_ledger_page.gd
git commit -m "feat: add current character upgrades page"
```

---

### Task 6: Run pause menu, Quit Run confirmation, and main-scene integration

**Files:**
- Create: `scripts/ui/run_pause_menu.gd`
- Create: `scenes/ui/run_pause_menu.tscn`
- Modify: `scripts/game/main.gd:4-26, 71-79, 157-192, 298-303`
- Modify: `scenes/game/main.tscn`
- Test: `tests/unit/test_run_pause_menu.gd`
- Modify: `tests/unit/test_main_wiring.gd`

**Interfaces:**
- Consumes: `CharacterLedger.is_open()`.
- Produces: `RunPauseMenu.configure(run: GameRun, ledger_open_provider: Callable) -> void`
- Produces: `RunPauseMenu.open() -> bool`
- Produces: `RunPauseMenu.close() -> void`
- Produces: signal `RunPauseMenu.quit_run_confirmed`
- Produces: `PartyForgeMain._return_to_front_end() -> void`

- [ ] **Step 1: Write the failing pause-menu suite**

Create `tests/unit/test_run_pause_menu.gd`:

```gdscript
extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var menu := (load("res://scenes/ui/run_pause_menu.tscn") as PackedScene).instantiate() as RunPauseMenu
	var run := GameRun.new()
	run.start_run()
	menu.configure(run, func() -> bool: return false)
	TestAssertions.truthy(menu.open(), "pause menu opens during active run", failures)
	TestAssertions.truthy((Engine.get_main_loop() as SceneTree).paused, "pause menu pauses run", failures)
	TestAssertions.truthy((menu.get_node("Overlay/Panel/Content/Settings") as Button).has_meta("coming_soon"), "Settings is marked Coming Soon", failures)
	(menu.get_node("Overlay/Panel/Content/QuitRun") as Button).pressed.emit()
	TestAssertions.truthy((menu.get_node("Overlay/QuitConfirmation") as Control).visible, "Quit Run requires confirmation", failures)
	var quit_count := [0]
	menu.quit_run_confirmed.connect(func() -> void: quit_count[0] += 1)
	(menu.get_node("Overlay/QuitConfirmation/Panel/Content/Confirm") as Button).pressed.emit()
	TestAssertions.equal(quit_count[0], 1, "confirmed Quit Run emits once", failures)
	menu.free()
	(Engine.get_main_loop() as SceneTree).paused = false
	return failures
```

Add required paths and nodes to `test_main_wiring.gd` for CharacterLedger and RunPauseMenu.

- [ ] **Step 2: Run RED**

Expected: pause scene and integrated nodes are absent.

- [ ] **Step 3: Create the pause-menu scene**

```text
RunPauseMenu (CanvasLayer, visible=false, process_mode=ALWAYS, RunPauseMenu)
└── Overlay (Control, full rect, mouse_filter=STOP)
    ├── Dimmer (ColorRect, full rect)
    ├── Panel (PanelContainer, centered 480x360)
    │   └── Content (VBoxContainer)
    │       ├── Title (Label, "Paused")
    │       ├── Resume (Button)
    │       ├── Settings (Button, focusable)
    │       └── QuitRun (Button)
    └── QuitConfirmation (Control, full rect, visible=false)
        └── Panel (PanelContainer, centered 560x280)
            └── Content (VBoxContainer)
                ├── Message (Label, "Quit this run? Unsaved run progress will be lost.")
                ├── Confirm (Button, "Quit Run")
                └── Cancel (Button)
```

Settings remains focusable. In `_ready()`, call `settings_button.set_meta("coming_soon", true)` so the development state is inspectable and tested. Pressing it writes `Settings: Coming Soon` into the Title or a dedicated status Label and performs no navigation.

- [ ] **Step 4: Implement pause ownership and input**

`RunPauseMenu` must:

- Open only in RUNNING or BOSS.
- Refuse to open when `ledger_open_provider.call()` is true.
- Acquire its own `RunPauseLease`.
- Close and release on Resume or `pause_menu`.
- Show QuitConfirmation without releasing pause.
- Emit `quit_run_confirmed` once when Confirm is pressed.
- Hide confirmation and return focus to QuitRun on Cancel.
- Mark handled input.

- [ ] **Step 5: Integrate both overlays without touching HUD scripts**

In `scenes/game/main.tscn`, add CharacterLedger and RunPauseMenu as siblings after HUD so they draw above it.

In `PartyForgeMain`:

```gdscript
var character_ledger: CharacterLedger
var run_pause_menu: RunPauseMenu
```

Cache both nodes in `_cache_nodes()`. In `_wire_static_ui()`:

```gdscript
character_ledger.configure(game_run, party_manager, catalog, Callable(self, "_ledger_health_for_member"))
run_pause_menu.configure(game_run, Callable(character_ledger, "is_open"))
if not run_pause_menu.quit_run_confirmed.is_connected(_return_to_front_end):
	run_pause_menu.quit_run_confirmed.connect(_return_to_front_end)
```

Add:

```gdscript
func _ledger_health_for_member(member_id: int) -> Dictionary:
	var actors := get_node_or_null("Actors")
	if actors == null:
		return {}
	for child: Node in actors.get_children():
		var actor := child as PartyActor
		if actor == null or not is_instance_valid(actor) or actor.is_queued_for_deletion():
			continue
		if actor.member_state == null or actor.member_state.member_id != member_id:
			continue
		var health := actor.get_node_or_null("HealthComponent") as HealthComponent
		if health == null:
			return {}
		return {
			"current": health.current_health,
			"maximum": health.max_health,
			"is_downed": health.is_downed,
			"is_dead": health.is_dead,
			"component": health,
		}
	return {}

func _return_to_front_end() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
```

The ledger-specific health provider intentionally does not stop at `PartyManager.MAX_PARTY_SIZE`; it must report any exceptional current members represented in the actor tree. The current Quit Run route reloads the scene and returns to visible class selection. Do not call `_quit()`, which closes the desktop application from the existing result panel.

- [ ] **Step 6: Verify integration and commit**

Run import, full suite, and diff check. Assert main starts with both overlays hidden and class selection visible.

```powershell
git add scripts/ui/run_pause_menu.gd scenes/ui/run_pause_menu.tscn scripts/game/main.gd scenes/game/main.tscn tests/unit/test_run_pause_menu.gd tests/unit/test_main_wiring.gd
git commit -m "feat: integrate ledger and run pause menu"
```

---

### Task 7: Responsive policy, controller focus, and pause-state edge cases

**Files:**
- Create: `scripts/ui/ledger/ledger_responsive_layout.gd`
- Modify: `scripts/ui/ledger/character_ledger.gd`
- Modify: `scripts/ui/ledger/stats_ledger_page.gd`
- Modify: `scripts/ui/ledger/upgrades_ledger_page.gd`
- Modify: `scenes/ui/ledger/character_ledger.tscn`
- Modify: `scenes/ui/ledger/stats_ledger_page.tscn`
- Modify: `scenes/ui/ledger/upgrades_ledger_page.tscn`
- Test: `tests/unit/test_ledger_responsive_input.gd`
- Modify: `tests/unit/test_responsive_ui.gd`

**Interfaces:**
- Produces: `LedgerResponsiveLayout.mode_for_size(size: Vector2) -> Mode`
- Produces: `CharacterLedger.apply_viewport_size(size: Vector2) -> void`
- Produces: `StatsLedgerPage.apply_compact(compact: bool) -> void`
- Produces: `UpgradesLedgerPage.apply_compact(compact: bool) -> void`

- [ ] **Step 1: Write failing responsive and controller tests**

Create `tests/unit/test_ledger_responsive_input.gd` asserting:

- 1920×1080 and 3840×2160 resolve to DESKTOP.
- 960×540 resolves to COMPACT.
- Desktop outer split is horizontal with one party-rail column.
- Compact outer split is vertical with three party-rail columns.
- Stats and Upgrades detail splits become vertical in compact mode.
- Bumper actions move Stats to Current Upgrades and back.
- Coming Soon is skipped.
- Focus returns to the originating row after a compact detail panel closes.
- Selection style includes a non-color border or text marker.

Extend `test_responsive_ui.gd` to assert CharacterLedger and RunPauseMenu roots are full rect and their primary panels remain contained at 1280×720, 1920×1080, and 3840×2160.

- [ ] **Step 2: Run RED**

Expected: responsive helper and explicit compact contracts are absent.

- [ ] **Step 3: Implement deterministic responsive behavior**

Create:

```gdscript
class_name LedgerResponsiveLayout
extends RefCounted

enum Mode { DESKTOP, COMPACT }
const COMPACT_WIDTH := 1100.0
const COMPACT_HEIGHT := 650.0

static func mode_for_size(size: Vector2) -> Mode:
	return Mode.COMPACT if size.x < COMPACT_WIDTH or size.y < COMPACT_HEIGHT else Mode.DESKTOP
```

`CharacterLedger.apply_viewport_size()` must:

- Set the outer `SplitContainer.vertical` in COMPACT.
- Set PartyEntries columns to 3 in COMPACT and 1 in DESKTOP.
- Ask every instantiated page to apply the same mode.
- Never reduce theme font sizes.
- Keep tooltips and status labels inside Overlay.

Each page's `apply_compact()` toggles its center/detail SplitContainer orientation. The compact detail panel may occupy the lower stack; it must not become a free-floating OS window.

- [ ] **Step 4: Complete controller focus behavior**

Implement:

- Explicit first-focus selection on open.
- Focus restoration from `LedgerPlayerContext.last_focus_path` when valid.
- Page Buttons and member Buttons with `focus_mode = FOCUS_ALL`.
- `ui_accept` pins the current detail.
- `ui_cancel` first closes a compact pinned detail, then closes the ledger.
- Bumpers cycle only AVAILABLE descriptors.
- Coming Soon buttons remain focusable and explain themselves on focus or activation.
- Member selection uses a text prefix, border StyleBox, or icon in addition to class color.

Do not add local-player devices or multiple viewports.

- [ ] **Step 5: Verify level-up and boss pause restoration**

Add focused assertions:

```gdscript
run.begin_level_up()
TestAssertions.truthy(tree.paused, "level-up owns pause before ledger", failures)
ledger.open_for_player()
ledger.close()
TestAssertions.truthy(tree.paused, "ledger close preserves level-up pause", failures)
run.resume_run()
TestAssertions.truthy(not tree.paused, "level-up resume still controls its pause", failures)
```

Repeat with a BOSS run state and require ledger close to restore unpaused BOSS.

- [ ] **Step 6: Verify GREEN and commit**

```powershell
& $godot --headless --path $project --editor --quit-after 2
& $godot --headless --path $project --script res://tests/test_runner.gd
git diff --check
git add scripts/ui/ledger scenes/ui/ledger tests/unit/test_ledger_responsive_input.gd tests/unit/test_responsive_ui.gd
git commit -m "feat: add responsive controller ledger behavior"
```

---

### Task 8: Documentation, full verification, and live acceptance

**Files:**
- Modify: `docs/handbook/10-party-forge-architecture-reference.md`
- Modify: `docs/development/GODOT_SKILL_CANDIDATES.md`

**Interfaces:**
- Consumes: all prior task outputs.
- Produces: verified, documented milestone ready for review and integration.

- [ ] **Step 1: Update the architecture reference**

Document:

- CharacterLedger ownership.
- Page descriptors and feature-gate states.
- LedgerDataProvider as the only page-facing domain adapter.
- Stats and Upgrades data flow.
- Character Ledger versus pause-menu input.
- Current front-end return route.
- Current single-player boundary and future per-player context.

Use exact current paths and explicitly mark Equipment, Developer Mode, persistence, local multiplayer, and dynamic cameras as deferred.

- [ ] **Step 2: Record reusable Godot skill candidates**

In `docs/development/GODOT_SKILL_CANDIDATES.md`, add bounded candidates for:

- Building a full-screen, pause-safe modal without stealing another modal's pause.
- Creating registry-backed, controller-focusable page tabs.
- Testing responsive Godot UI at desktop and compact viewport sizes.
- Building read-only UI adapters over Resources and resolver snapshots.

Each candidate must list trigger, inputs, outputs, safety checks, and verification commands. Do not create or install Codex skills in this milestone.

- [ ] **Step 3: Run fresh automated verification**

```powershell
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
$project = (Get-Location).Path
& $godot --headless --path $project --editor --quit-after 2
$importExit = $LASTEXITCODE
& $godot --headless --path $project --script res://tests/test_runner.gd
$testExit = $LASTEXITCODE
git diff --check
$diffExit = $LASTEXITCODE
if ($importExit -ne 0 -or $testExit -ne 0 -or $diffExit -ne 0) { exit 1 }
```

Expected: import exit `0`; test exit `0`; `TEST_SUMMARY: PASS`; diff check exit `0`; no unexpected `SCRIPT ERROR`, warning, or `TEST_FAILURE`.

- [ ] **Step 4: Run live Godot acceptance through the connected editor**

Use the main scene at 1920×1080:

1. Select Fighter and start the run.
2. Press `Tab`; require ledger open and combat frozen.
3. Inspect Fighter Stats, contextual rows, Show All, and one modifier breakdown.
4. Switch to Current Upgrades with keyboard and controller bumper.
5. Focus Equipment and Inventory; require **Coming Soon** and no page switch.
6. Close with `Escape`; require combat resumes.
7. Trigger level-up, open the ledger with `I`, close it, and require the same offer remains with gameplay paused.
8. Complete the level-up and require normal resume.
9. Press `Escape` from gameplay; require the separate pause menu.
10. Focus Settings; require **Coming Soon**.
11. Cancel Quit Run once, then confirm it; require return to class selection.
12. Resize to 3840×2160 and repeat a layout smoke.

After driving the game, read both game and editor logs with details. Require:

- `PARTY_FORGE_BOOT_OK`
- `PARTY_FORGE_CLASS_SELECTION_READY`
- No new editor script errors.
- No new game warnings or errors.

Stop the game and leave the editor open and ready. Do not call `scene_save`.

- [ ] **Step 5: Review preservation scope**

Run:

```powershell
git status --short
git diff --name-only main...HEAD
git diff --check
```

Require:

- Only milestone paths are changed.
- `scripts/ui/hud.gd`, `scripts/game/game_run.gd`, `scripts/ui/run_result_panel.gd`, and the existing handbook plan are absent from the changed path list.
- GodotSteam files and projectile tuning are unchanged.
- No `.godot/`, `.superpowers/`, or worktree contents are tracked.

- [ ] **Step 6: Commit documentation**

If Steps 3–5 require a correction, return to the task that owns that file, repeat its RED/GREEN cycle, and create its focused commit before continuing. Do not fold implementation corrections into the documentation commit.

```powershell
git add docs/handbook/10-party-forge-architecture-reference.md docs/development/GODOT_SKILL_CANDIDATES.md
git diff --cached --check
git commit -m "docs: document character ledger architecture"
```

- [ ] **Step 7: Request code review**

Invoke `superpowers:requesting-code-review`. Provide:

- Design spec path.
- Plan path.
- Commit range from the pre-implementation baseline through HEAD.
- Automated test and import evidence.
- Live acceptance results.
- Preserved dirty-main paths.

Resolve correctness findings before offering integration options.
