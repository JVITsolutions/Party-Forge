# Task 8 Living Forge Terminal Snapshot Report

## Scope

- Exact base: `11ceb76585faf7848ae6ad92a60a74ea2129ef04`.
- Task: capture immutable terminal run truth before cleanup.
- Excluded: Task 9 extraction picker/UI, terminal orchestration/recovery, tactics, push, merge.
- Historical `.superpowers/sdd/task-8-report.md` remains byte-for-byte blob `f9ab690ada4820c35ec225c152400ead751f24dc`.

## TDD RED

Production files were untouched when the new Task 8 suite first ran.

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 420 --script res://tests/focused_test_runner.gd -- tests/unit/test_run_terminal_snapshot.gd
```

- Exit: `1`.
- Marker: `TEST_SUMMARY: FAIL (4 failures)`.
- Classification: only the four approved missing types failed: `RunTerminalPartyMemberSnapshot`, `RunTerminalSnapshot`, `RunTerminalSnapshotResult`, and `RunTerminalSnapshotBuilder`.
- No unrelated parser or loader failure was present in the accepted RED run.

The later cold-JSON test also failed first because Task 7 correctly accepted JSON-safe integral floats but retained them in nested party rows. The repair normalizes only the already-strictly-decoded, Task-8-owned source copy; the final live and cold terminal documents are structurally exact.

## Implemented Contract

- `RunTerminalPartyMemberSnapshot` stores only positive member identity, nonblank display/class strings, leader state, and positive final level; `copy()` and `to_dictionary()` are value-only.
- `RunTerminalSnapshot` schema 1 has exact top fields: outcome, elapsed time, duplicated stable run identity, ordered members, and the defensive Task 7 `RunResolutionSource`.
- `RunTerminalSnapshot.from_dictionary()` rejects missing/extra/type-invalid fields, unsupported outcomes/schema, nonfinite or negative time, invalid JSON-safe identity, malformed members, duplicate IDs, invalid leader truth, more than 24 members, invalid ownership, and any top/member/source disagreement.
- The codec uses `RunResolutionSource.from_dictionary()` as the strict source authority. It never reconstructs source ownership or resolved attributes from display data and does not require catalog lookup for frozen class strings.
- `RunTerminalSnapshotResult` copy-owns every successful snapshot and exposes one exact readable diagnostic on failure.
- `RunTerminalSnapshotBuilder.capture()` validates configured identity, duration, party size, every member in original order, unique positive IDs, class identity/presentation, matching positive progression, and exactly one leader discovered anywhere in the party.
- Builder captures Task 7 live source once through `RunResolutionSource.from_context()`, then passes only typed copies into the terminal value boundary. Invalid members fail at their exact index; none are skipped.
- Display names use the nonblank character name or fall back to the frozen class display name.
- Captured truth retains no party member, actor, health component, scene node, class resource, or mutable context authority.

## Focused Coverage

- Both `VICTORY` and `DEFEAT`, zero and fractional nonnegative durations.
- One, ordinary three-member, and supported maximum 24-member structures; exact order and no truncation.
- Leader at member 13 proves the builder does not assume the first member is leader.
- Exact final levels from `PlayerRunContext.progression_for(member_id)`.
- Mutation of names, class presentation, progression, ownership, profile/run/seed/player identity, escaped member/source/snapshot copies, and source-node freeing after capture.
- Direct dictionary and actual JSON stringify/parse cold round trips.
- Comprehensive capture failure matrix for absent/mismatched progression, invalid/duplicate member IDs, missing/empty classes, zero/two leaders, incomplete run identity, and invalid ownership.
- Comprehensive codec failure matrix for exact fields/types/schema/outcome/time, member fields/levels/leader truth, duplicate/oversized parties, invalid ownership, and independently valid but inconsistent duplicated profile/run/seed/player/leader/member/source truth.
- Capture purity for profile snapshot and live item-ownership documents.

## GREEN Verification

### Exact Task 8 combined gate

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_run_terminal_snapshot.gd tests/unit/test_player_run_context.gd tests/unit/test_run_extraction_policy.gd
```

- Exit: `0`.
- Marker: `TEST_SUMMARY: PASS (0 failures)`.
- The emitted duplicate-equipment-source diagnostic belongs to an asserted retained negative-path test.

### Task 7 focused regression

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_run_extraction_policy.gd tests/unit/test_run_resolution_preflight.gd tests/unit/test_run_resolution_service.gd
```

- Exit: `0`.
- Marker: `TEST_SUMMARY: PASS (0 failures)`.

### Complete unit regression

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 1800 --script res://tests/test_runner.gd
```

- Exit: `0`.
- Marker: `TEST_SUMMARY: PASS (247 suites)`.
- Existing asserted negative-path errors and cleanup-debt warnings do not represent suite failures.

### Import, UID classification, and repository checks

- Headless editor import: exit `0`.
- The import generated many unrelated missing cache UIDs; all were classified and removed. Only the five intended Task 8 UIDs remain.
- Intended UIDs:
  - `scripts/run/run_terminal_party_member_snapshot.gd.uid`
  - `scripts/run/run_terminal_snapshot.gd.uid`
  - `scripts/run/run_terminal_snapshot_result.gd.uid`
  - `scripts/run/run_terminal_snapshot_builder.gd.uid`
  - `tests/unit/test_run_terminal_snapshot.gd.uid`
- `git diff --check`: clean.

## Principal SHA-256 Evidence

- `run_terminal_party_member_snapshot.gd`: `fb04def14160f35642da7c679b377e2ecc2ee65999407c1873d1be3593996d9e`
- `run_terminal_snapshot.gd`: `df05a524cd5835064b90926edf6dd63d7e6b2aef3f125a5c23f19d87aab615ed`
- `run_terminal_snapshot_result.gd`: `d0851e1cf76b416f6c9230cc95c8639f6b0454668f0655a138448e13590e0d3c`
- `run_terminal_snapshot_builder.gd`: `001e45fc92207cfdba6209114f0bb447b0ebcefa6e2b6d12f01b075c14c70aff`
- `test_run_terminal_snapshot.gd`: `47d24c55f0ef8d5d18fa2cbc4c136c1aed74a54ba5baa7267ae2c34bbfc6a8ea`

## Delivery State

- Task 8 implementation and verification are complete in the isolated worktree.
- No Task 9 work, push, merge, or worktree cleanup was performed.
