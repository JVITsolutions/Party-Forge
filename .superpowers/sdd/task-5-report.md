# Plan 4B Task 5 report: version-two profile migration and item persistence

Status: implementation and local verification complete on `feat/plan-4b-item-ownership`. Task 6 was not started.

## Scope and contracts

- Worktree: `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\plan-4b-item-ownership`.
- Base: `4fae7f1` (`feat: add atomic item container transactions`).
- `ProfileState.SCHEMA_VERSION` is now `2` with a versioned empty `ItemRegistry` document, exact profile-stash container documents, and a JSON-safe nonnegative issuance sequence.
- `ProfileCodec` defines exact historical schema-one and current schema-two field sets. Loadable validation accepts only complete v1/v2 documents; current validation accepts only complete v2 documents.
- Current storage validation constructs a synthetic schema-one `ItemOwnershipState` and decodes it with `GameCatalog.EQUIPMENT_CATALOG` and `GameCatalog.ITEM_FOUNDATION_CATALOG`. Persistent containers must be exact `profile_stash_tab` documents.
- `ProfileMigrator` validates before migration, deep-copies the source, recursively migrates transaction result snapshots, initializes no items or stash, rejects nonempty legacy stash storage with the required stable diagnostic, and verifies a normalized current round trip.
- `ProfileStore.save_profile()` remains current-only. A v1 load promotes a current-validated v2 candidate through `AtomicJsonStore` using the loadable validator, then performs a current-only primary reload before returning success.
- `ProfileMigrationResult` and `ProfileLoadResult` expose migration/source metadata. Failed migration and promotion results expose no partial profile.

## RED evidence

Command:

```powershell
& $godot --headless --path $project --quit-after 180 --script res://tests/focused_test_runner.gd -- tests/unit/test_profile_item_schema_migration.gd tests/unit/test_profile_state.gd tests/unit/test_atomic_profile_store.gd tests/unit/test_profile_manager.gd tests/unit/test_profile_mutation_service.gd
```

The accepted pre-implementation run exited `1` with `TEST_SUMMARY: FAIL (15 failures)`. Failures proved the requested missing behavior: no profile migrator script, no `item_records` or `next_item_sequence` state, no loadable/current validators, no catalog-backed item/stash rejection, no sequence rejection, and no validator available to construct either atomic migration fixture.

An earlier probe produced missing-class parse diagnostics and an unreliable runner exit. It was rejected as pass/RED evidence; the tests were guarded so the accepted RED was an assertion-level exit `1` with a complete summary.

## Migration and validation coverage

- The captured complete schema-one fixture includes every historical field, gold `77`, passive allocations and visibility, unlocks, owned character data, run history/resumable run data, and one applied transaction whose `result_profile` is a complete schema-one snapshot.
- Migration proves all existing values survive, the root and nested snapshot become schema two, each receives `{"schema_version": 1, "items": []}`, stash remains empty, issuance starts at zero, and the source dictionary and its serialized text remain unchanged.
- A nonempty legacy stash fails exactly with `PARTY_FORGE_PROFILE_MIGRATION_ERROR field=stash_tabs reason=unsupported legacy storage`, returns no profile, and leaves the input unchanged.
- Historical/current top-level missing and extra keys fail closed. A nested result snapshot using a different schema from its containing document also fails closed.
- Current validation accepts a complete catalog-backed item and exact sparse stash placement, returns defensive item/container copies, and rejects an unknown equipment base, a non-stash persistent container, negative/unsafe/fractional/string issuance sequences, and malformed field types.
- Ordinary current loads report `migrated = false` and `source_schema_version = 2`. Normal saves reject a typed schema-one state without changing current primary bytes.

## Atomic promotion coverage

- Failed injected promotion starts with valid schema-one primary and backup generations, returns no partial profile, and preserves both primary and verified backup bytes exactly.
- Successful promotion writes a schema-two primary, reports `migrated = true` / source schema `1`, and retains the displaced schema-one primary as the backup byte-for-byte.
- Existing corrupt-primary recovery, exact promoted-document verification, rollback, cleanup-debt, profile manager, and mutation/idempotency suites remain green.

## Verification evidence

The final hermetic import used worktree-local `APPDATA` and `LOCALAPPDATA`. It exited `0`; all 28 captured lines were scanned and contained zero script, parse, loader, engine-error, or warning markers.

The final focused profile batch exited `0` with:

```text
TEST_SUMMARY: PASS (0 failures)
```

All 54 captured lines were scanned with zero `TEST_FAILURE`, `SCRIPT ERROR`, `Parse Error`, `Failed to load`, or `No loader found` markers. Its warnings/errors are intentional recovery and filesystem-failure fixtures asserted by the existing suites.

The final hermetic full suite exited `0` with:

```text
TEST_SUMMARY: PASS (125 suites)
```

All 522 captured lines were inspected programmatically. There were zero `TEST_FAILURE`, `SCRIPT ERROR`, `Parse Error`, `Failed to load`, or `No loader found` markers. The 48 intentional negative-path `ERROR` lines and six warnings match the established Task 4 baseline.

## Hygiene and concerns

- The separate `ProfileIndex` schema-one literal in `test_profile_manager.gd` was intentionally retained; it is not a profile-document fixture.
- Verification generated five untracked test `.uid` sidecars: the new migration suite and four existing Plan 4B item suites. Only those test sidecars were removed. The two production-script UIDs remain scoped artifacts.
- `git diff --check` is clean. No open Task 5 production concern is known.

## Review correction addendum

This addendum supersedes the earlier promotion description above. The corrected
contract base is `28e3c91` (`docs: keep profile migration verification atomic`).
`AtomicJsonStore.save_document()` now validates candidate, temporary, and
promoted bytes with the current-schema validator while validating pre-existing
primary and backup generations with an optional loadable-schema validator.
`ProfileStore` supplies both validators and no longer performs a post-commit
reload after the atomic store has released rollback generations.

The accepted correction RED exited `1` with `TEST_SUMMARY: FAIL (18 failures)`.
It exposed non-canonical recursively migrated transaction snapshots (legacy key
order and JSON float representations), promoted candidates not verified as
current inside the atomic transaction, traversal-like caller IDs accepted before
path construction, and a requested/loaded profile-ID mismatch accepted with
filesystem mutation.

A strict-registry mutation temporarily bypassed decoding when the item list was
empty. `test_profile_state.gd` exited `1` with `TEST_SUMMARY: FAIL (5 failures)`,
including the new wrong-registry-schema and extra-registry-field assertions. The
mutation was removed. A second mutation temporarily omitted the optional
existing-generation validator from the migration call. The atomic profile suite
exited `1` with `TEST_SUMMARY: FAIL (11 failures)`, rejecting ordinary schema-one
promotion, promoted-current verification, recovered schema-one backup migration,
and failed-promotion recovery/artifact/loadability invariants. That mutation was
also removed.

The corrected migration rebuilds every applied-transaction `result_profile`
through the current codec, including deterministic field order and integer
representation. The load boundary validates the caller ID before path
construction and rejects a loaded document whose internal ID does not equal the
requested ID before any promotion write. New recovery coverage starts with a
corrupt primary and valid schema-one backup and proves both successful migration
with a preserved corrupt artifact and injected-promotion failure with a still
loadable schema-one generation.

Final hermetic correction gates used worktree-local `APPDATA` and `LOCALAPPDATA`:

- Import: exit `0`, 39 captured lines, zero script/parse/loader/engine-error
  markers. Four warnings reported cache recreation of the verification-only test
  UID sidecars removed below.
- Required five-suite profile batch: exit `0`, 70 captured lines,
  `TEST_SUMMARY: PASS (0 failures)`, zero test-failure/script/parse/loader
  markers. Its one error and seven warnings are intentional corrupt-file,
  rollback, and filesystem-failure fixtures.
- Full suite: exit `0`, 538 captured lines, `TEST_SUMMARY: PASS (125 suites)`,
  zero test-failure/script/parse/loader markers. Its 48 errors are intentional
  negative-path fixtures; its eight warnings comprise the established warning
  fixtures plus the two new corrupt-primary recovery cases.

Only the five untracked test `.uid` sidecars recreated by import were removed.
Task 6 was not started. No open Task 5 production concern is known.
