# Task 5 Report: Living Forge Upgrade Offer and Application Contracts

Status: implementation and scoped verification complete on `feat/living-forge-combat-loop-ui`. Task 6 UI work was not started.

## Scope and boundary

- Exact starting head: `880cd96f5c7e4a5fd77b33d8023996ead14ce4b2`.
- Added copy-owned `UpgradeOfferProjection` values and `UpgradeOfferProjectionService` adapters over the existing authored and foundational presentation authorities.
- Added `UpgradeChoice.ApplicationRoute` with exact `DIRECT`, `RECIPIENT_CONFIRMATION`, and `CONTEXT_CONFIRMATION` classification. Recruit is context confirmation, recipient-requiring authored choices are recipient confirmation, and every other current kind is direct.
- Added mutation-free `LevelUpApplicationPolicy` and typed `LevelUpApplicationResult`. Policy requires an authored choice to retain the exact current catalog definition object, re-resolves recruitment from the supplied current `GameCatalog`, validates exact recipients and capacity, and translates stale or rejected authority into complete player-readable sentences.
- Projection content does not store `PartyManager`, `UpgradeDefinition`, class definitions, or other mutable authority. Stable identity and semantic tags remain non-display values.
- Authored rarity is schema-backed, including default `COMMON` as `Common`. Foundational choices have no rarity. Unavailable optional icons remain empty.
- Targeted authored offers retain the authored effect summary before recipient selection. Exact before/after values remain exclusively supplied after recipient selection by `UpgradeApplicationService.preview_values()`.
- Recruitment presentation is restricted to catalog class display name, catalog role, and catalog-resolved trait names. It adds no inferred stats, equipment, synergy, exact delta, or pseudo-rank.
- Excluded: Task 6 panel/components/state machine, tactics/gambits, push, merge, plan edits, and progress-ledger edits.

## Strict TDD evidence

All Task 5 tests were authored before production changes. The first clean evidence-bearing RED command was:

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_upgrade_offer_projection.gd tests/unit/test_level_up_application_policy.gd tests/unit/test_upgrade_choices.gd tests/unit/test_upgrade_presentation.gd tests/unit/test_foundational_upgrade_presentation.gd
```

- Exit: `1`.
- Marker: `TEST_SUMMARY: FAIL (10 failures)`.
- Failures were limited to missing typed projection/result/policy scripts, missing `application_route`, and the previous presentation dictionaries lacking adapter metadata. No unrelated existing contract failed.

After minimum production implementation, the same exact five-suite command produced:

- Exit: `0`.
- Marker: `TEST_SUMMARY: PASS (0 failures)`.

Coverage includes deterministic copy ownership, build-all order, disabled semantics, all five current choice kinds, exact route table, visual-field route independence, default and authored rarity, foundational omission, catalog-only recruitment consequences, targeted summary omission of pre-recipient deltas, post-recipient exact preview values, and null/stale/capped/full/ineligible/valid mutation-free policy evaluation.

## Review repair evidence

The bounded review repair began at `f0edccf119c8654c21dfd61513c721c4f91f9682`. Tests were expanded before repair production edits, and the exact five-suite command above produced:

- Exit: `1`.
- Marker: `TEST_SUMMARY: FAIL (31 failures)`.
- Failures were limited to the newly required fail-closed projection authority checks, same-object authored definition validation, complete recruitment templates, and actionable recipient rejection text. Determinism and deep mutation-purity assertions already passed.

The minimum repair then made projection construction fail closed before kind-specific presentation when party, catalog, or current target authority is unavailable or mismatched. Authored application now rejects null or same-ID stale definitions with `This offer is no longer available.` and uses only the choice's existing application route. Recruitment effect/scope text now uses complete catalog-backed sentences, and supported eligibility diagnostics map to actionable player text.

The expanded matrix covers all five typed projection kinds, null authority, every foundational target family, same-ID stale authored definitions, repeated/reversed/permuted build order and ownership, valid and stale class-rank and trait applications, capped party-stat and authored upgrades, vanished or ineligible recipients, recruit availability/capacity, broad relevant party-state snapshots, revision/cache state, and signal-count equality before and after every policy result. The exact five-suite command then produced `TEST_SUMMARY: PASS (0 failures)` with exit `0`.

The already-running Godot editor/console process pair remained present during the repair runs but did not interfere with the focused runner, import, UID classification, or retained gates.

## Retained verification

- Related progression focused suites (`test_upgrade_definition`, `test_upgrade_catalog`, `test_upgrade_application`, `test_character_upgrade_integration`, `test_level_up_targeting_ui`, `test_level_up_reveal_controller`, and `test_upgrade_tooltip_ui`): `TEST_SUMMARY: PASS (0 failures)`; exit `0`.
- Task 4 focused HUD/Main/PartyManager suites: `TEST_SUMMARY: PASS (0 failures)`; exit `0`.
- Task 4 party scale/geometry: `COMBAT_HUD_PARTY_SCALE_SUMMARY: PASS`; exit `0`.
- Task 4 input routes: `COMBAT_HUD_INPUT_SUMMARY: PASS`; exit `0`.
- Progression arena retention: `PROGRESSION_ARENA_PROFILE_IMMUTABLE ... values_equal=true bytes_equal=true`, followed by `PROGRESSION_ARENA_SMOKE_SUMMARY: PASS`; exit `0`.

The retained unit suites emit their established negative-path diagnostics while finishing with exact PASS markers. The Task 5 exact gate itself completed without parser, loader, script-error, ObjectDB, RID, retained-resource, or allocator diagnostics.

## Import, UID, and integrity evidence

- Full headless editor import exited `0`.
- Same-process `Resolve-GeneratedUidState` classification retained exactly six intended new UIDs:
  - `scripts/ui/level_up/upgrade_offer_projection.gd.uid`
  - `scripts/ui/level_up/upgrade_offer_projection_service.gd.uid`
  - `scripts/progression/level_up_application_result.gd.uid`
  - `scripts/progression/level_up_application_policy.gd.uid`
  - `tests/unit/test_upgrade_offer_projection.gd.uid`
  - `tests/unit/test_level_up_application_policy.gd.uid`
- Import regenerated unrelated sidecars only for already tracked scripts; the exact classifier removed those sidecars and preserved the six Task 5 UIDs.
- `git diff --check` exited `0`.
- Baseline `4c4acb5e001b0cfbb64aa06358b42b7ed9a67eb9` remains an ancestor.
- Historical `.superpowers/sdd/task-5-report.md` remains byte-identical at blob `a1198174f36ce404595bac0107040bd6f1b5a243`.

## Concerns and handoff

- `LevelUpApplicationPolicy` is preflight only. Task 6 must keep `UpgradeApplicationService` and Main as mutation authority and must re-evaluate before commit.
- `icon_id` intentionally remains empty until an authoritative normalized icon mapping exists; Task 6 may render its established placeholder without inventing identity.
- No design blocker remains inside Task 5 scope.
