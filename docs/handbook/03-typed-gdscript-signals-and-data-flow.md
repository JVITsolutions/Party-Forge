# 3. Typed GDScript, Signals, and Party Forge Data Flow

> **Runtime architecture:** Party Forge nine-class selector at `b0be05a03bbd3ea5aae04d3e38ffdc0769a211ba`<br>
> **Godot version:** `4.7.1`<br>
> **Last checked:** `2026-07-30`

## What you will learn

- Read a short typed GDScript file from top to bottom.
- Recognize variables, constants, functions, arrays, dictionaries, enums, and `StringName` identifiers.
- Choose `_ready()`, `_process()`, or `_physics_process()` for the right kind of work.
- Tell an action-requesting method from an event-announcing signal.
- Follow Party Forge's run flow from class selection through a level-up choice.
- Connect an existing game event to presentation without duplicating its rule.

## Reading a typed GDScript file

Start with the smallest useful example: `res://scripts/data/class_definition.gd`.

```gdscript
class_name ClassDefinition              # A globally named custom type.
extends Resource                        # Its instances are data Resources, not Nodes.

enum Role { FRONTLINE, MIDLINE, BACKLINE, SUPPORT }

@export var id: StringName              # Editable in the Inspector; always a StringName.
@export var traits: Array[StringName] = []
@export var max_health: float = 100.0

func validate() -> PackedStringArray:   # No parameters; returns validation messages.
    var errors: PackedStringArray = []
    if max_health <= 0.0:
        errors.append("class %s health must be positive" % id)
    return errors
```

Read it in this order:

1. `class_name` tells you the name other scripts can use for the type.
2. `extends` tells you what the type inherits and therefore what it can do.
3. Constants and enums define fixed vocabulary.
4. Member variables hold each instance's state or data.
5. Functions define operations and answers.

The colon after a name introduces a type. The arrow in `func validate() -> PackedStringArray` introduces the return type. Typed code lets the editor catch more mistakes before the affected line runs and improves completion in the Script workspace.

> **Godot rule:** GDScript is gradually typed. Types may be written on variables, constants, parameters, function returns, arrays, and dictionaries; `:=` asks the parser to infer a variable's type from its initial value.

> **Party Forge convention:** Runtime and data scripts use typed declarations at their public boundaries. When reading a function, treat its parameter and return types as part of its contract.

## `extends`, `class_name`, variables, constants, and functions

`extends` establishes the base type. For example, `ClassDefinition` extends `Resource`, `PartyManager` extends `Node`, and `EnemyActor` extends `CharacterBody3D`. A script can use the properties and methods of its base type.

`class_name ClassDefinition` registers a global script class. Other files can then write `leader_class: ClassDefinition` without first loading the script into a constant. This names a type; it does not create an instance.

A `var` value can change. A `const` value cannot be reassigned. Party Forge uses both:

```gdscript
const MAX_PARTY_SIZE := 4
var members: Array[PartyMemberState] = []

func recruit(definition: ClassDefinition) -> bool:
    if definition == null or members.size() >= MAX_PARTY_SIZE:
        return false
    _append_member(definition, false)
    return true
```

The typed parameter says `recruit()` accepts a `ClassDefinition`. The `-> bool` says every successful path returns `true` or `false`. The method requests an action: try to recruit this definition.

Names beginning with one underscore, such as `_append_member`, are internal by convention. Names such as `_ready` are also recognized engine callbacks when their spelling and signature match Godot's API.

## Types, arrays, dictionaries, enums, and StringName

Common Party Forge types include:

| Type | Example | Meaning |
|---|---|---|
| `int` | `pending_levels: int` | Whole number. |
| `float` | `max_health: float` | Decimal number. |
| `bool` | `run_started: bool` | `true` or `false`. |
| `String` | `display_name: String` | User-facing or formatted text. |
| `StringName` | `class_id: StringName` | An engine identifier optimized for repeated comparisons. |
| Custom type | `catalog: GameCatalog` | An instance with a known Party Forge interface. |

An `Array` is an ordered sequence. `Array[StringName]` accepts `StringName` elements:

```gdscript
@export var traits: Array[StringName] = []
var classes: Array[ClassDefinition] = catalog.classes
```

A `Dictionary` maps keys to values. `PartyManager.class_ranks` maps a class ID to its current rank. Some current dictionaries are deliberately untyped because their values come from Resource data or contain more than one practical value shape:

```gdscript
var class_ranks: Dictionary = {}
class_ranks[definition.id] = 1
```

An enum gives readable names to integer choices:

```gdscript
enum Role { FRONTLINE, MIDLINE, BACKLINE, SUPPORT }
@export var role: Role
```

The Inspector shows the enum options instead of requiring a beginner to remember the stored integer.

Party Forge uses `StringName` for stable identifiers: class, trait, attack, and enemy IDs; group names such as `&"party_actors"`; and names used when signals or other members must be addressed dynamically. The `&"fighter"` spelling creates a `StringName` literal, while `"Fighter"` is a `String` intended for text.

> **Godot rule:** `StringName` makes repeated name comparison efficient. It does not check whether `&"figther"` was misspelled or whether that ID exists in a catalog.

> **Party Forge convention:** Use `StringName` for identifiers and `String` for player-facing text. Validate an identifier through `GameCatalog`, an allowed-ID list, or the owning system before acting on it.

## `_ready`, `_process`, and `_physics_process`

Godot calls these virtual methods; you do not schedule them yourself.

- `_ready() -> void` runs after a node and its children have entered the scene tree. Use it for post-instantiation setup: cache children, connect signals, configure process mode, or initialize presentation. `PartyForgeMain._ready()` caches its system nodes, loads and validates the catalog, wires the static UI, and prints boot checkpoints.
- `_process(delta: float) -> void` runs once per rendered frame. Use `delta` for frame-rate-independent visual or time-based updates. `HUD._process()` refreshes status and counts down the boss banner.
- `_physics_process(delta: float) -> void` runs at the fixed physics rate. Use it for movement and calculations that must stay synchronized with physics, especially a colliding body.

```gdscript
func _physics_process(delta: float) -> void:
    velocity = desired_direction * move_speed
    move_and_slide()
```

Do not move the same actor in both processing callbacks. Choose one owner and one timing model.

> **Godot rule:** `_process()` follows rendered frames; `_physics_process()` follows fixed physics steps. Their `delta` values are elapsed seconds for the corresponding update.

> **Current limitation:** Not every existing Party Forge movement helper is driven by `_physics_process()`; some systems advance through other owners. Follow the current call chain before relocating work merely because it involves a position.

## Methods request actions; signals announce events

A method call targets an owner and asks it to do something now:

```gdscript
party_manager.recruit(definition)
experience_system.add_experience(amount)
game_run.begin_level_up()
```

A signal announces that something already happened. Any connected listener may respond, and the emitter does not need to know every listener:

```gdscript
signal member_added(member: PartyMemberState)

func _append_member(definition: ClassDefinition, leader: bool) -> void:
    var member := PartyMemberState.new(members.size() + 1, definition, leader)
    members.append(member)
    member_added.emit(member)
```

The important Party Forge signals are:

| Signal | Owner and declaration | Meaning |
|---|---|---|
| `ClassSelectionPanel.class_selected` | `signal class_selected(class_id: StringName)` | A catalog-created leader button was pressed. `PartyForgeMain` validates the emitted ID through `GameCatalog` before starting a run. |
| `PartyManager.member_added` | `signal member_added(member: PartyMemberState)` | A member is now part of the authoritative party. `PartyActorSpawner` listens and creates a companion for non-leaders. |
| `EnemyActor.reward_dropped` | `signal reward_dropped(experience: int, drop_position: Vector3)` | An enemy completed its one-time reward drop. `SpawnDirector` listens and creates an experience orb. |
| `ExperienceSystem.level_ready` | `signal level_ready(level: int)` | Collected experience crossed a threshold and a pending level now exists. `PartyForgeMain` listens and presents choices. |
| `GameRun.victory` / `GameRun.defeat` | Signals with no arguments | The authoritative run state reached an outcome. `PartyForgeMain` listens and shows the result panel. |

The class selector is configured and connected once during setup. No class-specific node path is derived from a display name:

```gdscript
var selector := get_node("HUD/ClassSelection") as ClassSelectionPanel
selector.configure(catalog.classes)
if not selector.class_selected.is_connected(select_leader_class):
    selector.class_selected.connect(select_leader_class)
```

`ClassSelectionPanel.configure()` creates one runtime button for every ordered `ClassDefinition`. Each button emits the definition's exact `StringName` ID. The receiver's argument type matches that signal:

```gdscript
func select_leader_class(class_id: StringName) -> bool:
    var definition := catalog.class_by_id(class_id)
    if definition == null:
        return false
    # Initialize the party and leader from the validated definition.
    return true
```

> **Godot rule:** A custom signal may declare arguments, be connected to one or more callables, and be emitted with `.emit(...)`. The emitter is still responsible for supplying the intended arguments.

> **Party Forge convention:** Methods request state changes from the system that owns the rule. Signals announce completed events so other systems, especially presentation, can react without taking ownership of the rule.

## Party Forge run flow

Follow this chain through the current source:

1. **Class selection:** `ClassSelectionPanel.configure(catalog.classes)` creates all nine buttons. Pressing one emits `class_selected(class_id)`, which is connected to `PartyForgeMain.select_leader_class(class_id)` in `scripts/game/main.gd`.
2. **Catalog lookup:** `GameCatalog.class_by_id(class_id)` returns the matching `ClassDefinition`. An unknown ID is rejected with a `PARTY_FORGE_RESOURCE_ERROR`.
3. **Party initialization:** `PartyManager.initialize(definition, catalog.traits)` creates the leader's `PartyMemberState`. `member_added` is emitted, although `PartyActorSpawner` is connected after this initial leader step and ignores leader members in any case.
4. **Leader instance:** `leader.tscn` is instantiated under `Main/Actors`, then configured from the leader member and its `ClassDefinition`.
5. **Auto-combat:** The leader and later companions receive `AttackDefinition` data. Their attack controller selects targets and emits `attack_ready`; the combat executor performs the matching attack kind.
6. **Enemy reward:** On defeat, `EnemyActor` emits `reward_dropped(experience, drop_position)` exactly once. `SpawnDirector._on_reward_dropped()` creates an experience-orb scene at that position.
7. **Experience:** When the orb reaches the leader, `ExperienceOrb` calls `ExperienceSystem.add_experience(value)`. If a threshold is crossed, `ExperienceSystem` increments `pending_levels` and emits `level_ready(level)`.
8. **Level-ready signal:** `PartyForgeMain._on_level_ready()` asks `GameRun` to enter the level-up state and calls the level-up panel with three valid `UpgradeChoice` values.
9. **UI choice:** `LevelUpPanel` emits `choice_selected(choice)`. `PartyForgeMain._apply_choice()` validates the choice and asks `PartyManager` to recruit, rank up, upgrade a trait, or upgrade a party stat.
10. **Party update:** `PartyManager` changes its authoritative state and emits the corresponding event. For a recruit, `member_added` causes `PartyActorSpawner` to instantiate and configure a companion. The pending level is consumed and the run resumes when none remain.

This is a chain of owners, not one giant script. Catalog owns lookups, party manager owns party state, combat owns attacks, experience owns thresholds, game run owns run state, and UI presents choices.

## Exercise: follow one event through the game

Trace `EnemyActor.reward_dropped` without editing production code.

1. Press `F8`, save any intentional work, and record `git status --short`.
2. Open `res://scripts/game/spawn_director.gd` in the Script workspace.
3. Find `_on_reward_dropped(experience: int, drop_position: Vector3)` and click the gutter beside its first executable line to set a breakpoint.
4. Open `res://scenes/dev/combat_sandbox.tscn`, press `F6`, and spawn a Swarmer. Let the party defeat it. The full project with `F5` is an alternative, but the sandbox reaches the event faster.
5. When execution pauses, inspect the Debugger's stack and variables:
   - `experience` is an `int` supplied by `EnemyActor.reward_dropped`.
   - `drop_position` is a `Vector3` supplied by the defeated enemy.
   - `self` is the receiving `SpawnDirector`, not the `EnemyActor` emitter.
6. Inspect the Remote scene tree. Identify the defeated enemy's owner before it is freed, `SpawnDirector`, the `Effects` container where the orb is added, and `ExperienceSystem`, which will receive the value only after collection.
7. Continue execution, then press `F8`. Remove the breakpoint.
8. Run `git status --short` again. The before-and-after authored-file lists should match.

> **Checkpoint:** You can name the emitter, receiver, two typed arguments, and the node that owns each side of the connection. You also observed that reward emission creates an orb; it does not add experience directly.

## Production recipe: connect a new presentation response

Suppose a new `VictoryFlash` visual should play when a run is won. Do not calculate whether the boss is dead inside the effect. `GameRun.victory` already announces the authoritative outcome.

1. Put the visual node beneath `HUD` or another presentation owner. Give that node a method such as `play() -> void` that changes only visuals or audio.
2. In the composition owner, cache the node after instantiation.
3. Connect the existing signal during setup:

   ```gdscript
   func _ready() -> void:
       if not game_run.victory.is_connected(_on_victory_visual):
           game_run.victory.connect(_on_victory_visual)

   func _on_victory_visual() -> void:
       (get_node("HUD/VictoryFlash") as CanvasItem).show()
   ```

4. Leave `GameRun.boss_defeated()`, its state transition, and the existing result-panel response unchanged.
5. Run both a victory path and a defeat path. The visual must run only on victory and must not alter the run result.
6. Search for accidental duplicate rules:

   ```powershell
   rg -n 'boss_defeated|victory\.connect|_on_victory_visual' scripts scenes
   ```

> **Party Forge convention:** A visual receiver may display, animate, or play sound. It must not re-decide the event, award rewards, mutate party state, or emit a second authoritative outcome.

## Verification

For this chapter, verify understanding against the live project:

- Open `scripts/data/class_definition.gd` and identify `class_name`, `extends`, an enum, `Array[StringName]`, an exported `float`, and a typed return.
- Open `scripts/game/main.gd` and follow `select_leader_class()` through catalog lookup, party initialization, and leader instantiation.
- Search the exact signals:

  ```powershell
  rg -n 'signal (member_added|reward_dropped|level_ready|victory|defeat)' scripts
  ```

- Run the event exercise and inspect the receiver's typed arguments.
- Confirm `git status --short` matches the list recorded before the read-only exercise.

Stop if a signal never reaches its breakpoint, its receiver belongs to a different node than expected, or an unexplained file changes.

## Common errors and debugger messages

- **Unknown identifier:** The parser cannot resolve a name in the current scope. Check spelling and capitalization, then verify that a custom type has the expected `class_name` and that the file parses. `class_id` and `class_ids` are different identifiers.
- **Invalid type assignment:** A value does not fit the declared type, such as assigning a `String` to `var level: int`. Follow the data to its source; do not remove the type merely to silence the error.
- **Nonexistent function or property:** The referenced value's type does not declare that member. Check the type shown by completion or the debugger, confirm any cast, and verify that a node path returned the node you expected.
- **Bad indentation:** GDScript uses indentation to define blocks. Align sibling statements and use one indentation style. A line that looks visually close may still be outside the intended `if`, loop, or function.
- **Signal callback never runs:** Confirm the connection is executed, the emitter is the same instance you inspected, and `is_connected()` reports the exact callable. Then put one breakpoint on the `.emit(...)` line and another in the receiver.
- **Callback argument mismatch:** Compare the signal declaration, its `.emit(...)` call, and the receiver signature in that order.

Read the first parser error first. Later messages are often consequences of the earliest broken line.

## Rollback

1. Press `F8` and remove any breakpoints.
2. If a practice edit is unsaved, use `Ctrl+Z` in the same script tab or close it without saving.
3. If it was saved, inspect only that path with `git diff -- <exact-path>`.
4. Reverse the specific practice edit while preserving unrelated changes.
5. Reopen the script and confirm the parser is clean.
6. Compare `git status --short` with your recorded baseline.

Never use `git reset --hard` for this rollback. Completion means the exact unwanted diff is gone, not that the whole worktree was erased.

## Official Godot references

- [Static typing](https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/static_typing.html)
- [GDScript basics](https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/gdscript_basics.html)
- [Signals](https://docs.godotengine.org/en/4.7/getting_started/step_by_step/signals.html)
- [Idle and physics processing](https://docs.godotengine.org/en/4.7/tutorials/scripting/idle_and_physics_processing.html)
