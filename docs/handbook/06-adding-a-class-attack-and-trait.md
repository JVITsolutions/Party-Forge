# 6. Adding a Class, Attack, and Trait

> **Runtime architecture:** Party Forge nine-class selector at `b0be05a03bbd3ea5aae04d3e38ffdc0769a211ba`<br>
> **Handbook wording alignment:** `9f1b9bbb5cdc04374b3288ada07eb8081032a188`<br>
> **Godot version:** `4.7.1`<br>
> **Last checked:** `2026-07-30`

## What you will learn

- Add custom Resource files through the Godot Inspector.
- Build a class from behavior kinds Party Forge already supports.
- Validate linked attack, trait, and class data before registration.
- Register a party-supported class for both leader selection and recruitment.
- Identify additions that require new behavior code and tests.
- Remove a disposable content experiment without leaving broken references.

## What can reuse current behavior

Party Forge's party actor and executor already know how to execute four party-authored attack kinds: `MELEE_CLEAVE`, `PROJECTILE`, `AREA_PROJECTILE`, and `HEAL`. The full `AttackDefinition.Kind` enum also contains enemy-authored `DIRECT` and `AREA`; current party class execution does not support those two kinds. Party systems also know the supported trait stat IDs listed in Chapter 5. A new class can reuse supported party behavior by linking valid definitions; it does not need a new companion script merely because its numbers, color, or trait combination are new.

Registration is separate from creation. `GameCatalog` loads explicit arrays of known class and trait paths. It does not scan `data/` automatically. A valid file can therefore load in isolation while remaining unavailable during a normal run. Once a valid class is registered, both current consumers read the same ordered `catalog.classes`: `ClassSelectionPanel` creates its leader button and `LevelUpChoiceService` can create recruit choices while party space remains.

> **Party Forge convention:** Create content as custom `.tres` Resources, validate it in isolation, and then register it explicitly in `GameCatalog`. A file's presence under `data/` does not make it playable.

> **Current limitation:** Party Forge has no automatic content discovery. Every production class and trait path, plus the catalog test expectations that describe them, must be maintained by hand.

> **Godot rule:** A custom class that extends `Resource`, has a global `class_name`, and exports properties can be created and edited in the Inspector. Saving it as `.tres` stores those exported values and Resource references.

## Training example specification

The disposable example is a party-supported **Training Warden**. Create these exact Resources:

| Resource | Property | Value |
| --- | --- | --- |
| `data/training/training_warden_bolt.tres` | `id` | `training_warden_bolt` |
|  | `kind` | `PROJECTILE` |
|  | `damage_components[0].damage_type_id` | `physical` |
|  | `damage_components[0].base_amount` | `10.0` |
|  | `action_tags` | `[projectile, ranged]` |
|  | `can_crit` | `true` |
|  | `cooldown` | `1.0` |
|  | `range` | `10.0` |
|  | `projectile_speed` | `14.0` |
|  | `area_radius` | `0.0` |
| `data/training/training_focus.tres` | `id` | `training_focus` |
|  | `display_name` | `Training Focus` |
|  | `stat_id` | `attack_speed` |
|  | `tiers` | `{ 2: 0.10, 4: 0.25 }` |
|  | `effect_radius` | `0.0` |
| `data/training/training_warden.tres` | `id` | `training_warden` |
|  | `display_name` | `Training Warden` |
|  | `role` | `MIDLINE` |
|  | `color` | `#4f9dd9` |
|  | `traits` | `[training_focus, ranged]` |
|  | `capability_tags` | `[projectile, ranged]` |
|  | `base_stat_overrides` | `{}` |
|  | `max_health` | `110.0` |
|  | `armor` | `3.0` |
|  | `move_speed` | `6.2` |
|  | `class_rank_power_step` | `0.2` |
|  | `revive_delay` | `8.0` |
|  | `revive_health_fraction` | `0.5` |
|  | `preferred_distance` | `4.5` |
|  | `engagement_distance` | `10.0` |
|  | `tether_distance` | `10.0` |
|  | `primary_attack` | `training_warden_bolt` |
|  | `support_action` | empty |

The paths shown in the table are repository-relative. In Godot they appear with the `res://` prefix.

## Step 1: create the training attack

1. In the FileSystem dock, right-click `res://data/`, choose **New Folder**, and create `training` if it does not exist.
2. Right-click `res://data/training/`, choose **Create New > Resource**, select `AttackDefinition`, and choose **Create**.
3. Save it as `training_warden_bolt.tres` in that folder.
4. Enter the scalar attack values from the specification table. Select `PROJECTILE` from the `Kind` list; do not type a numeric enum value.
5. Expand `Damage Components`, set the array size to one, and create a new `AttackDamageComponent` in element `0`. Set its type ID to `physical` and base amount to `10.0`.
6. Expand `Action Tags`, set its size to two, and enter `projectile` and `ranged` once each. Enable `Can Crit`.
7. Save with **Ctrl+S** and confirm the Inspector header shows `res://data/training/training_warden_bolt.tres`.

This definition validates because its ID is non-empty, cooldown/range/projectile speed are finite and positive, its tags are nonempty and unique, and its one Physical component has a positive amount recognized by the baseline damage-type catalog. A zero area radius is intentional for this single-target projectile. Leave healing `power` at zero because damaging actions derive authored amounts only from components.

## Step 2: create the training trait

1. Create another custom Resource in `res://data/training/`, this time choosing `TraitDefinition`.
2. Save it as `training_focus.tres`.
3. Set the ID, display name, `attack_speed` stat ID, and zero effect radius.
4. Expand the `Tiers` dictionary in the Inspector. Set its size to two, then add integer threshold `2` with float value `0.10` and integer threshold `4` with float value `0.25`.
5. Save and reopen the file to confirm the dictionary retained both typed entries.

This trait validates because `attack_speed` is supported and both thresholds are at least two. Only `nearby_damage_reduction` requires a positive radius, so `0.0` is valid here.

## Step 3: create the training class

1. Create a `ClassDefinition` Resource in `res://data/training/` and save it as `training_warden.tres`.
2. Enter the scalar values in the specification. Use the role list to choose `MIDLINE` and the color picker to enter the HTML hex value `4f9dd9`.
3. Expand the `Traits` array and set its size to two. This is an `Array[StringName]`, so it stores trait IDs rather than Resource references.
4. Enter `training_focus` in element `0` and `ranged` in element `1`.
5. Set `Capability Tags` to `projectile` and `ranged`. Leave `Base Stat Overrides` empty because this example uses the ordinary health, armor, and movement fields without a specialized stat identity.
6. Drag `training_warden_bolt.tres` into `Primary Attack`.
7. Leave `Support Action` empty and save.

The class validates because it has identity text, a non-empty trait-ID array, positive health and revive values, a non-negative rank step, a revive fraction in `(0, 1]`, and a valid primary attack. `ClassDefinition.validate()` does not resolve trait IDs, so the isolated check below also verifies the expected IDs and loads both definitions. A support action is optional. The existing companion behavior can run its projectile and formation role without a Training Warden-specific script.

> **Checkpoint:** Click the linked primary attack in the class Inspector and confirm its path. An accidental built-in Resource may look correct but will not be the named training file expected by validation and registration. Also confirm the trait ID strings exactly match the registered definitions.

## Step 4: validate in isolation

Do this before editing catalog constants. A temporary `SceneTree` script can load the files, run their validators, and prove that two class copies activate the first Training Focus tier.

Create `res://scripts/dev/training_warden_validation.gd` with this temporary code:

```gdscript
extends SceneTree

func _init() -> void:
    var attack := load("res://data/training/training_warden_bolt.tres") as AttackDefinition
    var focus := load("res://data/training/training_focus.tres") as TraitDefinition
    var ranged := load("res://data/traits/ranged.tres") as TraitDefinition
    var warden := load("res://data/training/training_warden.tres") as ClassDefinition
    var types := GameCatalog.load_defaults().damage_types
    var failures: PackedStringArray = []

    if attack == null or focus == null or ranged == null or warden == null:
        failures.append("One or more training Resources did not load.")
    else:
        failures.append_array(attack.validate(types))
        failures.append_array(focus.validate())
        failures.append_array(warden.validate(types))
        if warden.primary_attack == null or warden.primary_attack.resource_path != attack.resource_path:
            failures.append("Training Warden references the wrong primary attack.")
        if &"training_focus" not in warden.traits or &"ranged" not in warden.traits:
            failures.append("Training Warden references the wrong trait IDs.")

        var catalog := GameCatalog.new()
        catalog.damage_types = types
        catalog.classes.append(warden)
        catalog.traits.append(focus)
        catalog.traits.append(ranged)
        failures.append_array(catalog.validate())

        var party := PartyManager.new()
        var trait_definitions: Array[TraitDefinition] = []
        trait_definitions.append(focus)
        trait_definitions.append(ranged)
        party.initialize(warden, trait_definitions)
        party.recruit(warden)
        if party.active_tier(&"training_focus") != 2:
            failures.append("Two Training Wardens did not activate Training Focus tier 2.")
        party.free()

    if failures.is_empty():
        print("TRAINING_WARDEN_VALID")
        quit(0)
    else:
        for failure: String in failures:
            push_error(failure)
        quit(1)
```

Run it from the repository root:

```powershell
godot --headless --path . --script res://scripts/dev/training_warden_validation.gd
```

Expect exit code zero and `TRAINING_WARDEN_VALID`. Then delete the temporary validation script and any generated UID belonging to it. Check `git status --short` so only the three intended training Resources remain from this stage.

This isolated catalog is local to the validator. It proves that the files link and validate without changing `GameCatalog.CLASS_PATHS` or `GameCatalog.TRAIT_PATHS`.

## Step 5: register for leader and recruit flows

Open `scripts/data/game_catalog.gd`. Preserve the existing nine class paths and thirteen trait paths, then append the two new entries to the corresponding explicit arrays:

```gdscript
const CLASS_PATHS: PackedStringArray = [
    # fighter, ranger, mage, cleric, paladin, rogue,
    # frost_mage, warlock, and marksman remain in their current order.
    "res://data/training/training_warden.tres",
]
const TRAIT_PATHS: PackedStringArray = [
    # All thirteen current trait paths remain.
    "res://data/training/training_focus.tres",
]
```

The comments abbreviate unchanged entries; do not replace the actual arrays with only the shown path. There is no attack-path array to edit because the class owns the primary-attack reference.

Update the catalog contracts at the same time. The registered result contains ten classes, fourteen traits, and the unchanged three enemies. Extend the existing catalog fixtures with:

- the exact ordered `training_warden` class ID after Marksman;
- `[&"training_warden", &"primary_attack", "res://data/training/training_warden_bolt.tres"]` in the attack-link expectations;
- the exact Training Warden Bolt, Training Warden, and Training Focus authored values;
- focused progression coverage that a recruit choice can target `training_warden` while party space remains and two copies activate Training Focus tier `2`;
- selector/Main coverage that `Class_training_warden` exists and emits the exact ID.

Run the catalog, selector, progression, and main-wiring suites. Then test both production consumers:

1. Start a fresh run and press the generated **Training Warden** leader button.
2. Confirm the leader's `class_definition.id` is `training_warden` and its projectile prepares and executes.
3. In another run, use a deterministic or isolated choice fixture to recruit Training Warden while the party has fewer than four members.
4. Recruit a second copy and confirm two `training_focus` contributions activate the `2` threshold and its 10% attack-speed bonus.
5. Confirm a fifth member is still rejected by `PartyManager.MAX_PARTY_SIZE`.

> **Checkpoint:** One validated `CLASS_PATHS` entry supplies the same `ClassDefinition` to leader and recruit flows. Registration does not guarantee a randomized recruit appears immediately, and it does not bypass the four-member cap.

## Why one registration reaches both flows

`PartyForgeMain._wire_static_ui()` passes `catalog.classes` to `ClassSelectionPanel.configure()`. The panel creates `Class_<id>` buttons at runtime and emits `class_selected(definition.id)`. No class-specific HUD node or callback branch is required.

`LevelUpChoiceService` also consumes the registered class array when it builds recruit choices. `PartyManager.recruit()` receives the same `ClassDefinition`, while `PartyActorSpawner` configures the companion from the resulting member state. Therefore a valid registered class using an already-supported attack kind and valid traits enters both flows without a class-specific actor script.

Registration still does not implement unsupported behavior. If the class asks for a new attack kind, targeting policy, stat effect, summon, or manual ability, add that behavior and its tests before registering content that depends on it.

## When a class requires new behavior

Resource-only reuse ends when the design asks the runtime to do something it cannot already execute. These additions require behavior code and focused tests:

- A new attack kind outside melee cleave, projectile, area projectile, and heal.
- Summoned units or persistent deployables.
- Auras with new recipient rules or continuous effects.
- Manual abilities or new player input.
- A new targeting policy, such as lowest-health enemy, chained targets, or geometry-aware priority.
- A trait stat outside the supported stat IDs, or a new special interaction tied to class or trait identity.

Define the data contract, add runtime consumption, reject unsupported values clearly, and test both definition validation and visible execution. Merely adding an enum value or stat string can make a Resource appear configurable while doing nothing useful in play.

Signals are a good boundary when one system needs to announce an event without knowing every receiver. For example, a manual-ability button could emit an activation request that the owning gameplay system validates and handles. The signal does not replace the behavior implementation; it decouples the sender from it.

## Tests and sandbox verification

Use this order for production content:

1. Run the isolated loader/validator before registration.
2. Run `tests/unit/test_game_catalog.gd` after changing catalog arrays.
3. Run the relevant class, attack, trait, party, selector, progression, and main-wiring suites for the behavior and integration points changed.
4. Load the combat sandbox and observe projectile travel, range, cadence, impact, formation distance, duplicate recruitment, and tier activation.
5. Run the full test suite once before committing.
6. Review `git diff --check` and `git status --short`. Remove disposable validator files and newly generated UID files that belong only to them.

For the Training Warden, confirm that the bolt is single-target, the support action stays absent, the generated leader button starts the exact class, the class remains in the midline formation, a recruit choice works while the party is open, and two copies activate Training Focus tier 2.

## Common mistakes

- Creating a generic Resource instead of the custom `AttackDefinition`, `TraitDefinition`, or `ClassDefinition` type.
- Saving a linked definition as a built-in Resource instead of the named `.tres` file.
- Typing an enum number rather than selecting `PROJECTILE` in the Inspector.
- Using string keys for the tier dictionary when integer thresholds are required.
- Registering the class but forgetting its new trait path.
- Looking for an attack registry even though the class directly references its attack.
- Adding a hand-authored HUD button even though `ClassSelectionPanel` owns runtime class buttons from the catalog.
- Deriving a node path from a display name instead of using the stable runtime name `Class_<id>` and emitted ID.
- Expecting a randomized recruit to appear immediately or after the party reaches four members.
- Adding a new attack kind or trait stat without an executor/modifier and tests.
- Leaving the temporary validator, generated UID, or disposable training content in a production commit.

## Rollback

Remove references before removing their targets:

1. Delete the Training Warden entry from `GameCatalog.CLASS_PATHS` and the Training Focus entry from `GameCatalog.TRAIT_PATHS`. In the same change, restore the catalog expectations to nine classes and thirteen traits, remove the three training rows and attack link, and remove the Training Warden leader/recruit/tier expectations.
2. Run a headless project parse plus the catalog, selector, progression, and main-wiring tests. This proves no startup or required test code still tries to load the training paths.
3. Delete `training_warden.tres`, `training_focus.tres`, and `training_warden_bolt.tres` from `data/training/`. Remove the directory if it is empty.
4. Run the relevant suites again, inspect the diff, and confirm no generated UID remains for deleted disposable files.

Deleting the Resources first creates broken catalog and cross-Resource paths, so registration comes out first.

## Official Godot references

- [Resources](https://docs.godotengine.org/en/4.7/tutorials/scripting/resources.html)
- [Creating custom Resources](https://docs.godotengine.org/en/4.7/tutorials/scripting/resources.html#creating-your-own-resources)
- [Exported properties](https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/gdscript_exports.html)
- [Using signals](https://docs.godotengine.org/en/4.7/getting_started/step_by_step/signals.html)
- [Project organization](https://docs.godotengine.org/en/4.7/tutorials/best_practices/project_organization.html)
