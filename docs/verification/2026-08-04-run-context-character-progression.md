# Plan 4A run-context character progression verification

Verified on 2026-08-04 with Godot `4.7.1.stable.mono.official.a13da4feb` in the isolated `run-context-character-progression` worktree and a detached cold-verification worktree.

## Tested code identity

The exact tested production and runner code is commit `da5da67bdedcc28ae8c3707d993e604c7c5f5f0d` (`fix: enforce run context ownership contracts`). This document is a documentation-only child of that code commit. Commit `da5da67` contains the complete Plan 4A code through `e91eec8` plus the four confirmed complete-range review corrections.

All accepted cold commands used a detached worktree at exactly `da5da67` and separate initially empty roots:

```powershell
$env:APPDATA = 'F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\plan4a-cold-env-da5da67\appdata'
$env:LOCALAPPDATA = 'F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\plan4a-cold-env-da5da67\localappdata'
```

## Complete-range review corrections

Each correction received a focused failing regression on parent head `e91eec8`, one minimal production change, and a focused zero-failure GREEN before the next correction.

| Contract | Confirmed root cause | Enforced invariant |
| --- | --- | --- |
| Party ownership | The registry indexed run player, profile, slot, and device but not the mutable `PartyManager`. | `DUPLICATE_PARTY` rejects an exact shared manager before any index write; the same identity/device can retry atomically with an unowned party. |
| Context identity | `PlayerRunContext.configure()` could overwrite a configured context while registry and reward keys retained old identity assumptions. | The first failed configuration is retryable; the first valid configuration succeeds; every later valid or invalid call returns `field=configuration reason=already configured` and mutates nothing. Registry lookup and reward idempotency identity cannot drift. |
| Growth readiness | Party configuration checked member/class presence but not growth existence or validation. | Every existing member must have a valid `growth_definition` before any identity, party, progression, queue, actor, signal, or callback state is committed. |
| Arena device lock | `reassign_device()` did not inspect the Arena roster lock. | A locked roster rejects current-device and collision-destination transfers with `ARENA_RUN_LOCKED` before validation or mutation. |

Focused combined verification for registry, context, class-growth, and reward distribution exited `0` with `TEST_SUMMARY: PASS (0 failures)`.

## Genuine cold import proof

The detached copy began with:

- exact head `da5da67` and clean Git status;
- no `.godot` directory;
- zero untracked `.import` files;
- zero untracked `.gd.uid` files;
- five tracked authored `.import` files and 430 tracked authored `.gd.uid` files left intact;
- empty isolated `APPDATA` and `LOCALAPPDATA` directories.

The documented command was run once without restoring any old sidecar:

```powershell
& $godot --headless --path $cold --import
```

It completed in approximately 31 seconds, exited `0`, completed the 596-step asset reimport, and emitted no `No loader found`, `Parse Error`, `SCRIPT ERROR`, `Failed loading resource`, or unexpected failure match. Afterward the disposable copy contained exactly 591 generated untracked `.import` files, 38 generated unrelated `.gd.uid` files, and 1,192 files totaling 24,254,230 bytes under `.godot/imported`.

The prior rejected cold attempt ended during the initial scan and therefore had no usable loaders. Current evidence confirms the tested hypothesis: a complete first scan and reimport succeeds sidecar-free; no repository fix, restored sidecar, or second import is required. A combined resource-load probe then exited `0` with `PASS (0 failures)`, followed by the complete suite at exit `0` with `TEST_SUMMARY: PASS (120 suites)`.

## Final exact-code gates

| Gate | Exit | Required evidence |
| --- | ---: | --- |
| Genuine cold import | 0 | Completed first scan and 596-step import; zero forbidden loader/parse/script matches |
| Registry/context/growth/reward resource probe | 0 | `TEST_SUMMARY: PASS (0 failures)` |
| Complete suite | 0 | `TEST_SUMMARY: PASS (120 suites)` |
| Two-context harness | 0 | `RUN_CONTEXT_HARNESS_SUMMARY: PASS contexts=2` |
| Production Arena smoke | 0 | `PROGRESSION_ARENA_SMOKE_SUMMARY: PASS`; profile values and SHA-256 bytes unchanged |
| Progressive load baseline | 0 | Four size markers and `PROGRESSION_24_MEMBER_SUMMARY: PASS` |
| Existing 24-member ledger | 0 | `LEDGER_24_MEMBER_SUMMARY: PASS (3 viewports)` |
| Startup smoke | 0 | No loader, parse, script, or failed-resource match |
| Whitespace and active status | 0 | `git diff --check` empty; active worktree clean after source commit |

Accepted ignored logs use the prefix `.superpowers/sdd/final-fixes-plan4a-`. The detailed ignored report is `.superpowers/sdd/plan4a-final-fixes-report.md`.

The production Arena smoke retained the exact immutable-profile proof:

```text
PROGRESSION_ARENA_PROFILE_IMMUTABLE profile=profile-plan4a-task9-smoke sha256_before=4737b1eb1f77a941c199f80c6e1b9b9b3e8d2b11e14384931723c631f5824e9d sha256_after=4737b1eb1f77a941c199f80c6e1b9b9b3e8d2b11e14384931723c631f5824e9d values_equal=true bytes_equal=true
```

## Progressive load baseline

These are fresh observed headless timings, not pass/fail performance thresholds.

| Members | Contexts | Actors | Progression (us) | Ledger refresh (us) | Process avg/max (ms) | Physics avg/max (ms) | Static/max memory (bytes) |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 1 | 1 | 482 | 2,713 | 0.130950 / 0.174000 | 49.660633 / 99.119000 | 114,296,865 / 116,831,630 |
| 6 | 1 | 6 | 2,407 | 3,099 | 0.507125 / 0.642000 | 103.413125 / 217.439000 | 118,957,399 / 118,979,303 |
| 12 | 2 | 12 | 4,773 | 6,434 | 1.091242 / 1.333000 | 151.151817 / 369.578000 | 124,322,771 / 124,358,159 |
| 24 | 4 | 24 | 8,801 | 13,645 | 3.097950 / 3.997000 | 162.940150 / 590.502000 | 135,059,951 / 135,095,339 |

Relative to the earlier accepted headless sample, progression time changed by -44/+22/-192/-814 microseconds and ledger time by -1/-177/+426/-240 microseconds at 1/6/12/24 members. These mixed small movements are observational run-to-run variance; they are not evidence of a performance threshold or regression. Correctness markers remained exact at every size.

## Sidecars and known diagnostics

The active worktree's restored test sidecars were preserved recoverably in stash object `c7641f3aa55204c180b31f1be90b479ac167c93b` (`plan-4a final fixes active generated sidecars`). No older stash was popped or removed. The active worktree contained zero untracked `.import` or `.gd.uid` files at the source commit.

The complete suite retains established intentional negative-path errors and the known 18 ObjectDB/five-resource shutdown diagnostics. The progressive-load child processes retain the known DummyMesh RID, 116 ObjectDB, 101 resource, and Variant allocator-page shutdown diagnostics. Startup retains the known `Scan thread aborted` warning. One pre-cold focused run printed `PASS (0 failures)` but its piped process ended with Windows access-violation code `-1073741819`; it was rejected. The immediate unpiped rerun and all subsequent combined, cold, full-suite, integration, and startup gates exited `0`.

## Accepted deferred Minor findings

- Task 1's growth suite validates every class resource, growth cycle outputs, boundaries, and failure shapes, but does not assert the design table as one exact class-to-cycle-and-weight map. That exact-map hardening remains deferred because the required fixes do not alter authored growth content.
- Shared cleanup-containment hardening remains deferred. Accepted verification uses isolated app-data roots and bounded disposable state; no required ownership fix changes the shared cleanup helpers.

## Explicit Plan 4A boundaries

- Normal Arena remains single-player.
- The two-profile harness proves domain and integration isolation; it is not playable split-screen.
- Controller assignments are automated contracts only. Physical-controller testing, disconnect/reconnect behavior, Steam Remote Play Together, and adaptive-camera behavior remain deferred.
- Tutorial work, onboarding presentation, Arena wave rework, and Adventure-mode work remain deferred.
- Character progression is run-scoped. No `ProfileState` value changed, and Plan 4A does not persist progression snapshots to profile storage.
