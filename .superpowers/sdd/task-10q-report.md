# Task 10Q report: exact ownership preview and complete expansion parity

Status: **DONE**. Functional commit: **40e3cfdb3bc2b73a4beaebfa02f668fe222b86d6** (`fix: normalize source previews and class generation`). The evidence-only successor contains this report and the verification-document update; its final hash is reported in the handoff because a commit cannot contain its own hash.

## Scope and preflight

- Worktree: `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\equipment-attribute-application`, branch `feat/equipment-attribute-application`.
- Approved-design range at the functional head: `00d145d7b461dde8d2cf4b01b36d57fb5ee73852..40e3cfdb3bc2b73a4beaebfa02f668fe222b86d6`, 49 commits after the range start.
- Godot: `4.7.1.stable.official.a13da4feb` from the WinGet console executable.
- Preflight had zero tracked/index drift and the protected untracked UID baseline was 127 files / 2,503 bytes / SHA-256 `0a392c6cde37052bb7a87455d77ef9a6cf12a4bb5198e43aa9715952b3c23cd3`.
- The authoritative main checkout remained read-only at `39deef45c0b8fd338da74af16e31d67a0f2dcc63` with its two known tracked overlays in `scripts/party/party_manager.gd` and `scripts/party/party_member_state.gd`. Nothing was integrated.

## Implementation

`PartyMemberState._normalized_modifier_source_copy()` is now the single deep-copy and target-owner normalization path used by add, replace, and candidate effective-resolution preview. Public structural validation still sees the raw incoming owner, preserving the established rejection of malformed equipment ownership; only the effective candidate graph is normalized exactly as commit will normalize it. Foreign-owner non-equipment sources can therefore no longer hide from `StatResolver` during preview, while one finite owner-77 source remains reusable across members as independent source and modifier copies without caller mutation.

Strict regressions exercise add and replace with two individually finite `1.0e308` increased-damage modifiers whose normalized aggregate is non-finite. Both reject before mutation and preserve exact owned documents, caller bytes and owner, stat revision, base/action cache identity, signals, and actor health. The unbound path has no activation, equipment ownership, or item transaction to mutate; the widened context/activation/transition suites retain those applicable no-drift contracts.

All five retained expansion rows now exactly match canonical ordered capabilities. Paladin, Rogue, Frost Mage, and Marksman gained their missing equipment tags; Warlock was already exact. One compact loop proves exact generator-row/canonical/persisted equality and validates every real starter-loadout item against a generated capability projection.

The first semantically clean cold generator exposed byte drift because unconditional `ResourceSaver` rewrote property order and, in a tracked-only import, could remove serialized UID hints. A deterministic `class_matches_row()` checks every class field authored by the migration. Canonical rows now skip the save byte-for-byte, while stale rows still regenerate and validate. No canonical `data/` file changed in the functional commit.

## TDD evidence

- Accepted ownership/parity RED: exit **1** in **2.2s**, `TEST_SUMMARY: FAIL (43 failures)`. Both owner-77 operations committed and drifted state; four stale class rows failed exact equality and real starter eligibility.
- The first implementation run was a useful late RED: exit **1**, `FAIL (6 failures)`, exposing that normalizing before structural checks weakened wrong-owner equipment rejection.
- Corrected shared-boundary GREEN: exit **0** in **2.2s**, `TEST_SUMMARY: PASS (0 failures)`.
- The first cold generator exited `0` with correct semantics but all five class hashes differed, so it was rejected as byte-parity evidence.
- Accepted byte-no-op RED: exit **1** in **1.0s**, `FAIL (1 failure)` for the absent canonical-row matcher; GREEN exited **0** in **1.0s**, `PASS (0 failures)`.

## Verification

All worktree gates were sequential and used Task 10Q-local `APPDATA` / `LOCALAPPDATA` roots.

| Gate | Exit / duration | Exact result |
| --- | --- | --- |
| Current-worktree import | `0` / **17.3s** | eight established missing-UID cache regenerations; structural/shutdown scan clean |
| Task 10M runner probe | `0` / **1.2s** | `TASK10M_EMPTY_RUNNER_PROBE_SUMMARY: PASS open=1 list=1 zero=1 focused=1` |
| Expanded 40-suite matrix | `0` / **90.6s** | `TEST_SUMMARY: PASS (0 failures)`; sandbox SHA `c201fd5917d9958da63dacd8201e80d5911c0de51af367977d2a5ee57dd9defe` |
| Equipment/cache integration | `0` | `TASK10J_ACTION_CACHE_SUMMARY: PASS members=24 hits=512 usec=2069`; `EQUIPMENT_ATTRIBUTE_APPLICATION_SUMMARY: PASS members=24 untouched=23 items=2` |
| Progression integration | `0` | `PROGRESSION_24_MEMBER_ISOLATION_PASS members=24 untouched=23`; `PROGRESSION_24_MEMBER_SUMMARY: PASS` |
| Exact-functional-head full suite | `0` / **128.2s** | exactly one `TEST_SUMMARY: PASS (166 suites)` |
| Exact-functional-head startup | `0` / **14.6s** | `PARTY_FORGE_BOOT_OK` once; `PARTY_FORGE_CLASS_SELECTION_READY` once |

The 40-suite matrix covered owner normalization, effective-source construction, stat resolution, PartyManager, PlayerRunContext, activation/transition/assignment, action archetypes/cadence/estimates/execution, every retained expansion class/catalog/trait/presentation suite, real caster/heavy-melee/ranged equipment eligibility, ledger/page, storage/profile projections, tooltips, sandbox state, and logger teardown.

The exact-head full log was 108,864 bytes. It had one PASS summary and zero FAIL summary, `TEST_FAILURE`, raw `SCRIPT ERROR`, parser/loader failure, ObjectDB/resource/RID/PagedAllocator/orphan leak, fatal, crash, or access-violation marker. The progression parent and four children retain their documented dummy-renderer/ObjectDB/resource/allocator shutdown notices; the hardened full gate and startup were clean.

## Fresh cold generator proof

A brand-new tracked-only copy contained 2,388 current files. Fresh import exited **0** in **40.3s**. Class-expansion generation exited **0** in **1.2s**, emitted `PARTY_FORGE_CLASS_EXPANSION_SAVED attacks=5 classes=5`, and emitted zero starter-loadout or class-expansion diagnostic. SHA-256 equality was exact for every regenerated class:

- Paladin: `c88accb7e8bb299a675810f4b6d380b191e22caece52f9871719ef01fc2b0799`
- Rogue: `128601079bd0646ba44cc3160ac6ac7fa9d7c6359cd2392dae49fabf6c75cd80`
- Frost Mage: `47793164aaa1b29f41547879a59cf04e6829c3b3230d8bf887128b99db178244`
- Warlock: `247b643bf06c2d09182311d75db867da1341b2a7aad7b8478cfbc1bb26e2365d`
- Marksman: `c5306c2e796dc7a591c94b4f453998652a2923092ac0d60c902d0430009ecb02`

With `PARTY_FORGE_GENERATOR_PARITY_CANONICAL_ROOT` pointed at the authoritative worktree, cold exact parity and real starter eligibility exited **0** in **1.1s** with `TEST_SUMMARY: PASS (0 failures)`.

## Hygiene and remaining boundaries

Eight exact import-created sidecars were checked against their recorded byte lengths and SHA-256 allowlist before removal. The protected UID manifest returned exactly to 127 files / 2,503 bytes / SHA-256 `0a392c6cde37052bb7a87455d77ef9a6cf12a4bb5198e43aa9715952b3c23cd3`.

An initial inline cleanup attempt was blocked before execution and changed nothing. The reviewable exact-path cleanup then removed **24 top-level targets / 8,670 files / 167,848,066 logical bytes** below `.superpowers\sdd`, after checking zero tracked descendants and zero reparse points. Task 10Q scratch residue was zero, the helper was removed, `git diff --check` passed, and functional `data/` drift was zero.

Physical-controller acceptance and visible GPU-backed/pixel-level review remain deferred. The progression integration retains its documented standalone subprocess shutdown notices. This task does not integrate the branch into main.
