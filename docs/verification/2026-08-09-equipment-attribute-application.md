# Equipment and Attribute Application Verification

Verified 2026-08-09 in the isolated linked worktree on branch **feat/equipment-attribute-application**.

## Task 10O final whole-branch review remediation

Task 10O verified exact functional head **69bec9790a94264ca431731a2c02f61604c6c8c9** after remediating all four findings from the mandatory `00d145d..2efe005` review. The complete approved-design range is now **00d145d7b461dde8d2cf4b01b36d57fb5ee73852..69bec9790a94264ca431731a2c02f61604c6c8c9**, 45 commits after the range start. The authoritative main checkout remained read-only at **39deef45c0b8fd338da74af16e31d67a0f2dcc63**, with its two known tracked overlays unchanged; no integration occurred.

The implementation now validates each complete candidate member-source collection before mutation, requiring one exact owned canonical equipment source at most; uses exact live coordinator ownership as the single stale-context mutation guard; removes only the Warlock's stale `ranged` archetype capability from both generator and canonical resource; and renders unauthoritative raw-roll differences as neutral, explicitly higher/lower, benefit-unknown comparisons. Real regressions cover malformed pre-bind source states and no-drift, released/replaced/reinitialized contexts, all nine actual class archetypes plus the Warlock action snapshot, and larger/smaller fallback rolls for all five modifier operations with accessible neutral semantics.

Strict accepted RED/GREEN evidence was:

| Finding | Accepted RED | Accepted GREEN |
| --- | --- | --- |
| Complete source collection | exit `1`, **3.578s**, `FAIL (55 failures)` | exit `0`, **3.462s**, `PASS (0 failures)` |
| Stale context mutation | exit `1`, **4.440s**, `FAIL (10 failures)` | exit `0`, **4.268s**, `PASS (0 failures)` |
| Caster-only Warlock | exit `1`, **3.523s**, `FAIL (6 failures)` | exit `0`, **4.615s**, `PASS (0 failures)` |
| Neutral raw fallback | exit `1`, **0.502s**, `FAIL (49 failures)` with no script error | exit `0`, **0.409s**, `PASS (0 failures)` |

One preliminary comparison RED with test-script errors was rejected. The first full runner was a useful late RED, exit `1` in **129.668s** with two stale fixture expectations: expanded class content still expected Warlock `ranged`, and an unconfigured context expected item-resolution mutation. The fixtures were aligned respectively to the approved caster-only data and a configured current-owner resolution contract; their focused rerun passed in **4.043s**. A later exact-string RED exposed mojibake punctuation in fallback text and expectation; plain ASCII punctuation replaced it, and the comparison/tooltip rerun passed.

### Task 10O gates

| Gate | Exit / duration | Exact result |
| --- | --- | --- |
| Isolated import | `0` / **17.366s** | structural and shutdown scan clean |
| Task 10M empty-runner probe | `0` / **1.640s** | `TASK10M_EMPTY_RUNNER_PROBE_SUMMARY: PASS open=1 list=1 zero=1 focused=1` |
| Widened 32-suite matrix | `0` / **91.044s** | `TEST_SUMMARY: PASS (0 failures)`; sandbox SHA `c201fd5917d9958da63dacd8201e80d5911c0de51af367977d2a5ee57dd9defe` |
| Equipment/cache integration | `0` / **1.603s** | `TASK10J_ACTION_CACHE_SUMMARY: PASS members=24 hits=512 usec=1660`; `EQUIPMENT_ATTRIBUTE_APPLICATION_SUMMARY: PASS members=24 untouched=23 items=2` |
| Progression integration | `0` / **15.056s** | `PROGRESSION_24_MEMBER_ISOLATION_PASS members=24 untouched=23`; `PROGRESSION_24_MEMBER_SUMMARY: PASS` |
| Final exact-head complete suite | `0` / **128.5s tool wall time** | exactly one `TEST_SUMMARY: PASS (166 suites)` |
| Isolated startup | `0` / **14.374s** | `PARTY_FORGE_BOOT_OK` once; `PARTY_FORGE_CLASS_SELECTION_READY` once |

The final exact-head full log was 98,074 bytes and had zero FAIL summary, `TEST_FAILURE`, raw `SCRIPT ERROR`, parser/loader failure, ObjectDB/resource/RID/PagedAllocator/orphan leak, fatal, crash, or access-violation marker. Progression retains its established five parent/child dummy-renderer shutdown-notice sets; the complete release gate and startup were clean.

Fresh tracked-only cold import exited `0` in **40.801s**. `migrate_class_expansion_data.gd` then exited expected `1` in **1.057s** on **35** known unrelated starter-loadout capability/tag diagnostics, after writing regenerated resources. Its Warlock output excluded `ranged`, and the cold canonical parity suite exited `0` in **0.454s** with `TEST_SUMMARY: PASS (0 failures)`.

Exact-path cleanup removed 25 initial Task 10O settings/cold/log targets (4,352 files / 85,951,089 logical bytes), followed by the smaller post-check and exact-head settings/log roots. All targets were verified below `.superpowers\sdd`, with zero tracked descendants and zero reparse points; residue was zero. Only the eight exact import-created allowlisted sidecars were removed. The protected manifest returned to **127 files / 2,503 bytes / SHA-256 0a392c6cde37052bb7a87455d77ef9a6cf12a4bb5198e43aa9715952b3c23cd3**. `git diff --check` passed, only the intentional Warlock class resource changed under `data/`, no Godot process targeted the worktree, and main remained untouched.

Physical-controller acceptance and visible GPU-backed/pixel-level manual review remain deferred. The unrelated 35-diagnostic class-expansion validation debt remains explicit rather than being represented as a clean generator exit.

## Task 10N current-head release-candidate verification

Task 10N verified exact feature head **1d5fdbeb57addd037dd4ddd0b9788db72fffe022** after the Task 10M dead-callback and real list-failure review remediation. The complete approved-design range remains **00d145d7b461dde8d2cf4b01b36d57fb5ee73852..1d5fdbe**, 43 commits after the range start. The isolated feature worktree began with empty tracked and index diffs. The authoritative main checkout was inspected read-only at **39deef45c0b8fd338da74af16e31d67a0f2dcc63** and was not reset, cleaned, stashed, integrated, or otherwise mutated; its two known tracked overlays remain `scripts/party/party_manager.gd` and `scripts/party/party_member_state.gd`.

The protected untracked sidecar baseline was re-derived from 127 sorted normalized paths, byte lengths, and per-file SHA-256 values joined by LF with no trailing LF. It was exactly **127 files / 2,503 bytes / SHA-256 0a392c6cde37052bb7a87455d77ef9a6cf12a4bb5198e43aa9715952b3c23cd3**. Including a trailing LF produces **406771aca63ab52a7fb02ccffabd0a8123c91343de3e5d1e4a49b605d8971d42**; this and Task 10M's older separately serialized path/content hashes are different algorithms, not manifest drift.

All accepted commands used **Godot 4.7.1.stable.mono.official.a13da4feb** from `F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe`, sequentially, with isolated Task 10N APPDATA/LOCALAPPDATA roots beneath `.superpowers\sdd`.

### Fresh import and fail-closed harness probes

| Gate | Exit / duration | Exact evidence |
| --- | --- | --- |
| Isolated editor import | **0** / **17.320s** | six established missing-UID cache warnings; zero parser, script, loader, shutdown-leak, fatal, crash, or access-violation diagnostic |
| Logger teardown | **0** / **0.269s** | **TEST_SUMMARY: PASS (0 failures)** |
| Deliberate script error | expected **1** / **0.268s** | **TEST_SUMMARY: FAIL (1 failures)**; captured `res://tests/support/script_error_capture_probe.gd:6`, function `run` |
| Intentional asserted `push_error()` | **0** / **0.918s** | **TEST_SUMMARY: PASS (0 failures)** and exactly four `PARTY_FORGE_DAMAGE_ERROR` records; retains its established standalone 18-ObjectDB/five-resource notice |
| Task 10M external runner probe | **0** / **1.517s** | **TASK10M_EMPTY_RUNNER_PROBE_SUMMARY: PASS open=1 list=1 zero=1 focused=1** |
| Direct focused runner without arguments | expected **1** / **0.400s** | stable **FOCUSED_TEST_RUNNER_ERROR: no suite path arguments** and **TEST_SUMMARY: FAIL (1 failures)** |

The external probe uses real process boundaries to prove the complete runner exits nonzero for unit-directory open failure, real `list_dir_begin()` failure, and zero discovered suites. The direct current-worktree probe separately proves the argument-free focused runner is nonzero. No runner can credit a zero-suite PASS under these contracts.

### Expanded focused and hardened full gates

The final focused command named **32 nonzero suite files**: the prior 30-suite Task 1-10L matrix plus `test_party_manager.gd` for Task 10M's dead-callback authority rejection and `test_resolved_attack_geometry.gd` for runtime action identity/geometry. It covered aggregate finiteness and profile persistence, action cadence, damage/healing estimates and comparisons, source/cache/state rejection, Stats Ledger, tooltips, sandbox state, catalog parity, and logger teardown. It exited **0** in **80.344s** with **TEST_SUMMARY: PASS (0 failures)** and `DEVELOPER_ITEM_SANDBOX_SHA256: c201fd5917d9958da63dacd8201e80d5911c0de51af367977d2a5ee57dd9defe`. Its 5,107-byte log contained one PASS summary and zero failure, captured/raw script error, parser/loader, ObjectDB/resource/RID/allocator/orphan, fatal, crash, or access-violation diagnostic.

The hardened complete runner exited **0** in **130.960s**. Its 46,732-byte retained log contained exactly:

~~~text
DEVELOPER_ITEM_SANDBOX_SHA256: c201fd5917d9958da63dacd8201e80d5911c0de51af367977d2a5ee57dd9defe
ITEM_TRANSACTION_MATRIX: PASS
TEST_SUMMARY: PASS (166 suites)
~~~

The PASS marker appeared once. There were zero FAIL summary, `TEST_FAILURE`, captured or raw `SCRIPT ERROR`, parser/loader failure, ObjectDB/resource/RID/PagedAllocator/orphan leak, fatal, crash, or access-violation markers. The log retained exactly **57** established asserted negative-path error markers and **10** documented JSON-store warnings.

### Fresh integrations, startup, and parity provenance

| Gate | Exit / duration | Exact accepted marker(s) | Boundary |
| --- | --- | --- | --- |
| Equipment configure/resume and cache | **0** / **1.611s** | **TASK10J_ACTION_CACHE_SUMMARY: PASS members=24 hits=512 usec=1688**; **EQUIPMENT_ATTRIBUTE_APPLICATION_SUMMARY: PASS members=24 untouched=23 items=2** | shutdown clean |
| Progression/load/isolation | **0** / **15.203s** | **PROGRESSION_24_MEMBER_ISOLATION_PASS members=24 untouched=23**; **PROGRESSION_24_MEMBER_SUMMARY: PASS** | retains the separately documented five parent/child shutdown-notice sets |
| Cleric Stats Ledger | **0** / **2.769s** | **LEDGER_24_MEMBER_SUMMARY: PASS (3 viewports)** | shutdown clean |
| Profile/storage | **0** / **8.796s** | **ITEM_STORAGE_PROFILE_ISOLATION_SUMMARY: PASS profiles=2 items=99** | shutdown clean |
| Responsive tooltip | **0** / **2.582s** | compatibility **1280x720** plus responsive **1920x1080**, **2560x1440**, **3840x2160**; **ITEM_TOOLTIP_RESPONSIVE_SUMMARY: PASS (3 sizes)** | shutdown clean |
| Isolated startup | **0** / **14.438s** | **PARTY_FORGE_BOOT_OK** once; **PARTY_FORGE_CLASS_SELECTION_READY** once | shutdown clean |

The progression runner's four load-size children and parent each retained the established three dummy-renderer mesh RID allocations, 130 ObjectDB instances, 114 resources, and medium/small PagedAllocator notices. Every other integration/startup log had zero test/script/parser/loader/shutdown-leak/fatal/crash/access-violation diagnostic.

The last accepted fresh cold-parity input remains **51b6f0096e595a9d0370c24e8679629ad55e2291**. An exact `git diff` from that commit through Task 10N input **1d5fdbe** found zero change under the complete `tools/` generator/input tree, complete generated `data/` tree, or `tests/unit/test_increment2_generator_parity.gd`. The in-worktree parity suite passed within the 32-suite gate. The Task 10H isolated cold runs for all five documented generators therefore remain authoritative; no destructive cold generation was rerun.

### Final cleanup and hygiene

Every scratch target was resolved as an exact top-level descendant of this worktree's `.superpowers\sdd`; each had zero tracked descendants and zero reparse points, and no Godot process targeted the worktree. Cleanup removed **24 top-level targets / 41 files / 7,089,808 logical bytes**: four Task 10M logs and its settings root, fourteen Task 10N logs and two settings roots, and three obsolete review diffs. Task briefs/reports/progress and current final-review package `review-ef28190..1d5fdbe.diff` were preserved. The temporary cleanup helpers were removed and the exact residue scan returned zero.

The accepted import/gates created eight task-local sidecars. The six established cache-warning files matched their recorded byte lengths and SHA-256 values. Two Task 10M support-script sidecars were also created at the accepted import timestamp: `tests/support/task10m_list_failure_runner.gd.uid` (20 bytes, SHA-256 `eb858aaf08f4b6f5d8c4cbf4e5b00ccc1e3c9e38c554ec7a32f10b1f7b749da3`) and `tests/support/test_suite_discovery.gd.uid` (20 bytes, SHA-256 `ba309cb99472122b2f84ece719f33be37ef8c941d8b7b27d9cf25d7cc4b6b02c`). Only those eight exact generated files were removed.

The protected manifest then returned exactly to **127 files / 2,503 bytes / SHA-256 0a392c6cde37052bb7a87455d77ef9a6cf12a4bb5198e43aa9715952b3c23cd3**. Final checks found zero worktree-targeting Godot editor/game/import/test/generator process; the 15 unrelated `godot-ai.exe` helpers remained untouched. `git diff --name-only -- data`, the index diff, and tracked drift outside this verification document/report were empty; `git diff --check` passed. The authoritative main checkout retained exactly its captured tracked overlays and was not integrated.

Physical-controller acceptance and visible GPU-backed/pixel-level manual review remain deferred. Headless deterministic evidence is not represented as completing either manual boundary.

## Task 10L current-head final revalidation

The final feature input was **7eaaf167e3daad42a2484c2da97f1a24d78c1aef** (**fix: show healing equipment comparisons**), based on Task 10K authority head **fafb0bbc2c914c4c4fdbe5e42aacdfaab0dc76b9**. The Task 10H evidence below is retained as the historical cold-generator proof; every runtime gate in this section was rerun from the exact Task 10L feature input with Godot **4.7.1.stable.mono.official.a13da4feb**.

### Healing comparison TDD and profile parity

The pre-edit comparison/profile baseline exited **0** in **2.039s** with **TEST_SUMMARY: PASS (0 failures)**. Tests were then authored before production changes for:

- **Healing / Use**, **Uses / Second**, and **Estimated HPS** increases and decreases;
- non-color prefix indicators, benefit direction, and accessible **improved/reduced** wording;
- unchanged healing estimates omitting comparison rows;
- a geometry-only healing range change preserving healing amount, use rate, and HPS; and
- a real persisted Cleric profile assignment whose preview deltas equal the shared estimates from the applied profile.

The accepted controlled RED exited **1** in **2.305s** with **TEST_SUMMARY: FAIL (27 failures)**. Every failure was an assertion for the three absent healing rows; profile save/apply and the shared estimate fixtures succeeded, and there was no parser, loader, script, or fixture failure.

The minimal implementation branches only the action-metric rows in `EquipmentComparisonProjectionService`: two healing estimates read `ActionCombatEstimate.healing_amount`, `attacks_per_second`, and `estimated_hps`; two damaging estimates retain Average Hit and DPS; both continue through the existing geometry and benefit-aware row helper. The two-suite GREEN exited **0** in **2.211s**, and the expanded eight-suite affected gate exited **0** in **5.545s**, each with **TEST_SUMMARY: PASS (0 failures)**.

### Verified ignored-artifact cleanup

Before deletion, every candidate was resolved to an exact absolute top-level target strictly beneath:

~~~text
F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\equipment-attribute-application\.superpowers\sdd
~~~

All candidates had zero tracked descendants and zero reparse points, and no worktree-targeting Godot process existed. Cleanup permanently removed only verified task-created cold copies/snapshots, archives, logs, and APPDATA/LOCALAPPDATA settings roots:

| Category | Targets | Files | Logical bytes |
| --- | ---: | ---: | ---: |
| Settings roots | 104 | 220 | 33,632,876 |
| Cold copies/snapshots | 19 | 62,490 | 1,245,561,085 |
| Logs | 4 | 4 | 1,512,594 |
| Archives | 2 | 2 | 87,200,183 |
| **Total** | **129** | **62,716** | **1,367,906,738** |

The tracked reports and ignored briefs, `.gitignore`, `progress.md`, and two review diff artifacts were intentionally preserved. The cleanup helper was ignored, deleted after use, and never staged. A first inline cleanup command was rejected by command policy before execution; it changed nothing. The accepted path-validated helper removed all 129 targets, and the exact residue scan returned **0**.

The protected pre-existing sidecar manifest remained **127 files / 2,503 bytes / SHA-256 0a392c6cde37052bb7a87455d77ef9a6cf12a4bb5198e43aa9715952b3c23cd3** before and after cleanup.

### Fresh import and harness probes

Every final command used the fresh isolated pair `.superpowers\sdd\task-10l-final-appdata` and `.superpowers\sdd\task-10l-final-localappdata`; commands ran sequentially and no process survived.

- Fresh editor import: exit **0**, **7.150s**; filesystem scan, global-class registration, and editor layout completed with no parser, script, loader, failed-resource, fatal, crash, or aborted-scan diagnostic.
- Logger teardown probe: exit **0**, **0.267s**, **TEST_SUMMARY: PASS (0 failures)**.
- Deliberate script-error probe: expected exit **1**, **0.266s**, **TEST_SUMMARY: FAIL (1 failures)**; the hardened runner captured `script_error_capture_probe.gd:6`, function `run`.
- Intentional damage-error probe: exit **0**, **0.914s**, **TEST_SUMMARY: PASS (0 failures)** and exactly the four established `PARTY_FORGE_DAMAGE_ERROR` records.

The fresh import recreated exactly the same six known sidecars recorded by Task 10H, with the same byte lengths and hashes. They were the only additions beyond the protected 127 and were deleted by exact path after all gates.

### Expanded focused and hardened complete gates

The final 30-suite focused command covered Tasks 1-10K plus the Task 10L healing/profile comparisons. It exited **0** in **76.963s** with **TEST_SUMMARY: PASS (0 failures)**, the stable sandbox hash, and no captured **SCRIPT ERROR**. Its standalone focused process emitted the established **24 ObjectDB / 10 resource** shutdown notice; it is functional focused evidence, not the shutdown-clean gate.

The hardened complete suite exited **0** in **130.496s** with:

~~~text
TEST_SUMMARY: PASS (166 suites)
DEVELOPER_ITEM_SANDBOX_SHA256: c201fd5917d9958da63dacd8201e80d5911c0de51af367977d2a5ee57dd9defe
ITEM_TRANSACTION_MATRIX: PASS
~~~

The retained final Godot log was **45,572 bytes**. A post-run exact scan found the PASS marker once and zero **TEST_SUMMARY: FAIL**, **TEST_FAILURE**, captured **SCRIPT ERROR**, parse/parser error, failed load, ObjectDB, resource-in-use, RID, PagedAllocator, orphan, fatal, or crash diagnostic. It retained 57 established asserted domain-error lines and ten JSON-store warning lines.

### Current-head integrations and startup

| Gate | Exit / duration | Exact accepted marker(s) | Boundary |
| --- | --- | --- | --- |
| Equipment application/cache | **0** / **1.572s** | **TASK10J_ACTION_CACHE_SUMMARY: PASS members=24 hits=512 usec=1672**; **EQUIPMENT_ATTRIBUTE_APPLICATION_SUMMARY: PASS members=24 untouched=23 items=2** | shutdown clean |
| Progression/load/isolation | **0** / **15.085s** | **PROGRESSION_24_MEMBER_ISOLATION_PASS members=24 untouched=23**; **PROGRESSION_24_MEMBER_SUMMARY: PASS** | retains established subprocess RID/ObjectDB/resource/allocator notices |
| Cleric ledger | **0** / **2.768s** | **LEDGER_24_MEMBER_SUMMARY: PASS (3 viewports)** | shutdown clean |
| Profile/storage | **0** / **9.270s** | **ITEM_STORAGE_PROFILE_ISOLATION_SUMMARY: PASS profiles=2 items=99** | shutdown clean |
| Responsive tooltip | **0** / **3.607s** | compatibility **1280x720**; responsive **1920x1080**, **2560x1440**, **3840x2160**; **ITEM_TOOLTIP_RESPONSIVE_SUMMARY: PASS (3 sizes)** | shutdown clean |
| Startup smoke | **0** / **4.162s** | **PARTY_FORGE_BOOT_OK** once; **PARTY_FORGE_CLASS_SELECTION_READY** once | shutdown clean |

The Cleric ledger still directly covers its complete Healing / Use, Uses / Second, and Estimated HPS card at all three target viewports. The Task 10L profile unit additionally covers the real healing-comparison preview/apply contract; the generic tooltip card contract continues to map positive, negative, and neutral row direction to green, red, and normal colors while preserving accessible text.

### Generator parity decision and final hygiene

The exact diff from the last fresh cold-parity input **51b6f0096e595a9d0370c24e8679629ad55e2291** through **7eaaf167e3daad42a2484c2da97f1a24d78c1aef** contains no generator script, canonical `data/` range, or `test_increment2_generator_parity.gd` change. The in-worktree parity suite passed inside the 30-suite gate. A new destructive cold generation was therefore not run; the complete fresh current-input cold parity at **51b6f0** remains authoritative in the historical section below, including its separately recorded unrelated class-expansion exit **1**.

After all verification, the two Task 10L settings roots and six import-created sidecars were removed. The exact residue scan returned **0**. The protected manifest again measured **127 files / 2,503 bytes / SHA-256 0a392c6cde37052bb7a87455d77ef9a6cf12a4bb5198e43aa9715952b3c23cd3**. `git diff --name-only -- data`, the index diff, and the tracked working-tree diff were empty before this document and the Task 10L report were authored.

An independent read-only review inspected the complete approved-design range **00d145d..7eaaf167**. It found no Critical, Important, or Minor issue and returned **READY**. The reviewer specifically confirmed the shared healing estimates, zero-delta omission, geometry coexistence, benefit/accessibility/color contract, persisted profile preview/apply parity, generator-proof reuse decision, range scope, and protected sidecar manifest. It did not rerun tests; the fresh evidence above is authoritative.

Physical-controller and visible GPU-backed manual pixel review remain deferred. The deterministic unit and integration gates cover content, color/accessibility contracts, focus/geometry, and supported viewports; they are not represented as hands-on hardware or human visual-quality sign-off.

## Scope and exact pre-state

- Approved design base: **00d145d**.
- Fresh Task 10H verification input: **51b6f0096e595a9d0370c24e8679629ad55e2291** (**test: cover healing ledger responsiveness**). This contains the Tasks 10A-E remediation, hardened script-error capture, the Task 10G shared action-cadence implementation, and the Cleric healing-card responsive follow-up.
- **git status --short --branch** reported the branch plus only the 127 protected pre-existing untracked **.gd.uid** sidecars. **git diff --name-only** and **git diff --cached --name-only** were empty.
- The Task 10H content-aware sidecar manifest serialized each sorted normalized relative path, byte length, and per-file SHA-256 with tab delimiters and LF separators. It contained 127 files / 2,503 bytes and had aggregate SHA-256 **0a392c6cde37052bb7a87455d77ef9a6cf12a4bb5198e43aa9715952b3c23cd3**.
- The process snapshot found 15 unrelated **godot-ai.exe attach** helpers at PIDs **10900**, **14120**, **14816**, **14992**, **16988**, **18024**, **27292**, **30724**, **34792**, **35764**, **37916**, **38348**, **38720**, **42332**, and **42624**. It found no Godot editor, game, import, test, or generator process targeting this worktree. No unrelated process was stopped.
- Godot executable: **F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe**.
- Exact engine version: **4.7.1.stable.mono.official.a13da4feb**.
- Every authoritative-worktree Godot command used the brand-new settings pair **.superpowers\sdd\task-10h-20260809-161016-appdata** and **.superpowers\sdd\task-10h-20260809-161016-localappdata**. Each cold copy used its own never-before-used sibling APPDATA/LOCALAPPDATA pair.
- Commands were sequential. Every accepted command was followed by a command-line process check; no accepted invocation overlapped another and no worktree-targeting process survived.

Common setup:

~~~powershell
$repo = (Get-Location).Path
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
$env:APPDATA = Join-Path $repo '.superpowers\sdd\task-10h-20260809-161016-appdata'
$env:LOCALAPPDATA = Join-Path $repo '.superpowers\sdd\task-10h-20260809-161016-localappdata'
~~~

## Fresh import/parser gate

~~~powershell
& $godot --headless --path . --editor --quit-after 300
~~~

- Exit **0**; **7.148s**.
- Zero **SCRIPT ERROR**, parse/parser error, failed script/resource load, missing loader, invalid call/index, fatal, crash, or aborted-scan diagnostic.
- Filesystem scan, global-class registration, and editor-layout initialization completed. **MCP | plugin disabled in headless mode** was informational.
- The import created exactly six sidecars that were absent from the pre-state; their provenance and cleanup are recorded below.

## Hardened runner proofs

~~~powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/support/logger_teardown_order_probe.gd
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/support/script_error_capture_probe.gd
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_damage_resolver.gd
~~~

| Gate | Required result | Fresh Task 10H result |
| --- | --- | --- |
| Logger teardown order | normal PASS | exit **0**; **0.272s**; **TEST_SUMMARY: PASS (0 failures)** once; zero captured **SCRIPT ERROR** |
| Deliberate script error | hardened runner rejects it | exit **1**; **0.266s**; **TEST_SUMMARY: FAIL (1 failures)** once; captured the nil-property **SCRIPT ERROR**, **res://tests/support/script_error_capture_probe.gd:6**, and function **run** |
| Intentional push_error paths | asserted domain errors still pass | exit **0**; **0.920s**; **TEST_SUMMARY: PASS (0 failures)** once; exactly four **PARTY_FORGE_DAMAGE_ERROR** records; zero captured **SCRIPT ERROR** |

The isolated damage-resolver probe emitted its established standalone shutdown notice for 18 ObjectDB instances and five resources. It is accepted only as proof that intentional domain **push_error** output is not misclassified as a script error. The consolidated focused gate and complete suite below are the shutdown-clean release gates.

## Tasks 1-10G focused remediation gate

~~~powershell
& $godot --headless --path . --quit-after 1800 --script res://tests/focused_test_runner.gd -- `
  tests/unit/test_attribute_derived_source_projector.gd `
  tests/unit/test_member_stat_resolution_service.gd `
  tests/unit/test_action_archetype.gd `
  tests/unit/test_action_cadence.gd `
  tests/unit/test_damage_resolver.gd `
  tests/unit/test_action_combat_estimate_service.gd `
  tests/unit/test_attack_execution.gd `
  tests/unit/test_equipment_modifier_projector.gd `
  tests/unit/test_equipment_activation_resolver.gd `
  tests/unit/test_equipment_transition_service.gd `
  tests/unit/test_player_run_context.gd `
  tests/unit/test_health_component.gd `
  tests/unit/test_run_context_registry.gd `
  tests/unit/test_local_run_setup_coordinator.gd `
  tests/unit/test_non_equipment_activation_refresh.gd `
  tests/unit/test_increment2_generator_parity.gd `
  tests/unit/test_equipment_assignment_service.gd `
  tests/unit/test_profile_loadout_assignment_service.gd `
  tests/unit/test_profile_storage_projection.gd `
  tests/unit/test_game_catalog.gd `
  tests/unit/test_ledger_data_provider.gd `
  tests/unit/test_stats_ledger_page.gd `
  tests/unit/test_resolved_stat_comparison_service.gd `
  tests/unit/test_item_presentation_projector.gd `
  tests/unit/test_developer_item_sandbox_state.gd `
  tests/unit/test_developer_item_sandbox.gd `
  tests/unit/test_item_tooltip_card.gd `
  tests/support/logger_teardown_order_probe.gd
~~~

- Exit **0**; **73.108s**.
- Exact marker **TEST_SUMMARY: PASS (0 failures)** appeared once.
- Zero **TEST_FAILURE**, captured **SCRIPT ERROR**, parse/parser error, failed-load/missing-loader, fatal, crash, ObjectDB, resource-in-use, RID, PagedAllocator, or orphan diagnostic.
- Allowed asserted output was exactly four **PARTY_FORGE_DAMAGE_ERROR** records and one **PARTY_FORGE_STAT_ERROR** record.
- Task 10G coverage includes the pure cadence formula; neutral and invalid boundaries; Wisdom-only cooldown-recovery changes; runtime/ledger parity for damage and healing; healing HPS without a damage archetype; and equipment-transition, source-refresh, and resumable-reconstruction rollback.
- Earlier remediation coverage remains present for source/cache isolation, complete generator catalogs, deterministic swap/storage planning, all owned-action validation, strict equipment requirement schema, monotonic core modifiers, sandbox/profile atomicity, and hardened logger teardown.

## Hardened complete suite

~~~powershell
& $godot --headless --path . --quit-after 1800 --script res://tests/test_runner.gd
~~~

- Exit **0**; **126.937s**.
- Exact marker **TEST_SUMMARY: PASS (166 suites)** appeared once.
- **DEVELOPER_ITEM_SANDBOX_SHA256: c201fd5917d9958da63dacd8201e80d5911c0de51af367977d2a5ee57dd9defe** and **ITEM_TRANSACTION_MATRIX: PASS** each appeared once.
- Zero **TEST_SUMMARY: FAIL**, **TEST_FAILURE**, captured **SCRIPT ERROR**, parse/parser error, failed-load/missing-loader, fatal, or crash diagnostic.
- Zero ObjectDB, resource-in-use, RID, PagedAllocator, or orphan shutdown diagnostic.
- Asserted negative-path domain errors, JSON-store warnings, and the forced directory-creation failure retained their established test contracts. None was a runtime script or test-harness error.

## Fresh integrations and startup

~~~powershell
& $godot --headless --path . --quit-after 900 --script res://tests/integration/equipment_attribute_application_runner.gd
& $godot --headless --path . --quit-after 1200 --script res://tests/integration/progression_24_member_runner.gd
& $godot --headless --path . --quit-after 900 --script res://tests/integration/ledger_24_member_runner.gd
& $godot --headless --path . --quit-after 900 --script res://tests/integration/item_storage_profile_runner.gd
& $godot --headless --path . --quit-after 900 --script res://tests/integration/item_tooltip_responsive_runner.gd
& $godot --headless --path . --quit-after 300
~~~

| Gate | Exit / duration | Exact accepted marker(s) | Shutdown diagnostics |
| --- | --- | --- | --- |
| Equipment application | **0** / **1.475s** | **EQUIPMENT_ATTRIBUTE_APPLICATION_SUMMARY: PASS members=24 untouched=23 items=2** | zero |
| Progression isolation/load | **0** / **15.084s** | **PROGRESSION_24_MEMBER_ISOLATION_PASS members=24 untouched=23**; **PROGRESSION_24_MEMBER_SUMMARY: PASS** | established subprocess diagnostics, detailed below |
| Cleric ledger responsiveness | **0** / **2.768s** | **LEDGER_24_MEMBER_SUMMARY: PASS (3 viewports)** | zero |
| Profile/storage isolation | **0** / **8.598s** | **ITEM_STORAGE_PROFILE_ISOLATION_SUMMARY: PASS profiles=2 items=99** | zero |
| Responsive item tooltip | **0** / **2.496s** | compatibility **1280x720**; responsive passes at **1920x1080**, **2560x1440**, and **3840x2160**; **ITEM_TOOLTIP_RESPONSIVE_SUMMARY: PASS (3 sizes)** | zero |
| Startup smoke | **0** / **4.071s** | **PARTY_FORGE_BOOT_OK** once; **PARTY_FORGE_CLASS_SELECTION_READY** once | zero |

All six processes exited with the required code and markers. All contained zero captured **SCRIPT ERROR**, test failure, parser/loader, fatal, crash, or access-violation evidence. No process survived.

The equipment runner covers immutable items, activation/disable/reactivation, candidate-action rejection atomicity, source refresh, resume, affected-member notification/cache replacement, and exact isolation for members 2-24.

The ledger runner now makes member 1 a Cleric. At **1920x1080**, **2560x1440**, and **3840x2160**, it proves the complete healing card and metrics remain visible and inside the Stats scroll viewport; exposes **Healing / Use**, **Uses / Second**, and **Estimated HPS**; and verifies the estimate-boundary text for missing health, targeting, movement, and AI downtime. This is the direct responsive coverage for Task 10G healing presentation.

The progression runner's four load-size children and parent each retained the known engine shutdown output: three dummy-renderer mesh RID allocations, 130 ObjectDB instances, 114 resources, and medium/small PagedAllocator pages. The runner and every child exited **0**, and both required 24-member markers appeared once. It is accepted as functional load/isolation evidence and explicitly is not represented as shutdown-hygiene-clean.

## Fresh current-HEAD cold generator parity

No Task 10F copy was reused. A fresh archive was produced from exact Task 10H input **51b6f0096e595a9d0370c24e8679629ad55e2291**.

~~~powershell
git archive --format=zip --output=.superpowers/sdd/task-10h-20260809-161016-cold-head.zip HEAD
tar -xf <archive> -C <fresh-copy>
& $godot --headless --path <fresh-copy> --import
$env:PARTY_FORGE_GENERATOR_PARITY_CANONICAL_ROOT = $repo.Replace('\', '/')
& $godot --headless --path <fresh-copy> --quit-after 600 --script <generator-script>
& $godot --headless --path <fresh-copy> --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_increment2_generator_parity.gd
~~~

- Archive: **43,681,460 bytes**; SHA-256 **976142314b03258afd80acc34fe99a8b841e657a716c9317589feb0e7be3d13d**.
- Each copy began with 2,377 archive files, 217 asset files, and no **.godot** cache.
- Terminating **--import** exited **0**, created exactly 1,192 imported artifacts, and emitted zero aborted-scan or forbidden diagnostic in every copy.

| Disposable generator | Import | Generator result | Complete parity result |
| --- | --- | --- | --- |
| **migrate_typed_combat_data.gd** | **0** / **32.029s** | **0** / **0.379s**; **PARTY_FORGE_TYPED_ATTACK_DATA_SAVED count=9** | **0** / **0.449s**; **TEST_SUMMARY: PASS (0 failures)** |
| **create_stat_foundation_data.gd** | **0** / **30.537s** | **0** / **0.267s** | **0** / **0.450s**; **TEST_SUMMARY: PASS (0 failures)** |
| **create_character_upgrade_data.gd** | **0** / **38.805s** | **0** / **1.458s**; **PARTY_FORGE_CHARACTER_UPGRADE_DATA_SAVED upgrades=25 names=10 keywords=81** | **0** / **0.737s**; **TEST_SUMMARY: PASS (0 failures)** |
| **create_default_data.gd** | **0** / **30.277s** | **0** / **0.452s**; **DATA_GENERATION_OK** | **0** / **0.450s**; **TEST_SUMMARY: PASS (0 failures)** |
| **migrate_class_expansion_data.gd** | **0** / **30.663s** | expected unrelated **1** / **1.213s**; exactly 36 starter-loadout capability/tag diagnostics across Paladin, Rogue, Frost Mage, Warlock, and Marksman | **0** / **0.456s**; **TEST_SUMMARY: PASS (0 failures)** |

Every parity run used the hardened focused runner. There were zero captured **SCRIPT ERROR**, test failure, parser/loader, fatal, crash, shutdown-leak, access-violation, or surviving-process diagnostics. The authoritative worktree had zero **data/** diff before and after cold verification.

The class-expansion nonzero result remains the separately recorded later validation boundary: its older class rows lack equipment capability tags required by starter-loadout validation. Complete retained attack/stat/keyword parity still passed for every emitted attack.

## Provenance, rejected evidence, and final hygiene

No Godot evidence was rejected in Task 10H: there was no access violation, wrapper argument error, overlapping invocation, aborted scan, or post-PASS nonzero exit. A combined cleanup command was blocked by the shell policy before execution; it did not run and did not affect evidence or repository state. Exact path-scoped dry runs preceded the accepted cleanup.

The authoritative import created these six files, all absent from the pre-state and written within the same import timestamp interval:

- **scripts/combat/action_cadence.gd.uid** — 17 bytes; SHA-256 **bcacf4f65dba516a7e9b532fad3bb0ca047dd1a1bf5133493922a30a71a837e7**
- **scripts/combat/candidate_action_validation_service.gd.uid** — 20 bytes; SHA-256 **2d5cbfd1781f79f39b609543c9a156a45e5aaba95a3c5c5bf80ca8a5e1b9a9a7**
- **tests/support/logger_teardown_order_probe.gd.uid** — 19 bytes; SHA-256 **9c328ac661d4e8975377ed01dbd96f7012b4694d995ce8da774ecc398507239e**
- **tests/support/script_error_capture_probe.gd.uid** — 20 bytes; SHA-256 **a7a52fdd6e19ad5d1c906eec254a900431dc58b1780a650df85a2684f188c42c**
- **tests/support/test_script_error_capture.gd.uid** — 20 bytes; SHA-256 **f0efe4c189a8369739173194afc66fb958815706a5a0007440e789ffc7e632b9**
- **tests/unit/test_action_cadence.gd.uid** — 20 bytes; SHA-256 **1857ddd44b485ed0a5e473d72b2f64e286a0ef41a62c5527bd504d9cb078691e**

Only those six exact generated files were removed. All 18 Task 10H settings/archive/copy paths were removed after exact path-scoped dry runs. No **.import** sidecar was added or removed.

After cleanup, the protected manifest returned exactly to 127 files / 2,503 bytes / SHA-256 **0a392c6cde37052bb7a87455d77ef9a6cf12a4bb5198e43aa9715952b3c23cd3**. No Task 10H artifact or worktree-targeting Godot process remained. **git diff --name-only -- data**, the tracked diff, and the index diff were empty before this document was authored.

Final repository checks:

~~~powershell
git diff --check
git diff --name-only
git diff --cached --name-only
git diff --name-only -- data
git status --short --branch
~~~

This verification document is the only intended tracked change before its documentation-only commit. No production code, Resource, scene, asset, project setting, profile/save data, canonical generated data, or protected sidecar was changed by Task 10H.

## Deferred hands-on review and remaining concerns

- A physical-controller pass is deferred. Automated controller/focus contracts remain covered, but this verification does not claim hardware gamepad behavior.
- Manual pixel review in a visible GPU-backed window is deferred. The responsive runners prove deterministic geometry, content, accessibility text, and viewport containment through 4K, not human visual-quality sign-off.
- The progression runner's established shutdown diagnostics remain visible and are not represented as a clean shutdown pass.
- The isolated intentional-**push_error** probe retains its smaller standalone 18-ObjectDB/five-resource shutdown notice; the consolidated focused gate and 166-suite release gate are shutdown clean.
- The retained class-expansion migration exits **1** on the unrelated starter-loadout capability/tag mismatch described above.
