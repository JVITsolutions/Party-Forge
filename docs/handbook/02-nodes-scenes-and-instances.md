# 2. Nodes, Scenes, and Instances

> **Architecture baseline:** `a293f6208bd3a62246043c1b3e7c0a49ad5fef73`<br>
> **Godot version:** `4.7.1`<br>
> **Last checked:** `2026-07-29`

## What you will learn

- Explain nodes, scenes, and instances using Party Forge's real scene trees.
- Find which parent determines a `Node3D` actor's local coordinate space.
- Trace a recruited member from a signal to a runtime companion instance and health bar.
- Add presentation beneath an actor wrapper without moving the behavior contract.

## Node, scene, and instance mental model

A **Node** is one focused engine object. A `CharacterBody3D` moves and collides, a `CollisionShape3D` supplies a collision shape, and a `Label3D` draws text in 3D. Nodes gain useful behavior by being arranged as parent and child nodes.

A **scene** is a saved tree of nodes with exactly one root. `scenes/characters/companion.tscn` has a `Companion` root and children for collision, a mesh, health, and attacking. Once saved, that scene behaves like a reusable component.

An **instance** is one usable copy made from a saved scene. Multiple companions can come from `companion.tscn`; each begins with the same structure but has its own runtime state, position, health, and target.

> **Godot rule:** A scene has one root and can be instantiated any number of times. An instance starts from the saved scene and can have per-instance property overrides.

Think of `companion.tscn` as a blueprint and each runtime `Companion` under `Main/Actors` as a built copy. The blueprint is a file; the copy is a live node tree.

## Local and global ownership

Every `Node3D` transform is relative to something:

- `position` is local to the node's parent.
- `global_position` is the position in the overall 3D world.

In Party Forge, `Main/Actors`, `Main/Enemies`, and `Main/Effects` are `Node3D` containers. A companion's local `position` belongs to the coordinate space of `Actors`. `PartyActorSpawner._leader_position()` in `scripts/party/party_actor_spawner.gd` converts the leader's `global_position` into the actor container's local space with `actor_container.to_local(...)` when necessary.

If you reparent a `Node3D`, the same local position can produce a different world position because the parent changed. In the standard Godot 4.7 Inspector, **Transform** shows the selected node's local values; it does not expose a `global_transform` field. To investigate placement without adding debug code, select the node and each `Node3D` ancestor in turn, read their local **Transform** values, and observe the resulting placement in the 3D viewport or running Game view before “fixing” a misplaced actor.

There is also responsibility ownership:

- The actor root script owns actor behavior.
- `HealthComponent` owns health state.
- `AttackController` owns attack coordination.
- Visual child nodes own presentation, not combat rules.

> **Party Forge convention:** Preserve those responsibility boundaries when adding art. A visual child should not replace the scripted root or become the new home of health and attack behavior.

## Party Forge's main scene

`scenes/game/main.tscn` is the composition root loaded by F5. Its root node is `Main`, with `scripts/game/main.gd` attached. The direct children assemble the run:

```text
Main
├── GameRun
├── PartyManager
├── ExperienceSystem
├── SpawnDirector
├── PartyActorSpawner
├── Arena
├── Actors
├── Enemies
├── Effects
├── LeaderCamera
└── HUD
```

- `GameRun` controls run states and outcome timing.
- `PartyManager` owns party membership, ranks, traits, and party-stat upgrades.
- `ExperienceSystem` owns experience and pending levels.
- `SpawnDirector` schedules and creates normal enemies and pickups.
- `PartyActorSpawner` turns recruited member state into companion instances.
- `Arena` is an instance of `scenes/arena/arena.tscn`.
- `Actors`, `Enemies`, and `Effects` keep runtime 3D objects grouped by purpose.
- `HUD` is an instance of `scenes/ui/hud.tscn` displayed through a `CanvasLayer`.

> **Party Forge convention:** `scenes/game/main.tscn` composes systems and containers; it does not embed every actor, enemy, effect, and panel as hand-authored children.

> **Current limitation:** `scripts/game/main.gd` still knows several concrete scene and HUD paths directly, including `HUD/LevelUpPanel`. Renaming or moving those nodes requires corresponding code changes and tests.

## Reusable actor, enemy, effect, and UI scenes

Party Forge uses saved scenes as reusable components:

- **Actors:** `scenes/characters/leader.tscn` and `scenes/characters/companion.tscn` wrap collision, presentation, `HealthComponent`, and `AttackController` around a scripted root.
- **Enemies:** `scenes/enemies/swarmer.tscn`, `scenes/enemies/spitter.tscn`, and `scenes/enemies/forge_guardian.tscn` provide reusable enemy trees.
- **Projectiles and effects:** `scenes/combat/projectile.tscn`, `scenes/combat/area_burst.tscn`, `scenes/combat/heal_effect.tscn`, `scenes/enemies/enemy_projectile.tscn`, and scenes under `scenes/effects/` are instantiated when actions need visible or timed objects.
- **UI:** `scenes/ui/hud.tscn` instances `scenes/ui/level_up_panel.tscn` and `scenes/ui/run_result_panel.tscn`; `scenes/ui/health_bar_3d.tscn` can be attached to actors and enemies at runtime.

Changing a source scene changes the defaults seen by its instances. An override on one instance can keep that one value different from the source.

> **Godot rule:** A saved scene works as a reusable blueprint. Editing its defaults affects instances unless an instance overrides the edited property.

## Parent and child paths

A node path describes a route through node names. From `Main`, `HUD/LevelUpPanel` means “find child `HUD`, then its child `LevelUpPanel`.” The code call `get_node("HUD/LevelUpPanel")` depends on both names and that hierarchy.

Paths are not labels for humans; they are runtime contracts. At architecture commit `a293f6208bd3a62246043c1b3e7c0a49ad5fef73`, examples include:

- `Actors`
- `Arena/PlayerSpawn`
- `LeaderCamera/Camera3D`
- `HUD/ClassSelection`
- `HUD/LevelUpPanel`
- `HUD/RunResultPanel`
- `Companion/HealthComponent` when described from the companion's parent

> **Party Forge convention:** Files and folders use lowercase `snake_case`; node names use `PascalCase`. Preserve required node names such as `HealthComponent`, `AttackController`, and `HealthBar3D` unless you also update every consumer.

If a node is renamed or moved, search for both its old path and name before saving:

```powershell
rg -n 'HUD/LevelUpPanel|HealthComponent|AttackController' scripts tests scenes
```

## Exercise: trace an instantiated companion

This exercise changes no authored files. The combat sandbox is the fastest route; the production run is an optional alternative.

1. Press `Ctrl+S`, press `F8`, and record `git status --short`. Expected changed files from this exercise: none.
2. In the FileSystem dock, open `res://scenes/dev/combat_sandbox.tscn` and press `F6`.
3. In the sandbox panel, click **Ranger**, **Mage**, or **Cleric** once. The party-size label should change from `1 / 4` to `2 / 4`.
4. While the sandbox is running, switch the Scene dock from **Local** to **Remote**.
5. Expand `CombatSandbox`, then `Actors`, then the runtime `Companion`.
6. Locate these children:
   - `HealthComponent`
   - `AttackController`
   - `HealthBar3D`, which itself contains `Label3D`
7. Select the companion and inspect its local **Transform > Position** without editing it. Then select its `Actors` parent and inspect that node's local **Transform > Position**. Return to the 3D viewport or Game view and observe where the companion appears relative to the leader. The normal Inspector will not show a separate global-transform value.
8. Press `F8`. Confirm the Scene dock returns to the saved Local tree, where the runtime companion is absent.
9. Run `git status --short` again and compare it with step 1.

> **Checkpoint:** During the run, the Remote tree contains `CombatSandbox/Actors/Companion` with `HealthComponent`, `AttackController`, and `HealthBar3D`. After F8, that runtime companion disappears and Git status is unchanged.

The production alternative is to press `F5`, select a leader, and recruit when a level-up offers a recruit choice. Inspect `Main/Actors/Companion` in the Remote tree the same way. The sandbox is preferred because its class buttons create the condition immediately without changing production data.

The runtime chain you just observed is:

1. `PartyManager.recruit()` calls `_append_member()` in `scripts/party/party_manager.gd`.
2. `_append_member()` emits `PartyManager.member_added`.
3. `PartyActorSpawner._on_member_added()` in `scripts/party/party_actor_spawner.gd` receives the member.
4. The spawner instantiates `res://scenes/characters/companion.tscn`.
5. It calls `configure(member)` and `configure_combat(party_manager, effects)`.
6. It instances `res://scenes/ui/health_bar_3d.tscn`, adds it as a child, and configures it with `HealthComponent`.
7. It adds the completed companion under the `Actors` container.

> **Party Forge convention:** Party state is created first; the spawner reacts to `member_added` and builds the matching presentation/combat actor tree.

## Production recipe: add presentation without moving behavior

Use this only for approved production art. Practice first in a disposable scene under `scenes/dev/`, and delete that training scene when finished.

1. Record `git status --short` and declare the one actor scene you expect to change, for example `scenes/characters/companion.tscn`.
2. Open the actor scene and confirm its root is still the scripted `Companion` `CharacterBody3D`.
3. Add a `Node3D` child named `Presentation` beneath the root.
4. Add or instance purely visual children beneath `Presentation`, such as a model, mesh, particles, or animation nodes. Use the Inspector for transforms and material overrides.
5. Do not rename, reparent, or delete the root, `CollisionShape3D`, `HealthComponent`, or `AttackController`.
6. Keep collision on the collision node; do not assume the imported model's visible shape is gameplay collision.
7. Run `scenes/dev/combat_sandbox.tscn` with F6, recruit a companion, and inspect the Remote tree.
8. Verify movement, attacking, damage, the health bar, and the intended visual placement.
9. Stop with F8 and review `git diff -- scenes/characters/companion.tscn` before committing.

> **Checkpoint:** The Remote companion retains the scripted `Companion` root, `CollisionShape3D`, `HealthComponent`, `AttackController`, and `HealthBar3D`; the approved visual appears beneath `Presentation` and does not change combat behavior.

> **Current limitation:** The current actor wrappers use simple built-in capsule meshes. Replacing presentation with imported art still requires deliberate scale, pivot, animation, and collision review; instancing a model alone does not solve those concerns.

## Verification with the Local and Remote scene trees

- **Local** shows what is saved in the currently open `.tscn` scene.
- **Remote** shows the live node tree created for the running game, including nodes instantiated by scripts.

Use Local to answer “what will this scene save?” Use Remote to answer “what exists right now?” A companion spawned by `PartyActorSpawner` is expected in Remote but not as a hand-authored child of `scenes/game/main.tscn`.

For a clean verification:

1. Confirm the Local sandbox tree contains `Actors` and `Leader`, but no companion.
2. Run the sandbox and recruit once.
3. Confirm the Remote tree adds one `Companion` under `Actors`.
4. Confirm the companion has its required behavior children and runtime health bar.
5. Stop and confirm the Local scene is unchanged.

## Common mistakes

- **“I cannot find the companion in Local.”** It is created by code at runtime. Switch to Remote while the run is active.
- **“Remote is empty or unavailable.”** Start F5 or F6 first and make sure the running process has not stopped on an error.
- **“I changed a Remote property and it vanished after F8.”** Remote edits affect the live instance and are not the same as editing and saving the source scene.
- **“The visual is offset from the actor.”** Inspect the visual child's local transform, then inspect the local transforms of its `Node3D` ancestors and observe the result in the 3D viewport. Do not move the root merely to compensate for a model pivot, and do not expect a global-transform field in the standard Inspector.
- **“The health bar disappeared after reorganizing children.”** Confirm `HealthComponent` kept its exact name and remains a child accessible to the spawner; confirm the runtime `HealthBar3D` was added.
- **“Renaming looked harmless but the run now errors.”** Copy the first Debugger error and search the repository for the old node path with `rg`.
- **“The sandbox party size stayed at 1 / 4.”** Check the Output and Debugger panels for catalog or script errors, then confirm you clicked a class button while the sandbox run was active.

## Rollback

For the read-only trace exercise, stop with `F8` and confirm `git status --short` matches the starting snapshot.

For an accidental unsaved scene edit:

1. Use Godot Undo (`Ctrl+Z`) in the scene.
2. If you understand the exact unsaved scene scope, close its tab without saving.
3. If it was saved, inspect only that path with `git diff -- <exact-scene-path>` and preserve every unrelated change.
4. Remove a disposable sandbox scene only after confirming its resolved path is under `scenes/dev/` and it contains no approved work.

Never use `git reset --hard` to undo a scene experiment. Stop and ask for help if the unwanted edit overlaps existing work.

> **Checkpoint:** The unwanted actor-scene diff is gone, the production node contract is intact, and unrelated work remains untouched.

## Official Godot references

- [Nodes and scenes](https://docs.godotengine.org/en/4.7/getting_started/step_by_step/nodes_and_scenes.html)
- [Creating instances](https://docs.godotengine.org/en/4.7/getting_started/step_by_step/instancing.html)
- [Godot classes, scripts, and scenes](https://docs.godotengine.org/en/4.7/tutorials/best_practices/what_are_godot_classes.html)
