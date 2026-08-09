# Equipment and Attribute Application Design

Date: 2026-08-09

Status: Approved design for weighted-loot Increment 2

Parent design: `2026-08-08-weighted-loot-generation-and-equipment-stats-design.md`

Where this increment specification is more specific than the parent design, this document is authoritative. In particular, losing an attribute requirement disables dependent equipped items instead of rejecting removal of the supporting item.

## Goal

Make generated equipment affect the character who equips it through Party Forge's existing stat pipeline. The implementation must resolve the six core attributes before projecting their derived combat effects, keep runtime combat and ledger estimates on one formula path, support equipped-but-disabled items when requirements are lost, and make every equipment transition safe to preview and commit.

This increment establishes the mechanical foundation. It does not author the complete production affix library or final item presentation.

## Design principles

- One authoritative stat pipeline serves combat, the character ledger, tooltips, and comparisons.
- Attributes resolve before the stats they derive; derived stats never feed back into attributes.
- Equipment projection is pure and does not mutate item instances, affix definitions, class resources, or base-item resources.
- Ownership changes and stat-source changes are previewed together and committed as one logical transition.
- An invalid or failed transition preserves the previous ownership, loadout, sources, health, and projections.
- Archetype scaling and damage-type scaling are independent axes.
- Attribute coefficients and caps are data-driven.
- Disabled equipment remains visible and understandable instead of silently disappearing or blocking support-item removal.

## Architecture

### AttributeDerivedSourceProjector

`AttributeDerivedSourceProjector` is a pure service. It consumes a raw resolved snapshot containing the six core attributes and an `AttributeProjectionTuning` resource. It emits a stable derived `StatModifierSource` for the member.

The projector must:

- read only `strength`, `dexterity`, `constitution`, `intelligence`, `wisdom`, and `charisma`;
- reject missing, unknown, non-finite, or otherwise invalid input;
- emit only non-attribute stats;
- use stable source and modifier identities;
- avoid inspecting items, actions, scenes, or UI;
- produce deterministic output for identical input and tuning.

Validation must reject a derived source that attempts to modify any core attribute. This prevents recursive resolution.

### MemberStatResolutionService

`MemberStatResolutionService` coordinates the two-pass calculation while continuing to use `StatResolver` for modifier semantics and tag filtering.

Pass one resolves raw attributes from:

- class or future class-baseline sources;
- character level and class growth;
- run upgrades;
- passive-tree and profile sources;
- active equipment;
- future non-derived sources.

The attribute projector then builds the member's derived source.

Pass two resolves the complete stat catalog from all ordinary sources plus the derived source. Action-specific resolution uses the same derived source and applies action tags through the existing resolver.

`PartyManager.stats_for()` and `PartyManager.stats_for_action()` remain the public entry points. They delegate to the resolution service and retain member and action caches. UI and combat code must not reproduce the attribute formulas.

### EquipmentModifierProjector

`EquipmentModifierProjector` is a pure service that consumes:

- a member ID;
- the member's complete candidate loadout;
- immutable `ItemInstance` records;
- equipment, item-foundation, affix, and stat catalogs;
- the resolved active/disabled equipment state.

It emits one combined equipment source per member:

```text
equipment_member_<member_id>
```

Each modifier retains a stable detailed identity containing the member, equipment slot, item instance, affix position and definition, and roll position. The exact encoded form may be compact, but it must be deterministic, unique within the source, diagnostic-friendly, and independent of array memory addresses.

The projector translates every active immutable item roll into a `StatModifier`, including:

- implicit affixes already materialized on the item instance;
- prefixes and suffixes;
- flat, increased, reduced, more, and less operations;
- required action or capability tags;
- core-attribute rolls;
- direct combat, defense, support, and utility rolls.

Disabled items contribute no modifiers, including implicit affixes and attributes.

### Equipment transition coordinator

The existing equipment assignment service remains responsible for ownership, containers, slots, handedness, reservations, and class compatibility. The run context coordinates it with equipment activation and stat projection.

An equipment transition follows this sequence:

1. Preview the complete candidate ownership and loadout state.
2. Validate structural rules such as containers, slots, handedness, reservations, and class compatibility.
3. Resolve the candidate active and disabled equipment sets.
4. Build and validate the complete candidate equipment source.
5. Resolve candidate raw attributes, final stats, and action estimates.
6. Commit candidate ownership and atomically replace the member's equipment source.
7. Invalidate affected caches and refresh observers once.
8. Apply maximum-health clamping after a successful commit.

Validation or projection failure returns a structured diagnostic and makes no mutation. If an unexpected failure occurs during the commit boundary, the coordinator restores the exact prior item state and stat source before returning failure.

## Attribute model

The six named attributes are D&D-inspired categories, but they use direct additive point values rather than the `(score - 10) / 2` modifier formula. This matches the existing progression system, where individual characters gain attribute points as they level.

Initial per-point conversions are:

| Attribute | Derived effects per point |
| --- | --- |
| Strength | 2% increased melee damage and 0.25 flat armor |
| Dexterity | 2% increased ranged damage, 0.5% increased attack speed, and 0.1 percentage points of dodge chance |
| Constitution | 3 flat maximum health and 0.05 flat health regeneration |
| Intelligence | 2% increased caster damage and 0.75% increased area size |
| Wisdom | 2% increased healing power and 0.5% increased cooldown recovery |
| Charisma | 1 flat party influence |

These coefficients live in `AttributeProjectionTuning`; code must not hard-code them outside its defaults or validation fixtures. Percentage conversions must use the operation/value convention already established by the stat resolver.

`party_influence` is a new canonical stat. It is the future input for auras, leadership abilities, recruitment interactions, party buffs, and related mechanics. This increment does not make every follower's Charisma directly multiply whole-party damage or healing because that would scale unsafely with large party limits.

Charisma continues to supply the already implemented smaller, diminishing item-generation influence where the generation request intentionally uses a character's Charisma.

The catalog also gains canonical `melee_damage`, `ranged_damage`, and `caster_damage` stats. Relevant keywords and tooltip explanations must be added with them.

Explicit percentage defenses, including dodge, retain their canonical caps. Projection must not bypass stat-definition clamping.

## Combat and action projection

Every damaging playable-character action has exactly one primary archetype tag:

- `melee`
- `ranged`
- `caster`

Damage types remain independent. Physical, fire, cold, lightning, chaos, and future types describe the damage component, not how the action is delivered.

For every damage component, pre-mitigation damage is:

```text
base component damage
* global damage
* primary archetype damage
* matching damage-type damage
* critical multiplier when the hit is critical
```

Examples:

- a flaming sword uses melee and fire scaling;
- a physical spell uses caster and physical scaling;
- a chaos arrow uses ranged and chaos scaling;
- a mixed fire/cold spell resolves both components separately and applies caster scaling to each.

The nine current class attacks normalize to:

| Class | Primary archetype |
| --- | --- |
| Fighter | Melee |
| Ranger | Ranged |
| Marksman | Ranged |
| Rogue | Melee |
| Paladin | Melee |
| Mage | Caster |
| Frost Mage | Caster |
| Cleric | Caster |
| Warlock | Caster |

This adds missing caster tags to Mage, Frost Mage, and Cleric and changes the Warlock bolt from ranged to caster.

Validation rejects damaging playable-character actions with no primary archetype or more than one. Healing-only actions do not require a damage archetype. Enemy actions remain compatible and are not forced through player-class archetype validation in this increment.

Runtime damage and `ActionCombatEstimateService` must share one pure preparation calculation. The ledger must not maintain an approximate duplicate formula.

Critical chance and critical multiplier apply after global, archetype, and type scaling. General character-sheet estimates remain theoretical pre-mitigation values because an actual target's armor, resistance, dodge, block, and incoming-damage modifiers are encounter-specific.

For each damaging action, the ledger displays component rows and totals for normal hit, critical hit, average hit, attacks per second, and expected DPS.

## Equipment requirements and disabled items

Equipping a new item still requires that the newly placed item be usable in the candidate loadout. Removing or swapping a supporting attribute item is allowed even if the change causes other already equipped items to lose their requirements.

After a candidate equipment change, activation resolves deterministically:

1. Start with raw attributes from all non-equipment sources.
2. Activate candidate items whose requirements are satisfied.
3. Add attribute modifiers supplied by newly active items.
4. Repeat until no additional item activates.
5. Mark every remaining equipped item disabled.

Because inactive items contribute nothing during resolution, an item cannot satisfy its own requirements and mutually dependent items cannot bootstrap one another. A valid support chain can activate in deterministic passes.

A disabled item:

- remains owned and remains in its equipment slot;
- contributes no implicit, prefix, suffix, attribute, or direct-stat modifier;
- cannot enable another item;
- reactivates automatically when a later transition restores its requirements;
- appears dimmed with a clear disabled overlay;
- identifies every unmet requirement in its tooltip;
- will eventually disable item-granted skills when that feature exists.

Structural failures such as an illegal slot, incompatible class, invalid handedness, or impossible reservation remain assignment failures rather than disabled states.

The active/disabled result must be stored or projected in a form that UI, comparisons, stat projection, and save validation can consume consistently. It must never be inferred separately by each consumer.

## Health refresh behavior

After a successful stat-source transition:

- if maximum health decreases below current health, current health is clamped to the new maximum;
- if maximum health increases, current health does not increase;
- equipment or general stat refresh does not preserve health percentage and does not grant free healing.

The existing percentage-preserving runtime refresh must be changed for this path. Spawn/setup code may still initialize a character at full health intentionally.

## Ledger and tooltip presentation

The character ledger gains canonical rows for:

- Melee Damage
- Ranged Damage
- Caster Damage
- Party Influence

An archetype or damage-type row is shown only when the member has the corresponding action, capability, or meaningful modifier. A class should not receive rows that are irrelevant to everything it can currently do.

Stat detail attribution identifies class growth, upgrades, passives, and equipment. Equipment attribution includes the item and affix label while stable IDs retain the exact technical origin.

Item comparisons use a complete dry-run candidate loadout and final two-pass snapshots. They do not subtract affix text directly. This captures:

- attribute-derived changes;
- active/disabled requirement cascades;
- two-handed displacement;
- every affected action's hit and DPS changes;
- defense, healing, and utility changes.

Comparison presentation uses:

- green text plus a positive or upward indicator for improvements;
- red text plus a negative or downward indicator for losses;
- normal text for unchanged values;
- a prominent warning when the transition disables another equipped item.

Color is never the only signal. Stat-definition comparison metadata should determine whether a larger or smaller number is beneficial where direction is not obvious.

Existing input behavior remains intact: hover opens the normal tooltip, Alt shows the equipped comparison, and Shift reveals affix names, tiers, roll values, and roll ranges.

## Validation and diagnostics

The increment must produce structured errors for:

- unknown stat IDs;
- unsupported modifier operations;
- missing, empty, or duplicate stable identities;
- invalid or non-finite modifier values;
- derived sources that modify core attributes;
- damaging playable-character actions with missing or conflicting archetypes;
- invalid slots, handedness, class restrictions, or reservations;
- corrupt item instances or missing referenced definitions;
- candidate resolution that produces invalid attributes, stats, or action estimates.

Diagnostics must identify the affected member and, where applicable, the slot, item instance, affix, roll, stat, or action.

## Cache and refresh contract

A successful equipment transition invalidates only the affected member's base and action caches, then emits the existing stat-change notification once. The ledger, actor runtime stats, and equipment UI refresh from that notification or the coordinated ownership refresh.

Failed previews and failed commits do not invalidate caches or emit misleading change signals.

The design must remain practical at the current developer party limit of 24 members. Equipment resolution is member-local; changing one member's loadout must not rebuild every other member's snapshots.

## Verification strategy

### Unit coverage

- Each individual attribute conversion and tuning validation.
- The two-pass no-feedback rule.
- Stable equipment projection from immutable item instances.
- All supported modifier operations and required tags.
- Unknown, duplicate, non-finite, and malformed modifier rejection.
- Requirement support chains.
- Self-requirement and mutual-dependency behavior.
- Disabled-item exclusion and automatic reactivation.
- Pure candidate comparison deltas and benefit-direction presentation.
- Health clamping without healing.
- Shared runtime/estimate damage preparation.

### Integration coverage

- All nine class primary archetype mappings.
- Physical, elemental, chaos, and multi-component action calculations.
- Equip, unequip, swap, two-handed reservation, and rollback paths.
- Removing attribute support disables dependent equipment without removing it.
- Restoring support reactivates equipment and its affixes.
- Ledger source attribution and action estimates after equipment changes.
- Green improvements, red losses, and non-color comparison indicators.
- Member-local cache invalidation and isolation across 24 party members.

### Acceptance checks

- Headless Godot import with no forbidden parser or resource diagnostics.
- Focused Increment 2 unit and integration suites.
- Full project test suite.
- Startup smoke markers exactly once.
- Tracked Git status inspected before and after Godot execution so generated `.gd.uid` files or formatter drift are not mistaken for authored changes.

## Increment boundary

Included in Increment 2:

- attribute-derived stats and data-driven tuning;
- melee, ranged, and caster scaling;
- generated equipment affixes affecting individual characters;
- deterministic active and disabled equipment;
- accurate item comparisons and ledger values;
- runtime and ledger damage-formula normalization;
- required keywords, rows, warnings, and comparison colors;
- safe equipment transition and health-refresh behavior.

Deferred:

- the complete production affix pool and twelve-tier content library;
- Loot Lab and production enemy-drop wiring;
- floating damage numbers and party damage/healing meters;
- item-granted active skills;
- final rarity lights, sounds, and animation;
- broad production inventory or equipment artwork replacement.
