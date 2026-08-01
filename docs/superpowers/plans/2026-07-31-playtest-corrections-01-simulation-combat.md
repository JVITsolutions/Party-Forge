# Simulation Pause and Combat Geometry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop run time during every blocking modal and make `range` and `area_radius` mean the same thing across current party and enemy attacks.

**Architecture:** `GameRun` exposes one automatic-simulation eligibility check used by its always-processing clock. A small immutable `ResolvedAttackGeometry` helper computes effective range and area from attack data and modifiers; party targeting, impact execution, support actions, and current enemy geometry consume that result.

**Tech Stack:** Godot 4.7.1 Mono, typed GDScript, Godot Resources, custom headless GDScript tests.

## Global Constraints

- Execute after the baseline preservation gate in `2026-07-31-playtest-corrections-execution-index.md`.
- Preserve the saved Rogue Flurry resource values: `range = 2.0`, `area_radius = 0.9`.
- `range` never aliases or derives from `area_radius`.
- Melee area is centered on the primary target impact point.
- The valid primary target is always hit, including when `area_radius == 0.0`.
- Enemy geometry gains modifier hooks, not a full enemy progression architecture.

---

### Task 1: Automatic Run-Clock Pause Contract

**Files:**
- Modify: `scripts/game/game_run.gd:21-38`
- Create: `tests/unit/test_game_run_pause_clock.gd`

**Interfaces:**
- Produces: `GameRun.can_advance_automatically(tree: SceneTree = null) -> bool`
- Preserves: `GameRun.advance_run_time(delta: float) -> void` as the explicit deterministic/test hook.

- [ ] **Step 1: Write the failing clock tests**

Create `tests/unit/test_game_run_pause_clock.gd`:

```gdscript
extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var tree := Engine.get_main_loop() as SceneTree
	tree.paused = false
	var run := GameRun.new()
	run.start_run()
	run.call("_process", 1.0)
	TestAssertions.near(run.elapsed_time(), 1.0, 0.001, "RUNNING automatic clock advances", failures)
	tree.paused = true
	run.call("_process", 3.0)
	TestAssertions.near(run.elapsed_time(), 1.0, 0.001, "tree pause blocks automatic clock", failures)
	tree.paused = false
	run.begin_level_up()
	run.call("_process", 2.0)
	TestAssertions.near(run.elapsed_time(), 1.0, 0.001, "LEVEL_UP blocks automatic clock", failures)
	run.resume_run()
	run.advance_run_time(RunStateMachine.BOSS_TIME)
	var before_boss_tick := run.elapsed_time()
	run.call("_process", 0.5)
	TestAssertions.near(run.elapsed_time(), before_boss_tick + 0.5, 0.001, "BOSS automatic clock advances", failures)
	tree.paused = false
	run.free()
	return failures
```

- [ ] **Step 2: Run the suite and confirm the pause assertion fails**

```powershell
& $godot --headless --path $worktree --script res://tests/test_runner.gd
```

Expected: `test_game_run_pause_clock.gd` reports that the tree pause did not block the automatic clock.

- [ ] **Step 3: Implement the automatic eligibility check**

Replace `GameRun._process` and add the helper:

```gdscript
func _process(delta: float) -> void:
	if can_advance_automatically():
		advance_run_time(delta)

func can_advance_automatically(tree: SceneTree = null) -> bool:
	var active_tree := tree if tree != null else Engine.get_main_loop() as SceneTree
	if active_tree != null and active_tree.paused:
		return false
	return current_state() in [
		RunStateMachineScript.State.RUNNING,
		RunStateMachineScript.State.BOSS,
	]
```

- [ ] **Step 4: Run focused/full tests**

Run the full runner. Expected: the new pause suite passes; any remaining failures match the recorded baseline Rogue expectations only.

- [ ] **Step 5: Commit the pause contract**

```powershell
git add -- scripts/game/game_run.gd tests/unit/test_game_run_pause_clock.gd
git commit -m "fix: stop run clock during blocking pauses"
```

### Task 2: Resolved Attack Geometry Value Object

**Files:**
- Create: `scripts/combat/resolved_attack_geometry.gd`
- Create: `tests/unit/test_resolved_attack_geometry.gd`

**Interfaces:**
- Produces: `ResolvedAttackGeometry.new(effective_range: float, effective_area_radius: float)`
- Produces: `ResolvedAttackGeometry.from_attack(definition: AttackDefinition, range_multiplier: float = 1.0, area_multiplier: float = 1.0) -> ResolvedAttackGeometry`
- Produces: public read-only-by-convention fields `range: float`, `area_radius: float`.

- [ ] **Step 1: Write failing geometry tests**

```gdscript
extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	var attack := AttackDefinition.new()
	attack.id = &"geometry_test"
	attack.kind = AttackDefinition.Kind.MELEE_CLEAVE
	attack.range = 2.0
	attack.area_radius = 0.9
	var geometry := ResolvedAttackGeometry.from_attack(attack, 1.5, 2.0)
	TestAssertions.near(geometry.range, 3.0, 0.001, "range multiplier scales range only", failures)
	TestAssertions.near(geometry.area_radius, 1.8, 0.001, "area multiplier scales area only", failures)
	var fallback := ResolvedAttackGeometry.from_attack(attack, NAN, -4.0)
	TestAssertions.near(fallback.range, 2.0, 0.001, "invalid range multiplier falls back to one", failures)
	TestAssertions.near(fallback.area_radius, 0.0, 0.001, "negative area multiplier clamps safely", failures)
	return failures
```

- [ ] **Step 2: Run and verify the missing class failure**

Expected: parser/load failure names `ResolvedAttackGeometry` as missing.

- [ ] **Step 3: Implement the immutable geometry helper**

```gdscript
class_name ResolvedAttackGeometry
extends RefCounted

@warning_ignore("shadowed_global_identifier")
var range: float
var area_radius: float

func _init(effective_range: float, effective_area_radius: float) -> void:
	range = maxf(effective_range, 0.0)
	area_radius = maxf(effective_area_radius, 0.0)

static func from_attack(
	definition: AttackDefinition,
	range_multiplier: float = 1.0,
	area_multiplier: float = 1.0
) -> ResolvedAttackGeometry:
	if definition == null:
		return ResolvedAttackGeometry.new(0.0, 0.0)
	var safe_range_multiplier := range_multiplier if is_finite(range_multiplier) and range_multiplier >= 0.0 else 1.0
	var safe_area_multiplier := area_multiplier if is_finite(area_multiplier) and area_multiplier >= 0.0 else 0.0
	return ResolvedAttackGeometry.new(
		definition.range * safe_range_multiplier,
		definition.area_radius * safe_area_multiplier
	)
```

- [ ] **Step 4: Run the full suite and commit**

```powershell
& $godot --headless --path $worktree --script res://tests/test_runner.gd
git add -- scripts/combat/resolved_attack_geometry.gd tests/unit/test_resolved_attack_geometry.gd
git commit -m "feat: centralize resolved attack geometry"
```

### Task 3: Party Acquisition and Target-Centered Melee

**Files:**
- Modify: `scripts/characters/party_actor.gd:133-144,227-238`
- Modify: `scripts/combat/attack_executor.gd:18-65`
- Modify: `tests/unit/test_attack_execution.gd`
- Modify: `tests/unit/test_attack_damage_data.gd`
- Modify: `tests/unit/test_game_catalog.gd`

**Interfaces:**
- Consumes: `ResolvedAttackGeometry.from_attack(...)` from Task 2.
- Changes internal executor signature to `_execute_melee(packet: DamagePacket, primary_target: CombatTarget, radius: float) -> void`.

- [ ] **Step 1: Add failing Rogue acquisition and target-centered cleave tests**

Extend `test_attack_execution.gd` with a fixture that places the Rogue at `Vector3.ZERO`, its primary hostile at `Vector3(1.9, 0, 0)`, one secondary at `Vector3(2.7, 0, 0)`, and another hostile at `Vector3(-0.4, 0, 0)`. Assert:

```gdscript
rogue.call("advance_combat", 0.1, candidates)
TestAssertions.truthy(primary_health.current_health < 100.0, "Rogue range 2.0 acquires primary", failures)
TestAssertions.truthy(near_primary_health.current_health < 100.0, "cleave uses 0.9 around impact", failures)
TestAssertions.near(behind_rogue_health.current_health, 100.0, 0.001, "cleave is not centered on attacker", failures)
```

Add a zero-area melee fixture and assert the primary target still takes damage while a colocated secondary does not.

- [ ] **Step 2: Run and verify current Rogue behavior fails**

Expected: the target at `1.9` is not acquired because current code substitutes `area_radius` for range.

- [ ] **Step 3: Use resolved range for primary and support acquisition**

Replace PartyActor's support and primary geometry calculation with:

```gdscript
var support_geometry := ResolvedAttackGeometry.from_attack(
	support_controller.definition,
	float(modifiers.get("range_multiplier")),
	float(modifiers.get("area_multiplier"))
)
var heal_target := HealingSelectorScript.most_injured(allies, support_geometry.range, combat_origin)
```

Replace `_try_primary_attack` with:

```gdscript
func _try_primary_attack(controller: AttackController, candidates: Array[CombatTarget], range_multiplier: float, area_multiplier: float) -> void:
	if controller == null or controller.definition == null or controller.cooldown_remaining > 0.0:
		return
	var origin := global_position if is_inside_tree() else position
	var geometry := ResolvedAttackGeometry.from_attack(controller.definition, range_multiplier, area_multiplier)
	var target := TargetSelector.nearest(origin, candidates, geometry.range, team_id)
	if target == null:
		return
	controller.cooldown_remaining = controller.definition.cooldown
	controller.attack_ready.emit(controller.definition, target)
```

- [ ] **Step 4: Center melee execution on the primary target**

Change the executor dispatch:

```gdscript
var geometry := ResolvedAttackGeometry.from_attack(
	definition,
	float(modifiers.get("range_multiplier")),
	float(modifiers.get("area_multiplier"))
)
match definition.kind:
	AttackDefinition.Kind.MELEE_CLEAVE:
		_execute_melee(packet, target, geometry.area_radius)
	AttackDefinition.Kind.PROJECTILE, AttackDefinition.Kind.AREA_PROJECTILE:
		_spawn_projectile(definition, target, modifiers, packet, geometry)
```

Change `_spawn_projectile` to accept `geometry: ResolvedAttackGeometry` and use `geometry.range` for maximum travel and `geometry.area_radius` for impact area. Keep projectile-speed scaling independent through `projectile_multiplier`.

Replace `_execute_melee` with:

```gdscript
func _execute_melee(packet: DamagePacket, primary_target: CombatTarget, radius: float) -> void:
	if primary_target == null or not primary_target.is_available or primary_target.team_id == owner_actor.team_id:
		return
	var seen: Dictionary = {}
	var targets: Array[CombatantAdapter] = []
	for actor: Node3D in _combatants():
		if actor == null or seen.has(actor.get_instance_id()) or not actor.has_method("get_combat_target") or not actor.has_method("get_combat_adapter"):
			continue
		seen[actor.get_instance_id()] = true
		var candidate := actor.call("get_combat_target") as CombatTarget
		if candidate == null or not candidate.is_available or candidate.team_id == owner_actor.team_id:
			continue
		var is_primary := candidate.actor == primary_target.actor
		if not is_primary and (radius <= 0.0 or primary_target.position.distance_squared_to(candidate.position) > radius * radius):
			continue
		var adapter := actor.call("get_combat_adapter", packet.action_tags) as CombatantAdapter
		if adapter != null and adapter.available and adapter.team_id != packet.source_team_id:
			targets.append(adapter)
	targets.sort_custom(func(left: CombatantAdapter, right: CombatantAdapter) -> bool:
		return String(left.combatant_id) < String(right.combatant_id)
	)
	for adapter: CombatantAdapter in targets:
		DamageResolver.resolve(packet, adapter, party_manager.combat_rng, party_manager.damage_types)
```

- [ ] **Step 5: Reconcile intentionally saved Rogue expectations**

Update exact resource assertions from `1.6` to `2.0` only where they describe `data/attacks/rogue_flurry.tres`. Keep `area_radius == 0.9` assertions unchanged.

- [ ] **Step 6: Run and commit**

```powershell
& $godot --headless --path $worktree --script res://tests/test_runner.gd
git add -- scripts/characters/party_actor.gd scripts/combat/attack_executor.gd tests/unit/test_attack_execution.gd tests/unit/test_attack_damage_data.gd tests/unit/test_game_catalog.gd
git commit -m "fix: separate attack range from impact area"
```

### Task 4: Current Enemy Geometry Hooks

**Files:**
- Modify: `scripts/enemies/enemy_actor.gd:57-73`
- Modify: `scripts/enemies/swarmer.gd:1-45`
- Modify: `scripts/enemies/forge_guardian.gd:120-172`
- Modify: `tests/unit/test_enemy_typed_combat.gd`

**Interfaces:**
- Produces: `EnemyActor.attack_geometry(attack_id: StringName) -> ResolvedAttackGeometry`.
- Uses enemy resolved stat values `attack_range` and `area_size` as multipliers, with a safe default of `1.0`.

- [ ] **Step 1: Add failing enemy parity tests**

Create an enemy definition with `stat_overrides = {&"attack_range": 1.5, &"area_size": 2.0}` and an attack with `range = 2.0`, `area_radius = 1.0`. Assert:

```gdscript
var geometry := enemy.call("attack_geometry", &"test_attack") as ResolvedAttackGeometry
TestAssertions.near(geometry.range, 3.0, 0.001, "enemy attack_range scales range", failures)
TestAssertions.near(geometry.area_radius, 2.0, 0.001, "enemy area_size scales area", failures)
```

Add boundary assertions proving Swarmer uses resolved range and Guardian shockwave uses resolved area.

- [ ] **Step 2: Implement the enemy helper**

Add to `enemy_actor.gd`:

```gdscript
func attack_geometry(attack_id: StringName) -> ResolvedAttackGeometry:
	var attack := definition.attack_by_id(attack_id) if definition != null else null
	if attack == null:
		return ResolvedAttackGeometry.new(0.0, 0.0)
	var adapter := get_combat_adapter(DamageResolver.action_tags_for(attack))
	var range_multiplier := adapter.stat_value(&"attack_range", 1.0) if adapter != null else 1.0
	var area_multiplier := adapter.stat_value(&"area_size", 1.0) if adapter != null else 1.0
	return ResolvedAttackGeometry.from_attack(attack, range_multiplier, area_multiplier)
```

Use `attack_geometry(&"swarmer_contact").range` for Swarmer contact and `attack_geometry(&"guardian_shockwave").area_radius` for Guardian shockwave. Preserve Guardian charge's swept collision interpretation while sourcing its width from `attack_geometry(&"guardian_charge").range`.

- [ ] **Step 3: Run focused/full tests and commit**

```powershell
& $godot --headless --path $worktree --script res://tests/test_runner.gd
git add -- scripts/enemies/enemy_actor.gd scripts/enemies/swarmer.gd scripts/enemies/forge_guardian.gd tests/unit/test_enemy_typed_combat.gd
git commit -m "fix: normalize enemy attack geometry"
```

### Task 5: Plan 01 Verification Gate

**Files:**
- Create: `docs/validation/evidence/2026-07-31-plan-01-simulation-combat.log`

- [ ] **Step 1: Run test and parser/import verification**

```powershell
& $godot --headless --path $worktree --script res://tests/test_runner.gd 2>&1 | Tee-Object -FilePath "$worktree\docs\validation\evidence\2026-07-31-plan-01-simulation-combat.log"
& $godot --headless --path $worktree --editor --quit-after 2
git -C $worktree diff --check
```

Expected: full suite passes, parser/import exits `0`, and `git diff --check` is silent.

- [ ] **Step 2: Commit verification evidence**

```powershell
git add -- docs/validation/evidence/2026-07-31-plan-01-simulation-combat.log
git commit -m "test: record simulation and combat verification"
```
