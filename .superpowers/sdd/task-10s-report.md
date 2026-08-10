# Task 10S report: transactional party-upgrade validation

Status: **DONE**. Functional commit: **3ef387a3b14dcb262e106ec2a52351f9c8060dde** (`fix: validate party upgrades transactionally`). The evidence successor contains this report and the exact-head verification update; its final hash is reported in the handoff.

## Scope and root cause

- Worktree: `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\equipment-attribute-application`, branch `feat/equipment-attribute-application`.
- The authoritative main checkout remained read-only at `39deef45c0b8fd338da74af16e31d67a0f2dcc63` with its two known tracked overlays. Nothing was integrated.
- `_commit_party_upgrade()` previously published rank, definition, and generated-source maps before invalidating every member. Unlike member/equipment source producers, it never resolved the prospective effective base or owned-action graphs. A previously owned source could therefore reserve the future generated ID, and individually finite party effects could combine into a non-finite base or action result after publication.

## Implementation and strict TDD

PartyManager now duplicates and stages all three party-upgrade maps, replaces only the requested upgrade in those candidate maps, and derives the affected-member union from the previous and prospective eligibility definitions. Every affected member is validated before publication. The existing normalized candidate validation path receives the staged maps, builds the exact effective graph through the refactored `_sources_for_owned` seam, resolves aggregate base stats, and calls `CandidateActionValidationService` for every owned action. Only after the entire batch succeeds are the live dictionaries assigned and the existing single all-member invalidation plus `upgrades_changed` signal performed. There is no mutate/rollback path and no parallel reserved-ID registry.

The strict regressions cover reverse-order `upgrade:vanguard_wall:party` collision, two individually finite `INCREASED 1.0e308` effects combining into aggregate overflow, four action-tagged `MORE 1.0e100` effects combining into owned-action overflow, and a two-member batch whose later eligible member holds the generated ID. Rejections preserve exact party rank/definition/source documents, every owned member-source document, catalog/caller resources, revision, base/action cache identities, signal streams, and actor health. A legitimate two-rank party upgrade still succeeds with one shared revision, one ordered stat notification per member, one upgrade notification, one stable generated source, and cumulative resolved values per rank.

- Accepted RED: exit **1** in **1.972s**, `TEST_SUMMARY: FAIL (30 failures)`. All four invalid operations returned success and drifted party maps, revision, caches, and signals; the legitimate rank semantics passed.
- Minimal GREEN: exit **0** in **1.881s**, `TEST_SUMMARY: PASS (0 failures)`.
- Final 19-suite focused matrix: exit **0** in **17.811s**, `TEST_SUMMARY: PASS (0 failures)` with zero `TEST_FAILURE` or raw `SCRIPT ERROR`.

## Verification

| Gate | Exit / duration | Exact result |
| --- | --- | --- |
| Isolated import | `0` / **17.250s** | eight known cache-created UIDs only; structural scan completed |
| Task 10M runner probe | `0` / **1.122s** | `TASK10M_EMPTY_RUNNER_PROBE_SUMMARY: PASS open=1 list=1 zero=1 focused=1` |
| Final 19-suite matrix | `0` / **17.811s** | `TEST_SUMMARY: PASS (0 failures)` |
| Equipment/cache integration | `0` / **1.597s** | `TASK10J_ACTION_CACHE_SUMMARY: PASS members=24 hits=512 usec=1638`; equipment PASS with 23 untouched and two items |
| Progression integration | `0` / **16.547s** | 24-member isolation and summary PASS |
| Exact-functional-head full suite | `0` / **131.709s** | exactly one `TEST_SUMMARY: PASS (166 suites)` |
| Exact-functional-head startup | `0` / **4.004s** | boot and class-selection readiness markers once each |

The accepted full log was 122,198 bytes and had zero FAIL summary, `TEST_FAILURE`, raw `SCRIPT ERROR`, parser/loader failure, ObjectDB/resource/RID/PagedAllocator/orphan leak, fatal, crash, or access-violation marker. The startup log had the two required markers exactly once and the same forbidden-marker scan was empty. One preliminary full attempt used a 120-second shell budget and was terminated before the known approximately 132-second suite duration; it had no surviving process and is not credited as test evidence. The unchanged functional head was rerun with a 240-second budget for the accepted result above.

## Cold reuse and hygiene

Task 10Q's fresh cold generator evidence is reusable because this exact command exited `0` with no diff:

```powershell
git diff --exit-code e9c2f17b9081d43fa8bc742a7e94670571f93370..3ef387a3b14dcb262e106ec2a52351f9c8060dde -- tools data tests/unit/test_increment2_generator_parity.gd
```

The focused generator-parity suite also passed. Task 10S changes no generator, generated data, canonical data, or parity input.

The eight import-created sidecars were compared against the pre-import path snapshot and recorded by exact length and SHA-256 before removal. The protected UID manifest returned to 127 files / 2,503 bytes / SHA-256 `0a392c6cde37052bb7a87455d77ef9a6cf12a4bb5198e43aa9715952b3c23cd3`. Exact-path cleanup removed **21 targets / 42 files / 4,020,583 logical bytes** below `.superpowers\sdd` after proving zero tracked descendants and reparse points. Task 10S scratch residue and worktree Godot processes were zero; tracked/index state, `git diff --check`, and functional `data/` drift were clean.

Physical-controller acceptance and visible GPU-backed/pixel-level review remain deferred. No main integration was performed.
