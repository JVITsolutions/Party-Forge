# Task 10T report: transactional recruitment validation

Status: **DONE**. Functional commit: **49c143b0fcc54a802db945632eccb40eca3cc946** (`fix: validate recruitment transactionally`). The evidence successor contains this report and the exact-head verification update; its final hash is reported in the handoff.

## Scope and root cause

- Worktree: `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\equipment-attribute-application`, branch `feat/equipment-attribute-application`.
- The authoritative main checkout remained read-only at `39deef45c0b8fd338da74af16e31d67a0f2dcc63` with its two known tracked overlays. Nothing was integrated.
- `recruit()` previously called `_append_member()` directly. That path appended the member, published its class rank and recalculated trait tiers before any aggregate base-stat or owned-action validation. A recruit could therefore inherit an active capability-gated party upgrade that made it invalid, or activate a composition trait that made the recruit or a later existing member invalid, after irreversible observable publication.

## Implementation and strict TDD

`recruit()` now builds the same deterministic candidate member without appending it, duplicates the current class-rank state, and computes trait tiers from a prospective member list. Every member in that prospective party is validated before publication. The validator receives the member object plus staged ranks and tiers, normalizes owned sources through the established `PartyMemberState` helper, builds the exact effective source graph through the shared party-upgrade source seam, resolves aggregate base stats, and calls `CandidateActionValidationService` for every owned action. There is no mutate/rollback path and no simplified parallel formula.

After the whole batch passes, recruitment appends the candidate, publishes the staged ranks and tiers, performs exactly one all-member invalidation, emits `active_traits_changed` only when the tiers changed, and finally emits `member_added`. A tier-changing second Fighter therefore retains exact event order `stats:1`, `stats:2`, `traits`, `member:2`.

The strict regressions cover a previously safe caster-only party upgrade rejecting a future canonical Mage, direct composition-trait overflow, and a tier transition that leaves the new member valid but makes a later existing member non-finite. Rejections preserve exact membership/name/ID/source documents, class ranks, active tiers, party-upgrade rank/definition/source documents, caller class resources, stat revision, base/action cache identities, signal streams, capacity state, and bound actor health. Positive regressions prove finite party upgrades reach future recruits, tier changes retain one-invalidation signal order, and null/capacity rejections remain atomic.

- Accepted RED: exit **1** in **2.339s**, `TEST_SUMMARY: FAIL (23 failures)`. All three invalid recruits returned success and drifted membership plus their affected ranks/tiers/revision/caches/signals. Positive and input-rejection contracts already passed.
- Minimal GREEN: exit **0** in **3.271s**, `TEST_SUMMARY: PASS (0 failures)`.
- Final 19-suite focused matrix: exit **0** in **20.762s**, `TEST_SUMMARY: PASS (0 failures)` with zero `TEST_FAILURE` or raw `SCRIPT ERROR`.
- Preliminary RED iterations 1-6 are not credited: they exposed test parse/helper defects or an invalid later-member setup rather than the production defect. `task-10t-red7.log` is the sole accepted RED.

## Verification

| Gate | Exit / duration | Exact result |
| --- | --- | --- |
| Isolated import | `0` / **5.051s** | eight known cache-created UIDs only; structural scan completed |
| Task 10M runner probe | `0` / **1.115s** | `TASK10M_EMPTY_RUNNER_PROBE_SUMMARY: PASS open=1 list=1 zero=1 focused=1` |
| Final 19-suite matrix | `0` / **20.762s** | `TEST_SUMMARY: PASS (0 failures)` |
| Equipment/cache integration | `0` / **2.583s** | `TASK10J_ACTION_CACHE_SUMMARY: PASS members=24 hits=512 usec=1757`; equipment PASS with 23 untouched and two items |
| Progression integration | `0` / **15.825s** | all four load-size markers, 24-member isolation, and summary PASS |
| Exact-functional-head full suite | `0` / **156.724s** | exactly one `TEST_SUMMARY: PASS (166 suites)` |
| Exact-functional-head startup | `0` / **4.084s** | boot and class-selection readiness markers once each |

The accepted full log was 130,444 bytes and had zero FAIL summary, `TEST_FAILURE`, raw `SCRIPT ERROR`, parser/loader failure, ObjectDB/resource/RID/PagedAllocator/orphan leak, fatal, crash, or access-violation marker. The startup log had the two required markers exactly once and the same forbidden-marker scan was empty. Focused negative-path logs retain expected asserted resolver errors and the established standalone-run 18 ObjectDB / 5 resource shutdown notice; those are not represented as shutdown-clean.

## Cold reuse and hygiene

The previous fresh cold generator evidence is reusable because this exact command exited `0` with no diff:

```powershell
git diff --exit-code 8490610fed3d484d7147b297d0e460ff63076e78..49c143b0fcc54a802db945632eccb40eca3cc946 -- tools data tests/unit/test_increment2_generator_parity.gd
```

The focused generator-parity suite also passed. Task 10T changes no generator, generated data, canonical data, or parity input.

The eight import-created sidecars were compared against the pre-import path snapshot and hash-allowlisted before exact-path removal. The protected UID manifest returned to 127 files / 2,503 bytes / SHA-256 `0a392c6cde37052bb7a87455d77ef9a6cf12a4bb5198e43aa9715952b3c23cd3`. Task 10T scratch residue and worktree Godot processes were zero; tracked/index state, `git diff --check`, and functional `data/` drift were clean.

Physical-controller acceptance and visible GPU-backed/pixel-level review remain deferred. No main integration was performed.
