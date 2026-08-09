# Task 6 report: atomic equipment transitions and health refresh

Status: initial implementation committed as `c92b97e60b7438b216daffbde1237dec412388da`; Important review findings fixed and fully verified, with the narrow follow-up commit pending at report-writing time.

## Scope and behavior

- Starting head: `094d7b0ea46f7f24939bd135559549a1fd4b93b0` (`feat: disable equipment with unmet attributes`).
- Added pure `EquipmentTransitionService.preview(...)` and owned `EquipmentTransitionResult` boundaries.
- Preview combines the existing structural assignment candidate, deterministic Task 5 activation, the immutable Task 4 equipment source, and Task 2 final two-pass stat resolution without mutating ownership, party sources, caches, items, affix rolls, or class Resources.
- Newly placed equipment must be active in the candidate loadout. Existing dependent items may remain equipped but disabled after a support-item removal.
- `PlayerRunContext.assign_equipment(...)` now stages candidate ownership and activation before replacing the stable `equipment_member_<member_id>` source. The synchronous `stats_changed` observer therefore sees one consistent committed ownership/source/activation state.
- A rejected source replacement restores exact prior ownership and activation, preserves cached snapshot identity, and emits no misleading stat signal. Base and action caches for unrelated members retain object identity.
- Fresh and resumable context configuration reconstructs every current member's activation and uniform equipment source before the context becomes configured. Valid resumed immutable items restore the same affix-derived and attribute-derived stats.
- Future recruits receive the same empty equipment activation/source contract when their run equipment container is added.
- Runtime maximum-health refresh uses clamp-only behavior. Maximum increases grant no health, decreases clamp only above the new maximum, and the first actor setup still intentionally initializes full health at its final resolved maximum.

## Important review follow-up

- Resumable configuration now calls `EquipmentAssignmentService.validate_member_loadout(...)` before activation. This public seam reuses the existing canonical-slot, class/capability, handedness/reservation, compatible-offhand, and quiver-family rules rather than maintaining a second structural rule set.
- `PartyManager.replace_member_sources_atomically(...)` is the approved narrow scope expansion required to make multi-member configuration genuinely atomic. It validates every member/source pair first, snapshots exact owned sources, commits through one protected no-invalidation seam, restores all snapshots on a selective rejection, and changes no revision/cache/signal state on failure.
- A successful source batch clears every affected base/action cache under one shared revision, then emits deterministic member-ID-ordered signals. `PlayerRunContext` stages its complete owned profile, party, progression, item state, activations, listener, and configured state before that batch, so synchronous observers see one coherent configuration.
- A failed source batch fully resets the context and disconnects its staged listener. The member-two selective rejection regression proves member one's exact prior source document, base cached snapshot identity, member-two action cached snapshot identity, revision, and no-signal state are preserved.
- Resume regressions cover a sword in a helmet slot, Ranger wearing incompatible heavy plate, and a light bow paired with a mismatched heavy-quiver family. All fail before source/cache/context mutation.

## TDD evidence

### Baseline

Before Task 6 edits:

```text
TEST_SUMMARY: PASS (161 suites)
TASK6_BASELINE_EXIT_CODE=0
```

### Controlled RED

Command:

```powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_equipment_transition_service.gd tests/unit/test_player_run_context.gd tests/unit/test_health_component.gd tests/unit/test_equipment_assignment_service.gd
```

Accepted result:

```text
TEST_SUMMARY: FAIL (14 failures)
TASK6_RED_EXIT_CODE=1
```

The failures were exactly the requested absent behavior: two missing transition scripts, two missing run-context APIs, two percentage-preserving health results, and eight context-level diagnostics still using the assignment prefix. The runner parsed all suites and returned a normal assertion summary.

### Registration import

The bounded editor scan registered both new global classes and exited `0`:

```text
[ DONE ] first_scan_filesystem
[ DONE ] update_scripts_classes
[ DONE ] loading_editor_layout
TASK6_IMPORT_EXIT_CODE=0
```

### Focused GREEN

The required four-suite Task 6 batch passed:

```text
TEST_SUMMARY: PASS (0 failures)
TASK6_GREEN_ATTEMPT_2_EXIT_CODE=0
```

Coverage proves pure preview, final Constitution-derived health, defensive state/activation results, immutable items/classes, requested-item disable rejection, invalid projection atomicity, synchronous committed-state visibility, source-rejection rollback, member-local base/action cache preservation, resume reconstruction, and clamp-without-heal behavior.

### Review RED and GREEN

The new player-context regressions were first run against the reviewed implementation:

```text
TEST_SUMMARY: FAIL (41 failures)
TASK6_REVIEW_RED_EXIT_CODE=1
```

Those failures were limited to the two reported defects: structurally invalid resumes were accepted, member one remained partially committed after a selective member-two rejection, revision/cache/signal state drifted, and success observers saw unstaged context/member-two state.

After the fix, the player-context suite passed, followed by the final seven-suite affected gate:

```text
TEST_SUMMARY: PASS (0 failures)
TASK6_REVIEW_GREEN_ATTEMPT_1_EXIT_CODE=0

TEST_SUMMARY: PASS (0 failures)
TASK6_REVIEW_FINAL_FOCUSED_EXIT_CODE=0
```

The final affected gate covered equipment transition, player context, health, assignment, PartyManager, run resolution, and run extraction policy.

## Full-suite compatibility findings

The first complete run found one stale health assertion and one fixture-order conflict:

- `test_final_review.gd` expected a full-health percentage-preserving refresh after a maximum-health upgrade. The parent approved changing the exact expectation from current health `273` to `260`, matching the Task 6 no-free-healing rule while maximum health still becomes `273`.
- `test_reward_distribution.gd` armed a `RejectingPartyManager` before context configuration even though it intended to reject a later XP growth source. Task 6's required empty equipment-source reconstruction reached that rejection first. The parent approved moving the rejection flag until immediately after fixture configuration, preserving both uniform empty equipment-source reconstruction and the original later XP-failure scenario.
- The existing player-context growth-source assertions were narrowed to locate `character_growth_1` by stable ID because each configured member now also owns the authoritative equipment source. The two Task 6 item fixtures received explicit one-column inventory capacity.
- Review-time structural resume validation exposed two older extraction fixtures that used a Fighter sword as a generic placeholder in a Ranger ring slot and Mage body-armour slot. The full runner still printed `PASS` while their fixture assertions aborted, so that first summary was not accepted. The placeholders were changed only to class/slot-compatible `windrunner_band`, `emberweave_robe`, or `greenwood_jerkin` base IDs while preserving the exact container slots, item identities, extraction selections, and expected projection behavior. Both suites then passed in isolation and in the affected batch.

Expanded focused compatibility gate:

```text
TEST_SUMMARY: PASS (0 failures)
TASK6_EXPANDED_FOCUSED_EXIT_CODE=0
```

This gate ran the four Task 6 suites plus `test_reward_distribution.gd` and `test_final_review.gd`.

## Final complete suite

Godot: `4.7.1.stable.mono.official.a13da4feb`.

```text
TEST_SUMMARY: PASS (162 suites)
TASK6_REVIEW_ACCEPTED_FULL_EXIT_CODE=0
```

The count is one above the 161-suite baseline because `test_equipment_transition_service.gd` is new. The complete runner retains its established intentional negative-path errors and warnings; no final assertion failed and the process exited `0`.

## Files in Task 6 scope

- `.superpowers/sdd/task-6-report.md`
- `scripts/equipment/equipment_transition_result.gd`
- `scripts/equipment/equipment_transition_service.gd`
- `scripts/equipment/equipment_assignment_service.gd`
- `scripts/party/party_manager.gd`
- `scripts/run/player_run_context.gd`
- `scripts/characters/party_actor.gd`
- `tests/unit/test_equipment_transition_service.gd`
- `tests/unit/test_player_run_context.gd`
- `tests/unit/test_health_component.gd`
- `tests/unit/test_equipment_assignment_service.gd`
- `tests/unit/test_final_review.gd` (parent-approved compatibility expectation)
- `tests/unit/test_reward_distribution.gd` (parent-approved compatibility fixture ordering)
- `tests/unit/test_run_resolution_service.gd` (structurally valid Ranger ring fixture)
- `tests/unit/test_run_extraction_policy.gd` (structurally valid follower equipment fixtures)

## Hygiene and concerns

- `git diff --check` passed.
- The editor import generated `.gd.uid` sidecars for the two new scripts and new test alongside the worktree's existing untracked sidecars. No `.gd.uid`, `.import`, `.godot`, ignored scratch artifact, or unrelated file will be staged.
- No open Task 6 functional concern is known. The atomic batch API is intentionally limited to replacing one already validated source per affected member; it is not a general PartyManager transaction API.
- Complete-suite output is not diagnostically pristine because established rejection tests intentionally emit errors and warnings; the authoritative final result is exit `0` with `PASS (162 suites)`.
