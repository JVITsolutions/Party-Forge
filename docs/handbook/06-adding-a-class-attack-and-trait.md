# 6. Adding a Class, Attack, and Trait

> **Handbook version:** Party Forge Typed Combat Task 8 architecture<br>
> **Godot version:** `4.7.1`<br>
> **Last checked:** `2026-07-30`

## What you will learn

- Add custom Resource files through the Godot Inspector.
- Build a class from behavior kinds Party Forge already supports.
- Validate linked attack, trait, and class data before registration.
- Register a recruit-only class without making it a starting leader.
- Identify additions that require new behavior code and tests.
- Remove a disposable content experiment without leaving broken references.

## What can reuse current behavior

Party Forge's party actor and executor already know how to execute four party-authored attack kinds: `MELEE_CLEAVE`, `PROJECTILE`, `AREA_PROJECTILE`, and `HEAL`. The full `AttackDefinition.Kind` enum also contains enemy-authored `DIRECT` and `AREA`; current party class execution does not support those two kinds. Party systems also know the supported trait stat IDs listed in Chapter 5. A new class can reuse supported party behavior by linking valid definitions; it does not need a new companion script merely because its numbers, color, or trait combination are new.

Registration is separate from creation. `GameCatalog` loads explicit arrays of known class and trait paths. It does not scan `data/` automatically. A valid file can therefore load in isolation while remaining unavailable during a normal run.

> **Party Forge convention:** Create content as custom `.tres` Resources, validate it in isolation, and then register it explicitly in `GameCatalog`. A file's presence under `data/` does not make it playable.

> **Current limitation:** Party Forge has no automatic content discovery. Every production class and trait path, plus the catalog test expectations that describe them, must be maintained by hand.

> **Godot rule:** A custom class that extends `Resource`, has a global `class_name`, and exports properties can be created and edited in the Inspector. Saving it as `.tres` stores those exported values and Resource references.

## Training example specification

The disposable example is a recruit-only **Training Warden**. Create these exact Resources:

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

## Step 3: create the recruit-only training class

1. Create a `ClassDefinition` Resource in `res://data/training/` and save it as `training_warden.tres`.
2. Enter the scalar values in the specification. Use the role list to choose `MIDLINE` and the color picker to enter the HTML hex value `4f9dd9`.
3. Expand the `Traits` array and set its size to two. This is an `Array[StringName]`, so it stores trait IDs rather than Resource references.
4. Enter `training_focus` in element `0` and `ranged` in element `1`.
5. Drag `training_warden_bolt.tres` into `Primary Attack`.
6. Leave `Support Action` empty and save.

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
    var failures: PackedStringArray = []

    if attack == null or focus == null or ranged == null or warden == null:
        failures.append("One or more training Resources did not load.")
    else:
        failures.append_array(attack.validate())
        failures.append_array(focus.validate())
        failures.append_array(warden.validate())
        if warden.primary_attack == null or warden.primary_attack.resource_path != attack.resource_path:
            failures.append("Training Warden references the wrong primary attack.")
        if &"training_focus" not in warden.traits or &"ranged" not in warden.traits:
            failures.append("Training Warden references the wrong trait IDs.")

        var catalog := GameCatalog.new()
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

## Step 5: register for recruitment

Open `scripts/data/game_catalog.gd`. Add these exact entries to the corresponding explicit arrays:

```gdscript
const CLASS_PATHS: PackedStringArray = [
    "res://data/classes/fighter.tres", "res://data/classes/ranger.tres",
    "res://data/classes/mage.tres", "res://data/classes/cleric.tres",
    "res://data/training/training_warden.tres"
]
const TRAIT_PATHS: PackedStringArray = [
    "res://data/traits/martial.tres", "res://data/traits/vanguard.tres",
    "res://data/traits/ranged.tres", "res://data/traits/arcane.tres",
    "res://data/traits/caster.tres", "res://data/traits/divine.tres",
    "res://data/traits/support.tres",
    "res://data/training/training_focus.tres"
]
```

These are the complete arrays after the additions. Preserve all existing entries. There is no attack-path array to edit because the class owns the primary-attack reference.

Update the required test contracts at the same time as the arrays. In `tests/unit/test_game_catalog.gd`, replace the two hard-coded size expectations with:

```gdscript
TestAssertions.equal(catalog.classes.size(), 5, "five classes", failures)
TestAssertions.equal(catalog.traits.size(), 8, "eight traits", failures)
```

The enemy count remains `3`. Then complete the catalog fixture:

- Add `[&"training_warden", &"primary_attack", "res://data/training/training_warden_bolt.tres"]` to `attack_links`.
- Add the exact Training Warden Bolt values to `attack_rows`, the exact Training Warden values to `class_rows`, and the exact Training Focus values to `trait_rows` in `_assert_generated_values()`.
- In `tests/unit/test_progression.gd`, add focused coverage that a generated recruit can target the registered `training_warden` while party space remains and that recruiting a second Training Warden makes `PartyManager.active_tier(&"training_focus")` equal `2`.

Run the catalog and progression tests, then start an ordinary run with an existing leader. While the party has fewer than four members, `LevelUpChoiceService` can offer one randomly selected registered class as a recruit choice. The Training Warden may not appear on the first level because recruitment is randomized. Choose it when offered.

The service allows a registered class to be recruited more than once. Recruit a second Training Warden and inspect the trait display or party state: two copies contribute two `training_focus` traits, activating its `2` threshold and the 10% attack-speed bonus. With a different leader occupying one of the four party slots, a recruit-only Training Warden can normally reach three copies, not the four-copy tier; the optional leader integration below makes four copies possible in a standard run.

> **Checkpoint:** Registration makes the class eligible for recruitment; it does not create a leader button or guarantee an immediate offer.

## Optional production step: make the class a selectable leader

A selectable leader requires UI and wiring work in addition to catalog registration:

1. Add a `Button` named `TrainingWarden` under `HUD/ClassSelection/Content` in `scenes/ui/hud.tscn` and give it the visible label **Training Warden**.
2. Update `PartyForgeMain._wire_static_ui()` in `scripts/game/main.gd` so the ID `&"training_warden"` resolves to `HUD/ClassSelection/Content/TrainingWarden` and connects to the same leader-selection callback as the existing buttons.
3. Do not rely on `String(class_id).capitalize()` for this ID: it produces a label with a space, while the node is named `TrainingWarden`. Prefer an explicit ID-to-node-path dictionary or wire this button explicitly.
4. Extend `tests/unit/test_main_wiring.gd::_test_hud_contract` to require the new button.
5. Extend `_test_class_selection_starts_run_and_applies_choices`, or add an equally focused wiring test, to press the Training Warden button and verify that `select_leader_class(&"training_warden")` starts the run with that leader.

The leader-specific files are therefore `scenes/ui/hud.tscn`, `scripts/game/main.gd`, and `tests/unit/test_main_wiring.gd`. UI presence without signal wiring is not a complete leader option.

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
3. Run the relevant class, attack, trait, party, combat-modifier, progression, and main-wiring suites for the behavior and integration points changed.
4. Load the combat sandbox and observe projectile travel, range, cadence, impact, formation distance, duplicate recruitment, and tier activation.
5. Run the full test suite once before committing.
6. Review `git diff --check` and `git status --short`. Remove disposable validator files and newly generated UID files that belong only to them.

For the Training Warden, confirm that the bolt is single-target, the support action stays absent, the class remains in the midline formation, a normal recruit offer works while the party is open, and two copies activate Training Focus tier 2.

## Common mistakes

- Creating a generic Resource instead of the custom `AttackDefinition`, `TraitDefinition`, or `ClassDefinition` type.
- Saving a linked definition as a built-in Resource instead of the named `.tres` file.
- Typing an enum number rather than selecting `PROJECTILE` in the Inspector.
- Using string keys for the tier dictionary when integer thresholds are required.
- Registering the class but forgetting its new trait path.
- Looking for an attack registry even though the class directly references its attack.
- Assuming catalog registration automatically adds a leader button.
- Wiring `training_warden` through `capitalize()` and looking for a node path containing a space.
- Expecting a randomized recruit to appear immediately or after the party reaches four members.
- Adding a new attack kind or trait stat without an executor/modifier and tests.
- Leaving the temporary validator, generated UID, or disposable training content in a production commit.

## Rollback

Remove references before removing their targets:

1. Delete the Training Warden entry from `GameCatalog.CLASS_PATHS` and the Training Focus entry from `GameCatalog.TRAIT_PATHS`. In the same change, restore the catalog expectations to four classes and seven traits, remove the three training rows and attack link from `tests/unit/test_game_catalog.gd`, and remove the Training Warden recruitment/tier expectations from `tests/unit/test_progression.gd`.
2. If leader support was added, remove its signal wiring and button plus the associated `tests/unit/test_main_wiring.gd` expectations.
3. Run a headless project parse plus the catalog and progression tests. This proves no startup or required test code still tries to load the training paths.
4. Delete `training_warden.tres`, `training_focus.tres`, and `training_warden_bolt.tres` from `data/training/`. Remove the directory if it is empty.
5. Run the relevant suites again, inspect the diff, and confirm no generated UID remains for deleted disposable files.

Deleting the Resources first creates broken catalog and cross-Resource paths, so registration comes out first.

## Official Godot references

- [Resources](https://docs.godotengine.org/en/4.7/tutorials/scripting/resources.html)
- [Creating custom Resources](https://docs.godotengine.org/en/4.7/tutorials/scripting/resources.html#creating-your-own-resources)
- [Exported properties](https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/gdscript_exports.html)
- [Using signals](https://docs.godotengine.org/en/4.7/getting_started/step_by_step/signals.html)
- [Project organization](https://docs.godotengine.org/en/4.7/tutorials/best_practices/project_organization.html)
