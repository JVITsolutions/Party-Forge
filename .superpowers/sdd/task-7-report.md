# Task 7 report: ledger relevance, equipment attribution, and action totals

Status: implementation, fresh verification, independent review, and scoped commit complete.

Implementation commit subject: `feat: show equipment-derived combat stats`. The final hash is recorded in the parent handoff because this tracked report is part of that same commit.

## Scope and behavior

- `LedgerDataProvider` remains fully data-driven: canonical `CAPABILITY` rows use `StatDefinition.capability_tags` and snapshot capabilities, with no class-ID cases.
- A breakdown row counts as modifier relevance only when it is a modifier operation and its contribution is genuinely non-zero. Task 1's zero-valued derived rows therefore do not reveal irrelevant melee/ranged/caster rows or default Party Influence.
- Non-zero modifiers still reveal otherwise irrelevant specialized stats, and `NON_DEFAULT` rows still appear when their resolved value differs from the canonical default.
- `stat_detail().sources` preserves the equipment projector contract: the human item/affix label remains `source_label`, while the detailed deterministic modifier identity remains `source_id`.
- Existing Task 3 action estimates continue to call `ActionDamageProjection.normal_component()` through `ActionCombatEstimateService`. Added coverage proves every component keeps damage identity plus normal/critical/average values; action normal, critical, and average totals equal their component sums; DPS equals average hit times attacks per second.
- No Task 8 tooltip/comparison/layout behavior was changed.

## TDD evidence

### Baseline

The required three-suite batch passed before Task 7 edits:

```text
TEST_SUMMARY: PASS (0 failures)
TASK7_BASELINE_EXIT_CODE=0
```

### Controlled RED

Tests were authored before production changes. The first attempt exposed a test-only multiline-lambda indentation error and Godot returned misleading exit `0`; that run was rejected as evidence and production remained untouched. After correcting the test syntax and replacing Task 6's already-installed empty equipment source in the page fixture, the accepted RED was:

```text
TEST_SUMMARY: FAIL (11 failures)
TASK7_ACCEPTED_RED_EXIT_CODE=1
```

The 11 failures were exactly the missing behavior:

- Fighter exposed irrelevant ranged/caster rows and default Party Influence.
- Ranger exposed irrelevant melee/caster rows and default Party Influence.
- Mage exposed irrelevant melee/ranged rows and default Party Influence.
- The Stats page exposed irrelevant Fighter archetype rows and default Party Influence.

There were no script, parse, or load failures in the accepted RED. The batch retained the established intentional non-finite-source rejection diagnostic.

### Focused GREEN

Command:

```powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_ledger_data_provider.gd tests/unit/test_action_combat_estimate_service.gd tests/unit/test_stats_ledger_page.gd
```

Final result after the clarity refactor:

```text
TEST_SUMMARY: PASS (0 failures)
TASK7_FINAL_FOCUSED_EXIT_CODE=0
```

The focused output includes the pre-existing intentional non-finite-source rejection plus ObjectDB/resource shutdown diagnostics; no Task 7 assertion failed.

## Complete-suite verification

Godot: `4.7.1.stable.official.a13da4feb`.

Command:

```powershell
& $godot --headless --path . --quit-after 1800 --script res://tests/test_runner.gd
```

Fresh result:

```text
TEST_SUMMARY: PASS (162 suites)
TASK7_FULL_TEST_FAILURE_LINES=0
TASK7_FULL_SCRIPT_PARSE_LOAD_LINES=0
TASK7_FULL_ERROR_LINES=56
TASK7_FULL_WARNING_LINES=10
TASK7_FULL_EXIT_CODE=0
```

The 56 error and 10 warning lines are the established intentional negative-path and shutdown diagnostics already recorded by Task 6. There were zero assertion failures and zero script/parse/load markers.

## Files in scoped commit

- `.superpowers/sdd/task-7-report.md`
- `scripts/ui/ledger/ledger_data_provider.gd`
- `tests/unit/test_action_combat_estimate_service.gd`
- `tests/unit/test_ledger_data_provider.gd`
- `tests/unit/test_stats_ledger_page.gd`

`scripts/ui/ledger/action_combat_estimate.gd` required no production change because Task 3 already supplied independently readable component rows and the requested total fields; Task 7 adds regression proof rather than duplicating or replacing that shared projection.

## Hygiene and concerns

- `git diff --check` passes.
- Exactly five scoped tracked files were committed, including this report.
- Pre-existing untracked `.gd.uid` sidecars remain untouched and will not be staged.
- No open Task 7 functional concern is known. Complete-runner output is not diagnostically pristine because established rejection tests intentionally emit errors and shutdown warnings.

## Independent review

An independent static review of the complete Task 7 diff against the approved brief and design reported no Critical, Important, or Minor findings. The reviewer did not rerun tests because fresh focused and full-suite verification was already recorded above.
