# Task 10P report: effective-source collision and exact Warlock generator parity

Status: **DONE**. Both Important findings in `task-10p-brief.md` were fixed test-first in the isolated `feat/equipment-attribute-application` worktree. Functional commit: **399a5de64f7fc8d37f9c001637c6ddc54561ab9d** (`fix: validate effective member source graph`). The evidence-only successor commit contains this report and the verification-document update; its exact hash is emitted in the handoff because a commit cannot embed its own final hash.

## Scope and preflight

- Worktree: `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\equipment-attribute-application`.
- Functional range: `429fc0716e3317df974a5f4b2cb8ec3d3e8c1ec6..399a5de64f7fc8d37f9c001637c6ddc54561ab9d`; approved-design range count is 47 commits after `00d145d7b461dde8d2cf4b01b36d57fb5ee73852`.
- Godot: `C:\Users\Jacob\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64_console.exe`, reporting `4.7.1.stable.official.a13da4feb`.
- Preflight had zero tracked/index diff, exactly 127 protected untracked `.gd.uid` files, and zero Godot process targeting this worktree.
- The authoritative main checkout stayed read-only at `39deef45c0b8fd338da74af16e31d67a0f2dcc63`, with the same two known tracked overlays in `scripts/party/party_manager.gd` and `scripts/party/party_member_state.gd`. Nothing was integrated.

## Root cause and implementation

Task 10O validated only the candidate member-owned source array. Runtime `_sources_for(member)` separately injected the class-rank source, every live eligible authored party-upgrade source, `party_upgrades`, and `active_traits`; `MemberStatResolutionService` then appended `attribute_projection_<member_id>` for its final pass. A user-owned source could therefore pass the owned-only check, commit and invalidate state, and collide only during later resolution.

The smallest shared seam now parameterizes the real source builder as `_sources_for_owned(member, owned_sources)`. Runtime `_sources_for(member)` delegates to it with the member's actual owned sources. Candidate validation preserves the canonical equipment owner/ID/uniqueness checks, constructs the effective graph through that same seam, and invokes the existing two-pass `MemberStatResolutionService.resolve()` before mutation. This catches actual current generated IDs and the derived attribute projection without a reserved-ID list and without mutating the member.

The regression table covers add and replace collisions for `class_rank_fighter` and `attribute_projection_1`, add collisions for `party_upgrades` and `active_traits`, and the live dynamic `upgrade:vanguard_wall:party` source created through `UpgradeApplicationService`. Rejection preserves exact owned source documents, stat revision, base/action cache identity, and signals. Legitimate unbound custom add/replace and canonical equipment initialization remain green; Task 10O's runtime activation/ownership/item/health no-drift coverage remains green in the widened and complete suites.

The Warlock class-expansion row now exactly equals the canonical capability array: `chaos`, `life_steal`, `projectile`, `armour_light`, `occult_wand`, `occult_grimoire`; `ranged` remains absent. The parity test uses exact ordered array equality and validates the actual canonical Warlock against real light armour, occult wand, and occult grimoire definitions. No canonical `data/` file required another edit.

## Strict TDD evidence

Tests were written before production changes and run together:

```powershell
& $godot --headless --path . --quit-after 1200 --script res://tests/focused_test_runner.gd -- `
  tests/unit/test_party_manager.gd `
  tests/unit/test_increment2_generator_parity.gd
```

- Accepted RED: exit **1**, **2.035s**, `TEST_SUMMARY: FAIL (30 failures)`. Failures were the public collision commits/no-drift assertions and exact three-versus-six Warlock capability mismatch; there was no test-script or parser failure.
- GREEN after the minimal shared-seam and row changes: exit **0**, **1.968s**, `TEST_SUMMARY: PASS (0 failures)`.
- Post-GREEN explicit cases for the two always-generated aggregate IDs (`party_upgrades`, `active_traits`) use the same table and production seam; `test_party_manager.gd` remained `PASS (0 failures)`.

## Verification

All accepted worktree gates used isolated Task 10P `APPDATA` / `LOCALAPPDATA` roots beneath `.superpowers\sdd`.

| Gate | Exit / duration | Exact result |
| --- | --- | --- |
| Isolated authoritative import | `0` / **17.063s** | eight established missing-UID cache regenerations; structural/shutdown scan clean |
| Task 10M runner probe | `0` / **1.091s** | `TASK10M_EMPTY_RUNNER_PROBE_SUMMARY: PASS open=1 list=1 zero=1 focused=1` |
| Widened 25-suite matrix | `0` / **18.272s** | `TEST_SUMMARY: PASS (0 failures)` |
| Equipment/cache integration | `0` / **1.602s** | `TASK10J_ACTION_CACHE_SUMMARY: PASS members=24 hits=512 usec=1648`; `EQUIPMENT_ATTRIBUTE_APPLICATION_SUMMARY: PASS members=24 untouched=23 items=2` |
| Progression integration | `0` / **15.166s** | `PROGRESSION_24_MEMBER_ISOLATION_PASS members=24 untouched=23`; `PROGRESSION_24_MEMBER_SUMMARY: PASS` |
| Exact-functional-head complete suite | `0` / **128.1s tool wall time** | exactly one `TEST_SUMMARY: PASS (166 suites)` |
| Exact-functional-head startup | `0` / **14.383s** | `PARTY_FORGE_BOOT_OK` once; `PARTY_FORGE_CLASS_SELECTION_READY` once |

The 25-suite matrix explicitly covered attribute projection, member resolution, action archetypes/cadence/estimates/execution, equipment modifier projection/activation/transition/assignment, PartyManager, PlayerRunContext, health, registry/setup/lifecycle refresh, generator parity, expanded class content, actual catalog, ledger/page, caster equipment eligibility, profile loadout assignment, upgrade application, and logger teardown.

The exact-head complete log was 106,424 bytes with a 127.791s file span. It contained exactly one PASS summary, 67 asserted negative-path domain errors and ten established warnings, and zero FAIL summary, `TEST_FAILURE`, raw `SCRIPT ERROR`, parser/loader failure, ObjectDB/resource/RID/PagedAllocator/orphan leak, fatal, crash, or access-violation marker. The progression parent and four children retain five documented sets of three dummy-mesh RID, 130 ObjectDB, 114 resource, and medium/small PagedAllocator notices; the hardened release gate and isolated startup were shutdown-clean.

## Fresh cold generator proof

A tracked-only cold copy contained 2,387 current worktree files. Fresh cold import exited **0** in **46.877s** with a clean structural/shutdown scan. `migrate_class_expansion_data.gd` then exited expected **1** in **1.603s** after writing resources, with exactly **28** known non-Warlock starter-loadout diagnostics and **zero** diagnostic naming `data/classes/warlock.tres`. This is seven fewer diagnostics than Task 10O because the five Warlock light-armour items, wand, and grimoire now retain eligibility after generation.

The regenerated cold Warlock resource contained exactly:

```text
capability_tags = [chaos, life_steal, projectile, armour_light, occult_wand, occult_grimoire]
```

With `PARTY_FORGE_GENERATOR_PARITY_CANONICAL_ROOT` pointed at the authoritative worktree, the cold exact-parity and real-equipment eligibility suite exited **0** in **0.545s** with `TEST_SUMMARY: PASS (0 failures)`.

## Hygiene and limitations

Initial exact-path cleanup validated and removed **17 top-level Task 10P targets / 4,345 files / 85,751,757 logical bytes** beneath `.superpowers\sdd`; all had zero tracked descendants and zero reparse points. The exact-head settings/log roots were later removed under the same boundary. Scratch residue was zero, temporary cleanup helpers were deleted, and zero Godot process targeted the worktree.

Only the eight exact hash-allowlisted import-created sidecars were removed. The protected manifest returned to exactly **127 files / 2,503 bytes / SHA-256 `0a392c6cde37052bb7a87455d77ef9a6cf12a4bb5198e43aa9715952b3c23cd3`**. `git diff --check` passed. Functional scope is exactly four tracked files (`party_manager.gd`, two unit suites, and `class_expansion_rows.gd`); `data/` drift is zero.

Remaining limitations:

- The class-expansion generator still reports 28 pre-existing starter-loadout capability gaps for Paladin, Rogue, Frost Mage, and Marksman; Warlock now has zero such diagnostic.
- Physical-controller acceptance and visible GPU-backed/pixel-level manual review remain deferred.
- The progression integration retains its documented standalone subprocess shutdown notices.
- This task does not integrate the branch into main.
