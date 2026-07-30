# 10. Party Forge Architecture Reference

> **Runtime architecture:** Party Forge Typed Combat Task 8 at `97f05b5fa77d8447830bb2a42209b83140384e6b`<br>
> **Godot version:** `4.7.1`<br>
> **Last checked:** `2026-07-30`

## How to use this reference

Use this chapter after you understand the concepts in Chapters 1–9. Start with the change-owner decision table, follow its path to the owning data, scene, or script, then use the matching verification checklist.

This is a map of the architecture after Typed Combat Task 8, not a promise that every folder is automatically discovered or every exported field is consumed. Confirm the live source before extending it.

> **Party Forge convention:** Data definitions describe content, scenes compose runtime nodes, focused scripts own behavior, and `PartyForgeMain` wires the main run.

## Top-level project map

| Path | Purpose |
| --- | --- |
| `data/` | External `.tres` definitions for attacks, classes, enemies, traits, and upgrade tuning |
| `scenes/` | Saved node trees for the main game, actors, enemies, combat effects, UI, arena, camera, progression, and developer sandbox |
| `scripts/` | Typed GDScript behavior and data classes, organized by gameplay responsibility |
| `tests/` | Custom headless runner, assertions, and the discoverable unit suites in `tests/unit/` |
| `tools/` | One-off data generation and validation scripts; not ordinary runtime systems |
| `docs/` | Handbook, development guidance, design/plan records, and validation evidence |
| `project.godot` | Main scene, display/stretch settings, input actions, renderer, and project identity |

The configured main scene is `res://scenes/game/main.tscn`. There is no `[autoload]` section in the verified `project.godot`; Party Forge's service-like nodes are children of the main scene, not global autoload singletons.

## Runtime scene tree

The saved main tree begins as:

1. `Main` — scripted by `PartyForgeMain`.
2. `Main/GameRun` — owns run-state transitions.
3. `Main/PartyManager` — owns party composition, ranks, traits, and upgrades.
4. `Main/ExperienceSystem` — owns experience and pending level-ups.
5. `Main/SpawnDirector` — owns timed regular-enemy spawning and reward-orb creation.
6. `Main/PartyActorSpawner` — creates companions after recruitment.
7. `Main/Arena` — instanced arena, player start, and enemy spawn markers.
8. `Main/Actors` — runtime leader and companions.
9. `Main/Enemies` — runtime regular enemies and boss.
10. `Main/Effects` — projectiles, area bursts, heal visuals, experience orbs, and boss telegraphs.
11. `Main/LeaderCamera` — follows the selected leader.
12. `Main/HUD` — status, class selection, level-up panel, run-result panel, and boss banner.

After leader selection, `PartyForgeMain` instances `Leader` under `Actors`, configures it from a `ClassDefinition`, attaches one `HealthBar3D`, configures the camera and spawn director, hides class selection, and starts the run. Recruits create `Companion` instances under `Actors`; enemies and effects appear only at runtime. Use the Remote tree to see them.

## System ownership table

| Owner | File | Owns | Does not own |
| --- | --- | --- | --- |
| `PartyForgeMain` | `scripts/game/main.gd` | Catalog gate, leader selection, service wiring, level-up application, boss creation, runtime health bars, result UI, hostile-effect cancellation | Definition values or low-level combat math |
| `GameRun` | `scripts/game/game_run.gd` | Run-state facade, pause policy, elapsed-time forwarding, debug time scale, victory/defeat signals | Enemy weights or UI layout |
| `RunStateMachine` | `scripts/game/run_state_machine.gd` | `SETUP`, `RUNNING`, `LEVEL_UP`, `BOSS`, `VICTORY`, `DEFEAT`; five-minute boss transition; terminal lock | Scene instancing |
| `PartyManager` | `scripts/party/party_manager.gd` | Members, class ranks, trait counts/tiers, party-stat ranks, per-trait upgrades, action-aware stat snapshots, shared party combat dependencies, four-member cap | Actor node movement or rendering |
| `ExperienceSystem` | `scripts/progression/experience_system.gd` | Experience totals, increasing thresholds, pending levels, `level_ready` | Choice generation or applying upgrades |
| `SpawnDirector` | `scripts/game/spawn_director.gd` | Regular spawn timing, weighted ID sampling, two regular scene preloads, spawn markers, reward-orb creation | Catalog discovery or boss behavior |
| `PartyActorSpawner` | `scripts/party/party_actor_spawner.gd` | Companion instancing, initial placement, combat configuration, companion health bars | Leader creation or party membership decisions |
| `PartyActor` | `scripts/characters/party_actor.gd` | Definition-driven health/combat setup, target collection, attacks, visual health feedback, team identity, and combat-target record | Formation movement policy for companions |
| `AttackController` | `scripts/combat/attack_controller.gd` | Attack definition, cooldown advancement, in-range target selection, `attack_ready` signal | Damage/projectile/heal execution |
| `AttackExecutor` | `scripts/combat/attack_executor.gd` | Party packet preparation/delivery, melee/projectile/area execution, separate healing, effect spawning | Defense formulas or choosing new unsupported attack kinds |
| `DamageResolver` | `scripts/combat/damage_resolver.gd` | Typed packet preparation; crit, dodge, mitigation, incoming multiplier, block, final health application, and overkill-safe life steal order | Target selection, movement, or visual effects |
| `RecoveryController` | `scripts/combat/recovery_controller.gd` | Frame-rate-independent regeneration from current resolved stats | Damage mitigation or revive timing |
| `HealthComponent` | `scripts/combat/health_component.gd` | Final health application, down/death state, healing, revive timing, and health signals | Armor/resistance/dodge/block formulas, actor movement, targeting, or rewards |
| `HUD` | `scripts/ui/hud.gd` and `scenes/ui/hud.tscn` | Status text, party/trait display, boss status and banner, composition of panels | Applying an upgrade choice |
| `LevelUpPanel` | `scripts/ui/level_up_panel.gd` and `scenes/ui/level_up_panel.tscn` | Three choice buttons, validity display, one `choice_selected` signal | Generating choices or mutating party state |
| `RunResultPanel` | `scripts/ui/run_result_panel.gd` and `scenes/ui/run_result_panel.tscn` | Victory/defeat display and restart/quit requests | Deciding the run result |

## Content definition table

| Type | Schema | External instances | Describes |
| --- | --- | --- | --- |
| `ClassDefinition` | `scripts/data/class_definition.gd` | `data/classes/*.tres` | Identity, role, color, trait IDs, base stats, revive settings, formation distances, primary attack, optional support action |
| `AttackDefinition` | `scripts/data/attack_definition.gd` | `data/attacks/*.tres` | Attack kind, typed damage components or heal power, action tags, crit permission, cooldown, range, projectile speed, and area radius |
| `DamageTypeDefinition` | `scripts/data/damage_type_definition.gd` | `data/damage_types/core_damage_types.tres` | Damage-type identity, offense/defense stat mappings, mitigation rule, and resistance bounds |
| `TraitDefinition` | `scripts/data/trait_definition.gd` | `data/traits/*.tres` | Trait identity, supported stat ID, count thresholds, bonus values, and optional effect radius |
| `EnemyDefinition` | `scripts/data/enemy_definition.gd` | `data/enemies/*.tres` | Enemy identity, behavior enum, health, speed, typed stat overrides, linked attacks, and experience |
| `UpgradeTuning` | `scripts/data/upgrade_tuning.gd` | `data/upgrades/default_upgrades.tres` | Party-stat maximum rank and per-rank party/trait upgrade steps |

Definitions are Resources, not running actors. `GameCatalog` explicitly loads class, trait, enemy, stat, and damage-type definitions. Party attacks are reached through class references; enemy definitions link their behavior-required attacks explicitly.

## Main run data flow

1. Godot instances `scenes/game/main.tscn` from `project.godot`.
2. `PartyForgeMain._ready()` caches the main service nodes and calls `GameCatalog.load_defaults()`.
3. Catalog validation must pass before class buttons are wired.
4. A class-selection button calls `select_leader_class(class_id)`.
5. The selected definition initializes `PartyManager`; the leader, health bar, camera, HUD, `PartyActorSpawner`, and `SpawnDirector` are configured.
6. `GameRun.start_run()` moves the state machine from `SETUP` to `RUNNING`.
7. `GameRun` advances elapsed time while `SpawnDirector` advances its regular spawn schedule.
8. Level-ready signals pause the run in `LEVEL_UP`; selecting a valid choice resumes the prior running or boss state.
9. At 300 seconds, `RunStateMachine` enters `BOSS` and emits `boss_requested`; `PartyForgeMain` instances the Forge Guardian.
10. Leader terminal death locks `DEFEAT`; boss defeat during `BOSS` locks `VICTORY`. The result panel appears and hostile transient effects are cancelled.

## Class and party flow

1. `GameCatalog` loads a `ClassDefinition` with trait IDs and linked attacks.
2. `PartyManager.initialize()` creates the leader's `PartyMemberState`, records class rank one, and recalculates trait counts.
3. `PartyForgeMain` configures the leader `PartyActor` from that member state.
4. A recruit choice calls `PartyManager.recruit()` while fewer than four members exist.
5. `member_added` reaches `PartyActorSpawner`, which instances and configures a companion plus health bar.
6. Trait counts are recalculated from every member's class trait IDs; the highest achieved threshold becomes active.
7. Class-rank, party-stat, and per-trait upgrades invalidate manager snapshots; action-aware stats feed `DamageResolver`, while `CombatModifiers` retains movement/timing values.
8. Companion movement uses role, preferred distance, tether distance, leader position, hostile position, and party separation.

`class_rank_power_step` scales typed attack damage for ranks above one. Recruiting a duplicate class contributes another member and its traits but does not itself increment the class rank.

## Combat flow

1. `PartyActor` advances its `AttackController` cooldown and collects live `CombatTarget` records from `party_actors` and `hostile_actors`.
2. Primary target selection rejects unavailable and same-team targets and applies range; support healing separately chooses an injured, available same-team target in range.
3. A ready controller emits `attack_ready(definition, target)`.
4. `AttackExecutor` gets the source combat adapter with normalized action tags. Healing reads `healing_power` directly and creates no damage packet.
5. A damaging execution prepares one immutable `DamagePacket`; a shared crit result belongs to that execution.
6. Melee, projectile, and area delivery obtain current target adapters, deduplicate and sort multi-target IDs, then call `DamageResolver.resolve()` independently per defender.
7. The resolver performs target dodge, typed mitigation/resistance, incoming modifiers such as Vanguard, block, final `HealthComponent.apply_damage()`, and actual-health-based life steal in that order.
8. Party and enemy projectiles carry packets plus the shared RNG/type dependencies; timed effects clean themselves up after impact or lifetime.
9. `RecoveryController` advances continuous regeneration before attacks, while health signals drive flash, down/revive presentation, bars, leader defeat, and enemy defeat.

Damage and healing are separate: Party Damage scales damaging packets, while heals use action-aware `healing_power` without entering `DamageResolver`.

## Enemy and reward flow

1. `SpawnSchedule.sample(elapsed)` returns the current interval plus Swarmer and Spitter weights for times from zero to under 300 seconds.
2. `SpawnDirector.sample_enemy_id()` selects `swarmer` or `spitter` from those weights.
3. `SpawnDirector.spawn_enemy()` accepts only those two regular IDs, chooses an off-camera marker, instances the matching preloaded scene, assigns a deterministic `enemy:<sequence>` combat identity plus shared RNG/type dependencies, configures target/effects support, and connects `reward_dropped`.
4. The scene's attached script—not `EnemyDefinition.behavior`—runs Swarmer or Spitter behavior.
5. `EnemyActor.configure()` applies definition health and connects terminal health to guarded defeat; behavior scripts prepare exact linked attack IDs and resolve them through adapters.
6. On defeat, `EnemyActor` emits one reward with the definition's experience and queues itself for deletion.
7. `SpawnDirector._on_reward_dropped()` instances an experience orb under `Effects`.
8. The orb follows the leader within pickup radius; collection adds experience to `ExperienceSystem` and frees the orb.

The Forge Guardian is boss-only. `PartyForgeMain` instances it in response to the five-minute boss request; it is not one of `SpawnDirector`'s two regular IDs.

## Level-up flow

1. An experience orb calls `ExperienceSystem.add_experience()` when collected.
2. Crossing one or more thresholds increments the level, records pending levels, and emits `level_ready` for each threshold.
3. `PartyForgeMain` asks `GameRun` to enter `LEVEL_UP`, which pauses the SceneTree.
4. `LevelUpChoiceService.generate()` builds registered recruit choices, owned-class rank choices, active-trait upgrades, and five party-stat choices.
5. While party space remains, one randomized recruit is included; remaining candidates are shuffled deterministically from the supplied seed.
6. `LevelUpPanel` displays three usable choices and emits the selected `UpgradeChoice` once.
7. `PartyForgeMain._apply_choice()` revalidates and applies recruit, class-rank, trait, or party-stat ownership through `PartyManager`.
8. One pending level is consumed. Another pending choice is presented, or the run resumes its prior state.

## Explicit registries and current limitations

| Boundary | Verified implementation | Consequence |
| --- | --- | --- |
| Catalog | `GameCatalog.CLASS_PATHS`, `TRAIT_PATHS`, and `ENEMY_PATHS` are explicit arrays | New files under `data/` are not discovered automatically |
| Leader selection | Four buttons and callback IDs: `fighter`, `ranger`, `mage`, `cleric` in `PartyForgeMain._wire_static_ui()` | A registered recruit does not automatically become a selectable leader |
| Attack kinds | Party: `MELEE_CLEAVE`, `PROJECTILE`, `AREA_PROJECTILE`, `HEAL`; enemy behaviors additionally use `DIRECT` and `AREA` | A new kind needs validation, owning behavior/delivery support, and tests |
| Trait effects | `attack_speed`, `nearby_damage_reduction`, `projectile_speed_and_range`, `area_size`, `cooldown_reduction`, `healing_and_revive`, `support_power` | A new stat ID needs modifier/party behavior and tests |
| Regular enemy scenes | `SWARMER_SCENE` and `SPITTER_SCENE`; accepted IDs `swarmer` and `spitter` | Catalog registration alone cannot make a regular enemy spawn |
| Spawn weights | `SpawnBand` has only `swarmer_weight` and `spitter_weight` | A third weighted enemy changes schedule and sampling architecture |
| Enemy behavior enum | Stored on `EnemyDefinition`, but no runtime factory selects scripts from it | The instantiated scene's attached script supplies behavior |
| Formation data | `engagement_distance` is exported but not consumed by verified runtime movement/targeting | Editing it alone has no gameplay effect |
| Presentation | Damage flash expects a direct `MeshInstance3D` | Nested imported hierarchies need an adapter or recursive handling |
| Audio | No reviewed custom bus layout or established audio integration | Verify actual buses; do not assume Music/SFX/UI names |

> **Current limitation:** These are implementation facts, not Godot restrictions. Change them deliberately with source, tests, and updated handbook guidance.

## Change-owner decision table

| Desired change | Primary owner | Additional integration |
| --- | --- | --- |
| Tune an existing number | Owning `.tres` definition, `UpgradeTuning`, or documented script constant | Relevant unit suite and controlled observation |
| Add an existing-kind attack | New `AttackDefinition` in `data/attacks/`; link from class | Definition/catalog-link tests and combat sandbox |
| Add a recruit-only class | Class/attack/trait Resources plus `GameCatalog` class/trait arrays | Catalog fixtures, progression recruitment/tier tests, ordinary run |
| Make a class leader-selectable | `scenes/ui/hud.tscn` and `PartyForgeMain._wire_static_ui()` | Main-wiring tests and explicit button path |
| Add a supported trait | `TraitDefinition` plus class trait IDs and `GameCatalog.TRAIT_PATHS` | Catalog, party-manager, modifier tests |
| Add a new trait effect | `TraitDefinition.SUPPORTED_STAT_IDS` plus consuming modifier/party behavior | Focused behavior tests and sandbox observation |
| Add an existing-behavior enemy | Enemy definition plus copied compatible enemy scene | Catalog, SpawnDirector ID/preload/selection, schedule, sandbox action, tests |
| Add genuinely new enemy behavior | New `EnemyActor`-derived script and scene | Deterministic movement/attack/effect tests, then all production registration |
| Replace a model | Game-owned wrapper's presentation child/imported Resource | Preserve root, components, collision, groups, flash target, health-bar contract |
| Add positional sound | `AudioStreamPlayer3D` owned by actor/effect | Imported stream, listener/attenuation tests, verified bus |
| Change UI layout | Relevant `scenes/ui/*.tscn` Control hierarchy | Responsive tutorial, layout tests, three 16:9 sizes and non-16:9 framing |
| Alter run timing | `RunStateMachine`, `GameRun`, `SpawnSchedule`, or boss/spawn constants according to the timer | Boundary tests, ordinary run through changed transition, HUD timing check |

## Verification checklist by change type

| Change category | Definition/catalog validation | Focused automated test | Sandbox/visual check | Parser/import | Ordinary run |
| --- | --- | --- | --- | --- | --- |
| Existing numeric data | Required when definition/catalog-backed; otherwise inspect the owning constant and its consumer | Owner/consumer suite | Required for observable effect | Required before commit | Required if pacing/progression changes |
| New class/attack/trait using supported behavior | Required in isolation and after registration | Catalog, party, progression, combat | Required | Required | Required for recruitment/leader flow |
| New attack kind or trait effect | Required | New behavior plus regression suites | Required | Required | Required |
| Existing-behavior enemy | Required | Catalog, spawn, schedule, enemy, sandbox contract | Required | Required | Required for wave pacing |
| New enemy behavior | Required | Deterministic movement/attack/reward/effect tests | Required | Required | Required |
| Model/material/import | Resource/reference check | Scene contract and affected actor tests | Required with collision and two instances | Required after reimport | Required if production actor changed |
| Audio | Stream/reference check | Ownership/cleanup test where practical | Required listening from multiple positions | Required | Required for production mix/context |
| UI layout | Not applicable unless data-linked | Main wiring and responsive UI suites | Required at target sizes | Required | Required for full interaction flow |
| Run timing/spawn weights | Schedule/state validation | Boundary and deterministic sampling/state tests | Useful for accelerated focused check | Required | Required through affected time |
| Documentation only | Link/path/source-fact audit | Existing full suite once at milestone | Not required unless instructions changed behavior claims | Required at milestone | Not required |

For every production change, also inspect `git diff --check`, `git status --short`, and the exact staged names. A check marked “not applicable” does not remove the need to validate the layers the change actually touches.

## Glossary

- **Node:** One runtime object in a SceneTree, with a type, name, properties, methods, signals, and optional children.
- **Scene:** A saved tree with one root node, usually stored as `.tscn`, that can be instantiated like a reusable node type.
- **Instance:** A live or editor copy created from a scene or class. Multiple instances can share Resource data.
- **Resource:** Reference-counted data, built into an owner or saved externally as `.tres`; it does not need to live in the SceneTree.
- **Signal:** A typed or untyped message an object emits so connected receivers can react without the sender calling their implementation directly.
- **Method:** A named function belonging to a class or object, such as `PartyManager.recruit()`.
- **Inspector:** The editor dock for viewing and editing exported properties on the selected node or Resource.
- **SceneTree:** The live hierarchy managed by Godot, including the current root, nodes, groups, processing, and pause state.
- **Local:** The editor-side scene currently open in the Scene dock, including changes that may not have been saved yet.
- **Remote:** The running SceneTree shown by the editor, including spawned and modified runtime nodes.
- **Autoload:** A scene or script configured in Project Settings to be added globally when the project starts. Party Forge's verified service nodes are main-scene children, not autoloads.
- **`res://`:** Godot's project-root path prefix. `res://scripts/game/main.gd` resolves inside the current Party Forge project.
- **`.tscn`:** Godot's text scene format.
- **`.tres`:** Godot's text Resource format.
- **`.gd`:** A GDScript source file.
- **`.uid`:** A Godot-generated identity sidecar used to keep Resource references stable when paths change.
- **`.import`:** Import metadata associated with a source asset inside the project.
- **Group:** A SceneTree label used to find or classify nodes without hard-coding every path, such as `party_actors` or `hostile_transient_effects`.
- **Collision layer/mask:** A layer says what physics category an object occupies; a mask says which layers it checks for interactions.
- **Typed GDScript:** GDScript with declared parameter, return, variable, collection, and signal types so intent and many mismatches are checked earlier.

## Official Godot references

- [Nodes and scenes](https://docs.godotengine.org/en/4.7/getting_started/step_by_step/nodes_and_scenes.html)
- [Resources](https://docs.godotengine.org/en/4.7/tutorials/scripting/resources.html)
- [Using signals](https://docs.godotengine.org/en/4.7/getting_started/step_by_step/signals.html)
- [Groups](https://docs.godotengine.org/en/4.7/tutorials/scripting/groups.html)
- [Project organization](https://docs.godotengine.org/en/4.7/tutorials/best_practices/project_organization.html)
