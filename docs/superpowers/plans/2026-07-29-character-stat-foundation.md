# Party Forge Character Stat Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Party Forge's scattered multiplier calculations with a tested, registry-backed per-member stat snapshot while preserving the current combat behavior.

**Architecture:** Godot `Resource` definitions describe stat metadata and modifier sources. `StatResolver` combines class bases and ordered modifier sources into an immutable `ResolvedStatSnapshot`; `PartyManager` owns per-member snapshots, revisions, and invalidation, while the existing `CombatModifiers` API becomes a temporary compatibility facade over the snapshot. This is the first independently testable implementation slice of the approved character-stat/class design; typed damage, expanded classes, and the character drawer remain outside this plan's file boundary.

**Tech Stack:** Godot 4.7.1 stable Mono, typed GDScript, Godot `.tres` resources, PowerShell, the existing custom headless test runner, and the connected Godot AI editor bridge for live verification.

## Global Constraints

- Preserve the current four-member party cap, duplicate classes, elastic formations, and existing gameplay loop.
- Preserve the user's projectile speed and lifetime tuning exactly.
- Preserve all unrelated formatting-only script edits, generated UIDs, GodotSteam files, handbook archive, and Godot AI configuration.
- Store percentage-like values as ratios: `0.15` means 15%.
- Resolve modifiers as `(base + flat) * (1 + increased - reduced) * each more * each less`.
- Apply minimum, maximum, rounding, and presentation rules from `StatDefinition`, never from UI code.
- Keep stable `member_id` values as the identity boundary for snapshots and invalidation.
- Combat and UI consumers must read the same resolved snapshot.
- Keep `CombatModifiers` only as a compatibility facade; do not add another parallel calculation path.
- Stage only files explicitly listed by each task and leave unrelated dirty-worktree files unstaged.

## File Structure

- Create `scripts/stats/stat_definition.gd`: metadata, formatting, clamping, and validation for one stat.
- Create `scripts/stats/stat_catalog.gd`: indexed registry and duplicate/reference validation.
- Create `tools/create_stat_foundation_data.gd`: deterministic generator for the initial editable stat catalog Resource.
- Create `data/stats/core_stats.tres`: generated authoritative baseline stat catalog.
- Create `scripts/stats/stat_modifier.gd`: one flat/increased/reduced/more/less operation with tag filters and source identity.
- Create `scripts/stats/stat_modifier_source.gd`: named ordered group of modifiers owned by a class, member, party, or trait.
- Create `scripts/stats/resolved_stat_snapshot.gd`: read-only consumer surface for values, capabilities, and breakdowns.
- Create `scripts/stats/stat_resolver.gd`: the only arithmetic implementation for effective character stats.
- Modify `scripts/data/class_definition.gd`: add data-driven base overrides and capability tags without removing current fields.
- Modify `scripts/party/party_member_state.gd`: own character-specific modifier sources and capability tags.
- Modify `scripts/party/party_manager.gd`: build source layers, cache snapshots, and emit member-scoped invalidation.
- Modify `scripts/combat/combat_modifiers.gd`: translate the existing combat multiplier API from resolved snapshots.
- Modify `scripts/characters/party_actor.gd`: refresh health and movement from the shared snapshot.
- Create `tests/unit/test_stat_catalog.gd`: registry, formatting, clamping, and validation coverage.
- Create `tests/unit/test_stat_resolver.gd`: arithmetic order, tag conditions, source breakdowns, and immutability coverage.
- Create `tests/unit/test_member_stats.gd`: stable identity, ownership, cache invalidation, and compatibility coverage.

---

### Task 1: Authoritative Stat Definitions and Catalog

**Files:**

- Create: `scripts/stats/stat_definition.gd`
- Create: `scripts/stats/stat_catalog.gd`
- Create: `tools/create_stat_foundation_data.gd`
- Create: `data/stats/core_stats.tres`
- Create: `tests/unit/test_stat_catalog.gd`

**Interfaces:**

- Consumes: `TestAssertions` and Godot `ResourceSaver`.
- Produces: `StatCatalog.definition(id: StringName) -> StatDefinition`, `StatCatalog.validate() -> PackedStringArray`, and `StatDefinition.finalize_value(value: float) -> float`.

- [ ] **Step 1: Record the dirty-worktree boundary**

Run:

```powershell
git status --short
git diff -- scripts/data/class_definition.gd data/classes/fighter.tres project.godot
```

Expected: the existing formatting/UID edits and Godot AI autoload are visible and remain unstaged by this task.

- [ ] **Step 2: Write the failing catalog test**

Create `tests/unit/test_stat_catalog.gd`:

```gdscript
extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog := load("res://data/stats/core_stats.tres") as StatCatalog
	TestAssertions.truthy(catalog != null, "core stat catalog loads", failures)
	if catalog == null:
		return failures
	TestAssertions.equal(catalog.validate(), PackedStringArray(), "core stat catalog validates", failures)
	TestAssertions.equal(catalog.definition(&"max_health").display_name, "Maximum Health", "max health metadata", failures)
	TestAssertions.equal(catalog.definition(&"fire_resistance").keyword_id, &"fire_resistance", "resistance keyword identity", failures)
	TestAssertions.near(catalog.definition(&"crit_chance").finalize_value(0.92), 0.75, 0.0001, "crit chance clamps to cap", failures)
	TestAssertions.near(catalog.definition(&"armor").finalize_value(-12.0), 0.0, 0.0001, "armor clamps at zero", failures)
	TestAssertions.equal(catalog.definition(&"life_steal").format_value(0.125), "12.5%", "ratio formatting", failures)

	var duplicate := StatCatalog.new()
	duplicate.definitions = [catalog.definition(&"armor"), catalog.definition(&"armor")]
	TestAssertions.truthy(
		duplicate.validate().has("PARTY_FORGE_STAT_ERROR id=armor reason=duplicate id"),
		"duplicate stat IDs are grep-friendly",
		failures,
	)
	return failures
```

- [ ] **Step 3: Run the suite and verify the new test fails**

Run:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path 'F:\Projects(root)\Game dev\Projects\party-forge' --script res://tests/test_runner.gd
```

Expected: FAIL because `StatCatalog`, `StatDefinition`, and `core_stats.tres` do not exist.

- [ ] **Step 4: Implement stat definition metadata**

Create `scripts/stats/stat_definition.gd`:

```gdscript
class_name StatDefinition
extends Resource

enum ValueFormat { NUMBER, INTEGER, RATIO_PERCENT, MULTIPLIER, PER_SECOND }
enum Visibility { UNIVERSAL, CAPABILITY, NON_DEFAULT }

@export var id: StringName
@export var display_name: String
@export var ui_group: StringName
@export var value_format := ValueFormat.NUMBER
@export_range(0, 3, 1) var precision := 1
@export var default_value := 0.0
@export var has_minimum := false
@export var minimum := 0.0
@export var has_maximum := false
@export var maximum := 0.0
@export var visibility := Visibility.NON_DEFAULT
@export var capability_tags: Array[StringName] = []
@export var keyword_id: StringName

func finalize_value(value: float) -> float:
	var result := value
	if has_minimum:
		result = maxf(result, minimum)
	if has_maximum:
		result = minf(result, maximum)
	var decimal_places := precision + 2 if value_format == ValueFormat.RATIO_PERCENT else precision
	return snappedf(result, pow(10.0, -decimal_places))

func format_value(value: float) -> String:
	var final := finalize_value(value)
	match value_format:
		ValueFormat.INTEGER:
			return str(roundi(final))
		ValueFormat.RATIO_PERCENT:
			return ("%.*f%%" % [precision, final * 100.0])
		ValueFormat.MULTIPLIER:
			return ("%.*fx" % [precision, final])
		ValueFormat.PER_SECOND:
			return ("%.*f/s" % [precision, final])
		_:
			return ("%.*f" % [precision, final])

func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if id.is_empty(): errors.append("stat id is empty")
	if display_name.is_empty(): errors.append("stat %s display name is empty" % id)
	if ui_group.is_empty(): errors.append("stat %s UI group is empty" % id)
	if keyword_id.is_empty(): errors.append("stat %s keyword id is empty" % id)
	if has_minimum and has_maximum and minimum > maximum:
		errors.append("stat %s minimum exceeds maximum" % id)
	if visibility == Visibility.CAPABILITY and capability_tags.is_empty():
		errors.append("stat %s capability visibility has no tags" % id)
	return errors
```

- [ ] **Step 5: Implement the indexed catalog**

Create `scripts/stats/stat_catalog.gd`:

```gdscript
class_name StatCatalog
extends Resource

@export var definitions: Array[StatDefinition] = []
var _by_id: Dictionary = {}

func definition(id: StringName) -> StatDefinition:
	if _by_id.size() != definitions.size():
		_rebuild_index()
	return _by_id.get(id) as StatDefinition

func all() -> Array[StatDefinition]:
	return definitions.duplicate()

func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	var seen: Dictionary = {}
	for entry: StatDefinition in definitions:
		if entry == null:
			errors.append("PARTY_FORGE_STAT_ERROR id=<null> reason=resource failed to load")
			continue
		if seen.has(entry.id):
			errors.append("PARTY_FORGE_STAT_ERROR id=%s reason=duplicate id" % entry.id)
		else:
			seen[entry.id] = true
		for reason: String in entry.validate():
			errors.append("PARTY_FORGE_STAT_ERROR id=%s reason=%s" % [entry.id, reason])
	return errors

func _rebuild_index() -> void:
	_by_id.clear()
	for entry: StatDefinition in definitions:
		if entry != null and not _by_id.has(entry.id):
			_by_id[entry.id] = entry
```

- [ ] **Step 6: Generate the initial editable catalog**

Create `tools/create_stat_foundation_data.gd` with a `SceneTree` entry point. Its `_initialize()` must build and save `res://data/stats/core_stats.tres` from this exact definition table:

```gdscript
extends SceneTree

const OUTPUT := "res://data/stats/core_stats.tres"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/stats"))
	var catalog := StatCatalog.new()
	catalog.definitions = [
		_stat(&"max_health", "Maximum Health", &"overview", 100.0, StatDefinition.ValueFormat.INTEGER, 0, true, 1.0, false, 0.0, StatDefinition.Visibility.UNIVERSAL),
		_stat(&"armor", "Armor", &"defense", 0.0, StatDefinition.ValueFormat.NUMBER, 1, true, 0.0, false, 0.0, StatDefinition.Visibility.UNIVERSAL),
		_stat(&"move_speed", "Movement Speed", &"utility", 6.0, StatDefinition.ValueFormat.NUMBER, 2, true, 0.1, false, 0.0, StatDefinition.Visibility.UNIVERSAL),
		_stat(&"damage", "Damage", &"offense", 1.0, StatDefinition.ValueFormat.MULTIPLIER, 2, true, 0.0, false, 0.0, StatDefinition.Visibility.UNIVERSAL),
		_stat(&"attack_speed", "Attack Speed", &"offense", 1.0, StatDefinition.ValueFormat.MULTIPLIER, 2, true, 0.05, false, 0.0, StatDefinition.Visibility.UNIVERSAL),
		_stat(&"crit_chance", "Critical Strike Chance", &"offense", 0.0, StatDefinition.ValueFormat.RATIO_PERCENT, 1, true, 0.0, true, 0.75, StatDefinition.Visibility.UNIVERSAL),
		_stat(&"crit_multiplier", "Critical Strike Multiplier", &"offense", 1.5, StatDefinition.ValueFormat.RATIO_PERCENT, 0, true, 1.0, false, 0.0, StatDefinition.Visibility.UNIVERSAL),
		_stat(&"attack_range", "Attack Range", &"offense", 1.0, StatDefinition.ValueFormat.MULTIPLIER, 2, true, 0.05, false, 0.0, StatDefinition.Visibility.UNIVERSAL),
		_stat(&"projectile_speed", "Projectile Speed", &"offense", 1.0, StatDefinition.ValueFormat.MULTIPLIER, 2, true, 0.05, false, 0.0, StatDefinition.Visibility.CAPABILITY, [&"projectile"]),
		_stat(&"area_size", "Area Size", &"offense", 1.0, StatDefinition.ValueFormat.MULTIPLIER, 2, true, 0.05, false, 0.0, StatDefinition.Visibility.CAPABILITY, [&"area"]),
		_stat(&"cooldown_rate", "Cooldown Rate", &"offense", 1.0, StatDefinition.ValueFormat.MULTIPLIER, 2, true, 0.05, false, 0.0, StatDefinition.Visibility.CAPABILITY, [&"cooldown"]),
		_stat(&"healing_power", "Healing Power", &"offense", 1.0, StatDefinition.ValueFormat.MULTIPLIER, 2, true, 0.0, false, 0.0, StatDefinition.Visibility.CAPABILITY, [&"healing"]),
		_stat(&"dodge_chance", "Dodge Chance", &"defense", 0.0, StatDefinition.ValueFormat.RATIO_PERCENT, 1, true, 0.0, true, 0.75, StatDefinition.Visibility.NON_DEFAULT),
		_stat(&"block_chance", "Block Chance", &"defense", 0.0, StatDefinition.ValueFormat.RATIO_PERCENT, 1, true, 0.0, true, 0.75, StatDefinition.Visibility.NON_DEFAULT),
		_stat(&"block_effectiveness", "Block Effectiveness", &"defense", 0.5, StatDefinition.ValueFormat.RATIO_PERCENT, 1, true, 0.0, true, 1.0, StatDefinition.Visibility.CAPABILITY, [&"block"]),
		_stat(&"health_regeneration", "Health Regeneration", &"defense", 0.0, StatDefinition.ValueFormat.PER_SECOND, 2, true, 0.0, false, 0.0, StatDefinition.Visibility.NON_DEFAULT),
		_stat(&"life_steal", "Life Steal", &"defense", 0.0, StatDefinition.ValueFormat.RATIO_PERCENT, 1, true, 0.0, true, 1.0, StatDefinition.Visibility.NON_DEFAULT),
		_stat(&"pickup_radius", "Pickup Radius", &"utility", 1.0, StatDefinition.ValueFormat.MULTIPLIER, 2, true, 0.1, false, 0.0, StatDefinition.Visibility.UNIVERSAL),
		_stat(&"physical_damage", "Physical Damage", &"offense", 1.0, StatDefinition.ValueFormat.MULTIPLIER, 2, true, 0.0, false, 0.0, StatDefinition.Visibility.CAPABILITY, [&"physical"]),
		_stat(&"fire_damage", "Fire Damage", &"offense", 1.0, StatDefinition.ValueFormat.MULTIPLIER, 2, true, 0.0, false, 0.0, StatDefinition.Visibility.CAPABILITY, [&"fire"]),
		_stat(&"cold_damage", "Cold Damage", &"offense", 1.0, StatDefinition.ValueFormat.MULTIPLIER, 2, true, 0.0, false, 0.0, StatDefinition.Visibility.CAPABILITY, [&"cold"]),
		_stat(&"lightning_damage", "Lightning Damage", &"offense", 1.0, StatDefinition.ValueFormat.MULTIPLIER, 2, true, 0.0, false, 0.0, StatDefinition.Visibility.CAPABILITY, [&"lightning"]),
		_stat(&"chaos_damage", "Chaos Damage", &"offense", 1.0, StatDefinition.ValueFormat.MULTIPLIER, 2, true, 0.0, false, 0.0, StatDefinition.Visibility.CAPABILITY, [&"chaos"]),
		_resistance(&"fire_resistance", "Fire Resistance", &"fire"),
		_resistance(&"cold_resistance", "Cold Resistance", &"cold"),
		_resistance(&"lightning_resistance", "Lightning Resistance", &"lightning"),
		_resistance(&"chaos_resistance", "Chaos Resistance", &"chaos"),
	]
	var result := ResourceSaver.save(catalog, OUTPUT)
	if result != OK:
		push_error("PARTY_FORGE_STAT_ERROR id=catalog reason=save failed code=%d" % result)
	quit(result)

func _resistance(id: StringName, label: String, capability: StringName) -> StatDefinition:
	return _stat(id, label, &"defense", 0.0, StatDefinition.ValueFormat.RATIO_PERCENT, 1, true, -1.0, true, 0.75, StatDefinition.Visibility.CAPABILITY, [capability])

func _stat(id: StringName, label: String, group: StringName, base: float, format: StatDefinition.ValueFormat, precision: int, has_min: bool, min_value: float, has_max: bool, max_value: float, visibility: StatDefinition.Visibility, tags: Array[StringName] = []) -> StatDefinition:
	var definition := StatDefinition.new()
	definition.id = id
	definition.display_name = label
	definition.ui_group = group
	definition.default_value = base
	definition.value_format = format
	definition.precision = precision
	definition.has_minimum = has_min
	definition.minimum = min_value
	definition.has_maximum = has_max
	definition.maximum = max_value
	definition.visibility = visibility
	definition.capability_tags = tags
	definition.keyword_id = id
	return definition
```

Run:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path 'F:\Projects(root)\Game dev\Projects\party-forge' --script res://tools/create_stat_foundation_data.gd
```

Expected: exit 0 and `data/stats/core_stats.tres` exists.

- [ ] **Step 7: Run the focused and full suites**

Run the full custom runner because it automatically discovers the new suite:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path 'F:\Projects(root)\Game dev\Projects\party-forge' --script res://tests/test_runner.gd
```

Expected: `TEST_SUMMARY: PASS (17 suites)`.

- [ ] **Step 8: Commit only Task 1 files**

```powershell
git add scripts/stats/stat_definition.gd scripts/stats/stat_catalog.gd tools/create_stat_foundation_data.gd data/stats/core_stats.tres tests/unit/test_stat_catalog.gd
git commit -m "feat: add character stat catalog"
```

---

### Task 2: Modifier Sources and Deterministic Resolver

**Files:**

- Create: `scripts/stats/stat_modifier.gd`
- Create: `scripts/stats/stat_modifier_source.gd`
- Create: `scripts/stats/resolved_stat_snapshot.gd`
- Create: `scripts/stats/stat_resolver.gd`
- Create: `tests/unit/test_stat_resolver.gd`

**Interfaces:**

- Consumes: `StatCatalog.definition()` and `StatDefinition.finalize_value()`.
- Produces: `StatResolver.resolve(member_id, catalog, base_values, capabilities, sources, action_tags, revision) -> ResolvedStatSnapshot` and `ResolvedStatSnapshot.value(stat_id, fallback) -> float`.

- [ ] **Step 1: Write the failing resolver test**

Create `tests/unit/test_stat_resolver.gd` with four cases: the approved `171.6` arithmetic example, required/excluded tag matching, catalog clamping, and named-source breakdown preservation. Use `StatModifier.create()` and `StatModifierSource.create()` from the implementation below. Assert that an untagged resolution excludes a `projectile` modifier and a tagged resolution includes it.

```gdscript
extends RefCounted

const CATALOG: StatCatalog = preload("res://data/stats/core_stats.tres")

func run() -> Array[String]:
	var failures: Array[String] = []
	var source := StatModifierSource.create(&"test_source", &"character", "Test Source", 7, [
		StatModifier.create(&"damage", StatModifier.Operation.FLAT, 20.0, &"flat", "Flat"),
		StatModifier.create(&"damage", StatModifier.Operation.INCREASED, 0.30, &"increased", "Increased"),
		StatModifier.create(&"damage", StatModifier.Operation.MORE, 0.10, &"more", "More", [&"projectile"]),
	])
	var plain := StatResolver.resolve(7, CATALOG, {&"damage": 100.0}, [], [source], [], 1)
	var projectile := StatResolver.resolve(7, CATALOG, {&"damage": 100.0}, [], [source], [&"projectile"], 2)
	TestAssertions.near(plain.value(&"damage"), 156.0, 0.001, "flat and increased order", failures)
	TestAssertions.near(projectile.value(&"damage"), 171.6, 0.001, "approved flat increased more order", failures)
	TestAssertions.equal(projectile.revision, 2, "snapshot carries revision", failures)
	TestAssertions.equal(projectile.breakdown(&"damage").size(), 4, "breakdown contains base and three sources", failures)
	TestAssertions.equal(projectile.breakdown(&"damage")[3]["source_label"], "More", "breakdown preserves source label", failures)

	var capped_source := StatModifierSource.create(&"caps", &"character", "Caps", 7, [
		StatModifier.create(&"crit_chance", StatModifier.Operation.FLAT, 2.0, &"crit", "Crit"),
	])
	var capped := StatResolver.resolve(7, CATALOG, {}, [], [capped_source], [], 3)
	TestAssertions.near(capped.value(&"crit_chance"), 0.75, 0.001, "definition cap applies after arithmetic", failures)
	return failures
```

- [ ] **Step 2: Run the suite and verify failure**

Run the full custom runner. Expected: FAIL because the modifier and resolver classes do not exist.

- [ ] **Step 3: Implement modifier and source Resources**

Create `scripts/stats/stat_modifier.gd` and `scripts/stats/stat_modifier_source.gd` with these public contracts:

```gdscript
# scripts/stats/stat_modifier.gd
class_name StatModifier
extends Resource

enum Operation { FLAT, INCREASED, REDUCED, MORE, LESS }

@export var stat_id: StringName
@export var operation := Operation.FLAT
@export var value := 0.0
@export var source_id: StringName
@export var source_label: String
@export var required_tags: Array[StringName] = []
@export var excluded_tags: Array[StringName] = []

static func create(target: StringName, op: Operation, amount: float, source: StringName, label: String, required: Array[StringName] = [], excluded: Array[StringName] = []) -> StatModifier:
	var modifier := StatModifier.new()
	modifier.stat_id = target
	modifier.operation = op
	modifier.value = amount
	modifier.source_id = source
	modifier.source_label = label
	modifier.required_tags = required
	modifier.excluded_tags = excluded
	return modifier

func applies_to(tags: Array[StringName]) -> bool:
	for tag: StringName in required_tags:
		if tag not in tags: return false
	for tag: StringName in excluded_tags:
		if tag in tags: return false
	return true
```

```gdscript
# scripts/stats/stat_modifier_source.gd
class_name StatModifierSource
extends Resource

@export var id: StringName
@export var source_type: StringName
@export var label: String
@export var owner_member_id := 0
@export var modifiers: Array[StatModifier] = []

static func create(source_id: StringName, type_id: StringName, display_label: String, member_id: int, entries: Array[StatModifier]) -> StatModifierSource:
	var source := StatModifierSource.new()
	source.id = source_id
	source.source_type = type_id
	source.label = display_label
	source.owner_member_id = member_id
	source.modifiers = entries
	return source
```

- [ ] **Step 4: Implement snapshots and the resolver**

`ResolvedStatSnapshot` must expose copies of breakdown arrays so consumers cannot mutate cached state. `StatResolver` must iterate catalog definitions, apply only matching modifiers, and append a base row plus one row per applied modifier.

```gdscript
# scripts/stats/resolved_stat_snapshot.gd
class_name ResolvedStatSnapshot
extends RefCounted

var revision := 0
var capabilities: Array[StringName] = []
var _values: Dictionary = {}
var _breakdowns: Dictionary = {}

func value(stat_id: StringName, fallback: float = 0.0) -> float:
	return float(_values.get(stat_id, fallback))

func breakdown(stat_id: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row: Dictionary in _breakdowns.get(stat_id, []):
		result.append(row.duplicate(true))
	return result

func set_resolved(stat_id: StringName, amount: float, rows: Array[Dictionary]) -> void:
	_values[stat_id] = amount
	_breakdowns[stat_id] = rows.duplicate(true)
```

```gdscript
# scripts/stats/stat_resolver.gd
class_name StatResolver
extends RefCounted

static func resolve(member_id: int, catalog: StatCatalog, base_values: Dictionary, capabilities: Array[StringName], sources: Array[StatModifierSource], action_tags: Array[StringName], revision: int) -> ResolvedStatSnapshot:
	var snapshot := ResolvedStatSnapshot.new()
	snapshot.revision = revision
	snapshot.capabilities = capabilities.duplicate()
	var tags := capabilities.duplicate()
	for tag: StringName in action_tags:
		if tag not in tags: tags.append(tag)
	for definition: StatDefinition in catalog.all():
		var base := float(base_values.get(definition.id, definition.default_value))
		var flat := 0.0
		var increased := 0.0
		var reduced := 0.0
		var more_factors: Array[float] = []
		var less_factors: Array[float] = []
		var rows: Array[Dictionary] = [{"source_id": &"base", "source_label": "Base", "operation": -1, "value": base}]
		for source: StatModifierSource in sources:
			if source == null or (source.owner_member_id != 0 and source.owner_member_id != member_id): continue
			for modifier: StatModifier in source.modifiers:
				if modifier == null or modifier.stat_id != definition.id or not modifier.applies_to(tags): continue
				match modifier.operation:
					StatModifier.Operation.FLAT: flat += modifier.value
					StatModifier.Operation.INCREASED: increased += modifier.value
					StatModifier.Operation.REDUCED: reduced += modifier.value
					StatModifier.Operation.MORE: more_factors.append(1.0 + modifier.value)
					StatModifier.Operation.LESS: less_factors.append(1.0 - modifier.value)
				rows.append({"source_id": modifier.source_id, "source_label": modifier.source_label, "operation": modifier.operation, "value": modifier.value})
		var effective := (base + flat) * (1.0 + increased - reduced)
		for factor: float in more_factors: effective *= factor
		for factor: float in less_factors: effective *= factor
		snapshot.set_resolved(definition.id, definition.finalize_value(effective), rows)
	return snapshot
```

- [ ] **Step 5: Run tests and commit**

Run the full suite. Expected: `TEST_SUMMARY: PASS (18 suites)`.

```powershell
git add scripts/stats/stat_modifier.gd scripts/stats/stat_modifier_source.gd scripts/stats/resolved_stat_snapshot.gd scripts/stats/stat_resolver.gd tests/unit/test_stat_resolver.gd
git commit -m "feat: resolve layered character stats"
```

---

### Task 3: Stable Per-Member Ownership and Snapshot Invalidation

**Files:**

- Modify: `scripts/data/class_definition.gd`
- Modify: `scripts/party/party_member_state.gd`
- Modify: `scripts/party/party_manager.gd`
- Create: `tests/unit/test_member_stats.gd`

**Interfaces:**

- Consumes: `StatResolver.resolve()` and `data/stats/core_stats.tres`.
- Produces: `PartyManager.stats_for(member_id: int) -> ResolvedStatSnapshot`, `PartyManager.add_member_source(member_id, source) -> bool`, and `PartyManager.stats_changed(member_id)`.

- [ ] **Step 1: Write failing ownership and invalidation tests**

Create `tests/unit/test_member_stats.gd`:

```gdscript
extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var catalog := GameCatalog.load_defaults()
	var ranger := catalog.class_by_id(&"ranger")
	var party := PartyManager.new()
	party.initialize(ranger, catalog.traits)
	party.recruit(ranger)
	var first_id := party.members[0].member_id
	var second_id := party.members[1].member_id
	var changed: Array[int] = []
	party.stats_changed.connect(func(member_id: int) -> void: changed.append(member_id))

	var first_before := party.stats_for(first_id)
	var second_before := party.stats_for(second_id)
	var personal := StatModifierSource.create(&"member_2_damage", &"character", "Personal Training", second_id, [
		StatModifier.create(&"damage", StatModifier.Operation.INCREASED, 0.25, &"personal_damage", "Personal Training"),
	])
	TestAssertions.truthy(party.add_member_source(second_id, personal), "member source is accepted", failures)
	var first_personal := party.stats_for(first_id)
	var second_personal := party.stats_for(second_id)
	TestAssertions.near(first_personal.value(&"damage"), 1.0, 0.001, "first duplicate excludes second member source", failures)
	TestAssertions.near(second_personal.value(&"damage"), 1.25, 0.001, "second duplicate owns personal source", failures)
	TestAssertions.equal(first_personal.revision, first_before.revision, "unrelated member cache remains valid", failures)
	TestAssertions.truthy(second_personal.revision > second_before.revision, "owned source invalidates target member", failures)

	var first_revision := first_personal.revision
	var second_revision := second_personal.revision
	TestAssertions.truthy(party.rank_up(&"ranger"), "shared Ranger rank increases", failures)
	var first_ranked := party.stats_for(first_id)
	var second_ranked := party.stats_for(second_id)
	TestAssertions.truthy(first_ranked.revision > first_revision, "class rank invalidates first duplicate", failures)
	TestAssertions.truthy(second_ranked.revision > second_revision, "class rank invalidates second duplicate", failures)
	TestAssertions.near(first_ranked.value(&"damage"), 1.2, 0.001, "shared class rank affects first duplicate", failures)
	TestAssertions.near(second_ranked.value(&"damage"), 1.45, 0.001, "shared and personal increased damage add", failures)
	TestAssertions.truthy(_has_source(first_ranked, &"damage", &"class_rank_ranger"), "first breakdown names class rank", failures)
	TestAssertions.truthy(_has_source(second_ranked, &"damage", &"personal_damage"), "second breakdown names personal source", failures)

	var event_count := changed.size()
	TestAssertions.equal(party.stats_for(9999), null, "unknown member has no snapshot", failures)
	TestAssertions.truthy(not party.add_member_source(9999, personal), "unknown member rejects source", failures)
	TestAssertions.equal(changed.size(), event_count, "unknown member emits no stat event", failures)
	party.free()
	return failures

func _has_source(snapshot: ResolvedStatSnapshot, stat_id: StringName, source_id: StringName) -> bool:
	for row: Dictionary in snapshot.breakdown(stat_id):
		if row["source_id"] == source_id:
			return true
	return false
```

- [ ] **Step 2: Run the suite and verify failure**

Run the custom runner. Expected: FAIL because `stats_for`, member sources, and member-scoped invalidation do not exist.

- [ ] **Step 3: Extend class and member data without erasing current fields**

Add to `ClassDefinition`:

```gdscript
@export var capability_tags: Array[StringName] = []
@export var base_stat_overrides: Dictionary = {}

func stat_base_values() -> Dictionary:
	var values := base_stat_overrides.duplicate(true)
	values[&"max_health"] = float(values.get(&"max_health", max_health))
	values[&"armor"] = float(values.get(&"armor", armor))
	values[&"move_speed"] = float(values.get(&"move_speed", move_speed))
	return values
```

Add to `PartyMemberState`:

```gdscript
var capability_tags: Array[StringName] = []
var modifier_sources: Array[StatModifierSource] = []
```

Initialize `capability_tags` from `definition.capability_tags`, then merge class traits without duplicates. Do not derive member identity from array position after construction.

- [ ] **Step 4: Add the party snapshot service**

Add to `PartyManager`:

```gdscript
signal stats_changed(member_id: int)

const STAT_CATALOG: StatCatalog = preload("res://data/stats/core_stats.tres")
var _stat_revision := 0
var _stat_cache: Dictionary = {}

func member_by_id(member_id: int) -> PartyMemberState:
	for member: PartyMemberState in members:
		if member.member_id == member_id: return member
	return null

func stats_for(member_id: int) -> ResolvedStatSnapshot:
	var member := member_by_id(member_id)
	if member == null: return null
	if _stat_cache.has(member_id): return _stat_cache[member_id] as ResolvedStatSnapshot
	var snapshot := StatResolver.resolve(member_id, STAT_CATALOG, member.class_definition.stat_base_values(), member.capability_tags, _sources_for(member), [], _stat_revision)
	_stat_cache[member_id] = snapshot
	return snapshot

func add_member_source(member_id: int, source: StatModifierSource) -> bool:
	var member := member_by_id(member_id)
	if member == null or source == null: return false
	source.owner_member_id = member_id
	member.modifier_sources.append(source)
	_invalidate_member(member_id)
	return true

func _invalidate_member(member_id: int) -> void:
	_stat_revision += 1
	_stat_cache.erase(member_id)
	stats_changed.emit(member_id)

func _invalidate_all_members() -> void:
	_stat_revision += 1
	_stat_cache.clear()
	for member: PartyMemberState in members:
		stats_changed.emit(member.member_id)
```

Implement `_sources_for(member)` and its helpers so layers are returned in class-rank, member-owned, party, then trait order:

```gdscript
func _sources_for(member: PartyMemberState) -> Array[StatModifierSource]:
	var sources: Array[StatModifierSource] = []
	var definition := member.class_definition
	var rank_bonus := float(maxi(get_class_rank(definition.id), 1) - 1) * definition.class_rank_power_step
	var class_rank_id := StringName("class_rank_%s" % definition.id)
	sources.append(StatModifierSource.create(
		class_rank_id,
		&"class_rank",
		"%s Rank" % definition.display_name,
		0,
		[StatModifier.create(&"damage", StatModifier.Operation.INCREASED, rank_bonus, class_rank_id, "%s Rank" % definition.display_name)],
	))
	for source: StatModifierSource in member.modifier_sources:
		sources.append(source)

	var party_modifiers: Array[StatModifier] = []
	for stat_id: StringName in PARTY_STAT_IDS:
		var amount := float(party_stat_rank(stat_id)) * _party_stat_step(stat_id)
		party_modifiers.append(StatModifier.create(stat_id, StatModifier.Operation.INCREASED, amount, StringName("party_%s" % stat_id), "Party %s" % String(stat_id).capitalize()))
	sources.append(StatModifierSource.create(&"party_upgrades", &"party", "Party Upgrades", 0, party_modifiers))

	var trait_modifiers: Array[StatModifier] = []
	for trait_id: StringName in definition.traits:
		var trait := trait_definition(trait_id)
		var active_value := effective_trait_value(trait_id)
		if trait == null or active_value <= 0.0:
			continue
		var label := trait.display_name
		match trait.stat_id:
			&"attack_speed":
				trait_modifiers.append(StatModifier.create(&"attack_speed", StatModifier.Operation.INCREASED, active_value, trait_id, label))
			&"cooldown_reduction":
				trait_modifiers.append(StatModifier.create(&"attack_speed", StatModifier.Operation.MORE, 1.0 / maxf(1.0 - active_value, 0.05) - 1.0, trait_id, label))
			&"projectile_speed_and_range":
				trait_modifiers.append(StatModifier.create(&"projectile_speed", StatModifier.Operation.INCREASED, active_value, trait_id, label))
				trait_modifiers.append(StatModifier.create(&"attack_range", StatModifier.Operation.INCREASED, active_value, trait_id, label))
			&"area_size":
				trait_modifiers.append(StatModifier.create(&"area_size", StatModifier.Operation.INCREASED, active_value, trait_id, label))
			&"support_power", &"healing_and_revive":
				trait_modifiers.append(StatModifier.create(&"healing_power", StatModifier.Operation.INCREASED, active_value, trait_id, label))
	sources.append(StatModifierSource.create(&"active_traits", &"trait", "Active Traits", 0, trait_modifiers))
	return sources

func _party_stat_step(stat_id: StringName) -> float:
	match stat_id:
		&"max_health": return upgrade_tuning.max_health_per_rank
		&"damage": return upgrade_tuning.damage_per_rank
		&"move_speed": return upgrade_tuning.move_speed_per_rank
		&"attack_speed": return upgrade_tuning.attack_speed_per_rank
		&"pickup_radius": return upgrade_tuning.pickup_radius_per_rank
		_: return 0.0
```

Insert invalidation at the mutation points before their existing public signals:

```gdscript
# rank_up(), after incrementing class_ranks
_invalidate_all_members()
class_rank_changed.emit(class_id, int(class_ranks[class_id]))

# upgrade_party_stat(), after incrementing party_stat_ranks
_invalidate_all_members()
upgrades_changed.emit()

# upgrade_trait(), after incrementing trait_upgrade_ranks
_invalidate_all_members()
upgrades_changed.emit()
```

Change `_recalculate_traits()` to return whether tiers changed, invalidate before notifying listeners, and avoid a double invalidation in `_append_member()`:

```gdscript
func _append_member(definition: ClassDefinition, leader: bool) -> void:
	var member := PartyMemberState.new(members.size() + 1, definition, leader)
	members.append(member)
	if not class_ranks.has(definition.id): class_ranks[definition.id] = 1
	if not _recalculate_traits():
		_invalidate_all_members()
	member_added.emit(member)

func _recalculate_traits() -> bool:
	var next: Dictionary = {}
	for definition: TraitDefinition in trait_definitions:
		var count: int = trait_count(definition.id)
		var achieved := 0
		for threshold: Variant in definition.tiers.keys():
			if count >= int(threshold): achieved = maxi(achieved, int(threshold))
		if achieved > 0: next[definition.id] = achieved
	if next == active_tiers:
		return false
	active_tiers = next
	_invalidate_all_members()
	active_traits_changed.emit(active_tiers.duplicate())
	return true
```

Call `_invalidate_all_members()` from rank, party-stat, trait-rank, recruitment, and active-trait changes. Keep the existing public signals for current consumers.

- [ ] **Step 5: Run tests and commit**

Run the full suite. Expected: `TEST_SUMMARY: PASS (19 suites)`.

```powershell
git add scripts/data/class_definition.gd scripts/party/party_member_state.gd scripts/party/party_manager.gd tests/unit/test_member_stats.gd
git commit -m "feat: add per-member stat snapshots"
```

---

### Task 4: Migrate Current Runtime Consumers to the Shared Snapshot

**Files:**

- Modify: `scripts/combat/combat_modifiers.gd`
- Modify: `scripts/characters/party_actor.gd`
- Modify: `tests/unit/test_attack_execution.gd`
- Modify: `tests/unit/test_party_manager.gd`

**Interfaces:**

- Consumes: `PartyManager.stats_for(member_id)`.
- Produces: unchanged `CombatModifiers.Snapshot` fields for existing combat code and snapshot-driven health/movement refresh in `PartyActor`.

- [ ] **Step 1: Strengthen compatibility tests before implementation**

In `test_attack_execution.gd`, append this block to `_test_combat_modifiers()` after the existing Fighter assertions:

```gdscript
	var personal := StatModifierSource.create(&"fighter_personal_damage", &"character", "Personal Training", fighter_party.members[0].member_id, [
		StatModifier.create(&"damage", StatModifier.Operation.INCREASED, 0.25, &"fighter_personal_damage", "Personal Training"),
	])
	TestAssertions.truthy(fighter_party.add_member_source(fighter_party.members[0].member_id, personal), "combat test member source added", failures)
	var personalized: RefCounted = modifier_script.call("resolve", fighter_party.members[0], fighter_party) as RefCounted
	var resolved := fighter_party.stats_for(fighter_party.members[0].member_id)
	TestAssertions.near(float(personalized.get("power_multiplier")), 1.45, 0.001, "combat facade includes member-owned damage", failures)
	TestAssertions.near(float(personalized.get("power_multiplier")), resolved.value(&"damage"), 0.001, "combat power equals resolved damage", failures)
	TestAssertions.near(float(personalized.get("cooldown_rate_multiplier")), resolved.value(&"attack_speed"), 0.001, "combat rate equals resolved attack speed", failures)
```

In `test_party_manager.gd`, call `_test_resolved_party_stats(failures)` from `run()` and add:

```gdscript
func _test_resolved_party_stats(failures: Array[String]) -> void:
	var catalog := GameCatalog.load_defaults()
	var fighter := catalog.class_by_id(&"fighter")
	var party := PartyManager.new()
	party.initialize(fighter, catalog.traits)
	var leader_id := party.members[0].member_id
	TestAssertions.truthy(party.upgrade_party_stat(&"max_health"), "health stat upgrade succeeds", failures)
	TestAssertions.truthy(party.upgrade_party_stat(&"move_speed"), "movement stat upgrade succeeds", failures)
	var leader_stats := party.stats_for(leader_id)
	TestAssertions.near(leader_stats.value(&"max_health"), 273.0, 0.001, "health upgrade resolves from class base", failures)
	TestAssertions.near(leader_stats.value(&"move_speed"), 6.39, 0.001, "movement upgrade resolves and rounds from class base", failures)
	TestAssertions.truthy(party.recruit(catalog.class_by_id(&"ranger")), "recruit succeeds after snapshot", failures)
	TestAssertions.equal(party.members[0].member_id, leader_id, "recruitment preserves leader identity", failures)
	TestAssertions.equal(party.stats_for(leader_id).value(&"max_health"), 273.0, "recruitment preserves leader snapshot value", failures)
	party.free()
```

- [ ] **Step 2: Run tests and verify the new assertions fail**

Expected: FAIL because `CombatModifiers` still calculates independently.

- [ ] **Step 3: Replace duplicate combat arithmetic with a facade**

Keep the existing `CombatModifiers.Snapshot` fields, but replace `resolve()` with:

```gdscript
static func resolve(member_state: PartyMemberState, party_manager: PartyManager) -> Snapshot:
	var result := Snapshot.new()
	if member_state == null or party_manager == null:
		return result
	var stats := party_manager.stats_for(member_state.member_id)
	if stats == null:
		return result
	result.power_multiplier = stats.value(&"damage", 1.0)
	result.cooldown_rate_multiplier = stats.value(&"attack_speed", 1.0)
	result.projectile_multiplier = stats.value(&"projectile_speed", 1.0)
	result.range_multiplier = stats.value(&"attack_range", 1.0)
	result.area_multiplier = stats.value(&"area_size", 1.0)
	result.healing_multiplier = stats.value(&"healing_power", 1.0)
	return result
```

Delete `_trait_definition()` because the facade no longer owns trait arithmetic.

- [ ] **Step 4: Move health and movement refresh to snapshots**

In `PartyActor.configure_combat()`, connect and disconnect `party_manager.stats_changed` alongside the existing signals. Add:

```gdscript
func _on_stats_changed(member_id: int) -> void:
	if member_state != null and member_state.member_id == member_id:
		_refresh_runtime_stats()
```

Replace max-health and movement calculation inside `_refresh_runtime_stats()` with:

```gdscript
var stats := party_manager.stats_for(member_state.member_id) if party_manager != null else null
move_speed = stats.value(&"move_speed", definition.move_speed) if stats != null else definition.move_speed
if health != null:
	health.set_max_health(stats.value(&"max_health", definition.max_health) if stats != null else definition.max_health, true)
	health.revive_delay = definition.revive_delay * (party_manager.revive_delay_multiplier() if party_manager != null else 1.0)
	health.revive_health_fraction = definition.revive_health_fraction
```

Do not modify projectile scripts or enemy projectile tuning.

- [ ] **Step 5: Run complete automated verification**

Run:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path 'F:\Projects(root)\Game dev\Projects\party-forge' --script res://tests/test_runner.gd
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path 'F:\Projects(root)\Game dev\Projects\party-forge' --editor --quit-after 2
```

Expected: `TEST_SUMMARY: PASS (19 suites)`, both processes exit 0, and parser/import output contains no errors.

- [ ] **Step 6: Verify through the live Godot editor bridge**

With Party Forge open, verify all of the following:

- The editor reports `readiness=ready`.
- `res://scenes/game/main.tscn` opens and its hierarchy is readable.
- Running the project reaches class selection without debugger errors.
- Selecting Fighter begins the run, health and movement initialize, and attacks still damage enemies.
- Ranking or party-stat modification invalidates only the intended member snapshots.
- Stopping the run returns the editor to `play_state=stopped`.

- [ ] **Step 7: Commit only runtime migration files**

```powershell
git add scripts/combat/combat_modifiers.gd scripts/characters/party_actor.gd tests/unit/test_attack_execution.gd tests/unit/test_party_manager.gd
git commit -m "refactor: drive combat from resolved stats"
```

## Final Review Gate

- Re-run `git status --short` and confirm unrelated user-authored files remain unstaged.
- Re-run the full suite and parser/import check from Task 4.
- Confirm the approved arithmetic example resolves to exactly `171.6` before stat-definition rounding.
- Confirm two duplicate classes can hold different member-owned sources.
- Confirm class ranks remain shared by class ID.
- Confirm no projectile speed/lifetime constants changed.
- Confirm no UI code calculates effective stat values.
- Confirm `CombatModifiers` contains no independent trait or upgrade formulas.
- Confirm `data/stats/core_stats.tres` is editable through the Godot Inspector.
