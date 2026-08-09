# Equipment and Attribute Application Verification

Verified 2026-08-09 in the isolated linked worktree on branch **feat/equipment-attribute-application**.

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
