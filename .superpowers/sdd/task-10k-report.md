# Task 10K report: restrict atomic equipment-source batches

Status: implementation and fresh verification complete; scoped commit pending at report-writing time.

## Root cause and remediation

`PartyManager.replace_member_sources_atomically()` accepted any validated stat source. A configured run could therefore commit an arbitrary non-equipment core-attribute source through this public batch seam without invoking the `PlayerRunContext` coordinator that recomputes equipment activation. The committed attributes and cached stats changed, but requirement-dependent equipment activation remained stale.

The general batch seam has been removed rather than retained as a compatibility alias. Its replacement is `replace_member_equipment_sources_atomically()` and is used only by `PlayerRunContext.configure()` for fresh/resumable equipment reconstruction.

Before any snapshot or mutation, the replacement contract:

- rejects an empty batch or non-integer member key with the established batch-level `-1` result;
- sorts member IDs before validation so contextual member rejection is deterministic;
- requires every member to exist and every value to be a `StatModifierSource`;
- requires `source_type == &"equipment"`;
- requires the exact canonical ID `equipment_member_<member_id>`;
- requires `owner_member_id` to equal the dictionary member key; and
- validates every source against the canonical stat catalog.

Only after the full batch passes does the existing transaction snapshot sources, commit through the protected no-invalidation seam, restore every member on a selective commit rejection, and invalidate all affected members under one shared revision. Successful signals remain member-ID ordered. Failure preserves exact source documents, revision, base/action cache identity, signals, configuration state, coordinator ownership, and item/activation state.

## TDD evidence

### Accepted controlled RED

The two-suite PartyManager/non-equipment refresh regression executed normally against the prior production code and returned:

```text
TEST_SUMMARY: FAIL (9 failures)
TASK10K_RED_EXIT_CODE=1
```

The failures proved both absent API restrictions and the live defect: the old batch method accepted an arbitrary Strength source, installed it, advanced the shared revision, emitted `stats_changed(1)`, and replaced affected base/action caches while the configured Strength-requirement sword remained disabled with stale activation.

### GREEN and malformed-value hardening

The first focused GREEN returned:

```text
TEST_SUMMARY: PASS (0 failures)
TASK10K_FIRST_GREEN_EXIT_CODE=0
```

A later malformed Variant case exposed a runtime cast diagnostic. That run was not accepted as RED evidence because it contained a script error. The final input guard rejects non-source values contextually without a cast error; the focused PartyManager rerun returned `TEST_SUMMARY: PASS (0 failures)` and exit `0`.

## Coverage

The final tests cover:

- explicit absence of `replace_member_sources_atomically()` and presence of the narrow replacement;
- arbitrary non-equipment core sources, wrong source type, wrong canonical ID, wrong owner, null and wrong-Variant values;
- mixed valid/invalid batches and duplicate source ownership across member keys;
- deterministic lowest-member rejection when insertion order differs;
- canonical equipment success with one shared revision and sorted signals;
- selective commit rollback during context configuration;
- exact source documents, revisions, signal lists, and affected/unaffected base/action cache identities on rejection;
- synchronous configure observers seeing complete context, activation, sources, and final stats;
- fresh and resumable 24-member reconstruction with members 2-24 retaining identity;
- registry bind, clear, reinitialize, replacement-owner, and late-clear lifecycle behavior; and
- existing member-local coordinated non-equipment refresh behavior.

## Fresh verification

Godot: `4.7.1.stable.official.a13da4feb`.

Final affected gate (PartyManager, PlayerRunContext, RunContextRegistry, non-equipment activation refresh, equipment activation/transition, member resolution, and health):

```text
TEST_SUMMARY: PASS (0 failures)
TASK10K_FINAL_FOCUSED_EXIT_CODE=0
```

Final equipment configure/resume integration:

```text
TASK10J_ACTION_CACHE_SUMMARY: PASS members=24 hits=512 usec=1661
EQUIPMENT_ATTRIBUTE_APPLICATION_SUMMARY: PASS members=24 untouched=23 items=2
TASK10K_FINAL_EQUIPMENT_24_EXIT_CODE=0
```

Final 24-member progression/lifecycle integration:

```text
PROGRESSION_24_MEMBER_ISOLATION_PASS members=24 untouched=23
PROGRESSION_24_MEMBER_SUMMARY: PASS
TASK10K_FINAL_PROGRESSION_24_EXIT_CODE=0
```

Hardened complete suite:

```text
TEST_SUMMARY: PASS (166 suites)
TASK10K_HARDENED_FULL_EXIT_CODE=0
```

The complete runner finished in 126.5 seconds and retained its established asserted negative-path domain errors, JSON-store warnings, and shutdown diagnostics. It exited `0` with no failure summary.

## Scope and hygiene

Task 10K changes are limited to:

- `scripts/party/party_manager.gd`
- `scripts/run/player_run_context.gd`
- `tests/unit/test_party_manager.gd`
- `tests/unit/test_non_equipment_activation_refresh.gd`
- `.superpowers/sdd/task-10k-report.md`

`git diff --check` passed before report creation. The worktree's pre-existing untracked `.gd.uid` sidecars were not edited or staged. Task-specific APPDATA/LOCALAPPDATA directories remain ignored under `.superpowers/sdd` and are not commit scope.

## Concerns

No Task 10K functional concern remains. The batch API intentionally remains equipment-only; future multi-member non-equipment changes must use a genuine activation-aware multi-member coordinator instead of broadening this seam.
