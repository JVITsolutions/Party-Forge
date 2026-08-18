# Whole-Number Critical Chance Design

## Goal

Make critical strike chance read and behave as a player-facing whole-number percentage everywhere. A character with the universal 5% base critical chance who equips an item granting +5% critical strike chance must resolve to 10% critical strike chance.

## Core Rule

Critical strike chance remains a normalized ratio internally: 5% is stored as `0.05`, 10% as `0.10`, and the existing 75% cap remains `0.75`. Combat probability code continues consuming that ratio. Player-facing authoring and presentation use whole percentage points.

The core stat definition owns these rules:

- Default value: `0.05` (5%).
- Display precision: zero decimal places.
- Resolved values: snapped to `0.01` increments before publication.
- Existing minimum and 75% maximum behavior remains unchanged.

Class-specific overrides remain authoritative. For example, a class authored at `0.10` still starts at 10%, not 15%.

## Item Generation

Critical-strike-chance item rolls are generated in `0.01` steps. The item effect definition gains an optional roll step with a default of no quantization so unrelated stats retain their current continuous behavior. Every production affix effect that modifies `crit_chance` opts into a `0.01` roll step.

The deterministic generator still selects the same affix and tier from the same seed. It first computes the existing quality-weighted value, then snaps that value to the declared roll step and clamps it to the tier bounds. The snapped value is the value persisted on the item and used by combat.

Existing saved items are not rewritten destructively. Their resolved critical chance is normalized by the stat definition, and their displayed value is formatted as a whole percentage.

## Presentation

The stat definition is the source of truth for ratio formatting. A flat modifier to a ratio stat is presented as percentage points rather than as a raw decimal or the technical word `flat`.

Required examples:

- Core stat row: `Critical Strike Chance 5%`.
- Item effect: `+5% Critical Strike Chance`.
- Advanced item range: `Range: 4%-6%`.
- Equipment comparison: `▲ +5% Critical Strike Chance — improved`.
- Stat detail base source: `Base: 5%`.
- Stat detail item source: `Ring Of Mercy — Ring Of Mercy Legacy: +5%`.

The item projection layer receives the `StatDefinition` it already looks up and uses it for the effect text and advanced range text. The ledger provider enriches each source row with the definition-formatted value, and the stats page renders that value instead of reformatting raw floats independently.

## Scope

This change applies only to critical strike chance and the generic opt-in item roll-step mechanism needed to express it. It does not change critical strike multiplier, other chance stats, the 75% cap, class-specific critical chance overrides, upgrade values, damage formulas, rarity selection, tier selection, or affix weights.

## Validation

Automated RED-GREEN coverage must prove:

- The default critical strike chance is 5% and a +5% modifier resolves to 10%.
- Resolution and display use whole percentage points.
- A deterministic critical chance affix roll is persisted on a `0.01` step and stays within its tier bounds.
- Item effect text and advanced ranges use whole percentages.
- Stat rows and source breakdowns never expose raw values such as `0.05`, `0.0111 flat`, or `1.1%`.
- Existing comparison direction and color semantics remain intact.
- The focused suites, affected integration coverage, and one isolated cold-import full suite pass without parser, loader, script, RID, ObjectDB, or resource-leak markers.

Manual 1080p visual acceptance will be repeated after the automated correction and will include the item tooltip and Stats page shown together where practical.
