# Character Ledger Party Count and Combat Estimates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Display live party occupancy above the character ledger roster and truthful per-action hit/critical/average/DPS estimates on each character's Stats page.

**Architecture:** Add a typed, target-independent combat-estimate read model and a pure estimator that reuses action-aware PartyManager stats without altering combat. LedgerDataProvider adapts the current primary/support action slots into ordered estimates, while CharacterLedger and StatsLedgerPage only render the resulting data. The action-source adapter is the sole future change point when basic, multiple-primary, and multiple-ultimate slots are authored.

**Tech Stack:** Godot 4.7.1, typed GDScript, Godot Resources, existing RefCounted unit-test harness, `.tscn` UI scenes.

## Global Constraints

- Work only in `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\ledger-combat-estimates` on `feat/ledger-combat-estimates`.
- Do not modify class models, equipment data, animations, presentation scenes, or the active `feat/playable-class-presentations` worktree.
- Do not expand `ClassDefinition` action slots in this change.
- Do not change runtime damage, cooldown, critical-strike, targeting, or mitigation behavior.
- Estimates are pre-mitigation, per target, and assume continuous use on cooldown.
- Preserve the existing `Damage`, typed-damage, critical-strike, and attack-speed multiplier rows.
- Healing-only actions do not appear in Combat Estimates.
- Floating combat text and measured damage/healing telemetry remain separate systems.
- Every production change follows a witnessed RED then GREEN test cycle.
- Godot executable: `F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe`.

## File structure

**Create**

- `scripts/ui/ledger/action_combat_estimate.gd` — typed read model for one action and its ordered component rows.
- `scripts/ui/ledger/action_combat_estimate_service.gd` — pure estimate formulas and validation.
- `tests/unit/test_action_combat_estimate_service.gd` — formula, mixed-damage, non-critical, and invalid-data coverage.

**Modify**

- `scripts/ui/ledger/ledger_data_provider.gd` — current action-slot adapter and stable estimate list.
- `scripts/ui/ledger/stats_ledger_page.gd` — Combat Estimates rendering and formatting.
- `scenes/ui/ledger/character_ledger.tscn` — roster column and party-count label.
- `scripts/ui/ledger/character_ledger.gd` — live count text, revised node paths, responsive sizing.
- `tests/unit/test_ledger_data_provider.gd` — action discovery, order, duplicate suppression, healing exclusion.
- `tests/unit/test_stats_ledger_page.gd` — visible estimate cards, mixed-component text, existing focus/stat behavior.
- `tests/unit/test_character_ledger_shell.gd` — live party count and revised roster paths.
- `tests/integration/ledger_24_member_runner.gd` — revised paths, capacity label, 24-member scrolling in both layouts.

---

### Task 1: Typed per-action combat estimator

**Files:**
- Create: `scripts/ui/ledger/action_combat_estimate.gd`
- Create: `scripts/ui/ledger/action_combat_estimate_service.gd`
- Create: `tests/unit/test_action_combat_estimate_service.gd`

**Interfaces:**
- Consumes: `AttackDefinition`, `PartyManager.stats_for_action(member_id, action_tags)`, `PartyManager.stats_for(member_id)`, `DamageResolver.action_tags_for(attack)`, `DamageTypeCatalog.definition(type_id)`.
- Produces: `ActionCombatEstimateService.estimate(attack: AttackDefinition, member_id: int, party: PartyManager, types: DamageTypeCatalog) -> ActionCombatEstimate`.
- Produces model fields: `action_id`, `display_name`, `available`, `unavailable_reason`, `can_crit`, `normal_hit`, `critical_hit`, `average_hit`, `attacks_per_second`, `estimated_dps`, and `component_rows`.

- [ ] **Step 1: Write the failing estimator tests**

Create `tests/unit/test_action_combat_estimate_service.gd` with a real Ranger fixture and these assertions:

```gdscript
extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	_test_action_aware_critical_estimate(failures)
	_test_noncritical_mixed_damage(failures)
	_test_invalid_damage_type_is_unavailable(failures)
	return failures

func _test_action_aware_critical_estimate(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"ranger"), catalog.traits)
	var source := StatModifierSource.create(&"estimate_fixture", &"test", "Estimate Fixture", 1, [
		StatModifier.create(&"damage", StatModifier.Operation.INCREASED, 0.50, &"projectile_damage", "Projectile Damage", [&"projectile"]),
		StatModifier.create(&"physical_damage", StatModifier.Operation.INCREASED, 0.20, &"physical_damage", "Physical Damage", [&"physical"]),
		StatModifier.create(&"crit_chance", StatModifier.Operation.FLAT, 0.25, &"crit_chance", "Critical Chance"),
		StatModifier.create(&"attack_speed", StatModifier.Operation.INCREASED, 0.10, &"attack_speed", "Attack Speed"),
	])
	TestAssertions.truthy(party.add_member_source(1, source), "estimate fixture source applies", failures)
	var estimate := ActionCombatEstimateService.estimate(catalog.class_by_id(&"ranger").primary_attack, 1, party, catalog.damage_types)
	TestAssertions.truthy(estimate.available, "valid Ranger estimate is available", failures)
	TestAssertions.near(estimate.normal_hit, 19.8, 0.001, "normal hit uses global and physical action modifiers", failures)
	TestAssertions.near(estimate.critical_hit, 29.7, 0.001, "critical hit uses 1.5 multiplier", failures)
	TestAssertions.near(estimate.average_hit, 22.275, 0.001, "average hit weights 25 percent crit chance", failures)
	TestAssertions.near(estimate.attacks_per_second, 2.0, 0.001, "attack speed divides authored cooldown", failures)
	TestAssertions.near(estimate.estimated_dps, 44.55, 0.001, "DPS uses average hit and attacks per second", failures)
	party.free()

func _test_noncritical_mixed_damage(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var attack := AttackDefinition.new()
	attack.id = &"mixed_test"
	attack.kind = AttackDefinition.Kind.MELEE_CLEAVE
	attack.cooldown = 2.0
	attack.range = 2.0
	attack.can_crit = false
	attack.action_tags = [&"melee"]
	attack.damage_components = [_component(&"physical", 10.0), _component(&"fire", 5.0)]
	var estimate := ActionCombatEstimateService.estimate(attack, 1, party, catalog.damage_types)
	TestAssertions.truthy(estimate.available and not estimate.can_crit, "mixed noncritical estimate is available", failures)
	TestAssertions.near(estimate.normal_hit, 15.0, 0.001, "mixed components sum into one hit", failures)
	TestAssertions.near(estimate.average_hit, 15.0, 0.001, "noncritical average equals normal", failures)
	TestAssertions.equal(estimate.component_rows.map(func(row: Dictionary) -> StringName: return row.damage_type_id), [&"physical", &"fire"], "component order stays authored", failures)
	party.free()

func _test_invalid_damage_type_is_unavailable(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var party := PartyManager.new()
	party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
	var attack := catalog.class_by_id(&"fighter").primary_attack.duplicate(true) as AttackDefinition
	attack.damage_components = [_component(&"void", 10.0)]
	var estimate := ActionCombatEstimateService.estimate(attack, 1, party, catalog.damage_types)
	TestAssertions.truthy(not estimate.available, "unknown type cannot produce invented numbers", failures)
	TestAssertions.truthy("Unknown damage type" in estimate.unavailable_reason, "unavailable reason names the invalid boundary", failures)
	party.free()

func _component(type_id: StringName, amount: float) -> AttackDamageComponent:
	var result := AttackDamageComponent.new()
	result.damage_type_id = type_id
	result.base_amount = amount
	return result
```

- [ ] **Step 2: Run the suite and verify RED**

Run:

```powershell
$env:APPDATA = Join-Path (Get-Location) '.superpowers\sdd\task1-red-appdata'
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path (Get-Location).Path --script res://tests/test_runner.gd --quit-after 120
```

Expected: `TEST_SUMMARY: FAIL` because `ActionCombatEstimateService` and `ActionCombatEstimate` do not exist. Confirm the failure is not a parser typo in the test.

- [ ] **Step 3: Add the typed model**

Create `scripts/ui/ledger/action_combat_estimate.gd`:

```gdscript
class_name ActionCombatEstimate
extends RefCounted

var action_id: StringName
var display_name := ""
var available := false
var unavailable_reason := ""
var can_crit := false
var normal_hit := 0.0
var critical_hit := 0.0
var average_hit := 0.0
var attacks_per_second := 0.0
var estimated_dps := 0.0
var component_rows: Array[Dictionary] = []
```

- [ ] **Step 4: Implement the minimal pure estimator**

Create `scripts/ui/ledger/action_combat_estimate_service.gd` with this calculation shape:

```gdscript
class_name ActionCombatEstimateService
extends RefCounted

static func estimate(attack: AttackDefinition, member_id: int, party: PartyManager, types: DamageTypeCatalog) -> ActionCombatEstimate:
	var result := ActionCombatEstimate.new()
	if attack == null:
		return _unavailable(result, "Missing attack definition.")
	result.action_id = attack.id
	result.display_name = String(attack.id).replace("_", " ").capitalize()
	if party == null or types == null or member_id <= 0:
		return _unavailable(result, "Missing character combat data.")
	if attack.is_healing() or attack.damage_components.is_empty():
		return _unavailable(result, "Action does not deal direct damage.")
	if not is_finite(attack.cooldown) or attack.cooldown <= 0.0:
		return _unavailable(result, "Invalid action cooldown.")
	var action_stats := party.stats_for_action(member_id, DamageResolver.action_tags_for(attack))
	var cooldown_stats := party.stats_for(member_id)
	if action_stats == null or cooldown_stats == null:
		return _unavailable(result, "Missing resolved character stats.")
	result.can_crit = attack.can_crit
	var crit_chance := action_stats.value(&"crit_chance", 0.0) if result.can_crit else 0.0
	var crit_multiplier := maxf(1.0, action_stats.value(&"crit_multiplier", 1.5))
	for component: AttackDamageComponent in attack.damage_components:
		if component == null:
			return _unavailable(result, "Null damage component.")
		var type_definition := types.definition(component.damage_type_id)
		if type_definition == null:
			return _unavailable(result, "Unknown damage type: %s." % component.damage_type_id)
		var normal := component.base_amount * action_stats.value(&"damage", 1.0) * action_stats.value(type_definition.offense_stat_id, 1.0)
		if not is_finite(normal) or normal < 0.0:
			return _unavailable(result, "Invalid derived damage for %s." % type_definition.display_name)
		var critical := normal * crit_multiplier if result.can_crit else normal
		var average := normal * (1.0 + crit_chance * (crit_multiplier - 1.0))
		result.normal_hit += normal
		result.critical_hit += critical
		result.average_hit += average
		result.component_rows.append({
			"damage_type_id": component.damage_type_id,
			"display_name": type_definition.display_name,
			"normal_hit": normal,
			"critical_hit": critical,
			"average_hit": average,
		})
	result.attacks_per_second = cooldown_stats.value(&"attack_speed", 1.0) / attack.cooldown
	result.estimated_dps = result.average_hit * result.attacks_per_second
	if not is_finite(result.attacks_per_second) or result.attacks_per_second < 0.0 or not is_finite(result.estimated_dps):
		return _unavailable(result, "Invalid derived action rate.")
	result.available = true
	return result

static func _unavailable(result: ActionCombatEstimate, reason: String) -> ActionCombatEstimate:
	result.available = false
	result.unavailable_reason = reason
	return result
```

- [ ] **Step 5: Run the complete suite and verify GREEN**

Run the Step 2 command with `task1-green-appdata`.

Expected: `TEST_SUMMARY: PASS (79 suites)`, zero `SCRIPT ERROR`, zero `TEST_FAILURE`.

- [ ] **Step 6: Commit Task 1**

```powershell
git add scripts/ui/ledger/action_combat_estimate.gd scripts/ui/ledger/action_combat_estimate_service.gd tests/unit/test_action_combat_estimate_service.gd
git commit -m 'feat: calculate per-action combat estimates'
```

---

### Task 2: Ledger action discovery and estimate data

**Files:**
- Modify: `scripts/ui/ledger/ledger_data_provider.gd`
- Modify: `tests/unit/test_ledger_data_provider.gd`

**Interfaces:**
- Consumes: `ActionCombatEstimateService.estimate(...)` from Task 1.
- Produces: `LedgerDataProvider.combat_estimate_rows(member_id: int) -> Array[ActionCombatEstimate]`.
- Current slot order: `primary_attack`, then `support_action`.

- [ ] **Step 1: Add failing provider coverage**

Add `_test_combat_estimate_action_discovery(failures)` to `run()` and implement a copied class fixture with two damaging actions plus duplicate and healing cases:

```gdscript
func _test_combat_estimate_action_discovery(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var definition := catalog.class_by_id(&"fighter").duplicate(true) as ClassDefinition
	definition.id = &"estimate_fixture"
	definition.primary_attack = catalog.class_by_id(&"fighter").primary_attack
	definition.support_action = catalog.class_by_id(&"ranger").primary_attack
	var party := PartyManager.new()
	party.initialize(definition, catalog.traits)
	var provider := LedgerDataProvider.new()
	provider.configure(party, catalog, Callable())
	var rows := provider.combat_estimate_rows(1)
	TestAssertions.equal(rows.map(func(row: ActionCombatEstimate) -> StringName: return row.action_id), [&"fighter_cleave", &"ranger_shot"], "provider preserves authored action-slot order", failures)

	definition.support_action = definition.primary_attack
	party.initialize(definition, catalog.traits)
	rows = provider.combat_estimate_rows(1)
	TestAssertions.equal(rows.size(), 1, "duplicate action ID/resource appears once", failures)

	definition.support_action = catalog.class_by_id(&"cleric").support_action
	party.initialize(definition, catalog.traits)
	rows = provider.combat_estimate_rows(1)
	TestAssertions.equal(rows.size(), 1, "healing-only support action is excluded", failures)
	provider.configure(null, null, Callable())
	party.free()
```

- [ ] **Step 2: Run the suite and verify RED**

Run the Task 1 suite command with `task2-red-appdata`.

Expected: `TEST_SUMMARY: FAIL` because `combat_estimate_rows` is missing.

- [ ] **Step 3: Implement the current-slot adapter**

Add to `LedgerDataProvider`:

```gdscript
func combat_estimate_rows(member_id: int) -> Array[ActionCombatEstimate]:
	var rows: Array[ActionCombatEstimate] = []
	var member := party.member_by_id(member_id) if party != null else null
	if member == null or catalog == null:
		return rows
	var seen_ids: Dictionary = {}
	var seen_instances: Dictionary = {}
	for attack: AttackDefinition in _owned_actions(member.class_definition):
		if attack == null or attack.is_healing() or attack.damage_components.is_empty():
			continue
		var instance_key := attack.get_instance_id()
		if seen_instances.has(instance_key) or (not attack.id.is_empty() and seen_ids.has(attack.id)):
			continue
		seen_instances[instance_key] = true
		if not attack.id.is_empty():
			seen_ids[attack.id] = true
		rows.append(ActionCombatEstimateService.estimate(attack, member_id, party, catalog.damage_types))
	return rows

func _owned_actions(definition: ClassDefinition) -> Array[AttackDefinition]:
	var result: Array[AttackDefinition] = []
	if definition == null:
		return result
	if definition.primary_attack != null:
		result.append(definition.primary_attack)
	if definition.support_action != null:
		result.append(definition.support_action)
	return result
```

- [ ] **Step 4: Run the complete suite and verify GREEN**

Run with `task2-green-appdata`.

Expected: `TEST_SUMMARY: PASS (79 suites)`, zero forbidden markers.

- [ ] **Step 5: Commit Task 2**

```powershell
git add scripts/ui/ledger/ledger_data_provider.gd tests/unit/test_ledger_data_provider.gd
git commit -m 'feat: expose ledger action estimates'
```

---

### Task 3: Render every damaging action on the Stats page

**Files:**
- Modify: `scripts/ui/ledger/stats_ledger_page.gd`
- Modify: `tests/unit/test_stats_ledger_page.gd`

**Interfaces:**
- Consumes: `LedgerDataProvider.combat_estimate_rows(member_id)`.
- Produces nodes under `Layout/Content/StatSide/StatScroll/Groups/Group_combat_estimates/Action_<action_id>`.
- Preserves: `_first_stat_button` as the initial controller/keyboard focus and existing `select_stat()` behavior.

- [ ] **Step 1: Add failing Stats-page rendering assertions**

After the first `page.refresh()` in `test_stats_ledger_page.gd`, add:

```gdscript
	var estimates := page.get_node_or_null("Layout/Content/StatSide/StatScroll/Groups/Group_combat_estimates") as VBoxContainer
	TestAssertions.truthy(estimates != null, "Stats page renders Combat Estimates before stat groups", failures)
	var fighter_card := page.get_node_or_null("Layout/Content/StatSide/StatScroll/Groups/Group_combat_estimates/Action_fighter_cleave") as PanelContainer
	TestAssertions.truthy(fighter_card != null, "selected Fighter primary action has an estimate card", failures)
	if fighter_card != null:
		var metrics := (fighter_card.get_node("Content/Metrics") as Label).text
		TestAssertions.truthy("Normal Hit" in metrics and "Critical Hit" in metrics and "Average Hit" in metrics, "card exposes all hit values", failures)
		TestAssertions.truthy("Attacks / Second" in metrics and "Estimated DPS" in metrics, "card exposes rate and DPS", failures)
		TestAssertions.truthy("pre-mitigation" in fighter_card.tooltip_text and "per target" in fighter_card.tooltip_text, "card explains estimate boundary", failures)
	TestAssertions.truthy(page.initial_focus() is Button and (page.initial_focus() as Button).name.begins_with("Stat_"), "combat estimates do not steal first-stat focus", failures)
```

Update the expected group order to:

```gdscript
[&"Group_combat_estimates", &"Group_overview", &"Group_offense", &"Group_defense", &"Group_resistances", &"Group_utility"]
```

Change the initial Fighter fixture to use a deep copy so the catalog resource is never mutated:

```gdscript
	var fighter := catalog.class_by_id(&"fighter").duplicate(true) as ClassDefinition
	party.initialize(fighter, catalog.traits)
```

After the initial Fighter estimate assertions, add a mixed-component action and refresh:

```gdscript
	var mixed_attack := fighter.primary_attack.duplicate(true) as AttackDefinition
	mixed_attack.id = &"mixed_preview"
	mixed_attack.damage_components = [_damage_component(&"physical", 10.0), _damage_component(&"fire", 5.0)]
	fighter.primary_attack = mixed_attack
	page.refresh()
	var mixed_components := (page.get_node("Layout/Content/StatSide/StatScroll/Groups/Group_combat_estimates/Action_mixed_preview/Content/Components") as Label).text
	TestAssertions.truthy("Physical" in mixed_components and "Fire" in mixed_components, "mixed estimate exposes each damage-type component", failures)
```

Add this fixture helper to the test file:

```gdscript
func _damage_component(type_id: StringName, amount: float) -> AttackDamageComponent:
	var result := AttackDamageComponent.new()
	result.damage_type_id = type_id
	result.base_amount = amount
	return result
```

- [ ] **Step 2: Run the suite and verify RED**

Run with `task3-red-appdata`.

Expected: `TEST_SUMMARY: FAIL` because `Group_combat_estimates` does not exist.

- [ ] **Step 3: Render the Combat Estimates group before ordinary stats**

In `StatsLedgerPage.refresh()`, call `_render_combat_estimates()` immediately after `_render_header(member)` and before creating ordinary stat groups.

Add these methods:

```gdscript
func _render_combat_estimates() -> void:
	var group := _create_group(&"combat_estimates")
	(group.get_node("Heading") as Label).text = "Combat Estimates"
	group.tooltip_text = "Pre-mitigation damage per target, assuming continuous use whenever each action is ready."
	for estimate: ActionCombatEstimate in provider.combat_estimate_rows(context.selected_member_id):
		group.add_child(_create_combat_estimate_card(estimate))

func _create_combat_estimate_card(estimate: ActionCombatEstimate) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Action_%s" % estimate.action_id
	panel.tooltip_text = "Pre-mitigation damage per target; excludes defenses, misses, travel time, movement, and AI downtime."
	var content := VBoxContainer.new()
	content.name = "Content"
	var title := Label.new()
	title.name = "Title"
	title.text = estimate.display_name
	content.add_child(title)
	var metrics := Label.new()
	metrics.name = "Metrics"
	metrics.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if estimate.available:
		var critical_text := _estimate_number(estimate.critical_hit) if estimate.can_crit else "Cannot Crit"
		metrics.text = "Normal Hit: %s\nCritical Hit: %s\nAverage Hit: %s\nAttacks / Second: %.2f\nEstimated DPS: %s" % [
			_estimate_number(estimate.normal_hit), critical_text, _estimate_number(estimate.average_hit),
			estimate.attacks_per_second, _estimate_number(estimate.estimated_dps),
		]
	else:
		metrics.text = "Estimate unavailable: %s" % estimate.unavailable_reason
	content.add_child(metrics)
	var components := Label.new()
	components.name = "Components"
	components.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	components.visible = estimate.available and estimate.component_rows.size() > 1
	var component_lines := PackedStringArray()
	for row: Dictionary in estimate.component_rows:
		component_lines.append("%s: %s normal" % [row.display_name, _estimate_number(float(row.normal_hit))])
	components.text = "Damage Types\n%s" % "\n".join(component_lines)
	content.add_child(components)
	panel.add_child(content)
	return panel

func _estimate_number(value: float) -> String:
	return ("%.2f" % value).rstrip("0").rstrip(".")
```

If no damaging actions exist, keep the heading and add one label with `No damaging actions available.` so the section never disappears ambiguously.

- [ ] **Step 4: Run the complete suite and verify GREEN**

Run with `task3-green-appdata`.

Expected: `TEST_SUMMARY: PASS (79 suites)`, existing stat selection/detail/focus tests still pass.

- [ ] **Step 5: Commit Task 3**

```powershell
git add scripts/ui/ledger/stats_ledger_page.gd tests/unit/test_stats_ledger_page.gd
git commit -m 'feat: show action damage estimates in ledger'
```

---

### Task 4: Live party occupancy above the roster

**Files:**
- Modify: `scenes/ui/ledger/character_ledger.tscn`
- Modify: `scripts/ui/ledger/character_ledger.gd`
- Modify: `tests/unit/test_character_ledger_shell.gd`
- Modify: `tests/integration/ledger_24_member_runner.gd`

**Interfaces:**
- Consumes: `PartyManager.members.size()` and `PartyManager.capacity()`.
- Produces: label at `Overlay/Frame/Layout/Body/PartyColumn/PartyCount` with exact text `Party Members: <current> / <capacity>`.
- Moves existing roster paths under `Body/PartyColumn/PartyScroll` without changing member button names or focus metadata.

- [ ] **Step 1: Add failing unit assertions for live occupancy**

Update roster paths in `test_character_ledger_shell.gd` and add:

```gdscript
	var party_count := ledger.get_node("Overlay/Frame/Layout/Body/PartyColumn/PartyCount") as Label
	TestAssertions.equal(party_count.text, "Party Members: 1 / 4", "ledger shows live production occupancy", failures)
	TestAssertions.truthy(party.recruit(catalog.class_by_id(&"fighter")), "provider refresh fixture recruits a member", failures)
	TestAssertions.equal(party_count.text, "Party Members: 2 / 4", "party signal refreshes occupancy", failures)
```

Keep the existing rail child-count assertion after recruitment; do not duplicate the recruit call already in the test.

- [ ] **Step 2: Update the 24-member integration runner for RED**

Change constants to:

```gdscript
const PARTY_SCROLL_PATH := ^"Overlay/Frame/Layout/Body/PartyColumn/PartyScroll"
const PARTY_COUNT_PATH := ^"Overlay/Frame/Layout/Body/PartyColumn/PartyCount"
const MEMBER_1_PATH := ^"Overlay/Frame/Layout/Body/PartyColumn/PartyScroll/PartyEntries/Member_1"
const MEMBER_24_PATH := ^"Overlay/Frame/Layout/Body/PartyColumn/PartyScroll/PartyEntries/Member_24"
```

After opening each viewport, assert:

```gdscript
_assert((ledger.get_node(PARTY_COUNT_PATH) as Label).text == "Party Members: 24 / 24", "%s count reports all developer members" % mode)
```

In the refresh-lifecycle fixture, assert `Party Members: 2 / 24` before recruitment and `Party Members: 3 / 24` after recruitment. Do not weaken the existing scroll-intersection or directional-focus assertions.

- [ ] **Step 3: Run unit and integration runners and verify RED**

Run the full unit suite with `task4-red-appdata`, then run:

```powershell
$env:APPDATA = Join-Path (Get-Location) '.superpowers\sdd\task4-ledger-red-appdata'
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path (Get-Location).Path --script res://tests/integration/ledger_24_member_runner.gd
```

Expected: both runners fail because `PartyColumn/PartyCount` is absent.

- [ ] **Step 4: Restructure the roster scene**

Replace the first `Body` child with:

```ini
[node name="PartyColumn" type="VBoxContainer" parent="Overlay/Frame/Layout/Body"]
custom_minimum_size = Vector2(260, 0)
layout_mode = 2
size_flags_vertical = 3
theme_override_constants/separation = 8

[node name="PartyCount" type="Label" parent="Overlay/Frame/Layout/Body/PartyColumn"]
layout_mode = 2
text = "Party Members: 0 / 0"

[node name="PartyScroll" type="ScrollContainer" parent="Overlay/Frame/Layout/Body/PartyColumn"]
layout_mode = 2
size_flags_vertical = 3
follow_focus = true
horizontal_scroll_mode = 0

[node name="PartyEntries" type="GridContainer" parent="Overlay/Frame/Layout/Body/PartyColumn/PartyScroll"]
layout_mode = 2
size_flags_horizontal = 3
columns = 1
```

- [ ] **Step 5: Update CharacterLedger paths, text, and responsive sizing**

Add `_refresh_party_count()` at the start of `_rebuild_member_rail()`:

```gdscript
func _refresh_party_count() -> void:
	var current := party.members.size() if party != null else 0
	var maximum := party.capacity() if party != null else 0
	_party_count().text = "Party Members: %d / %d" % [current, maximum]
```

Update `_party_scroll()`, `_party_entries()`, and `_clear_dynamic_ui()` to the `PartyColumn` paths. Add:

```gdscript
func _party_column() -> VBoxContainer:
	return get_node("Overlay/Frame/Layout/Body/PartyColumn") as VBoxContainer

func _party_count() -> Label:
	return get_node("Overlay/Frame/Layout/Body/PartyColumn/PartyCount") as Label
```

In `apply_viewport_size()`, move the old roster minimum sizing from `_party_scroll()` to `_party_column()`:

```gdscript
_party_column().custom_minimum_size = Vector2(0.0, 136.0) if compact else Vector2(260.0, 0.0)
```

- [ ] **Step 6: Run unit and integration runners and verify GREEN**

Run the two Step 3 commands with `task4-green-appdata` and `task4-ledger-green-appdata`.

Expected:

- `TEST_SUMMARY: PASS (79 suites)`
- `LEDGER_24_MEMBER_SUMMARY: PASS (2 viewports)`
- zero script/test/integration failure markers

- [ ] **Step 7: Commit Task 4**

```powershell
git add scenes/ui/ledger/character_ledger.tscn scripts/ui/ledger/character_ledger.gd tests/unit/test_character_ledger_shell.gd tests/integration/ledger_24_member_runner.gd
git commit -m 'feat: show live party capacity in ledger'
```

---

### Task 5: Final integration and regression verification

**Files:**
- Modify only if a verified integration regression requires a scoped correction in the files already listed above.
- Do not alter class/equipment/presentation files during finalization.

**Interfaces:**
- Verifies the Task 1–4 interfaces together.
- Produces no new gameplay interface.

- [ ] **Step 1: Run a clean editor import/parser gate**

```powershell
$env:APPDATA = Join-Path (Get-Location) '.superpowers\sdd\final-import-appdata'
$output = & 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --editor --path (Get-Location).Path --quit 2>&1
$output | Select-String -Pattern 'SCRIPT ERROR|Parse Error|ERROR:'
```

Expected: editor exits 0, `[ DONE ] first_scan_filesystem`, and the filtered error output is empty.

- [ ] **Step 2: Run the complete unit suite from fresh APPDATA**

Use the Task 1 test command with `final-suite-appdata`.

Expected: `TEST_SUMMARY: PASS (79 suites)`, zero `SCRIPT ERROR`, zero `TEST_FAILURE`.

- [ ] **Step 3: Run retained ledger integration coverage**

Run `ledger_24_member_runner.gd` with `final-ledger-appdata`.

Expected: `LEDGER_24_MEMBER_SUMMARY: PASS (2 viewports)` and member 24 remains reachable by mouse/direct focus and directional controller input.

- [ ] **Step 4: Run retained responsive geometry coverage**

```powershell
$env:APPDATA = Join-Path (Get-Location) '.superpowers\sdd\final-responsive-appdata'
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path (Get-Location).Path --script res://tests/integration/responsive_ui_geometry_runner.gd
```

Expected: `RESPONSIVE_GEOMETRY_SUMMARY: PASS (4 sizes)`.

- [ ] **Step 5: Verify scope and clean generated artifacts**

```powershell
git diff --check main...HEAD
git status --short --untracked-files=all
git diff --name-only main...HEAD
```

Expected tracked scope is limited to the design/plan documents and Task 1–4 files. Remove only Godot-generated untracked `.uid` sidecars and generated Hollow Zangetsu `.import` files created inside this isolated worktree; do not touch the main checkout or the other active worktree.

- [ ] **Step 6: Commit any verified final correction separately**

If Step 1–5 required a scoped correction, commit only that correction and its regression test:

```powershell
git add scripts/ui/ledger/action_combat_estimate.gd scripts/ui/ledger/action_combat_estimate_service.gd scripts/ui/ledger/ledger_data_provider.gd scripts/ui/ledger/stats_ledger_page.gd scripts/ui/ledger/character_ledger.gd scenes/ui/ledger/character_ledger.tscn tests/unit/test_action_combat_estimate_service.gd tests/unit/test_ledger_data_provider.gd tests/unit/test_stats_ledger_page.gd tests/unit/test_character_ledger_shell.gd tests/integration/ledger_24_member_runner.gd
git commit -m 'fix: preserve ledger combat estimate integration'
```

If no correction was required, do not create an empty commit.

- [ ] **Step 7: Request independent code review**

Review the complete range `e92e1f32b4e82155a4d3c605ec6be7150a00b210..HEAD` for formula fidelity, action discovery, UI readability, 24-member navigation, and scope isolation. Resolve every Critical or Important finding with a fresh failing regression test before presenting integration options.
