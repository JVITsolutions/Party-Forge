# Party Forge Five-Minute Prototype Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a complete five-minute Party Forge run in which a player-controlled class leader recruits an automatic four-character party, activates overlapping traits, survives escalating enemies, and defeats the Forge Guardian.

**Architecture:** Typed GDScript systems own one responsibility each and exchange typed signals or explicit method calls. Godot `Resource` files hold combat and content values, while deterministic RefCounted helpers isolate rules that can be exercised headlessly without physics or rendering.

**Tech Stack:** Godot 4.7.1 stable Mono editor, typed GDScript, Jolt Physics, Godot Resources and scenes, PowerShell verification commands, custom headless GDScript test runner.

## Global Constraints

- Project root: `F:\Projects(root)\Game dev\Projects\party-forge`.
- Engine executable: `F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64.exe`.
- Gameplay code uses typed GDScript; no C# gameplay assembly is introduced.
- The ordinary run has four total party members including the leader, but collection logic must accept arbitrary future party sizes.
- Combat is automatic; the player controls only leader movement.
- The camera is a fixed high-angle 3D perspective and follows the leader without player rotation controls.
- The run reaches its boss phase at exactly 300 seconds of unpaused run time.
- Companion defeat creates a temporary downed state; leader defeat ends the run.
- Duplicate classes share a run-specific class rank and count independently toward traits.
- Trait definitions accept thresholds above four even though prototype content uses thresholds at two and four.
- Placeholder visuals must communicate allegiance, class, health, damage, healing, experience, danger, downing, boss arrival, victory, and defeat.
- No final AV assets, equipment, inventory, shop, persistent metagame, active abilities, procedural arena, multiplayer, or required controller support are added.
- Every task ends with the listed focused tests plus the complete headless suite.

---

## File Responsibility Map

- `tests/test_runner.gd` discovers and runs every `tests/unit/test_*.gd` suite.
- `tests/assertions.gd` provides deterministic assertion helpers without a third-party test addon.
- `scripts/data/*.gd` define validated Resource schemas; `data/**/*.tres` contain tunable content.
- `scripts/combat/health_component.gd` is the sole owner of health, damage, downing, revival, and leader death.
- `scripts/party/party_manager.gd` owns party records, class ranks, trait counts, and the party cap.
- `scripts/progression/*.gd` own experience thresholds and valid level-up choices.
- `scripts/combat/target_selector.gd` and `attack_controller.gd` own deterministic target and cooldown rules.
- `scripts/characters/*.gd` own leader input, companion steering, and actor presentation hooks.
- `scripts/formation/formation_math.gd` computes role-based desired movement without reading the scene tree.
- `scripts/enemies/*.gd` own regular enemy steering and boss actions.
- `scripts/game/game_run.gd` owns the run state machine and mutually exclusive terminal states.
- `scripts/game/spawn_director.gd` owns time-based enemy composition and boss spawning.
- `scripts/ui/*.gd` render state and submit level-up selections; they do not calculate game rules.
- `scenes/dev/combat_sandbox.tscn` is an isolated tuning and regression workspace.

---

### Task 1: Bootable Project and Headless Test Harness

**Files:**
- Modify: `project.godot`
- Create: `scenes/game/main.tscn`
- Create: `scripts/game/main.gd`
- Create: `tests/assertions.gd`
- Create: `tests/test_runner.gd`
- Create: `tests/unit/test_boot.gd`

**Interfaces:**
- Produces: `TestAssertions.equal(actual, expected, label, failures)` and `TestAssertions.truthy(value, label, failures)`.
- Produces: a runner contract in which each `tests/unit/test_*.gd` script implements `func run() -> Array[String]`.

- [ ] **Step 1: Write the boot test and assertion helpers**

```gdscript
# tests/assertions.gd
class_name TestAssertions
extends RefCounted

static func equal(actual: Variant, expected: Variant, label: String, failures: Array[String]) -> void:
    if actual != expected:
        failures.append("%s: expected %s, got %s" % [label, expected, actual])

static func truthy(value: bool, label: String, failures: Array[String]) -> void:
    if not value:
        failures.append("%s: expected true" % label)

static func near(actual: float, expected: float, tolerance: float, label: String, failures: Array[String]) -> void:
    if absf(actual - expected) > tolerance:
        failures.append("%s: expected %.3f +/- %.3f, got %.3f" % [label, expected, tolerance, actual])
```

```gdscript
# tests/unit/test_boot.gd
extends RefCounted

func run() -> Array[String]:
    var failures: Array[String] = []
    TestAssertions.equal(ProjectSettings.get_setting("application/config/name"), "Party Forge", "project name", failures)
    TestAssertions.truthy(ResourceLoader.exists("res://scenes/game/main.tscn"), "main scene exists", failures)
    return failures
```

- [ ] **Step 2: Create the discovering test runner**

```gdscript
# tests/test_runner.gd
extends SceneTree

func _initialize() -> void:
    var failures: Array[String] = []
    var suite_paths: PackedStringArray = _collect_suites("res://tests/unit")
    for suite_path: String in suite_paths:
        var suite_script: Script = load(suite_path)
        var suite: RefCounted = suite_script.new()
        var suite_failures: Array[String] = suite.run()
        for failure: String in suite_failures:
            failures.append("%s :: %s" % [suite_path, failure])
    if failures.is_empty():
        print("TEST_SUMMARY: PASS (%d suites)" % suite_paths.size())
        quit(0)
        return
    for failure: String in failures:
        push_error("TEST_FAILURE: %s" % failure)
    print("TEST_SUMMARY: FAIL (%d failures)" % failures.size())
    quit(1)

func _collect_suites(root: String) -> PackedStringArray:
    var paths: PackedStringArray = []
    var directory: DirAccess = DirAccess.open(root)
    if directory == null:
        return paths
    directory.list_dir_begin()
    var name: String = directory.get_next()
    while not name.is_empty():
        if not directory.current_is_dir() and name.begins_with("test_") and name.ends_with(".gd"):
            paths.append(root.path_join(name))
        name = directory.get_next()
    directory.list_dir_end()
    paths.sort()
    return paths
```

- [ ] **Step 3: Run the test to verify it fails before the scene exists**

Run:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64.exe' --headless --path 'F:\Projects(root)\Game dev\Projects\party-forge' --script res://tests/test_runner.gd
```

Expected: exit code `1` and `TEST_FAILURE: res://tests/unit/test_boot.gd :: main scene exists: expected true`.

- [ ] **Step 4: Create the minimal main scene and input map**

```gdscript
# scripts/game/main.gd
extends Node

func _ready() -> void:
    print("PARTY_FORGE_BOOT_OK")
```

```ini
; scenes/game/main.tscn
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/game/main.gd" id="1"]

[node name="Main" type="Node"]
script = ExtResource("1")
```

Add to `project.godot`:

```ini
[application]
run/main_scene="res://scenes/game/main.tscn"

[input]
move_left={"deadzone": 0.2, "events": [Object(InputEventKey,"physical_keycode":65)]}
move_right={"deadzone": 0.2, "events": [Object(InputEventKey,"physical_keycode":68)]}
move_forward={"deadzone": 0.2, "events": [Object(InputEventKey,"physical_keycode":87)]}
move_back={"deadzone": 0.2, "events": [Object(InputEventKey,"physical_keycode":83)]}
```

- [ ] **Step 5: Run the focused test, parser check, and startup smoke check**

Run the headless test command from Step 3, then:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64.exe' --headless --path 'F:\Projects(root)\Game dev\Projects\party-forge' --editor --quit-after 2
```

Expected: `TEST_SUMMARY: PASS (1 suites)`, `PARTY_FORGE_BOOT_OK`, and no parser or runtime errors.

- [ ] **Step 6: Commit the bootable baseline**

```powershell
git add project.godot scenes/game/main.tscn scripts/game/main.gd tests
git commit -m "build: add Godot test harness"
```

---

### Task 2: Health, Damage, Downing, Revival, and Leader Death

**Files:**
- Create: `scripts/combat/health_component.gd`
- Create: `tests/unit/test_health_component.gd`

**Interfaces:**
- Produces: `HealthComponent.configure(maximum: float, armor_value: float, leader: bool, revive_seconds: float, revive_fraction: float)`.
- Produces: `take_damage(raw_damage: float) -> float`, `heal(amount: float) -> float`, and `advance_time(delta: float)`.
- Emits: `health_changed`, `downed`, `revived`, and `died`.

- [ ] **Step 1: Write failing health lifecycle tests**

```gdscript
# tests/unit/test_health_component.gd
extends RefCounted

const HealthScript := preload("res://scripts/combat/health_component.gd")

func run() -> Array[String]:
    var failures: Array[String] = []
    var companion: HealthComponent = HealthScript.new()
    companion.configure(100.0, 3.0, false, 8.0, 0.5)
    TestAssertions.near(companion.take_damage(13.0), 10.0, 0.001, "armor reduces damage", failures)
    companion.take_damage(500.0)
    TestAssertions.truthy(companion.is_downed, "companion is downed", failures)
    companion.advance_time(7.9)
    TestAssertions.truthy(companion.is_downed, "companion remains downed before delay", failures)
    companion.advance_time(0.1)
    TestAssertions.truthy(not companion.is_downed, "companion revives", failures)
    TestAssertions.near(companion.current_health, 50.0, 0.001, "revive health fraction", failures)

    var leader: HealthComponent = HealthScript.new()
    leader.configure(80.0, 0.0, true, 8.0, 0.5)
    leader.take_damage(80.0)
    TestAssertions.truthy(leader.is_dead, "leader dies", failures)
    leader.take_damage(10.0)
    TestAssertions.near(leader.current_health, 0.0, 0.001, "terminal damage is idempotent", failures)
    return failures
```

- [ ] **Step 2: Run the suite and verify the missing-script failure**

Expected: exit code `1` with a load error naming `res://scripts/combat/health_component.gd`.

- [ ] **Step 3: Implement the component**

```gdscript
# scripts/combat/health_component.gd
class_name HealthComponent
extends Node

signal health_changed(current: float, maximum: float)
signal downed
signal revived
signal died

var max_health: float = 1.0
var current_health: float = 1.0
var armor: float = 0.0
var is_leader: bool = false
var is_downed: bool = false
var is_dead: bool = false
var revive_delay: float = 8.0
var revive_health_fraction: float = 0.5
var revive_remaining: float = 0.0

func configure(maximum: float, armor_value: float, leader: bool, revive_seconds: float, revive_fraction: float) -> void:
    max_health = maxf(maximum, 1.0)
    current_health = max_health
    armor = maxf(armor_value, 0.0)
    is_leader = leader
    revive_delay = maxf(revive_seconds, 0.1)
    revive_health_fraction = clampf(revive_fraction, 0.01, 1.0)
    is_downed = false
    is_dead = false

func take_damage(raw_damage: float) -> float:
    if is_dead or is_downed or raw_damage <= 0.0:
        return 0.0
    var applied: float = maxf(1.0, raw_damage - armor)
    current_health = maxf(0.0, current_health - applied)
    health_changed.emit(current_health, max_health)
    if current_health <= 0.0:
        if is_leader:
            is_dead = true
            died.emit()
        else:
            is_downed = true
            revive_remaining = revive_delay
            downed.emit()
    return applied

func heal(amount: float) -> float:
    if is_dead or is_downed or amount <= 0.0:
        return 0.0
    var previous: float = current_health
    current_health = minf(max_health, current_health + amount)
    health_changed.emit(current_health, max_health)
    return current_health - previous

func advance_time(delta: float) -> void:
    if not is_downed or delta <= 0.0:
        return
    revive_remaining = maxf(0.0, revive_remaining - delta)
    if revive_remaining <= 0.0:
        is_downed = false
        current_health = max_health * revive_health_fraction
        health_changed.emit(current_health, max_health)
        revived.emit()
```

- [ ] **Step 4: Run the focused and complete suites**

Expected: `TEST_SUMMARY: PASS (2 suites)`.

- [ ] **Step 5: Commit**

```powershell
git add scripts/combat/health_component.gd tests/unit/test_health_component.gd
git commit -m "feat: add party health lifecycle"
```

---

### Task 3: Validated Class, Attack, Trait, and Enemy Data

**Files:**
- Create: `scripts/data/attack_definition.gd`
- Create: `scripts/data/class_definition.gd`
- Create: `scripts/data/trait_definition.gd`
- Create: `scripts/data/enemy_definition.gd`
- Create: `scripts/data/game_catalog.gd`
- Create: `tools/create_default_data.gd`
- Create: generated `data/attacks/*.tres`, `data/classes/*.tres`, `data/traits/*.tres`, and `data/enemies/*.tres`
- Create: `tests/unit/test_game_catalog.gd`

**Interfaces:**
- Produces: Resource classes `AttackDefinition`, `ClassDefinition`, `TraitDefinition`, and `EnemyDefinition`, each with `validate() -> PackedStringArray`.
- Produces: `GameCatalog.load_defaults() -> GameCatalog`, `class_by_id(id)`, and `trait_by_id(id)`.

- [ ] **Step 1: Write the catalog validation test**

```gdscript
# tests/unit/test_game_catalog.gd
extends RefCounted

func run() -> Array[String]:
    var failures: Array[String] = []
    var catalog: GameCatalog = GameCatalog.load_defaults()
    TestAssertions.equal(catalog.classes.size(), 4, "four classes", failures)
    TestAssertions.equal(catalog.traits.size(), 7, "seven traits", failures)
    TestAssertions.equal(catalog.enemies.size(), 3, "two enemies plus boss", failures)
    TestAssertions.equal(catalog.validate().size(), 0, "catalog validates", failures)
    TestAssertions.equal(catalog.class_by_id(&"fighter").traits, [&"martial", &"vanguard"], "fighter traits", failures)
    TestAssertions.equal(catalog.class_by_id(&"cleric").support_action.id, &"cleric_heal", "cleric heal", failures)
    return failures
```

- [ ] **Step 2: Verify the test fails because data classes are absent**

Expected: a parser error naming `GameCatalog`.

- [ ] **Step 3: Implement exact Resource schemas**

```gdscript
# scripts/data/attack_definition.gd
class_name AttackDefinition
extends Resource

enum Kind { MELEE_CLEAVE, PROJECTILE, AREA_PROJECTILE, HEAL }

@export var id: StringName
@export var kind: Kind
@export var power: float = 1.0
@export var cooldown: float = 1.0
@export var range: float = 1.0
@export var projectile_speed: float = 0.0
@export var area_radius: float = 0.0

func validate() -> PackedStringArray:
    var errors: PackedStringArray = []
    if id.is_empty(): errors.append("attack id is empty")
    if power <= 0.0: errors.append("attack %s power must be positive" % id)
    if cooldown <= 0.0: errors.append("attack %s cooldown must be positive" % id)
    if range <= 0.0: errors.append("attack %s range must be positive" % id)
    if kind in [Kind.PROJECTILE, Kind.AREA_PROJECTILE] and projectile_speed <= 0.0:
        errors.append("attack %s projectile speed must be positive" % id)
    return errors
```

```gdscript
# scripts/data/class_definition.gd
class_name ClassDefinition
extends Resource

enum Role { FRONTLINE, MIDLINE, BACKLINE, SUPPORT }

@export var id: StringName
@export var display_name: String
@export var role: Role
@export var color: Color = Color.WHITE
@export var traits: Array[StringName] = []
@export var max_health: float = 100.0
@export var armor: float = 0.0
@export var move_speed: float = 6.0
@export var preferred_distance: float = 2.0
@export var engagement_distance: float = 8.0
@export var tether_distance: float = 10.0
@export var primary_attack: AttackDefinition
@export var support_action: AttackDefinition

func validate() -> PackedStringArray:
    var errors: PackedStringArray = []
    if id.is_empty(): errors.append("class id is empty")
    if display_name.is_empty(): errors.append("class %s display name is empty" % id)
    if traits.is_empty(): errors.append("class %s has no traits" % id)
    if max_health <= 0.0: errors.append("class %s health must be positive" % id)
    if primary_attack == null: errors.append("class %s primary attack is missing" % id)
    if primary_attack != null:
        for reason: String in primary_attack.validate(): errors.append("class %s primary %s" % [id, reason])
    if support_action != null:
        for reason: String in support_action.validate(): errors.append("class %s support %s" % [id, reason])
    return errors
```

```gdscript
# scripts/data/trait_definition.gd
class_name TraitDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var stat_id: StringName
@export var tiers: Dictionary = {2: 0.15, 4: 0.35}

func validate() -> PackedStringArray:
    var errors: PackedStringArray = []
    if id.is_empty(): errors.append("trait id is empty")
    if stat_id.is_empty(): errors.append("trait %s stat id is empty" % id)
    for threshold: Variant in tiers.keys():
        if int(threshold) < 2: errors.append("trait %s threshold must be at least two" % id)
    return errors
```

```gdscript
# scripts/data/enemy_definition.gd
class_name EnemyDefinition
extends Resource

enum Behavior { SWARMER, SPITTER, FORGE_GUARDIAN }

@export var id: StringName
@export var behavior: Behavior
@export var max_health: float = 20.0
@export var move_speed: float = 3.0
@export var contact_damage: float = 5.0
@export var experience: int = 1

func validate() -> PackedStringArray:
    var errors: PackedStringArray = []
    if id.is_empty(): errors.append("enemy id is empty")
    if max_health <= 0.0: errors.append("enemy %s health must be positive" % id)
    if move_speed <= 0.0: errors.append("enemy %s speed must be positive" % id)
    return errors
```

- [ ] **Step 4: Create the data generator with exact prototype values**

`tools/create_default_data.gd` must construct and save these values:

```gdscript
extends SceneTree

func _initialize() -> void:
    for path: String in ["res://data/attacks", "res://data/classes", "res://data/traits", "res://data/enemies"]:
        DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
    var attacks: Dictionary = {}
    attacks[&"fighter_cleave"] = _attack(&"fighter_cleave", AttackDefinition.Kind.MELEE_CLEAVE, 18.0, 0.8, 2.2, 0.0, 1.6)
    attacks[&"ranger_shot"] = _attack(&"ranger_shot", AttackDefinition.Kind.PROJECTILE, 11.0, 0.55, 11.0, 16.0, 0.0)
    attacks[&"mage_burst"] = _attack(&"mage_burst", AttackDefinition.Kind.AREA_PROJECTILE, 24.0, 1.5, 12.0, 11.0, 2.5)
    attacks[&"cleric_bolt"] = _attack(&"cleric_bolt", AttackDefinition.Kind.PROJECTILE, 8.0, 1.0, 10.0, 13.0, 0.0)
    attacks[&"cleric_heal"] = _attack(&"cleric_heal", AttackDefinition.Kind.HEAL, 18.0, 3.0, 9.0, 0.0, 0.0)
    for id: StringName in attacks:
        ResourceSaver.save(attacks[id], "res://data/attacks/%s.tres" % id)

    _save_class(&"fighter", "Fighter", ClassDefinition.Role.FRONTLINE, Color("d94f4f"), [&"martial", &"vanguard"], 140.0, 6.0, 6.2, 2.0, 5.0, 9.0, attacks[&"fighter_cleave"], null)
    _save_class(&"ranger", "Ranger", ClassDefinition.Role.MIDLINE, Color("5fbd72"), [&"martial", &"ranged"], 90.0, 1.0, 6.6, 5.0, 11.0, 11.0, attacks[&"ranger_shot"], null)
    _save_class(&"mage", "Mage", ClassDefinition.Role.BACKLINE, Color("9567e8"), [&"arcane", &"ranged", &"caster"], 75.0, 0.0, 6.0, 6.5, 12.0, 12.0, attacks[&"mage_burst"], null)
    _save_class(&"cleric", "Cleric", ClassDefinition.Role.SUPPORT, Color("f0d15b"), [&"divine", &"support", &"caster"], 95.0, 2.0, 6.0, 4.0, 10.0, 10.0, attacks[&"cleric_bolt"], attacks[&"cleric_heal"])

    _save_trait(&"martial", "Martial", &"attack_speed", {2: 0.15, 4: 0.35})
    _save_trait(&"vanguard", "Vanguard", &"nearby_damage_reduction", {2: 0.12, 4: 0.28})
    _save_trait(&"ranged", "Ranged", &"projectile_speed_and_range", {2: 0.15, 4: 0.35})
    _save_trait(&"arcane", "Arcane", &"area_size", {2: 0.18, 4: 0.40})
    _save_trait(&"caster", "Caster", &"cooldown_reduction", {2: 0.12, 4: 0.28})
    _save_trait(&"divine", "Divine", &"healing_and_revive", {2: 0.18, 4: 0.40})
    _save_trait(&"support", "Support", &"support_power", {2: 0.15, 4: 0.35})

    _save_enemy(&"swarmer", EnemyDefinition.Behavior.SWARMER, 24.0, 4.8, 8.0, 2)
    _save_enemy(&"spitter", EnemyDefinition.Behavior.SPITTER, 42.0, 2.8, 10.0, 4)
    _save_enemy(&"forge_guardian", EnemyDefinition.Behavior.FORGE_GUARDIAN, 1500.0, 3.3, 22.0, 100)
    print("DATA_GENERATION_OK")
    quit(0)

func _attack(id: StringName, kind: AttackDefinition.Kind, power: float, cooldown: float, range_value: float, speed: float, radius: float) -> AttackDefinition:
    var value := AttackDefinition.new()
    value.id = id; value.kind = kind; value.power = power; value.cooldown = cooldown
    value.range = range_value; value.projectile_speed = speed; value.area_radius = radius
    return value

func _save_class(id: StringName, name_value: String, role: ClassDefinition.Role, color: Color, traits: Array[StringName], health: float, armor: float, speed: float, preferred: float, engagement: float, tether: float, primary: AttackDefinition, support: AttackDefinition) -> void:
    var value := ClassDefinition.new()
    value.id = id; value.display_name = name_value; value.role = role; value.color = color; value.traits = traits
    value.max_health = health; value.armor = armor; value.move_speed = speed
    value.preferred_distance = preferred; value.engagement_distance = engagement; value.tether_distance = tether
    value.primary_attack = primary; value.support_action = support
    ResourceSaver.save(value, "res://data/classes/%s.tres" % id)

func _save_trait(id: StringName, name_value: String, stat: StringName, tiers: Dictionary) -> void:
    var value := TraitDefinition.new()
    value.id = id; value.display_name = name_value; value.stat_id = stat; value.tiers = tiers
    ResourceSaver.save(value, "res://data/traits/%s.tres" % id)

func _save_enemy(id: StringName, behavior: EnemyDefinition.Behavior, health: float, speed: float, damage: float, experience: int) -> void:
    var value := EnemyDefinition.new()
    value.id = id; value.behavior = behavior; value.max_health = health; value.move_speed = speed
    value.contact_damage = damage; value.experience = experience
    ResourceSaver.save(value, "res://data/enemies/%s.tres" % id)
```

- [ ] **Step 5: Implement `GameCatalog`, generate data, and rerun tests**

```gdscript
# scripts/data/game_catalog.gd
class_name GameCatalog
extends RefCounted

const CLASS_PATHS: PackedStringArray = [
    "res://data/classes/fighter.tres", "res://data/classes/ranger.tres",
    "res://data/classes/mage.tres", "res://data/classes/cleric.tres"
]
const TRAIT_PATHS: PackedStringArray = [
    "res://data/traits/martial.tres", "res://data/traits/vanguard.tres",
    "res://data/traits/ranged.tres", "res://data/traits/arcane.tres",
    "res://data/traits/caster.tres", "res://data/traits/divine.tres",
    "res://data/traits/support.tres"
]
const ENEMY_PATHS: PackedStringArray = [
    "res://data/enemies/swarmer.tres", "res://data/enemies/spitter.tres",
    "res://data/enemies/forge_guardian.tres"
]

var classes: Array[ClassDefinition] = []
var traits: Array[TraitDefinition] = []
var enemies: Array[EnemyDefinition] = []

static func load_defaults() -> GameCatalog:
    var catalog := GameCatalog.new()
    for path: String in CLASS_PATHS:
        catalog.classes.append(load(path) as ClassDefinition)
    for path: String in TRAIT_PATHS:
        catalog.traits.append(load(path) as TraitDefinition)
    for path: String in ENEMY_PATHS:
        catalog.enemies.append(load(path) as EnemyDefinition)
    return catalog

func class_by_id(id: StringName) -> ClassDefinition:
    for definition: ClassDefinition in classes:
        if definition != null and definition.id == id: return definition
    return null

func trait_by_id(id: StringName) -> TraitDefinition:
    for definition: TraitDefinition in traits:
        if definition != null and definition.id == id: return definition
    return null

func validate() -> PackedStringArray:
    var errors: PackedStringArray = []
    var seen: Dictionary = {}
    var resources: Array[Resource] = []
    for definition: ClassDefinition in classes: resources.append(definition)
    for definition: TraitDefinition in traits: resources.append(definition)
    for definition: EnemyDefinition in enemies: resources.append(definition)
    for definition: Resource in resources:
        if definition == null:
            errors.append("PARTY_FORGE_RESOURCE_ERROR reason=resource failed to load")
            continue
        var id: StringName = definition.get("id")
        if seen.has(id): errors.append("PARTY_FORGE_RESOURCE_ERROR reason=duplicate id %s" % id)
        seen[id] = true
        var validation: PackedStringArray = definition.call("validate")
        for reason: String in validation:
            errors.append("PARTY_FORGE_RESOURCE_ERROR id=%s reason=%s" % [id, reason])
    return errors
```

Run:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64.exe' --headless --path 'F:\Projects(root)\Game dev\Projects\party-forge' --script res://tools/create_default_data.gd
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64.exe' --headless --path 'F:\Projects(root)\Game dev\Projects\party-forge' --script res://tests/test_runner.gd
```

Expected: `DATA_GENERATION_OK` and `TEST_SUMMARY: PASS (3 suites)`.

- [ ] **Step 6: Commit**

```powershell
git add scripts/data tools/create_default_data.gd data tests/unit/test_game_catalog.gd
git commit -m "feat: add Party Forge content resources"
```

---

### Task 4: Party Records, Recruitment, Shared Class Ranks, and Trait Tiers

**Files:**
- Create: `scripts/party/party_member_state.gd`
- Create: `scripts/party/party_manager.gd`
- Create: `tests/unit/test_party_manager.gd`

**Interfaces:**
- Produces: `PartyManager.initialize(leader_class)`, `recruit(class_definition) -> bool`, `rank_up(class_id) -> bool`, `get_class_rank(class_id) -> int`, `trait_count(trait_id) -> int`, and `active_tier(trait_id) -> int`.
- Emits: `member_added(member)`, `class_rank_changed(class_id, rank)`, and `active_traits_changed(tiers)`.

- [ ] **Step 1: Write tests for duplicates, the cap, shared ranks, and overlapping traits**

```gdscript
# tests/unit/test_party_manager.gd
extends RefCounted

func run() -> Array[String]:
    var failures: Array[String] = []
    var catalog := GameCatalog.load_defaults()
    var party := PartyManager.new()
    party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
    TestAssertions.equal(party.members.size(), 1, "leader occupies one slot", failures)
    TestAssertions.truthy(party.recruit(catalog.class_by_id(&"fighter")), "duplicate fighter recruits", failures)
    TestAssertions.equal(party.trait_count(&"martial"), 2, "duplicate counts for martial", failures)
    TestAssertions.equal(party.active_tier(&"vanguard"), 2, "vanguard tier two", failures)
    party.recruit(catalog.class_by_id(&"ranger"))
    party.recruit(catalog.class_by_id(&"mage"))
    TestAssertions.truthy(not party.recruit(catalog.class_by_id(&"cleric")), "fifth member rejected", failures)
    party.rank_up(&"fighter")
    TestAssertions.equal(party.get_class_rank(&"fighter"), 2, "shared fighter rank", failures)
    TestAssertions.equal(party.active_tier(&"ranged"), 2, "ranger and mage overlap", failures)
    return failures
```

- [ ] **Step 2: Verify the missing `PartyManager` parser failure**

- [ ] **Step 3: Implement party state and deterministic tier calculation**

```gdscript
# scripts/party/party_member_state.gd
class_name PartyMemberState
extends RefCounted

var member_id: int
var class_definition: ClassDefinition
var is_leader: bool

func _init(id_value: int, definition: ClassDefinition, leader: bool) -> void:
    member_id = id_value
    class_definition = definition
    is_leader = leader
```

```gdscript
# scripts/party/party_manager.gd
class_name PartyManager
extends Node

signal member_added(member: PartyMemberState)
signal class_rank_changed(class_id: StringName, rank: int)
signal active_traits_changed(tiers: Dictionary)

const MAX_PARTY_SIZE := 4
var members: Array[PartyMemberState] = []
var class_ranks: Dictionary = {}
var trait_definitions: Array[TraitDefinition] = []
var active_tiers: Dictionary = {}

func initialize(leader_class: ClassDefinition, traits: Array[TraitDefinition]) -> void:
    members.clear(); class_ranks.clear(); active_tiers.clear(); trait_definitions = traits
    _append_member(leader_class, true)

func recruit(definition: ClassDefinition) -> bool:
    if definition == null or members.size() >= MAX_PARTY_SIZE:
        return false
    _append_member(definition, false)
    return true

func rank_up(class_id: StringName) -> bool:
    if not class_ranks.has(class_id):
        return false
    class_ranks[class_id] = int(class_ranks[class_id]) + 1
    class_rank_changed.emit(class_id, int(class_ranks[class_id]))
    return true

func get_class_rank(class_id: StringName) -> int:
    return int(class_ranks.get(class_id, 0))

func trait_count(trait_id: StringName) -> int:
    var count := 0
    for member: PartyMemberState in members:
        if trait_id in member.class_definition.traits:
            count += 1
    return count

func active_tier(trait_id: StringName) -> int:
    return int(active_tiers.get(trait_id, 0))

func _append_member(definition: ClassDefinition, leader: bool) -> void:
    var member := PartyMemberState.new(members.size() + 1, definition, leader)
    members.append(member)
    if not class_ranks.has(definition.id): class_ranks[definition.id] = 1
    _recalculate_traits()
    member_added.emit(member)

func _recalculate_traits() -> void:
    var next: Dictionary = {}
    for definition: TraitDefinition in trait_definitions:
        var count: int = trait_count(definition.id)
        var achieved := 0
        for threshold: Variant in definition.tiers.keys():
            if count >= int(threshold): achieved = maxi(achieved, int(threshold))
        if achieved > 0: next[definition.id] = achieved
    if next != active_tiers:
        active_tiers = next
        active_traits_changed.emit(active_tiers.duplicate())
```

- [ ] **Step 4: Run all tests**

Expected: `TEST_SUMMARY: PASS (4 suites)`.

- [ ] **Step 5: Commit**

```powershell
git add scripts/party tests/unit/test_party_manager.gd
git commit -m "feat: add party composition and traits"
```

---

### Task 5: Experience Thresholds and Valid Level-Up Choices

**Files:**
- Create: `scripts/progression/experience_system.gd`
- Create: `scripts/progression/upgrade_choice.gd`
- Create: `scripts/progression/level_up_choice_service.gd`
- Create: `tests/unit/test_progression.gd`

**Interfaces:**
- Produces: `ExperienceSystem.add_experience(amount)`, `experience_for_next_level()`, and `consume_pending_level()`.
- Produces: `LevelUpChoiceService.generate(party, catalog, seed) -> Array[UpgradeChoice]` with exactly three usable choices.

- [ ] **Step 1: Write progression tests**

Test these exact cases in `tests/unit/test_progression.gd`:

```gdscript
extends RefCounted

func run() -> Array[String]:
    var failures: Array[String] = []
    var experience := ExperienceSystem.new()
    experience.add_experience(20)
    TestAssertions.equal(experience.pending_levels, 1, "first threshold", failures)
    var catalog := GameCatalog.load_defaults()
    var party := PartyManager.new()
    party.initialize(catalog.class_by_id(&"fighter"), catalog.traits)
    var early: Array[UpgradeChoice] = LevelUpChoiceService.generate(party, catalog, 7)
    TestAssertions.equal(early.size(), 3, "three early choices", failures)
    TestAssertions.truthy(early.any(func(choice: UpgradeChoice) -> bool: return choice.kind == UpgradeChoice.Kind.RECRUIT), "open party guarantees recruit", failures)
    party.recruit(catalog.class_by_id(&"ranger")); party.recruit(catalog.class_by_id(&"mage")); party.recruit(catalog.class_by_id(&"cleric"))
    var full: Array[UpgradeChoice] = LevelUpChoiceService.generate(party, catalog, 7)
    TestAssertions.truthy(full.all(func(choice: UpgradeChoice) -> bool: return choice.kind != UpgradeChoice.Kind.RECRUIT), "full party excludes recruits", failures)
    TestAssertions.truthy(full.all(func(choice: UpgradeChoice) -> bool: return choice.is_valid_for(party)), "all full choices usable", failures)
    return failures
```

- [ ] **Step 2: Verify the missing-type failure**

- [ ] **Step 3: Implement the experience curve and choice contract**

```gdscript
# scripts/progression/experience_system.gd
class_name ExperienceSystem
extends Node

signal level_ready(level: int)
var level: int = 1
var experience: int = 0
var pending_levels: int = 0

func experience_for_next_level() -> int:
    return 20 + (level - 1) * 10

func add_experience(amount: int) -> void:
    experience += maxi(amount, 0)
    while experience >= experience_for_next_level():
        experience -= experience_for_next_level()
        level += 1
        pending_levels += 1
        level_ready.emit(level)

func consume_pending_level() -> bool:
    if pending_levels <= 0: return false
    pending_levels -= 1
    return true
```

```gdscript
# scripts/progression/upgrade_choice.gd
class_name UpgradeChoice
extends RefCounted

enum Kind { RECRUIT, CLASS_RANK, TRAIT, PARTY_STAT }
var kind: Kind
var target_id: StringName
var label: String

func _init(kind_value: Kind, target: StringName, label_value: String) -> void:
    kind = kind_value; target_id = target; label = label_value

func key() -> String:
    return "%d:%s" % [kind, target_id]

func is_valid_for(party: PartyManager) -> bool:
    match kind:
        Kind.RECRUIT: return party.members.size() < PartyManager.MAX_PARTY_SIZE
        Kind.CLASS_RANK: return party.get_class_rank(target_id) > 0
        Kind.TRAIT: return party.active_tier(target_id) > 0
        Kind.PARTY_STAT: return true
    return false
```

```gdscript
# scripts/progression/level_up_choice_service.gd
class_name LevelUpChoiceService
extends RefCounted

const PARTY_STATS: Array[StringName] = [&"max_health", &"damage", &"move_speed", &"attack_speed", &"pickup_radius"]

static func generate(party: PartyManager, catalog: GameCatalog, seed: int) -> Array[UpgradeChoice]:
    var rng := RandomNumberGenerator.new(); rng.seed = seed
    var chosen: Array[UpgradeChoice] = []
    var candidates: Array[UpgradeChoice] = []
    var recruits: Array[UpgradeChoice] = []
    for definition: ClassDefinition in catalog.classes:
        recruits.append(UpgradeChoice.new(UpgradeChoice.Kind.RECRUIT, definition.id, "Recruit %s" % definition.display_name))
        if party.get_class_rank(definition.id) > 0:
            candidates.append(UpgradeChoice.new(UpgradeChoice.Kind.CLASS_RANK, definition.id, "Train %s" % definition.display_name))
    for definition: TraitDefinition in catalog.traits:
        if party.active_tier(definition.id) > 0:
            candidates.append(UpgradeChoice.new(UpgradeChoice.Kind.TRAIT, definition.id, "Strengthen %s" % definition.display_name))
    for stat: StringName in PARTY_STATS:
        candidates.append(UpgradeChoice.new(UpgradeChoice.Kind.PARTY_STAT, stat, "Party %s" % String(stat).replace("_", " ").capitalize()))
    if party.members.size() < PartyManager.MAX_PARTY_SIZE:
        chosen.append(recruits[rng.randi_range(0, recruits.size() - 1)])
    for index: int in range(candidates.size() - 1, 0, -1):
        var swap_index: int = rng.randi_range(0, index)
        var held: UpgradeChoice = candidates[index]
        candidates[index] = candidates[swap_index]
        candidates[swap_index] = held
    var keys: Dictionary = {}
    for existing: UpgradeChoice in chosen: keys[existing.key()] = true
    for candidate: UpgradeChoice in candidates:
        if chosen.size() >= 3: break
        if candidate.is_valid_for(party) and not keys.has(candidate.key()):
            chosen.append(candidate); keys[candidate.key()] = true
    return chosen
```

- [ ] **Step 4: Run all tests and confirm deterministic output for seed 7**

Expected: all suites pass twice with the same three choice IDs for seed `7`.

- [ ] **Step 5: Commit**

```powershell
git add scripts/progression tests/unit/test_progression.gd
git commit -m "feat: add level progression choices"
```

---

### Task 6: Deterministic Targeting and Automatic Attack Cooldowns

**Files:**
- Create: `scripts/combat/combat_target.gd`
- Create: `scripts/combat/target_selector.gd`
- Create: `scripts/combat/attack_controller.gd`
- Create: `tests/unit/test_targeting.gd`

**Interfaces:**
- Produces: `TargetSelector.nearest(origin, candidates, maximum_range, own_team) -> CombatTarget`.
- Produces: `AttackController.configure(definition, team_id)`, `advance(delta)`, and `try_attack(origin, candidates) -> CombatTarget`.
- Emits: `attack_ready(definition, target)` only when cooldown and range requirements pass.

- [ ] **Step 1: Write nearest-target and cooldown tests**

Create three `CombatTarget` values at `(2,0,0)`, `(5,0,0)`, and `(20,0,0)`. Assert that range `10` chooses the first, range `1` returns null, the first `try_attack` succeeds, an immediate second call returns null, and a call after advancing the full cooldown succeeds.

- [ ] **Step 2: Run and verify the missing-type failure**

- [ ] **Step 3: Implement the small deterministic classes**

```gdscript
# scripts/combat/combat_target.gd
class_name CombatTarget
extends RefCounted

var actor: Node3D
var position: Vector3
var team_id: int
var is_available: bool = true

func _init(actor_value: Node3D, position_value: Vector3, team: int) -> void:
    actor = actor_value; position = position_value; team_id = team
```

```gdscript
# scripts/combat/target_selector.gd
class_name TargetSelector
extends RefCounted

static func nearest(origin: Vector3, candidates: Array[CombatTarget], maximum_range: float, own_team: int) -> CombatTarget:
    var selected: CombatTarget
    var best_distance := maximum_range
    for candidate: CombatTarget in candidates:
        if not candidate.is_available or candidate.team_id == own_team: continue
        var distance := origin.distance_to(candidate.position)
        if distance <= best_distance:
            selected = candidate; best_distance = distance
    return selected
```

```gdscript
# scripts/combat/attack_controller.gd
class_name AttackController
extends Node

signal attack_ready(definition: AttackDefinition, target: CombatTarget)
var definition: AttackDefinition
var team_id: int
var cooldown_remaining: float = 0.0

func configure(attack: AttackDefinition, own_team: int) -> void:
    definition = attack; team_id = own_team; cooldown_remaining = 0.0

func advance(delta: float) -> void:
    cooldown_remaining = maxf(0.0, cooldown_remaining - maxf(delta, 0.0))

func try_attack(origin: Vector3, candidates: Array[CombatTarget]) -> CombatTarget:
    if definition == null or cooldown_remaining > 0.0: return null
    var target := TargetSelector.nearest(origin, candidates, definition.range, team_id)
    if target == null: return null
    cooldown_remaining = definition.cooldown
    attack_ready.emit(definition, target)
    return target
```

- [ ] **Step 4: Run all tests**

- [ ] **Step 5: Commit**

```powershell
git add scripts/combat tests/unit/test_targeting.gd
git commit -m "feat: add automatic target selection"
```

---

### Task 7: Saved Arena, Leader Movement, and Fixed High-Angle Camera

**Files:**
- Create: `scripts/characters/leader_movement.gd`
- Create: `scripts/characters/party_actor.gd`
- Create: `scripts/characters/leader.gd`
- Create: `scripts/camera/leader_camera.gd`
- Create: `scenes/arena/arena.tscn`
- Create: `scenes/characters/leader.tscn`
- Create: `scenes/camera/leader_camera.tscn`
- Modify: `scenes/game/main.tscn`
- Create: `tests/unit/test_leader_movement.gd`

**Interfaces:**
- Produces: `LeaderMovement.velocity(input_vector, speed) -> Vector3`.
- Produces: `PartyActor.configure(member_state)` and `receive_damage(amount)`.
- Produces: scene groups `party_actors` and `hostile_actors` for runtime target collection.

- [ ] **Step 1: Test planar normalized movement**

Assert that zero input returns `Vector3.ZERO`, `(1,0)` at speed `6` returns `(6,0,0)`, and diagonal input never exceeds speed `6`.

- [ ] **Step 2: Implement `LeaderMovement` and verify tests**

```gdscript
class_name LeaderMovement
extends RefCounted

static func velocity(input_vector: Vector2, speed: float) -> Vector3:
    var limited := input_vector.limit_length(1.0)
    return Vector3(limited.x, 0.0, limited.y) * speed
```

- [ ] **Step 3: Create the actor and leader scenes**

`PartyActor` extends `CharacterBody3D`, owns a child `HealthComponent`, `CollisionShape3D`, colored `MeshInstance3D`, and `AttackController`, and exposes `get_combat_target()`. `Leader` extends `PartyActor`, reads `Input.get_vector("move_left", "move_right", "move_forward", "move_back")`, assigns `velocity` through `LeaderMovement`, calls `move_and_slide()`, and skips movement when downed or the run is paused.

- [ ] **Step 4: Save the arena instead of depending on the unsaved editor scene**

Create `arena.tscn` with a `40 x 0.5 x 30` floor `BoxMesh`, matching `BoxShape3D`, four invisible boundary collision boxes, `PlayerSpawn` at `(0, 0.75, 0)`, and four `EnemySpawnMarker` nodes near the corners. Set collision layers so the floor and boundaries block actors but not attack areas.

- [ ] **Step 5: Create and integrate the camera**

`LeaderCamera` follows its exported target with exponential smoothing, holds rotation `(-55 degrees, 0, 0)`, local position `(0, 18, 14)`, perspective FOV `52`, and never reads input. Update `main.tscn` to instance the arena, leader, and camera.

- [ ] **Step 6: Run tests and the scene for 120 frames**

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64.exe' --path 'F:\Projects(root)\Game dev\Projects\party-forge' --quit-after 120
```

Expected: a visible bounded floor, class-colored leader placeholder, fixed high-angle camera, and no errors.

- [ ] **Step 7: Commit**

```powershell
git add scenes scripts/characters scripts/camera tests/unit/test_leader_movement.gd
git commit -m "feat: add arena leader and camera"
```

---

### Task 8: Role-Based Elastic Companion Formation

**Files:**
- Create: `scripts/formation/formation_math.gd`
- Create: `scripts/characters/companion.gd`
- Create: `scripts/party/party_actor_spawner.gd`
- Create: `scenes/characters/companion.tscn`
- Create: `tests/unit/test_formation_math.gd`

**Interfaces:**
- Produces: `FormationMath.desired_velocity(role, actor_position, leader_position, threat_position, preferred_distance, tether_distance, separation, speed) -> Vector3`.
- Consumes: `PartyManager.member_added` and `ClassDefinition` role distances.

- [ ] **Step 1: Write vector-level formation tests**

Test that a companion beyond tether moves toward the leader, a Fighter between leader and threat advances toward the threat, a Mage inside its preferred distance moves away from the threat, a Cleric remains closer to the leader than a Mage, and separation changes a zero-length desired vector.

- [ ] **Step 2: Verify failure, then implement formation math**

```gdscript
# scripts/formation/formation_math.gd
class_name FormationMath
extends RefCounted

static func desired_velocity(role: ClassDefinition.Role, actor_position: Vector3, leader_position: Vector3, threat_position: Vector3, preferred_distance: float, tether_distance: float, separation: Vector3, speed: float) -> Vector3:
    var actor := Vector3(actor_position.x, 0.0, actor_position.z)
    var leader := Vector3(leader_position.x, 0.0, leader_position.z)
    var threat := Vector3(threat_position.x, 0.0, threat_position.z)
    var desired_point := leader
    if actor.distance_to(leader) > tether_distance:
        desired_point = leader
    else:
        var away_from_threat := (leader - threat).normalized()
        if away_from_threat.is_zero_approx(): away_from_threat = Vector3.BACK
        match role:
            ClassDefinition.Role.FRONTLINE:
                desired_point = leader - away_from_threat * minf(preferred_distance, 3.0)
            ClassDefinition.Role.MIDLINE:
                desired_point = threat + away_from_threat * preferred_distance
            ClassDefinition.Role.BACKLINE:
                desired_point = threat + away_from_threat * preferred_distance
            ClassDefinition.Role.SUPPORT:
                desired_point = leader + away_from_threat * minf(preferred_distance, 4.0)
    var desired := desired_point - actor
    desired += separation.limit_length(1.5)
    desired.y = 0.0
    if desired.length_squared() < 0.01: return Vector3.ZERO
    return desired.normalized() * speed
```

- [ ] **Step 3: Implement the companion scene and party actor spawner**

`Companion._physics_process()` gathers the nearest hostile target, calculates separation from all `party_actors`, requests a velocity from `FormationMath`, and calls `move_and_slide()`. `PartyActorSpawner` listens to `member_added`, ignores the leader record, instances one `companion.tscn`, configures it from the record, and adds it to an actor container. It uses the number of existing companions only for a small spawn offset, never as a permanent formation slot.

- [ ] **Step 4: Run all tests and spawn Fighter/Ranger/Mage/Cleric through a temporary test setup**

Expected: companions return when separated from the leader, do not stack, and maintain visibly different distance bands.

- [ ] **Step 5: Commit**

```powershell
git add scripts/formation scripts/characters scripts/party scenes/characters tests/unit/test_formation_math.gd
git commit -m "feat: add elastic party formation"
```

---

### Task 9: Attack Execution, Projectiles, Area Damage, and Cleric Healing

**Files:**
- Create: `scripts/combat/attack_executor.gd`
- Create: `scripts/combat/projectile.gd`
- Create: `scripts/combat/timed_effect.gd`
- Create: `scripts/combat/healing_selector.gd`
- Create: `scenes/combat/projectile.tscn`
- Create: `scenes/combat/area_burst.tscn`
- Create: `scenes/combat/heal_effect.tscn`
- Modify: `scripts/characters/party_actor.gd`
- Create: `tests/unit/test_attack_execution.gd`

**Interfaces:**
- Consumes: `AttackController.attack_ready(definition, target)`.
- Produces: `HealingSelector.most_injured(living_party, range, origin)` using missing-health percentage.
- Produces: projectiles that carry team, damage, speed, area radius, maximum range, and lifetime.

- [ ] **Step 1: Write combat-rule tests**

Test that healing selects the living actor with the greatest missing-health percentage, excludes downed actors, melee damage reaches only targets inside the cleave radius, projectile lifetime is finite, and Mage area damage reaches two hostiles inside the configured radius but not one outside.

- [ ] **Step 2: Implement `HealingSelector` and attack execution**

`AttackExecutor` switches on `AttackDefinition.Kind`: melee queries hostile actors in the cleave area and applies damage once; projectile instances `projectile.tscn`; area projectile instances a projectile that creates `area_burst.tscn` on impact; heal calls `HealingSelector` and applies `definition.power`. All temporary scenes use a `SceneTreeTimer` or explicit lifetime and queue themselves free.

- [ ] **Step 3: Connect every PartyActor's primary and support controllers**

The primary controller always runs while the actor is available. The Cleric support controller checks for an injured living ally before attacking; when no valid heal exists, the primary holy projectile remains active. Apply class-rank multipliers and active trait modifiers at attack time from read-only PartyManager queries.

- [ ] **Step 4: Run all tests and a headless 600-frame combat smoke scene**

Expected: no orphan-node warnings, no friendly fire, and every temporary projectile/effect exits by lifetime.

- [ ] **Step 5: Commit**

```powershell
git add scripts/combat scripts/characters/party_actor.gd scenes/combat tests/unit/test_attack_execution.gd
git commit -m "feat: execute automatic class attacks"
```

---

### Task 10: Regular Enemies, Experience Orbs, and Escalating Spawns

**Files:**
- Create: `scripts/enemies/enemy_actor.gd`
- Create: `scripts/enemies/swarmer.gd`
- Create: `scripts/enemies/spitter.gd`
- Create: `scripts/enemies/enemy_projectile.gd`
- Create: `scripts/progression/experience_orb.gd`
- Create: `scripts/game/spawn_schedule.gd`
- Create: `scripts/game/spawn_director.gd`
- Create: `scenes/enemies/swarmer.tscn`
- Create: `scenes/enemies/spitter.tscn`
- Create: `scenes/enemies/enemy_projectile.tscn`
- Create: `scenes/progression/experience_orb.tscn`
- Create: `tests/unit/test_spawn_schedule.gd`

**Interfaces:**
- Produces: `SpawnSchedule.sample(elapsed_seconds) -> SpawnBand` with interval, Swarmer weight, and Spitter weight.
- Emits: `EnemyActor.reward_dropped(experience, position)` exactly once.
- Consumes: leader position, `ExperienceSystem`, and arena spawn markers.

- [ ] **Step 1: Test escalation bands**

Use these exact bands: `0-59s` interval `1.25`, weights `100/0`; `60-149s` interval `0.9`, weights `80/20`; `150-239s` interval `0.65`, weights `65/35`; `240-299s` interval `0.45`, weights `55/45`. Assert boundary values and that no ordinary band is returned at `300` seconds.

- [ ] **Step 2: Implement the schedule and verify tests**

```gdscript
# scripts/game/spawn_schedule.gd
class_name SpawnSchedule
extends RefCounted

class SpawnBand extends RefCounted:
    var interval: float
    var swarmer_weight: int
    var spitter_weight: int
    func _init(seconds: float, swarmer: int, spitter: int) -> void:
        interval = seconds; swarmer_weight = swarmer; spitter_weight = spitter

static func sample(elapsed_seconds: float) -> SpawnBand:
    if elapsed_seconds < 0.0 or elapsed_seconds >= 300.0: return null
    if elapsed_seconds < 60.0: return SpawnBand.new(1.25, 100, 0)
    if elapsed_seconds < 150.0: return SpawnBand.new(0.9, 80, 20)
    if elapsed_seconds < 240.0: return SpawnBand.new(0.65, 65, 35)
    return SpawnBand.new(0.45, 55, 45)
```

- [ ] **Step 3: Implement Swarmer and Spitter behavior**

Swarmer moves directly toward the nearest living party actor and applies contact damage on a per-target cooldown. Spitter maintains eight meters from the leader, fires a visible projectile every `2.2` seconds, and retreats when closer than five meters. Both stop acting when dead and emit one reward event.

- [ ] **Step 4: Implement experience drops and collection**

An orb stores its integer value, remains still outside pickup range, accelerates toward the leader within `5.0` meters, is collected within `0.65` meters, adds its value to `ExperienceSystem`, and frees itself. Shared `pickup_radius` upgrades multiply the attraction radius.

- [ ] **Step 5: Implement `SpawnDirector`**

Use a local seeded RNG, choose among arena spawn markers outside the camera view, sample the active band, and instance the weighted enemy scene. Pause its elapsed clock while the scene tree is paused for a level-up. Stop ordinary schedule sampling at `300` seconds.

- [ ] **Step 6: Run tests and a two-minute accelerated spawn smoke test**

Expected: both regular enemy types appear by the accelerated equivalent of 60 seconds and experience collection raises levels.

- [ ] **Step 7: Commit**

```powershell
git add scripts/enemies scripts/progression scripts/game scenes/enemies scenes/progression tests/unit/test_spawn_schedule.gd
git commit -m "feat: add enemies experience and spawns"
```

---

### Task 11: Run State Machine and Forge Guardian Boss

**Files:**
- Create: `scripts/game/run_state_machine.gd`
- Create: `scripts/game/game_run.gd`
- Create: `scripts/enemies/boss_action_schedule.gd`
- Create: `scripts/enemies/forge_guardian.gd`
- Create: `scenes/enemies/forge_guardian.tscn`
- Create: `scenes/effects/danger_ring.tscn`
- Create: `tests/unit/test_run_state_machine.gd`
- Create: `tests/unit/test_boss_action_schedule.gd`

**Interfaces:**
- Produces states: `SETUP`, `RUNNING`, `LEVEL_UP`, `BOSS`, `VICTORY`, and `DEFEAT`.
- Produces: `advance_run_time(delta)`, `begin_level_up()`, `resume_run()`, `leader_defeated()`, and `boss_defeated()`.
- Emits: `boss_requested` once at 300 seconds and one terminal-state signal.

- [ ] **Step 1: Write run-state tests**

Assert that paused level-up time does not advance the run clock, `299.99` seconds remains `RUNNING`, reaching `300.0` requests the boss once, leader defeat produces `DEFEAT`, boss defeat produces `VICTORY`, and neither terminal method can overwrite the other.

- [ ] **Step 2: Implement and verify the state machine**

```gdscript
# scripts/game/run_state_machine.gd
class_name RunStateMachine
extends RefCounted

signal state_changed(state: State)
signal boss_requested
signal victory
signal defeat

enum State { SETUP, RUNNING, LEVEL_UP, BOSS, VICTORY, DEFEAT }
const BOSS_TIME := 300.0
var state: State = State.SETUP
var elapsed: float = 0.0
var terminal_locked: bool = false
var boss_emitted: bool = false

func start() -> void: _set_state(State.RUNNING)

func advance_run_time(delta: float) -> void:
    if state != State.RUNNING or delta <= 0.0: return
    elapsed = minf(BOSS_TIME, elapsed + delta)
    if elapsed >= BOSS_TIME and not boss_emitted:
        boss_emitted = true
        _set_state(State.BOSS)
        boss_requested.emit()

func begin_level_up() -> void:
    if state == State.RUNNING: _set_state(State.LEVEL_UP)

func resume_run() -> void:
    if state == State.LEVEL_UP: _set_state(State.RUNNING)

func leader_defeated() -> void:
    if terminal_locked: return
    terminal_locked = true; _set_state(State.DEFEAT); defeat.emit()

func boss_defeated() -> void:
    if terminal_locked or state != State.BOSS: return
    terminal_locked = true; _set_state(State.VICTORY); victory.emit()

func _set_state(next: State) -> void:
    if next == state: return
    state = next; state_changed.emit(state)
```

`GameRun` adapts these signals to scene actions and sets `get_tree().paused` only for `LEVEL_UP`, `VICTORY`, and `DEFEAT`; its own process mode remains `PROCESS_MODE_ALWAYS`.

- [ ] **Step 3: Test and implement the boss action schedule**

```gdscript
# scripts/enemies/boss_action_schedule.gd
class_name BossActionSchedule
extends RefCounted

enum Action { CHARGE, SHOCKWAVE, SUMMON }
const ACTIONS: Array[Action] = [Action.CHARGE, Action.SHOCKWAVE, Action.SUMMON]
const RECOVERY: Array[float] = [2.0, 2.5, 3.0]
var index: int = 0
var remaining: float = 0.0

func advance(delta: float) -> void:
    remaining = maxf(0.0, remaining - maxf(delta, 0.0))

func take_next() -> int:
    if remaining > 0.0: return -1
    var action: Action = ACTIONS[index]
    remaining = RECOVERY[index]
    index = (index + 1) % ACTIONS.size()
    return action
```

- [ ] **Step 4: Implement the Forge Guardian scene**

Charge telegraphs the leader's sampled position for `0.8` seconds, then moves in that direction for `0.65` seconds. Shockwave displays a six-meter danger ring for `1.0` second before applying damage. Summon requests six Swarmers from `SpawnDirector`. Boss health reaches zero once, emits `boss_defeated`, and disables every pending hit area.

- [ ] **Step 5: Run the complete suite and an accelerated boss smoke run**

Set a debug-only time scale through a command-line feature flag, reach the boss phase, exercise all three actions, and restore ordinary timing before commit. Expected: boss signal once and no simultaneous victory/defeat.

- [ ] **Step 6: Commit**

```powershell
git add scripts/game scripts/enemies scenes/enemies scenes/effects tests/unit/test_run_state_machine.gd tests/unit/test_boss_action_schedule.gd
git commit -m "feat: add boss run phase"
```

---

### Task 12: Level-Up UI, HUD, Visual Feedback, and Main-Scene Integration

**Files:**
- Create: `scripts/ui/hud.gd`
- Create: `scripts/ui/level_up_panel.gd`
- Create: `scripts/ui/run_result_panel.gd`
- Create: `scripts/ui/health_bar_3d.gd`
- Create: `scenes/ui/hud.tscn`
- Create: `scenes/ui/level_up_panel.tscn`
- Create: `scenes/ui/run_result_panel.tscn`
- Create: `scenes/ui/health_bar_3d.tscn`
- Modify: `scripts/game/main.gd`
- Modify: `scenes/game/main.tscn`
- Create: `tests/unit/test_main_wiring.gd`

**Interfaces:**
- Consumes: GameRun state, leader health, boss health, ExperienceSystem, PartyManager, and `UpgradeChoice` values.
- Produces: `LevelUpPanel.choice_selected(choice)` and restart/quit requests.

- [ ] **Step 1: Write the main-wiring resource test**

Assert that the main scene contains nodes named `GameRun`, `PartyManager`, `ExperienceSystem`, `SpawnDirector`, `PartyActorSpawner`, `Arena`, `Actors`, `Enemies`, `Effects`, and `HUD`, and that every required PackedScene path loads.

- [ ] **Step 2: Build the HUD and choice panel**

HUD displays leader health, experience progress, `MM:SS` run time, four party entries, active trait tiers, and a hidden boss health bar. The level-up panel contains three buttons created from the exact three `UpgradeChoice` values, disables invalid selections, emits once, and hides before unpausing.

- [ ] **Step 3: Apply choices through one main-scene method**

```gdscript
# method and state added to scripts/game/main.gd
var party_stats: Dictionary = {
    &"max_health": 0, &"damage": 0, &"move_speed": 0,
    &"attack_speed": 0, &"pickup_radius": 0
}
var trait_upgrade_ranks: Dictionary = {}

func _apply_choice(choice: UpgradeChoice) -> bool:
    var applied := false
    match choice.kind:
        UpgradeChoice.Kind.RECRUIT:
            applied = party_manager.recruit(catalog.class_by_id(choice.target_id))
        UpgradeChoice.Kind.CLASS_RANK:
            applied = party_manager.rank_up(choice.target_id)
        UpgradeChoice.Kind.TRAIT:
            if party_manager.active_tier(choice.target_id) > 0:
                trait_upgrade_ranks[choice.target_id] = int(trait_upgrade_ranks.get(choice.target_id, 0)) + 1
                applied = true
        UpgradeChoice.Kind.PARTY_STAT:
            if party_stats.has(choice.target_id):
                party_stats[choice.target_id] = mini(int(party_stats[choice.target_id]) + 1, 20)
                applied = true
    if not applied:
        push_error("PARTY_FORGE_INVALID_CHOICE kind=%d target=%s" % [choice.kind, choice.target_id])
        return false
    experience_system.consume_pending_level()
    game_run.resume_run()
    return true
```

- [ ] **Step 4: Add placeholder visual communication**

Use class colors from `ClassDefinition`, black/orange enemies, cyan experience orbs, green healing bursts, white damage flashes, red boss danger rings, a gray downed material, billboard health bars, a boss-arrival banner, and full-screen victory/defeat panels. These colors must remain distinct under the fixed camera and Forward+ renderer.

- [ ] **Step 5: Integrate a complete run**

`Main` loads `GameCatalog`, validates it before spawning, creates the chosen leader, wires every system explicitly, starts GameRun, and exposes a simple initial class-selection panel. A catalog error prevents run start and prints `PARTY_FORGE_RESOURCE_ERROR path=<path> reason=<message>`.

- [ ] **Step 6: Run all tests and parser/startup checks**

Expected: every headless suite passes, the project reaches class selection without errors, and selecting a class starts the timer.

- [ ] **Step 7: Commit**

```powershell
git add scripts/ui scripts/game scenes/ui scenes/game tests/unit/test_main_wiring.gd
git commit -m "feat: integrate playable Party Forge run"
```

---

### Task 13: Developer Sandbox and Recorded Acceptance Evidence

**Files:**
- Create: `scripts/dev/combat_sandbox.gd`
- Create: `scenes/dev/combat_sandbox.tscn`
- Create: `docs/validation/party-forge-prototype-validation.md`
- Create: `docs/validation/screenshots/boss-victory.png`
- Create: `docs/validation/screenshots/leader-defeat.png`

**Interfaces:**
- Produces: sandbox actions for spawning each class, each regular enemy, the boss, damaging a selected companion, and clearing hostiles.
- Consumes: the same production scenes and Resources as an ordinary run; no sandbox-only methods are added to production classes.

- [ ] **Step 1: Create the sandbox scene using production interfaces**

The sandbox UI has explicit buttons for Fighter, Ranger, Mage, Cleric, Swarmer, Spitter, Forge Guardian, down selected companion, and clear hostiles. It shows live party size, class ranks, trait counts, and active tiers. It may call public production methods but must not bypass the party cap unless launched with `--editor --path` and the sandbox scene directly.

- [ ] **Step 2: Run the complete automated evidence command**

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64.exe' --headless --path 'F:\Projects(root)\Game dev\Projects\party-forge' --script res://tests/test_runner.gd
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64.exe' --headless --path 'F:\Projects(root)\Game dev\Projects\party-forge' --editor --quit-after 2
```

Expected: zero exit codes, a PASS summary for every suite, and no parser/runtime errors.

- [ ] **Step 3: Run and record the boss-victory acceptance path**

Play an ordinary five-minute run from `main.tscn`. Recruit to four characters with at least one duplicate, activate at least two overlapping traits, observe a companion down and revive, observe Swarmer and Spitter behavior, defeat the Forge Guardian, and save the victory screen as `docs/validation/screenshots/boss-victory.png`.

- [ ] **Step 4: Run and record the defeat acceptance path**

Start a separate ordinary run, allow the leader to die, confirm the defeat state cannot be replaced by victory, and save the defeat screen as `docs/validation/screenshots/leader-defeat.png`.

- [ ] **Step 5: Write the validation report from observed evidence**

The report must contain the engine version string, commit hash, exact automated commands and exit codes, suite count, Godot error count, party composition used, traits activated, down/revive observation, enemy behaviors observed, boss trigger time, victory result, defeat result, and links to both screenshots. Every entry states `PASS`, `FAIL`, or `DEFERRED` with a factual reason; the final milestone is not complete while any required entry is `FAIL` or `DEFERRED`.

- [ ] **Step 6: Review the final diff and commit evidence**

```powershell
git status --short
git diff --check
git add scripts/dev scenes/dev docs/validation
git commit -m "test: record Party Forge prototype validation"
```

- [ ] **Step 7: Verify the committed worktree**

```powershell
git status --short --branch
git log --oneline --decorate -15
```

Expected: a clean `main` worktree with the design commit followed by one focused commit per implementation task.
