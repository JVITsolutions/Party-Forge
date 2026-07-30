# 7. Adding an Enemy

> **Handbook version:** Party Forge Typed Combat Task 8 architecture<br>
> **Godot version:** `4.7.1`<br>
> **Last checked:** `2026-07-30`

## What you will learn

- Build an enemy scene that satisfies Party Forge's shared enemy contract.
- Reuse the existing Swarmer behavior without changing production spawning.
- Register a production enemy in the catalog, spawn director, schedule, sandbox, and tests.
- Recognize when a new enemy needs a new behavior script rather than new data alone.
- Verify targeting, damage, rewards, cleanup, and transient hostile effects.
- Roll back an enemy without leaving broken Resource or scene references.

## The EnemyActor contract

Party Forge enemies are `CharacterBody3D` scenes whose scripts extend `scripts/enemies/enemy_actor.gd`. The base class supplies the shared combat contract; the attached scene script supplies movement and attacks.

A conforming enemy must:

1. Have a `HealthComponent` child. `EnemyActor.configure()` applies `EnemyDefinition.max_health`, connects health and death signals, and reports `PARTY_FORGE_ENEMY_HEALTH_MISSING` when the child is absent.
2. Belong to the `hostile_actors` group and report hostile team ID `2` through `get_combat_target()`.
3. Receive an `EnemyDefinition` through its exported `definition` property, then call or inherit `configure()` before combat.
4. Receive explicit combat RNG/type dependencies and a stable `enemy:<sequence>` ID through `configure_combat()`.
5. Expose action-aware combat adapters and prepare/resolve authored attacks through `DamageResolver`.
6. Return a combat-target record that becomes unavailable after death.
7. Emit exactly one `reward_dropped(experience, position)` signal on defeat.
8. Stop moving, complete defeat once, and `queue_free()` itself.

`EnemyActor` guards both defeat handling and reward emission. Keep those guards when extending it; otherwise two damage events in the same frame can pay twice.

> **Godot rule:** `CharacterBody3D` is a script-driven physics body. Set its `velocity` and call `move_and_slide()` during physics processing; do not multiply the velocity itself by `delta`.

> **Party Forge convention:** All hostile actors join `hostile_actors`, use team ID `2`, expose combat targets plus typed adapters, route damaging gameplay through `DamageResolver`, and route terminal health through `EnemyActor.defeat()`.

> **Current limitation:** The contract depends on specific child names, especially `HealthComponent` and `MeshInstance3D`. Renaming or nesting those nodes requires coordinated script and test changes.

## Current enemy data and behavior split

An `EnemyDefinition` contains identity and tuning data: ID, behavior enum, maximum health, movement speed, typed stat overrides, linked authored attacks, and experience. It does not execute that behavior.

The current scenes make the split visible:

| Scene | Attached script | Result |
| --- | --- | --- |
| `scenes/enemies/swarmer.tscn` | `scripts/enemies/swarmer.gd` | Chases the nearest living party actor and resolves its linked `swarmer_contact` attack. |
| `scenes/enemies/spitter.tscn` | `scripts/enemies/spitter.gd` | Maintains range and fires hostile projectiles. |

Both scripts extend `EnemyActor`. Both scenes also assign their matching definition, health component, visible mesh, and collision shape.

> **Important:** Setting `behavior = SWARMER` does not choose `swarmer.gd`. The script attached to the instantiated scene determines what runs. The enum is validated data and descriptive metadata in the current architecture.

## Training Brute specification

Use this exact disposable definition throughout the chapter:

| Property | Value |
| --- | --- |
| Resource path | `data/training/training_brute.tres` |
| `id` | `training_brute` |
| `behavior` | `SWARMER` |
| `max_health` | `40.0` |
| `move_speed` | `3.5` |
| `attacks` | `[training_brute_contact]` |
| `experience` | `5` |

Create `data/training/training_brute_contact.tres` as an `AttackDefinition` with exact ID `swarmer_contact`, kind `DIRECT`, Physical base amount `12.0`, cooldown `0.8`, range `0.9`, tags `[melee, contact]`, and `can_crit = false`. The exact ID is required because the reused Swarmer behavior requests `swarmer_contact`.

The path is repository-relative; Godot displays it as `res://data/training/training_brute.tres`.

## Track A: sandbox an enemy using Swarmer behavior

This track proves the content in a disposable harness. It does not add the enemy to ordinary waves.

### Create the Resources

1. In the FileSystem dock, create `res://data/training/` if it does not exist.
2. Duplicate `res://data/attacks/swarmer_contact.tres` into the training folder as `training_brute_contact.tres`. Keep ID `swarmer_contact`, type `physical`, cooldown `0.8`, range `0.9`, and tags `melee`/`contact`; change only the component base amount to `12.0`.
3. Right-click the folder, choose **Create New > Resource**, select `EnemyDefinition`, and save it as `training_brute.tres`.
4. Enter every enemy value from the specification. Select `SWARMER` from the Behavior list and link `training_brute_contact.tres` in the `Attacks` array.
5. Save, close, and reopen both Resources. Confirm their Inspector paths and values, then run both validators against the baseline damage/stat catalogs.

### Make a disposable enemy scene

1. Duplicate `res://scenes/enemies/swarmer.tscn` as `res://scenes/dev/training_brute.tscn`.
2. Open the duplicate and rename its root to `TrainingBrute`.
3. Drag `training_brute.tres` onto the root's `Definition` property.
4. Leave the root script as `scripts/enemies/swarmer.gd`. That attachment is what gives the brute Swarmer movement and contact attacks.
5. Optionally change the existing `MeshInstance3D` material color so the training enemy is easy to identify. Do not change its collision yet.

### Put it only in a disposable combat sandbox

1. Duplicate `res://scenes/dev/combat_sandbox.tscn` as `res://scenes/dev/training_brute_sandbox.tscn`.
2. Open the duplicate and instantiate `training_brute.tscn` under its `Enemies` node. Place the instance away from the party's initial position.
3. In the Node dock, select the Training Brute's `reward_dropped` signal. Connect it to the sibling `SpawnDirector` node and use its existing `_on_reward_dropped` receiver method. This gives the disposable instance the same experience-orb handling as director-spawned enemies.
4. Run the current scene with **F6**. Do not add `training_brute` to `GameCatalog`, `SpawnDirector`, or `SpawnSchedule` for Track A.

Observe all of the following:

- It selects a living party actor and closes distance at the slower training speed.
- Contact prepares the authored Physical packet and resolves up to `12.0` before the target's armor, resistance, Vanguard, dodge, and block rules.
- Its health starts at `40.0`, damaging party attacks reach its typed combat adapter, and terminal health triggers death once.
- Defeat emits one reward of `5` experience, produces one experience orb under `Effects`, and removes the enemy.
- **Clear Hostiles** removes the enemy and any hostile transient effects.

Use the Remote scene tree while the sandbox runs to confirm the assigned definition, `HealthComponent`, group membership, and cleanup. Then stop and delete the two disposable scenes, the training Resource, and only the generated UID files that belong to them.

> **Checkpoint:** `git status --short` should return to its pre-exercise state after Track A cleanup. The normal game must never spawn the Training Brute.

## Track B: register an enemy for production spawning

Production registration is a coordinated change. A scene file alone is neither cataloged nor spawnable.

1. Move the reviewed enemy scene to a permanent path such as `scenes/enemies/training_brute.tscn`; keep its `EnemyActor`-derived script, `HealthComponent`, collision, definition, and hostile group.
2. Move its attack and enemy definition to permanent data paths, preserve the exact behavior-required attack ID, then add the definition path to `GameCatalog.ENEMY_PATHS` in `scripts/data/game_catalog.gd`.
3. In `scripts/game/spawn_director.gd`, preload the new scene, accept `&"training_brute"` in the ID guard, and select that scene for the new ID. Preserve both existing `swarmer` and `spitter` branches.
4. Add a Training Brute action to `scenes/dev/combat_sandbox.tscn` and wire it in `scripts/dev/combat_sandbox.gd`. Use an explicit ID-to-button path for an underscored ID; do not assume `capitalize()` will match a node named `TrainingBrute`.
5. Extend the catalog, spawn-director, schedule, and sandbox contract tests for the new ID, scene, button, reward connection, and definition values.

Ordinary wave selection also requires deliberate schedule work. `scripts/game/spawn_schedule.gd` currently models only `swarmer_weight` and `spitter_weight`, and `SpawnDirector.sample_enemy_id()` totals only those two fields. Every current time band therefore samples only `swarmer` or `spitter`.

Adding a third weighted enemy is a behavior and architecture change, not a one-line data registration. Add a typed `training_brute_weight` field to `SpawnBand`, update its constructor and every band, include the weight in total and threshold calculations, and add deterministic boundary tests. Decide the intended weight for every band, including zero-weight bands, rather than relying on a default that hides an omission.

> **Current limitation:** `SpawnSchedule` is a two-enemy data structure and `SpawnDirector` has hard-coded scene selection. Neither discovers registered enemies automatically.

## Track C: implement genuinely new behavior

Create a focused behavior script when the enemy's movement or attack cannot be expressed by an existing scene script. Examples include charging, summoning, orbiting, area denial, or retreat rules different from the Spitter.

1. Start from a small scene that keeps the `EnemyActor` root contract.
2. Attach a new script that extends `EnemyActor`; do not copy its health, targeting, reward, or defeat implementation.
3. Implement movement and attack decisions in a focused method called from `_physics_process(delta)`; use `prepare_attack(id)` and `resolve_attack(packet, adapter)` instead of scalar damage.
4. Reuse `living_party_actors()` and `CombatTarget` data instead of searching arbitrary nodes by name.
5. Keep the enemy in `hostile_actors`. Put spawned hostile projectiles and telegraphs in `hostile_transient_effects` so victory, defeat, and sandbox clearing cancel them.
6. Give every projectile or effect finite lifetime ownership and cleanup on impact, invalid target, cancellation, or timeout.
7. Add deterministic tests for target choice, movement boundaries, cooldowns, damage, reward-once behavior, and effect cleanup before adding schedule weight.

The Spitter is a useful reference for a ranged loop and `scenes/enemies/enemy_projectile.tscn` is a useful reference for transient ownership. Reuse their contracts, not necessarily their exact numbers.

## Health, teams, targeting, rewards, and transient effects

- **Health:** Configure the named `HealthComponent` from the enemy definition. `DamageResolver` applies final resolved damage through the combat adapter; terminal health reaches `defeat()`. `HealthComponent.apply_damage()` is reserved for focused health-state setup/tests, not gameplay delivery.
- **Teams:** Enemies use hostile team ID `2`. `living_party_actors()` searches the `party_actors` group, rejects unavailable combat targets and any target that also reports hostile team ID `2`, and leaves eligible non-hostile party actors for enemy selection.
- **Targeting:** `living_party_actors()` queries the `party_actors` group and excludes unavailable targets. A behavior script chooses among that valid set.
- **Rewards:** The enemy emits one `reward_dropped` signal. `SpawnDirector` owns converting that event into an experience orb under the scene's `Effects` container.
- **Cleanup:** The enemy owns its defeat cleanup. Each projectile or telegraph owns its normal lifetime; the game additionally clears the `hostile_transient_effects` group when combat ends.

Do not make an enemy directly edit progression totals, search for the HUD, or free arbitrary siblings. Those responsibilities belong to the reward receiver and scene owner.

## Tests and sandbox verification

Use this order for a production enemy:

1. Load and validate its `EnemyDefinition` in isolation.
2. Test the scene contract: derived script, named health child, collision, hostile group, and assigned definition.
3. Test movement and attack behavior with fixed positions and controlled physics steps.
4. Execute an authored attack through the enemy behavior API, then test terminal health, one reward, correct experience value, and one cleanup. Use `HealthComponent.apply_damage()` only when the test is explicitly setting up health state rather than testing gameplay delivery.
5. Test `GameCatalog.ENEMY_PATHS` and exact generated definition values.
6. Test every accepted `SpawnDirector` ID, rejected IDs, selected scene, signal connection, and reward orb creation.
7. Test schedule boundary times, zero and nonzero weights, and deterministic sample thresholds.
8. Run `scenes/dev/combat_sandbox.tscn` with **F6**. Spawn each enemy, clear hostiles, and inspect both `Enemies` and `Effects` in the Remote tree.
9. Run the full suite once before committing, then inspect `git diff --check` and `git status --short`.

## Common mistakes

- Treating `EnemyDefinition.behavior` as a script factory.
- Creating the definition and assuming the catalog scans `data/`.
- Registering the definition but not teaching `SpawnDirector` its scene and ID.
- Adding a third schedule weight without updating every band, total, threshold, and test.
- Copying `EnemyActor` logic into a behavior script and losing reward-once guards.
- Omitting or renaming `HealthComponent`, `MeshInstance3D`, or the hostile group.
- Making a projectile hostile without adding it to `hostile_transient_effects`.
- Leaving a projectile, telegraph, or timer with no lifetime owner.
- Testing only that a scene loads instead of observing movement, damage, rewards, and cleanup.
- Leaving disposable training scenes, Resources, connections, or generated UID files in the commit.

## Rollback

Remove references before targets:

1. Remove the new enemy's weights and sampling branches from `SpawnSchedule` and `SpawnDirector`, restore every band and deterministic schedule test, and remove its sandbox action.
2. Remove its scene preload, accepted ID, and selection branch from `SpawnDirector`.
3. Remove its path from `GameCatalog.ENEMY_PATHS` and restore catalog counts and fixture rows.
4. Remove the associated production tests only where the production behavior no longer exists; keep general contract coverage.
5. Run a headless project parse and focused catalog, spawn, schedule, sandbox, and enemy tests while the target Resource and scene still exist. This proves no required code references them.
6. Delete the enemy scene, enemy/attack definitions, behavior script if unique, and only their generated UID files.
7. Run the focused tests and full suite again. Inspect for remaining `training_brute` references and confirm the normal game and combat sandbox load.

Deleting the scene or definition first leaves broken preloads and Resource paths, which can prevent the project from parsing far enough to report the real rollback mistake.

## Official Godot references

- [CharacterBody3D](https://docs.godotengine.org/en/4.7/classes/class_characterbody3d.html)
- [Collision shapes (3D)](https://docs.godotengine.org/en/4.7/tutorials/physics/collision_shapes_3d.html)
- [Groups](https://docs.godotengine.org/en/4.7/tutorials/scripting/groups.html)
- [Scene organization](https://docs.godotengine.org/en/4.7/tutorials/best_practices/scene_organization.html)
