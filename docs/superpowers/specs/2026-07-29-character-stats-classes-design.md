# Party Forge Character Stats and Expanded Classes Design

**Date:** 2026-07-29
**Status:** Approved by Jacob on 2026-07-29

## Purpose

Expand Party Forge from four to nine playable classes and establish a data-driven character-stat foundation for future upgrades, items, affixes, passive trees, temporary effects, and novel abilities. The system must support high build variety without copying every possible stat into every class script.

The milestone also adds a per-character Stat UI. A compact party roster remains visible during play; selecting a member pauses the run and opens a detailed character drawer. Every player-facing stat, element, trait, ailment, tag, and modifier-source keyword must have a consistent registry-backed tooltip.

## Design Goals

- Make every displayed combat stat functional rather than decorative.
- Keep character values linked to stable party-member identities, not UI positions.
- Let content add stats and modifiers through Godot `Resource` data rather than class-specific calculation branches.
- Support individual character builds alongside party-wide traits and upgrades.
- Establish clear extension points for items, affixes, class passive trees, and many future damage types.
- Preserve the current four-member party cap, duplicate classes, elastic formations, and existing gameplay loop.
- Keep the system understandable and editable by a developer learning Godot.

## Scope

### Included

- Five additional playable classes: Paladin, Rogue, Frost Mage, Warlock, and Marksman.
- Catalog-driven leader selection and recruitment across all nine classes.
- Central registries for stats, damage types, and keywords.
- Per-character base stats, modifiers, resolved snapshots, and source breakdowns.
- Individual, class-specific, party-wide, and trait modifier ownership.
- Physical, Fire, Cold, Lightning, and Chaos damage.
- Functional armor, resistances, critical strikes, block, dodge, regeneration, and life steal.
- A persistent compact party roster and paused detailed character drawer.
- Context-sensitive stat visibility plus an explicit Show All Stats mode.
- Registry-backed keyword tooltips for mouse and keyboard/controller focus.
- Validation, automated tests, and responsive layout checks.
- Modifier-source extension points for future equipment, affixes, passive trees, buffs, debuffs, and ailments.

### Excluded

- Inventory, equipment slots, item drops, rarity generation, and affix rolling.
- Passive-tree persistence, currency, or tree UI.
- Functional Ignite, Chill, Freeze, Shock, Poison, or other ailments.
- A broad content pass for upgrades beyond the cases needed to validate the foundation.
- Steam API initialization, achievements, statistics, cloud saves, lobbies, or other Steamworks features.
- Final character art, animation, audio, or balance.

## Architectural Approach

Use a data-driven layered-stat system. Static definitions live in Godot `Resource` catalogs; live party members contain only their identity, class reference, ranks, capabilities, and modifier sources. A central resolver produces an immutable effective-stat snapshot used by both combat and UI.

This deliberately stops short of making every attack and interaction a completely generic effect graph. The selected approach supplies extensible stats and tagged modifiers without building a custom game engine before the required interactions are known.

## Content Registries

### Stat Definitions

A stat definition describes what a stat means and how it behaves, not any character's current value. Each definition includes at least:

- Stable `StringName` ID.
- Display name.
- UI group.
- Value format, precision, and sign behavior.
- Base/default value.
- Optional minimum and maximum.
- Visibility policy.
- Capability tags that make a zero-valued specialized stat relevant.
- Keyword or tooltip reference.

Representative IDs include:

- `max_health`, `armor`, `move_speed`, `damage`, and `attack_speed`.
- `crit_chance`, `crit_multiplier`, `dodge_chance`, `block_chance`, and `block_effectiveness`.
- `health_regeneration` and `life_steal`.
- `attack_range`, `projectile_speed`, `area_size`, `cooldown_rate`, `healing_power`, and `pickup_radius`.
- Damage-type bonuses and resistances for Physical, Fire, Cold, Lightning, and Chaos.

New specialized stats can be registered later without adding exported variables to every class.

### Damage-Type Definitions

Initial damage types are:

- Physical
- Fire
- Cold
- Lightning
- Chaos

Each definition includes a stable ID, display data, keyword tooltip, presentation color, and matching defensive-stat reference. Damage-type lookups must be catalog-driven so later types such as Holy, Poison, Bleed, Shadow, Arcane, or Storm can be introduced through data and supporting content.

### Keyword Definitions

Keyword data is the authoritative source for player-facing explanations. It covers stats, damage types, traits, tags, modifier operations, source categories, and reserved ailment terminology.

The same keyword ID must produce the same core explanation in class descriptions, upgrade choices, stat rows, source breakdowns, and future item tooltips. Contextual additions may show the selected character's current value, cap, or relevant sources, but must not replace the canonical definition.

Playable content must not claim to apply an ailment before that ailment is functional. Ailment definitions can exist for validation and future development without being granted by current classes or upgrades.

## Character State and Identity

Every party member has a stable member ID independent of party-array index. The live character state contains:

- Member ID.
- Class-definition reference.
- Leader flag.
- Class rank.
- Capability tags.
- Character-owned modifier sources.
- References needed to obtain active party and trait sources.

The UI, combat actors, and upgrade targeting use the member ID. Adding, downing, reviving, or reordering party members must not make a panel display another character's values.

Class rank remains shared per class ID for the current run, preserving the existing duplicate-class rule. Two Rangers therefore read the same Ranger rank, but each can also own different character-specific upgrades. A member snapshot records the shared class-rank source separately from that member's individual sources.

## Modifier Model

Every modifier records:

- Target stat ID.
- Operation.
- Numeric value.
- Source type and stable source ID.
- Human-readable source label.
- Scope or owner.
- Optional required and excluded tags.
- Optional conditions reserved for supported runtime checks.

The initial operations are:

- **Flat:** added to the base value.
- **Increased/Reduced:** combined additively into one percentage stage.
- **More/Less:** applied as separate multiplicative factors.

Effective values resolve as:

```text
(base + total flat)
× (1 + total increased - total reduced)
× each more multiplier
× each less multiplier
= effective value
```

For example:

```text
100 base damage
+20 flat damage
+30% increased damage
10% more projectile damage

(100 + 20) × 1.30 × 1.10 = 171.6
```

The matching stat definition then applies its minimum, maximum, rounding, and presentation rules. Conditional modifiers apply only when their tag requirements match the action or value being resolved.

### Modifier Sources and Ownership

The resolver accepts named layers in a deterministic order:

1. Class base values.
2. Class-rank modifiers.
3. Character-owned run upgrades.
4. Future equipment and affixes.
5. Party-wide run upgrades.
6. Trait synergies.
7. Future class passive-tree modifiers.
8. Temporary buffs and debuffs.

The order identifies and explains sources; operation semantics determine the arithmetic. Future systems integrate by contributing modifier sources rather than rewriting character calculations.

## Resolved Stat Snapshots

The resolver returns an immutable snapshot containing:

- Effective values by stat ID.
- Relevant capability tags.
- Source-by-source calculation breakdowns.
- Contextual visibility information.
- A revision identifier for consumers.

Snapshots are cached per member and invalidated when a relevant class rank, owned upgrade, party upgrade, trait tier, or temporary source changes. UI consumers respond to `stats_changed(member_id)` instead of recalculating every stat each frame.

Combat and UI must read the same resolved values. Neither the HUD nor the class controllers maintain an independent version of a combat formula.

## Damage Resolution

Attacks create typed damage packets containing:

- Source member or actor ID.
- Attack or ability ID.
- One or more damage components keyed by damage-type ID.
- Action tags such as `projectile`, `bow`, `melee`, or `area`.
- Whether the hit may critically strike.

An attack may combine multiple damage types without introducing a separate damage function.

The initial hit order is:

1. Resolve attacker values and applicable tagged modifiers.
2. Build the typed damage packet.
3. Roll critical strike once for the complete hit.
4. Roll defender dodge; a successful dodge avoids the complete hit.
5. Mitigate each damage component with armor or its matching resistance.
6. Roll block and apply block effectiveness to the remaining hit.
7. Apply final health damage.
8. Grant life steal based on final health damage actually dealt.

### Defensive and Recovery Rules

- Armor applies to Physical damage with `physical_after_armor = physical_damage × 100 / (100 + max(0, armor))`. This supplies diminishing returns and treats negative armor as zero until an explicit vulnerability mechanic is designed.
- Fire, Cold, Lightning, and Chaos Resistance reduce their matching components with `damage_after_resistance = damage × (1 - resistance)`, after resistance is clamped to its registered limits.
- Resistances default to 0% and have a normal maximum of 75%.
- Dodge avoids the complete hit and has a normal maximum of 75%.
- Block Chance determines whether a hit is blocked.
- Block Effectiveness determines the prevented share and defaults to 50%.
- Regeneration restores health continuously according to its per-second value.
- Life Steal restores a percentage of final damage dealt and cannot exceed maximum health.
- Crit Multiplier defaults to 150%; Crit Chance is class dependent.

Limits and defaults live in stat definitions rather than scattered controller constants. Enemies use the same damage pipeline with simpler stat providers where a full player-facing character sheet is unnecessary.

## Expanded Class Catalog

All nine classes are valid leaders and recruits. Duplicate classes remain allowed, and every duplicate is an independently addressable party member. The four-member party cap remains unchanged.

### Existing Classes

- **Fighter:** Physical melee; traits `Martial` and `Vanguard`.
- **Ranger:** rapid Physical projectiles; traits `Martial` and `Ranged`.
- **Mage:** Fire area projectiles; traits `Arcane`, `Caster`, and `Fire`.
- **Cleric:** Lightning-flavored judgment projectile plus healing; traits `Divine`, `Support`, and `Caster`.

### New Classes

- **Paladin:** Physical frontline melee with high armor, block, regeneration, and light party protection; traits `Divine`, `Vanguard`, and `Martial`.
- **Rogue:** fast Physical skirmisher with crit, dodge, modest life steal, and low durability; traits `Martial` and `Skirmisher`.
- **Frost Mage:** Cold area projectiles and a future control identity; traits `Arcane`, `Caster`, and `Cold`.
- **Warlock:** heavy Chaos projectiles and life steal; traits `Occult`, `Caster`, and `Chaos`.
- **Marksman:** heavy Physical bow attacks with low attack speed, very high hit damage, and greater range than Ranger; traits `Martial`, `Ranged`, and `Bow`. The existing `res://data/classes/marksman.tres` becomes the authoritative class definition and references a dedicated heavy-bow attack Resource.

The current in-development Marksman Resource will be completed rather than replaced with an unrelated class concept. It is not considered complete until its ID, display data, role, traits, base stats, formation distances, attack reference, validation, catalog entry, leader selection, recruitment eligibility, and focused tests all agree.

All values remain balance data. This milestone must establish distinct and testable identities without treating initial numbers as final balance.

## Catalog-Driven Selection

Replace the hard-coded four-button leader selector with a scrollable class grid generated from the class catalog. A valid class Resource automatically becomes available to leader selection, recruitment generation, stat identification, tooltip lookup, and content validation.

The selector must remain usable at the 1920×1080 logical resolution and when scaled to 3840×2160. It must not derive scene node paths from display names or require a new hard-coded code branch for each class.

## Upgrade Ownership and Flow

Upgrade choices visibly declare one of these scopes:

- **Recruit:** adds a member while party space exists.
- **Character:** modifies one chosen member.
- **Class-specific:** targets only members matching a class or capability.
- **Party:** affects every current and future member for the run.
- **Trait:** changes a party synergy or trait rank.

Selecting a generic character upgrade opens the party roster for recipient selection. Class-specific choices preselect or restrict eligible members. Party choices require no second selection.

The milestone adds only enough choices to validate flat, increased, more, conditional, individual, class-specific, party-wide, and trait modifiers. Wider upgrade design follows after the foundation is proven.

## Stat UI

### Persistent Compact Roster

The compact roster remains visible during normal play. Each member card displays:

- Class identity.
- Current and maximum health.
- Role.
- Class rank.
- Important temporary state where relevant.
- A clear selected-member treatment.

### Paused Character Drawer

Clicking or focusing a roster card and confirming it pauses combat and opens an expandable drawer for that member. A party-member hotkey can perform the same action. UI controls continue processing while gameplay is paused. Escape or the active member hotkey closes the drawer and resumes the prior pause state safely.

The drawer contains:

- Header: class, role, rank, traits, and capability keywords.
- Overview: health, damage, attack rate, range, movement, and class-defining values.
- Offense: typed damage, crit, projectile, area, cooldown, and healing modifiers.
- Defense: armor, resistances, dodge, block, regeneration, and life steal.
- Utility: movement, pickup, revive behavior, and future specialized values.
- Show All Stats: the complete registry for advanced inspection and debugging.

### Contextual Visibility

- Universal stats always appear.
- Specialized stats appear when a capability or relevant modifier makes them meaningful.
- A relevant specialized stat remains visible when its effective value is zero.
- Irrelevant stats remain hidden unless Show All Stats is enabled.

For example, Fire Damage appears for a Fire-capable Mage or any character that acquires a Fire modifier. It does not occupy space on every class by default.

### Source Breakdowns

Each row shows the effective value. Expanding it shows base and named contributing sources. The breakdown must reflect the resolver's actual arithmetic rather than a second UI-only calculation.

```text
Fire Damage                              +38%
  Base                                      0%
  Mage class rank                         +10%
  Ember specialization                    +15%
  Party: Arcane Convergence               +13%
```

## Tooltip Behavior

- Hovering a keyword opens its explanation.
- Keyboard or controller focus provides equivalent access.
- Keywords use a consistent visual treatment.
- Tooltips include the canonical definition plus applicable cap, format, and selected-character context.
- Tooltips can be pinned while related values are inspected.
- Every exposed keyword resolves through a registry ID.

If content refers to an unknown tooltip in a development build, the UI shows `Missing definition: <id>` so the defect is visible. Automated validation must prevent known missing definitions from passing the content suite.

## Responsive Layout

The roster and drawer use Godot containers, anchors, and project stretch behavior rather than fixed physical-screen coordinates. The logical design target remains 1920×1080 and must scale correctly to 3840×2160 without shifting modal or drawer content toward the upper-left.

The drawer may cover part of the arena because gameplay is paused. It must not obscure its own close control, selected-member identity, or tooltip region at supported resolutions.

## Validation and Failure Behavior

Catalog validation detects:

- Duplicate registry IDs.
- Missing stat, keyword, damage-type, class, attack, or trait references.
- Player-facing keywords without tooltip definitions.
- Invalid modifier operations or value ranges.
- Specialized stats without visibility or capability rules.
- Classes missing required display or combat data.
- Class-specific upgrades with no eligible class or tag.
- Damage types without matching resistance definitions.

Messages include a grep-friendly error code or content ID and the Resource path. Invalid catalog entries are excluded safely where possible so one malformed optional Resource does not crash a run. Required baseline content failing validation must fail automated tests and block a completion claim.

## Testing Strategy

Implementation follows focused red-green-refactor cycles. Automated coverage includes:

- Flat, increased, and more operation order.
- Stat minimums, maximums, rounding, and formatting.
- Conditional tag matching.
- Character-specific versus party-wide ownership.
- Modifier-source breakdowns.
- Snapshot invalidation and stable member targeting.
- Contextual stat visibility and Show All Stats.
- Typed damage and resistance calculations.
- Deterministic crit, dodge, and block outcomes through injectable or seeded randomness.
- Regeneration and life-steal limits.
- Every exposed keyword having a valid tooltip.
- All nine classes loading through the catalog.
- Leader selection generated from catalog data.
- Recruitment and upgrade eligibility with a four-member party.
- UI layout smoke checks at 1920×1080 and 3840×2160.

Focused unit and scene tests are followed by the full existing suite, Godot parser/import validation, and a manual run covering leader selection, recruitment, individual upgrades, party upgrades, drawer inspection, tooltips, and representative typed-damage interactions.

## Migration and Preservation

Existing scalar combat and class fields should migrate behind compatibility-friendly interfaces where practical, but compatibility wrappers must not create a permanent second stat model. Migration is complete when combat and UI read the resolver's values and tests no longer depend on duplicated formulas.

Preserve all unrelated user-authored and Godot-serialized work. In particular, this feature must not overwrite the user's projectile speed/lifetime tuning, formatting-only script changes, add-ons, or unrelated generated files. The in-development Marksman Resource is in scope and should be incorporated carefully.

The existing GodotSteam GDExtension add-on must remain loadable while this milestone is developed. The character/stat implementation does not initialize Steam or add Steam gameplay dependencies; Steamworks behavior receives its own later design and validation pass.

## Implementation Staging

Planning should divide work into independently verifiable stages:

1. Registries, definitions, validation, and modifier arithmetic.
2. Per-member state, source ownership, snapshots, and invalidation.
3. Typed combat, defenses, recovery, and migration of existing classes.
4. Five class Resources and catalog-driven selection/recruitment.
5. Character/party upgrade targeting and validation content.
6. Compact roster, character drawer, tooltips, and responsive behavior.
7. Full integration, documentation, and manual verification.

Items, affixes, passive-tree UI, and functional ailments begin only after this milestone is verified.

## Acceptance Criteria

The milestone is complete when:

- Nine classes are catalog-loaded and usable as leaders and recruits.
- `res://data/classes/marksman.tres` validates, references its dedicated attack Resource, is catalog-loaded, and is available through leader selection and recruitment.
- Marksman demonstrably attacks slower, hits harder, and reaches farther than Ranger.
- Every party member has independently resolved and displayed stats.
- Individual upgrades affect only their chosen member.
- Party and trait sources affect all eligible members, including later recruits where specified.
- Specialized rows appear only when relevant, with Show All Stats available.
- Combat and UI agree on effective values and source breakdowns.
- All initial damage types resolve through one typed pipeline.
- Crit, block, dodge, regeneration, life steal, armor, and resistances are functional and tested.
- Every exposed keyword has a working registry-backed tooltip.
- Leader selection contains no hard-coded four-class dependency.
- The roster and drawer remain correctly positioned at 1920×1080 and 3840×2160.
- Focused tests, the full suite, parser/import validation, and the manual acceptance run succeed without overwriting unrelated user work.
