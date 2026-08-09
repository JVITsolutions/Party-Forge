# Task 8 Report: Disabled Equipment and Projected Comparisons

## Scope

Implemented Plan 5 Task 8 on `feat/equipment-attribute-application` from parent `d9bea3ffc856c825cc86d533d3e8c9ab508b43ba`.

The implementation:

- compares current and dry-run candidate final stat snapshots using each stat's benefit direction;
- appends projected action average-hit/DPS changes and activation cascade warnings;
- uses green/up, red/down, and neutral symbols together with explicit accessible wording;
- annotates inactive equipped items, renders a `DISABLED` slot overlay, and lists exact human requirements such as `Requires Constitution 5 (has 3)`;
- supplies projected rows to Armoury, Warehouse, and the Developer Item Sandbox, retaining raw modifier comparison only when no character/class projection exists;
- preserves comparison caches through the Armoury and Warehouse projection wrappers.

Two narrow domain seams were added because the approved UI projection cannot be correct without them:

- `ProfileLoadoutAssignmentService.preview(profile, request)` performs the normal assignment path on a defensive profile copy without persistence.
- `ActionCombatEstimateService.estimate_from_snapshot(attack, snapshot, damage_types)` estimates actions from an already-resolved candidate snapshot.

Profile assignment now validates structural compatibility separately from activation, permits already-equipped dependents to become disabled, rejects the newly placed inactive item in either swap direction, and uses the same activation resolver for preview and apply.

## Files

Created:

- `scripts/ui/storage/resolved_stat_comparison_service.gd`
- `scripts/ui/storage/equipment_comparison_projection_service.gd`
- `tests/unit/test_resolved_stat_comparison_service.gd`

Modified:

- `scripts/equipment/profile_loadout_assignment_service.gd`
- `scripts/ui/ledger/action_combat_estimate_service.gd`
- shared storage presentation, comparison, slot, tooltip, and profile-projection scripts;
- Armoury and Warehouse projection/screen adapters;
- Developer Item Sandbox comparison fixture;
- focused unit and responsive integration coverage.

No `.gd.uid`, import, screenshot, or scratch artifacts are part of the intended commit.

## RED-GREEN Evidence

The initial Task 8 focused RED exited `1` with `TEST_SUMMARY: FAIL (14 failures)`. It contained assertion failures for the absent comparison and disabled-presentation behavior, with no accepted parser/loader failure.

The semantic profile-assignment follow-up RED exited with three failures covering disabled-dependent preview/apply parity and rejection of a newly placed inactive candidate.

Independent review then identified five missing boundaries. The accepted combined review RED exited `1` with `TEST_SUMMARY: FAIL (10 failures)` and covered:

- delta formatting independent of absolute stat minimums;
- an explicit projected-slot result when dry-run assignment is rejected;
- inactive items entering the loadout through the reverse side of an occupied swap;
- exact human requirement wording from live activation data;
- a valid Developer Sandbox fixture that renders projected stat/action rows.

After correction, the four-suite review batch passed:

```text
TEST_SUMMARY: PASS (0 failures)
```

The sandbox correction also exposed and fixed an older invalid synthetic profile boundary: a five-slot developer inventory had been modeled as a profile stash tab, whose required capacity is 100. The fixture now equips one deterministic Forge baseline per canonical slot and repacks all other items into one valid 100-slot synthetic stash.

## Final Verification

Affected 12-suite batch:

```text
TEST_SUMMARY: PASS (0 failures)
```

This covered resolved and action comparisons, profile assignment/projection, raw-fallback suppression, slot/button/card/panel presentation, Armoury, Warehouse, and the Developer Item Sandbox.

Responsive runner:

```text
ITEM_TOOLTIP_COMPATIBILITY_PASS size=1280x720
ITEM_TOOLTIP_RESPONSIVE_SIZE_PASS size=1920x1080
ITEM_TOOLTIP_RESPONSIVE_SIZE_PASS size=2560x1440
ITEM_TOOLTIP_RESPONSIVE_SIZE_PASS size=3840x2160
ITEM_TOOLTIP_RESPONSIVE_SUMMARY: PASS (3 sizes)
```

Complete unit suite after all production fixes:

```text
DEVELOPER_ITEM_SANDBOX_SHA256: c201fd5917d9958da63dacd8201e80d5911c0de51af367977d2a5ee57dd9defe
ITEM_TRANSACTION_MATRIX: PASS
TEST_SUMMARY: PASS (163 suites)
```

The full suite exited `0` in 165.5 seconds. Its error stream contained established intentional negative-test diagnostics; the passing summary is authoritative.

`git diff --check` is clean.

## Independent Review

The first review reported zero Critical, five Important, and one Minor finding. All were corrected test-first. The same reviewer re-reviewed the final diff and reported:

```text
No actionable findings.
All five prior Important findings and the Minor cache issue are resolved.
No new Critical or Important issues.
```

## Visual QA Boundary

The responsive runner exercises real tooltip/card layout and visible text geometry at 720p compatibility, 1080p, 1440p, and 4K, including edge anchors, multiple comparison-card counts, normal/compare/advanced/combined modes, pin reachability, and scrollbar containment. It reported no overflow.

No manual screenshot or pixel-by-pixel art review was performed. Remaining visual risk is therefore limited to subjective color/typography polish rather than measured containment or missing content.

## Commit

Intended commit message: `feat: show projected equipment comparisons`
