# City Access snapshot acceptance and rollback qualification

Date: 2026-08-27. This record describes a retained-feature-worktree qualification only. It does not activate the candidate, merge either branch, push, alter `main`, or create a release.

## Exact inputs and revision sequence

| Worktree | Branch | Qualification-input HEAD |
| --- | --- | --- |
| Party Forge | `feature/latticewright-v3-portfolio` | `33dd26ee91c24e2ed93e99cb4bef92fadff6b1d8` |
| Latticewright | `feature/v3-graph-portals-party-forge` | `12408a727b3a49aab62bd8c6a70266abdc445d2e` |

`33dd26e` is explicitly the pre-Task-8 Party Forge qualification-input HEAD. The initial Task 8 acceptance commit is `2b785270245595079fc8ca9426b00029ebc5bd83` (`test: qualify City access snapshot rollback`). This documentation correction follows that initial acceptance commit, so the input identity must not be read as the branch's final HEAD.

Fresh SHA-256 values:

| Artifact | SHA-256 |
| --- | --- |
| `design/progression/latticewright/party-forge-city-access.pstree` | `3c459454210de71e766c80d57d51825977811990678b53579a7d8573299df721` |
| `design/progression/latticewright/party-forge-city-access.pstree.json` runtime-v3 source | `bb3abd94d6b86716d3c39840deef460e20596abb858ba6abd4535067d664ff78` |
| `data/world/access/party-forge-city-access.snapshot.json` | `ca046f55eaaf28ff050c6d7ab240232d5663820d88c1551160a7a2c4476b6a55` |

The checked-in snapshot is 2,539 bytes. A fresh importer replay exited `0` in `0.389s` and emitted exactly:

```text
PARTY_FORGE_CITY_ACCESS_IMPORT status=UNCHANGED adapter=latticewright-runtime-v3-city-access stage=compare
```

This is repeat-import byte parity: the production importer canonically translated the exact runtime-v3 bytes and found no write necessary.

## Party Forge acceptance

The dedicated runner was first deliberately RED: exit `1` in `0.293s` with `CITY_ACCESS_SNAPSHOT_ACCEPTANCE_PENDING`; no production source was changed. The completed runner then executed the whole acceptance flow in one headless process:

```powershell
& $godot --headless --path . --quit-after 600 --script res://tests/integration/city_access_snapshot_runner.gd
```

The initial acceptance run exited `0` in `1.135s` and printed the sole success marker:

```text
CITY_ACCESS_SNAPSHOT_ACCEPTANCE_OK locations=7 profiles=7 rollback=legacy
```

In that one process it strictly read and SHA-256 hashed the checked-in runtime-v3 source; translated it with `LatticewrightRuntimeV3CityAccessImporter`; compared canonical candidate bytes with the checked-in snapshot; loaded the production snapshot; and evaluated all seven locations for seven profiles: NOT_STARTED, IN_PROGRESS, COMPLETED, and one profile for each individual permanent unlock. Before/after `ProfileState.to_dictionary()` values and `ProfileCodec.encode()` UTF-8 bytes were equal for every profile. It also proved default flag-off `LEGACY`; Player Mode plus flag-on `LEGACY` with `candidate_requires_developer_mode`; Developer Mode plus flag-on `CANDIDATE`; an injected invalid snapshot result `CANDIDATE_FAILED` with no fallback; immediate flag-off `LEGACY` rollback; and present/loadable format-1 City data through `PassiveTreeLoader` at `data/passive_trees/city/party-forge-city.pstree.json`.

The required focused batch was initially run in `17.338s` and exited `0`. The evidence-correction replay below retained a new capture and reproduced that result in `17.469s`.

```powershell
& $godot --headless --path . --quit-after 1200 --script res://tests/focused_test_runner.gd -- tests/unit/test_atomic_profile_store.gd tests/unit/test_strict_json_document_reader.gd tests/unit/test_generated_json_document_writer.gd tests/unit/test_city_access_snapshot_loader.gd tests/unit/test_latticewright_runtime_v3_city_access_importer.gd tests/unit/test_latticewright_access_import_cli.gd tests/unit/test_city_access_evaluator.gd tests/unit/test_party_forge_settings.gd tests/unit/test_settings_screen.gd tests/unit/test_city_access_provider.gd tests/unit/test_city_access_generated_artifacts.gd tests/unit/test_passive_tree_loader.gd
```

```text
TEST_SUMMARY: PASS (0 failures)
```

The correction replay also ran the dedicated integration command again: exit `0` in `1.138s`, exactly one `CITY_ACCESS_SNAPSHOT_ACCEPTANCE_OK locations=7 profiles=7 rollback=legacy` marker.

The full Party Forge runner was run from this retained worktree:

```powershell
& $godot --headless --path . --quit-after 2400 --script res://tests/test_runner.gd
```

The initial capture exited `0` with exactly one `TEST_SUMMARY: PASS (227 suites)` marker and had a `236.062s` captured-output interval (from `2026-08-27T06:21:55.6636262-04:00` to the exit marker at `2026-08-27T06:25:51.7253123-04:00`; wrapper launch preceded capture by less than one second). The evidence-correction replay ran the identical command from the retained worktree, exited `0` in `236.573s`, and retained its command capture.

The diagnostic-line total is expected to vary between replay environments and runs; it is not an invariant gate. The initial capture counted 97 `ERROR:` and 11 `WARNING:` lines. An independent review replay counted 98 `ERROR:` and 11 `WARNING:` lines. The retained correction replay counted 97 `ERROR:` and 11 `WARNING:` lines. The invariant gates were true in every cited full capture: exactly one `TEST_SUMMARY: PASS (227 suites)` and zero `TEST_SUMMARY: FAIL`, `TEST_FAILURE`, `SCRIPT ERROR`, `Parse Error`, `Failed to load script`, and `No loader found` markers.

Expected negative-path examples include intentional non-finite-stat rejection (`PARTY_FORGE_STAT_ERROR source=nonfinite_crit`), invalid damage-boundary rejection (`PARTY_FORGE_DAMAGE_ERROR`), and the exact weighted-content fixture diagnostic (project-relative paths only): `PARTY_FORGE_WEIGHTED_CONTENT_BUILD_ERROR stage=base_manifest id=hawkeye_band reason=loaded resource path must equal res://data/equipment/bases/greenwood/hawkeye_band.tres, got res://data/equipment/bases/greenwood/not_hawkeye_band.tres`. These are exercised failure paths, not test-runner failures.

## Latticewright source qualification

All commands ran in `E:\Projects\Passive Skill Tree Creator\.worktrees\v3-graph-portals-party-forge` with `npm.cmd`:

| Command | Result |
| --- | --- |
| `node --test scripts/party-forge/create-party-forge-portfolio.test.mjs` | exit `0`, 5/5 pass, `0.220s` |
| `npm.cmd test -- tests/party-forge/portfolio.test.ts src/core/project-v3/runtime-codec.test.ts src/core/project-v3/resolve-runtime.test.ts` | exit `0`, 3 files / 20 tests pass, `2.116s` |
| `npm.cmd run typecheck` | exit `0`, `6.621s` |
| `npm.cmd run lint` | exit `0`, `4.948s` |

## Task 9 hardening refresh

The final audit findings were corrected on the retained Party Forge worktree
without changing the checked-in authoring, runtime-v3, or snapshot artifacts.
Fresh qualification ran at these exact revisions:

| Worktree | Branch | HEAD |
| --- | --- | --- |
| Party Forge | `feature/latticewright-v3-portfolio` | `1194a362fe1c396dfd41fdd2dcf9d8b04b11fbd4` |
| Latticewright | `feature/v3-graph-portals-party-forge` | `12408a727b3a49aab62bd8c6a70266abdc445d2e` |

Task 9 made snapshot-v1 producer provenance bounded and opaque at runtime,
validated the exact canonical bytes against the production 1 MiB boundary,
checked path length before allocation, and replaced the generated writer's
delete/promote window with a verified recovery record and truthful
`unchanged`/`rejected`/`committed`/`indeterminate` states. The fixed writer now
owns recovery, comparison, replacement, verification, and rollback; the CLI no
longer performs a second restoration protocol. An independent task review
approved the complete `3da442b..1194a36` range after the recovery-before-
dependency-check regression was corrected.

Fresh Party Forge results:

| Gate | Result |
| --- | --- |
| Dedicated integration runner | exit `0`, `2.137s`, `CITY_ACCESS_SNAPSHOT_ACCEPTANCE_OK locations=7 profiles=7 rollback=legacy` |
| Exact 12-suite focused batch | exit `0`, `25.031s`, `TEST_SUMMARY: PASS (0 failures)` |
| Explicit importer replay | exit `0`, `0.806s`, `UNCHANGED`; snapshot SHA-256 unchanged before/after |
| Complete Party Forge suite | exit `0`, `382.809s`, exactly one `TEST_SUMMARY: PASS (227 suites)` |

The fresh complete-suite log has SHA-256
`e6817b404af829fac6302a26df70f86ed0fd64d1348989edd43de241ffd66c12`.
It contains zero `TEST_SUMMARY: FAIL`, `TEST_FAILURE`, `SCRIPT ERROR`,
`Parse Error`, `Failed to load script`, and `No loader found` markers. Its 98
`ERROR:` and 11 `WARNING:` lines are exercised negative-path diagnostics; their
count is contextual rather than an invariant gate.

Fresh Latticewright producer results:

| Command | Result |
| --- | --- |
| `node --test scripts/party-forge/create-party-forge-portfolio.test.mjs` | exit `0`, 5/5 pass, `0.614s` |
| `npm.cmd test -- tests/party-forge/portfolio.test.ts src/core/project-v3/runtime-codec.test.ts src/core/project-v3/resolve-runtime.test.ts` | exit `0`, 3 files / 20 tests pass, `30.044s` |
| `npm.cmd run typecheck` | exit `0`, `12.234s` |
| `npm.cmd run lint` | exit `0`, `23.750s` |

Fresh artifact identity remained:

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `design/progression/latticewright/party-forge-city-access.pstree` | 11,055 | `3c459454210de71e766c80d57d51825977811990678b53579a7d8573299df721` |
| `design/progression/latticewright/party-forge-city-access.pstree.json` | 9,972 | `bb3abd94d6b86716d3c39840deef460e20596abb858ba6abd4535067d664ff78` |
| `data/world/access/party-forge-city-access.snapshot.json` | 2,539 | `ca046f55eaaf28ff050c6d7ab240232d5663820d88c1551160a7a2c4476b6a55` |

## Final-review compatibility and recovery refresh

The subsequent whole-branch review found that CLI source preflight could bypass
pending generated-write recovery, that the producer no longer reproduced the
accepted runtime bytes for 15 retained portfolio projects, and three related
coverage issues. Those findings were corrected on the retained feature
worktrees. The only canonical artifact change was separately approved: City
Access authoring `fieldIds` were reordered to the public Latticewright codec's
ordinal order. This changed no semantic value or byte count. Runtime-v3 and the
Party Forge snapshot remained byte-identical.

Implementation revisions qualified here:

| Worktree | Branch | Implementation HEAD |
| --- | --- | --- |
| Party Forge | `feature/latticewright-v3-portfolio` | `5e1c46a` |
| Latticewright | `feature/v3-graph-portals-party-forge` | `575ada0` |

An independent fix review reported no Critical, Important, or Minor findings.
Root then reran the following fresh gates on 2026-08-28:

| Gate | Result |
| --- | --- |
| Latticewright producer tests | exit `0`, 6/6 pass, `0.514s` wall time |
| Latticewright focused portfolio test | exit `0`, 1 file / 3 tests pass, `2.460s` wall time |
| Latticewright typecheck | exit `0`, `7.499s` wall time |
| Latticewright lint | exit `0`, `6.095s` wall time |
| Party Forge exact 12-suite batch | exit `0`, `18.165s`, `TEST_SUMMARY: PASS (0 failures)` |
| Party Forge integration runner | exit `0`, `1.351s`, `CITY_ACCESS_SNAPSHOT_ACCEPTANCE_OK locations=7 profiles=7 rollback=legacy` |
| Explicit importer replay | exit `0`, `0.477s`, `UNCHANGED` |
| Complete Party Forge suite | exit `0`, `240.806s`, exactly one `TEST_SUMMARY: PASS (227 suites)` |

The complete-suite marker audit contained zero `TEST_SUMMARY: FAIL`,
`TEST_FAILURE`, `SCRIPT ERROR`, `Parse Error`, `Failed to load script`, and `No
loader found` markers. Its 98 `ERROR:` and 11 `WARNING:` lines were the expected
negative-path diagnostics and are not invariant counts.

Final artifact identity for this refresh:

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `design/progression/latticewright/party-forge-city-access.pstree` | 11,055 | `49e990eb09720a5cbd590f3bcdc8d732b3b578aa8a61c77a11d7ed118409f10a` |
| `design/progression/latticewright/party-forge-city-access.pstree.json` | 9,972 | `bb3abd94d6b86716d3c39840deef460e20596abb858ba6abd4535067d664ff78` |
| `data/world/access/party-forge-city-access.snapshot.json` | 2,539 | `ca046f55eaaf28ff050c6d7ab240232d5663820d88c1551160a7a2c4476b6a55` |

The producer's fixed-hash regression preserves all 32 accepted authoring and
runtime files for the retained 16-project portfolio. New runtime requirement
projection and strict runtime canonicalization apply only to the separate City
Access project. The generated writer owns recovery before every CLI source
preflight, and unresolved recovery reports `INDETERMINATE` without source or
write work.

## Final recovery-contract correction refresh

The complete-branch audit then identified that recovery preflight overloaded
the final `unchanged` write state for both no pending transaction and verified
rollback. The user approved a bounded correction: recovery now has a distinct
`none`/`rolled_back`/`candidate_verified`/`indeterminate` resolution contract.
The three safe resolutions continue into ordinary source processing and the
fixed writer, so final `UNCHANGED`, `REJECTED`, or `COMMITTED` status is emitted
only after actual candidate comparison or promotion. Only an unprovable
recovery aborts before source work as `INDETERMINATE`.

Implementation revisions qualified here:

| Worktree | Branch | Implementation HEAD |
| --- | --- | --- |
| Party Forge | `feature/latticewright-v3-portfolio` | `96c61233f10a215afb58f685e1f5fa19f89301c4` |
| Latticewright | `feature/v3-graph-portals-party-forge` | `26098c0da6fa5c60597fc414cd2b4db79d0b1114` |

The same correction also declared the City Access builder in the producer's
TypeScript module surface, clarified the generated README as a retained
16-project portfolio plus separate City Access pair, removed the test-only
provider-state inspection API, and moved recovery tests to isolated temporary
target and staging roots. A fresh independent correction review reported no
Critical, Important, or Minor findings.

Root reran these gates on 2026-08-28:

| Gate | Result |
| --- | --- |
| Latticewright producer tests | exit `0`, 6/6 pass, `0.381s` wall time |
| Latticewright relevant tests | exit `0`, 3 files / 20 tests pass, `2.501s` wall time |
| Latticewright typecheck | exit `0`, `7.943s` wall time |
| Latticewright lint | exit `0`, `6.119s` wall time |
| Party Forge exact 12-suite batch | exit `0`, `18.590s`, `TEST_SUMMARY: PASS (0 failures)` |
| Party Forge integration runner | exit `0`, `1.390s`, `CITY_ACCESS_SNAPSHOT_ACCEPTANCE_OK locations=7 profiles=7 rollback=legacy` |
| Explicit importer replay | exit `0`, `0.585s`, `UNCHANGED` at `stage=compare` |
| Complete Party Forge suite | exit `0`, `241.850s`, exactly one `TEST_SUMMARY: PASS (227 suites)` |

The complete-suite marker audit contained zero `TEST_SUMMARY: FAIL`,
`TEST_FAILURE`, `SCRIPT ERROR`, `Parse Error`, `Failed to load script`, and `No
loader found` markers. The 98 `ERROR:` and 11 `WARNING:` lines were expected
negative-path diagnostics and are not invariant counts.

After every RED and GREEN recovery run, the fixed staging tree had zero files
and the protected artifacts retained their exact identity:

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `design/progression/latticewright/party-forge-city-access.pstree` | 11,055 | `49e990eb09720a5cbd590f3bcdc8d732b3b578aa8a61c77a11d7ed118409f10a` |
| `design/progression/latticewright/party-forge-city-access.pstree.json` | 9,972 | `bb3abd94d6b86716d3c39840deef460e20596abb858ba6abd4535067d664ff78` |
| `data/world/access/party-forge-city-access.snapshot.json` | 2,539 | `ca046f55eaaf28ff050c6d7ab240232d5663820d88c1551160a7a2c4476b6a55` |

## Boundary and audit statement

The candidate stays default-off and Developer Mode-only. No City scene, navigation route, profile schema, `ProfileCodec`, passive allocation behavior, Player Mode activation, or current format-1 City runtime was changed. The format-1 City source is both present and loader-qualified. No merge, push, `main` change, remote/default activation, player-build wiring, or release occurred. This is ready for user review only; merge or activation still requires separate approval.
