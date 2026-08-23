# Whole-Number Critical Chance and Multi-Crit Design

## Goal

Make critical strike chance a whole-number percentage that begins at a meaningful universal baseline and scales into an uncapped incremental-game mechanic. A character with 5% base critical chance who equips an item granting +5% critical strike chance resolves to 10%. Critical chance above 100% creates additional, independently processed critical damage instances without firing additional projectiles.

## Stat Rules

Critical strike chance remains a normalized ratio internally: 5% is stored as `0.05`, 105% as `1.05`, and 1150% as `11.50`. Combat code consumes that ratio while player-facing authoring and presentation use whole percentage points.

The core stat definition owns these rules:

- Universal default value: `0.05` (5%).
- Display precision: zero decimal places.
- Resolved values: snapped to `0.01` increments before publication.
- Critical chance has no normal gameplay maximum.

Rogue, Marksman, and Warlock have a class-specific total base critical chance of `0.10` (10%). Their override replaces the universal default rather than adding another ten points or preserving older higher values. All other current classes inherit the universal 5% baseline.

Critical strike multiplier remains a single multiplier applied to every critical damage instance. For example, 250% critical strike multiplier makes each critical instance deal 2.5 times the normal damage. It does not create additional projectiles, damage instances, or multiplier rolls.

## Whole-Number Item Rolls

Critical-strike-chance item rolls are generated in `0.01` steps. The item effect definition gains an optional roll step whose default disables quantization so unrelated stats retain their current continuous behavior. Every production affix effect modifying `crit_chance` opts into a `0.01` step.

The deterministic generator still selects the same affix and tier from the same seed. It first computes the existing quality-weighted value, then snaps that value to the declared roll step and clamps it to the tier bounds. The snapped value is persisted on the item and used by combat.

Existing saved items are not rewritten destructively. Their resolved critical chance is normalized by the stat definition, and their displayed value is formatted as a whole percentage.

## Multi-Crit Resolution

One attack or projectile impact performs one critical-count roll and produces an ordered bundle of damage instances:

- Below 100% critical chance, the attack produces one damage instance. It is critical if the normal chance roll succeeds and otherwise remains a normal hit.
- At 100% or more, `floor(critical_chance)` critical instances are guaranteed. The fractional remainder receives one independent deterministic roll for one additional critical instance.
- At 105%, the result is one guaranteed critical instance plus a 5% chance for a second.
- At 1150%, the result is eleven guaranteed critical instances plus a 50% chance for a twelfth.
- Each critical instance uses the attack's complete normal damage calculation and full critical strike multiplier.
- Each instance that reaches a living target independently triggers on-hit and on-crit processing.
- On-kill processing occurs once when the target first reaches zero health.
- No additional projectile, attack animation, cooldown, targeting operation, or attack-level effect is created.

The bundle records requested, processed, guaranteed, and fractional instance counts; ordered per-instance results; whether each instance struck a living target or was overkill-only; total overkill; and safety-ceiling diagnostics.

## Safety Ceiling

One attack processes at most 10,000 multi-crit instances. Critical chance itself remains uncapped so builds and the Stats page preserve their real value.

If an attack requests more than 10,000 instances:

- Damage and proc processing stop at 10,000.
- Developer diagnostics record requested and processed counts and explicitly identify ceiling truncation.
- The character's build and stored critical chance are not altered.
- The ceiling can be raised later after performance testing.

## Death and Overkill

When an instance kills the target, damage and on-kill behavior resolve once. Every already-rolled instance remaining in the bundle still contributes its full would-be damage to overkill, including the full critical multiplier, but those post-death instances do not trigger on-hit, on-crit, life steal, ailments, or additional on-kill effects.

Example: a target has 100 health and an attack produces three 60-damage critical instances. The first leaves 40 health, the second kills with 20 excess damage, and the third contributes its full 60 damage. The recorded overkill total is 80.

The target exposes an immutable overkill record for exactly two seconds from the killing blow. It contains the killing blow's excess plus all remaining multi-crit damage. The initial implementation only records and expires this value; future effects may read it to damage nearby enemies. The buffer is not persisted across saves or runs.

## Presentation

The stat definition is the source of truth for ratio formatting. A flat modifier to critical chance is presented as percentage points rather than a raw decimal or the technical word `flat`.

Required examples:

- Core stat row: `Critical Strike Chance 5%`.
- Crit-focused class row: `Critical Strike Chance 10%`.
- Item effect: `+5% Critical Strike Chance`.
- Advanced item range: `Range: 4%-6%`.
- Equipment comparison: `▲ +5% Critical Strike Chance — improved`.
- Stat detail base source: `Base: 5%`.
- Stat detail item source: `Ring Of Mercy — Ring Of Mercy Legacy: +5%`.
- Uncapped value: `Critical Strike Chance 1150%`.

All multi-crit damage applies immediately and in deterministic order. Presentation receives the completed bundle and staggers its feedback:

- One critical damage number per critical instance.
- One red hit flash per instance that struck the target while it was alive.
- Post-death instances still show staggered damage numbers using a reserved, distinct overkill style.
- Post-death instances do not produce red flashes.

The final overkill art treatment may be added later, but the presentation event must identify overkill-only numbers now so the style can be changed without altering combat.

The `Multi-Crit` keyword explains critical-chance overflow in tooltips. Developer diagnostics expose requested and processed instances, the fractional roll result, overkill totals, and ceiling truncation.

## Character Sheet Estimates

Damage and DPS estimates must use the same expected-value rules as live combat and must not clamp critical chance to 100%:

- Below 100%, expected damage remains the normal-hit/critical-hit weighted average.
- At or above 100%, expected damage is normal damage multiplied by critical multiplier and expected critical instance count.
- Exactly 100% produces one full critical instance, keeping the estimate continuous at the boundary.

## Scope

This increment changes the critical chance baseline, class-specific Rogue/Marksman/Warlock totals, critical roll presentation and quantization, live damage resolution, proc dispatch, overkill recording, combat estimates, keyword text, diagnostics, and presentation-event contracts.

It does not create final floating-number art, final overkill styling, overkill-spreading abilities, additional projectiles, new item affixes, different rarity/tier/affix weights, or changes to critical strike multiplier values.

## Validation

Automated RED-GREEN coverage must prove:

- Current non-crit-focused classes resolve to 5%; Rogue, Marksman, and Warlock resolve to 10%.
- A +5% modifier applied to the 5% default resolves and displays as 10%.
- A deterministic critical chance item roll is persisted on a `0.01` step and remains within tier bounds.
- Item effects, advanced ranges, comparisons, stat rows, and source breakdowns never expose raw values such as `0.05`, `0.0111 flat`, or `1.1%`.
- Boundaries at 0%, 5%, 99%, 100%, 105%, and 1150% produce deterministic instance counts.
- Values above the 10,000-instance ceiling truncate safely and emit diagnostics without modifying the build.
- Every living-target instance produces its own damage, on-hit, and on-crit processing while creating no extra projectile.
- On-kill occurs once, post-death proc dispatch stops, and all remaining rolled damage contributes to the two-second overkill record.
- The overkill record expires after exactly two seconds and is not persisted.
- DPS estimates match live expected-value rules above and below 100%.
- Focused suites, affected integration coverage, and one isolated cold-import full suite pass without parser, loader, script, RID, ObjectDB, or resource-leak markers.

Manual 1080p visual acceptance will be repeated after automated verification and will include the item tooltip, Stats page, equipment preview isolation, ground-item interaction, and the available temporary multi-crit feedback.
