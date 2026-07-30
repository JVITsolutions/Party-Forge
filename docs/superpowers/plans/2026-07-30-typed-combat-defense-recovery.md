# Party Forge Typed Combat, Defenses, and Recovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace every current raw party and enemy damage path with one deterministic typed-damage resolver and make crit, dodge, armor, resistances, block, life steal, regeneration, and existing Vanguard protection functional.

**Architecture:** Godot `Resource` catalogs define damage types and authored damage components. Attack execution prepares attacker-dependent values and one shared crit outcome into an immutable packet; a central resolver combines that packet with a target adapter, independent dodge/block rolls, mitigation, health application, and life steal. `PartyManager` supplies action-aware snapshots, enemies supply lightweight snapshots, and `HealthComponent` owns only health state.

**Tech Stack:** Godot 4.7.1 stable Mono, typed GDScript, Godot `.tres` Resources, the existing custom headless test runner, PowerShell, Git, and the connected Godot AI editor bridge for live verification.

## Global Constraints

- Use the approved design at `docs/superpowers/specs/2026-07-30-typed-combat-defense-recovery-design.md` as the authority.
- Keep the damage-type registry open-ended; never switch on `physical`, `fire`, `cold`, `lightning`, or `chaos` IDs inside `DamageResolver`.
- Store chance and resistance values as ratios: `0.15` means 15 percent.
- Use one run-level seeded `CombatRng`; gameplay code must not call global `randf()` or create private combat RNGs.
- Roll crit once per attack execution and reuse it for all targets; roll dodge and block independently per defender in stable combatant-ID order.
- Apply damage in this order: global and typed offense, crit, dodge, type mitigation, contextual incoming multiplier, block, health, life steal.
- Use actual health removed, excluding overkill, as the life-steal base.
- Healing remains a positive effect using `power * healing_power`; it never enters `DamageResolver`.
- Preserve Spitter `SPEED = 6.0` and `MAX_LIFETIME = 3.0` exactly.
- Preserve current four-member parties, duplicate classes, elastic formations, run flow, experience, death/downed/revive behavior, and Vanguard protection.
- Preserve all unrelated user work. At plan creation, `fighter.tres`, `core_stats.tres`, the handbook plan, `project.godot`, `main.tscn`, `hud.tscn`, `class_definition.gd`, `game_run.gd`, `main.gd`, and several UI scripts are dirty; GodotSteam, Marksman, the handbook ZIP, and a UID are untracked.
- Before editing any already-dirty file, record its current diff. Stage only feature hunks with an index-only patch; never stage the whole dirty file. Verify `git diff --cached --name-status` before every commit.
- Do not initialize Steam or add a Steam gameplay dependency.

## File Structure

- Create `scripts/data/damage_type_definition.gd`: one type's display, stat mappings, mitigation rule, and validation.
- Create `scripts/data/damage_type_catalog.gd`: deterministic indexed registry and cross-reference validation.
- Create `data/damage_types/core_damage_types.tres`: Physical, Fire, Cold, Lightning, and Chaos definitions.
- Modify `scripts/data/game_catalog.gd`: load and validate the damage catalog alongside existing content.
- Create `scripts/data/attack_damage_component.gd`: one positive authored amount keyed by damage-type ID.
- Modify `scripts/data/attack_definition.gd`: damaging components, normalized action tags, crit permission, and heal/damage validation.
- Create `tools/migrate_typed_combat_data.gd`: deterministic, idempotent creation/migration of current party and enemy attack Resources.
- Create `data/attacks/swarmer_contact.tres`, `spitter_projectile.tres`, `guardian_charge.tres`, and `guardian_shockwave.tres`.
- Create `scripts/combat/combat_rng.gd`: seeded ordered draws and explicit chance-roll evidence.
- Create `scripts/combat/prepared_damage_component.gd`: immutable attacker-scaled component evidence.
- Create `scripts/combat/damage_packet.gd`: immutable prepared hit shared by its delivery targets.
- Create `scripts/combat/damage_result.gd`: complete per-defender outcome evidence.
- Create `scripts/combat/combatant_adapter.gd`: common identity, team, availability, health, snapshot, and incoming-multiplier surface.
- Create `scripts/combat/damage_resolver.gd`: the sole damaging-hit preparation and resolution formulas.
- Create `scripts/combat/recovery_controller.gd`: frame-rate-independent regeneration.
- Modify `scripts/combat/health_component.gd`: apply final damage without armor or a minimum-one rule.
- Modify `scripts/party/party_manager.gd`: cache normalized action-aware snapshots and own run combat dependencies.
- Modify `scripts/characters/party_actor.gd`: expose a party adapter, configure recovery, and stop applying damage locally.
- Modify `scripts/combat/attack_executor.gd`, `projectile.gd`, and `area_burst.gd`: prepare and deliver packets rather than scalar damage.
- Modify `scripts/combat/combat_modifiers.gd`: retain timing/range/area/healing values but remove its parallel damage multiplier.
- Modify `scripts/data/enemy_definition.gd`: stat overrides, attack array, lookup, and behavior validation.
- Modify `scripts/enemies/enemy_actor.gd`: enemy adapter, stable identity, shared resolver access, and recovery.
- Modify `scripts/enemies/swarmer.gd`, `spitter.gd`, `enemy_projectile.gd`, and `forge_guardian.gd`: retrieve stable attack IDs and resolve packets.
- Modify `scripts/game/game_run.gd`: own and reseed the one run-level combat RNG.
- Modify `scripts/game/spawn_director.gd`: assign stable enemy sequence IDs and pass combat dependencies.
- Modify `scripts/game/main.gd`: pass the run seed, combat RNG, and damage catalog to party, spawns, and boss.
- Update existing combat, health, catalog, member-stat, main-wiring, and final-review tests.
- Create focused suites `test_damage_type_catalog.gd`, `test_attack_damage_data.gd`, `test_combat_rng.gd`, `test_recovery_controller.gd`, `test_damage_resolver.gd`, `test_enemy_typed_combat.gd`, and `test_typed_combat_integration.gd`.

---

### Task 1: Damage-Type Registry and Catalog Integration

**Files:**

- Create: `scripts/data/damage_type_definition.gd`
- Create: `scripts/data/damage_type_catalog.gd`
- Create: `data/damage_types/core_damage_types.tres`
- Modify: `scripts/data/game_catalog.gd`
- Create: `tests/unit/test_damage_type_catalog.gd`

**Interfaces:**

- Consumes: `StatCatalog.definition(id)` and `GameCatalog.load_defaults()`.
- Produces: `DamageTypeCatalog.definition(id: StringName) -> DamageTypeDefinition`, `all() -> Array[DamageTypeDefinition]`, and `validate(stats: StatCatalog) -> PackedStringArray`.

- [ ] **Step 1: Record the worktree boundary**

Run:

```powershell
git status --short
git diff -- data/stats/core_stats.tres scripts/data/game_catalog.gd
```

Expected: the Godot-added UIDs in `core_stats.tres` remain unstaged; `game_catalog.gd` is clean.

- [ ] **Step 2: Write the failing registry test**

Create `tests/unit/test_damage_type_catalog.gd` with this `run()` body:

```gdscript
extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var game := GameCatalog.load_defaults()
	var types := game.damage_types
	TestAssertions.truthy(types != null, "damage catalog loads", failures)
	if types == null:
		return failures
	TestAssertions.equal(types.validate(PartyManager.STAT_CATALOG), PackedStringArray(), "damage catalog validates", failures)
	TestAssertions.equal(types.all().map(func(entry: DamageTypeDefinition) -> StringName: return entry.id), [&"physical", &"fire", &"cold", &"lightning", &"chaos"], "damage type order", failures)
	TestAssertions.equal(types.definition(&"physical").mitigation_rule, DamageTypeDefinition.MitigationRule.ARMOR, "physical uses armor", failures)
	TestAssertions.equal(types.definition(&"fire").defense_stat_id, &"fire_resistance", "fire resistance mapping", failures)

	var duplicate := DamageTypeCatalog.new()
	duplicate.definitions = [types.definition(&"fire"), types.definition(&"fire")]
	TestAssertions.truthy(duplicate.validate(PartyManager.STAT_CATALOG).has("PARTY_FORGE_DAMAGE_ERROR type=fire reason=duplicate id"), "duplicate diagnostic", failures)
	var missing := DamageTypeDefinition.new()
	missing.id = &"radiant"
	missing.display_name = "Radiant"
	missing.keyword_id = &"radiant"
	missing.offense_stat_id = &"missing_damage"
	missing.defense_stat_id = &"missing_resistance"
	missing.mitigation_rule = DamageTypeDefinition.MitigationRule.RESISTANCE
	var custom := DamageTypeCatalog.new()
	custom.definitions = [missing]
	TestAssertions.equal(custom.validate(PartyManager.STAT_CATALOG), PackedStringArray([
		"PARTY_FORGE_DAMAGE_ERROR type=radiant stat=missing_damage reason=unknown offense stat",
		"PARTY_FORGE_DAMAGE_ERROR type=radiant stat=missing_resistance reason=unknown defense stat",
	]), "missing stat diagnostics", failures)
	return failures
```

- [ ] **Step 3: Run the suite and verify RED**

Run:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path 'F:\Projects(root)\Game dev\Projects\party-forge' --script res://tests/test_runner.gd
```

Expected: FAIL because the damage-type classes and `GameCatalog.damage_types` do not exist.

- [ ] **Step 4: Implement the definition and catalog**

Create `scripts/data/damage_type_definition.gd`:

```gdscript
class_name DamageTypeDefinition
extends Resource

enum MitigationRule { ARMOR, RESISTANCE }

@export var id: StringName
@export var display_name: String
@export var keyword_id: StringName
@export var presentation_color := Color.WHITE
@export var offense_stat_id: StringName
@export var defense_stat_id: StringName
@export var mitigation_rule := MitigationRule.RESISTANCE

func validate(stats: StatCatalog) -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty(): errors.append("PARTY_FORGE_DAMAGE_ERROR type=<empty> reason=missing id")
	if display_name.is_empty(): errors.append("PARTY_FORGE_DAMAGE_ERROR type=%s reason=missing display name" % id)
	if keyword_id.is_empty(): errors.append("PARTY_FORGE_DAMAGE_ERROR type=%s reason=missing keyword id" % id)
	var offense := stats.definition(offense_stat_id) if stats != null else null
	var defense := stats.definition(defense_stat_id) if stats != null else null
	if offense == null:
		errors.append("PARTY_FORGE_DAMAGE_ERROR type=%s stat=%s reason=unknown offense stat" % [id, offense_stat_id])
	if defense == null:
		errors.append("PARTY_FORGE_DAMAGE_ERROR type=%s stat=%s reason=unknown defense stat" % [id, defense_stat_id])
	elif mitigation_rule == MitigationRule.RESISTANCE and defense.value_format != StatDefinition.ValueFormat.RATIO_PERCENT:
		errors.append("PARTY_FORGE_DAMAGE_ERROR type=%s stat=%s reason=resistance rule requires ratio stat" % [id, defense_stat_id])
	return errors
```

Create `scripts/data/damage_type_catalog.gd`:

```gdscript
class_name DamageTypeCatalog
extends Resource

@export var definitions: Array[DamageTypeDefinition] = []

func definition(type_id: StringName) -> DamageTypeDefinition:
	for entry: DamageTypeDefinition in definitions:
		if entry != null and entry.id == type_id:
			return entry
	return null

func all() -> Array[DamageTypeDefinition]:
	return definitions.duplicate()

func validate(stats: StatCatalog) -> PackedStringArray:
	var errors := PackedStringArray()
	var seen: Dictionary = {}
	for entry: DamageTypeDefinition in definitions:
		if entry == null:
			errors.append("PARTY_FORGE_DAMAGE_ERROR type=<null> reason=resource failed to load")
			continue
		if seen.has(entry.id):
			errors.append("PARTY_FORGE_DAMAGE_ERROR type=%s reason=duplicate id" % entry.id)
			continue
		seen[entry.id] = true
		errors.append_array(entry.validate(stats))
	return errors
```

- [ ] **Step 5: Author the five initial definitions and load them through GameCatalog**

Create `data/damage_types/core_damage_types.tres` with five `DamageTypeDefinition` subresources using this exact table:

```text
physical  | Physical  | physical_damage  | armor                | ARMOR      | #d8d2c4
fire      | Fire      | fire_damage      | fire_resistance      | RESISTANCE | #ff6b3d
cold      | Cold      | cold_damage      | cold_resistance      | RESISTANCE | #70c8ff
lightning | Lightning | lightning_damage | lightning_resistance | RESISTANCE | #ffe36b
chaos     | Chaos     | chaos_damage     | chaos_resistance     | RESISTANCE | #b56cff
```

Set each `keyword_id` equal to its type ID. Add to `GameCatalog`:

```gdscript
const DAMAGE_TYPES: DamageTypeCatalog = preload("res://data/damage_types/core_damage_types.tres")
var damage_types: DamageTypeCatalog = DAMAGE_TYPES
```

Prepend `damage_types.validate(PartyManager.STAT_CATALOG)` to `GameCatalog.validate()` before validating classes, traits, and enemies. When catalog validation reports an error from a persisted attack, enemy, or type Resource, prefix it with that Resource's `resource_path` so the final line retains `PARTY_FORGE_DAMAGE_ERROR` plus `path=<resource_path>`.

- [ ] **Step 6: Run GREEN, inspect, and commit**

Run:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path 'F:\Projects(root)\Game dev\Projects\party-forge' --editor --quit-after 2
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path 'F:\Projects(root)\Game dev\Projects\party-forge' --script res://tests/test_runner.gd
git diff --check
```

Expected: parser exits 0 and `TEST_SUMMARY: PASS (20 suites)`.

Commit only Task 1 files:

```powershell
git add scripts/data/damage_type_definition.gd scripts/data/damage_type_catalog.gd data/damage_types/core_damage_types.tres scripts/data/game_catalog.gd tests/unit/test_damage_type_catalog.gd
git diff --cached --name-status
git commit -m "feat: add damage type catalog"
```

---

### Task 2: Typed Attack Authoring and Current Attack Resources

**Files:**

- Create: `scripts/data/attack_damage_component.gd`
- Modify: `scripts/data/attack_definition.gd`
- Create: `tools/migrate_typed_combat_data.gd`
- Modify: `data/attacks/fighter_cleave.tres`, `ranger_shot.tres`, `mage_burst.tres`, `cleric_bolt.tres`, `cleric_heal.tres`
- Create: `data/attacks/swarmer_contact.tres`, `spitter_projectile.tres`, `guardian_charge.tres`, `guardian_shockwave.tres`
- Modify: `tests/unit/test_game_catalog.gd`
- Create: `tests/unit/test_attack_damage_data.gd`

**Interfaces:**

- Consumes: `DamageTypeCatalog.definition(type_id)`.
- Produces: `AttackDefinition.normalized_action_tags() -> Array[StringName]`, `is_healing() -> bool`, and `validate(types: DamageTypeCatalog = null) -> PackedStringArray`.

- [ ] **Step 1: Write failing attack-data coverage**

Create `tests/unit/test_attack_damage_data.gd` asserting:

```gdscript
extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var types := GameCatalog.load_defaults().damage_types
	var expected := {
		"res://data/attacks/fighter_cleave.tres": [&"physical", 18.0, [&"area", &"melee"]],
		"res://data/attacks/ranger_shot.tres": [&"physical", 11.0, [&"projectile", &"ranged"]],
		"res://data/attacks/mage_burst.tres": [&"fire", 24.0, [&"area", &"fire", &"projectile"]],
		"res://data/attacks/cleric_bolt.tres": [&"lightning", 8.0, [&"lightning", &"projectile"]],
	}
	for path: String in expected:
		var attack := load(path) as AttackDefinition
		TestAssertions.equal(attack.validate(types), PackedStringArray(), "%s validates" % path, failures)
		TestAssertions.equal(attack.damage_components.size(), 1, "%s one component" % path, failures)
		TestAssertions.equal(attack.damage_components[0].damage_type_id, expected[path][0], "%s type" % path, failures)
		TestAssertions.near(attack.damage_components[0].base_amount, expected[path][1], 0.001, "%s amount" % path, failures)
		TestAssertions.equal(attack.normalized_action_tags(), expected[path][2], "%s tags" % path, failures)
		TestAssertions.truthy(attack.can_crit, "%s can crit" % path, failures)
	var heal := load("res://data/attacks/cleric_heal.tres") as AttackDefinition
	TestAssertions.truthy(heal.is_healing() and heal.damage_components.is_empty() and not heal.can_crit, "heal stays positive-only", failures)
	TestAssertions.near(heal.power, 18.0, 0.001, "heal power preserved", failures)
	for path: String in ["res://data/attacks/swarmer_contact.tres", "res://data/attacks/spitter_projectile.tres", "res://data/attacks/guardian_charge.tres", "res://data/attacks/guardian_shockwave.tres"]:
		TestAssertions.equal((load(path) as AttackDefinition).validate(types), PackedStringArray(), "%s validates" % path, failures)
	return failures
```

- [ ] **Step 2: Run RED**

Run the full test command. Expected: FAIL because components and enemy attack Resources do not exist.

- [ ] **Step 3: Implement component and attack validation**

Create `scripts/data/attack_damage_component.gd`:

```gdscript
class_name AttackDamageComponent
extends Resource

@export var damage_type_id: StringName
@export var base_amount := 0.0

func validate(attack_id: StringName, types: DamageTypeCatalog) -> PackedStringArray:
	var errors := PackedStringArray()
	if damage_type_id.is_empty(): errors.append("PARTY_FORGE_DAMAGE_ERROR attack=%s type=<empty> reason=missing component type" % attack_id)
	elif types == null or types.definition(damage_type_id) == null: errors.append("PARTY_FORGE_DAMAGE_ERROR attack=%s type=%s reason=unknown component type" % [attack_id, damage_type_id])
	if not is_finite(base_amount) or base_amount <= 0.0: errors.append("PARTY_FORGE_DAMAGE_ERROR attack=%s type=%s reason=component amount must be finite and positive" % [attack_id, damage_type_id])
	return errors
```

Replace `AttackDefinition` with the existing delivery fields plus:

```gdscript
enum Kind { MELEE_CLEAVE, PROJECTILE, AREA_PROJECTILE, HEAL, DIRECT, AREA }
const DEFAULT_TYPES: DamageTypeCatalog = preload("res://data/damage_types/core_damage_types.tres")

@export var power := 0.0
@export var damage_components: Array[AttackDamageComponent] = []
@export var action_tags: Array[StringName] = []
@export var can_crit := false

func is_healing() -> bool:
	return kind == Kind.HEAL

func normalized_action_tags() -> Array[StringName]:
	var result: Array[StringName] = []
	for tag: StringName in action_tags:
		if not tag.is_empty() and tag not in result: result.append(tag)
	result.sort()
	return result

func validate(types: DamageTypeCatalog = null) -> PackedStringArray:
	var damage_types := types if types != null else DEFAULT_TYPES
	var errors := PackedStringArray()
	if id.is_empty(): errors.append("PARTY_FORGE_DAMAGE_ERROR attack=<empty> reason=missing id")
	if not is_finite(cooldown) or cooldown <= 0.0: errors.append("PARTY_FORGE_DAMAGE_ERROR attack=%s reason=cooldown must be finite and positive" % id)
	if not is_finite(range) or range <= 0.0: errors.append("PARTY_FORGE_DAMAGE_ERROR attack=%s reason=range must be finite and positive" % id)
	if kind in [Kind.PROJECTILE, Kind.AREA_PROJECTILE] and (not is_finite(projectile_speed) or projectile_speed <= 0.0): errors.append("PARTY_FORGE_DAMAGE_ERROR attack=%s reason=projectile speed must be finite and positive" % id)
	if not is_finite(area_radius) or area_radius < 0.0: errors.append("PARTY_FORGE_DAMAGE_ERROR attack=%s reason=area radius must be finite and nonnegative" % id)
	if normalized_action_tags().size() != action_tags.size(): errors.append("PARTY_FORGE_DAMAGE_ERROR attack=%s reason=empty or duplicate action tag" % id)
	if is_healing():
		if power <= 0.0: errors.append("PARTY_FORGE_DAMAGE_ERROR attack=%s reason=heal power must be positive" % id)
		if not damage_components.is_empty(): errors.append("PARTY_FORGE_DAMAGE_ERROR attack=%s reason=heal has damage components" % id)
		if can_crit: errors.append("PARTY_FORGE_DAMAGE_ERROR attack=%s reason=heal cannot crit" % id)
		return errors
	if damage_components.is_empty(): errors.append("PARTY_FORGE_DAMAGE_ERROR attack=%s reason=damaging attack has no components" % id)
	var seen: Dictionary = {}
	for component: AttackDamageComponent in damage_components:
		if component == null:
			errors.append("PARTY_FORGE_DAMAGE_ERROR attack=%s type=<null> reason=null component" % id)
			continue
		if seen.has(component.damage_type_id): errors.append("PARTY_FORGE_DAMAGE_ERROR attack=%s type=%s reason=duplicate component type" % [id, component.damage_type_id])
		seen[component.damage_type_id] = true
		errors.append_array(component.validate(id, damage_types))
	return errors
```

- [ ] **Step 4: Migrate all current attack Resources from an exact table**

Create `tools/migrate_typed_combat_data.gd` as an idempotent `SceneTree` script. Its table must set these exact fields and save each Resource with `ResourceSaver.save()`:

```text
fighter_cleave      existing path  MELEE_CLEAVE    Physical 18  cooldown .8  range 2.2  area 1.6  tags melee,area             crit true
ranger_shot         existing path  PROJECTILE      Physical 11  cooldown .55 range 11   speed 16   tags projectile,ranged       crit true
mage_burst          existing path  AREA_PROJECTILE Fire     24  cooldown 1.5 range 12   speed 11 area 2.5 tags projectile,area,fire crit true
cleric_bolt         existing path  PROJECTILE      Lightning 8  cooldown 1   range 10   speed 13   tags projectile,lightning   crit true
cleric_heal         existing path  HEAL             no component; power 18; cooldown 3; range 9; tags healing; crit false
swarmer_contact     new path       DIRECT          Physical 8   cooldown .8  range .9              tags melee,contact           crit false
spitter_projectile  new path       PROJECTILE      Physical 10  cooldown 2.2 range 18   speed 6    tags projectile,ranged      crit false
guardian_charge     new path       DIRECT          Physical 22  cooldown 1   range 2.4             tags melee,charge            crit false
guardian_shockwave  new path       AREA            Physical 22  cooldown 1   range 6     area 6     tags area,shockwave          crit false
```

Use this complete migration entry point and encode the table above as the nine dictionaries in `ROWS`:

```gdscript
extends SceneTree

const ROWS: Array[Dictionary] = [
	{"path":"res://data/attacks/fighter_cleave.tres", "id":&"fighter_cleave", "kind":AttackDefinition.Kind.MELEE_CLEAVE, "type":&"physical", "amount":18.0, "power":0.0, "cooldown":0.8, "range":2.2, "speed":0.0, "area":1.6, "tags":[&"melee", &"area"], "crit":true},
	{"path":"res://data/attacks/ranger_shot.tres", "id":&"ranger_shot", "kind":AttackDefinition.Kind.PROJECTILE, "type":&"physical", "amount":11.0, "power":0.0, "cooldown":0.55, "range":11.0, "speed":16.0, "area":0.0, "tags":[&"projectile", &"ranged"], "crit":true},
	{"path":"res://data/attacks/mage_burst.tres", "id":&"mage_burst", "kind":AttackDefinition.Kind.AREA_PROJECTILE, "type":&"fire", "amount":24.0, "power":0.0, "cooldown":1.5, "range":12.0, "speed":11.0, "area":2.5, "tags":[&"projectile", &"area", &"fire"], "crit":true},
	{"path":"res://data/attacks/cleric_bolt.tres", "id":&"cleric_bolt", "kind":AttackDefinition.Kind.PROJECTILE, "type":&"lightning", "amount":8.0, "power":0.0, "cooldown":1.0, "range":10.0, "speed":13.0, "area":0.0, "tags":[&"projectile", &"lightning"], "crit":true},
	{"path":"res://data/attacks/cleric_heal.tres", "id":&"cleric_heal", "kind":AttackDefinition.Kind.HEAL, "type":&"", "amount":0.0, "power":18.0, "cooldown":3.0, "range":9.0, "speed":0.0, "area":0.0, "tags":[&"healing"], "crit":false},
	{"path":"res://data/attacks/swarmer_contact.tres", "id":&"swarmer_contact", "kind":AttackDefinition.Kind.DIRECT, "type":&"physical", "amount":8.0, "power":0.0, "cooldown":0.8, "range":0.9, "speed":0.0, "area":0.0, "tags":[&"melee", &"contact"], "crit":false},
	{"path":"res://data/attacks/spitter_projectile.tres", "id":&"spitter_projectile", "kind":AttackDefinition.Kind.PROJECTILE, "type":&"physical", "amount":10.0, "power":0.0, "cooldown":2.2, "range":18.0, "speed":6.0, "area":0.0, "tags":[&"projectile", &"ranged"], "crit":false},
	{"path":"res://data/attacks/guardian_charge.tres", "id":&"guardian_charge", "kind":AttackDefinition.Kind.DIRECT, "type":&"physical", "amount":22.0, "power":0.0, "cooldown":1.0, "range":2.4, "speed":0.0, "area":0.0, "tags":[&"melee", &"charge"], "crit":false},
	{"path":"res://data/attacks/guardian_shockwave.tres", "id":&"guardian_shockwave", "kind":AttackDefinition.Kind.AREA, "type":&"physical", "amount":22.0, "power":0.0, "cooldown":1.0, "range":6.0, "speed":0.0, "area":6.0, "tags":[&"area", &"shockwave"], "crit":false},
]

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/attacks"))
	for row: Dictionary in ROWS:
		var attack: AttackDefinition
		if ResourceLoader.exists(row["path"]): attack = load(row["path"]) as AttackDefinition
		else: attack = AttackDefinition.new()
		attack.id = row["id"]
		attack.kind = row["kind"]
		attack.power = row["power"]
		attack.cooldown = row["cooldown"]
		attack.range = row["range"]
		attack.projectile_speed = row["speed"]
		attack.area_radius = row["area"]
		attack.action_tags.assign(row["tags"])
		attack.can_crit = row["crit"]
		attack.damage_components.clear()
		if not StringName(row["type"]).is_empty():
			var component := AttackDamageComponent.new()
			component.damage_type_id = row["type"]
			component.base_amount = row["amount"]
			attack.damage_components.append(component)
		var error := ResourceSaver.save(attack, row["path"])
		if error != OK:
			push_error("PARTY_FORGE_DAMAGE_ERROR path=%s reason=save failed code=%d" % [row["path"], error])
			quit(1)
			return
	print("PARTY_FORGE_TYPED_ATTACK_DATA_SAVED count=%d" % ROWS.size())
	quit(0)
```

- [ ] **Step 5: Update generated-value tests and run the migration**

In `test_game_catalog.gd`, replace damaging `power` assertions with `damage_components[0]` type/amount assertions and keep Cleric heal power at `18.0`.

Run:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path 'F:\Projects(root)\Game dev\Projects\party-forge' --editor --quit-after 2
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path 'F:\Projects(root)\Game dev\Projects\party-forge' --script res://tools/migrate_typed_combat_data.gd
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path 'F:\Projects(root)\Game dev\Projects\party-forge' --script res://tests/test_runner.gd
```

Expected: migration prints count 9 and tests print `TEST_SUMMARY: PASS (21 suites)`.

- [ ] **Step 6: Commit**

Stage only the files listed for Task 2 and commit:

```powershell
git diff --cached --check
git commit -m "feat: author typed attack damage"
```

---

### Task 3: Seeded RNG and Immutable Runtime Contracts

**Files:**

- Create: `scripts/combat/combat_rng.gd`
- Create: `scripts/combat/prepared_damage_component.gd`
- Create: `scripts/combat/damage_packet.gd`
- Create: `scripts/combat/damage_result.gd`
- Create: `scripts/combat/combatant_adapter.gd`
- Modify feature hunks only: `scripts/game/game_run.gd`
- Create: `tests/unit/test_combat_rng.gd`

**Interfaces:**

- Produces: `CombatRng.new(seed_value: int, prescribed_draws: Array[float])`, `roll(chance: float) -> Dictionary`, `DamagePacket.create(source_value: CombatantAdapter, attack_value: StringName, tags: Array[StringName], crit_allowed: bool, crit_result: bool, draw: float, multiplier: float, steal_rate: float, prepared: Array[PreparedDamageComponent]) -> DamagePacket`, and `CombatantAdapter.stat_value(stat_id: StringName, fallback: float) -> float`.

- [ ] **Step 1: Write RED tests for draw boundaries, reseeding, defensive copies, and run ownership**

The new suite must assert this contract:

```gdscript
var rng := CombatRng.new(77, [0.20, 0.80])
TestAssertions.equal(rng.roll(0.0), {"consumed": false, "draw": -1.0, "success": false}, "zero chance", failures)
TestAssertions.equal(rng.roll(1.0), {"consumed": false, "draw": -1.0, "success": true}, "certain chance", failures)
TestAssertions.equal(rng.roll(0.25), {"consumed": true, "draw": 0.20, "success": true}, "draw succeeds", failures)
TestAssertions.equal(rng.roll(0.25), {"consumed": true, "draw": 0.80, "success": false}, "draw fails", failures)
var run := GameRun.new()
run.configure_seed(1337)
TestAssertions.truthy(run.combat_rng is CombatRng, "run owns combat RNG", failures)
```

Also construct a packet with a component array, mutate the caller's array/component, and assert the packet still exposes its original values.

- [ ] **Step 2: Run RED**

Expected: FAIL because runtime contract classes do not exist.

- [ ] **Step 3: Implement CombatRng**

Create:

```gdscript
class_name CombatRng
extends RefCounted

var _rng := RandomNumberGenerator.new()
var _prescribed: Array[float] = []
var draw_count := 0

func _init(seed_value: int = 0, prescribed_draws: Array[float] = []) -> void:
	reseed(seed_value, prescribed_draws)

func reseed(seed_value: int, prescribed_draws: Array[float] = []) -> void:
	_rng.seed = seed_value
	_prescribed.clear()
	for draw: float in prescribed_draws:
		if is_finite(draw) and draw >= 0.0 and draw < 1.0: _prescribed.append(draw)
		else: push_error("PARTY_FORGE_DAMAGE_ERROR rng_draw=%s reason=draw must be finite and in [0,1)" % draw)
	draw_count = 0

func roll(chance: float) -> Dictionary:
	if not is_finite(chance):
		push_error("PARTY_FORGE_DAMAGE_ERROR chance=%s reason=chance must be finite" % chance)
		return {"consumed": false, "draw": -1.0, "success": false}
	var finalized := clampf(chance, 0.0, 1.0)
	if finalized <= 0.0: return {"consumed": false, "draw": -1.0, "success": false}
	if finalized >= 1.0: return {"consumed": false, "draw": -1.0, "success": true}
	var draw := _prescribed.pop_front() if not _prescribed.is_empty() else _rng.randf()
	draw_count += 1
	return {"consumed": true, "draw": draw, "success": draw < finalized}
```

- [ ] **Step 4: Implement runtime value objects**

Create `scripts/combat/prepared_damage_component.gd`:

```gdscript
class_name PreparedDamageComponent
extends RefCounted

var damage_type_id: StringName
var authored_amount := 0.0
var global_scaled := 0.0
var typed_scaled := 0.0
var post_crit := 0.0

func _init(type_id: StringName = &"", authored: float = 0.0, global_amount: float = 0.0, typed_amount: float = 0.0, critical_amount: float = 0.0) -> void:
	damage_type_id = type_id
	authored_amount = authored
	global_scaled = global_amount
	typed_scaled = typed_amount
	post_crit = critical_amount

func copy() -> PreparedDamageComponent:
	return PreparedDamageComponent.new(damage_type_id, authored_amount, global_scaled, typed_scaled, post_crit)
```

Create `scripts/combat/combatant_adapter.gd`:

```gdscript
class_name CombatantAdapter
extends RefCounted

var actor: Node3D
var combatant_id: StringName
var team_id := 0
var available := true
var health: HealthComponent
var stats: ResolvedStatSnapshot
var incoming_provider: Callable

func _init(actor_value: Node3D = null, id_value: StringName = &"", team_value: int = 0, health_value: HealthComponent = null, stats_value: ResolvedStatSnapshot = null, available_value: bool = true, incoming_value: Callable = Callable()) -> void:
	actor = actor_value
	combatant_id = id_value
	team_id = team_value
	health = health_value
	stats = stats_value
	available = available_value
	incoming_provider = incoming_value

func stat_value(stat_id: StringName, fallback: float = 0.0) -> float:
	return stats.value(stat_id, fallback) if stats != null else fallback

func incoming_damage_multiplier(packet: DamagePacket) -> float:
	if incoming_provider.is_valid(): return maxf(0.0, float(incoming_provider.call(packet)))
	return 1.0
```

Create `scripts/combat/damage_packet.gd`:

```gdscript
class_name DamagePacket
extends RefCounted

var valid := false
var error_reason: String
var source: CombatantAdapter
var source_id: StringName
var source_team_id := 0
var attack_id: StringName
var can_crit := false
var critical := false
var crit_draw := -1.0
var crit_multiplier := 1.0
var life_steal_rate := 0.0
var _action_tags: Array[StringName] = []
var _components: Array[PreparedDamageComponent] = []
var action_tags: Array[StringName]:
	get: return _action_tags.duplicate()
var components: Array[PreparedDamageComponent]:
	get:
		var result: Array[PreparedDamageComponent] = []
		for component: PreparedDamageComponent in _components: result.append(component.copy())
		return result

static func create(source_value: CombatantAdapter, attack_value: StringName, tags: Array[StringName], crit_allowed: bool, crit_result: bool, draw: float, multiplier: float, steal_rate: float, prepared: Array[PreparedDamageComponent]) -> DamagePacket:
	var packet := DamagePacket.new()
	packet.valid = true
	packet.source = source_value
	packet.source_id = source_value.combatant_id
	packet.source_team_id = source_value.team_id
	packet.attack_id = attack_value
	packet.can_crit = crit_allowed
	packet.critical = crit_result
	packet.crit_draw = draw
	packet.crit_multiplier = multiplier
	packet.life_steal_rate = steal_rate
	packet._action_tags = tags.duplicate()
	for component: PreparedDamageComponent in prepared: packet._components.append(component.copy())
	return packet

static func invalid(reason: String, source_value: CombatantAdapter = null, attack_value: StringName = &"") -> DamagePacket:
	var packet := DamagePacket.new()
	packet.error_reason = reason
	packet.source = source_value
	packet.source_id = source_value.combatant_id if source_value != null else &""
	packet.source_team_id = source_value.team_id if source_value != null else 0
	packet.attack_id = attack_value
	return packet

func source_is_available_for_life_steal() -> bool:
	return source != null and source.health != null and is_instance_valid(source.health) and not source.health.is_dead and not source.health.is_downed
```

Create `scripts/combat/damage_result.gd`:

```gdscript
class_name DamageResult
extends RefCounted

var valid := false
var error_reason: String
var source_id: StringName
var attack_id: StringName
var target_id: StringName
var action_tags: Array[StringName] = []
var can_crit := false
var critical := false
var crit_draw := -1.0
var crit_multiplier := 1.0
var dodge_chance := 0.0
var dodge_draw := -1.0
var dodged := false
var block_chance := 0.0
var block_draw := -1.0
var blocked := false
var block_effectiveness := 0.0
var component_breakdowns: Array[Dictionary] = []
var incoming_multiplier := 1.0
var incoming_prevented := 0.0
var total_post_mitigation := 0.0
var damage_before_block := 0.0
var block_prevented := 0.0
var final_damage := 0.0
var actual_health_removed := 0.0
var life_steal_rate := 0.0
var life_steal_restored := 0.0
```

- [ ] **Step 5: Give GameRun one reseedable combat RNG**

Add feature hunks without staging the pre-existing formatting diff:

```gdscript
var run_seed := 1337
var combat_rng := CombatRng.new(run_seed)

func configure_seed(seed_value: int) -> void:
	run_seed = seed_value
	combat_rng.reseed(run_seed)
```

- [ ] **Step 6: Run GREEN and commit**

Expected: `TEST_SUMMARY: PASS (22 suites)`. Verify the cached diff for `game_run.gd` contains only the three feature hunks, then commit `feat: add deterministic combat contracts`.

---

### Task 4: Final-Damage Health and Continuous Recovery

**Files:**

- Modify: `scripts/combat/health_component.gd`
- Create: `scripts/combat/recovery_controller.gd`
- Modify: `scripts/characters/party_actor.gd`
- Modify: `scripts/enemies/enemy_actor.gd`
- Modify: `tests/unit/test_health_component.gd`
- Modify: `tests/unit/test_final_review.gd`
- Create: `tests/unit/test_recovery_controller.gd`

**Interfaces:**

- Produces: `HealthComponent.apply_damage(final_damage) -> float`, unchanged `heal(amount) -> float`, and `RecoveryController.configure(health, regeneration_provider)` / `advance(delta)`.

- [ ] **Step 1: Change the health tests first**

Replace armor expectations with final-damage behavior:

```gdscript
var companion := HealthComponent.new()
companion.configure(100.0, false, 8.0, 0.5)
TestAssertions.near(companion.apply_damage(13.0), 13.0, 0.001, "final damage is exact", failures)
TestAssertions.near(companion.apply_damage(500.0), 87.0, 0.001, "overkill reports actual removal", failures)
TestAssertions.truthy(companion.is_downed, "companion is downed", failures)
```

Create recovery tests for `10.0/s * 0.25 = 2.5`, four quarter-steps equaling one full step, full-health clamping, no recovery while downed/dead, and recovery after revive.

- [ ] **Step 2: Run RED**

Expected: FAIL because `apply_damage`, the new configure signature, and `RecoveryController` do not exist.

- [ ] **Step 3: Refactor HealthComponent**

Remove `armor` and the armor argument. Keep all signals and revive logic. Implement:

```gdscript
func configure(maximum: float, leader: bool, revive_seconds: float, revive_fraction: float, terminal_death: bool = false) -> void:
	max_health = maxf(maximum, 1.0)
	current_health = max_health
	is_leader = leader
	death_is_terminal = terminal_death
	revive_delay = maxf(revive_seconds, 0.1)
	revive_health_fraction = clampf(revive_fraction, 0.01, 1.0)
	is_downed = false
	is_dead = false

func apply_damage(final_damage: float) -> float:
	if is_dead or is_downed or not is_finite(final_damage) or final_damage <= 0.0:
		return 0.0
	var previous := current_health
	current_health = maxf(0.0, current_health - final_damage)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		if is_leader or death_is_terminal:
			is_dead = true
			died.emit()
		else:
			is_downed = true
			revive_remaining = revive_delay
			downed.emit()
	return previous - current_health

func take_damage(final_damage: float) -> float:
	return apply_damage(final_damage)
```

The temporary `take_damage` alias keeps intermediate commits green and is removed in Task 8.

- [ ] **Step 4: Implement RecoveryController**

```gdscript
class_name RecoveryController
extends Node

var health: HealthComponent
var regeneration_provider: Callable

func configure(target_health: HealthComponent, provider: Callable) -> void:
	health = target_health
	regeneration_provider = provider

func advance(delta: float) -> float:
	if health == null or health.is_dead or health.is_downed or delta <= 0.0 or health.current_health >= health.max_health:
		return 0.0
	var rate := maxf(0.0, float(regeneration_provider.call())) if regeneration_provider.is_valid() else 0.0
	return health.heal(rate * delta)
```

- [ ] **Step 5: Update every configure call and existing direct health test**

Update party/enemy actors and all tests from `configure(max, armor, leader, delay, fraction, terminal)` to `configure(max, leader, delay, fraction, terminal)`. Replace test-only direct damage with `apply_damage`. Do not migrate gameplay delivery yet; the temporary alias keeps those paths working.

- [ ] **Step 6: Run GREEN and commit**

Expected: `TEST_SUMMARY: PASS (23 suites)`. Commit `refactor: separate health from mitigation`.

---

### Task 5: Central Damage Resolver and Full Calculation Evidence

**Files:**

- Create: `scripts/combat/damage_resolver.gd`
- Create: `tests/unit/test_damage_resolver.gd`

**Interfaces:**

- Consumes: validated `AttackDefinition`, source/target `CombatantAdapter`, `CombatRng`, and `DamageTypeCatalog`.
- Produces: `action_tags_for(attack) -> Array[StringName]`, `prepare(attack, source, rng, types) -> DamagePacket`, and `resolve(packet, target, rng, types) -> DamageResult`.

- [ ] **Step 1: Write the resolver matrix as failing tests**

Cover these exact cases with prescribed draws and real `HealthComponent` instances:

```text
100 Physical, damage 1.20, physical_damage 1.50 => prepared 180
180 Physical against 80 armor => 100 health damage
100 Fire against +75% resistance => 25
100 Fire against -100% resistance => 200
60 Physical + 40 Fire against 50 armor and 25% fire resistance => 40 + 30 = 70
50% crit at 2.0 multiplier with draw .20 => every component doubles
25% dodge with draw .10 => zero damage and no block draw
50% block at 60% effectiveness after mitigation => 40% remains
Vanguard incoming multiplier .88 applies after mitigation and before block
30 final damage against 10 remaining health => actual removal 10
20% life steal from actual removal 10 => requested 2, clamped by source health
unknown type, unavailable target, same-team target, and non-finite amount => invalid result, no health/RNG change
```

Add a custom `radiant` definition using the RESISTANCE rule and assert it resolves without changing resolver code.

- [ ] **Step 2: Run RED**

Expected: FAIL because `DamageResolver` does not exist.

- [ ] **Step 3: Implement preparation**

Create `scripts/combat/damage_resolver.gd` and implement its preparation half exactly:

```gdscript
class_name DamageResolver
extends RefCounted

static func action_tags_for(attack: AttackDefinition) -> Array[StringName]:
	var tags: Array[StringName] = []
	if attack != null:
		tags = attack.normalized_action_tags()
		for component: AttackDamageComponent in attack.damage_components:
			if component != null and not component.damage_type_id.is_empty() and component.damage_type_id not in tags:
				tags.append(component.damage_type_id)
	tags.sort()
	return tags

static func prepare(attack: AttackDefinition, source: CombatantAdapter, rng: CombatRng, types: DamageTypeCatalog) -> DamagePacket:
	if attack == null: return _invalid_packet("attack=<null> source=<unknown> reason=missing attack", source)
	if source == null: return _invalid_packet("attack=%s source=<null> reason=missing source provider" % attack.id, null, attack.id)
	if source.combatant_id.is_empty(): return _invalid_packet("attack=%s source=<empty> reason=missing combatant identity" % attack.id, source, attack.id)
	if rng == null: return _invalid_packet("attack=%s source=%s reason=missing combat RNG" % [attack.id, source.combatant_id], source, attack.id)
	if types == null: return _invalid_packet("attack=%s source=%s reason=missing damage catalog" % [attack.id, source.combatant_id], source, attack.id)
	var validation := attack.validate(types)
	if not validation.is_empty(): return _invalid_packet(String(validation[0]).trim_prefix("PARTY_FORGE_DAMAGE_ERROR "), source, attack.id)
	if attack.is_healing(): return _invalid_packet("attack=%s source=%s reason=healing cannot create damage packet" % [attack.id, source.combatant_id], source, attack.id)

	var tags := action_tags_for(attack)
	var crit_chance := source.stat_value(&"crit_chance", 0.0) if attack.can_crit else 0.0
	var crit_roll := rng.roll(crit_chance)
	var critical := bool(crit_roll["success"])
	var crit_multiplier := maxf(1.0, source.stat_value(&"crit_multiplier", 1.5))
	var prepared: Array[PreparedDamageComponent] = []
	for component: AttackDamageComponent in attack.damage_components:
		var type_definition := types.definition(component.damage_type_id)
		var global_scaled := component.base_amount * source.stat_value(&"damage", 1.0)
		var typed_scaled := global_scaled * source.stat_value(type_definition.offense_stat_id, 1.0)
		var post_crit := typed_scaled * crit_multiplier if critical else typed_scaled
		if not is_finite(post_crit): return _invalid_packet("attack=%s source=%s type=%s reason=non-finite prepared amount" % [attack.id, source.combatant_id, component.damage_type_id], source, attack.id)
		prepared.append(PreparedDamageComponent.new(component.damage_type_id, component.base_amount, global_scaled, typed_scaled, post_crit))
	return DamagePacket.create(source, attack.id, tags, attack.can_crit, critical, float(crit_roll["draw"]), crit_multiplier, source.stat_value(&"life_steal", 0.0), prepared)
```

No other attacker scaling belongs in delivery scripts.

- [ ] **Step 4: Implement per-defender resolution**

Append the per-defender half below. It records every intermediate value in `DamageResult.component_breakdowns`:

```gdscript
static func resolve(packet: DamagePacket, target: CombatantAdapter, rng: CombatRng, types: DamageTypeCatalog) -> DamageResult:
	var result := _base_result(packet, target)
	var invalid_reason := _resolution_error(packet, target, rng, types)
	if not invalid_reason.is_empty():
		result.error_reason = invalid_reason
		if packet == null or packet.valid: push_error(invalid_reason)
		return result
	result.valid = true
	result.dodge_chance = target.stat_value(&"dodge_chance", 0.0)
	var dodge := rng.roll(result.dodge_chance)
	result.dodge_draw = float(dodge["draw"])
	result.dodged = bool(dodge["success"])
	if result.dodged: return result

	for prepared: PreparedDamageComponent in packet.components:
		var definition := types.definition(prepared.damage_type_id)
		var defense := target.stat_value(definition.defense_stat_id, 0.0)
		var mitigated := prepared.post_crit * 100.0 / (100.0 + maxf(0.0, defense)) if definition.mitigation_rule == DamageTypeDefinition.MitigationRule.ARMOR else prepared.post_crit * (1.0 - defense)
		mitigated = maxf(0.0, mitigated)
		result.total_post_mitigation += mitigated
		result.component_breakdowns.append({
			"damage_type_id": prepared.damage_type_id,
			"authored_amount": prepared.authored_amount,
			"global_scaled": prepared.global_scaled,
			"typed_scaled": prepared.typed_scaled,
			"post_crit": prepared.post_crit,
			"defense_stat_id": definition.defense_stat_id,
			"defense_value": defense,
			"post_mitigation": mitigated,
		})

	result.incoming_multiplier = target.incoming_damage_multiplier(packet)
	result.damage_before_block = result.total_post_mitigation * result.incoming_multiplier
	result.incoming_prevented = result.total_post_mitigation - result.damage_before_block
	result.block_chance = target.stat_value(&"block_chance", 0.0)
	var block := rng.roll(result.block_chance)
	result.block_draw = float(block["draw"])
	result.blocked = bool(block["success"])
	result.block_effectiveness = target.stat_value(&"block_effectiveness", 0.5) if result.blocked else 0.0
	result.final_damage = maxf(0.0, result.damage_before_block * (1.0 - result.block_effectiveness))
	result.block_prevented = result.damage_before_block - result.final_damage
	result.actual_health_removed = target.health.apply_damage(result.final_damage)
	result.life_steal_rate = packet.life_steal_rate
	if packet.source_is_available_for_life_steal() and result.actual_health_removed > 0.0:
		result.life_steal_restored = packet.source.health.heal(result.actual_health_removed * packet.life_steal_rate)
	return result

static func _base_result(packet: DamagePacket, target: CombatantAdapter) -> DamageResult:
	var result := DamageResult.new()
	if packet != null:
		result.source_id = packet.source_id
		result.attack_id = packet.attack_id
		result.action_tags = packet.action_tags
		result.can_crit = packet.can_crit
		result.critical = packet.critical
		result.crit_draw = packet.crit_draw
		result.crit_multiplier = packet.crit_multiplier
	if target != null: result.target_id = target.combatant_id
	return result

static func _resolution_error(packet: DamagePacket, target: CombatantAdapter, rng: CombatRng, types: DamageTypeCatalog) -> String:
	if packet == null: return "PARTY_FORGE_DAMAGE_ERROR attack=<null> source=<null> target=<unknown> reason=missing packet"
	if not packet.valid: return packet.error_reason
	if target == null: return "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=<null> reason=missing target provider" % [packet.attack_id, packet.source_id]
	if target.combatant_id.is_empty(): return "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=<empty> reason=missing combatant identity" % [packet.attack_id, packet.source_id]
	if not target.available or target.health == null: return "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=%s reason=target unavailable" % [packet.attack_id, packet.source_id, target.combatant_id]
	if packet.source_team_id == target.team_id: return "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=%s reason=team-invalid target" % [packet.attack_id, packet.source_id, target.combatant_id]
	if rng == null: return "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=%s reason=missing combat RNG" % [packet.attack_id, packet.source_id, target.combatant_id]
	if types == null: return "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=%s reason=missing damage catalog" % [packet.attack_id, packet.source_id, target.combatant_id]
	for component: PreparedDamageComponent in packet.components:
		if types.definition(component.damage_type_id) == null: return "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=%s type=%s reason=unknown runtime type" % [packet.attack_id, packet.source_id, target.combatant_id, component.damage_type_id]
		if not is_finite(component.post_crit) or component.post_crit < 0.0: return "PARTY_FORGE_DAMAGE_ERROR attack=%s source=%s target=%s type=%s reason=invalid runtime amount" % [packet.attack_id, packet.source_id, target.combatant_id, component.damage_type_id]
	return ""

static func _invalid_packet(reason: String, source: CombatantAdapter = null, attack_id: StringName = &"") -> DamagePacket:
	var message := "PARTY_FORGE_DAMAGE_ERROR %s" % reason
	push_error(message)
	return DamagePacket.invalid(message, source, attack_id)
```

Invalid results call `push_error()` once with their stable `PARTY_FORGE_DAMAGE_ERROR` reason, consume no defender RNG, and change no health.

- [ ] **Step 5: Run GREEN and commit**

Expected: `TEST_SUMMARY: PASS (24 suites)`. Commit `feat: resolve typed combat damage`.

---

### Task 6: Party Snapshots, Adapters, Healing, Projectiles, and Areas

**Files:**

- Modify: `scripts/party/party_manager.gd`
- Modify: `scripts/characters/party_actor.gd`
- Modify: `scripts/combat/combat_modifiers.gd`
- Modify: `scripts/combat/attack_executor.gd`
- Modify: `scripts/combat/projectile.gd`
- Modify: `scripts/combat/area_burst.gd`
- Modify: `tests/unit/test_member_stats.gd`
- Modify: `tests/unit/test_attack_execution.gd`
- Modify: `tests/unit/test_final_review.gd`

**Interfaces:**

- Produces: `PartyManager.configure_combat(rng, types)`, `stats_for_action(member_id, tags)`, and `PartyActor.get_combat_adapter(tags)`.

- [ ] **Step 1: Add failing action-cache and party-delivery tests**

Assert that `stats_for_action(id, [&"projectile", &"bow"])` applies tag-required modifiers, normalizes duplicate/reordered tags to the same cached object, differs from `stats_for(id)`, and is invalidated with the context-free cache.

Update attack tests to assert:

- Fighter cleave prepares one packet and damages two targets.
- One prescribed crit affects both cleave targets.
- Prescribed defender draws produce independent dodge/block outcomes in stable combatant-ID order.
- Party projectile stores `packet`, not `damage`, and preserves prepared values after the source gains a modifier.
- Mage area uses the projectile's original packet for every in-radius target and deduplicates repeated actors.
- Multi-target life steal sums only the actual health removed from targets that were not dodged or blocked to zero.
- Cleric heal still restores `18 * healing_power` and creates no packet.

- [ ] **Step 2: Run RED**

Expected: the new action APIs and packet delivery contracts fail.

- [ ] **Step 3: Add normalized action snapshots and dependencies to PartyManager**

Implement:

```gdscript
var combat_rng: CombatRng
var damage_types: DamageTypeCatalog
var _action_stat_cache: Dictionary = {}

func configure_combat(rng: CombatRng, types: DamageTypeCatalog) -> void:
	combat_rng = rng
	damage_types = types

func stats_for_action(member_id: int, action_tags: Array[StringName]) -> ResolvedStatSnapshot:
	var member := member_by_id(member_id)
	if member == null: return null
	var normalized := _normalized_tags(action_tags)
	var parts := PackedStringArray()
	for tag: StringName in normalized: parts.append(String(tag))
	var key := "%d|%s" % [member_id, ",".join(parts)]
	if _action_stat_cache.has(key): return _action_stat_cache[key] as ResolvedStatSnapshot
	var snapshot := StatResolver.resolve(member_id, STAT_CATALOG, member.class_definition.stat_base_values(), member.capability_tags, _sources_for(member), normalized, _stat_revision)
	_action_stat_cache[key] = snapshot
	return snapshot
```

Clear affected action keys in `_invalidate_member()` and all action keys in `_invalidate_all_members()`.

- [ ] **Step 4: Expose the party adapter and recovery**

`PartyActor.get_combat_adapter(tags)` builds ID `party:<member_id>`, current availability, health, `party_manager.stats_for_action(member_id, tags)`, and a callable returning `party_manager.incoming_damage_multiplier(self)`. Configure one `RecoveryController` with a callable reading current context-free `health_regeneration`, and call `recovery.advance(delta)` from the existing unpaused `_process` path before advancing attacks. Remove Vanguard multiplication from `receive_damage`; it now exists only in the adapter.

- [ ] **Step 5: Replace scalar party delivery**

`AttackExecutor.execute()` obtains the source adapter using `DamageResolver.action_tags_for(attack)` and calls `DamageResolver.prepare()`. For healing it skips preparation and calls:

```gdscript
target_health.heal(definition.power * source_adapter.stat_value(&"healing_power", 1.0))
```

Melee sorts eligible target adapters by `combatant_id` and resolves the same packet once per deduplicated actor. Projectiles store the packet plus resolver dependencies. Area bursts receive the same packet and resolve independently against sorted, deduplicated adapters.

Keep movement/timing values in `CombatModifiers`, but remove `power_multiplier`; damaging power now exists only in `DamageResolver` and healing reads `healing_power` directly.

- [ ] **Step 6: Run GREEN and commit**

Expected: all 24 suites PASS. A source search shows party delivery no longer calls `receive_damage` or carries scalar `damage`. Commit `refactor: route party attacks through typed damage`.

---

### Task 7: Enemy Attack Data, Stable IDs, and Shared Resolution

**Files:**

- Modify: `scripts/data/enemy_definition.gd`
- Modify: `data/enemies/swarmer.tres`, `spitter.tres`, `forge_guardian.tres`
- Modify: `scripts/data/game_catalog.gd`
- Modify: `scripts/enemies/enemy_actor.gd`
- Modify: `scripts/enemies/swarmer.gd`, `spitter.gd`, `enemy_projectile.gd`, `forge_guardian.gd`
- Modify: `scripts/game/spawn_director.gd`
- Modify feature hunks only: `scripts/game/main.gd`
- Modify: `tests/unit/test_spawn_schedule.gd`, `test_game_catalog.gd`, `test_main_wiring.gd`, `test_final_review.gd`
- Create: `tests/unit/test_enemy_typed_combat.gd`

**Interfaces:**

- Produces: `EnemyDefinition.attack_by_id(id)`, `EnemyActor.configure_combat(id, rng, types)`, `get_combat_adapter(tags)`, `prepare_attack(id)`, and `resolve_attack(packet, target)`.

- [ ] **Step 1: Write failing enemy migration tests**

Test exact attack links:

```text
swarmer        attacks [swarmer_contact]                    stat_overrides {}
spitter        attacks [spitter_projectile]                 stat_overrides {}
forge_guardian attacks [guardian_charge, guardian_shockwave] stat_overrides {}
```

Assert duplicate/missing attack IDs, unknown stat overrides, non-finite overrides, and behavior capability mismatches return `PARTY_FORGE_DAMAGE_ERROR` messages. Spawn two enemies and assert IDs `enemy:1` and `enemy:2`. Use prescribed draws to prove enemy Physical attacks use the same armor/dodge/block resolver as party hits.

- [ ] **Step 2: Run RED**

Expected: enemy definitions still expose `contact_damage`, no stable combat IDs exist, and enemy scripts bypass the resolver.

- [ ] **Step 3: Refactor EnemyDefinition and Resources**

Replace `contact_damage` with:

```gdscript
@export var stat_overrides: Dictionary[StringName, float] = {}
@export var attacks: Array[AttackDefinition] = []

func attack_by_id(attack_id: StringName) -> AttackDefinition:
	for attack: AttackDefinition in attacks:
		if attack != null and attack.id == attack_id: return attack
	return null
```

`validate(types, stats)` validates unique attack IDs, every attack, finite known overrides, and required IDs by behavior: Swarmer requires `swarmer_contact`, Spitter requires `spitter_projectile`, and Guardian requires `guardian_charge` plus `guardian_shockwave`. Update `GameCatalog.validate()` to pass both catalogs.

Use these exact validation additions after the existing ID/health/speed checks:

```gdscript
func validate(types: DamageTypeCatalog = null, stats: StatCatalog = null) -> PackedStringArray:
	var errors := PackedStringArray()
	if id.is_empty(): errors.append("enemy id is empty")
	if max_health <= 0.0: errors.append("enemy %s health must be positive" % id)
	if move_speed <= 0.0: errors.append("enemy %s speed must be positive" % id)
	var seen: Dictionary = {}
	for attack: AttackDefinition in attacks:
		if attack == null:
			errors.append("PARTY_FORGE_DAMAGE_ERROR enemy=%s attack=<null> reason=null attack" % id)
			continue
		if seen.has(attack.id): errors.append("PARTY_FORGE_DAMAGE_ERROR enemy=%s attack=%s reason=duplicate attack id" % [id, attack.id])
		seen[attack.id] = true
		errors.append_array(attack.validate(types))
	for stat_id: StringName in stat_overrides:
		var amount := float(stat_overrides[stat_id])
		if stats == null or stats.definition(stat_id) == null: errors.append("PARTY_FORGE_DAMAGE_ERROR enemy=%s stat=%s reason=unknown stat override" % [id, stat_id])
		elif not is_finite(amount): errors.append("PARTY_FORGE_DAMAGE_ERROR enemy=%s stat=%s reason=non-finite stat override" % [id, stat_id])
	var required: Array[StringName] = []
	match behavior:
		Behavior.SWARMER: required = [&"swarmer_contact"]
		Behavior.SPITTER: required = [&"spitter_projectile"]
		Behavior.FORGE_GUARDIAN: required = [&"guardian_charge", &"guardian_shockwave"]
	for required_id: StringName in required:
		if attack_by_id(required_id) == null: errors.append("PARTY_FORGE_DAMAGE_ERROR enemy=%s attack=%s reason=required behavior attack missing" % [id, required_id])
	return errors
```

Run the migration tool after extending it to link the exact attack Resources above and remove serialized `contact_damage` from all three enemy `.tres` files.

- [ ] **Step 4: Add enemy adapters and deterministic spawn identities**

`EnemyActor.configure_combat(sequence_id, rng, types)` stores `enemy:<sequence_id>`, dependencies, and configures recovery. Its adapter resolves defaults/overrides through `StatResolver` and uses incoming multiplier `1.0`.

In `SpawnDirector`, reset `_enemy_sequence = 0` in `configure()`, increment only after a valid enemy is instantiated, and call `enemy.configure_combat(_enemy_sequence, combat_rng, damage_types)`. Extend `configure()` with explicit `CombatRng` and `DamageTypeCatalog` arguments; do not create fallback RNGs.

- [ ] **Step 5: Route every enemy behavior through stable attack IDs**

- Swarmer prepares `swarmer_contact` when its cooldown permits and resolves it against the target adapter.
- Spitter prepares `spitter_projectile` at firing time; `EnemyProjectile` carries the packet and resolves at impact.
- Guardian prepares one `guardian_charge` packet when charge execution begins, clears a per-charge hit-ID set, and resolves that packet once against each party adapter entering the attack's `range` during `_move_charge()`. Shockwave prepares one `guardian_shockwave` packet and resolves it against sorted party adapters in its authored radius.
- Summon remains nondamaging.
- `EnemyProjectile` retains `SPEED := 6.0` and `MAX_LIFETIME := 3.0` unchanged.

- [ ] **Step 6: Wire the one run seed on main without staging pre-existing formatting**

Add `RUN_SEED := 1337`. Before actors attack, call:

```gdscript
game_run.configure_seed(RUN_SEED)
party_manager.configure_combat(game_run.combat_rng, catalog.damage_types)
spawn_director.configure(RUN_SEED, leader, experience_system, markers, camera, get_node("Enemies"), get_node("Effects"), _pickup_multiplier(), game_run.combat_rng, catalog.damage_types)
```

Configure the boss as `enemy:boss` with the same RNG/catalog before its first action. Verify the cached `main.gd` diff contains only these feature hunks.

- [ ] **Step 7: Run GREEN and commit**

Expected: `TEST_SUMMARY: PASS (25 suites)`, parser exit 0, and searches find no `contact_damage`. Commit `refactor: route enemies through typed damage`.

---

### Task 8: Remove Compatibility Bypasses and Verify the Complete Slice

**Files:**

- Modify: `scripts/combat/health_component.gd`
- Modify: `scripts/characters/party_actor.gd`
- Modify: `scripts/enemies/enemy_actor.gd`
- Update all tests still calling `take_damage` or actor `receive_damage`
- Create: `tests/unit/test_typed_combat_integration.gd`

**Interfaces:**

- Removes: `HealthComponent.take_damage()` and actor-level scalar `receive_damage()` compatibility paths.
- Leaves: `HealthComponent.apply_damage()` for focused health-state tests and `DamageResolver` as the only gameplay damage caller.

- [ ] **Step 1: Write the failing static and integration audit**

Create a suite that reads production source with `FileAccess.get_file_as_string()` and fails if:

```gdscript
var forbidden := {
	"res://scripts/combat/health_component.gd": ["var armor", "maxf(1.0", "func take_damage"],
	"res://scripts/characters/party_actor.gd": ["func receive_damage"],
	"res://scripts/enemies/enemy_actor.gd": ["func receive_damage"],
	"res://scripts/data/enemy_definition.gd": ["contact_damage"],
	"res://scripts/combat/projectile.gd": ["var damage :="],
	"res://scripts/combat/area_burst.gd": ["var damage :="],
	"res://scripts/enemies/enemy_projectile.gd": ["var damage :="],
}
```

Also instantiate all four class attacks, all three enemy definitions, and all delivery scenes; assert every damaging action reaches a valid packet and every baseline catalog validates.

- [ ] **Step 2: Run RED**

Expected: FAIL on the temporary `take_damage` and actor compatibility functions.

- [ ] **Step 3: Remove every bypass and update callers**

Delete the temporary HealthComponent alias and both scalar actor functions. Replace test-only state setup with `health.apply_damage()`. Gameplay tests must execute authored attacks through `AttackExecutor` or enemy behavior APIs. Run:

```powershell
rg -n "contact_damage|func receive_damage|\.receive_damage\(|call\(\"receive_damage\"|func take_damage|\.take_damage\(|call\(\"take_damage\"|raw_damage - armor|maxf\(1\.0" scripts data tests
```

Expected: no production bypass matches; test matches exist only where the audit's forbidden strings are intentionally listed.

- [ ] **Step 4: Run the complete automated verification**

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path 'F:\Projects(root)\Game dev\Projects\party-forge' --script res://tests/test_runner.gd
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path 'F:\Projects(root)\Game dev\Projects\party-forge' --editor --quit-after 2
git diff --check
```

Expected: `TEST_SUMMARY: PASS (26 suites)`, parser exit 0, and diff check exit 0. The expected invalid-packet diagnostic may appear only in the focused test that intentionally triggers it.

- [ ] **Step 5: Commit the cleanup**

Verify staged scope and commit `refactor: remove raw damage bypasses`.

- [ ] **Step 6: Verify live through the connected Godot editor**

Save all open scenes first. Run the current `main.tscn` and verify Fighter Physical cleave, Ranger Physical projectile, Mage Fire burst, Cleric Lightning bolt and healing, enemy contact/projectile/boss damage, experience and levels, down/revive, regeneration, life steal, and run victory/defeat flow. Use controlled test modifiers for armor, one resistance, dodge, block, regeneration, and life steal; do not leave balance-only modifiers in baseline Resources.

Confirm Spitter remains dodgeable with speed 6 and lifetime 3. Read both game and editor logs with details and require zero unexpected errors. Stop the project and restore `main.tscn` as the active saved scene.

- [ ] **Step 7: Record final evidence and inspect preservation**

Run:

```powershell
git log --oneline -10
git status --short
git diff -- data/classes/fighter.tres data/stats/core_stats.tres project.godot scenes/game/main.tscn scenes/ui/hud.tscn scripts/ui
```

Expected: typed-combat commits are present; all pre-existing user/Steam/Marksman/handbook changes remain saved and unstaged unless a narrowly scoped feature hunk was explicitly committed.

## Completion Criteria

- All eight task commits exist and their staged scopes were reviewed before commit.
- All 26 suites pass and the headless parser/import scan exits 0.
- The static audit finds no raw gameplay damage bypass, subtractive armor, minimum-one rule, or scalar enemy contact damage.
- Live party and enemy attacks use the same resolver with clean editor/game logs.
- Crit is shared per execution; target dodge/block are independent and deterministic.
- Mixed damage, negative/capped resistance, Vanguard, overkill-safe life steal, continuous regeneration, and healing separation have focused evidence.
- Spitter tuning and unrelated user work remain preserved.
