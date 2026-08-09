# Equipment and Attribute Application Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make immutable generated equipment affect its owning character through two-pass attribute projection, deterministic active/disabled requirement handling, shared runtime/ledger damage math, and accurate color-coded comparisons.

**Architecture:** `MemberStatResolutionService` performs a raw-attribute pass, projects a derived source from data-authored tuning, and performs the final resolution pass. Pure equipment services translate item rolls into one stable member source and compute a deterministic active set; `PlayerRunContext` previews ownership and stats together before committing state and replacing the source. Combat, ledger estimates, storage projections, and tooltips consume these shared results rather than implementing parallel formulas.

**Tech Stack:** Godot 4.7.1 stable Mono, typed GDScript, Godot `.tres` Resources, the existing immutable item/stat/party systems, PowerShell, Git worktrees, and the custom headless test runners.

## Global Constraints

- Execute in an isolated `feat/equipment-attribute-application` worktree created from approved design commit `00d145d` with the `using-git-worktrees` skill.
- Preserve the user's authoritative checkout and its existing untracked `.gd.uid` files; never bulk-clean or stage them from `main`.
- Do not mutate `ItemInstance`, item affix definitions, equipment bases, class Resources, or generated affix rolls.
- Derived sources may read the six core attributes but may never modify them.
- Runtime combat, character-ledger estimates, and equipment comparisons must share authoritative projection code.
- Archetype and damage-type scaling remain independent: one of melee/ranged/caster plus each authored damage component's type.
- Structural equipment invalidity remains a rejected assignment; lost attribute requirements leave existing gear equipped but disabled.
- A newly placed item must become active in the candidate loadout or the equip attempt fails.
- Maximum-health decreases clamp current health; increases do not heal or preserve health percentage.
- Comparison improvements are green with an upward/positive indicator; losses are red with a downward/negative indicator; color is not the only signal.
- Member-local equipment changes must not invalidate or recompute unrelated party members, including at the 24-member developer limit.
- Use TDD for every task and commit only the files listed for that task.
- Do not author `.gd.uid` text manually. Inspect generated sidecars after Godot runs and stage only deliberately required new-script sidecars.

---

## File map

### New stat-resolution files

- `scripts/stats/attribute_projection_tuning.gd`: exported coefficients and validation for the six attributes.
- `scripts/stats/attribute_projection_result.gd`: structured success/failure from attribute projection.
- `scripts/stats/attribute_derived_source_projector.gd`: pure raw-attribute-to-derived-source conversion.
- `scripts/stats/member_stat_resolution.gd`: raw snapshot, derived source, final snapshot, and structured error.
- `scripts/stats/member_stat_resolution_service.gd`: authoritative two-pass resolver.
- `data/stats/default_attribute_projection.tres`: initial approved coefficients.

### New combat files

- `scripts/combat/action_archetype.gd`: exact-one primary archetype validation and stat lookup.
- `scripts/combat/action_damage_projection.gd`: shared normal-component scaling used by runtime and estimates.

### New equipment files

- `scripts/equipment/equipment_modifier_projection.gd`: structured item-roll projection result.
- `scripts/equipment/equipment_modifier_projector.gd`: pure active-item-to-member-source conversion.
- `scripts/equipment/equipment_activation_result.gd`: active IDs, disabled requirements, raw attributes, and source.
- `scripts/equipment/equipment_activation_resolver.gd`: deterministic fixed-point requirement resolution.
- `scripts/equipment/equipment_transition_result.gd`: complete dry-run ownership/stat transition.
- `scripts/equipment/equipment_transition_service.gd`: combines structural assignment, activation, projection, and final stat preview.

### New comparison files

- `scripts/ui/storage/resolved_stat_comparison_service.gd`: benefit-aware final-stat delta rows.
- `scripts/ui/storage/equipment_comparison_projection_service.gd`: combines stat, action, and disabled-status deltas.

### Principal modified files

- `scripts/stats/stat_definition.gd`
- `scripts/stats/stat_resolver.gd`
- `data/stats/core_stats.tres`
- `data/keywords/core_keywords.tres`
- `scripts/party/party_manager.gd`
- `scripts/data/class_definition.gd`
- `scripts/combat/damage_resolver.gd`
- `scripts/ui/ledger/action_combat_estimate_service.gd`
- `data/attacks/{mage_burst,frost_shard,cleric_bolt,warlock_bolt}.tres`
- `scripts/equipment/equipment_eligibility.gd`
- `scripts/equipment/equipment_assignment_service.gd`
- `scripts/run/player_run_context.gd`
- `scripts/characters/party_actor.gd`
- `scripts/ui/ledger/ledger_data_provider.gd`
- `scripts/ui/storage/{item_presentation_projector,item_comparison_resolver,item_tooltip_card,storage_slot_button}.gd`
- `scripts/ui/storage/profile_storage_projection.gd`
- `scripts/ui/{armoury/armoury_screen,warehouse/warehouse_screen,developer_item_sandbox}.gd`

---

### Task 1: Canonical archetype stats and attribute projection

**Files:**
- Create: `scripts/stats/attribute_projection_tuning.gd`
- Create: `scripts/stats/attribute_projection_result.gd`
- Create: `scripts/stats/attribute_derived_source_projector.gd`
- Create: `data/stats/default_attribute_projection.tres`
- Modify: `scripts/stats/stat_definition.gd:1-44`
- Modify: `data/stats/core_stats.tres`
- Modify: `data/keywords/core_keywords.tres`
- Test: `tests/unit/test_attribute_derived_source_projector.gd`
- Test: `tests/unit/test_stat_catalog.gd`

**Interfaces:**
- Consumes: `ResolvedStatSnapshot`, `StatModifier`, `StatModifierSource`, and `ClassGrowthDefinition.CORE_ATTRIBUTE_IDS`.
- Produces: `AttributeDerivedSourceProjector.project(member_id: int, raw: ResolvedStatSnapshot, tuning: AttributeProjectionTuning) -> AttributeProjectionResult`.
- Produces canonical stats `melee_damage`, `ranged_damage`, `caster_damage`, and `party_influence`.

- [ ] **Step 1: Write failing catalog and projector tests**

Add a suite whose `run()` verifies all four new stat definitions and all approved conversions. Use a raw snapshot populated through `set_resolved()` only inside the test fixture:

```gdscript
var raw := ResolvedStatSnapshot.new()
raw.set_resolved(&"strength", 10.0, [])
raw.set_resolved(&"dexterity", 8.0, [])
raw.set_resolved(&"constitution", 6.0, [])
raw.set_resolved(&"intelligence", 4.0, [])
raw.set_resolved(&"wisdom", 2.0, [])
raw.set_resolved(&"charisma", 3.0, [])
var projection := AttributeDerivedSourceProjector.project(7, raw, preload("res://data/stats/default_attribute_projection.tres"))
TestAssertions.truthy(projection.ok(), "valid attributes project", failures)
TestAssertions.near(_modifier(projection.source, &"melee_damage").value, 0.20, 0.0001, "strength projects melee damage", failures)
TestAssertions.near(_modifier(projection.source, &"armor").value, 2.5, 0.0001, "strength projects armor", failures)
TestAssertions.near(_modifier(projection.source, &"ranged_damage").value, 0.16, 0.0001, "dexterity projects ranged damage", failures)
TestAssertions.near(_modifier(projection.source, &"max_health").value, 18.0, 0.0001, "constitution projects health", failures)
TestAssertions.near(_modifier(projection.source, &"caster_damage").value, 0.08, 0.0001, "intelligence projects caster damage", failures)
TestAssertions.near(_modifier(projection.source, &"healing_power").value, 0.04, 0.0001, "wisdom projects healing", failures)
TestAssertions.near(_modifier(projection.source, &"party_influence").value, 3.0, 0.0001, "charisma projects influence", failures)
```

Also assert that member ID `0`, a missing raw snapshot, a non-finite attribute, negative tuning, and a projector output targeting a core attribute return a stable `PARTY_FORGE_ATTRIBUTE_PROJECTION_ERROR`.

- [ ] **Step 2: Run the focused RED test**

```powershell
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_attribute_derived_source_projector.gd tests/unit/test_stat_catalog.gd
```

Expected: non-zero exit because the new projector classes and canonical stat definitions do not exist.

- [ ] **Step 3: Add tuning, result, and projector implementations**

Implement the tuning Resource with these exact defaults and a `validate()` method that rejects non-finite or negative values:

```gdscript
class_name AttributeProjectionTuning
extends Resource

@export var melee_damage_per_strength := 0.02
@export var armor_per_strength := 0.25
@export var ranged_damage_per_dexterity := 0.02
@export var attack_speed_per_dexterity := 0.005
@export var dodge_per_dexterity := 0.001
@export var max_health_per_constitution := 3.0
@export var regeneration_per_constitution := 0.05
@export var caster_damage_per_intelligence := 0.02
@export var area_size_per_intelligence := 0.0075
@export var healing_power_per_wisdom := 0.02
@export var cooldown_rate_per_wisdom := 0.005
@export var party_influence_per_charisma := 1.0

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	for property: Dictionary in get_property_list():
		var name := StringName(String(property.get("name", "")))
		if not String(name).ends_with("_strength") and not String(name).ends_with("_dexterity") and not String(name).ends_with("_constitution") and not String(name).ends_with("_intelligence") and not String(name).ends_with("_wisdom") and not String(name).ends_with("_charisma"):
			continue
		var value := float(get(name))
		if not is_finite(value) or value < 0.0:
			errors.append("PARTY_FORGE_ATTRIBUTE_PROJECTION_ERROR field=%s reason=coefficient must be finite and nonnegative" % name)
	return errors
```

`AttributeProjectionResult` owns `error` and `source`, exposes `ok()`, and copies no mutable item state. `AttributeDerivedSourceProjector` builds one source named `attribute_projection_<member_id>` and uses stable modifier IDs `attribute_projection_<member_id>_<stat_id>`. Use `INCREASED` for multiplicative-display stats and `FLAT` for armor, dodge, health, regeneration, and party influence.

- [ ] **Step 4: Add stat and keyword Resources**

Add `melee_damage`, `ranged_damage`, and `caster_damage` as offense multipliers with default `1.0`, minimum `0.0`, capability visibility, and capability tags matching their IDs. Add `party_influence` as a non-default utility number with default `0.0` and minimum `0.0`. Register matching keyword definitions with plain-language explanations.

Use this resource shape for each archetype, changing IDs, display names, tags, and keywords together:

```ini
[sub_resource type="Resource" id="Resource_melee_damage"]
script = ExtResource("1_w76bv")
id = &"melee_damage"
display_name = "Melee Damage"
ui_group = &"offense"
value_format = 3
precision = 2
default_value = 1.0
has_minimum = true
visibility = 1
capability_tags = Array[StringName]([&"melee"])
keyword_id = &"melee_damage"
```

```ini
[sub_resource type="Resource" id="Resource_keyword_melee_damage"]
script = ExtResource("1_plt8n")
id = &"melee_damage"
display_name = "Melee Damage"
explanation = "Modifies damage dealt by actions whose primary archetype is Melee."
```

Add comparison direction metadata to `StatDefinition` for later tooltip work:

```gdscript
enum ComparisonDirection { HIGHER_IS_BETTER, LOWER_IS_BETTER, NEUTRAL }
@export var comparison_direction := ComparisonDirection.HIGHER_IS_BETTER
```

Existing definitions inherit `HIGHER_IS_BETTER`; no current stat needs a lower-is-better override.

- [ ] **Step 5: Run GREEN tests and commit**

Run the focused command from Step 2. Expected: exit `0` and exactly `TEST_SUMMARY: PASS (0 failures)`.

```powershell
git add scripts/stats/attribute_projection_tuning.gd scripts/stats/attribute_projection_result.gd scripts/stats/attribute_derived_source_projector.gd scripts/stats/stat_definition.gd data/stats/default_attribute_projection.tres data/stats/core_stats.tres data/keywords/core_keywords.tres tests/unit/test_attribute_derived_source_projector.gd tests/unit/test_stat_catalog.gd
git commit -m "feat: add attribute-derived stat projection"
```

---

### Task 2: Authoritative two-pass member resolution

**Files:**
- Create: `scripts/stats/member_stat_resolution.gd`
- Create: `scripts/stats/member_stat_resolution_service.gd`
- Modify: `scripts/stats/stat_resolver.gd:1-24`
- Modify: `scripts/party/party_manager.gd:13-16,72-125,267-323`
- Test: `tests/unit/test_member_stat_resolution_service.gd`
- Test: `tests/unit/test_party_manager.gd`

**Interfaces:**
- Consumes: `AttributeDerivedSourceProjector.project(...)` from Task 1.
- Produces: `MemberStatResolutionService.resolve(member_id, catalog, base_values, capabilities, sources, action_tags, revision, tuning) -> MemberStatResolution`.
- Produces read-only preview helpers on `PartyManager`: `member_base_values`, `member_capabilities`, `member_sources_without_equipment`, and `stat_revision`.

- [ ] **Step 1: Write failing no-feedback and member-isolation tests**

Cover one ordinary source that grants Strength and another that directly grants melee damage. Assert pass one reads Strength, pass two contains both derived and direct effects, and a malicious tuning/projector fixture cannot put an attribute into the derived source. Add a PartyManager test proving repeated calls use the cache and invalidating member 1 does not replace member 2's snapshot.

```gdscript
var source := StatModifierSource.create(&"growth_1", &"growth", "Growth", 1, [
	StatModifier.create(&"strength", StatModifier.Operation.FLAT, 5.0, &"growth_1_strength", "Growth"),
	StatModifier.create(&"melee_damage", StatModifier.Operation.INCREASED, 0.10, &"direct_melee", "Direct"),
])
var result := MemberStatResolutionService.resolve(1, GameCatalog.STAT_CATALOG, {}, [&"melee"], [source], [&"melee"], 4, DEFAULT_TUNING)
TestAssertions.truthy(result.ok(), "two-pass result is valid", failures)
TestAssertions.near(result.raw_attributes.value(&"strength"), 5.0, 0.0001, "pass one resolves raw strength", failures)
TestAssertions.near(result.final_stats.value(&"melee_damage"), 1.20, 0.0001, "pass two combines direct and derived melee scaling", failures)
```

- [ ] **Step 2: Run the focused RED test**

```powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_member_stat_resolution_service.gd tests/unit/test_party_manager.gd
```

Expected: non-zero exit because the two-pass service does not exist and PartyManager still calls `StatResolver` directly.

- [ ] **Step 3: Implement the structured resolution and strengthen source validation**

`MemberStatResolution` contains:

```gdscript
var error := ""
var raw_attributes: ResolvedStatSnapshot
var derived_source: StatModifierSource
var final_stats: ResolvedStatSnapshot
func ok() -> bool: return error.is_empty() and raw_attributes != null and derived_source != null and final_stats != null
```

Implement the service in this order:

```gdscript
var source_errors := StatResolver.validate_sources(catalog, sources)
if not source_errors.is_empty(): return MemberStatResolution.failure(source_errors[0])
var raw := StatResolver.resolve(member_id, catalog, base_values, capabilities, sources, [], revision)
var projection := AttributeDerivedSourceProjector.project(member_id, raw, tuning)
if not projection.ok(): return MemberStatResolution.failure(projection.error)
var final_sources := sources.duplicate()
final_sources.append(projection.source)
var final := StatResolver.resolve(member_id, catalog, base_values, capabilities, final_sources, action_tags, revision)
return MemberStatResolution.success(raw, projection.source, final)
```

Extend `StatResolver.validate_sources()` to reject null catalogs, empty/duplicate source IDs, empty modifier source IDs, unsupported operations, and non-finite values. Do not reject repeated modifier `source_id` values in legacy sources; the equipment projector will enforce its own stronger uniqueness contract.

- [ ] **Step 4: Route PartyManager through the service**

Preload `default_attribute_projection.tres`. Replace both direct `StatResolver.resolve` calls with `MemberStatResolutionService.resolve`; cache only `final_stats`, and return `null` after pushing the structured error.

Add read-only preview inputs:

```gdscript
func member_base_values(member_id: int) -> Dictionary
func member_capabilities(member_id: int) -> Array[StringName]
func member_sources_without_equipment(member_id: int) -> Array[StatModifierSource]
func stat_revision() -> int
```

`member_sources_without_equipment` uses `_sources_for(member)` and excludes only sources whose `source_type == &"equipment"`. It returns a new Array and never exposes the member's owned source collection directly.

- [ ] **Step 5: Run GREEN tests and commit**

Expected: focused runner exits `0` with `TEST_SUMMARY: PASS (0 failures)`.

```powershell
git add scripts/stats/member_stat_resolution.gd scripts/stats/member_stat_resolution_service.gd scripts/stats/stat_resolver.gd scripts/party/party_manager.gd tests/unit/test_member_stat_resolution_service.gd tests/unit/test_party_manager.gd
git commit -m "feat: resolve member stats in two passes"
```

---

### Task 3: Primary archetypes and shared damage preparation

**Files:**
- Create: `scripts/combat/action_archetype.gd`
- Create: `scripts/combat/action_damage_projection.gd`
- Modify: `scripts/data/class_definition.gd:51-66`
- Modify: `scripts/combat/damage_resolver.gd:14-38`
- Modify: `scripts/ui/ledger/action_combat_estimate_service.gd:4-47`
- Modify: `data/attacks/mage_burst.tres`
- Modify: `data/attacks/frost_shard.tres`
- Modify: `data/attacks/cleric_bolt.tres`
- Modify: `data/attacks/warlock_bolt.tres`
- Test: `tests/unit/test_action_archetype.gd`
- Test: `tests/unit/test_damage_resolver.gd`
- Test: `tests/unit/test_action_combat_estimate_service.gd`
- Test: `tests/unit/test_game_catalog.gd`

**Interfaces:**
- Consumes: canonical archetype stats from Task 1 and two-pass action snapshots from Task 2.
- Produces: `ActionArchetype.primary_tag(attack)`, `ActionArchetype.stat_id(attack)`, and `ActionDamageProjection.normal_component(...)`.

- [ ] **Step 1: Write failing archetype and formula-parity tests**

Assert zero and two primary tags fail playable-class validation, healing does not require one, and each of the nine class primaries maps exactly once. Add a mixed-component caster fixture and verify runtime prepared component values equal ledger normal-component values.

```gdscript
var normal := ActionDamageProjection.normal_component(10.0, 1.20, 1.30, 1.40)
TestAssertions.near(normal, 21.84, 0.0001, "global, archetype, and type scaling multiply once", failures)
```

- [ ] **Step 2: Run the focused RED test**

```powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_action_archetype.gd tests/unit/test_damage_resolver.gd tests/unit/test_action_combat_estimate_service.gd tests/unit/test_game_catalog.gd
```

Expected: non-zero exit because caster tags and shared scaling do not exist.

- [ ] **Step 3: Implement archetype validation and shared scaling**

Use this contract:

```gdscript
class_name ActionArchetype
extends RefCounted

const PRIMARY_TAGS: Array[StringName] = [&"melee", &"ranged", &"caster"]

static func primary_tag(attack: AttackDefinition) -> StringName:
	if attack == null: return &""
	var found: Array[StringName] = []
	for tag: StringName in PRIMARY_TAGS:
		if tag in attack.normalized_action_tags(): found.append(tag)
	return found[0] if found.size() == 1 else &""

static func stat_id(attack: AttackDefinition) -> StringName:
	var tag := primary_tag(attack)
	return StringName("%s_damage" % tag) if not tag.is_empty() else &""

static func validate_player_damage_action(attack: AttackDefinition) -> PackedStringArray:
	if attack == null or attack.is_healing(): return PackedStringArray()
	var count := PRIMARY_TAGS.filter(func(tag: StringName) -> bool: return tag in attack.normalized_action_tags()).size()
	return PackedStringArray() if count == 1 else PackedStringArray(["PARTY_FORGE_DAMAGE_ERROR attack=%s reason=expected exactly one primary archetype" % attack.id])
```

`ActionDamageProjection.normal_component(base, global_multiplier, archetype_multiplier, type_multiplier)` validates finite nonnegative inputs and returns their product. Both runtime and estimate services call it.

- [ ] **Step 4: Normalize data and runtime/ledger consumers**

Add `caster` to Mage, Frost Mage, and Cleric attack tags. Replace `ranged` with `caster` on Warlock. Keep all other tags unchanged and sorted.

In runtime and estimate code, resolve the archetype stat once per attack:

```gdscript
var archetype_stat_id := ActionArchetype.stat_id(attack)
var archetype_multiplier := source.stat_value(archetype_stat_id, 1.0)
var normal := ActionDamageProjection.normal_component(component.base_amount, source.stat_value(&"damage", 1.0), archetype_multiplier, source.stat_value(type_definition.offense_stat_id, 1.0))
```

Use the action snapshot for archetype, type, critical chance, critical multiplier, and action-rate stats. Preserve pre-mitigation ledger semantics.

- [ ] **Step 5: Run GREEN tests and commit**

```powershell
git add scripts/combat/action_archetype.gd scripts/combat/action_damage_projection.gd scripts/data/class_definition.gd scripts/combat/damage_resolver.gd scripts/ui/ledger/action_combat_estimate_service.gd data/attacks/mage_burst.tres data/attacks/frost_shard.tres data/attacks/cleric_bolt.tres data/attacks/warlock_bolt.tres tests/unit/test_action_archetype.gd tests/unit/test_damage_resolver.gd tests/unit/test_action_combat_estimate_service.gd tests/unit/test_game_catalog.gd
git commit -m "feat: apply primary archetype damage scaling"
```

---

### Task 4: Immutable item-roll to equipment-source projection

**Files:**
- Create: `scripts/equipment/equipment_modifier_projection.gd`
- Create: `scripts/equipment/equipment_modifier_projector.gd`
- Test: `tests/unit/test_equipment_modifier_projector.gd`

**Interfaces:**
- Consumes: member ID, equipment container ID, `ItemOwnershipState`, active item IDs, equipment/foundation/stat catalogs.
- Produces: `EquipmentModifierProjector.project(member_id, container_id, state, active_item_ids, equipment, foundation, stats) -> EquipmentModifierProjection`.

- [ ] **Step 1: Write failing immutable projection tests**

Issue a fixture item containing an implicit, an attribute prefix, a typed-damage suffix, and a tagged melee roll. Assert all active rolls appear exactly once, inactive IDs contribute nothing, input `to_dictionary()` values are byte-for-byte equivalent before/after, and malformed roll values fail without a partial source.

Verify stable identity shape:

```gdscript
var expected := "equip_m1_smain_hand_i%s_a0_%s_r0" % [item.instance_id, item.affixes[0].definition_id]
TestAssertions.equal(String(projection.source.modifiers[0].source_id), expected, "equipment modifier identity is stable", failures)
```

- [ ] **Step 2: Run the focused RED test**

```powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_equipment_modifier_projector.gd
```

Expected: non-zero exit because the equipment projector does not exist.

- [ ] **Step 3: Implement strict projection**

`EquipmentModifierProjection` exposes `error`, `source`, and `ok()`. The projector must:

```gdscript
var source_id := StringName("equipment_member_%d" % member_id)
var modifiers: Array[StatModifier] = []
for slot_index: int in container.occupied_slots():
	var item_id := container.item_id_at(slot_index)
	if item_id not in active_item_ids: continue
	var item := registry.item(item_id)
	var slot_id := EquipmentSlotIndex.slot_for(slot_index)
	for affix_index: int in item.affixes.size():
		var affix := item.affixes[affix_index]
		for roll_index: int in affix.rolls.size():
			var roll := affix.rolls[roll_index]
			var modifier_id := StringName("equip_m%d_s%s_i%s_a%d_%s_r%d" % [member_id, slot_id, item.instance_id, affix_index, affix.definition_id, roll_index])
			var modifier := StatModifier.create(roll.stat_id, roll.operation, roll.value, modifier_id, _label(base, affix, foundation), roll.required_tags)
			modifiers.append(modifier)
```

Before returning success, validate every referenced item/base/affix/stat, operation, finite value, tag, and identity. Reject duplicate detailed IDs. Return a single empty `equipment_member_<id>` source when the active set is empty so source replacement remains uniform.

Use this exact human-readable label helper so ledger attribution remains stable:

```gdscript
static func _label(base: EquipmentBaseDefinition, affix: ItemAffixInstance, foundation: ItemFoundationCatalog) -> String:
	var definition := foundation.affix(affix.definition_id)
	var affix_name := definition.display_name if definition != null else String(affix.definition_id).replace("_", " ").capitalize()
	return "%s — %s" % [base.display_name, affix_name]
```

- [ ] **Step 4: Run GREEN, check immutability, and commit**

Expected: `TEST_SUMMARY: PASS (0 failures)`.

```powershell
git add scripts/equipment/equipment_modifier_projection.gd scripts/equipment/equipment_modifier_projector.gd tests/unit/test_equipment_modifier_projector.gd
git commit -m "feat: project equipped item rolls into stats"
```

---

### Task 5: Deterministic active and disabled equipment

**Files:**
- Create: `scripts/equipment/equipment_activation_result.gd`
- Create: `scripts/equipment/equipment_activation_resolver.gd`
- Modify: `scripts/equipment/equipment_eligibility.gd:1-31`
- Modify: `scripts/equipment/equipment_assignment_service.gd:15-115`
- Test: `tests/unit/test_equipment_activation_resolver.gd`
- Test: `tests/unit/test_equipment_assignment_service.gd`

**Interfaces:**
- Consumes: Task 4 projector plus PartyManager preview inputs from Task 2.
- Produces: `EquipmentActivationResolver.resolve(member_id, container_id, state, equipment, foundation, stats, base_values, capabilities, non_equipment_sources, revision) -> EquipmentActivationResult`.
- `EquipmentActivationResult` provides `is_active(item_id)`, `disabled_reasons(item_id)`, `active_item_ids`, `raw_attributes`, `source`, and a defensive `copy()`.

- [ ] **Step 1: Write failing support-chain and disabled-state tests**

Cover these exact cases:

- base attributes activate item A, A's Strength activates item B;
- item B cannot satisfy its own requirement;
- A and B cannot mutually bootstrap from insufficient base attributes;
- removing A leaves B equipped but disabled and removes all B affixes;
- restoring A automatically reactivates B;
- an illegal class/slot/handedness assignment still fails structurally;
- a newly placed item that remains disabled is rejected.

- [ ] **Step 2: Run the focused RED test**

```powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_equipment_activation_resolver.gd tests/unit/test_equipment_assignment_service.gd
```

Expected: failures because complete-loadout validation still rejects lost attributes and no fixed-point resolver exists.

- [ ] **Step 3: Separate structural and attribute eligibility**

Refactor `EquipmentEligibility` into:

```gdscript
static func validate_structure(item: EquipmentBaseDefinition, class_definition: ClassDefinition, requested_slot_id: StringName, loadout: Dictionary = {}) -> PackedStringArray
static func unmet_attribute_requirements(item: EquipmentBaseDefinition, attributes: Dictionary) -> PackedStringArray
static func validate_equip(item: EquipmentBaseDefinition, class_definition: ClassDefinition, requested_slot_id: StringName, loadout: Dictionary = {}, attributes: Dictionary = {}) -> PackedStringArray
```

`validate_equip` concatenates structure and attribute errors for legacy callers. `EquipmentAssignmentService` uses `validate_structure` for every candidate loadout item. It no longer rejects existing equipment solely because attributes were lost.

- [ ] **Step 4: Implement fixed-point activation**

Start with zero active items. On each pass:

```gdscript
var projection := EquipmentModifierProjector.project(member_id, container_id, state, active_ids, equipment, foundation, stats)
var raw_sources := non_equipment_sources.duplicate()
raw_sources.append(projection.source)
var raw := StatResolver.resolve(member_id, stats, base_values, capabilities, raw_sources, [], revision)
var changed := false
for item_id: String in equipped_ids:
	if item_id in active_ids: continue
	var definition := equipment.definition(registry.item(item_id).base_definition_id)
	var requirements := _attribute_values(raw)
	if EquipmentEligibility.unmet_attribute_requirements(definition, requirements).is_empty():
		active_ids.append(item_id)
		changed = true
if not changed: break
```

Reproject once with the final active set. Populate disabled reasons from the final raw attributes. Sort item IDs and reason lines before returning so results are deterministic.

- [ ] **Step 5: Run GREEN tests and commit**

```powershell
git add scripts/equipment/equipment_activation_result.gd scripts/equipment/equipment_activation_resolver.gd scripts/equipment/equipment_eligibility.gd scripts/equipment/equipment_assignment_service.gd tests/unit/test_equipment_activation_resolver.gd tests/unit/test_equipment_assignment_service.gd
git commit -m "feat: disable equipment with unmet attributes"
```

---

### Task 6: Atomic run-context equipment transitions and health refresh

**Files:**
- Create: `scripts/equipment/equipment_transition_result.gd`
- Create: `scripts/equipment/equipment_transition_service.gd`
- Modify: `scripts/run/player_run_context.gd:16-24,181-207`
- Modify: `scripts/characters/party_actor.gd:351-361`
- Test: `tests/unit/test_equipment_transition_service.gd`
- Test: `tests/unit/test_player_run_context.gd`
- Test: `tests/unit/test_health_component.gd`
- Test: `tests/unit/test_equipment_assignment_service.gd`

**Interfaces:**
- Consumes: structural preview from `EquipmentAssignmentService`, activation from Task 5, and two-pass resolution from Task 2.
- Produces: `PlayerRunContext.preview_equipment_assignment(...) -> EquipmentTransitionResult`, existing `assign_equipment(...)` as preview-then-commit, and `equipment_activation(member_id) -> EquipmentActivationResult`.

- [ ] **Step 1: Write failing atomicity and health tests**

Assert:

- successful equip changes ownership and the equipment source before `stats_changed` observers query them;
- failed projection changes neither state nor source and emits no `stats_changed`;
- equipping Constitution gear raises maximum without raising current health;
- removing it clamps only when current health exceeds the new maximum;
- member 1 equipment changes do not replace member 2 snapshots;
- bootstrap/resume reconstructs equipment sources and disabled states from immutable item records.

- [ ] **Step 2: Run the focused RED test**

```powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_equipment_transition_service.gd tests/unit/test_player_run_context.gd tests/unit/test_health_component.gd tests/unit/test_equipment_assignment_service.gd
```

Expected: failure because `assign_equipment` commits ownership without projecting equipment stats.

- [ ] **Step 3: Implement pure transition preview**

`EquipmentTransitionResult` owns `error`, candidate `ItemOwnershipState`, `EquipmentActivationResult`, and `MemberStatResolution`. It exposes `ok()`, `state()`, `activation()`, and `resolution()`; `state()` and `activation()` return defensive copies.

`EquipmentTransitionService.preview(...)`:

1. calls structural assignment preview;
2. resolves candidate activation using PartyManager's non-equipment preview inputs;
3. rejects an equip when the requested item is not active;
4. resolves final member stats with the candidate equipment source;
5. returns success without mutating context or party.

The public signature is:

```gdscript
func preview(
	state: ItemOwnershipState,
	member_id: int,
	item_id: String,
	slot_id: StringName,
	party: PartyManager,
	equipment: EquipmentCatalog,
	foundation: ItemFoundationCatalog,
) -> EquipmentTransitionResult
```

Use stable errors beginning `PARTY_FORGE_EQUIPMENT_TRANSITION_ERROR` and include member, item, slot, and nested detail.

- [ ] **Step 4: Commit through PlayerRunContext**

Add `_equipment_activation_by_member`. Implement:

```gdscript
func assign_equipment(...) -> EquipmentAssignmentResult:
	var preview := preview_equipment_assignment(member_id, item_id, slot_id, equipment, foundation)
	if not preview.ok(): return EquipmentAssignmentResult.failure(preview.error)
	var previous_state := _item_state
	var previous_activation := equipment_activation(member_id)
	var next_activation := preview.activation()
	_item_state = preview.state()
	_equipment_activation_by_member[member_id] = next_activation.copy()
	if not party.replace_member_source(member_id, next_activation.source):
		_item_state = previous_state
		_equipment_activation_by_member[member_id] = previous_activation
		return EquipmentAssignmentResult.failure("PARTY_FORGE_EQUIPMENT_TRANSITION_ERROR member=%d reason=stat source commit rejected" % member_id)
	return EquipmentAssignmentResult.success(_item_state)
```

Because `_item_state` changes before `party.replace_member_source()` emits `stats_changed`, synchronous observers see one consistent committed state. There is no mutation after the source replacement succeeds.

During `configure()`, reconstruct every member's current equipment activation/source before marking the context configured. An invalid resumable equipment state fails configuration rather than silently dropping affixes.

- [ ] **Step 5: Correct health refresh**

Change runtime stat refresh to:

```gdscript
health.set_max_health(snapshot.value(&"max_health", health.max_health), false)
```

Keep spawn initialization intentionally full-health. Do not change explicit heal/revive behavior.

- [ ] **Step 6: Run GREEN tests and commit**

```powershell
git add scripts/equipment/equipment_transition_result.gd scripts/equipment/equipment_transition_service.gd scripts/run/player_run_context.gd scripts/characters/party_actor.gd tests/unit/test_equipment_transition_service.gd tests/unit/test_player_run_context.gd tests/unit/test_health_component.gd tests/unit/test_equipment_assignment_service.gd
git commit -m "feat: commit equipment stats atomically"
```

---

### Task 7: Ledger rows, source attribution, and action estimates

**Files:**
- Modify: `scripts/ui/ledger/ledger_data_provider.gd:73-151`
- Modify: `scripts/ui/ledger/action_combat_estimate.gd`
- Test: `tests/unit/test_ledger_data_provider.gd`
- Test: `tests/unit/test_action_combat_estimate_service.gd`
- Test: `tests/unit/test_stats_ledger_page.gd`

**Interfaces:**
- Consumes: final PartyManager snapshots and shared action projection from Tasks 2-3.
- Produces visible canonical archetype/influence rows and per-component action totals with equipment source labels.

- [ ] **Step 1: Write failing ledger coverage**

Create Fighter, Ranger, and Mage fixtures with attribute/equipment sources. Assert each sees its relevant archetype row and does not see irrelevant default rows. Assert Party Influence appears only when non-default. Verify an equipment affix label appears in `stat_detail().sources` and each damaging action exposes component rows, normal hit, critical hit, average hit, attacks per second, and DPS.

```gdscript
var fighter_rows := provider.stat_rows(fighter_id)
TestAssertions.truthy(fighter_rows.any(func(row: Dictionary) -> bool: return row.stat_id == &"melee_damage"), "fighter shows melee damage", failures)
TestAssertions.truthy(not fighter_rows.any(func(row: Dictionary) -> bool: return row.stat_id == &"caster_damage"), "fighter hides irrelevant caster damage", failures)
var action_rows := provider.combat_estimate_rows(fighter_id)
TestAssertions.truthy(not action_rows.is_empty() and action_rows[0].available, "fighter action estimate is available", failures)
TestAssertions.truthy(action_rows[0].estimated_dps > 0.0, "fighter action shows DPS", failures)
```

- [ ] **Step 2: Run the focused RED test**

```powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_ledger_data_provider.gd tests/unit/test_action_combat_estimate_service.gd tests/unit/test_stats_ledger_page.gd
```

Expected: failures for missing relevance/attribution expectations.

- [ ] **Step 3: Implement relevance and source display**

Retain `StatDefinition.Visibility.CAPABILITY` as the canonical relevance rule. Archetype stats use their matching capability tags; a non-default modifier also makes a row visible. `party_influence` uses `NON_DEFAULT`.

Do not special-case class IDs in `LedgerDataProvider`. Use snapshot capabilities and breakdown rows. Preserve the equipment projector's human label in the stat source list and detailed stable source ID in the existing source dictionary.

Keep visibility data-driven:

```gdscript
func _is_visible(definition: StatDefinition, snapshot: ResolvedStatSnapshot, breakdown: Array[Dictionary]) -> bool:
	var has_modifier_source := breakdown.size() > 1
	if definition.visibility == StatDefinition.Visibility.UNIVERSAL: return true
	if definition.visibility == StatDefinition.Visibility.CAPABILITY:
		return has_modifier_source or definition.capability_tags.any(func(tag: StringName) -> bool: return tag in snapshot.capabilities)
	return has_modifier_source or not is_equal_approx(snapshot.value(definition.id, definition.default_value), definition.default_value)
```

Ensure `ActionCombatEstimate` component rows remain independently readable and totals are the sum of their components. The estimate service must call the shared Task 3 projection rather than reproduce multiplication.

- [ ] **Step 4: Run GREEN tests and commit**

```powershell
git add scripts/ui/ledger/ledger_data_provider.gd scripts/ui/ledger/action_combat_estimate.gd tests/unit/test_ledger_data_provider.gd tests/unit/test_action_combat_estimate_service.gd tests/unit/test_stats_ledger_page.gd
git commit -m "feat: show equipment-derived combat stats"
```

---

### Task 8: Disabled-slot presentation and projected tooltip comparisons

**Files:**
- Create: `scripts/ui/storage/resolved_stat_comparison_service.gd`
- Create: `scripts/ui/storage/equipment_comparison_projection_service.gd`
- Modify: `scripts/ui/storage/item_presentation_projector.gd:4-44`
- Modify: `scripts/ui/storage/item_comparison_resolver.gd:4-75`
- Modify: `scripts/ui/storage/storage_slot_button.gd:16-175`
- Modify: `scripts/ui/storage/item_tooltip_card.gd:25-62,220-231`
- Modify: `scripts/ui/storage/profile_storage_projection.gd:17-104`
- Modify: `scripts/ui/armoury/armoury_screen.gd:184-193`
- Modify: `scripts/ui/warehouse/warehouse_screen.gd:140-149`
- Modify: `scripts/ui/developer_item_sandbox.gd:535-544`
- Test: `tests/unit/test_resolved_stat_comparison_service.gd`
- Test: `tests/unit/test_item_comparison_resolver.gd`
- Test: `tests/unit/test_storage_slot_button.gd`
- Test: `tests/unit/test_item_tooltip_card.gd`
- Test: `tests/unit/test_profile_storage_projection.gd`
- Test: `tests/integration/item_tooltip_responsive_runner.gd`

**Interfaces:**
- Consumes: current/candidate final snapshots, action estimates, `StatDefinition.comparison_direction`, and activation results.
- Produces: comparison rows shaped as `{stat_id, delta, direction, text}` plus status-warning rows and item detail fields `is_disabled` and `disabled_requirement_lines`.

- [ ] **Step 1: Write failing comparison and disabled-UI tests**

Assert:

- higher-is-better positive deltas use direction `1`, `▲`, and green presentation;
- losses use direction `-1`, `▼`, and red presentation;
- color-neutral accessibility text still says improved or reduced;
- attribute gear comparisons include their derived melee/ranged/caster and defensive changes;
- a candidate that disables another item adds a prominent warning;
- disabled slots are dimmed, expose `Disabled` in `accessibility_name`, and show every unmet requirement;
- tooltip layouts remain inside 1080p, 1440p, and 4K logical/physical viewport cases.

```gdscript
var lines := ResolvedStatComparisonService.compare(current, candidate, GameCatalog.STAT_CATALOG)
var melee := lines.filter(func(line: Dictionary) -> bool: return line.stat_id == &"melee_damage")[0]
TestAssertions.equal(melee.direction, 1, "melee improvement is beneficial", failures)
TestAssertions.truthy(String(melee.text).begins_with("▲"), "improvement has an upward indicator", failures)
card.present(disabled_detail, &"inspected", false, lines, false)
TestAssertions.truthy(card.rendered_text().contains("Disabled"), "tooltip announces disabled equipment", failures)
```

- [ ] **Step 2: Run the focused RED test**

```powershell
& $godot --headless --path . --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_resolved_stat_comparison_service.gd tests/unit/test_item_comparison_resolver.gd tests/unit/test_storage_slot_button.gd tests/unit/test_item_tooltip_card.gd tests/unit/test_profile_storage_projection.gd
```

Expected: failures because existing comparisons subtract raw rolls and slots lack disabled state.

- [ ] **Step 3: Implement benefit-aware final-stat comparisons**

`ResolvedStatComparisonService.compare(current, candidate, catalog)` iterates catalog definitions and creates rows only for changed final values:

```gdscript
var delta := candidate.value(definition.id, definition.default_value) - current.value(definition.id, definition.default_value)
var benefit := 1 if definition.comparison_direction == StatDefinition.ComparisonDirection.HIGHER_IS_BETTER else -1 if definition.comparison_direction == StatDefinition.ComparisonDirection.LOWER_IS_BETTER else 0
var direction := int(signf(delta)) * benefit
var symbol := "▲" if direction > 0 else "▼" if direction < 0 else "•"
var meaning := "improved" if direction > 0 else "reduced" if direction < 0 else "changed"
```

Format through the stat definition, include both symbol and meaning in accessible text, and keep raw delta values for tests/debugging. `EquipmentComparisonProjectionService` appends action hit/DPS changes and active/disabled status changes using the same row contract.

- [ ] **Step 4: Feed dry-run projections into existing layered tooltips**

Extend `ItemComparisonResolver.resolve()` with an optional `projected_lines_by_slot: Dictionary = {}`. Use projected rows when provided; retain raw-roll deltas only as a fallback when no character/class projection exists.

`ProfileStorageProjection` retains a private copy of its decoded `ItemOwnershipState`, builds a class-base equipment projection for its active class, and exposes `comparison_lines_by_slot(item_id) -> Dictionary`. It creates each compatible-slot candidate through the existing profile loadout assignment service, then feeds current and candidate sources through `MemberStatResolutionService`. Armoury and Warehouse pass that dictionary to `ItemComparisonResolver`. The developer sandbox builds the same projection from its fixture class and item state. Future run inventory UI will call `PlayerRunContext.preview_equipment_assignment()` and the same comparison service.

The existing resolver call becomes:

```gdscript
var projected_by_slot := storage.comparison_lines_by_slot(String(detail.get("instance_id", "")))
var comparisons := ItemComparisonResolver.resolve(detail, storage.leader_slots, storage.item_records, projected_by_slot)
```

- [ ] **Step 5: Render disabled equipment clearly**

Annotate projected item details:

```gdscript
detail["is_disabled"] = not activation.is_active(item.instance_id)
detail["disabled_requirement_lines"] = activation.disabled_reasons(item.instance_id)
```

`StorageSlotButton` creates one centered child Label named `DisabledOverlay`, with text `DISABLED`, mouse filtering ignored, high-contrast background, and visibility bound to `is_disabled`. Dim the item content without dimming the warning below an accessible contrast level. `ItemTooltipCard` adds a red-orange `Disabled — requirements not met` line followed by the exact requirements.

Comparison rows already color positive green and negative red; retain those colors and add the new symbols/accessible wording.

- [ ] **Step 6: Run GREEN unit and responsive tests, then commit**

```powershell
& $godot --headless --path . --quit-after 900 --script res://tests/integration/item_tooltip_responsive_runner.gd
```

Expected: unit batch `TEST_SUMMARY: PASS (0 failures)` and responsive runner's existing PASS marker with no edge overflow.

```powershell
git add scripts/ui/storage/resolved_stat_comparison_service.gd scripts/ui/storage/equipment_comparison_projection_service.gd scripts/ui/storage/item_presentation_projector.gd scripts/ui/storage/item_comparison_resolver.gd scripts/ui/storage/storage_slot_button.gd scripts/ui/storage/item_tooltip_card.gd scripts/ui/storage/profile_storage_projection.gd scripts/ui/armoury/armoury_screen.gd scripts/ui/warehouse/warehouse_screen.gd scripts/ui/developer_item_sandbox.gd tests/unit/test_resolved_stat_comparison_service.gd tests/unit/test_item_comparison_resolver.gd tests/unit/test_storage_slot_button.gd tests/unit/test_item_tooltip_card.gd tests/unit/test_profile_storage_projection.gd tests/integration/item_tooltip_responsive_runner.gd
git commit -m "feat: show projected equipment comparisons"
```

---

### Task 9: Resume, 24-member isolation, and end-to-end regression

**Files:**
- Modify: `tests/integration/progression_24_member_runner.gd`
- Create: `tests/integration/equipment_attribute_application_runner.gd`
- Modify: `tests/unit/test_run_item_ownership.gd`
- Modify: `tests/unit/test_item_instance_codec.gd`
- Modify: `tests/unit/test_game_catalog.gd`

**Interfaces:**
- Consumes: all Increment 2 services.
- Produces: end-to-end proof that item records remain immutable/persistent, resumed loadouts rebuild the same stats, and only the affected member refreshes.

- [ ] **Step 1: Add a failing 24-member and resume scenario**

The integration runner must:

1. build a party of 24 under the developer capacity policy;
2. give member 1 attribute and typed-damage gear;
3. record member 2-24 snapshot object identities/revisions;
4. equip, disable, and reactivate member 1 gear;
5. assert only member 1 receives stat-change notifications;
6. encode the run item state, restore a new context, and assert identical active IDs, disabled reasons, final stats, and action estimates;
7. assert all serialized `ItemInstance` dictionaries remain unchanged.

Use explicit signal and snapshot assertions:

```gdscript
var changed_members: Array[int] = []
party.stats_changed.connect(func(member_id: int) -> void: changed_members.append(member_id))
var untouched_before := party.stats_for(2)
var result := context.assign_equipment(1, item.instance_id, &"main_hand", equipment, foundation)
_assert(result.ok(), "member one equipment transition succeeds")
_assert(changed_members == [1], "only member one emits stats_changed")
_assert(party.stats_for(2) == untouched_before, "member two retains its cached snapshot")
```

- [ ] **Step 2: Run the RED integration batch**

```powershell
& $godot --headless --path . --quit-after 900 --script res://tests/integration/equipment_attribute_application_runner.gd
```

Expected: non-zero exit until resume reconstruction and member-local invalidation are complete.

- [ ] **Step 3: Run focused regression and commit**

```powershell
& $godot --headless --path . --quit-after 900 --script res://tests/focused_test_runner.gd -- tests/unit/test_stat_catalog.gd tests/unit/test_stat_resolver.gd tests/unit/test_party_manager.gd tests/unit/test_damage_resolver.gd tests/unit/test_action_combat_estimate_service.gd tests/unit/test_equipment_assignment_service.gd tests/unit/test_run_item_ownership.gd tests/unit/test_item_instance_codec.gd tests/unit/test_game_catalog.gd
& $godot --headless --path . --quit-after 900 --script res://tests/integration/equipment_attribute_application_runner.gd
& $godot --headless --path . --quit-after 900 --script res://tests/integration/progression_24_member_runner.gd
```

Expected: all commands exit `0`; focused unit runner prints `TEST_SUMMARY: PASS (0 failures)` and both integration runners print their explicit PASS markers.

```powershell
git add tests/integration/equipment_attribute_application_runner.gd tests/integration/progression_24_member_runner.gd tests/unit/test_run_item_ownership.gd tests/unit/test_item_instance_codec.gd tests/unit/test_game_catalog.gd
git commit -m "test: cover equipment attributes end to end"
```

---

### Task 10: Final verification and evidence

**Files:**
- Create: `docs/verification/2026-08-09-equipment-attribute-application.md`
- Modify only if verification exposes a real defect: files owned by Tasks 1-9 and their tests.

**Interfaces:**
- Consumes: complete feature branch.
- Produces: reproducible verification evidence and a clean, reviewable branch ready for independent review and integration choice.

- [ ] **Step 1: Record exact pre-gate state**

```powershell
git status --short --branch
git log -1 --format='%H %s'
Get-Process | Where-Object { $_.ProcessName -like 'Godot*' } | Select-Object Id,ProcessName,Path
```

Expected: only intentional branch changes are tracked; no test process targets the worktree. Do not stop the user's unrelated live editor.

- [ ] **Step 2: Run fresh import/parser validation**

Use task-specific settings roots inside the worktree:

```powershell
$env:APPDATA = (Join-Path (Get-Location) '.superpowers\sdd\equipment-attribute-final-appdata')
$env:LOCALAPPDATA = (Join-Path (Get-Location) '.superpowers\sdd\equipment-attribute-final-localappdata')
& $godot --headless --path . --editor --quit-after 300 2>&1 | Tee-Object '.superpowers\sdd\equipment-attribute-import.log'
```

Expected: exit `0`, with no `SCRIPT ERROR`, parse error, resource-load failure, or forbidden diagnostic. Record intentionally asserted negative-path domain errors separately.

- [ ] **Step 3: Run focused and full automated gates**

```powershell
& $godot --headless --path . --quit-after 1200 --script res://tests/focused_test_runner.gd -- tests/unit/test_attribute_derived_source_projector.gd tests/unit/test_member_stat_resolution_service.gd tests/unit/test_action_archetype.gd tests/unit/test_damage_resolver.gd tests/unit/test_action_combat_estimate_service.gd tests/unit/test_equipment_modifier_projector.gd tests/unit/test_equipment_activation_resolver.gd tests/unit/test_equipment_transition_service.gd tests/unit/test_player_run_context.gd tests/unit/test_ledger_data_provider.gd tests/unit/test_resolved_stat_comparison_service.gd tests/unit/test_item_tooltip_card.gd
& $godot --headless --path . --quit-after 1800 --script res://tests/test_runner.gd
& $godot --headless --path . --quit-after 900 --script res://tests/integration/equipment_attribute_application_runner.gd
& $godot --headless --path . --quit-after 900 --script res://tests/integration/item_tooltip_responsive_runner.gd
```

Expected: focused marker `TEST_SUMMARY: PASS (0 failures)`, a full-suite `TEST_SUMMARY: PASS` marker containing the exact observed suite count, both integration PASS markers, and exit `0` for every process. Record the observed suite count in the evidence document rather than predicting it in the plan.

- [ ] **Step 4: Run startup smoke and inspect generated drift**

```powershell
& $godot --headless --path . --quit-after 300 2>&1 | Tee-Object '.superpowers\sdd\equipment-attribute-startup.log'
git status --short
git diff --check
```

Expected: `PARTY_FORGE_BOOT_OK` and `PARTY_FORGE_CLASS_SELECTION_READY` exactly once, no forbidden diagnostics, and no unexpected tracked rewrites. Compare any generated `.gd.uid`/`.import` files against the pre-gate manifest and remove only files proven to have been generated inside the isolated worktree.

- [ ] **Step 5: Write evidence and commit**

The verification document records exact commit, Godot version, commands, exit codes, markers, suite counts, integration scenarios, allowed negative diagnostics, sidecar handling, and any deferred physical-controller/manual visual check.

```powershell
git add docs/verification/2026-08-09-equipment-attribute-application.md
git commit -m "docs: verify equipment attribute application"
git status --short --branch
```

Expected: branch has no tracked changes. Generated sidecars, if any, are reported explicitly rather than described as a clean tree.

- [ ] **Step 6: Request independent review before integration**

Review the full range from `00d145d` to feature head for spec compliance and code quality. Resolve Critical or Important findings test-first, rerun affected focused tests plus the complete suite, and update evidence. Then use `finishing-a-development-branch` to offer the user merge, PR, keep-worktree, or discard choices. Do not fast-forward `main` without the user's integration selection.
