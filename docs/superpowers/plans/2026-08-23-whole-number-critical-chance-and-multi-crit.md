# Whole-Number Critical Chance and Multi-Crit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make critical chance a readable whole-number percentage with a 5% universal baseline, add uncapped independent multi-crit damage instances above 100%, and preserve deterministic combat, loot, ledger, and future proc/presentation contracts.

**Architecture:** Keep normalized ratios in the stat system and make `StatDefinition` the formatting authority. Prepare one immutable `DamagePacket` per attack/projectile impact, including one bounded `MultiCritRoll`; route every target resolution through a run-scoped `CombatResolutionService`. The service captures the target's defensive state once, resolves every instance synchronously with independent dodge/block rolls, emits living-hit/proc and completed-presentation contracts, and stores immutable two-second overkill records after enemy nodes are freed. Existing one-projectile/one-cooldown/one-animation behavior remains unchanged.

**Tech Stack:** Godot 4.7.1, typed GDScript, `.tres` data, `.tscn` scenes, deterministic `CombatRng`, focused unit runners, real-scene integration runners, isolated cold-import acceptance.

## Global Constraints

- Implement only in `feat/playtest-recovery-loot-ui` at `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\playtest-recovery-loot-ui`.
- Preserve the user-owned main editor and the untracked `docs/validation/screenshots/playtest-recovery/` and `docs/verification/2026-08-18-playtest-recovery-and-ground-loot.md` evidence.
- Follow strict RED-GREEN-REFACTOR. Record the expected assertion failure before each production change.
- Store critical chance internally as a normalized ratio: `0.05 == 5%`, `1.05 == 105%`, `11.50 == 1150%`.
- Do not cap or rewrite the character's resolved critical chance. Limit only processed instances to `10_000` per attack/target resolution.
- Multi-crit does not create extra projectiles, attacks, targeting operations, animations, cooldowns, or attack-level effects.
- Resolve gameplay damage synchronously and deterministically. Only the future presentation consumer may stagger damage numbers and flashes.
- Dodge and block are independent per instance. Post-death instances use a frozen defensive snapshot, add only successful resolved damage to overkill, and emit no on-hit/on-crit/life-steal/ailment/additional-kill events.
- Keep legacy direct `DamageResolver.resolve()` available as a one-instance compatibility path for focused callers while production runtime call sites move to `CombatResolutionService.resolve_bundle()`.
- Never update deterministic hashes merely to silence a test. Regenerate, inspect the exact semantic change, then update the expected hash from accepted output.
- Do not implement final floating-number art, final overkill styling, or an overkill-spread ability in this increment.

---

## Task 1: Establish whole-number critical stats, class baselines, and keyword truth

**Files:**

- Modify: `tests/unit/test_stat_catalog.gd`
- Modify: `tests/unit/test_stat_resolver.gd`
- Modify: `tests/unit/test_expanded_class_content.gd`
- Modify: `tests/unit/test_game_catalog.gd`
- Modify: `tests/unit/test_increment2_generator_parity.gd`
- Modify: `tools/create_stat_foundation_data.gd`
- Modify: `tools/class_expansion_rows.gd`
- Modify: `tools/character_upgrade_content_rows.gd`
- Modify: `tools/create_character_upgrade_data.gd`
- Modify: `data/stats/core_stats.tres`
- Modify: `data/classes/rogue.tres`
- Modify: `data/classes/marksman.tres`
- Modify: `data/classes/warlock.tres`
- Modify: `data/keywords/core_keywords.tres`
- Modify: `data/upgrades/cards/precision.tres`
- Modify: `data/upgrades/cards/cutthroat_instinct.tres`

- [ ] **Step 1: Add RED assertions for the universal and specialized baselines**

Assert `crit_chance` has default `0.05`, precision `0`, minimum `0`, no maximum, and snaps `0.0111` to `0.01`. Resolve an ordinary class to `0.05`; resolve Rogue, Marksman, and Warlock to exactly `0.10`. Replace the old Rogue `0.20` expectations in both class-content tables.

Add the `multi_crit` keyword expectation and make the crit-chance explanation state that each full 100% guarantees another critical damage instance and the remainder is rolled independently. Update the canonical keyword count from 81 to 82. Assert critical upgrade tooltips reference `multi_crit` as well as `crit_chance`.

- [ ] **Step 2: Run RED**

```powershell
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
& $godot --headless --path (Get-Location).Path --quit-after 420 --script res://tests/focused_test_runner.gd -- tests/unit/test_stat_catalog.gd tests/unit/test_stat_resolver.gd tests/unit/test_expanded_class_content.gd tests/unit/test_game_catalog.gd tests/unit/test_increment2_generator_parity.gd
```

Expected: non-zero exit only for the old zero default, one-decimal/capped definition, Rogue 20%, missing Warlock override, and missing multi-crit keyword/tooltips.

- [ ] **Step 3: Change the source tables and persisted resources together**

In `create_stat_foundation_data.gd` and `core_stats.tres`, author `crit_chance` as:

```gdscript
_stat(&"crit_chance", "Critical Strike Chance", &"offense", 0.05,
    StatDefinition.ValueFormat.RATIO_PERCENT, 0, true, 0.0, false, 0.0,
    StatDefinition.Visibility.UNIVERSAL)
```

Set Rogue, Marksman, and Warlock total class overrides to `0.10` in both source rows and `.tres` files. Add `multi_crit` to `KEYWORD_ROWS` and the persisted catalog; update `_tooltip_keywords()` to append it whenever an upgrade effect modifies `crit_chance`, then update only the two currently generated critical upgrade resources.

- [ ] **Step 4: Run GREEN and generator parity**

Run the focused command again. Expected: `TEST_SUMMARY: PASS (0 failures)`, all persisted/source catalog parity assertions green, and no parser/loader failure.

- [ ] **Step 5: Commit**

```powershell
git add tests/unit/test_stat_catalog.gd tests/unit/test_stat_resolver.gd tests/unit/test_expanded_class_content.gd tests/unit/test_game_catalog.gd tests/unit/test_increment2_generator_parity.gd tools/create_stat_foundation_data.gd tools/class_expansion_rows.gd tools/character_upgrade_content_rows.gd tools/create_character_upgrade_data.gd data/stats/core_stats.tres data/classes/rogue.tres data/classes/marksman.tres data/classes/warlock.tres data/keywords/core_keywords.tres data/upgrades/cards/precision.tres data/upgrades/cards/cutthroat_instinct.tres
git commit -m "feat: establish whole-number critical chance"
```

---

## Task 2: Quantize critical item rolls and format every player-facing source

**Files:**

- Modify: `tests/unit/test_item_generation_definitions.gd`
- Modify: `tests/unit/test_item_affix_assembler.gd`
- Modify: `tests/unit/test_weighted_loot_content_rows.gd`
- Modify: `tests/unit/test_increment2_generator_parity.gd`
- Modify: `tests/unit/test_item_presentation_projector.gd`
- Modify: `tests/unit/test_item_tooltip_card.gd`
- Modify: `tests/unit/test_resolved_stat_comparison_service.gd`
- Modify: `tests/unit/test_ledger_data_provider.gd`
- Modify: `tests/unit/test_stats_ledger_page.gd`
- Modify: `scripts/items/item_modifier_effect_definition.gd`
- Modify: `scripts/items/item_affix_definition.gd`
- Modify: `scripts/items/item_affix_assembler.gd`
- Modify: `scripts/ui/storage/item_presentation_projector.gd`
- Modify: `scripts/ui/storage/item_tooltip_card.gd`
- Modify: `scripts/ui/ledger/ledger_data_provider.gd`
- Modify: `scripts/ui/ledger/stats_ledger_page.gd`
- Modify: `tools/weighted_loot_content_rows.gd`
- Modify: `tools/build_weighted_loot_content.gd`
- Regenerate and review: the 20 production affix resources whose effects modify `crit_chance`
- Modify only after accepted regeneration: `tests/unit/test_increment2_generator_parity.gd` deterministic weighted-loot hash

- [ ] **Step 1: Add RED roll-step validation and persistence tests**

Add optional `roll_step` expectations to `ItemModifierEffectDefinition`: default `0.0`, finite, nonnegative. For a positive step, assert every tier range contains at least one legal grid point.

Generate `Ring Of Mercy` and `of_precision` with deterministic seeds and assert:

```gdscript
TestAssertions.near(fmod(roll.value, 0.01), 0.0, 0.000001, "crit roll uses one-point grid", failures)
TestAssertions.truthy(roll.value >= bounds.x and roll.value <= bounds.y, "quantized roll remains in tier bounds", failures)
```

Include boundary ranges whose minimum/maximum are not themselves exact grid points so clamp-after-snap cannot persist `0.011` accidentally.

- [ ] **Step 2: Add RED presentation assertions**

Project an existing saved `0.0111` crit roll and a generated `0.05` roll. Assert all surfaces show definition-formatted whole percentage points:

- `+1% Critical Strike Chance`, never `+0.01` or `0.0111 flat`.
- `Range: 1%-2%`, never `0.01-0.02`.
- `▲ +5% Critical Strike Chance — improved`.
- `Base: 5%` and `Ring Of Mercy — Ring Of Mercy Legacy: +1%`.
- final row values never show decimal percent text such as `1.1%`.

- [ ] **Step 3: Run RED**

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_item_generation_definitions.gd tests/unit/test_item_affix_assembler.gd tests/unit/test_weighted_loot_content_rows.gd tests/unit/test_item_presentation_projector.gd tests/unit/test_item_tooltip_card.gd tests/unit/test_resolved_stat_comparison_service.gd tests/unit/test_ledger_data_provider.gd tests/unit/test_stats_ledger_page.gd
```

Expected: failures expose continuous rolls and raw flat formatting; unrelated stat presentation remains green.

- [ ] **Step 4: Implement a generic opt-in grid and definition-owned formatting**

Add `@export var roll_step := 0.0`. Quantize by selecting the nearest legal integer step index between `ceil(minimum / step)` and `floor(maximum / step)`, then multiply by the step. Return a structured generation failure if a positive-step range contains no legal grid point.

Make `weighted_loot_content_rows._effect()` author `0.01` only for `crit_chance`; copy and serialize it in `build_weighted_loot_content.gd`. Do not quantize dodge, block, life steal, or unrelated ratios.

Pass `StatDefinition` formatting through the projected effect and projected range fields. Enrich stat breakdown rows with definition-formatted base/modifier text so `StatsLedgerPage` no longer guesses that every FLAT value is a raw number.

- [ ] **Step 5: Regenerate the weighted content deterministically and inspect scope**

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 900 --script res://tools/build_weighted_loot_content.gd
git diff --stat
git diff -- data/items/affixes/production
```

Expected: semantic changes are limited to the 20 critical-chance affix effect resources plus generator-owned catalog output if its bytes necessarily include those effects. Reject unrelated authored-content drift.

Run the known deterministic parity test, capture the old/new item and trace bytes, verify the only value change is crit-grid snapping, and then update `WEIGHTED_LOOT_COMBINED_SHA256`.

- [ ] **Step 6: Run GREEN and commit**

Run the Task 2 focused command plus `tests/unit/test_increment2_generator_parity.gd`. Expected: `PASS (0 failures)` and no raw crit decimals in the asserted UI surfaces.

```powershell
git add scripts/items/item_modifier_effect_definition.gd scripts/items/item_affix_definition.gd scripts/items/item_affix_assembler.gd scripts/ui/storage/item_presentation_projector.gd scripts/ui/storage/item_tooltip_card.gd scripts/ui/ledger/ledger_data_provider.gd scripts/ui/ledger/stats_ledger_page.gd tools/weighted_loot_content_rows.gd tools/build_weighted_loot_content.gd data/items/affixes/production tests/unit/test_item_generation_definitions.gd tests/unit/test_item_affix_assembler.gd tests/unit/test_weighted_loot_content_rows.gd tests/unit/test_item_presentation_projector.gd tests/unit/test_item_tooltip_card.gd tests/unit/test_resolved_stat_comparison_service.gd tests/unit/test_ledger_data_provider.gd tests/unit/test_stats_ledger_page.gd tests/unit/test_increment2_generator_parity.gd
git commit -m "feat: quantize and present critical item rolls"
```

---

## Task 3: Prepare one bounded multi-crit roll per attack

**Files:**

- Create: `scripts/combat/multi_crit_roll.gd`
- Modify: `scripts/combat/damage_packet.gd`
- Modify: `scripts/combat/prepared_damage_component.gd`
- Modify: `scripts/combat/damage_resolver.gd`
- Create: `tests/unit/test_multi_crit_roll.gd`
- Modify: `tests/unit/test_damage_resolver.gd`
- Modify: `tests/unit/test_action_damage_component_projection.gd`

- [ ] **Step 1: Add deterministic boundary RED tests**

Build attacks at `0%`, `5%`, `99%`, `100%`, `105%`, and `1150%`. Assert:

| Chance | Prescribed draw | Ordered instances |
|---|---:|---|
| 0% | none | one normal |
| 5% | 0.04 / 0.05 | one critical / one normal |
| 99% | 0.98 / 0.99 | one critical / one normal |
| 100% | none | one guaranteed critical |
| 105% | 0.04 / 0.05 | two critical / one critical |
| 1150% | 0.49 / 0.50 | twelve critical / eleven critical |

Assert exact RNG consumption: guaranteed instances consume no draws; the remainder consumes exactly one draw when it is processable. Assert a request above 10,000 reports the uncapped requested count, processes exactly 10,000, marks truncation, and never allocates an array larger than 10,000.

- [ ] **Step 2: Run RED**

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 420 --script res://tests/focused_test_runner.gd -- tests/unit/test_multi_crit_roll.gd tests/unit/test_damage_resolver.gd tests/unit/test_action_damage_component_projection.gd
```

Expected: missing `MultiCritRoll`/packet fields and old one-roll/75%-era behavior fail.

- [ ] **Step 3: Implement immutable roll metadata**

`MultiCritRoll` exposes read-only:

- normalized `crit_chance`;
- `requested_instances`, `processed_instances`, and `guaranteed_instances`;
- `fractional_chance`, `fractional_draw`, `fractional_success`, and whether the draw was consumed;
- `ceiling_truncated`;
- an ordered bounded `critical_flags` copy.

Below 100%, store one normal-or-critical flag. At or above 100%, store guaranteed critical flags plus the successful processable remainder. Keep compatibility packet accessors (`critical`, `crit_draw`) mapped to the first/resulting roll, but make `packet.multi_crit_roll` authoritative.

Prepare base component damage only once per attack as today. Resolve the per-instance critical multiplier later from `PreparedDamageComponent.typed_scaled`; do not resample base weapon damage or create a second attack.

- [ ] **Step 4: Run GREEN and commit**

Run Task 3 focused tests. Expected: exact boundary and RNG assertions pass.

```powershell
git add scripts/combat/multi_crit_roll.gd scripts/combat/damage_packet.gd scripts/combat/prepared_damage_component.gd scripts/combat/damage_resolver.gd tests/unit/test_multi_crit_roll.gd tests/unit/test_damage_resolver.gd tests/unit/test_action_damage_component_projection.gd
git commit -m "feat: prepare bounded multi-crit rolls"
```

---

## Task 4: Resolve one instance against a frozen defense snapshot

**Files:**

- Create: `scripts/combat/damage_defense_snapshot.gd`
- Modify: `scripts/combat/damage_result.gd`
- Modify: `scripts/combat/damage_resolver.gd`
- Modify: `tests/unit/test_damage_resolver.gd`

- [ ] **Step 1: Add RED tests for independent defense draws**

Create a three-instance critical packet and a target with dodge and block. Prescribe alternating draws and assert each instance can independently be:

- dodged;
- hit and blocked;
- hit and unblocked.

Assert two RNG opportunities per non-dodged instance and no block draw for a dodged instance. Assert a fully prevented result has zero final damage and is not proc-eligible.

- [ ] **Step 2: Add RED frozen-state/post-death tests**

Capture defense values once, kill the target after instance two, then resolve instance three without applying health. Change the live target's stat source after capture and prove instance three still uses the captured dodge, defense, incoming multiplier, block chance, and block effectiveness.

Add `DamageResult` evidence fields: instance index, `target_was_alive`, `overkill_only`, `health_before`, `killing_blow`, `excess_damage`, and `proc_eligible`.

- [ ] **Step 3: Run RED**

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 420 --script res://tests/focused_test_runner.gd -- tests/unit/test_damage_resolver.gd
```

- [ ] **Step 4: Split capture, calculation, and health application**

Add `DamageResolver.capture_defense(packet, target, types)` and `resolve_instance(...)`. The latter receives the immutable snapshot plus explicit `apply_health`/`allow_life_steal` flags. It independently rolls dodge and block, derives critical component amounts from `typed_scaled`, and can calculate successful post-death would-be damage without calling `HealthComponent.apply_damage()`.

Keep `DamageResolver.resolve()` as a compatibility wrapper that resolves only the packet's first instance against a newly captured snapshot. Do not let production runtime use this wrapper after Task 6.

- [ ] **Step 5: Run GREEN and commit**

```powershell
git add scripts/combat/damage_defense_snapshot.gd scripts/combat/damage_result.gd scripts/combat/damage_resolver.gd tests/unit/test_damage_resolver.gd
git commit -m "feat: resolve independent defended damage instances"
```

---

## Task 5: Add run-scoped bundle, proc, presentation, and overkill services

**Files:**

- Create: `scripts/combat/combat_damage_instance_event.gd`
- Create: `scripts/combat/damage_bundle_result.gd`
- Create: `scripts/combat/overkill_record.gd`
- Create: `scripts/combat/overkill_buffer_service.gd`
- Create: `scripts/combat/combat_resolution_service.gd`
- Create: `tests/unit/test_overkill_buffer_service.gd`
- Create: `tests/unit/test_combat_resolution_service.gd`
- Modify: `tests/unit/test_health_component.gd`

- [ ] **Step 1: Add RED ordered-bundle and proc-contract tests**

Resolve a `3 x 60` critical bundle into a 100-health target. Assert immediately after the call:

- all three results exist in order;
- health is zero;
- two living-target events are recorded;
- two on-hit and two on-crit signals fire;
- one target-killed signal fires;
- the third result is `overkill_only` and emits no hit/crit/life-steal signal;
- one completed presentation bundle contains three damage-number events, two flash-eligible events, and one distinct overkill-only event;
- total overkill is `80`.

Add a mixed dodge/block post-death case and assert only successful resolved would-be damage enters overkill.

- [ ] **Step 2: Add RED exact-expiration tests**

Record the killing bundle in `OverkillBufferService`; assert it remains readable at `1.999` seconds, expires at exactly `2.000`, and is not included in any profile/run save codec. Replace records atomically when a target identity is reused.

- [ ] **Step 3: Run RED**

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 420 --script res://tests/focused_test_runner.gd -- tests/unit/test_combat_resolution_service.gd tests/unit/test_overkill_buffer_service.gd tests/unit/test_health_component.gd
```

- [ ] **Step 4: Implement the synchronous service**

`CombatResolutionService.resolve_bundle(packet, target)` must:

1. validate dependencies and capture target identity, position, health, and defense once;
2. iterate only `packet.multi_crit_roll.critical_flags` in order;
3. call `resolve_instance()` with independent defense rolls;
4. emit `hit_proc_requested` and `crit_proc_requested` only for positive, living-target results;
5. emit `target_killed` once on the first live-to-dead transition;
6. continue post-death calculations without procs/health/life steal;
7. store killing excess plus successful remaining resolved damage in the two-second buffer;
8. emit one immutable completed presentation bundle after gameplay damage is fully resolved;
9. publish a diagnostics snapshot with requested/processed/guaranteed/remainder/truncation/overkill values.

The service owns one `OverkillBufferService` and advances it from `_process(delta)`. Also expose deterministic `advance(delta)` for tests; never use wall-clock time or `await` for expiry.

- [ ] **Step 5: Run GREEN and commit**

```powershell
git add scripts/combat/combat_damage_instance_event.gd scripts/combat/damage_bundle_result.gd scripts/combat/overkill_record.gd scripts/combat/overkill_buffer_service.gd scripts/combat/combat_resolution_service.gd tests/unit/test_overkill_buffer_service.gd tests/unit/test_combat_resolution_service.gd tests/unit/test_health_component.gd
git commit -m "feat: resolve multi-crit bundles and overkill"
```

---

## Task 6: Route every player and enemy damage path through the run service

**Files:**

- Modify: `scenes/game/main.tscn`
- Modify: `scripts/game/main.gd`
- Modify: `scripts/party/party_manager.gd`
- Modify: `scripts/combat/attack_executor.gd`
- Modify: `scripts/combat/projectile.gd`
- Modify: `scripts/combat/area_burst.gd`
- Modify: `scripts/game/spawn_director.gd`
- Modify: `scripts/enemies/enemy_actor.gd`
- Modify: `scripts/enemies/enemy_projectile.gd`
- Modify: `scripts/enemies/spitter.gd`
- Modify: `scripts/enemies/boltcaster.gd`
- Modify: `scripts/dev/combat_sandbox.gd`
- Modify: `tests/unit/test_attack_execution.gd`
- Modify: `tests/unit/test_enemy_typed_combat.gd`
- Modify: `tests/unit/test_main_wiring.gd`
- Modify: `tests/unit/test_final_review.gd`

- [ ] **Step 1: Add RED wiring and one-projectile regressions**

Add a `CombatResolutionService` child to the expected Main scene contract. Assert Main passes the same service instance to `PartyManager` and `SpawnDirector`; spawned player actors, party projectiles, area bursts, enemies, enemy projectiles, boss charge, and boss shockwave all ultimately use it.

Execute an 1150% ranged attack and assert exactly one `PartyProjectile` exists before impact, one impact occurs, and the target bundle contains 11 or 12 critical instances according to the prescribed remainder. Add equivalent melee/area and hostile projectile assertions.

Add a source scan assertion that production combat files contain no direct `DamageResolver.resolve(` call outside `combat_resolution_service.gd` and the documented compatibility wrapper/tests.

- [ ] **Step 2: Run RED**

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_attack_execution.gd tests/unit/test_enemy_typed_combat.gd tests/unit/test_main_wiring.gd tests/unit/test_final_review.gd
```

- [ ] **Step 3: Wire explicit dependencies**

Add the service node beside `PartyManager`. Cache it in Main, configure it from `game_run.combat_rng` and `catalog.damage_types`, and pass it explicitly through existing configure methods. Add optional test-fixture fallback injection only where unit construction requires it; production must never locate the service via group scans, singletons, or static mutable state.

`AttackExecutor` invokes the service directly for melee. `PartyProjectile` and `AreaBurst` carry the same service reference. `SpawnDirector` passes it into `EnemyActor.configure_combat`; Spitter/Boltcaster pass it to `EnemyProjectile`; boss contact/shockwave use `EnemyActor.resolve_attack()` backed by the same service.

- [ ] **Step 4: Run GREEN plus combat integrations**

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_attack_execution.gd tests/unit/test_enemy_typed_combat.gd tests/unit/test_main_wiring.gd tests/unit/test_final_review.gd
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/integration/progression_24_member_runner.gd
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/integration/weighted_loot_production_runner.gd
```

Expected: all combat paths pass, no extra projectile, existing XP/loot/boss-defeat behavior remains once per enemy.

- [ ] **Step 5: Commit**

```powershell
git add scenes/game/main.tscn scripts/game/main.gd scripts/party/party_manager.gd scripts/combat/attack_executor.gd scripts/combat/projectile.gd scripts/combat/area_burst.gd scripts/game/spawn_director.gd scripts/enemies/enemy_actor.gd scripts/enemies/enemy_projectile.gd scripts/enemies/spitter.gd scripts/enemies/boltcaster.gd scripts/dev/combat_sandbox.gd tests/unit/test_attack_execution.gd tests/unit/test_enemy_typed_combat.gd tests/unit/test_main_wiring.gd tests/unit/test_final_review.gd
git commit -m "feat: route runtime damage through multi-crit service"
```

---

## Task 7: Make ledger estimates, developer diagnostics, and presentation contracts truthful

**Files:**

- Modify: `scripts/ui/ledger/action_combat_estimate.gd`
- Modify: `scripts/ui/ledger/action_combat_estimate_service.gd`
- Modify: `scripts/ui/ledger/stats_ledger_page.gd`
- Modify: `scripts/ui/developer_mode_badge.gd`
- Modify: `scripts/game/main.gd`
- Modify: `tests/unit/test_action_combat_estimate_service.gd`
- Modify: `tests/unit/test_stats_ledger_page.gd`
- Modify: `tests/unit/test_developer_mode_badge.gd`
- Modify: `tests/unit/test_main_wiring.gd`

- [ ] **Step 1: Add RED expected-value boundaries**

Assert:

- below 100%: `normal * (1 + chance * (crit_multiplier - 1))`;
- exactly 100%: one full critical instance;
- at/above 100%: `normal * crit_multiplier * (guaranteed + remainder)`;
- 105% reports expected critical instances `1.05`;
- 1150% reports `11.50` and is not clamped to one;
- estimated DPS equals average bundle damage times actions per second.

Expose `expected_critical_instances` and `expected_damage_instances` on `ActionCombatEstimate`. In the Stats page, label the current `Average Hit` as `Average Damage / Use` when a build can produce multiple instances.

- [ ] **Step 2: Add RED developer/presentation diagnostics**

Feed a normal, 105%, overkill, and truncated bundle into the badge. Assert developer mode can show the latest requested/processed count, remainder outcome, overkill, and `TRUNCATED` marker without overwriting the existing ground-loot diagnostics section. Production mode remains hidden.

- [ ] **Step 3: Run RED**

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 420 --script res://tests/focused_test_runner.gd -- tests/unit/test_action_combat_estimate_service.gd tests/unit/test_stats_ledger_page.gd tests/unit/test_developer_mode_badge.gd tests/unit/test_main_wiring.gd
```

- [ ] **Step 4: Implement shared expected-count math and diagnostics projection**

Use one pure helper on `MultiCritRoll` (or a dedicated static expected-count method) so live boundaries and estimates cannot drift. Refactor `DeveloperModeBadge` to retain independent ground-loot and combat diagnostic strings and compose both. Main connects `CombatResolutionService.diagnostics_changed` once per run and clears combat diagnostics on teardown.

Do not instantiate floating labels here. The completed `CombatDamageInstanceEvent` contract already supplies value, critical flag, living/overkill-only state, target identity/position, and ordered index/count for the future staggered presenter.

- [ ] **Step 5: Run GREEN and commit**

```powershell
git add scripts/ui/ledger/action_combat_estimate.gd scripts/ui/ledger/action_combat_estimate_service.gd scripts/ui/ledger/stats_ledger_page.gd scripts/ui/developer_mode_badge.gd scripts/game/main.gd tests/unit/test_action_combat_estimate_service.gd tests/unit/test_stats_ledger_page.gd tests/unit/test_developer_mode_badge.gd tests/unit/test_main_wiring.gd
git commit -m "feat: expose multi-crit estimates and diagnostics"
```

---

## Task 8: Prove live-scene ordering, ceiling safety, and save compatibility

**Files:**

- Create: `tests/integration/multi_crit_combat_runner.gd`
- Create: `tests/integration/multi_crit_performance_runner.gd`
- Modify: `tests/unit/test_item_instance_codec.gd`
- Modify: `tests/unit/test_profile_state.gd` only if required by existing save fixture names
- Create: `docs/verification/2026-08-23-whole-number-critical-chance-and-multi-crit.md`

- [ ] **Step 1: Build a real-scene integration runner**

Attach production Main/combat nodes to the `SceneTree` and await natural frames. Prove:

- a 105% player projectile launches once and produces the prescribed one/two-instance result;
- an 1150% melee hit applies all gameplay damage before the next frame;
- a target death emits reward/defeat/loot once even when later instances add overkill;
- independent dodge/block draws match their per-instance evidence;
- presentation bundle indices remain stable after the enemy is queued for deletion;
- the overkill record remains readable after the enemy node is freed and expires after deterministic two-second advancement.

Do not call `_ready`, `_process`, `_exit_tree`, private resolution methods, or direct enemy `defeat()` from the runner.

- [ ] **Step 2: Add ceiling/performance coverage**

Resolve a 10,000-instance request against a durable test target and a larger truncated request against an identical target. Assert bounded result/event arrays, exact diagnostic counts, finite totals, no build mutation, and a documented headless elapsed-time/memory observation. This is a safety observation, not a rendered gameplay benchmark.

- [ ] **Step 3: Add save compatibility coverage**

Decode a legacy item document containing an off-grid `crit_chance` roll. Assert decoding preserves the raw saved item, stat resolution snaps it non-destructively for combat, and every presentation surface formats it as a whole percentage. Assert the new overkill buffer and combat diagnostics do not appear in encoded profile/resumable-run documents.

- [ ] **Step 4: Run focused and integration GREEN**

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 900 --script res://tests/focused_test_runner.gd -- tests/unit/test_item_instance_codec.gd tests/unit/test_multi_crit_roll.gd tests/unit/test_damage_resolver.gd tests/unit/test_combat_resolution_service.gd tests/unit/test_overkill_buffer_service.gd tests/unit/test_attack_execution.gd tests/unit/test_enemy_typed_combat.gd tests/unit/test_action_combat_estimate_service.gd tests/unit/test_developer_mode_badge.gd
& $godot --headless --path (Get-Location).Path --quit-after 900 --script res://tests/integration/multi_crit_combat_runner.gd
& $godot --headless --path (Get-Location).Path --quit-after 900 --script res://tests/integration/multi_crit_performance_runner.gd
```

Expected: all explicit PASS markers once, no parser/loader/script/leak marker, and 10,000 is the largest processed count.

- [ ] **Step 5: Commit**

```powershell
git add tests/integration/multi_crit_combat_runner.gd tests/integration/multi_crit_performance_runner.gd tests/unit/test_item_instance_codec.gd tests/unit/test_profile_state.gd docs/verification/2026-08-23-whole-number-critical-chance-and-multi-crit.md
git commit -m "test: verify multi-crit runtime boundaries"
```

Stage `test_profile_state.gd` only if it actually changed.

---

## Task 9: Complete isolated acceptance and independent review

**Files:**

- Modify: `.superpowers/sdd/progress.md`
- Modify: `docs/verification/2026-08-23-whole-number-critical-chance-and-multi-crit.md`
- Create only after visual execution: `docs/validation/screenshots/multi-crit/`

- [ ] **Step 1: Run `git diff --check` and exact focused batches**

Repeat Tasks 1-8 focused commands at the final commit. Confirm one `TEST_SUMMARY: PASS (0 failures)` marker per batch and zero forbidden parser/loader/script/RID/ObjectDB/resource-leak markers.

- [ ] **Step 2: Run an isolated cold import and full suite**

Create a clean archive/copy of the exact final commit outside the live worktree and give the command its own temporary `APPDATA` and `LOCALAPPDATA` roots.

```powershell
& $godot --headless --path $coldProject --import
& $godot --headless --path $coldProject --quit-after 2400 --script res://tests/test_runner.gd
& $godot --headless --path $coldProject --quit-after 30
```

Expected: cold import exit 0; complete suite reports at least the prior 202 suites plus the new suites; boot emits `PARTY_FORGE_BOOT_OK` and `PARTY_FORGE_CLASS_SELECTION_READY`; no forbidden failure/leak markers.

- [ ] **Step 3: Run manual 1080p visual acceptance when the user is available**

Validate:

- Fighter/default class shows 5%; Rogue, Marksman, and Warlock show 10%.
- Ring effects/ranges/stat sources show whole percentages and item comparisons retain green/red deltas.
- Equipment preview remains isolated; ground-item pickup and tooltip dismissal remain correct.
- Available temporary multi-crit feedback does not fire extra projectiles and remains readable enough for prototype QA.

Do not claim final floating-number or overkill art acceptance; those are deliberately out of scope.

- [ ] **Step 4: Request independent specification and code-quality review**

Give the reviewer the approved spec, this plan, commit range, exact test logs, and preserved dirty-state list. Require severity-labeled findings and explicit checks for:

- per-instance dodge/block independence;
- post-death no-proc rule and successful-only overkill;
- one reward/kill/projectile;
- 10,000 ceiling without build mutation;
- generator/source/persisted parity;
- legacy save compatibility;
- no unrelated untracked-evidence mutation.

- [ ] **Step 5: Record truthful completion state**

Update the verification report and `.superpowers/sdd/progress.md` with exact commit IDs, commands, results, independent review, and any remaining manual visual gate. Do not mark the increment complete if the cold suite or required review is missing.

```powershell
git add .superpowers/sdd/progress.md docs/verification/2026-08-23-whole-number-critical-chance-and-multi-crit.md
git commit -m "docs: verify whole-number multi-crit increment"
```

Do not stage the pre-existing playtest-recovery evidence. Stage new screenshots only after they are actually captured and reviewed.
