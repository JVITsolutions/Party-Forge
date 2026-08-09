# Task 10A report: atomic activation refresh after non-equipment attribute changes

Status: implementation and fresh verification complete; scoped commit pending at report-writing time.

## Root cause and remediation

`PlayerRunContext` previously recomputed `_equipment_activation_by_member` only while configuring/resuming a run or previewing an equipment assignment. `award_experience()` and other later `PartyManager.replace_member_source()` calls committed the new non-equipment source and invalidated the affected stat caches immediately, but retained the old activation result and old `equipment_member_<id>` source. Growth and personal upgrade sources could therefore satisfy a requirement while the item remained disabled; a later source loss could leave an invalid item active.

The remediation adds one member-local coordinator contract:

- A configured `PlayerRunContext` binds its non-equipment source refresh callback to its `PartyManager`.
- Context-bound `add_member_source()` and `replace_member_source()` calls route non-equipment sources through that callback. Equipment-source commits retain their existing transition path.
- The callback builds the candidate non-equipment source set by stable source ID, reruns `EquipmentActivationResolver`, and validates the final two-pass member snapshot before mutation.
- `PartyManager.replace_member_source_with_equipment_atomically()` prevalidates the candidate non-equipment and exact member equipment sources, snapshots the exact owned source documents, commits both through the existing protected no-invalidation seam, restores the snapshot if either commit is rejected, and invalidates the affected member once only after both sources exist.
- The context stages the copied activation before that one invalidation, so synchronous `stats_changed` observers see the candidate non-equipment source, refreshed equipment source, activation, unchanged ownership, and final stats together. A rejected commit restores the exact previous activation before returning failure.
- Progression state and personal upgrade rank are staged before the coordinated stat signal and restored if the source transaction fails. Existing level/progression and upgrade signals retain their prior successful ordering/counts.
- Temporary duplicate-party contexts remain constructible so `RunContextRegistry` continues to own the stable `DUPLICATE_PARTY` rejection boundary; the first successfully bound context remains authoritative until that invalid alias is rejected.

No item, affix, equipment-base, class, growth, action, UI, generator, swap, or action-transition production code changed.

## Required behavior coverage

`tests/unit/test_non_equipment_activation_refresh.gd` exercises real production services and one narrow failure-injection subclass:

- one equipped Fighter sword starts disabled behind a one-Strength requirement;
- actual level-two Fighter growth adds Strength and reactivates it automatically;
- the reactivated immutable item's Constitution affix raises final and runtime maximum health without healing current health;
- replacement of the stable growth source with an empty respec source disables the sword without unequipping it, records the exact unmet-Strength reason, removes its derived health, and clamps current health only when above the reduced maximum;
- a real personal `UpgradeApplicationService` core-attribute upgrade reactivates the same requirement gear, and direct replacement of that stable upgrade source disables it again;
- synchronous observers see coherent source, activation, ownership, final-stat, and runtime-health state;
- each successful member-local refresh emits exactly one `stats_changed(1)` and advances the shared revision exactly once;
- one 24-member run preserves the exact base/action snapshot object identities and snapshot revisions for members 2-24 through growth and requirement loss;
- affected member base/action snapshots are replaced, while item JSON, ownership JSON, class base values, class growth data, and the original equipment definition remain unchanged;
- forced rejection of the second, equipment-source commit after the candidate non-equipment source was written restores exact source documents, activation IDs/reasons, ownership, item bytes, revision, affected and unrelated cache identities, and emits no stat signal.

## TDD evidence

### Baseline

Before Task 10A edits, the five-suite PartyManager/run-context/activation/transition/health batch exited `0`:

```text
TEST_SUMMARY: PASS (0 failures)
TASK10A_BASELINE_EXIT_CODE=0
```

### Accepted controlled RED

Command:

```powershell
& $godot --headless --path . --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_non_equipment_activation_refresh.gd
```

The accepted pre-production run parsed and executed normally, exited `1`, and failed only on the absent refresh/rollback behavior:

```text
TEST_SUMMARY: FAIL (13 failures)
TASK10A_ACCEPTED_RED_EXIT_CODE=1
```

Representative evidence was stale `active == false`, maximum health `260` instead of `269`, and a rejected-refresh fixture that instead returned success, retained the candidate source, advanced revision `3 -> 4`, emitted `[1]`, and replaced affected caches.

### Focused GREEN

The dedicated regression returned:

```text
TEST_SUMMARY: PASS (0 failures)
TASK10A_GREEN_ATTEMPT_2_EXIT_CODE=0
```

The expanded affected gate covered the new suite plus PartyManager, PlayerRunContext, authored upgrades, reward distribution, health, equipment activation, equipment transition, and member stat resolution:

```text
TEST_SUMMARY: PASS (0 failures)
TASK10A_AFFECTED_GREEN_ATTEMPT_1_EXIT_CODE=0
```

The established intentional negative-path stat and upgrade diagnostics remained present; no assertion, parser, script, or loader failure occurred.

### 24-member integrations

```text
EQUIPMENT_ATTRIBUTE_APPLICATION_SUMMARY: PASS members=24 untouched=23 items=2
TASK10A_EQUIPMENT_INTEGRATION_EXIT_CODE=0

PROGRESSION_24_MEMBER_ISOLATION_PASS members=24 untouched=23
PROGRESSION_24_MEMBER_SUMMARY: PASS
TASK10A_PROGRESSION_24_EXIT_CODE=0
```

The progression runner retains its established RID/ObjectDB/resource shutdown diagnostics; all child processes and the parent exited `0`.

### Full-suite compatibility correction

The first full run correctly rejected the change with two `test_run_context_registry.gd` failures. Coordinator binding had caused a second temporary context for the same party to fail configuration before the registry could return its established `DUPLICATE_PARTY` diagnostic. No Task 10A behavior assertion failed.

The binding call was narrowed so configuration does not preempt that ownership layer. The exact registry/context/Task 10A compatibility batch then returned:

```text
TEST_SUMMARY: PASS (0 failures)
TASK10A_REGISTRY_COMPAT_GREEN_EXIT_CODE=0
```

The repeated complete suite on the corrected tree returned:

```text
TEST_SUMMARY: PASS (164 suites)
TASK10A_FULL_RERUN_EXIT_CODE=0
```

The count is one above the prior 163-suite Increment 2 evidence because the Task 10A unit suite is new. The full runner retains established intentional negative-path errors/warnings; the authoritative result is exit `0` with `PASS (164 suites)`.

## Files in scoped commit

- `.superpowers/sdd/task-10a-report.md`
- `scripts/party/party_manager.gd`
- `scripts/run/player_run_context.gd`
- `tests/unit/test_non_equipment_activation_refresh.gd`

## Hygiene and boundary

- `git diff --check` passed before report authoring and will be rerun before commit.
- The worktree retains 123 pre-existing untracked `.gd.uid` sidecars. The new test did not create a sidecar. No `.gd.uid`, `.import`, `.godot`, log, scratch artifact, Resource, scene, asset, UI, item-generation, swap, or action-transition file is in scope.
- Party-global rank, trait, party-stat, and currently authored party-upgrade paths do not grant core attributes and were not broadened into a multi-member activation transaction. A future party-global core-attribute source would require its own multi-member atomic coordinator rather than this explicitly member-local seam.
- No open Task 10A functional concern is known for current runtime member-owned source, progression, respec, or personal-upgrade paths.
