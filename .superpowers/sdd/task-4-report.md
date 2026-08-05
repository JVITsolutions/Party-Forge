# Plan 4B Task 4 report: atomic item container transactions

Status: implementation, independent-review corrections, and local verification complete on `feat/plan-4b-item-ownership`. Task 5 was not started.

## Scope and contracts

- Worktree: `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\plan-4b-item-ownership`.
- Base: `2c716e9` (`docs: define atomic item transaction contract`).
- Added schema-one `ItemTransactionRequest`, stable `ItemTransactionResult.Code`, defensive `ItemTransactionJournal`, and `ItemContainerTransactionService`.
- Added only underscore-prefixed mutation helpers to `ItemRegistry`, `ItemSlotContainer`, and `ItemOwnershipState`; registry/container dictionaries remain private and public ownership projections remain defensive.
- Requests serialize the ten required fields in exact order and fingerprint the complete compact canonical JSON document.
- The service validates request shape before journal lookup, copies the original ownership state, performs exactly one candidate mutation, validates the complete candidate, and records only successful candidates.
- Create and remove update the registry and exact slot in one candidate. Move and swap preserve the registry item documents exactly and never compact placement.

## RED evidence

Command:

```powershell
& $godot --headless --path $project --quit-after 120 --script res://tests/focused_test_runner.gd -- tests/unit/test_item_container_transactions.gd
```

The pre-implementation run produced the intended missing-feature parse diagnostics: `ItemContainerTransactionService`, `ItemTransactionRequest`, `ItemTransactionResult`, and `ItemTransactionJournal` were undeclared. As in Task 3, Godot exited `0` without a `TEST_SUMMARY` because the missing suite could not instantiate. That exit code was rejected as pass evidence; the missing-type diagnostics are the RED evidence.

## Transaction matrix and invariants

- Success coverage: create-and-place, move-to-empty, swap-occupied, and sandbox-remove all snapshot the original serialized state, prove byte-equivalent source state, and assert exact sparse placement. Move and swap compare complete registry item documents before and after.
- Failure coverage: all stable non-success codes are asserted, including malformed/self-referential requests, unknown owner/container, source and destination bounds, stale/empty sources, empty swap destination, occupied create/move destinations, duplicate instance, duplicate reference, invalid create/registry items, replay, and collision.
- Every ordinary failure asserts `next_state == null`, no journal entry, and byte-equivalent original state. Replay and collision separately assert original-state byte equivalence plus their required journal behavior.
- Idempotency coverage proves successful same-fingerprint replay returns `TRANSACTION_REPLAY`, `duplicate = true`, and the original recorded complete state. A changed fingerprint returns `TRANSACTION_COLLISION`, returns no state, and cannot replace the journal record.
- Failed-first-attempt coverage proves a source-mismatch is not recorded and the same transaction ID/request succeeds after preconditions change.
- Defensive-copy coverage mutates the constructor source item, request item accessor, canonical request document, result state, journal entry, journal entries map, journal copy, and replay result. No mutation reaches the owned request/result/journal/state data.
- Fingerprint coverage proves exact top-level field order, equality with `JSON.stringify(canonical_document()).sha256_text()`, equivalent item-copy determinism, and nested dictionary insertion-order independence.
- Precedence coverage proves request shape before journal lookup, owner before container/bounds, container before bounds, registry integrity before source identity, source identity before destination occupancy, destination bounds, empty-swap mapping, occupied-create mapping, and duplicate-instance before destination occupancy.

## Verification evidence

The focused transaction, ownership-state, and item-codec regression batch was run twice, with `PARTY_FORGE_TRANSACTION_CASE_ORDER=forward` and then `reverse`. Both runs exited `0` and emitted identical markers:

```text
ITEM_TRANSACTION_MATRIX: PASS
TEST_SUMMARY: PASS (0 failures)
```

A fresh hermetic import using worktree-local `APPDATA` and `LOCALAPPDATA` exited `0`; all 21 captured lines were scanned and there were zero script, parse, loader, or engine error markers.

The fresh hermetic full suite exited `0` with:

```text
ITEM_TRANSACTION_MATRIX: PASS
TEST_SUMMARY: PASS (124 suites)
```

All 522 captured lines were inspected programmatically. There were zero `TEST_FAILURE`, `SCRIPT ERROR`, `Parse Error`, `Failed to load`, or `No loader found` markers. The run emitted 48 intentional negative-path `ERROR` lines and six warnings from existing tests/shutdown behavior, including the established `18 ObjectDB` leak warning and five resources still in use; none originated from the new item transaction code.

## Hygiene and concerns

- `git diff --check` was clean before final staging.
- Import/full-suite verification generated four untracked test `.uid` sidecars: the new transaction suite and the three existing Plan 4B item suites. Only those verification-created test UIDs were removed. The four production-script UIDs remain scoped artifacts.
- No open Task 4 production concern is known. The focused runner can still exit `0` after a suite-load parse failure, so accepted evidence always requires both the PASS marker and a complete output scan.

## Independent Task 4 review corrections

The sequential independent review identified one Important and two Minor findings. All three were corrected without broadening the public API or starting Task 5:

- State-null and request-owner/state-owner validation now occur before journal lookup. An exact-fingerprint request routed with a different ownership state returns `UNKNOWN_OWNER`, exposes no recorded state, is not marked duplicate, and changes neither owner state nor journal. An exact replay with null state returns `INVALID_REQUEST` without exposing the journal snapshot.
- The reordered focused run now uses a fixed permutation of all seven complete scenario groups: request schema, four successes, failure matrix, replay/collision, failed retry, defensive copies, and validation precedence. Its failure matrix also uses a fixed non-reversal permutation. The forward and reordered runs execute every group exactly once and retain identical output markers.
- Create and sandbox-remove success fixtures now contain unrelated records in both source and destination containers. They assert the unrelated item documents and sparse slot documents remain byte-exact; remove also proves the registry loses only the targeted record.

Review RED was targeted and exited `1` with exactly five assertions. Before the service correction, cross-owner and null-state exact replays returned `TRANSACTION_REPLAY` and exposed the recorded state; the cross-owner result was also incorrectly marked duplicate. Moving the two state-routing checks before fingerprint/journal lookup made the same focused suite exit `0` with `ITEM_TRANSACTION_MATRIX: PASS` and `TEST_SUMMARY: PASS (0 failures)`.

Targeted mutation evidence temporarily incremented every unrelated create/remove registry item's level while leaving candidates structurally valid. The focused suite exited `1` with exactly four byte-preservation failures: unrelated source and destination records for create, and unrelated source and destination records for remove. The mutation was then removed through `apply_patch`; no mutation code remains.

Final review verification:

- Combined transaction, ownership-state, and item-codec forward run: exit `0`, zero unexpected markers, `ITEM_TRANSACTION_MATRIX: PASS`, `TEST_SUMMARY: PASS (0 failures)`.
- The same combined suites in deterministic reordered mode: exit `0`, zero unexpected markers, and identical markers.
- Fresh hermetic import: exit `0`; all 32 captured lines were scanned with zero script, parse, loader, or engine error markers. Verification recreated the transaction-test UID plus the three known missing existing item-test UIDs; only those four generated test sidecars were removed.
- Fresh hermetic full suite: exit `0`, `TEST_SUMMARY: PASS (124 suites)`. All 522 lines were scanned with zero `TEST_FAILURE`, `SCRIPT ERROR`, `Parse Error`, `Failed to load`, or `No loader found` markers. The established 48 intentional negative-path errors, six warnings, 18 leaked ObjectDB instances, and five resources still in use remain unchanged baseline noise.
