# Party Forge Typed Combat, Defenses, and Recovery Design

**Date:** 2026-07-30
**Status:** Design sections approved in conversation; awaiting written-spec review
**Parent design:** `docs/superpowers/specs/2026-07-29-character-stats-classes-design.md`

## Purpose

Implement stage 3 of the approved character-stats milestone: migrate every current party and enemy attack to one extensible typed-damage pipeline, make the existing defensive and recovery stats functional, and ensure combat reads the same resolved character stats that future UI, upgrades, items, affixes, and passive trees will inspect.

This slice establishes the rules and extension points needed for high-synergy builds without implementing ailments, items, passive trees, or the five additional classes yet.

## Goals

- Resolve party and enemy damage through one deterministic pipeline.
- Represent damage types in Resource data so future types do not require a fixed enum or a new resolver branch.
- Support mixed-type hits, action tags, critical strikes, dodge, armor, resistances, block, life steal, and regeneration.
- Keep attacker-wide outcomes shared where appropriate while preserving independent defender reactions for area and cleave attacks.
- Make combat results inspectable enough for automated tests, future floating combat text, tooltips, and debugging.
- Remove the current duplicate armor and raw-damage paths after content migration.
- Preserve the user's tuned Spitter projectile speed and lifetime.

## Included Scope

- Resource-backed damage-type definitions and catalog.
- Typed damage components on damaging `AttackDefinition` Resources.
- Runtime attack preparation, `DamagePacket`, and `DamageResult` models.
- A seeded run-level combat random-number service.
- A central `DamageResolver` used by both teams.
- Party stat-provider and lightweight enemy stat-provider adapters.
- Functional critical strike, dodge, armor, resistance, block, life steal, and continuous health regeneration.
- Migration of all current party and enemy attacks and their delivery objects.
- Validation, focused unit and integration tests, parser/import checks, and live verification.

## Excluded Scope

- Damage over time, Ignite, Chill, Freeze, Shock, Poison, Bleed, or other ailments.
- Resistance penetration, damage conversion, or gain-as-extra-damage rules.
- Items, rarities, affixes, inventory, or equipment.
- Passive-tree state, persistence, currency, or UI.
- The five additional classes, including final Marksman integration.
- The character drawer, stat tooltips, and floating combat text.
- Final balance, final visual effects, or final audio.

## Architectural Decision

Use typed damage packets, a central resolver, and combatant adapters.

Static authoring data remains in Godot `Resource` files. Attack execution prepares the attacker-dependent portion of a hit once. Each delivery object carries that prepared attack to one or more defenders. The central resolver then evaluates defender-dependent outcomes and returns a complete result. Health components only apply final health changes and manage downed, dead, heal, and revive state.

The resolver does not know whether a combatant is a party member or enemy. It reads a small stat-provider interface supplied by an adapter:

- Party adapters obtain action-aware snapshots from `PartyManager` by stable member ID.
- Enemy adapters read registered defaults plus the `EnemyDefinition` stat overrides.

This keeps enemy setup lightweight while preventing a second damage formula.

## Data Model

### DamageTypeDefinition

Each registered damage type is a `Resource` with:

- `id: StringName`
- `display_name: String`
- `keyword_id: StringName`
- `presentation_color: Color`
- `offense_stat_id: StringName`
- `defense_stat_id: StringName`
- `mitigation_rule`, using a small rule enum owned by the definition (`ARMOR` or `RESISTANCE` initially)

The initial catalog contains:

| Type | Offense stat | Defense stat | Rule |
| --- | --- | --- | --- |
| Physical | `physical_damage` | `armor` | Armor |
| Fire | `fire_damage` | `fire_resistance` | Resistance |
| Cold | `cold_damage` | `cold_resistance` | Resistance |
| Lightning | `lightning_damage` | `lightning_resistance` | Resistance |
| Chaos | `chaos_damage` | `chaos_resistance` | Resistance |

Adding another direct-hit damage type requires a definition, matching registered stats, and content that uses it. It must not require adding a new `match` branch to the resolver.

### DamageTypeCatalog

The catalog is the authoritative lookup for type IDs. It provides stable lookup and validation, rejects duplicate IDs, and returns definitions in deterministic authoring order. Runtime packets containing an unknown type are invalid and cause no health change.

### AttackDamageComponent

Each damaging `AttackDefinition` owns one or more component Resources. A component contains:

- `damage_type_id: StringName`
- `base_amount: float`

Base amount must be finite and strictly positive. Multiple components may share an attack but duplicate type IDs within one attack are rejected to keep authoring and result breakdowns unambiguous.

### AttackDefinition Changes

`AttackDefinition` gains:

- `damage_components: Array[AttackDamageComponent]`
- `action_tags: Array[StringName]`
- `can_crit: bool`

Damaging attacks must have at least one valid damage component. Healing attacks continue to use the existing positive `power` value and must not have damage components. After migration, `power` is no longer a damage-authoring field.

Action tags describe the executed action, not the class in general. Examples include `melee`, `projectile`, `area`, `bow`, and `healing`. The preparation context combines the authored action tags with the IDs of every damage type present in the attack, so Fire-specific conditions cannot become detached from an authored Fire component. Tags are normalized by removing empty values and duplicates and sorting by `StringName` before stat resolution or cache lookup.

### DamagePacket

A runtime packet is immutable after preparation and contains:

- Source actor reference or stable source identity.
- Source team ID.
- Attack ID.
- Normalized action tags.
- Crit permission.
- Prepared crit outcome and the RNG draw used for that decision.
- Prepared typed component amounts after attacker scaling and crit.

The packet deliberately contains no defender state. Projectiles and delayed areas therefore preserve the attacker's prepared hit even if the attacker moves, changes stats, or is removed before impact.

### DamageResult

Every resolution attempt returns a result, including invalid, dodged, fully blocked, or zero-damage outcomes. The result records:

- Validity and stable error reason, if invalid.
- Source identity, attack ID, target identity, and action tags.
- Crit eligibility, crit outcome, crit draw, and crit multiplier.
- Dodge chance, draw, and outcome.
- Block chance, draw, outcome, and effectiveness.
- Per-component authored amount, global-scaled amount, typed-scaled amount, post-crit amount, mitigation stat, and post-mitigation amount.
- Contextual incoming-damage multiplier and the amount it prevents.
- Total damage before block, damage prevented by block, and resolved final damage.
- Actual health removed after health clamping.
- Life-steal rate and healing actually restored.

The result is evidence for tests and later presentation systems. Presentation code must not recalculate combat outcomes from it.

### Combatant Adapters and Identity

Each actor exposes a combat adapter with:

- Stable combatant ID.
- Team ID and availability.
- Current health component.
- Context-aware stat lookup.
- Optional incoming-damage multiplier lookup.

Party IDs derive from stable member IDs. Enemy actors receive a monotonically increasing spawn-sequence ID from the run's spawn system. The IDs are stable for that run and never derive from scene-tree order or display names.

Multi-target delivery sorts eligible defenders by stable combatant ID before consuming defender RNG. This makes the same run seed and the same combat state produce the same dodge, block, and life-steal sequence.

## Stat Resolution and Scaling

### Party Action-Aware Snapshots

`PartyManager.stats_for(member_id)` remains the context-free API used by movement, maximum health, and future UI.

Combat adds `stats_for_action(member_id, action_tags)`. It resolves the same base values and modifier sources with normalized action tags passed into `StatResolver`. Cached action snapshots use a deterministic key formed from member ID, stat revision, and sorted unique tags. Any member or party invalidation clears the affected context-free and action-aware cache entries.

This allows modifiers such as increased projectile damage or more bow damage to use the existing tag requirements without introducing attack-specific branches.

### Attacker Scaling

For each authored component:

```text
global_scaled = base_amount * attacker.damage
typed_scaled = global_scaled * attacker.<type offense stat>
post_crit = typed_scaled * attacker.crit_multiplier if the prepared hit crits
```

The current `damage` and typed damage stats are multipliers whose neutral value is `1.0`. Their own flat/increased/more modifier arithmetic remains the responsibility of `StatResolver`; the damage resolver consumes only the finalized snapshot values.

All component arithmetic uses full floating-point precision. Health and result presentation may round for display, but gameplay does not round between stages.

## Seeded Combat Randomness

Each `GameRun` creates one `CombatRng` from the run seed and passes the same service to party and enemy combat systems. Combat code must not call global `randf()`, create private `RandomNumberGenerator` instances, or hide combat RNG in an autoload.

The service exposes ordered, testable draws in the half-open range `[0.0, 1.0)`. A chance succeeds when `draw < finalized_chance`. Zero chance consumes no draw and always fails; chance at or above one consumes no draw and always succeeds. Registered stat caps normally keep current crit, dodge, and block chances below one, but the boundary behavior remains explicit.

Tests may construct the service with a known seed or a deterministic draw sequence. Production and tests use the same public combat API.

## Attack Preparation and Multi-Target Semantics

An attack execution has two phases.

### Phase 1: Prepare Once

The executor:

1. Loads the attack's normalized tags.
2. Obtains the attacker's action-aware stat snapshot.
3. Scales every typed component.
4. Rolls critical strike once if the attack may crit and chance is nonzero.
5. Applies the same crit outcome to every component.
6. Produces one immutable prepared packet.

The crit roll is shared across every target reached by that single attack execution. A Fighter cleave or Mage burst is either critical for all targets or critical for none, matching Path of Exile-style per-action critical behavior.

### Phase 2: Resolve Per Defender

For each eligible defender, in stable combatant-ID order, the resolver:

1. Validates packet and target.
2. Reads the defender's current combat stats.
3. Rolls dodge independently for that defender.
4. If not dodged, mitigates every component independently.
5. Applies any contextual incoming-damage multiplier supplied by the defender adapter.
6. Rolls block independently for that defender.
7. Applies block effectiveness to the combined post-mitigation hit.
8. Sends final damage to the defender's health component.
9. Calculates life steal from actual health removed and heals the source if eligible.
10. Returns the complete `DamageResult`.

Area and cleave delivery must deduplicate targets by actor instance and resolve no actor more than once per execution.

## Mitigation Rules

### Dodge

Dodge avoids the entire hit before mitigation. A dodged hit removes no health and grants no life steal. Each target of a multi-target attack rolls separately.

### Physical Armor

Physical components use:

```text
post_armor = physical_damage * 100 / (100 + max(0, armor))
```

Negative armor behaves as zero in this slice. Physical vulnerability can be designed later without overloading the initial rule.

### Resistances

Non-Physical registered types use:

```text
post_resistance = typed_damage * (1 - finalized_resistance)
```

The stat definition applies its registered limits before the resolver reads the value. Current Fire, Cold, Lightning, and Chaos Resistance range from `-1.0` to `0.75`. Negative resistance increases damage; `-1.0` therefore doubles the matching component. A normal maximum of `0.75` reduces it by 75 percent.

### Block

Block is rolled after all components are mitigated. On success:

```text
final_damage = total_post_mitigation * (1 - block_effectiveness)
```

`block_effectiveness` is finalized by its stat definition and currently ranges from `0.0` to `1.0`, with a neutral/default value of `0.5`. Full effectiveness may reduce a hit to zero.

### Existing Vanguard Reduction

The current positional Vanguard trait remains functional. The party combat adapter obtains `PartyManager.incoming_damage_multiplier(target_actor)` at impact and supplies it as a contextual multiplier after per-component mitigation and before block. Enemy adapters return `1.0` in this slice. The multiplier and the amount it prevents are recorded in `DamageResult`.

This adapter hook preserves the existing nearby-protection behavior without letting `PartyActor.receive_damage` bypass the resolver. A later generalized damage-taken modifier system may replace the hook only after it has its own approved order-of-operations design.

### Zero Damage

The old minimum-one-damage rule is removed. Valid mitigation and block may produce zero final damage. The resolver rejects non-finite values and clamps the final value to at least zero, but it does not round or apply an epsilon minimum; any finite positive result removes that exact amount of health.

## Health, Life Steal, and Regeneration

### HealthComponent Responsibility

`HealthComponent` no longer stores or subtracts armor. Its damage entry point accepts resolved, nonnegative final damage, clamps health, performs downed/dead transitions, and returns the actual health removed.

Focused health-state tests may call this final-damage entry point directly. Gameplay attacks, projectiles, contact attacks, and boss areas must not bypass `DamageResolver`.

### Life Steal

Life steal is:

```text
requested_heal = actual_health_removed * attacker.life_steal
```

The source health component applies normal maximum-health clamping and reports the healing actually restored. Life steal:

- Uses actual health removed, excluding overkill.
- Grants nothing for invalid, dodged, zero-damage, already defeated, or unavailable targets.
- Is calculated separately for each actually damaged target of a multi-target attack.
- May heal between target resolutions, while target iteration remains deterministic.
- Does not apply to healing abilities.
- Does not revive a downed or dead source.

### Healing Abilities

Positive healing remains separate from typed damage:

```text
requested_heal = attack.power * attacker.healing_power
```

Healing does not crit, use mitigation, trigger life steal, or create a `DamagePacket`. Existing healing target selection and health clamping remain intact.

### Continuous Regeneration

A small `RecoveryController` associated with each combatant advances recovery using the current provider value:

```text
requested_heal = max(0, health_regeneration) * max(0, delta)
```

Regeneration is continuous, frame-rate independent, and clamped by `HealthComponent.heal`. It pauses at full health and while a combatant is downed or dead. It resumes after revival using the current stat snapshot. Recovery tests call an explicit advance method; they do not depend on wall-clock waits or scene-frame timing.

## Enemy Combat Data and Adapters

`EnemyDefinition` replaces scalar `contact_damage` authoring with:

- `stat_overrides: Dictionary[StringName, float]`
- `attacks: Array[AttackDefinition]`

Enemy providers begin with registered neutral/default values and overlay validated finite values from `stat_overrides`. Current enemies have zero armor, resistances, dodge, block, regeneration, and life steal unless explicitly authored otherwise.

Enemy behavior scripts retrieve required attacks by stable attack ID, never by array position. Capability validation ensures each behavior has the attacks it uses.

Current enemy migration requires at least:

- Swarmer contact attack: Physical.
- Spitter projectile attack: Physical.
- Forge Guardian charge/contact attack: Physical.
- Forge Guardian shockwave attack: Physical.

Summoning is not a damaging attack. It remains a behavior action.

## Current Party Content Migration

Every present damaging party attack receives typed components and action tags:

| Resource | Initial type | Required tags |
| --- | --- | --- |
| `fighter_cleave.tres` | Physical | `melee`, `area` |
| `ranger_shot.tres` | Physical | `projectile`, `ranged` |
| `mage_burst.tres` | Fire | `projectile`, `area`, `fire` |
| `cleric_bolt.tres` | Lightning | `projectile`, `lightning` |
| `cleric_heal.tres` | Healing, no damage components | `healing` |

The existing four class identities remain unchanged except that their attacks now use typed damage. Marksman is deliberately left for the later class-expansion stage, but this pipeline must be ready for its Physical `projectile`, `ranged`, and `bow` tags.

## Delivery Objects

- Melee execution resolves the prepared packet against each deduplicated target in range.
- Party projectiles carry the prepared packet instead of a scalar damage value.
- Area bursts carry the same prepared packet and create an independent defender result per target.
- Enemy projectiles carry a prepared packet and resolve it on impact.
- Enemy contact and boss areas prepare their authored attack and use the central resolver.

The Spitter projectile's current movement tuning remains exactly `SPEED = 6.0` and `MAX_LIFETIME = 3.0` during this slice. Typed-packet migration must not restore the previous harder-to-dodge values or otherwise change its homing behavior.

## Error Handling and Validation

Validation errors use grep-friendly messages beginning with:

```text
PARTY_FORGE_DAMAGE_ERROR
```

Messages include the relevant type, attack, enemy, stat, or Resource path whenever available.

Content validation rejects:

- Missing or duplicate damage-type IDs.
- Missing display, keyword, offense-stat, or defense-stat references.
- Unknown offense or defense stat IDs.
- Unsupported mitigation rules.
- Resistance-mitigated types whose defense stat is not a registered resistance.
- Missing, null, non-finite, non-positive, duplicate-type, or unknown-type attack components.
- Damaging attacks without components.
- Healing attacks with damage components or crit enabled.
- Empty or duplicate action tags after normalization.
- Missing enemy attack IDs or duplicate attack IDs within an enemy.
- Unknown or non-finite enemy stat overrides.
- Behavior definitions missing required stable attack IDs.

Runtime validation treats an unknown type, non-finite amount, missing or empty combatant identity, missing source provider, missing target provider, unavailable target, or team-invalid target as an invalid result. It emits a stable diagnostic, performs no health change, consumes no defender RNG, and grants no life steal.

Required baseline catalog or migrated content errors fail automated validation. Optional malformed entries are excluded safely where possible, but baseline gameplay must not silently fall back to raw scalar damage.

## Migration Completion Rules

Migration is complete only when:

- `HealthComponent` contains no armor formula or armor field.
- `EnemyDefinition` contains no `contact_damage` field.
- Party and enemy delivery objects carry packets rather than scalar damage.
- Gameplay code has no direct raw-damage calls into party or enemy health.
- All current attack Resources validate through the typed catalog.
- All current enemy behaviors retrieve attacks by stable ID.
- The old subtractive armor formula and minimum-one-damage behavior are absent.
- Existing healing still works through its explicitly separate positive-effect path.

Temporary compatibility helpers are acceptable only inside an individual migration commit and must not remain at completion.

## Testing Strategy

Implementation follows focused red-green-refactor cycles. Tests use real Resources and production APIs rather than test-only production methods.

### Catalog and Validation Tests

- Initial five types load and map to the correct offense and defense stats.
- A test-only additional type resolves through data without modifying resolver code.
- Duplicate and missing IDs, unknown stats, missing resistance mappings, and invalid mitigation rules fail with stable diagnostics.
- Damaging, healing, enemy, and component validation covers every rejection rule above.

### Resolver Unit Tests

- Neutral single-component Physical and elemental hits.
- Global and typed multipliers apply multiplicatively.
- Mixed-type packets mitigate each component independently.
- One prepared crit outcome applies to every component.
- One prepared crit outcome is shared across all targets of an execution.
- Different targets make independent dodge and block rolls.
- Multi-target defender order is stable by combatant ID for reproducible RNG consumption.
- Dodge occurs before mitigation and prevents the complete hit.
- Armor matches the diminishing-returns formula, including zero and negative armor.
- Positive, capped, zero, and negative resistances match the registered rules.
- Block occurs after mitigation and uses block effectiveness.
- Vanguard's current nearby reduction is applied in the resolver and remains functional.
- Full block and high mitigation may yield zero damage.
- Invalid packets consume no defender RNG and make no state change.
- Results preserve all calculation evidence.

### Health and Recovery Tests

- Final damage reports actual health removed.
- Overkill does not increase life steal.
- Dodged, blocked-to-zero, and unavailable targets grant no life steal.
- Multi-target attacks grant life steal only from targets actually damaged.
- Life steal respects source maximum health and dead/downed restrictions.
- Healing power scales healing without entering damage resolution.
- Regeneration is frame-rate independent, respects maximum health, pauses while downed/dead, and resumes after revive.

### Adapter and Integration Tests

- Party attacks use action-aware snapshot tags and invalidate cached contexts correctly.
- Enemy defaults and stat overrides feed the same resolver.
- Fighter cleave, Ranger projectile, Mage area projectile, Cleric bolt, and Cleric heal preserve their delivery behavior.
- Swarmer contact, Spitter projectile, Guardian charge/contact, and Guardian shockwave use stable authored attacks.
- Projectiles retain prepared values after launch.
- Area and cleave attacks deduplicate targets.
- A repository check finds no remaining gameplay raw-damage path, `contact_damage`, or subtractive armor formula.

Focused tests are followed by the complete existing test suite and a headless Godot parser/import scan.

## Live Verification

With the editor's saved user state preserved, run the game and verify:

1. Fighter damages multiple nearby enemies with Physical cleave.
2. Ranger projectile deals Physical damage and remains functional.
3. Mage burst deals Fire area damage through one prepared packet.
4. Cleric bolt deals Lightning damage and Cleric healing remains a positive effect.
5. A temporary controlled defender demonstrates armor, one resistance, dodge, and block without adding permanent balance content.
6. A controlled damaged party member visibly regenerates and a controlled attacker visibly receives life steal.
7. Swarmer, Spitter, and Forge Guardian attacks all damage party members through the shared resolver.
8. Spitter projectiles remain avoidable with speed `6.0` and lifetime `3.0`.
9. Enemies can still be defeated, experience gained, levels earned, party members downed/revived, and the run completed or lost.
10. Godot's debugger contains no new parser, Resource, or combat errors.

## Acceptance Criteria

This slice is complete when:

- Five initial damage types load from one Resource catalog and an additional test type requires no resolver branch.
- Every current damaging party and enemy action uses typed components and the central resolver.
- Global and typed damage, crit, dodge, armor, resistance, block, regeneration, and life steal are functional and covered by deterministic tests.
- A single attack execution shares its crit result and gives each defender independent dodge and block outcomes.
- Mixed-type packets and negative resistance behave according to this specification.
- Life steal uses actual health removed and excludes overkill and avoided damage.
- Healing remains functional without masquerading as negative damage.
- Party action tags use the existing modifier model and snapshot invalidation.
- `DamageResult` provides complete, testable calculation evidence.
- No gameplay raw-damage bypass, legacy subtractive armor formula, scalar enemy `contact_damage`, or minimum-one-damage rule remains.
- Spitter speed and lifetime tuning remain unchanged.
- Focused tests, the full suite, parser/import validation, and the live verification pass succeed without staging or overwriting unrelated user work.

## Future Extension Points

The catalog and per-component result model provide stable insertion points for later penetration, conversion, gain-as-extra, ailments, keyword tooltips, items, affixes, and passive-tree modifiers. Those systems require their own approved rules before implementation; this slice intentionally does not guess their order of operations.
