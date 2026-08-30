# Task 8 Living Forge Terminal Snapshot Report

## Scope

- Exact base: `11ceb76585faf7848ae6ad92a60a74ea2129ef04`.
- Task: capture immutable terminal run truth before cleanup.
- Excluded: Task 9 extraction picker/UI, terminal orchestration/recovery, tactics, push, merge.
- Historical `.superpowers/sdd/task-8-report.md` remains byte-for-byte blob `f9ab690ada4820c35ec225c152400ead751f24dc`.

## TDD RED

### Original implementation RED (reported, not independently reproducible from the current tree)

The original implementation report recorded the following command and result. No durable terminal transcript is preserved in this worktree, so these details are retained as reported evidence rather than a newly reproduced observation.

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 420 --script res://tests/focused_test_runner.gd -- tests/unit/test_run_terminal_snapshot.gd
```

- Exit: `1`.
- Marker: `TEST_SUMMARY: FAIL (4 failures)`.
- Reported classification: only the four then-missing Task 8 types failed: `RunTerminalPartyMemberSnapshot`, `RunTerminalSnapshot`, `RunTerminalSnapshotResult`, and `RunTerminalSnapshotBuilder`; production files were reported untouched.

### Repair RED (reported by the implementer)

Before any repair production edit, the expanded Task 8 test ran with the same focused command.

- Exit: `1`.
- Marker: `TEST_SUMMARY: FAIL (20 failures)`.
- Classification: failures were confined to the approved missing repair surfaces: typed failure categories/player recovery copy, JSON-unsafe member/progression values, and aggregate defensive-copy validation.
- Production files were unchanged from repair base `1dc994b700f2798a5354f08552f54fed8341c732` at this checkpoint.

## Implemented Contract

- `RunTerminalPartyMemberSnapshot` stores only positive JSON-safe member identity, nonblank display/class strings, leader state, and positive JSON-safe final level; `copy()` and `to_dictionary()` are value-only.
- `RunTerminalSnapshot` schema 1 has exact top fields: outcome, elapsed time, duplicated stable run identity, ordered members, and the defensive Task 7 `RunResolutionSource`.
- `RunTerminalSnapshot.from_dictionary()` rejects missing/extra/type-invalid fields, unsupported outcomes/schema, nonfinite or negative time, invalid JSON-safe identity, malformed members, duplicate IDs, invalid leader truth, more than 24 members, invalid ownership, and any top/member/source disagreement.
- The codec uses `RunResolutionSource.from_dictionary()` as the strict source authority. It never reconstructs source ownership or resolved attributes from display data and does not require catalog lookup for frozen class strings.
- Aggregate construction independently revalidates every supplied member value and requires a valid defensive copy before retaining it; mutated or tampered values fail cleanly instead of producing a successful snapshot with a null member.
- `RunTerminalSnapshotResult` copy-owns every successful snapshot. Failure results keep a stable `FailureCategory`, an exact internal diagnostic, and a separate complete player-safe recovery message; success clears all three failure surfaces.
- Builder and codec map context, outcome, duration, identity, party/member, progression, ownership, source, document, and schema failures to stable categories without leaking internal tokens such as `PARTY_FORGE` or `field=` into player-facing text.
- `RunTerminalSnapshotBuilder.capture()` validates configured JSON-safe identity, duration, party size, every member in original order, unique positive JSON-safe IDs, class identity/presentation, matching positive JSON-safe progression, and exactly one leader discovered anywhere in the party.
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
- Capture failure matrix for unconfigured/null context; invalid outcome/time; empty/null member rows; zero, duplicate, or JSON-unsafe IDs; zero/two leaders; blank class and display fallback; missing, mismatched, zero, or JSON-unsafe progression; profile/resumable identity mismatch; and invalid ownership/source truth.
- Codec failure matrix for missing/extra fields, schema/outcome/identity types and JSON-safe bounds, time, nonarray/empty/nondictionary members, member missing/extra/blank/type/JSON-safe fields, duplicate/leader truth, oversized parties, malformed nested source, invalid ownership, and inconsistent duplicated profile/run/seed/player/leader/member/source truth.
- Typed-result checks cover every stable failure category, null failure snapshots, exact representative internal diagnostics, player-safe recovery messages, and cleared success surfaces.
- Capture purity fingerprints party order, progression, profile snapshot, and live item-ownership documents before and after capture.

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

- `run_terminal_party_member_snapshot.gd`: `c2d315f0255a545b0d5b34e0f06209cedc2fba0cb89ced26cd182e406baf530c`
- `run_terminal_snapshot.gd`: `410368b4b29cb85e10afbcdc7bf2fa919685cbd40ae145d70a3d1d4f0d53bd3b`
- `run_terminal_snapshot_result.gd`: `26dedb71b2959f43aa8f394174d8229900022bdd176bfc84df42c8b3803d01ac`
- `run_terminal_snapshot_builder.gd`: `311ecd014ac78748cef15f37c53eed3e3726fa29d248a09a1b94f53cbb9f28c2`
- `test_run_terminal_snapshot.gd`: `1780c1caa642c3b85b81d35c21eed3b6196501363557508c0d41144ea10ed2d2`

## Delivery State

- Task 8 implementation and verification are complete in the isolated worktree.
- No Task 9 work, push, merge, or worktree cleanup was performed.
