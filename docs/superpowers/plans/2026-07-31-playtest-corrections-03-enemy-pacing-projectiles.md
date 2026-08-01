# Enemy Pacing and Projectile Modes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Introduce the red linear-projectile Boltcaster, move purple homing Spitters later, and make 100% density approximate the former 200%–250% intensity.

**Architecture:** `EnemyProjectileProfile` stores movement/presentation properties while the referenced `AttackDefinition` remains authoritative for speed, range, area, and damage. One projectile runtime handles linear segment hits and homing steering. Spawn bands hold three explicit weights and new baseline intervals.

**Tech Stack:** Godot 4.7.1 Mono, typed GDScript, Godot `.tres` Resources and `.tscn` scenes, deterministic spawn tests.

## Global Constraints

- Execute after Plans 01 and 02 pass.
- Boltcaster begins at 60 seconds; Spitter begins at 150 seconds.
- Boltcaster fires red, linear projectiles at a captured player position.
- Spitter fires purple, homing projectiles.
- Projectile speed, range, area, damage, movement profile, and color are authored data.
- Linear projectiles never retarget.
- New 100% intervals target approximately 2.25 times the old enemy count.
- Scheduled spawns remain capped at 64 per update.

---

### Task 1: Enemy Projectile Profile Resource

**Files:**
- Create: `scripts/data/enemy_projectile_profile.gd`
- Modify: `scripts/data/enemy_definition.gd:1-43`
- Create: `tests/unit/test_enemy_projectile_profile.gd`

**Interfaces:**
- Produces enum `EnemyProjectileProfile.Movement { LINEAR, HOMING }`.
- Produces exported fields `movement`, `color`, `hit_radius`, `max_lifetime`, `tell_duration`.
- Adds `EnemyDefinition.projectile_profile: EnemyProjectileProfile`.

- [ ] **Step 1: Write failing validation tests**

```gdscript
extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var profile := EnemyProjectileProfile.new()
	profile.hit_radius = -1.0
	profile.max_lifetime = NAN
	profile.tell_duration = -0.1
	var errors := profile.validate(&"test_enemy")
	TestAssertions.truthy(errors.any(func(value: String) -> bool: return "hit radius" in value), "negative hit radius fails", failures)
	TestAssertions.truthy(errors.any(func(value: String) -> bool: return "lifetime" in value), "non-finite lifetime fails", failures)
	TestAssertions.truthy(errors.any(func(value: String) -> bool: return "tell duration" in value), "negative tell fails", failures)
	var enemy := EnemyDefinition.new()
	enemy.id = &"missing_profile"
	enemy.behavior = EnemyDefinition.Behavior.SPITTER
	TestAssertions.truthy(enemy.validate().any(func(value: String) -> bool: return "projectile profile" in value), "ranged behavior requires profile", failures)
	return failures
```

- [ ] **Step 2: Implement the profile**

```gdscript
class_name EnemyProjectileProfile
extends Resource

enum Movement { LINEAR, HOMING }

@export var movement := Movement.LINEAR
@export var color := Color.RED
@export var hit_radius := 0.45
@export var max_lifetime := 3.0
@export var tell_duration := 0.35

func validate(enemy_id: StringName) -> PackedStringArray:
	var errors := PackedStringArray()
	if movement not in [Movement.LINEAR, Movement.HOMING]:
		errors.append("PARTY_FORGE_PROJECTILE_ERROR enemy=%s reason=invalid movement" % enemy_id)
	if not is_finite(hit_radius) or hit_radius <= 0.0:
		errors.append("PARTY_FORGE_PROJECTILE_ERROR enemy=%s reason=hit radius must be finite and positive" % enemy_id)
	if not is_finite(max_lifetime) or max_lifetime <= 0.0:
		errors.append("PARTY_FORGE_PROJECTILE_ERROR enemy=%s reason=lifetime must be finite and positive" % enemy_id)
	if not is_finite(tell_duration) or tell_duration < 0.0:
		errors.append("PARTY_FORGE_PROJECTILE_ERROR enemy=%s reason=tell duration must be finite and nonnegative" % enemy_id)
	return errors
```

Append `BOLTCASTER` after `FORGE_GUARDIAN` in `EnemyDefinition.Behavior`; do not insert or reorder existing enum members because `.tres` files serialize their integer values. Export `projectile_profile`, require attack IDs `boltcaster_bolt`/`spitter_projectile`, and append profile validation for both ranged behaviors.

- [ ] **Step 3: Run and commit**

```powershell
& $godot --headless --path $worktree --script res://tests/test_runner.gd
git add -- scripts/data/enemy_projectile_profile.gd scripts/data/enemy_definition.gd tests/unit/test_enemy_projectile_profile.gd
git commit -m "feat: define enemy projectile movement profiles"
```

### Task 2: Data-Driven Linear and Homing Projectile Runtime

**Files:**
- Modify: `scripts/enemies/enemy_projectile.gd:1-46`
- Modify: `scenes/enemies/enemy_projectile.tscn`
- Modify: `tests/unit/test_spawn_schedule.gd`
- Modify: `tests/unit/test_enemy_typed_combat.gd`

**Interfaces:**
- Changes `EnemyProjectile.configure(target_actor, prepared_packet, shared_combat_rng, shared_damage_types, attack_definition, profile, aim_position)`.
- Produces inspection fields `movement`, `speed`, `maximum_range`, `area_radius`, `direction`, `distance_travelled`.

- [ ] **Step 1: Add failing movement tests**

Create one linear projectile aimed at `(10, 0, 0)`, move its original target to `(0, 0, 10)`, advance `0.5`, and assert its Z direction remains zero. Create a homing projectile, move the target, advance, and assert it gains positive Z. Assert both expire at attack range and use profile colors.

- [ ] **Step 2: Replace constants with configured data**

Use these fields:

```gdscript
var target: Node3D
var packet: DamagePacket
var combat_rng: CombatRng
var damage_types: DamageTypeCatalog
var movement := EnemyProjectileProfile.Movement.LINEAR
var speed := 0.01
var maximum_range := 0.01
var area_radius := 0.0
var hit_radius := 0.45
var lifetime := 0.1
var elapsed := 0.0
var distance_travelled := 0.0
var direction := Vector3.FORWARD
```

Configure with:

```gdscript
func configure(
	target_actor: Node3D,
	prepared_packet: DamagePacket,
	shared_combat_rng: CombatRng,
	shared_damage_types: DamageTypeCatalog,
	attack: AttackDefinition,
	profile: EnemyProjectileProfile,
	aim_position: Vector3
) -> void:
	target = target_actor
	packet = prepared_packet
	combat_rng = shared_combat_rng
	damage_types = shared_damage_types
	movement = profile.movement
	speed = maxf(attack.projectile_speed, 0.01)
	maximum_range = maxf(attack.range, 0.01)
	area_radius = maxf(attack.area_radius, 0.0)
	hit_radius = maxf(profile.hit_radius, 0.01)
	lifetime = minf(profile.max_lifetime, maximum_range / speed + 0.5)
	elapsed = 0.0
	distance_travelled = 0.0
	direction = (aim_position - _position()).normalized()
	if direction.is_zero_approx():
		direction = Vector3.FORWARD
	_apply_color(profile.color)
```

- [ ] **Step 3: Implement movement and segment collision**

Each update refreshes direction only for `HOMING`, advances no farther than remaining range, and finds the first living party actor whose position-to-segment squared distance is within `hit_radius * hit_radius`. On a hit, resolve the prepared packet; if `area_radius > 0`, resolve all available party adapters inside that radius exactly once.

Use the same point-to-segment calculation already proven in `forge_guardian.gd`, copied as a private projectile helper so the runtime has no dependency on the boss script.

Color implementation duplicates the `MeshInstance3D` material before assigning albedo/emission, preventing one projectile from recoloring all shared instances.

- [ ] **Step 4: Run and commit**

```powershell
& $godot --headless --path $worktree --script res://tests/test_runner.gd
git add -- scripts/enemies/enemy_projectile.gd scenes/enemies/enemy_projectile.tscn tests/unit/test_spawn_schedule.gd tests/unit/test_enemy_typed_combat.gd
git commit -m "feat: support linear and homing enemy projectiles"
```

### Task 3: Boltcaster Content and Telegraph Behavior

**Files:**
- Create: `scripts/enemies/boltcaster.gd`
- Create: `scenes/enemies/boltcaster.tscn`
- Create: `data/enemies/boltcaster.tres`
- Create: `data/attacks/boltcaster_bolt.tres`
- Create: `data/projectiles/boltcaster_bolt.tres`
- Create: `data/projectiles/spitter_orb.tres`
- Modify: `data/enemies/spitter.tres`
- Modify: `scripts/enemies/spitter.gd:1-67`
- Modify: `tests/unit/test_game_catalog.gd`
- Modify: `tests/unit/test_expanded_catalog.gd`
- Modify: `tests/unit/test_spawn_schedule.gd`

**Interfaces:**
- Produces class `Boltcaster` with `configure_target(...)` and `advance_behavior(delta)` matching Spitter's spawn contract.
- Both ranged enemies call the new projectile configure signature.

- [ ] **Step 1: Add failing catalog and behavior tests**

Assert catalog/default resource loading includes Boltcaster with behavior `BOLTCASTER`, attack `boltcaster_bolt`, a `LINEAR` profile, red color, and tell duration `0.35`. Assert Spitter has `HOMING` and purple color. In a behavior fixture, begin Boltcaster fire, move the leader during the tell, and assert the spawned projectile direction still points to the position sampled when the tell began.

- [ ] **Step 2: Author projectile profiles and attacks**

`data/projectiles/boltcaster_bolt.tres` values:

```text
movement = LINEAR
color = Color(1.0, 0.08, 0.05, 1.0)
hit_radius = 0.4
max_lifetime = 3.0
tell_duration = 0.35
```

`data/projectiles/spitter_orb.tres` values:

```text
movement = HOMING
color = Color(0.75, 0.15, 1.0, 1.0)
hit_radius = 0.45
max_lifetime = 3.0
tell_duration = 0.2
```

`boltcaster_bolt.tres` uses physical damage `9`, cooldown `2.4`, range `16`, projectile speed `8`, area `0`, and tags `projectile`, `ranged`.

- [ ] **Step 3: Implement Boltcaster state machine**

Use states `MOVING`, `TELLING`, and fields `leader`, `projectile_parent`, `fire_cooldown`, `tell_remaining`, `sampled_aim_position`. At preferred distance `9` (retreat below `5.5`), stop and begin a tell only when cooldown reaches zero. Capture `sampled_aim_position` at tell start. When the tell ends, spawn the projectile with that position, then reset cooldown from the attack resource.

Only begin a tell when the target is within `attack_geometry(&"boltcaster_bolt").range`. Spitter likewise fires only within `attack_geometry(&"spitter_projectile").range`; both enemies may continue moving toward their preferred distance while outside attack range.

The firing call is:

```gdscript
projectile.configure(
	leader,
	packet,
	combat_rng,
	damage_types,
	attack,
	definition.projectile_profile,
	sampled_aim_position
)
```

Spitter passes the leader's current position and its homing profile through the same signature.

- [ ] **Step 4: Author Boltcaster scene/resource**

Follow `spitter.tscn` structure with a distinct red rectangular/caster silhouette and `data/enemies/boltcaster.tres`: health `15`, move speed `3.1`, experience `3`, Boltcaster behavior, attack/profile references.

- [ ] **Step 5: Register default catalog loading**

Update the catalog/default-data list that currently loads Swarmer, Spitter, and Forge Guardian so Boltcaster is loaded and validated. Do not key behavior off filename strings outside catalog/spawn registration.

- [ ] **Step 6: Run and commit**

```powershell
& $godot --headless --path $worktree --script res://tests/test_runner.gd
git add -- scripts/enemies/boltcaster.gd scenes/enemies/boltcaster.tscn data/enemies/boltcaster.tres data/attacks/boltcaster_bolt.tres data/projectiles/boltcaster_bolt.tres data/projectiles/spitter_orb.tres data/enemies/spitter.tres scripts/enemies/spitter.gd scripts/data/game_catalog.gd tests/unit/test_game_catalog.gd tests/unit/test_expanded_catalog.gd tests/unit/test_spawn_schedule.gd
git commit -m "feat: add telegraphed Boltcaster enemy"
```

### Task 4: Three-Enemy Spawn Bands and Baseline Density

**Files:**
- Modify: `scripts/game/spawn_schedule.gd:1-23`
- Modify: `scripts/game/spawn_director.gd:1-106`
- Modify: `tests/unit/test_spawn_schedule.gd`
- Modify: `tests/unit/test_combat_test_overrides.gd`

**Interfaces:**
- Adds `SpawnBand.boltcaster_weight: int`.
- `SpawnDirector.sample_enemy_id` chooses among all three weights deterministically.

- [ ] **Step 1: Add failing exact-boundary tests**

Assert:

```text
0.000–59.999: interval 0.56, weights 100/0/0
60.000–149.999: interval 0.40, weights 75/25/0
150.000–239.999: interval 0.29, weights 60/32/8
240.000–299.999: interval 0.20, weights 50/35/15
```

Retain null outside `0..300`. Add prescribed RNG/statistical boundary checks proving all three IDs can be selected and invalid weights return empty.

- [ ] **Step 2: Extend SpawnBand and sample data**

```gdscript
class SpawnBand extends RefCounted:
	var interval: float
	var swarmer_weight: int
	var boltcaster_weight: int
	var spitter_weight: int

	func _init(seconds: float, swarmer: int, boltcaster: int, spitter: int) -> void:
		interval = seconds
		swarmer_weight = swarmer
		boltcaster_weight = boltcaster
		spitter_weight = spitter
```

Return the four exact bands listed in Step 1.

- [ ] **Step 3: Register Boltcaster scene and weighted selection**

Preload the scene and calculate cumulative weights:

```gdscript
var swarmer_weight := int(band.get("swarmer_weight"))
var boltcaster_weight := int(band.get("boltcaster_weight"))
var total := swarmer_weight + boltcaster_weight + int(band.get("spitter_weight"))
if total <= 0:
	return &""
var roll := rng.randi_range(1, total)
if roll <= swarmer_weight:
	return &"swarmer"
if roll <= swarmer_weight + boltcaster_weight:
	return &"boltcaster"
return &"spitter"
```

Use an explicit scene dictionary in `spawn_enemy`:

```gdscript
const ENEMY_SCENES := {
	&"swarmer": SWARMER_SCENE,
	&"boltcaster": BOLTCASTER_SCENE,
	&"spitter": SPITTER_SCENE,
}
```

- [ ] **Step 4: Run and commit**

```powershell
& $godot --headless --path $worktree --script res://tests/test_runner.gd
git add -- scripts/game/spawn_schedule.gd scripts/game/spawn_director.gd tests/unit/test_spawn_schedule.gd tests/unit/test_combat_test_overrides.gd
git commit -m "balance: retune early enemy spawn bands"
```

### Task 5: Plan 03 Verification Gate

**Files:**
- Create: `docs/validation/evidence/2026-07-31-plan-03-enemies.log`

- [ ] **Step 1: Automated verification**

```powershell
& $godot --headless --path $worktree --script res://tests/test_runner.gd 2>&1 | Tee-Object -FilePath "$worktree\docs\validation\evidence\2026-07-31-plan-03-enemies.log"
& $godot --headless --path $worktree --editor --quit-after 2
git -C $worktree diff --check
```

- [ ] **Step 2: Manual five-minute run**

At 100% density verify: only Swarmers before 60 seconds; red Boltcaster shots from 60 seconds; no Spitter before 150 seconds; purple Spitter shots after 150 seconds; Boltcaster shots remain on their original line; no new parser/runtime errors.

- [ ] **Step 3: Commit evidence**

Append the factual manual result to the log, then:

```powershell
git add -- docs/validation/evidence/2026-07-31-plan-03-enemies.log
git commit -m "test: record enemy pacing verification"
```
