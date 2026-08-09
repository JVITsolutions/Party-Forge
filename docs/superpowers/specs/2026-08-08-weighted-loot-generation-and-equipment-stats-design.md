# Party Forge Weighted Loot Generation and Equipment Stats Design

**Status:** Approved design

**Date:** 2026-08-08

**Depends on:** Plan 4B item identity and ownership, leader-loadout and extraction continuity, shared equipment UI and layered item tooltips, canonical stat resolution, and action combat estimates

## Purpose

This increment turns Party Forge's deterministic item fixtures into a production-ready, data-driven loot-generation foundation and makes equipped items affect character statistics and action estimates. The system is designed for the game's long-term identity: large build variety, strong synergies, unlock-heavy progression, and extreme incremental scaling without sacrificing reproducibility or save integrity.

The generator must be explainable enough to balance hundreds of affixes later. A generated item is the result of explicit stages, not one opaque random function. Every accepted and rejected choice can be reconstructed from a seed and request. Once issued, the item remains an immutable record containing the exact base, rarity, affixes, tiers, operations, and rolled values selected at generation time.

This design preserves the existing ownership, equipment, extraction, Armoury, Warehouse, tooltip, and profile-save contracts. It extends those systems rather than creating parallel item or stat pipelines.

## Approved decisions

- Use a staged deterministic generator with a typed request and structured result.
- Preserve the ten authored equipment rarity ranks from Common through Eternal.
- Register all ten ranks now, but allow ordinary generation only through Legendary in the first production pool.
- Let rarity definitions own weighted prefix/suffix patterns and explicit-affix counts.
- Keep guaranteed equipment-base implicits separate from explicit rarity affixes.
- Launch with twelve affix power tiers while keeping the schema expandable beyond twelve.
- Author approximately 75-100 initial numerical and hybrid affixes as individual resources in categorized folders and register them through an explicit manifest.
- Use relative spawn weights, modifier families, tags, item-level gates, rarity/source restrictions, and generation domains.
- Use an initial content item-level domain of 1-1000. Item level comes from the content source, not character level.
- Higher item level improves access to and relative odds of stronger tiers and naturally rarer affix families, but never guarantees them or bypasses gates.
- Use soft party bias only while selecting an equipment base. Affix selection remains based on the item, source, and generation rules.
- Give the six attributes universal meanings across all classes.
- Add canonical melee, ranged, and caster damage stats independently from physical, fire, cold, lightning, chaos, and future damage types.
- Give every ordinary damaging action exactly one primary archetype tag to prevent accidental double dipping.
- Resolve attributes before attribute-derived combat modifiers and forbid derived stats from feeding back into attributes.
- Apply equipment changes atomically and preserve existing current-health behavior when maximum health changes.
- Extend the developer sandbox with a deterministic Loot Lab that explains and statistically exercises the generator without mutating player profiles.
- Preserve normal item tooltip controls: hover for the item, Alt or left trigger for comparison, and Shift or right trigger for advanced affix details.

## Scope

This design covers:

- Production rarity definitions and weighted affix-pattern definitions.
- Production affix and tier resource schemas.
- Explicit affix manifests and startup validation.
- Deterministic equipment-base, rarity, pattern, affix-family, tier, and roll selection.
- Item-level, source, difficulty/Heat, unlock, party-bias, and Charisma inputs.
- Guaranteed base implicits and explicit affix generation.
- Equipment-to-stat modifier projection.
- Universal attribute projection and primary action-archetype scaling.
- Damage, healing, defense, and action-estimate refresh after equipment changes.
- Developer-only item-generation traces and batch distribution analysis.
- Save compatibility, structured failures, and verification requirements.

This design does not yet implement:

- Conditional-on-event modifiers, triggered skills, procs, status application, summons, or skill transformations.
- Legendary special powers or Mythic-through-Eternal acquisition systems.
- Crafting, corruption, rerolling, enchanting, salvage, vendors, carts, or player-to-player item transfer.
- Final drop-rate balance for every game mode, difficulty, region, boss, or passive tree.
- Ground-drop presentation, rarity beams, slot-machine reward audio, or final rarity visual effects.
- New inventory, stash, extraction, Armoury, or Warehouse ownership rules.
- Final incremental-number display policy for values beyond the existing supported ranges.

Those future systems consume the same request, domain, tag, modifier-family, item-instance, and stat-source contracts.

## Architectural overview

The generation flow is deliberately staged:

```text
ItemGenerationRequest
        |
        v
Equipment Base Selector
        |
        v
Rarity Selector
        |
        v
Rarity Pattern Selector
        |
        v
Eligible Affix Pool Builder
        |
        v
Weighted Affix Family Selector
        |
        v
Affix Tier Selector
        |
        v
Exact Roll Selector
        |
        v
Existing ItemInstanceIssuer
        |
        v
Immutable ItemInstance
```

Each stage receives an immutable view of the request and prior selections. It returns either one complete stage result or a structured failure. No stage writes to a profile, run inventory, equipment sheet, issuer sequence, or ownership registry.

Only after every generation stage succeeds does the existing issuer allocate the final sequence and create the immutable item instance. Placement remains a separate existing item-container transaction. This prevents a failed generation from consuming an issuance sequence or leaving an orphaned record.

## Generation request

`ItemGenerationRequest` is a typed value object with at least:

- `seed`: deterministic generation seed.
- `generation_sequence`: deterministic substream/sequence within the seed.
- `item_level`: positive content level, initially tuned over 1-1000.
- `source_id`: stable source identity such as enemy family, boss, wave, region, vendor, or crafting source.
- `generation_domain`: ordinary drop, boss drop, raid drop, vendor, crafting, developer, or future domain.
- `difficulty_id` and `heat`: mode/difficulty inputs that may modify allowed ranks or relative weights.
- `permitted_rarity_ids`: the ranks this caller is authorized to generate.
- `party_archetype_tags`: primary archetype needs represented in the active local party.
- `charisma_value`: resolved loot-influence Charisma supplied by the owning profile/player context.
- `unlock_tags`: progression gates already unlocked by the relevant profile.
- `required_base_tags` and `excluded_base_tags`: optional caller restrictions.
- `required_affix_tags` and `excluded_affix_tags`: optional domain restrictions.
- `forced_base_id`, `forced_rarity_id`, or other explicit developer/test overrides when the domain permits them.

The request must be JSON-safe and canonicalizable for traces and deterministic tests. It cannot hold scene nodes, live party objects, mutable profile state, or random-number-generator objects.

## Deterministic randomness

One request produces the same complete item or the same structured failure on every supported machine and repeated run when catalogs and generator-version inputs are identical.

The generator uses named deterministic substreams or stable stage salts. Adding a diagnostic random call in one stage must not shift unrelated later selections. The item origin records:

- generator schema/version,
- source and domain,
- seed and generation sequence,
- item level,
- selected rarity and base,
- and any authorized override identifiers.

The origin is diagnostic provenance. Existing items are never reconstructed from their seed during load. Their exact generated values remain explicit in the item instance.

## Rarity ranks

The term **rarity rank** identifies the ten equipment rarities. The term **affix tier** is reserved for the independent power tiers within an affix definition.

| Rank | Rarity | Ordinary first-pool status | Explicit affixes | Long-term identity |
| ---: | --- | --- | ---: | --- |
| 1 | Common (white) | Active | 0 | Base implicit only |
| 2 | Uncommon (green) | Active | 1 | One prefix or suffix |
| 3 | Rare (blue) | Active after progression unlock | 2 | Two explicit affixes |
| 4 | Epic (purple) | Active after progression unlock | 3 | Three explicit affixes and a visual glow |
| 5 | Legendary (orange) | Active after progression unlock | 4 | Peak natural gear plus a reserved game-changing special-power slot |
| 6 | Mythic (red) | Registered, ordinary generation inactive | 4 | Raid-boss/crafted acquisition, stronger level-scaling affixes |
| 7 | Exotic (teal) | Registered, ordinary generation inactive | 5 | Rule-breaking mechanics; eventual two-equipped limit |
| 8 | Ascendant (gold) | Registered, ordinary generation inactive | 6 | High-difficulty celestial gear with evolving stats |
| 9 | Divine (cyan) | Registered, ordinary generation inactive | 4 | High-level party synergy and aura affixes |
| 10 | Eternal (prismatic) | Registered, ordinary generation inactive | Special | Absolute ceiling, unbounded/evolving or world-tier effects |

All ranks are visible and issuable through explicitly authorized Developer Mode fixtures. Mythic through Eternal must reject ordinary generation until their dedicated acquisition, modifier, scaling, equip-limit, and persistence rules exist.

Legendary is active for ordinary generation with four explicit numerical/hybrid affixes. Its reserved special-power slot remains empty and visibly marked inactive in developer traces until the special-power system is implemented. An ordinary Legendary cannot silently substitute a fifth normal affix for that reserved slot.

## Rarity patterns and affix capacity

Rarity owns a weighted collection of affix patterns rather than only minimum and maximum counts. A pattern declares its prefix count, suffix count, special count, weight, and applicable generation domains.

The first active patterns are:

- Common: zero explicit affixes.
- Uncommon: weighted choice between one prefix and one suffix.
- Rare: weighted choice among two prefixes, one prefix plus one suffix, and two suffixes.
- Epic: weighted choice between two prefixes plus one suffix and one prefix plus two suffixes.
- Legendary: four explicit affixes selected from data-authored prefix/suffix patterns, plus one inactive reserved special-power slot.

The exact initial weights are balance data, not hardcoded policy. Patterns are validated against the rarity's exact explicit-affix count. Future ranks may use more than three prefixes or suffixes; the schema must not impose a universal three-prefix/three-suffix cap.

Every equipment base separately declares guaranteed implicit definitions. Implicits are generated before explicit affixes, appear in their own tooltip section, and do not consume prefix, suffix, or special capacity.

## Affix definition model

Each production affix is one authored Godot Resource under a categorized data folder and is registered by an explicit manifest. Recursive directory discovery is not authoritative because accidental files, editor backups, or temporary resources must not change the loot pool.

An affix definition contains at least:

- stable `id` and player-facing name components,
- `affix_kind`: implicit, prefix, suffix, or special,
- one or more typed modifier effects,
- one or more modifier-family IDs,
- required, optional, and excluded item/base tags,
- allowed generation domains and sources,
- allowed rarity ranks,
- base spawn weight,
- tier definitions,
- advanced-tooltip name such as a prefix or suffix title,
- player-facing keyword references,
- developer notes and balance category.

Each modifier effect identifies a canonical stat, operation, finite value range, and applicability tags. The existing flat, increased, reduced, more, and less operations remain authoritative unless a later explicitly designed operation is added.

Hybrid affixes remain one affix and consume one pattern slot. They can contribute multiple modifier effects, but must declare every modifier family they block. This keeps a single hybrid from stacking with closely related pure affixes unless deliberately allowed.

### Modifier families

Modifier families are stable exclusion groups. Once an affix is selected, every candidate that shares a mutually exclusive family is removed from the remaining eligible pool. Families prevent combinations such as multiple versions of the same maximum-health affix, pure and hybrid variants of the same restricted bonus, or conflicting mutually exclusive mechanics.

Families are not display labels. They are validated stable IDs and can be shared across prefixes, suffixes, implicits, and future special powers when the design requires exclusion.

## Initial affix content

The first production manifest contains approximately 75-100 numerical and hybrid affixes. It should establish broad build coverage without prematurely encoding complex triggers.

The initial categories include:

- Strength, Dexterity, Constitution, Intelligence, Wisdom, and Charisma.
- Melee damage, ranged damage, and caster damage.
- Physical, fire, cold, lightning, and chaos damage.
- Critical-strike chance and critical-strike multiplier.
- Attack speed, cooldown recovery, range, projectile speed, and area size.
- Maximum health, armor, dodge, block, health regeneration, life steal, and resistances.
- Healing power, movement speed, pickup range, and appropriate numerical utility stats.
- Intentional two-effect hybrid affixes that declare all blocked families.

Conditional affixes, on-hit/on-kill/on-damage triggers, ailments, summoned allies, skill replacement, and rule-breaking behavior are a later content milestone. The first schema still reserves generation-domain, tag, keyword, and special-effect extension seams so those additions do not require replacing item identity.

## Affix tiers

The initial pool has twelve ascending affix tiers. Tier numbers ascend in power: Tier 1 is the weakest initial tier and Tier 12 the strongest initial tier. The schema uses authored tier records rather than fixed arrays whose length is assumed to be twelve.

Each tier record includes:

- tier number,
- minimum item level,
- base tier weight,
- minimum and maximum roll for every modifier effect,
- allowed rarity/source/domain restrictions when narrower than its parent affix,
- and optional developer balance metadata.

Tier thresholds are ascending and roll ranges are finite and non-descending in power. Tiers do not have to use evenly spaced item levels or linear values. More tiers may be added later without changing item-instance serialization because issued items already store the selected tier and exact rolls.

## Eligibility and weighted selection

The generator filters before it weights. An affix or tier is eligible only when all applicable rules pass:

1. The manifest entry and referenced resources are valid.
2. Its affix kind matches an open slot in the selected rarity pattern.
3. The equipment base/item tags satisfy required and excluded tags.
4. The request generation domain and source are allowed.
5. The rarity rank is allowed.
6. The item level reaches the tier threshold.
7. Required progression unlocks are present.
8. It does not conflict with already selected modifier families.
9. Caller restrictions do not exclude it.

Only the surviving pool receives relative weights. Stronger, more synergistic affix families and higher tiers generally have lower base weights. The effective weight is a finite positive value calculated from data-authored factors such as:

```text
base affix weight
* source/domain modifier
* item-level affix-rarity shift
* rarity-rank modifier
* tier weight
* item-level tier shift
* difficulty/Heat modifier
* diminishing Charisma modifier
```

This formula describes factor order, not fixed numeric tuning. Ineligible candidates always have zero participation and cannot be restored by a positive modifier.

### Item-level behavior

Item level represents content power and comes from the drop source: enemy, boss, wave, region, difficulty/Heat, vendor, crafting source, or future encounter definition. It is never copied directly from the receiving character's level.

The initial broad balance domain is 1-1000. As item level rises:

- more affix tiers become eligible,
- higher eligible tiers gain relative weight,
- naturally lower-weight affix families receive a controlled relative boost,
- and low tiers remain possible unless a specific source rule excludes them.

High item level improves opportunity; it does not promise a high tier or rare family. A level-1000 Rare item is still a Rare item with its rarity pattern and affix count. It may roll strong tiers, but neither Rare nor item level alone forces Tier 8 or any other tier.

### Difficulty and Heat

Difficulty and Heat enter through explicit request fields and data-authored weight or authorization rules. They may improve rarity-rank odds, tier odds, special-source access, or item level, but must not be hidden global state. A trace must distinguish a rarity becoming authorized from its weight merely increasing.

## Equipment-base smart loot

Smart loot is a soft bias during equipment-base selection only. The active party's primary archetype tags increase the relative weights of bases useful to that party, while a configurable portion of global and off-party equipment remains available.

The bias must not:

- guarantee an immediately equippable base,
- remove global accessories,
- choose an affix based on the currently focused character,
- or make the same seed nondeterministic when UI focus changes.

After selecting the base, affix generation uses only the base/item tags, request source/domain, progression gates, item level, rarity, difficulty/Heat, Charisma, and already selected families.

## Charisma and loot influence

Charisma has one universal identity with both combat-support and smaller loot/economy effects. It contributes to party influence, party-wide damage, healing, and future support-effect strength. Its loot/economy contribution is deliberately secondary.

Resolved Charisma may apply diminishing-return improvements to:

- rarity-rank odds,
- naturally rare affix-family weights,
- exact roll quality within an already selected tier,
- gold quantity,
- and future vendor outcomes.

Charisma has a configurable soft cap with no hard cap. It can make good outcomes more likely but cannot authorize locked rarity ranks, unlock an affix or tier, bypass item tags, defeat a modifier-family conflict, override source/domain restrictions, or exceed a tier's authored roll range.

## Universal attribute model

All classes use the same six attributes and meanings:

| Attribute | Universal derived effects |
| --- | --- |
| Strength | Melee damage and armor |
| Dexterity | Ranged damage, attack speed, and dodge |
| Constitution | Maximum health and health regeneration |
| Intelligence | Caster damage and area size |
| Wisdom | Healing power and cooldown recovery |
| Charisma | Party influence plus smaller loot/economy influence |

Class growth determines which attributes a class gains most efficiently, but does not redefine an attribute. Equipment, run upgrades, passive trees, and future buffs all feed the same raw attribute values.

### Two-pass resolution

Character stats resolve in two explicit passes:

1. Resolve raw Strength, Dexterity, Constitution, Intelligence, Wisdom, and Charisma from class base/growth, levels, upgrades, passive trees, equipment, and future approved sources.
2. Project attribute-derived modifier sources and then resolve all combat, support, defense, action, and display stats.

Derived stats never feed back into attributes. This acyclic contract prevents unstable loops such as Strength granting armor which grants Strength.

Attribute conversion coefficients and diminishing curves are data-driven balance values. Source IDs remain stable so the ledger and diagnostics can explain the exact class, level, equipment, upgrade, passive, and derived-attribute contribution.

## Archetype damage and damage types

Add canonical `melee_damage`, `ranged_damage`, and `caster_damage` stats. These describe how an action is delivered, not what damage type it deals.

Damage types remain independent: physical, fire, cold, lightning, chaos, and future types. Examples:

- A flaming sword attack scales with melee damage and fire damage.
- A physical spell scales with caster damage and physical damage.
- A chaos arrow scales with ranged damage and chaos damage.

Every ordinary damaging action declares exactly one primary archetype tag: melee, ranged, or caster. The nine current classes must each author the correct primary tag for every damaging basic, primary, and ultimate action. Future deliberately hybrid actions may declare explicitly designed secondary scaling, but the resolver must never infer two primary tags or accidentally apply two full archetype multipliers.

Critical-strike chance and critical-strike multiplier are independent canonical stats and both participate in action estimates and tooltips where relevant.

## Equipment modifier projection

An equipped item projects its guaranteed implicits and explicit affix rolls into the existing `StatModifierSource` pipeline. It does not mutate class definitions, base stats, affix resources, or the item instance.

Source IDs are stable and identify:

- owning member,
- equipment slot,
- item instance,
- implicit or explicit affix,
- and modifier-effect index when an affix has multiple effects.

The stat ledger can therefore group or explain a contribution without relying on display text. Attribute-derived sources and Charisma party-influence sources use separate stable namespaces.

### Atomic equipment change

Equipping, swapping, or removing gear is one failure-atomic operation:

1. Validate the proposed complete loadout through existing eligibility and ownership rules.
2. Build every equipment modifier source for the candidate loadout.
3. Validate all referenced stats, operations, values, tags, affix instances, and source IDs.
4. Resolve a candidate stat state and action estimates.
5. Commit equipment ownership and replace equipment-derived sources together.
6. Invalidate caches and refresh the ledger, tooltips, action damage/healing values, defenses, and derived UI.

If any stage fails, equipment placement, ownership, modifier sources, current health, and displayed projections remain unchanged.

When maximum health decreases, current health clamps to the new maximum. Equipping or removing maximum-health gear never grants free healing by preserving a percentage or increasing current health. Future explicit healing-on-equip behavior requires its own effect system.

## Immutable instance and save behavior

Issued items continue to store exact immutable values:

- base definition ID,
- rarity ID,
- item level,
- ordered implicit and explicit affix instances,
- affix definition IDs and kinds,
- selected tiers,
- modifier operations and exact rolled values,
- origin/source data,
- and generator version/provenance.

Catalog changes affect future generation only. Loading a save does not reroll, retier, or recompute an old item's affixes. If an authored definition is later removed or made incompatible, strict validation produces a stable diagnostic and existing recovery/quarantine rules apply; the loader never silently substitutes another affix.

Existing fixture items and profile schema remain loadable. Any schema increment requires explicit migration and round-trip verification through the existing atomic profile store.

## Tooltips and player presentation

Normal equipment presentation continues to use the shared item slot and layered tooltip contracts:

- Hover/focus shows the item's name, icon, rarity background, restrictions, implicits, explicit affixes, and rolled values.
- Alt on keyboard/mouse or left trigger on controller shows comparison against the currently equipped item for the selected character.
- Shift on keyboard/mouse or right trigger on controller shows advanced affix names, affix tiers, actual rolls, and possible roll ranges.
- Normal keywords use the shared keyword-tooltip system.
- Unequippable state remains visible through the existing icon and tooltip reason.

Developer Mode may additionally show IDs, tags, modifier families, base/effective weights, source/domain decisions, stage substreams, and generation traces. These diagnostics are never shown in ordinary Player Mode.

## Developer Loot Lab

The existing isolated Developer Item Sandbox gains a Loot Lab page. It uses a disposable developer ownership domain and cannot mutate the selected player profile, persistent stash, active run, or progression unlocks.

The Loot Lab supports:

- Selecting or randomizing an equipment base.
- Selecting allowed rarity ranks.
- Setting item level, source, domain, difficulty, and Heat.
- Configuring party archetype tags and Charisma.
- Entering a seed and generation sequence.
- Generating one item or a deterministic batch.
- Issuing a selected result into the existing sandbox inventory.
- Viewing every stage's eligible candidates, exclusions, effective weights, selected pattern, families, tiers, and exact rolls.
- Comparing observed batch distributions with normalized expected weights.
- Flagging unreachable affixes, empty pools, modifier-family conflicts, tier gaps, impossible patterns, and inactive-rarity violations.
- Exporting a JSON-safe or text balance report without saving profile state.

Batch generation must be bounded and cancellable so performance experiments cannot freeze the editor. Repeating the same batch parameters produces the same ordered results.

## Validation and failure behavior

Catalog startup validation rejects the production manifest when any of these conditions occur:

- Duplicate or empty stable IDs.
- A manifest path is missing, duplicated, or points to the wrong resource type.
- Unknown stat IDs, operations, tags, modifier families, generation domains, sources, rarity IDs, or unlock IDs.
- Non-finite, zero, or negative participating weights.
- Missing, descending, duplicate, or invalid tier numbers.
- Non-ascending item-level thresholds.
- Missing or non-finite roll ranges, minimum values above maximum values, or power ranges descending unexpectedly without an explicit exemption.
- Rarity patterns whose counts do not match their rarity definition.
- An enabled rarity with no reachable valid pattern or possible generation source.
- An active equipment base with invalid or unreachable guaranteed implicits.
- A hybrid affix that fails to declare all of its modifier families.
- Mythic-through-Eternal ordinary generation accidentally enabled before their systems exist.

A generation request returns either one complete candidate item or a structured `ItemGenerationFailure`. Failure contains the generator version, stage, source, seed, generation sequence, stable reason code, and relevant candidate rejection summaries. It does not return a partial item.

Generation failure consumes no item issuance sequence and mutates no inventory, equipment sheet, ownership registry, run context, profile, or save file.

## Delivery sequence

Implementation is divided into four bounded increments.

### Increment 1: Definitions and deterministic generator

- Expand rarity definitions and add weighted pattern definitions.
- Add tier records, multi-effect affixes, modifier families, generation domains, request/result/failure/trace types, explicit manifests, and validators.
- Implement deterministic base, rarity, pattern, affix, tier, and exact-roll stages.
- Register all ten rarity ranks while keeping ordinary generation restricted through Legendary.
- Preserve fixture issuance and existing immutable codecs.

### Increment 2: Equipment and attribute application

- Add canonical melee, ranged, and caster damage stats where absent.
- Implement the two-pass raw-attribute and derived-stat projection.
- Add stable equipment and attribute-derived modifier sources.
- Wire atomic loadout source replacement, cache invalidation, health clamping, ledger refresh, tooltips, and action combat estimates.
- Audit all nine classes and their damaging actions for exactly one primary archetype tag.

### Increment 3: Initial production content

- Author approximately 75-100 numerical/hybrid affix resources with twelve initial tiers.
- Author/validate guaranteed implicits for every active equipment base.
- Establish initial relative weights, modifier families, item-level thresholds, rarity/source restrictions, and advanced tooltip names.
- Produce balance reports covering item levels, rarities, equipment archetypes, party bias, and Charisma.

### Increment 4: Loot Lab and integration

- Add the developer-only Loot Lab UI and batch analysis.
- Connect authorized production sources to the generator without changing ownership transactions.
- Validate Player Mode/Developer Mode gates, responsive layouts, mouse/keyboard input, and controller input.
- Complete cold-import, full-suite, startup, save-compatibility, and manual equipment-stat verification.

Each increment receives its own implementation plan, RED/GREEN tests, review, and approval/integration checkpoint. Complex conditional/proc affixes and upper-rarity special systems remain later increments rather than being smuggled into the initial numerical pool.

## Verification strategy

### Catalog and deterministic unit tests

- Every manifest/resource validation rule has a failing fixture and passing counterpart.
- Fixed requests produce byte-equivalent canonical results for fixed seeds.
- Each stage failure reports the correct stage, code, source, seed, and rejection context.
- Failed generation consumes no issuer sequence and mutates no ownership state.
- Common through Legendary produce only valid authorized patterns.
- Mythic through Eternal reject ordinary generation and remain available only to authorized developer fixtures.
- Implicits appear on every applicable base and never consume explicit slots.
- Modifier families prevent forbidden pure/pure and pure/hybrid combinations.

### Statistical tests

Deterministic large batches measure observed distributions against broad, non-flaky tolerances across:

- low, middle, and high item levels,
- each active rarity,
- melee, ranged, caster, and global equipment bases,
- different party compositions,
- low, moderate, and extreme Charisma,
- and representative difficulty/Heat settings.

Tests must demonstrate direction rather than guarantee individual outcomes: higher item level trends toward higher tiers and lower-weight families; Charisma shows diminishing returns; soft party bias increases useful bases without eliminating off-party/global bases; no modifier ever bypasses a hard gate.

### Stat and equipment tests

- All six attributes resolve before their derived combat sources.
- Derived stats cannot modify raw attributes.
- Strength, Dexterity, Constitution, Intelligence, Wisdom, and Charisma apply their approved universal effects.
- Every current damaging action has exactly one correct primary archetype tag.
- Melee/ranged/caster scaling composes independently with damage types.
- Deliberate future hybrid tests cannot accidentally receive two full primary multipliers.
- Critical chance and critical multiplier both affect estimates correctly.
- Equipping and removing items updates attributes, action damage, DPS, healing, health, armor, dodge, block, cooldowns, area, and other affected ledger rows.
- Failed equipment transitions are byte-equivalent and UI-equivalent to the starting state.
- Maximum-health decreases clamp current health; maximum-health increases do not heal.
- Save/load preserves exact item tiers, operations, and rolls after catalogs are changed in a test fixture.

### UI and integration tests

- Normal, compare, and advanced tooltip layers preserve mouse/keyboard and controller behavior.
- Developer diagnostics are absent in Player Mode.
- Loot Lab is unavailable outside Developer Mode and cannot mutate real profiles.
- Recipient/member switching keeps comparison and equipment eligibility correct.
- Equipment and Loot Lab layouts remain usable at 1920x1080, 2560x1440, and 3840x2160.
- Controller focus, scrolling, generation, batch cancellation, item issue, and tooltip modifiers work without a mouse.
- Existing Armoury, Warehouse, extraction, loadout warning, equipment ownership, and profile-isolation suites remain green.

### Final gates

Before integration, each increment runs proportionate focused suites. The final increment requires:

1. Cold Godot import with no loader, missing-resource, or parse failure.
2. Focused catalog/generator/stat/equipment/Loot-Lab suites.
3. The complete automated suite with one explicit passing summary.
4. Headless startup smoke with expected boot markers.
5. Save compatibility and profile-isolation tests.
6. Responsive and controller integration runners.
7. A manual developer playtest that equips generated items and confirms action damage, healing, defense, attributes, tooltips, and ledger values change as expected.

## Acceptance criteria

This design is implemented when:

1. A typed deterministic request can generate a complete valid Common-through-Legendary item or one structured failure.
2. All ten rarity ranks are registered, while unavailable ranks cannot leak into normal generation.
3. Rarity patterns control explicit prefix/suffix capacity and guaranteed base implicits remain separate.
4. Approximately 75-100 initial numerical/hybrid affixes are manifest-registered, family-safe, weighted, and tiered across twelve expandable initial tiers.
5. Item level, source, rarity, difficulty/Heat, and diminishing Charisma modify odds without bypassing hard gates.
6. Party smart loot biases equipment bases without controlling affix rolls or eliminating global/off-party drops.
7. Issued items preserve exact values across save/load and future catalog rebalance.
8. Equipped implicits and affixes flow through the canonical stat resolver using stable, explainable source IDs.
9. Universal attributes and the melee/ranged/caster axis work consistently for all current classes and damaging actions.
10. Equipment transitions are atomic, health-safe, and immediately reflected in action estimates, ledgers, and tooltips.
11. The isolated Developer Loot Lab reproduces seeds, analyzes distributions, explains exclusions/weights, and cannot mutate player profiles.
12. Existing item ownership, extraction, Armoury, Warehouse, loadout, tooltip, responsive, controller, and save contracts remain intact.

## Future expansion seams

Later designs can add:

- Conditional, triggered, ailment, summon, and skill-transforming affixes.
- Legendary special-power definitions.
- Raid/crafting Mythic acquisition and scaling.
- Exotic equip limits and rule-breaking behaviors.
- Ascendant evolving stats, Divine party auras, and Eternal world-tier effects.
- Crafting weights, blocked modifiers, rerolls, corruption, fracture, and deterministic recipes.
- Passive-tree nodes that authorize domains or modify explicit weight factors.
- Vendor identities, smart-stock rules, cart extraction, and shop economy modifiers.
- Rarity reward animations, lights, sounds, and slot-machine upgrade/drop presentation.
- Additional attributes, damage types, archetype axes, affix tiers, rarity ranks, and item levels beyond the initial tuning domain.

These systems may add data and policy around the generator and equipment transaction, but they must not introduce a second item identity, bypass the ownership service, reroll existing items during load, or create a competing stat-resolution path.

## Design references

The weighting and exclusion concepts are informed by Path of Exile's modifier tags, groups, and spawn weights; the distinction between ordinary and special high-tier acquisition is informed by Last Epoch; and relative affix-combination weighting is informed by Grim Dawn. Lootun and Party Forge's existing design history motivate the breadth, synergy, and inspectable developer tooling. These are mechanical references only; Party Forge retains its own rarity structure, attributes, classes, terminology, content, and progression rules.
