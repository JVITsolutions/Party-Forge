# Plan 4B Task 7 report: run-context inventory ownership

Status: implementation and local verification complete on `feat/plan-4b-item-ownership`. Task 8 was not started.

## Scope and contracts

- Final parent verified before the Task 7 commit: `580fd29` (`docs: plan leader loadout extraction continuity`).
- `PlayerRunContext.configure()` now builds and validates one context-owned `run-inventory` plus an empty registry before committing any identity, profile, party, progression, journal, or sequence fields.
- Inventory capacity is exactly `5 * profile.inventory_columns`: zero, one, and eight columns materialize `0`, `5`, and `40` slots.
- Every configured context owns an independent `ItemOwnershipState`, `ItemTransactionJournal`, and run issuance sequence starting at zero. Public state and inventory accessors return defensive copies.
- Run create requests require namespace `run:<profile_id>:<run_seed>:<run_player_id>` and the current integral run sequence. Only a successful, nonduplicate create advances the run sequence.
- Exact replays, collisions, failed validation, moves, swaps, and rejected sandbox-only removes consume no create sequence. Journal entries and identical transaction IDs remain isolated between contexts.
- The production run-operation whitelist contains only `create_and_place`, `move_to_empty`, and `swap_occupied`. `sandbox_remove` is rejected before mutation or journaling.
- The source profile and defensive profile snapshot remain byte-equivalent, including persistent `next_item_sequence` and `resumable_run`; run ownership is not persisted.
- Equipment, extraction, ground pickup, run loss, cross-player transfer, persistent resumable-run ownership, and Task 8 remain outside this task.

## RED evidence

Tests were authored before `scripts/run/player_run_context.gd` was changed. The first attempted RED run exposed and corrected a test-only reserved-word parse error; it was rejected as RED evidence and production code remained untouched.

The accepted focused RED command ran:

```text
res://tests/unit/test_run_item_ownership.gd
res://tests/unit/test_player_run_context.gd
res://tests/unit/test_run_context_registry.gd
```

It exited `1` with `TEST_SUMMARY: FAIL (7 failures)`, no parse/script/loader failure, and these exact intended missing-API assertions:

```text
run context exposes defensive item state: expected true
run context exposes its fixed inventory projection: expected true
run context exposes its production item transaction boundary: expected true
run context exposes item state after Task 7: expected true
run context exposes run inventory after Task 7: expected true
registered contexts expose run item ownership: expected true
registered contexts expose fixed run inventories: expected true
```

## Coverage

`test_run_item_ownership.gd` proves:

- exact capacities `0`, `5`, and `40`, stable `run-inventory` identity/kind, and context owner identity;
- cross-context registry/container/profile isolation, including mutation attempts against every returned state, registry, item, container, transaction-result, and profile projection;
- wrong-owner atomic rejection and independent use of the same transaction ID by two contexts;
- exact run namespace, sequence zero, rejection of wrong namespace/future/fractional sequence, and valid retry with the same unjournaled ID;
- sequence advancement only after successful nonduplicate creates, with replay/collision/move behavior retaining the expected next sequence;
- atomic null-request, missing-catalog, malformed-request, and sandbox-remove rejection;
- positive production create, move, and swap behavior, plus proof that rejected remove is unjournaled and cannot destroy the item.

The existing player-context suite now proves failed configuration commits no item state/inventory or usable journal, a valid retry creates one registry/container/journal entry, and replay cannot duplicate the item. The registry suite proves registered contexts retain independent defensive ownership projections.

## GREEN and regression evidence

All final evidence below ran against parent `580fd29` with Godot `4.7.1`, isolated task-specific `APPDATA` and `LOCALAPPDATA`, and exited `0`.

- Task 7 focused batch (three suites): four captured lines, `TEST_SUMMARY: PASS (0 failures)`, zero test/script/parse/loader markers.
- Required run regression batch (Task 7, player context, run registry, reward distribution, experience orb, progression, character progression, and main wiring): eight suites, 88 captured lines, `TEST_SUMMARY: PASS (0 failures)`, zero test/script/parse/loader markers.
- Item-foundation regression batch (container transactions, ownership state, instance codec, persistent storage wrapper, and storage reconciliation): five suites, `ITEM_TRANSACTION_MATRIX: PASS`, `TEST_SUMMARY: PASS (0 failures)`, zero test/script/parse/loader markers.
- Fresh final import: 21 captured lines, exit `0`, zero errors, warnings, script/parse/loader failures, or failed-resource markers.
- Fresh final complete suite: 538 captured lines, exit `0`, zero `TEST_FAILURE`, script, parse, loader, or failed-resource markers, and `TEST_SUMMARY: PASS (128 suites)`.

The complete suite emitted the established 48 intentional negative-path error lines and eight established warning/shutdown lines, matching the pre-Task-7 127-suite baseline and the prior Task 6 evidence. No line originated from the new Task 7 suite or implementation.

## Hygiene and diagnostics

- `git diff --check` is clean before commit.
- The first fresh import generated eight untracked test `.gd.uid` sidecars and warned that cached UIDs were being recreated. Their exact paths were validated as untracked files under `tests/unit`; only those eight verification-created sidecars were removed.
- A concurrent future extraction-plan document was committed separately as `580fd29` and excluded from Task 7 staging.
- No open Task 7 production-code concern is known. The extraction/loadout design remains documentation-only.
