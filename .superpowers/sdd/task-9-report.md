# Task 9 report: resume, 24-member isolation, and end-to-end regression

Status: regression implementation and fresh verification complete; scoped commit pending at report-writing time.

## Scope and result

Task 9 started from `f8e51c3239e142d7886cd6532d9703850ff56b74` (`feat: show projected equipment comparisons`) on the isolated `feat/equipment-attribute-application` worktree.

No production code changed. Task 6 already supplied resumable equipment reconstruction, atomic source replacement, affected-member cache invalidation, and one-signal refresh behavior. Task 9 adds end-to-end and retained regression evidence around those existing seams:

- `equipment_attribute_application_runner.gd` builds one Mage party at the developer capacity of 24 members;
- it owns an immutable Constitution circlet and fire-damage wand, with the wand requiring the circlet's three Constitution points in the isolated test catalog fixture;
- it caches both base and Mage-action snapshot objects plus their revisions for members 2-24;
- each member-one equip, disable, and resumed-reactivation transition proves exactly one revision advance and an exact `stats_changed == [1]` signal sequence;
- every member 2-24 base/action cache retains the same object identity and original snapshot revision through each transition;
- removing the circlet leaves the wand equipped but disabled, excludes all of its effects, retains the exact unmet-Constitution reason, and returns both final stats and the fire action estimate to their exact baseline documents;
- the disabled item state is encoded with `ResumableRunItemCodec`, decoded, configured into a new 24-member context, and compared for identical active IDs, disabled reasons, final stat values/breakdowns, and complete action-estimate values/components;
- re-equipping the circlet after resume restores the exact pre-disable active IDs, final stat document, and action estimate while again preserving members 2-24;
- both item dictionaries remain JSON-byte-equivalent after every assignment, disable, encode/decode, resume reconstruction, and reactivation boundary.

The retained progression integration now also creates one real 24-member party and proves a member-one source refresh preserves member 2-24 base/action snapshot identities and revisions. Its new exact marker is:

```text
PROGRESSION_24_MEMBER_ISOLATION_PASS members=24 untouched=23
```

Unit regressions add:

- exact attribute and typed-damage `ItemInstance` codec round trips;
- resumable ownership-state round trips that preserve both item dictionaries byte-equivalently;
- deterministic, available, positive primary-action estimates for all nine playable classes.

## TDD and existing-green evidence

### Pre-edit baseline

The exact Task 9 focused batch passed before edits:

```text
TEST_SUMMARY: PASS (0 failures)
TASK9_BASELINE_FOCUSED_EXIT_CODE=0
TASK9_BASELINE_FOCUSED_SECONDS=5.498
```

The existing progression integration also passed every 1/6/12/24 case before modification:

```text
PROGRESSION_24_MEMBER_SUMMARY: PASS
TASK9_BASELINE_24_EXIT_CODE=0
TASK9_BASELINE_24_SECONDS=16.959
```

### First authored-runner attempt

The first new integration run exited `1` in `2.119` seconds with one assertion:

```text
EQUIPMENT_ATTRIBUTE_APPLICATION_SUMMARY: FAIL failures=1
EQUIPMENT_ATTRIBUTE_APPLICATION_FAILURE: attribute and typed-damage items are active together
```

This was not accepted as a production RED. `EquipmentActivationResult` correctly returned both active IDs in its documented sorted order; the new test had written the same two expected IDs in reverse order. Only the test expectation was corrected. No production file was touched.

The corrected regression immediately demonstrated the already-installed behavior:

```text
EQUIPMENT_ATTRIBUTE_APPLICATION_SUMMARY: PASS members=24 untouched=23 items=2
TASK9_EXISTING_GREEN_EXIT_CODE=0
TASK9_EXISTING_GREEN_SECONDS=1.973
```

This is honestly existing-green coverage. A controlled product RED was not manufactured because the approved implementation already met the Task 9 contract.

## Final verification

Godot: `4.7.1.stable.mono.official.a13da4feb`.

### Focused Task 9 regression

```powershell
& $godot --headless --path . --quit-after 900 --script res://tests/focused_test_runner.gd -- tests/unit/test_stat_catalog.gd tests/unit/test_stat_resolver.gd tests/unit/test_party_manager.gd tests/unit/test_damage_resolver.gd tests/unit/test_action_combat_estimate_service.gd tests/unit/test_equipment_assignment_service.gd tests/unit/test_run_item_ownership.gd tests/unit/test_item_instance_codec.gd tests/unit/test_game_catalog.gd
```

```text
TEST_SUMMARY: PASS (0 failures)
TASK9_FOCUSED_GREEN_EXIT_CODE=0
TASK9_FOCUSED_GREEN_SECONDS=6.246
```

The error stream contains only established intentional negative-path diagnostics from stat, damage, and non-finite estimate tests, plus the existing shutdown diagnostics. No Task 9 assertion, parser, script, or loader failure occurred.

### Equipment attribute application integration

```powershell
& $godot --headless --path . --quit-after 900 --script res://tests/integration/equipment_attribute_application_runner.gd
```

```text
EQUIPMENT_ATTRIBUTE_APPLICATION_SUMMARY: PASS members=24 untouched=23 items=2
TASK9_EXISTING_GREEN_EXIT_CODE=0
TASK9_EXISTING_GREEN_SECONDS=1.973
```

### Progression 24-member integration

```powershell
& $godot --headless --path . --quit-after 900 --script res://tests/integration/progression_24_member_runner.gd
```

```text
PROGRESSION_24_MEMBER_ISOLATION_PASS members=24 untouched=23
PROGRESSION_LOAD_SIZE_PASS members=1 contexts=1 actors=1 party_members=1 ...
PROGRESSION_LOAD_SIZE_PASS members=6 contexts=1 actors=6 party_members=6 ...
PROGRESSION_LOAD_SIZE_PASS members=12 contexts=2 actors=12 party_members=12 ...
PROGRESSION_LOAD_SIZE_PASS members=24 contexts=4 actors=24 party_members=24 ...
PROGRESSION_24_MEMBER_SUMMARY: PASS
TASK9_24_GREEN_EXIT_CODE=0
TASK9_24_GREEN_SECONDS=17.246
```

The integration retains its established RID/ObjectDB/resource shutdown diagnostics. All child processes and the parent runner exited `0`.

### Complete suite compatibility

The Task 9 plan commits after focused and integration gates; a complete suite was nevertheless run as an extra compatibility check:

```powershell
& $godot --headless --path . --quit-after 1800 --script res://tests/test_runner.gd
```

```text
DEVELOPER_ITEM_SANDBOX_SHA256: c201fd5917d9958da63dacd8201e80d5911c0de51af367977d2a5ee57dd9defe
ITEM_TRANSACTION_MATRIX: PASS
TEST_SUMMARY: PASS (163 suites)
TASK9_FULL_EXIT_CODE=0
TASK9_FULL_SECONDS=146.252
```

The complete runner retains its established intentional negative-path errors/warnings and shutdown diagnostics. The authoritative result is exit `0` with `PASS (163 suites)`.

## Files in scoped commit

- `.superpowers/sdd/task-9-report.md`
- `tests/integration/equipment_attribute_application_runner.gd`
- `tests/integration/progression_24_member_runner.gd`
- `tests/unit/test_run_item_ownership.gd`
- `tests/unit/test_item_instance_codec.gd`
- `tests/unit/test_game_catalog.gd`

No production script, Resource, scene, asset, project setting, import artifact, or generated sidecar is in scope.

## Hygiene and concerns

- `git diff --check` passed before report authoring and will be rerun before commit.
- The worktree currently retains 123 pre-existing untracked `.gd.uid` sidecars. No `.gd.uid` is staged, and running the new script directly did not create an `equipment_attribute_application_runner.gd.uid` sidecar.
- The integration temporarily replaces the in-memory live wand definition with a deep-copied fixture that adds the Constitution requirement, then restores the original definition before exit. This is necessary because production content intentionally has no final attribute requirements yet and `PlayerRunContext.configure()` reconstructs against `GameCatalog.EQUIPMENT_CATALOG`. No on-disk catalog or Resource changes.
- No open Task 9 functional concern is known. Final production content requirements and broad inventory artwork remain outside this increment.
