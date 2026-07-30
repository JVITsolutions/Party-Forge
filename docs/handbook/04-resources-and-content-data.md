# 4. Resources and Party Forge Content Data

> **Runtime architecture:** Party Forge nine-class selector at `b0be05a03bbd3ea5aae04d3e38ffdc0769a211ba`<br>
> **Godot version:** `4.7.1`<br>
> **Last checked:** `2026-07-30`

## What you will learn

- Tell a working scene node from a data-only Resource.
- Distinguish external `.tres` files from Resources built into a scene.
- Edit exported fields through the Inspector and understand where the edit is saved.
- Locate Party Forge's definition types and content files.
- Choose `load()` or `preload()` based on when the path is known.
- Register and validate content without assuming folders are scanned automatically.
- Decide whether a requested change belongs in data, scene composition, registration, or behavior code.

## Nodes perform work; Resources describe data

A `Node` lives in a scene tree. It can process frames, receive input, own children, move, collide, and connect to other live nodes. A `Resource` is a reference-counted data object. It can have typed properties and validation methods, but it does not need a place in the scene tree.

Party Forge separates the two:

- `PartyActor` is a node that moves and attacks.
- `ClassDefinition` is a Resource that describes its health, movement, traits, color, and attacks.
- `EnemyActor` is a node that moves, exposes a typed combat adapter, executes linked attacks, and drops a reward.
- `EnemyDefinition` is a Resource that describes an enemy ID, behavior kind, health, speed, stat overrides, linked attacks, and experience.

The node reads a definition and performs work. The definition does not search for targets or advance time.

> **Godot rule:** Resources are data containers derived from `Resource`; Nodes belong to a scene tree and receive node lifecycle behavior.

> **Party Forge convention:** Put tunable content values in a definition Resource and runtime behavior in the system or actor that consumes that definition.

## External and built-in Resources

An **external Resource** is saved as its own file. Party Forge's `res://data/attacks/ranger_shot.tres` is external. Its Inspector header shows its file path, and saving it changes that `.tres` file.

A **built-in Resource** is stored inside the `.tscn` scene or `.tres` Resource that owns it. For example, a material created directly in a scene's Mesh property may be serialized as a `[sub_resource]` section of the scene rather than as a separate file.

Use the Inspector to check the Resource's path before editing:

- A `res://...` path means it is external.
- An empty path usually means it is built into its owner.

Choose external data when multiple owners should deliberately reference one named definition, when the data needs its own reviewable file, or when it belongs in `data/`. Use a built-in Resource for a small value that is truly private to one owning scene.

> **Godot rule:** External Resources are individual files; built-in Resources are serialized inside their owning scene or Resource. Instancing the owner does not guarantee a unique copy of every Resource.

> **Current limitation:** A visually local Resource in the Inspector may still be shared by multiple consumers. Check its path and references; do not infer ownership from which node you clicked.

## Exported properties and the Inspector

`@export` stores a property and exposes it in the Inspector:

```gdscript
class_name AttackDefinition
extends Resource

enum Kind { MELEE_CLEAVE, PROJECTILE, AREA_PROJECTILE, HEAL, DIRECT, AREA }

@export var id: StringName
@export var kind: Kind
@export var power: float = 0.0
@export var cooldown: float = 1.0
@export var range: float = 1.0
@export var damage_components: Array[AttackDamageComponent] = []
@export var action_tags: Array[StringName] = []
@export var can_crit := false
```

Because the script has `class_name AttackDefinition` and `extends Resource`, `AttackDefinition` is available as a custom Resource type in the editor. Its exported fields appear with appropriate controls: an enum list for `kind`, numeric editors, typed arrays for components/tags, a checkbox for crit permission, and a text field for the ID.

To edit an external definition:

1. Double-click its `.tres` file in the FileSystem dock.
2. Confirm the Inspector's Resource type and path.
3. Change only the intended exported field.
4. Save with `Ctrl+S`.
5. Inspect `git diff -- <exact-file>` before staging.

Avoid hand-editing `.tres` syntax while learning. The Inspector preserves Resource references and serialized value formats.

> **Godot rule:** Exported properties are stored with the scene or Resource and displayed in the Inspector. A custom `class_name` derived from `Resource` makes that type available in the Create Resource dialog.

> **Party Forge convention:** Author definition data through the Inspector, but review the resulting text diff before committing.

## Party Forge definition types

The Resource scripts define schemas under `res://scripts/data/`; instances live under `res://data/`.

| Definition type | Schema path | Current instance paths | Describes |
|---|---|---|---|
| `AttackDefinition` | `res://scripts/data/attack_definition.gd` | `res://data/attacks/*.tres` | Attack kind, typed damage components or heal power, action tags, crit permission, cooldown, range, projectile speed, and area radius. |
| `DamageTypeDefinition` | `res://scripts/data/damage_type_definition.gd` | `res://data/damage_types/core_damage_types.tres` | Type identity, offense/defense stat mappings, mitigation rule, and resistance bounds. |
| `ClassDefinition` | `res://scripts/data/class_definition.gd` | `res://data/classes/*.tres` | Class identity, role, trait IDs, capability tags, base-stat overrides, health, movement, spacing, and referenced primary/support attacks. |
| `TraitDefinition` | `res://scripts/data/trait_definition.gd` | `res://data/traits/*.tres` | Trait identity, supported stat ID, activation tiers, values, and optional effect radius. |
| `EnemyDefinition` | `res://scripts/data/enemy_definition.gd` | `res://data/enemies/*.tres` | Enemy identity, behavior enum, health, speed, typed stat overrides, linked attacks, and experience reward. |
| `UpgradeTuning` | `res://scripts/data/upgrade_tuning.gd` | `res://data/upgrades/default_upgrades.tres` | Party-stat maximum rank and per-rank tuning steps. |
| `UpgradeDefinition` / `StatUpgradeEffect` | `res://scripts/data/upgrade_definition.gd`, `res://scripts/data/stat_upgrade_effect.gd` | `res://data/upgrades/cards/*.tres` | Authored card identity, scope, eligibility, maximum rank, selection weight, tooltip keywords, and stat-modifier effects. |
| `ExperienceTuning` | `res://scripts/data/experience_tuning.gd` | `res://data/progression/default_experience.tres` | Base, linear, and accelerating terms for each next-level experience requirement. |
| `StatCatalog` / `StatDefinition` | `res://scripts/stats/stat_catalog.gd`, `res://scripts/stats/stat_definition.gd` | `res://data/stats/core_stats.tres` | Stat defaults, limits, precision, formatting, visibility, capability requirements, and keyword identity. |

`ClassDefinition` demonstrates nested Resource data:

```gdscript
@export var traits: Array[StringName] = []
@export var capability_tags: Array[StringName] = []
@export var base_stat_overrides: Dictionary = {}
@export var primary_attack: AttackDefinition
@export var support_action: AttackDefinition
```

Ownership is layered rather than duplicated:

- `AttackDefinition` owns authored attack delivery values and typed damage components or healing power. A class references the attack Resource.
- `TraitDefinition` owns count thresholds and the stat bonus. A class stores trait IDs so `PartyManager` can count them across members.
- `StatDefinition` owns the global default, limits, precision, visibility rule, and capability requirements for a stat.
- `ClassDefinition.capability_tags` declares what a class can expose, such as `bow`, `block`, or `life_steal`.
- `ClassDefinition.base_stat_overrides` supplies class-specific starting values keyed by registered stat ID. The legacy `max_health`, `armor`, and `move_speed` fields remain authoritative fallbacks through `stat_base_values()`.

The Ranger class file references `ranger_shot.tres` instead of copying all attack values into the class. The Marksman class uses capability tags and base overrides for its authored critical identity while the stat catalog still owns how those stat values are finalized and formatted.

> **Party Forge convention:** Definition IDs use lowercase `snake_case` `StringName` values such as `&"ranger_shot"`; display names are separate `String` fields when players need formatted text.

## Loading, caching, and shared Resource instances

GDScript provides two convenient loading forms:

```gdscript
# The path is chosen while this code runs.
var definition := load(path) as ClassDefinition

# The path is a constant known when this script is parsed.
const DEFAULT_UPGRADE_TUNING: UpgradeTuning = preload(
    "res://data/upgrades/default_upgrades.tres"
)
```

Party Forge uses `load(path)` in `GameCatalog.load_defaults()` because it loops over path registries. It uses `preload()` for fixed dependencies such as `PartyManager.DEFAULT_UPGRADE_TUNING` and scenes that a script always needs.

- Choose `preload()` when the dependency and literal path are fixed and should be available with the script.
- Choose `load()` when the path is selected at runtime or comes from a registry variable.

Neither is universally better. The path's source and the desired loading time decide.

Loaded Resources are cached. Loading the same path again normally returns the cached Resource instance. If one consumer changes an exported field at runtime, another consumer referencing that Resource may observe the same change.

If a system truly needs private runtime data, duplicate deliberately and keep the duplicate in memory:

```gdscript
var private_attack := (load("res://data/attacks/ranger_shot.tres") as AttackDefinition).duplicate(true) as AttackDefinition
private_attack.damage_components[0].base_amount = 999.0
```

`duplicate(true)` also duplicates nested Resources where supported. It does not save a new file. Do not duplicate by reflex; shared read-only definitions are the intended normal case.

> **Godot rule:** `load()` executes at runtime, while `preload()` requires a constant path and loads with script compilation. `ResourceLoader` caches loaded paths for reuse by default.

> **Party Forge convention:** Treat loaded definition Resources as shared, read-only configuration during a run. Put changing health, cooldown, ranks, and pending levels in runtime state objects rather than mutating definitions.

## GameCatalog and explicit registration

`res://scripts/data/game_catalog.gd` contains the current registries:

```gdscript
const CLASS_PATHS: PackedStringArray = [
    "res://data/classes/fighter.tres", "res://data/classes/ranger.tres",
    "res://data/classes/mage.tres", "res://data/classes/cleric.tres",
    "res://data/classes/paladin.tres", "res://data/classes/rogue.tres",
    "res://data/classes/frost_mage.tres", "res://data/classes/warlock.tres",
    "res://data/classes/marksman.tres"
]

const TRAIT_PATHS: PackedStringArray = [
    "res://data/traits/martial.tres", "res://data/traits/vanguard.tres",
    # Eleven other current trait paths follow, for thirteen total.
]

const ENEMY_PATHS: PackedStringArray = [
    "res://data/enemies/swarmer.tres", "res://data/enemies/spitter.tres",
    "res://data/enemies/forge_guardian.tres"
]
```

`GameCatalog.load_defaults()` loops over those constants and loads the corresponding typed Resources. The current catalog contains nine ordered classes, thirteen traits, and three enemies. Adding a class, trait, or enemy `.tres` file to a folder does **not** register it. Add its exact `res://` path to the matching constant when the new content is meant for production.

Attack definitions have no separate `ATTACK_PATHS` registry. They become reachable through `ClassDefinition.primary_attack`/`support_action` or `EnemyDefinition.attacks`. The damage-type catalog is loaded explicitly by `GameCatalog`; `UpgradeTuning` is loaded separately by `PartyManager.DEFAULT_UPGRADE_TUNING`.

Authored upgrade cards use another explicit registry: `GameCatalog.REQUIRED_UPGRADE_PATHS` (with an empty optional list at this checkpoint). Add a production card by adding one row to `tools/character_upgrade_content_rows.gd`, run `tools/create_character_upgrade_data.gd`, and add the exact generated `data/upgrades/cards/<id>.tres` path to the required registry; review both diffs. The row supplies the card's scope, class/tag eligibility, rank cap, and effects. `CHARACTER` and `CLASS_SPECIFIC` cards target one eligible member; `PARTY` and `TRAIT` cards use party ownership, with trait/tag eligibility deciding which current and future members receive their modifier source.

Personal ranks are keyed by the stable `PartyMemberState.member_id`, not by class ID or actor node. That lets two members of the same class own different cards and ranks without storing scene references in runtime state. Party-owned matching sources are recomputed against each member, so an eligible recruit added later receives the already-owned synergy.

`ExperienceSystem` preloads `data/progression/default_experience.tres`. Its `ExperienceTuning` computes the next requirement from `base_cost + linear_growth * n + acceleration * n * n`, clamps the result to at least one, and falls back to safe nonnegative terms when loaded values are invalid.

> **Party Forge convention:** Content registration is explicit and code-reviewed; folders are not scanned automatically.

> **Current limitation:** Upgrade rarity is stored but does not scale selection or effects. Inventory, passive trees, save/load persistence, and player-facing renaming controls are deferred; do not infer them from the card schema or stored character names.

## Validation and grep-friendly errors

Each definition's `validate()` returns a `PackedStringArray`. An empty result means that definition found no validation errors:

```gdscript
func validate() -> PackedStringArray:
    var errors: PackedStringArray = []
    if id.is_empty():
        errors.append("enemy id is empty")
    if max_health <= 0.0:
        errors.append("enemy %s health must be positive" % id)
    return errors
```

`GameCatalog.validate()` combines registered classes, traits, and enemies. It:

1. Reports a Resource that failed to load.
2. Reads each Resource's `id`.
3. Uses one `seen` dictionary to detect duplicate IDs across its registered arrays.
4. Calls that definition's `validate()`.
5. Prefixes returned reasons with a stable marker.

Examples of the current format are:

```text
PARTY_FORGE_RESOURCE_ERROR reason=resource failed to load
PARTY_FORGE_RESOURCE_ERROR reason=duplicate id ranger
PARTY_FORGE_DAMAGE_ERROR path=res://data/attacks/ranger_shot.tres attack=ranger_shot type=physical reason=amount must be finite and positive
PARTY_FORGE_RESOURCE_ERROR path=res://data reason=...
```

The final path-prefixed line is produced by `PartyForgeMain.format_resource_error()` when catalog errors are reported during boot. The stable `PARTY_FORGE_RESOURCE_ERROR` prefix is grep-friendly:

```powershell
rg -n 'PARTY_FORGE_RESOURCE_ERROR' scripts tests
```

Validation checks supported rules, not every design judgment. A valid Resource can still be unbalanced, unregistered, visually confusing, or unused.

> **Party Forge convention:** Preserve the exact uppercase error prefix and include an ID, path, and reason when the current layer knows them.

> **Current limitation:** Catalog duplicate-ID detection covers the registered class, trait, and enemy arrays. Attacks are validated through their owning class references, and `UpgradeTuning.validate()` must be called by its own consumer or a focused check; neither type is a separate catalog registry today.

## Exercise: inspect and duplicate an attack Resource

Create a disposable training Resource, validate it directly, and remove every exercise file afterward.

1. Press `F8`, save intentional work, and record `git status --short`.
2. In the FileSystem dock, right-click `res://data/attacks/ranger_shot.tres` and choose **Duplicate**.
3. Name the copy `training_ranger_shot_disposable.tres` in `res://data/attacks/`. This label makes its temporary purpose unmistakable.
4. Open the copy in the Inspector. Confirm its type is `AttackDefinition`, then set **Id** to the unique value `training_ranger_shot_disposable`.
5. Inspect **Kind**, **Damage Components**, **Action Tags**, **Can Crit**, **Cooldown**, **Range**, **Projectile Speed**, and **Area Radius**. Do not change the production `ranger_shot.tres`.
6. Create a disposable script at `res://scripts/dev/training_attack_validation.gd` with:

   ```gdscript
   extends SceneTree

   func _init() -> void:
       var attack := load(
           "res://data/attacks/training_ranger_shot_disposable.tres"
       ) as AttackDefinition
       var errors: PackedStringArray = attack.validate() if attack != null else PackedStringArray(["failed to load"])
       if errors.is_empty():
           print("PARTY_FORGE_TRAINING_ATTACK_VALID")
           quit(0)
           return
       for reason: String in errors:
           push_error("PARTY_FORGE_RESOURCE_ERROR id=training_ranger_shot_disposable reason=%s" % reason)
       quit(1)
   ```

7. From the project root, run the isolated validator:

   ```powershell
   & '<path-to-your-Godot-console-executable>' --headless --path . --script res://scripts/dev/training_attack_validation.gd
   ```

   Expected output includes `PARTY_FORGE_TRAINING_ATTACK_VALID` and the process exits `0`.
8. As a learning check, expand the first damage component and temporarily set **Base Amount** to `0.0`, save, and run the validator again. Expected: a structured `PARTY_FORGE_DAMAGE_ERROR` mentioning a finite positive amount and a nonzero exit. Restore `11.0` and confirm the validator returns to exit `0`.
9. Press `F8`, then remove these exact disposable files through the FileSystem dock or filesystem:
   - `data/attacks/training_ranger_shot_disposable.tres`
   - `scripts/dev/training_attack_validation.gd`
   - `scripts/dev/training_attack_validation.gd.uid`, if Godot generated it
10. Run `git status --short` and compare it with step 1.

> **Checkpoint:** You inspected a custom Resource through exported fields, observed a failing and passing direct validation, and returned to the original Git status.

The unique training ID is good hygiene, but this direct attack check does not prove catalog registration or global attack-ID uniqueness. Production attacks are reached through class references in the current architecture.

## Production recipe: decide whether a change is data or behavior

Classify the requested change before opening a file:

| Requested change | Correct change kind | Party Forge example | Expected primary scope |
|---|---|---|---|
| Tune values within an existing definition schema. | **Resource edit** | Increase Ranger Shot cooldown without changing how cooldowns work. | `data/attacks/ranger_shot.tres` |
| Assemble or reposition nodes and Resources. | **Scene composition** | Add a presentation child beneath `companion.tscn`. | One `.tscn`, plus intentionally new presentation assets/scripts if required. |
| Add another class, trait, or enemy of an existing supported kind. | **Existing-kind registration** | Add a new enemy using an existing `EnemyDefinition.Behavior`. | New `.tres`, matching scene/reference if required, and the relevant `GameCatalog.*_PATHS` entry. |
| Introduce a rule the current schema and consumers cannot perform. | **New behavior code** | Add an attack kind with different targeting and execution semantics. | Definition enum/schema, consuming behavior, tests, content, and possibly scenes. |

Use this sequence:

1. State the player-facing goal in one sentence.
2. Find the current owner and consumer.
3. Check whether an exported field already expresses the change.
4. If yes, edit the Resource and validate it.
5. If the content is a new registered class, trait, or enemy, add the explicit catalog path.
6. If no existing field or behavior can express it, design and test the new behavior instead of hiding a rule in a data filename or scene node.
7. Predict the changed files, edit through the Inspector where practical, and compare the actual diff with that prediction.

> **Party Forge convention:** Data chooses among supported behavior and supplies values. It does not become executable merely because a designer wants a new rule.

## Verification

For this chapter, verify the live architecture:

- Open each schema in `scripts/data/` and one matching `.tres` under `data/`.
- Confirm the Inspector exposes the fields declared with `@export`.
- Search the explicit registries:

  ```powershell
  rg -n 'const (CLASS_PATHS|TRAIT_PATHS|ENEMY_PATHS)' scripts/data/game_catalog.gd
  ```

- Run the disposable attack exercise and observe one passing and one intentionally failing `validate()` result.
- Search `PARTY_FORGE_RESOURCE_ERROR` and identify both catalog-level and path-level formatting.
- After cleanup, confirm the before-and-after `git status --short` outputs match.

Do not continue if the Resource type is wrong, the Inspector is editing the production file instead of the copy, validation unexpectedly passes with a zero component amount, or cleanup leaves an unexplained `.tres`, `.gd`, or `.uid` file.

## Common mistakes

- **“I added a `.tres`, but the game cannot find it.”** A folder is not a registry. Add a class, trait, or enemy path to the matching `GameCatalog` constant, or add the correct owning reference for an attack or tuning Resource.
- **“I changed one Resource and several actors changed.”** The loaded instance is shared. Treat definitions as read-only, or duplicate intentionally for private runtime state.
- **“I edited a field, but Git shows a `.tscn` instead of the expected `.tres`.”** You edited a built-in Resource. Inspect its path and decide whether it should be made external.
- **“`load()` returned `null` or printed a missing-file error.”** Check the exact `res://` path, case, extension, and whether Godot recognizes the file.
- **“`preload(variable_path)` does not parse.”** `preload()` requires a constant string path. Use `load(variable_path)` when the path is selected at runtime.
- **“Validation passed, so the content is registered and balanced.”** Validation covers coded invariants only. Confirm registration, references, gameplay behavior, and balance separately.
- **“The ID looks like text, so a typo will be corrected.”** `StringName` does not validate spelling. Use a lookup or allowed-ID list and read the returned error.
- **“Duplicate ID means duplicate filename.”** The current catalog checks each registered Resource's `id` value, not only its filename.

## Rollback

1. Press `F8` and close the edited Resource Inspector.
2. If the edit is unsaved, use Undo in the same Inspector context or close without saving.
3. If it was saved, inspect `git diff -- <exact-resource-path>`.
4. Restore only the unintended fields through the Inspector.
5. If a disposable Resource was created, remove that exact `.tres` and any exact temporary validator `.gd`/`.uid` files.
6. Reopen the original Resource and run its relevant validation again.
7. Confirm `git status --short` matches the recorded baseline and no unrelated work was removed.

Never delete a broad directory or use `git reset --hard` to clean up one exercise. Roll back exact files and exact fields.

## Official Godot references

- [Resources](https://docs.godotengine.org/en/4.7/tutorials/scripting/resources.html)
- [Exported properties](https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/gdscript_exports.html)
- [ResourceLoader](https://docs.godotengine.org/en/4.7/classes/class_resourceloader.html)
