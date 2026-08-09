# Task 10K report: restrict atomic equipment-source batches

Status: implementation, sibling-bypass review remediation, and fresh verification complete; review-fix commit pending at report-writing time.

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

## Sibling-bypass review remediation

Review found that the member-local paired seam, `replace_member_source_with_equipment_atomically()`, was still publicly callable without proof that the exact bound `PlayerRunContext` coordinator initiated the transaction. A direct caller could submit an arbitrary Strength source together with the current empty equipment source. Party sources, revision, caches, and signals changed while the configured requirement item retained stale disabled activation.

The paired seam now requires opaque coordinator authority:

- `PartyManager.bind_member_source_refresh_coordinator()` issues one fresh `RefCounted` identity only while no coordinator or authority is bound;
- `PlayerRunContext` privately retains that identity and passes it to the paired commit;
- the paired commit rejects missing, wrong, or stale identity before source validation, snapshots, or mutation;
- exact unbind requires both the coordinator Callable and the identical authority object;
- context reset and registry clear exact-unbind and discard the retained identity;
- `PartyManager.initialize()` invalidates both the prior coordinator and prior authority; and
- a late clear from an old registry cannot unbind a replacement coordinator because its authority identity is stale.

The paired seam also verifies both source owner IDs match the requested member. The optional default is rejection-only so a legacy three-argument direct call fails closed; there is no compatibility alias or convenience path that commits without authority.

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

### Accepted sibling-bypass RED

After removing one invalid test-fixture cleanup attempt, the PartyManager/non-equipment regression executed normally against the first Task 10K commit and returned:

```text
TEST_SUMMARY: FAIL (12 failures)
TASK10K_AUTHORITY_ACCEPTED_RED_EXIT_CODE=1
```

The assertion failures proved the missing fourth authority argument/token contract and the live bypass: direct paired commit installed arbitrary Strength, advanced the revision, emitted one member signal, replaced affected base/action caches, and left the newly eligible sword disabled with stale activation.

## Coverage

The final tests cover:

- explicit absence of `replace_member_sources_atomically()` and presence of the narrow replacement;
- missing, wrong, exact, and stale paired-commit authority behavior;
- exact coordinator bind/unbind ownership plus clear, replacement, duplicate-context, reinitialize, and late-clear lifecycle behavior;
- arbitrary non-equipment core sources, wrong source type, wrong canonical ID, wrong owner, null and wrong-Variant values;
- empty batch, non-integer key, unknown positive member, and zero/negative member-key results;
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

### Final review-remediation rerun

The final authority tree returned:

```text
TEST_SUMMARY: PASS (0 failures)
TASK10K_AUTHORITY_FINAL_FOCUSED_EXIT_CODE=0

TASK10J_ACTION_CACHE_SUMMARY: PASS members=24 hits=512 usec=1676
EQUIPMENT_ATTRIBUTE_APPLICATION_SUMMARY: PASS members=24 untouched=23 items=2
TASK10K_AUTHORITY_EQUIPMENT_24_EXIT_CODE=0

PROGRESSION_24_MEMBER_ISOLATION_PASS members=24 untouched=23
PROGRESSION_24_MEMBER_SUMMARY: PASS
TASK10K_AUTHORITY_PROGRESSION_24_EXIT_CODE=0

TEST_SUMMARY: PASS (166 suites)
TASK10K_AUTHORITY_HARDENED_FULL_EXIT_CODE=0
```

The review-remediation complete runner finished in 138.5 seconds and retained only the same established asserted diagnostics and warnings.

## Scope and hygiene

Task 10K changes are limited to:

- `scripts/party/party_manager.gd`
- `scripts/run/player_run_context.gd`
- `tests/unit/test_party_manager.gd`
- `tests/unit/test_non_equipment_activation_refresh.gd`
- `tests/unit/test_run_context_registry.gd`
- `.superpowers/sdd/task-10k-report.md`

`git diff --check` passed before report creation. The worktree's pre-existing untracked `.gd.uid` sidecars were not edited or staged. Task-specific APPDATA/LOCALAPPDATA directories remain ignored under `.superpowers/sdd` and are not commit scope.

## Concerns

No Task 10K functional concern remains. The batch API intentionally remains equipment-only; future multi-member non-equipment changes must use a genuine activation-aware multi-member coordinator instead of broadening this seam.
