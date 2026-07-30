# Party Forge Character-Targeted Upgrades Design

**Date:** 2026-07-30
**Status:** Approved by Jacob on 2026-07-30

## Purpose

Build the next progression layer after the nine-class catalog: a data-driven level-up system that makes each party member independently buildable while also rewarding overlapping class traits and capabilities.

The milestone adds 25 authored upgrade cards in addition to the existing recruitment, class-rank, trait-rank, and party-stat choices. It also adds stable class-flavored character names, a moderately accelerating XP curve, recipient selection for character upgrades, and complete hover/focus tooltips.

The design must be simple to extend through Godot Resources now and capable of supporting mechanic-changing upgrades later without replacing its targeting, ownership, catalog, or UI foundations.

## Goals

- Make individual party members independently targetable, including duplicate classes.
- Reward both character specialization and party composition.
- Keep upgrade content editable through Godot Resources rather than per-card scripts.
- Ensure combat calculations, effect descriptions, and future Stat UI breakdowns share one source of truth.
- Provide enough authored choices for meaningful build variety during testing.
- Preserve clear extension points for triggers, added projectiles, retaliation, on-kill effects, items, affixes, and class passive trees.
- Keep all player-facing keywords explained through registry-backed tooltips.
- Make XP pacing and character-name content editable without code changes.

## Out of Scope

This milestone does not add:

- Active upgrade rarity tiers or rarity-based value scaling.
- The persistent compact party roster or full character Stat UI.
- Inventory, equipment, item rarities, or affixes.
- Player-controlled character renaming.
- Custom per-card scripts or mechanic-changing trigger effects.
- Save persistence, meta progression, or passive-tree UI.
- Strong late-run XP compounding intended for longer runs.

Rarity metadata, future effect-handler boundaries, and mutable character names are included only where needed to avoid later data migration.

## Architecture

### UpgradeDefinition

Each authored card is an `UpgradeDefinition` Resource. It contains:

- Stable upgrade ID.
- Display name and short card summary.
- Detailed description data and tooltip keyword IDs.
- Scope: `CHARACTER`, `CLASS_SPECIFIC`, `PARTY`, or `TRAIT`.
- Allowed class IDs.
- Required-all, required-any, and excluded trait or capability tags.
- Maximum rank and selection weight.
- Reserved rarity metadata that remains inactive in this milestone.
- One or more typed effect definitions.

Upgrade Resources are immutable content definitions. Run-specific ownership and ranks must never be written back into the shared Resources.

### Typed Effects

The initial 25 cards primarily use a stat-modifier effect. A stat effect specifies:

- Stat ID.
- Modifier operation: flat, increased, reduced, more, or less.
- Value per rank or a rank-indexed value list.
- Optional required and excluded action or capability tags.
- Player-facing source label.

An upgrade-effect application service validates and executes typed effects. The initial service supports the modifier effects required by this milestone. Later mechanic-heavy content can add validated effect types and handlers without changing `UpgradeDefinition`, upgrade ownership, recipient targeting, or choice presentation.

Content Resources must not contain arbitrary per-card scripts. New behavior belongs in a reusable typed handler shared by all cards using that behavior.

### Catalog Integration

`GameCatalog` loads authored upgrades and exposes lookup by stable ID. Its validation covers upgrade definitions alongside classes, traits, stats, damage types, enemies, and tooltip keywords.

The catalog must reject or safely exclude optional authored cards with:

- Duplicate or empty IDs.
- Missing display or tooltip data.
- Unknown stat, class, trait, capability, or keyword references.
- Unsupported effect types or operations.
- Invalid rank caps, weights, or values.
- Empty or contradictory eligibility.
- A class-specific definition with no eligible class.

Errors use a grep-friendly `PARTY_FORGE_UPGRADE_ERROR` prefix and include the upgrade ID and Resource path.

## Ownership and Resolution

### Character Ownership

Character-targeted upgrades are owned by stable `PartyMemberState.member_id`. Duplicate classes remain separate recipients and can hold different cards and ranks.

Applying a character upgrade records its rank on that member and contributes named `StatModifierSource` entries to the existing stat resolver. Source IDs include the upgrade ID and owning member identity so source breakdowns remain stable and debuggable.

### Party and Matching-Party Ownership

Party-wide and matching-party synergy upgrades are stored by `PartyManager`. Their eligibility is evaluated whenever sources are resolved for a member. Therefore, an eligible character recruited after the upgrade was chosen receives the effect automatically.

Party-wide state is not copied into every existing member. This prevents divergence and supports future party composition changes.

### Trait Ownership

Existing trait-rank choices remain separate foundational choices. Authored trait or capability synergies use the same upgrade-definition and effect system, with scope determining whether the card affects one selected eligible member or every matching party member.

### Atomic Application

A choice is validated when generated and revalidated when confirmed. All effects are checked before state changes. If any effect is invalid, no rank or modifier from that choice is applied.

Successful application invalidates only the required stat caches and emits the existing stat and upgrade change signals. The future Stat UI therefore receives the same values used by combat.

## Authored Upgrade Set

The 25 authored cards are separate from recruitment, class training, trait strengthening, and existing party-stat choices.

Names and initial values below are the implementation baseline. They remain editable balance data, but implementation and automated tests use these exact values until a later balance pass deliberately changes them.

### Nine Class Signatures

Each class has exactly one defining signature. Signatures are class-specific and have a maximum rank of one.

| Signature | Initial effects |
|---|---|
| **Hold the Line — Fighter** | 20% increased Maximum Health and +5 Armor. |
| **Quickdraw — Ranger** | 20% increased Attack Speed and 25% increased Projectile Speed. |
| **Living Flame — Mage** | 25% increased Fire Damage and 20% increased Area Size. |
| **Sacred Conduit — Cleric** | 25% increased Healing Power and 25% increased Lightning Damage. |
| **Consecrated Bulwark — Paladin** | +10 percentage points Block Chance and +1.5 Health Regeneration per second. |
| **Cutthroat Instinct — Rogue** | +10 percentage points Critical Strike Chance, +0.25 Critical Strike Multiplier, and +5 percentage points Life Steal. |
| **Heart of Winter — Frost Mage** | 25% increased Cold Damage and 20% increased Area Size. |
| **Blood Covenant — Warlock** | 30% increased Chaos Damage and +8 percentage points Life Steal, but 15% reduced Maximum Health. |
| **Deadeye — Marksman** | 30% more Physical Damage, 20% increased Attack Range, and +0.25 Critical Strike Multiplier, but 15% less Attack Speed. |

Trade-offs use the same reduced or less modifier operations used by the stat resolver. They are not implemented as hidden class-specific formulas.

### Seven Shared Character Upgrades

These target one chosen eligible member and have a maximum rank of three. Values are gained per rank.

| Upgrade | Eligibility | Effect per rank |
|---|---|---|
| **Martial Training** | `martial` | 8% increased Physical Damage and +1 Armor. |
| **Ranged Calibration** | `ranged` | 10% increased Attack Range and 10% increased Projectile Speed. |
| **Caster Discipline** | `caster` | 8% increased Damage and 8% increased Attack Speed. |
| **Skirmisher's Rhythm** | `skirmisher` | +4 percentage points Dodge Chance and 5% increased Movement Speed. |
| **Projectile Mastery** | `projectile` | 12% increased Projectile Speed and 8% increased Damage for actions tagged `projectile`. |
| **Expanding Power** | `area` | 10% increased Area Size and 8% increased Damage for actions tagged `area`. |
| **Elemental Attunement** | Any of `fire`, `cold`, `lightning`, or `chaos` | 12% increased damage for each elemental damage capability the selected member possesses. |

Eligibility uses class traits and capability tags rather than class-name branches. `Elemental Attunement` applies the modifier matching the selected member's supported damage tag, such as Fire, Cold, Lightning, or Chaos.

### Three Matching-Party Synergies

These have a maximum rank of one and affect every matching current or future party member.

| Synergy | Eligibility | Effect |
|---|---|---|
| **Vanguard Wall** | `vanguard` | +3 Armor and 10% increased Maximum Health. |
| **Arcane Convergence** | `arcane` | 12% increased Area Size plus 10% increased Fire, Cold, Lightning, or Chaos Damage when the member has the matching capability. |
| **Divine Covenant** | `divine` | 15% increased Healing Power and +1 Health Regeneration per second. |

These cards directly reward overlapping party composition. Their card and tooltip text explicitly state that later matching recruits also receive the effect.

### Six Universal Character Upgrades

These are broadly targetable, have a maximum rank of five, and gain the listed value per rank.

1. **Vitality** — 8% increased Maximum Health.
2. **Tempered Armor** — +2 Armor.
3. **Ferocity** — 8% increased Damage.
4. **Alacrity** — 6% increased Attack Speed.
5. **Fleetfoot** — 5% increased Movement Speed.
6. **Precision** — +3 percentage points Critical Strike Chance.

Universal cards also serve as validated fallback candidates if stricter eligibility filtering cannot fill all three level-up slots.

## Capability Consistency

Upgrade eligibility must be understandable from class Resources. Existing class and attack content receives any missing explicit capability tags required by these cards. Validation checks that class capabilities and authored attacks do not contradict the upgrade promises.

Trait and capability IDs remain registry-style `StringName` identifiers. Upgrade selection must not infer eligibility from display names or scene node paths.

Eligibility uses these exact rules:

- An empty allowed-class list accepts any class; otherwise the member's class ID must be present.
- Every required-all tag must be present.
- At least one required-any tag must be present when that list is non-empty.
- No excluded tag may be present.
- Class traits and capability tags participate in the same normalized eligibility tag set.

## Choice Generation

The level-up panel continues to present three choices.

- While party space remains, one slot is guaranteed to contain a recruit choice.
- The other slots draw from valid authored and foundational choices.
- The player may decline the recruit and take another offered upgrade.
- Once the four-member party is full, all three slots draw from upgrades.
- Cards at maximum rank are excluded.
- Character cards with no eligible recipient are excluded.
- Class and trait choices remain limited to owned or active content as appropriate.
- Duplicate choice keys cannot appear in the same offer.
- Seeded generation remains deterministic for testing.

If normal filtering cannot produce three choices, eligible universal cards fill the remaining slots. The player must never be trapped in the level-up state by an empty or unusable offer.

## Upgrade-First Recipient Flow

The player selects an upgrade before selecting a recipient.

Each initial card displays:

- Name and scope badge.
- Current rank and maximum rank.
- Short plain-language summary.
- Eligibility summary.
- Whether it affects one character or every matching member.

Selecting a character-targeted card opens a recipient picker without rerolling or replacing the original offer. The picker displays every current member:

- Generated character name.
- Class and role.
- Health and current class rank.
- Eligibility state.
- Preview of relevant resolved values before and after the upgrade.

Eligible members can be confirmed. Ineligible members remain visible but disabled and state the reason. Cancel returns to the unchanged three-card offer.

Party and trait cards apply after a confirmation step without recipient selection. Combat remains paused for the entire level-up and targeting flow. Existing queued levels are then presented one at a time.

## Tooltips and Keywords

Hovering an upgrade card opens its detailed tooltip. Keyboard or controller focus provides identical information.

The tooltip includes:

- Exact effect values at the offered rank.
- All trade-offs.
- Scope and recipient eligibility.
- Current rank and maximum rank.
- Whether later matching recruits inherit the effect.
- Plain-language explanations for every referenced keyword.

Descriptions are assembled from definition data and formatted through the stat and keyword registries. The UI must not maintain a second set of numerical effect text that can disagree with applied values.

A typical signature tooltip communicates both its numbers and its terminology:

```text
Deadeye — Marksman Signature

The selected Marksman deals 20% more Physical Damage and gains Attack
Range and Critical Strike Multiplier, but has less Attack Speed.

More: A multiplicative modifier applied after increased and reduced values.
Physical Damage: Damage mitigated by Armor.
Maximum rank: 1
```

The values shown are read from the offered definition and rank. Every exposed keyword must resolve through the keyword registry. Development builds show `Missing definition: <id>` for unexpected gaps, while catalog tests reject known missing definitions.

Tooltips must remain inside the supported viewport, avoid covering the focused card when practical, and remain usable at the 1920x1080 logical target and 3840x2160 scaling target.

## Experience Progression

XP requirements move from the hard-coded linear formula into an `ExperienceTuning` Resource.

For current level `L`, where the run starts at level one, the next-level requirement is:

```text
ceil(20 + 8 * (L - 1) + 2 * (L - 1)^2)
```

This produces the initial moderate sequence:

```text
20, 30, 44, 62, 84, 110...
```

The Resource therefore defaults to base cost `20`, linear growth `8`, and acceleration `2`. The formula must be deterministic, monotonic, integer-valued, and protected against invalid negative tuning.

Stronger late-run compounding is deferred until runs are long enough to evaluate it. The Resource boundary must allow a future curve mode or additional term without changing `ExperienceSystem` consumers.

Adding enough XP for multiple levels preserves overflow, increments every earned level, and queues one choice sequence per level. Increasing requirements must not discard already-earned XP or pending choices.

## Character Names

Each class references an editable class-flavored name pool containing at least eight names. A generic fallback pool contains at least twelve names. When a leader or recruit is created:

- A name is selected deterministically from the run seed and stable member ID.
- Names already used by the current party are avoided while alternatives exist.
- A generic fallback pool prevents an empty or exhausted class pool from blocking member creation.
- The selected value is stored on `PartyMemberState` and is not regenerated by the UI.
- The same value appears in recipient targeting and the later roster and character sheet.

The character name is deliberately stored as mutable member state. A later combined Stat UI and inventory/equipment character sheet will allow the player to edit it. This milestone does not add the editing control.

Names are run-local until save and meta-progression persistence receive their own design.

## Failure Behavior

- Unknown upgrade IDs cannot be applied.
- Stale offers are revalidated against current ranks and party composition.
- Invalid targets do not consume the choice or close the level-up flow.
- Failed atomic application reports a structured error and leaves state unchanged.
- Missing optional upgrade Resources are excluded without crashing a run.
- Missing required baseline definitions fail automated validation and block completion.
- Name-pool failures use the generic fallback and emit a development warning.
- Invalid XP tuning falls back to a safe monotonic requirement and reports the invalid field.

## Testing Strategy

Implementation follows focused red-green-refactor cycles.

### Data and Catalog Tests

- Exactly 25 authored cards load.
- The distribution is nine signatures, seven shared-character cards, three matching-party synergies, and six universal cards.
- Every class has exactly one signature.
- All IDs are unique and all referenced stats, tags, classes, and keywords exist.
- Reserved rarity metadata does not alter current selection or values.
- Invalid definitions produce structured errors with IDs and paths.

### Ownership and Resolution Tests

- Individual upgrades affect only the selected member ID.
- Two members of the same class can hold different ranks and resolved values.
- Matching-party effects apply to current and later eligible recruits.
- Ineligible members receive no matching effect.
- One-time and repeatable caps are enforced.
- Flat, increased, reduced, more, and less effects preserve resolver order.
- Source breakdowns name the correct card and rank.
- Failed multi-effect application is atomic.

### Choice and UI Tests

- An open party receives one recruit choice and two other valid choices.
- A full party receives three non-recruit choices.
- Capped and unusable cards are excluded.
- Universal fallbacks prevent an empty offer.
- Selecting a character card opens the recipient picker.
- Ineligible members are disabled with a reason.
- Cancel restores the unchanged offer.
- Hover and keyboard focus show equivalent tooltip content.
- Tooltip numbers match the effects actually applied.
- Layout remains centered and usable at 1920x1080 and 3840x2160.

### XP and Naming Tests

- The default tuning returns the approved moderately accelerating sequence.
- Requirements are monotonic and invalid values fail safely.
- XP overflow and multiple pending levels are preserved.
- Generated names are deterministic for the same seed and member ID.
- Duplicate names are avoided when the pool permits.
- Empty class pools use the generic fallback.

### Manual Acceptance Run

Run from leader selection through a full party and verify:

1. A recruit is offered while a party slot remains.
2. Two members of the same class receive distinct generated names.
3. Hover and focus explain every offered card and keyword.
4. A universal character upgrade changes only the chosen member.
5. A class signature reinforces the intended class identity.
6. A shared character upgrade restricts recipients correctly.
7. A matching-party synergy affects all current matches and a later recruit.
8. A trade-off displays and resolves both its benefit and penalty.
9. Multiple queued levels appear separately without XP loss.
10. The interface remains correctly positioned at both supported resolutions.

## Preservation Boundaries

Implementation must preserve unrelated user and Godot changes, including projectile speed and lifetime tuning, responsive UI work, the GodotSteam add-on, handbook files, and any unrelated generated metadata.

The upgrade milestone may touch current progression, party state, catalog, class capability data, level-up UI, and focused tests only as required by this design. The existing persistent roster and Stat UI work remains the following stage.

## Acceptance Criteria

The milestone is complete when:

- All 25 authored cards are catalog-loaded, validated, and eligible as designed.
- Recruitment remains guaranteed as an option while space exists.
- Character upgrades use upgrade-first recipient selection and stable member IDs.
- Duplicate classes can receive different upgrades and are distinguished by generated names.
- Party synergies affect every matching current and future member.
- Mixed repeatability and rank caps work.
- Hover and focus tooltips explain exact effects, trade-offs, eligibility, and every keyword.
- Applied combat values and tooltip values share the same data and agree.
- The moderate XP curve is data-driven and preserves overflow and queued levels.
- Character names are deterministic, class-flavored, stored on member state, and ready for later editing.
- Focused tests, the full suite, Godot parser/import validation, and the manual acceptance run pass.
- No unrelated user-authored or Godot-serialized work is overwritten.

## Next Milestone

After this milestone is verified, build the persistent compact roster and combined character Stat UI. That interface will expose resolved values and modifier-source breakdowns and will later sit beside inventory/equipment. Player-controlled character renaming will be enabled through that character sheet after both panels share a stable selected-member context.
