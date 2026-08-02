# Character Ledger Party Count and Combat Estimates Design

Date: 2026-08-01
Status: Approved for implementation planning

## Purpose

Make the character ledger answer two immediate player questions:

1. How many party slots are currently occupied and available?
2. What damage does each damaging action owned by the selected character actually deal?

This work adds theoretical character-sheet estimates. Floating combat numbers and measured damage/healing performance are deliberately separate later systems.

## Player-facing behavior

### Party capacity label

The roster rail displays `Party Members: <current> / <capacity>` immediately above the character list. The current value comes from `PartyManager.members.size()`. The maximum comes from `PartyManager.capacity()`, so production limits, developer overrides, and later progression-controlled capacity use the same display without UI-specific rules.

The label refreshes when the ledger opens, when the provider reports a party change, and whenever the ledger is explicitly refreshed. It remains above the roster in desktop and compact layouts.

### Combat Estimates section

The selected character's Stats page displays a `Combat Estimates` section before the ordinary stat groups. Every currently owned action that has damage components receives an entry. Healing-only actions are excluded from this section.

Each damaging action displays:

- Normal Hit
- Critical Hit, or `Cannot Crit`
- Average Hit
- Attacks per Second
- Estimated DPS
- A per-damage-type breakdown when the action contains more than one damage component

The existing `Damage`, typed-damage, critical-strike, and attack-speed multiplier rows remain visible. They explain the modifiers used by the estimates rather than being replaced by derived numbers.

## Estimate semantics

All estimates are pre-mitigation, per target, and assume the action is used continuously whenever it becomes ready. They do not include target armor, resistances, dodge, block, incoming-damage modifiers, projectile travel time, misses, target acquisition, movement, AI downtime, overkill, or additional targets hit by an area attack.

For each damage component:

```text
normal component = authored base amount
                 * action-aware global Damage multiplier
                 * action-aware typed-damage multiplier
```

The action's Normal Hit is the sum of its normal components.

```text
critical hit = normal hit * critical-strike multiplier
average hit  = normal hit * (1 + crit chance * (crit multiplier - 1))
attacks/sec  = resolved cooldown-rate multiplier / authored cooldown
estimated DPS = average hit * attacks/sec
```

For actions that cannot critically strike, Critical Hit displays `Cannot Crit`, Average Hit equals Normal Hit, and no critical probability is applied. Critical chance uses the finalized capped stat value. Critical multiplier has the same minimum of `1.0` used by combat.

Damage scaling uses `PartyManager.stats_for_action()` with `DamageResolver.action_tags_for()` so tag-gated upgrades affect the same attacks in the sheet and in combat. Cooldown rate uses the context-free resolved attack-speed value because the current runtime advances all action controllers through `CombatModifiers.resolve()` using that value. This keeps the sheet faithful to current execution instead of inventing action-specific cooldown behavior.

An area attack reports damage to one target. It is never multiplied by an assumed enemy count. A multi-component hit reports the total and component values. True multi-hit sequences, damage over time, channeling, conditional repeats, and other timing models display an unavailable explanation until their authored action data contains enough information for a truthful estimate.

## Architecture

### `ActionCombatEstimate`

A typed read model carries the UI result without exposing combat internals:

- action ID and display label
- availability and unavailable reason
- can-crit flag
- normal hit
- critical hit
- average hit
- attacks per second
- estimated DPS
- ordered damage-type component rows

### `ActionCombatEstimateService`

A pure `RefCounted` service calculates one estimate from an `AttackDefinition`, selected member ID, `PartyManager`, and `DamageTypeCatalog`. It reuses existing action-tag and stat-resolution contracts but does not roll RNG or resolve against a target. Invalid or unsupported data returns an unavailable estimate instead of silently omitting the action or displaying a misleading zero.

The estimate service owns the formulas. Neither `StatsLedgerPage` nor `LedgerDataProvider` duplicates combat arithmetic.

### `LedgerDataProvider`

`LedgerDataProvider.combat_estimate_rows(member_id)` supplies every damaging action for the selected character in stable authored order. Under the current class schema, the action source adapter inspects `primary_attack` followed by `support_action`, removes null entries, removes duplicate action resources/IDs, and filters actions without damage components.

The estimator accepts an array of actions internally. When classes gain basic attacks, multiple primaries, and multiple ultimates, only the action-source adapter changes; estimation and UI rendering remain unchanged. This feature does not expand `ClassDefinition` itself, avoiding conflict with the separate class-model/equipment implementation.

### Ledger UI

The character ledger's first split pane becomes a roster column containing the capacity label and the existing scrollable member list. Existing focus navigation and 24-member scrolling remain intact after node paths are updated.

The Stats page renders combat entries at the top of its existing scrollable stat-group container, followed by the normal Overview, Offense, Defense, Resistances, and Utility groups. This lets future characters expose several actions without permanently consuming fixed vertical space or crushing the detail panel. The section and entries use visible text; tooltips repeat the pre-mitigation/per-target caveat.

Desktop, compact, keyboard/mouse, and controller behavior remain supported. The combat entries are informational and do not steal the existing first-stat focus target.

## Formatting

- Hit and DPS values use up to two decimal places and omit unnecessary trailing zeroes.
- Attacks per Second uses two decimal places.
- Damage-type labels come from the damage-type catalog when available and fall back to a humanized ID.
- Action labels currently humanize the action ID because `AttackDefinition` has no authored display-name field. A future authored label can replace that fallback without changing the estimate model.
- Unavailable actions show their reason rather than invented numeric values.

## Error handling

The service returns an unavailable estimate when any required input is missing, the attack is healing-only, the cooldown is non-finite or non-positive, a damage component is null, a damage type is unknown, a required resolved snapshot is missing, or any derived number is non-finite or negative.

Normal valid actions remain visible if another action is unavailable. UI refreshes tolerate a missing selected member by clearing the combat section along with the existing identity/stat content.

## Testing

Implementation follows strict red-green TDD.

Unit coverage will prove:

- party capacity text uses live member count and `PartyManager.capacity()`
- the capacity label refreshes after recruitment and supports developer capacity 24
- normal, critical, average-hit, attacks-per-second, and DPS formulas
- action-aware global and typed modifiers affect the correct action
- non-critical and mixed-damage actions
- stable action ordering and duplicate filtering
- healing-only action exclusion
- invalid/unsupported actions produce explanatory unavailable rows
- combat estimate rendering preserves existing stat selection and focus

Retained integration coverage will verify the 24-member ledger, responsive geometry, keyboard/controller navigation, and the complete Godot suite.

## Deferred systems

Floating damage/healing numbers during combat are outside this change.

An eventual run telemetry system will record actual damage dealt, effective healing, DPS/HPS, kills, overkill, and overhealing by party member and action. It will consume emitted combat results rather than character-sheet estimates. Keeping telemetry separate ensures the theoretical sheet remains deterministic while the performance page reflects target defenses, misses, downtime, and real encounter conditions.

## Scope boundaries

This change does not:

- add or alter class models, equipment, animations, or presentation scenes
- change `ClassDefinition` to add future action slots
- change combat damage, cooldown, targeting, or critical-strike behavior
- add floating combat text
- add the damage/healing performance tracker
- estimate damage against a chosen enemy
- estimate healing, damage over time, or multi-target totals
