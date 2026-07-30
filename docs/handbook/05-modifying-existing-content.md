# 5. Modifying Existing Party Forge Content Safely

> **Handbook version:** Party Forge Typed Combat Task 8 architecture<br>
> **Godot version:** `4.7.1`<br>
> **Last checked:** `2026-07-30`

## What you will learn

- Find the Resource or script that owns a balance value.
- Predict which visible behavior a field can change.
- Change one value through the Inspector and verify it in a focused sandbox.
- Recognize values that are still script-owned rather than data-driven.
- Restore an experiment cleanly when its result is not worth keeping.

## Start with the owning Resource or script

A value is safe to tune only after you know where it is defined and where it is consumed. Start from the visible behavior, find its owner in this table, and open that file in the Godot FileSystem dock. Selecting an external `.tres` file exposes its exported properties in the Inspector.

> **Party Forge convention:** Tune data-owned values in their external definition Resources. Treat script-owned constants as behavior changes that require source review and the relevant script tests.

| Editable value | Owning file or type | Observable effect |
| --- | --- | --- |
| Class health, armor, speed, rank damage step, revive settings, formation distances, attacks | `ClassDefinition` Resources in `data/classes/` | Companion durability, movement, class-rank typed-damage scaling, revival, formation, and actions |
| Attack kind, typed damage components or healing power, action tags, crit permission, cooldown, range, projectile speed, area radius | `AttackDefinition` Resources in `data/attacks/` | Which executor runs, typed impact strength, modifier context, attack frequency, reach, projectile travel, and effect size |
| Trait stat, thresholds, bonuses, radius | `TraitDefinition` Resources in `data/traits/` | Party bonuses activated by duplicate trait counts |
| Enemy health, speed, linked attacks, stat overrides, experience | `EnemyDefinition` Resources in `data/enemies/` | Enemy durability, movement, typed offense/defense, and experience drops |
| Spitter spacing and firing cadence | `scripts/enemies/spitter.gd` constants | Retreat distance, preferred distance, and time between shots |
| Swarmer contact reach, cadence, tags, and damage | `data/attacks/swarmer_contact.tres` | Contact-hit eligibility, cooldown, modifier context, and Physical amount |
| Spawn interval and enemy mix over five minutes | `scripts/game/spawn_schedule.gd` time bands | Encounter density and the Swarmer/Spitter ratio as a run advances |
| Party upgrade limits and per-rank steps | `UpgradeTuning` Resource | The party-stat maximum rank and the per-rank steps for party stats and trait upgrades |
| Current party upgrade ranks | `PartyManager` | Health, Damage, Move Speed, Attack Speed, and Pickup Range levels, plus separate ranks for each active trait |

> **Checkpoint:** If a value is not exported on a Resource, changing a similarly named `.tres` field will not affect it. Follow the owning script instead.

## Class and formation values

Each file in `data/classes/` is a `ClassDefinition`. Its exported values include:

- `max_health`, `armor`, and `move_speed` for base survivability and movement.
- `class_rank_power_step` for the typed attack damage gained from each class rank above one. It does not scale healing.
- `revive_delay` and `revive_health_fraction` for revival timing and returned health.
- `role`, `preferred_distance`, `engagement_distance`, and `tether_distance` for formation intent.
- `primary_attack` and the optional `support_action`, which reference `AttackDefinition` Resources.

The role chooses the companion's formation lane. `preferred_distance` and `tether_distance` are consumed by the current companion formation behavior. Larger values are not automatically better: a companion that travels farther may spend more time moving and less time acting.

> **Current limitation:** `engagement_distance` is exported as class data, but the current validator does not constrain it and the verified architecture does not consume it during runtime targeting or formation movement. Editing it alone has no observable gameplay effect yet.

`ClassDefinition.validate()` requires a non-empty ID and display name, at least one trait, positive health and revive delay, a non-negative rank step, a revive fraction greater than zero and no greater than one, and a valid primary attack. A support action is optional, but it must validate when assigned.

## Attack values

A party-authored `AttackDefinition` executed by `AttackExecutor` chooses one of four supported party kinds:

- `MELEE_CLEAVE` applies a close area hit.
- `PROJECTILE` launches a projectile at a target.
- `AREA_PROJECTILE` launches a projectile that bursts in an area.
- `HEAL` restores health instead of damaging an enemy.

The full `AttackDefinition.Kind` enum also includes `DIRECT` and `AREA`. Those kinds are used by linked enemy attacks whose behavior scripts own delivery; they are not additional party execution kinds.

The common fields are `cooldown`, `range`, `action_tags`, and `can_crit`. Projectile kinds also use `projectile_speed`; area-capable execution uses `area_radius`. Damaging actions own one or more `AttackDamageComponent` entries, each with a `damage_type_id` and positive `base_amount`. A `HEAL` owns positive `power` instead and must have no damage components.

Validation requires a non-empty ID, finite positive cooldown and range, normalized nonempty action tags, and valid kind-specific fields. Damaging actions require at least one unique typed component; heals require positive power, cannot crit, and reject damage components. `PROJECTILE` and `AREA_PROJECTILE` require positive projectile speed. Area radius must be finite and nonnegative, so a plain projectile may intentionally use `0.0`; a useful cleave or area burst still needs a practical positive radius.

> **Godot rule:** The Inspector restricts an exported enum to known choices, but the runtime behavior still has to support the selected kind. Adding a new enum entry is behavior work, not a data-only balance edit.

## Trait tiers and supported effects

A `TraitDefinition` has an ID, display name, `stat_id`, tier dictionary, and `effect_radius`. The current supported stat IDs are:

- `attack_speed`
- `nearby_damage_reduction`
- `projectile_speed_and_range`
- `area_size`
- `cooldown_reduction`
- `healing_and_revive`
- `support_power`

The tier dictionary maps a required trait count to a bonus, such as `{ 2: 0.15, 4: 0.35 }`. Party members can share traits, so duplicate recruits may activate a threshold. Thresholds must be at least two.

The Vanguard trait uses `nearby_damage_reduction`. Its `effect_radius` is required to be positive and limits which companions receive its protection. The current damage-reduction runtime also recognizes the trait by the ID `vanguard`; changing that ID would break the effect even if the stat ID still validates. The revive-delay behavior similarly recognizes the Divine trait by its existing `divine` ID.

> **Current limitation:** A valid `stat_id` proves that the definition is supported, but a special ID-based behavior can impose an additional contract. Preserve existing IDs during balance work.

## Enemy values and script constants

An `EnemyDefinition` exports `max_health`, `move_speed`, typed `stat_overrides`, linked `attacks`, and `experience`. The behavior enum determines which exact attack IDs must be present:

- `SWARMER` requires `swarmer_contact`, a close direct contact hit.
- `SPITTER` requires `spitter_projectile`, whose packet is prepared when the Spitter fires and delivered by the hostile projectile.
- `FORGE_GUARDIAN` requires both `guardian_charge`, prepared once per charge and resolved at most once for each crossed target, and `guardian_shockwave`, an area attack resolved independently against each target in its radius.

Validation checks these attack links against the damage-type catalog and stat overrides against the stat catalog; it still cannot prove that the resulting balance feels good.

Some enemy behavior remains in scripts:

- `scripts/enemies/spitter.gd` owns `PREFERRED_DISTANCE = 8.0`, `RETREAT_DISTANCE = 5.0`, and the initial/fallback `FIRE_INTERVAL = 2.2`; its authored attack owns the normal cooldown.
- `scripts/enemies/enemy_projectile.gd` owns delivery `SPEED = 6.0` and `MAX_LIFETIME = 3.0`.
- `data/attacks/swarmer_contact.tres` owns Swarmer contact reach, cooldown, tags, and Physical damage.
- `data/attacks/guardian_charge.tres` and `data/attacks/guardian_shockwave.tres` own the Forge Guardian's typed charge and radial damage respectively; Guardian movement, per-charge deduplication, and target collection remain behavior-script responsibilities.

These delivery and spacing constants are not fields on `EnemyDefinition`. Change attack damage, range, and cooldown in the linked `AttackDefinition`; change movement spacing or projectile flight only in the owning behavior script and its tests.

The five-minute spawn curve is also script-owned in `SpawnSchedule`:

| Run time | Spawn interval | Swarmer weight | Spitter weight |
| --- | ---: | ---: | ---: |
| `0` to under `60` seconds | `1.25` | `100` | `0` |
| `60` to under `150` seconds | `0.90` | `80` | `20` |
| `150` to under `240` seconds | `0.65` | `65` | `35` |
| `240` to under `300` seconds | `0.45` | `55` | `45` |

Times before zero or at least 300 seconds have no schedule band. Editing these bands changes pacing code and deserves script tests plus an ordinary run, not only a Resource check.

## Party upgrades and spawn timing

`UpgradeTuning` owns the maximum rank and per-rank step for upgrades. `PartyManager` tracks five party-stat ranks: Health, Damage, Move Speed, Attack Speed, and Pickup Range. It also keeps a separate upgrade rank for each active trait. Most party-stat multipliers use `1.0 + rank * step`; a trait's own upgrade rank scales that trait's active tier value.

Damage and healing now have separate resolver paths. Party Damage scales typed damage components during packet preparation; healing reads `healing_power` and creates no damage packet. Balance and test them independently.

Spawn timing is independent of these party ranks. It is selected from the five script-owned time bands above.

## Exercise: make one reversible balance change

This exercise changes the Spitter from a one-hit target for the Fighter's 18-Physical cleave into a two-hit target, then restores the original value.

1. Before editing, run `git status --short` and note the current output. Do not continue if `data/enemies/spitter.tres` already has an unrelated change.
2. In the FileSystem dock, select `res://data/enemies/spitter.tres`.
3. In the Inspector, confirm that `Max Health` is `18.0`. Change it to `20.0`, then save the Resource with **Ctrl+S**.
4. Double-click `res://scenes/dev/combat_sandbox.tscn` to open it, then run the current scene with **F6**.
5. Spawn a Spitter and move the Fighter close enough to cleave it. Observe that the first 18-Physical hit leaves a small amount of health and the second hit defeats it.
6. Stop the sandbox. Set `Max Health` back to `18.0` in the Inspector and save.
7. Run the same sandbox action again. Observe the restored one-hit result.
8. In a terminal at the repository root, run `git diff -- data/enemies/spitter.tres`. It should print nothing. Run `git status --short` and compare it with the output from step 1.

> **Checkpoint:** The experiment is complete only when the visible behavior returned to baseline and the file diff disappeared.

## Production recipe: tune, observe, and record a change

1. Write the intended player effect in one sentence, such as “Spitters should survive one baseline Fighter cleave.”
2. Identify the owning Resource or script and confirm the present value.
3. Change one value only. Multiple simultaneous changes make the cause of an observed result ambiguous.
4. Run the narrowest validation that exercises the owner.
5. Observe the behavior in a focused sandbox and record what happened, including the test setup.
6. If the change affects spawn pacing or the shape of a normal run, play an ordinary run through the affected time band.
7. Review the diff. Keep generated files and unrelated formatting out of it.
8. Commit the balance change separately with its intended effect and observation in the commit message or review notes.

## Verification ladder

Use the smallest rung that can fail for the change, then climb as needed:

1. **Resource validation:** load the changed definition and call its `validate()` method.
2. **Relevant unit suite:** run the definition, modifier, enemy, party, or spawn-schedule tests that consume the value.
3. **Focused sandbox:** reproduce the intended visible effect with controlled actors and timing.
4. **Ordinary run:** use this when pacing, progression, party composition, or encounter pressure changed.

A passing validator does not prove game feel. A good-looking sandbox moment does not prove the Resource remains structurally valid. Keep both checks.

## Common mistakes

- Editing a Resource without checking whether it is external and shared.
- Tuning `engagement_distance` and expecting a runtime change in the current architecture.
- Setting an area attack's radius to zero because the validator permits it.
- Renaming `vanguard` or `divine` without updating their ID-based behavior and tests.
- Looking for Spitter cadence, Swarmer contact timing, or spawn bands in enemy `.tres` files.
- Editing healing power and expecting it to change damaging packets, or editing Party Damage and expecting it to strengthen healing.
- Changing several values before observing any one of them.
- Treating a parse or validation pass as proof that the balance result feels correct.
- Forgetting to restore a disposable exercise and confirm that its diff is empty.

## Rollback

For an uncommitted Inspector experiment, restore the exact original value, save, and verify the file diff disappears. If the file contained work before your experiment, restore only your changed field; do not discard the entire file.

For a committed production change, prefer a normal revert commit so the history records why the balance was undone. Re-run the same validation and observation that justified the original change.

## Official Godot references

- [Resources](https://docs.godotengine.org/en/4.7/tutorials/scripting/resources.html)
- [Creating your own resources](https://docs.godotengine.org/en/4.7/tutorials/scripting/resources.html#creating-your-own-resources)
- [GDScript exported properties](https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/gdscript_exports.html)
- [Project organization](https://docs.godotengine.org/en/4.7/tutorials/best_practices/project_organization.html)
