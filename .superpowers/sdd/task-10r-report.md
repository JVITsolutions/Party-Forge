# Task 10R report: complete unbound owned-action validation

Status: **DONE**. Functional commit: **2f00ec14a224ca0da382141f3153386eb3ac128f** (`fix: validate unbound owned actions`). The evidence successor contains this report and the exact-head verification update; its final hash is reported in the handoff.

## Scope and root cause

- Worktree: `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\equipment-attribute-application`, branch `feat/equipment-attribute-application`.
- Approved-design range at the functional head: `00d145d7b461dde8d2cf4b01b36d57fb5ee73852..2f00ec14a224ca0da382141f3153386eb3ac128f`, 51 commits after the range start.
- The authoritative main checkout remained read-only at `39deef45c0b8fd338da74af16e31d67a0f2dcc63` with its two known tracked overlays. Nothing was integrated.

Task 10Q made candidate base resolution use the exact normalized effective graph, but `PartyManager._validate_candidate_member_sources()` still passed empty action tags only. A source constrained to an owned action could therefore be invisible to base resolution, commit, invalidate state, and make the next action snapshot fail. Coordinated refresh, equipment transition, and profile assignment already used `CandidateActionValidationService`; the unbound path was the remaining boundary mismatch.

## Implementation and TDD

After normalized effective base resolution succeeds, PartyManager now passes that same graph through `CandidateActionValidationService.validate()`. The service owns action enumeration, authored-action validation, action-tagged member resolution, geometry/cadence, and combat-estimate validation. PartyManager supplies configured `damage_types` when present and `GameCatalog.DAMAGE_TYPES` otherwise.

The strict regression reuses the established action-only fixture: four individually finite `MORE 1.0e100` cooldown modifiers gated by `task10d_action_only`. Unbound add with configured damage types and replace with the canonical fallback both reject before mutation. Exact owned documents, caller bytes/owner 77, revision, base and matching-action cache identities, signals, and actor health remain unchanged. A finite owner-77 action-tagged source succeeds as an independent defensive copy, leaves base and the other owned action unchanged, and changes only the matching owned action.

- Accepted RED: exit **1** in **2.2s**, `TEST_SUMMARY: FAIL (12 failures)`; both overflow operations committed and drifted state.
- Minimal GREEN: exit **0** in **2.2s**, `TEST_SUMMARY: PASS (0 failures)`.
- The first 19-suite matrix was a useful late RED: exit **1** in **14.1s**, `FAIL (21 failures)`. Two resume-corruption tests still seeded invalid action/geometry state through public add. They now use their existing no-invalidation test subclass so resume rejection remains independently covered. The affected pair passed in **3.4s**, and the complete matrix passed in **14.1s**.
- The first exact full run was another useful late RED: exit **1** in **131.2s**, `FAIL (14 failures)`. Two unrelated synthetic fixtures had no primary action; assigning the canonical Fighter action restored valid source-mutation preconditions. Their three-suite rerun passed in **5.6s**.

## Verification

| Gate | Exit / duration | Exact result |
| --- | --- | --- |
| Isolated import | `0` / **17.3s** | eight known cache-created UIDs; structural/shutdown scan clean |
| Task 10M runner probe | `0` / **1.2s** | `PASS open=1 list=1 zero=1 focused=1` |
| Final 19-suite focused matrix | `0` / **14.1s** | `TEST_SUMMARY: PASS (0 failures)` |
| Equipment/cache integration | `0` | `TASK10J_ACTION_CACHE_SUMMARY: PASS members=24 hits=512 usec=1650`; equipment PASS with 23 untouched and two items |
| Progression integration | `0` | 24-member isolation and summary PASS |
| Exact-functional-head full suite | `0` / **132.0s** | exactly one `TEST_SUMMARY: PASS (166 suites)` |
| Exact-functional-head startup | `0` / **14.7s** | boot and class-selection readiness markers once each |

The final full log was 111,602 bytes and had zero FAIL summary, `TEST_FAILURE`, raw `SCRIPT ERROR`, parser/loader failure, ObjectDB/resource/RID/PagedAllocator/orphan leak, fatal, crash, or access-violation marker.

## Cold-reuse proof and hygiene

Task 10Q's fresh cold generator evidence is reusable. This exact command exited `0` with no diff:

```powershell
git diff --exit-code c340d85f9596156ba083148ddab129e94cac0390..2f00ec14a224ca0da382141f3153386eb3ac128f -- tools data tests/unit/test_increment2_generator_parity.gd
```

Thus Task 10R changes no generator, generated data, or generator-parity input. Its focused parity suite passed, and Task 10Q remains the current fresh import/generator/hash proof.

Eight exact import-created UIDs were byte/hash allowlisted before removal. The protected manifest returned to 127 files / 2,503 bytes / SHA-256 `0a392c6cde37052bb7a87455d77ef9a6cf12a4bb5198e43aa9715952b3c23cd3`. Exact-path cleanup removed **17 targets / 41 files / 4,047,706 logical bytes** beneath `.superpowers\sdd` after checking zero tracked descendants and reparse points. Task 10R scratch residue and worktree Godot processes were zero; tracked/index state and `git diff --check` were clean; functional `data/` drift was zero.

Physical-controller acceptance and visible GPU-backed/pixel-level review remain deferred. No main integration was performed.
