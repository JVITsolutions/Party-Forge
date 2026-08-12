# Live Personal Loot and Equipment Ledger Verification

Date: 2026-08-11

Status: Automated final acceptance passed on the repaired branch; manual visual and physical-controller acceptance deferred.

## Verified tree and environment

- Post-fix commit under test: `d4f91f9342d18aaeaf54c995e3012fd696fff872`
- Task 13 base: `7b70000e5279434fc889cf51fb8ca5c180444902`
- Feature fork point used by the deferred-scope audit: `4021a98326488e08d1cbd0ac511de04434b1721c`
- Branch: `feat/live-personal-loot`
- Godot: `F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe`
- Working project: `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\live-personal-loot`
- Evidence root: `C:\Users\Jacob\AppData\Local\Temp\party-forge-live-loot-final-acceptance-d4f91f93-3a6d007186544632b4ca81c17ded266a`
- Cold project: `C:\Users\Jacob\AppData\Local\Temp\party-forge-live-loot-final-cold-d4f91f93-23b826c57cc743e98093b9934e3afbde\party-forge`

The working tree was clean and exactly at the cited post-fix commit before acceptance began. Every Step 2 process and every cold process used a newly created, command-specific `APPDATA` and `LOCALAPPDATA` pair under the evidence root (`runtime-step2-01` through `runtime-step2-08`, then `runtime-cold-01-import` through `runtime-cold-03-boot`). No shared user application-data root was used.

## Step 2 focused acceptance batch

Every row below was a separate Godot process run from the working project. Durations are fresh wall-clock observations from `System.Diagnostics.Stopwatch`.

| # | Exact command after the Godot executable | Exit | Duration | Exact PASS evidence / suites | Viewport | Caveat | Log |
|---|---|---:|---:|---|---|---|---|
| 1 | `--headless --path . --quit-after 420 --script res://tests/focused_test_runner.gd -- tests/unit/test_personal_loot_roll_service.gd tests/unit/test_ground_item_registry.gd tests/unit/test_personal_loot_drop_coordinator.gd tests/unit/test_ground_item_targeting_service.gd tests/unit/test_ground_item_pickup_service.gd tests/unit/test_ledger_item_provider.gd tests/unit/test_equipment_inventory_ledger_page.gd tests/unit/test_character_equipment_preview.gd tests/unit/test_main_wiring.gd` | 0 | 25.760 s | `TEST_SUMMARY: PASS (0 failures)`; 9 focused suites | Headless/default | The Main wiring negative-path assertion intentionally emits one structured `PARTY_FORGE_RUN_CONTEXT_ERROR field=test`; no parse, loader, or leak marker occurred. | `C:\Users\Jacob\AppData\Local\Temp\party-forge-live-loot-final-acceptance-d4f91f93-3a6d007186544632b4ca81c17ded266a\step2-01-focused.log` |
| 2 | `--headless --path . --quit-after 240 --script res://tests/integration/personal_loot_defeat_runner.gd` | 0 | 3.094 s | `PERSONAL_LOOT_DEFEAT_INTEGRATION: PASS`; `PERSONAL_LOOT_XP_REGRESSION: PASS`; `FORGE_GUARDIAN_VICTORY_REGRESSION: PASS`; 1 integration runner | Headless/default | Automated defeat/victory integration, not a manual playtest. The Guardian marker proves the zero-chance boss path creates no chest and still transitions to victory. | `C:\Users\Jacob\AppData\Local\Temp\party-forge-live-loot-final-acceptance-d4f91f93-3a6d007186544632b4ca81c17ded266a\step2-02-personal-loot-defeat.log` |
| 3 | `--headless --path . --quit-after 240 --script res://tests/integration/ground_item_pickup_input_runner.gd` | 0 | 2.161 s | `GROUND_ITEM_PICKUP_MOUSE: PASS`; `GROUND_ITEM_PICKUP_CONTROLLER: PASS`; `GROUND_ITEM_PICKUP_FULL_INVENTORY: PASS`; `GROUND_ITEM_PICKUP_FOREIGN_OWNER: PASS`; `GROUND_ITEM_PICKUP_INPUT_INTEGRATION: PASS`; 1 integration runner | Actual viewport-dispatched input with automated viewport fixtures | This is the updated actual-input runner: it covers shared-tooltip/focus ownership, owner-relative range, the non-color selection ring, persistent `Move closer`, deterministic next/empty selection, exact pooled-node reset, reconfigure status reset, and natural teardown. Events are automated, not physical-controller acceptance. | `C:\Users\Jacob\AppData\Local\Temp\party-forge-live-loot-final-acceptance-d4f91f93-3a6d007186544632b4ca81c17ded266a\step2-03-ground-item-pickup-input.log` |
| 4 | `--headless --path . --quit-after 300 --script res://tests/integration/equipment_ledger_responsive_runner.gd` | 0 | 2.899 s | `TASK10_EQUIPMENT_LEDGER_RESOLUTION_PASS size=1920x1080`; `TASK10_EQUIPMENT_LEDGER_RESOLUTION_PASS size=2560x1440`; `TASK10_EQUIPMENT_LEDGER_RESOLUTION_PASS size=3840x2160`; `TASK10_EQUIPMENT_LEDGER_MEMBER_24_PASS`; `TASK10_EQUIPMENT_LEDGER_RESPONSIVE_SUMMARY: PASS (0 failures)`; 1 integration runner | 1920x1080, 2560x1440, 3840x2160 | Automated geometry, closed focus graph, tooltip-layer, and equipment-refresh checks; no screenshots or visual judgment. | `C:\Users\Jacob\AppData\Local\Temp\party-forge-live-loot-final-acceptance-d4f91f93-3a6d007186544632b4ca81c17ded266a\step2-04-equipment-ledger-responsive.log` |
| 5 | `--headless --path . --quit-after 240 --script res://tests/integration/equipment_ledger_preview_runner.gd` | 0 | 1.793 s | `TASK11_EQUIPMENT_LEDGER_PREVIEW_SUMMARY: PASS (0 failures)`; 1 integration runner | 1280x720 | Automated isolated-preview state and input isolation, not manual visual acceptance. | `C:\Users\Jacob\AppData\Local\Temp\party-forge-live-loot-final-acceptance-d4f91f93-3a6d007186544632b4ca81c17ded266a\step2-05-equipment-ledger-preview.log` |
| 6 | `--headless --path . --quit-after 240 --script res://tests/integration/live_loot_lifecycle_runner.gd` | 0 | 4.750 s | `LIVE_LOOT_LIFECYCLE_INTEGRATION: PASS`; 1 integration runner | Headless/default | Automated victory, defeat, restart, front-end, aborted-startup, and subsequent-run cleanup. | `C:\Users\Jacob\AppData\Local\Temp\party-forge-live-loot-final-acceptance-d4f91f93-3a6d007186544632b4ca81c17ded266a\step2-06-live-loot-lifecycle.log` |
| 7 | `--headless --path . --quit-after 300 --script res://tests/integration/live_personal_loot_multiplayer_runner.gd` | 0 | 1.881 s | `LIVE_PERSONAL_LOOT_MULTIPLAYER_SUMMARY: PASS`; 1 integration runner | 1280x720 automated projection | Four real contexts/profiles use devices 0-3 and red/blue/yellow/green identities. One forced ordinary defeat yields independent P1/P2 successes and out-of-range P3/P4 failures. Production projection, targeting, and pickup verify foreign visibility without targeting/collection, P1-only mutation, and P2 full-inventory persistence. | `C:\Users\Jacob\AppData\Local\Temp\party-forge-live-loot-final-acceptance-d4f91f93-3a6d007186544632b4ca81c17ded266a\step2-07-live-personal-loot-multiplayer.log` |
| 8 | `--headless --path . --quit-after 300 --script res://tests/integration/live_personal_loot_performance_runner.gd` | 0 | 3.646 s | `LIVE_LOOT_MEMORY_SUMMARY: before_bytes=120332711 after_bytes=268099279 peak_bytes=268343511 projected=2003 pool_limit=64 frame_samples=60`; `LIVE_LOOT_SCALE_SUMMARY: chests=2003 owners=4 peak_frame_ms=0.034`; `LIVE_LOOT_MOVING_CAMERA_SUMMARY: records=2003 samples=60 peak_frame_ms=0.034 peak_projection_work=32 peak_pending=1942 settle_frames=71 memory_peak_bytes=268343511`; `LIVE_LOOT_PERFORMANCE_SUMMARY: PASS`; 1 integration runner | Alternating 1920x1080 and 2560x1440 during camera motion | Headless process-frame observation on this machine, not a rendered gameplay benchmark. The test includes 2,000 ordinary records plus selected/hovered/focused critical records. | `C:\Users\Jacob\AppData\Local\Temp\party-forge-live-loot-final-acceptance-d4f91f93-3a6d007186544632b4ca81c17ded266a\step2-08-live-personal-loot-performance.log` |

The scan across all eight Step 2 logs and all three cold logs found zero `SCRIPT ERROR`, `Parse Error`, `No loader found`, `leaked at exit`, `ObjectDB instances were leaked`, or `resources still in use` markers.

## Performance observations

The repaired runner registered 2,000 ordinary records across four owners and then three late-sorting critical records before frame measurement. It moved the camera and alternated viewport sizes while reserving the production 32-projection budget for selected, hovered, and focus-inspected records first; ordinary pending work then converged after motion stopped.

- Records/chests: 2,003 total (2,000 ordinary plus 3 critical)
- Owners: 4, at least 500 ordinary records each
- Measured moving frames: 60
- Peak process frame: 0.034 ms
- Hard gate: <=33.4 ms; PASS
- Peak combined projection work: 32
- Production per-frame projection limit: 32
- Peak pending projection count: 1,942
- Convergence after motion stopped: 71 frames, within the 128-frame runner bound
- Static memory before records: 120,332,711 bytes
- Static memory after projection: 268,099,279 bytes
- Static memory peak: 268,343,511 bytes
- Projected chest count at observation: 2,003
- Inactive pool bound: 64

These values are fresh observations, not a cross-hardware performance guarantee.

## Cold archive acceptance

The cold project was created in a new temporary extraction from exactly `d4f91f9342d18aaeaf54c995e3012fd696fff872`:

```powershell
git archive d4f91f9342d18aaeaf54c995e3012fd696fff872 -o $archive
Expand-Archive -LiteralPath $archive -DestinationPath $coldProject
```

- Archive path: `C:\Users\Jacob\AppData\Local\Temp\party-forge-live-loot-final-cold-d4f91f93-23b826c57cc743e98093b9934e3afbde\tracked.zip`
- Archive SHA-256: `bc993b54b517f0322c630a579cc6178e5a36468e1036308cccb3cf9ee5ec2019`
- `git archive` exit: 0
- Archive file entries: 2,888
- Extracted files: 2,888
- Clean extraction: `True`
- Before import: `.git` absent, `.godot` absent, `.worktrees` absent
- Before import: focused runner, full runner, multiplayer runner, and performance runner present
- Before import: `GODOT_IMPORT_PERFORMED=False`
- Trace log: `C:\Users\Jacob\AppData\Local\Temp\party-forge-live-loot-final-acceptance-d4f91f93-3a6d007186544632b4ca81c17ded266a\cold-paths.txt`

| Run | Exact command | Exit | Duration | Exact PASS evidence / suites | Viewport | Caveat | Log |
|---|---|---:|---:|---|---|---|---|
| Cold import | `& $godot --headless --path $coldProject --import` | 0 | 31.002 s | Import completed; zero `ERROR:` lines and zero forbidden parse/loader/leak markers | Editor import/headless | Fresh exact-commit archive; isolated command-specific application-data roots. | `C:\Users\Jacob\AppData\Local\Temp\party-forge-live-loot-final-acceptance-d4f91f93-3a6d007186544632b4ca81c17ded266a\cold-01-import.log` |
| Complete suite | `& $godot --headless --path $coldProject --quit-after 600 --script res://tests/test_runner.gd` | 0 | 246.337 s | Exactly one `TEST_SUMMARY: PASS (201 suites)` marker | Headless/default | Negative-path tests intentionally emitted 79 structured `ERROR:` diagnostics and 10 JSON-store cleanup/corrupt-primary warnings. The terminal summary was exactly one PASS, with zero parse/loader/leak markers. | `C:\Users\Jacob\AppData\Local\Temp\party-forge-live-loot-final-acceptance-d4f91f93-3a6d007186544632b4ca81c17ded266a\cold-02-full-suite.log` |
| Boot smoke | `& $godot --headless --path $coldProject --quit-after 20` | 0 | 3.734 s | Exactly one `PARTY_FORGE_BOOT_OK` and one `PARTY_FORGE_CLASS_SELECTION_READY` | Headless/default | Startup readiness only; zero `ERROR:` and zero forbidden parse/loader/leak markers; no visual interaction. | `C:\Users\Jacob\AppData\Local\Temp\party-forge-live-loot-final-acceptance-d4f91f93-3a6d007186544632b4ca81c17ded266a\cold-03-boot.log` |

## Manual visual and physical-controller acceptance

Automated simulation is not counted as manual acceptance.

| Manual row | Status | Reason |
|---|---|---|
| Arena chest, rarity glow, owner pennant/label at all three target resolutions | DEFERRED | No rendered screenshot capture or human visual review was performed. |
| Mouse hover/click and `Move closer` visual persistence | DEFERRED | Updated actual-input contracts passed; no manual pointer playtest was performed. |
| Equipment & Inventory page at 1920x1080, 2560x1440, and 3840x2160 | DEFERRED | Automated geometry markers passed; no manual screenshot review was performed. |
| Member 24 selection and visible equipment refresh | DEFERRED | Automated member-24 and preview refresh assertions passed; no human visual confirmation. |
| Pinned tooltip plus Alt/Shift layers | DEFERRED | Automated live-layer and safe-margin assertions passed; no manual visual confirmation. |
| Accepted equipment visual refresh | DEFERRED | Automated isolated preview replacement passed; no manual art/readability judgment. |
| Physical controller D-pad chest cycling | DEFERRED | No physical controller was used. |
| Physical controller south-face pickup/place | DEFERRED | No physical controller was used. |
| Physical controller west-face hold/release | DEFERRED | No physical controller was used. |
| Physical controller LT/RT tooltip layers | DEFERRED | No physical controller was used. |
| Physical controller right-stick roster/inventory scroll | DEFERRED | No physical controller was used. |
| Physical controller out-of-range `Move closer` selection persistence | DEFERRED | Automated controller-event simulation passed; no physical-controller playtest was performed. |

## Deferred-scope audit

The exact Task 13 search was rerun over `scripts`, `tests`, and this final document, with `run history` / `run_history` included. Its 289 full-tree hits were reviewed as pre-existing extraction/profile code, validation tests, vocabulary, typed seams, or this verification text. Targeted feature-diff and production searches recorded the following:

- Boss drop: `PersonalLootTuning.drop_basis_points[&"boss"] == 0`; the fresh `FORGE_GUARDIAN_VICTORY_REGRESSION: PASS` integration confirms no Guardian chest is created and victory remains direct. The boss item-level category and test-only forced-decision seam do not activate a normal boss reward.
- Extraction: no file under `scripts/extraction` changed from feature fork `4021a983...` through `d4f91f93...`, and none changed from Task 13 base `7b70000e...` through the tested head. Existing extraction systems are outside this increment.
- Trading / deliberate player item drop: targeted production search found zero trading hits, and the feature diff added no deferred trading behavior.
- Timed despawn: targeted `scripts/loot`, `scripts/world`, and `scripts/run` search found zero despawn or ground-timeout hits. Ground records remain until collection or run cleanup.
- Ground save/resume: targeted `scripts/profile` search found zero ground references. The run-ground container remains runtime-owned and is not added to profile or resumable-run serialization.
- Run History: the only production write-shaped hit is the pre-existing codec decode assignment `profile.run_history = _dictionaries(...)`; schema-3 compatibility preserves the existing field but adds no run-summary/history producer or mutation path.

The feature-diff audit found no changed extraction files, no trading/despawn implementation, and no newly added deferred keyword lines beyond the preserved schema fields, zero-boss assertion, and unrelated personal-drop setting names. The post-Task-13-base diff added none of the deferred keywords. No boss reward activation, extraction-loop work, trading, timed despawn, ground persistence, or run-history behavior slipped into the repaired branch.

Audit logs:

- `C:\Users\Jacob\AppData\Local\Temp\party-forge-live-loot-final-acceptance-d4f91f93-3a6d007186544632b4ca81c17ded266a\deferred-scope-audit.log`
- `C:\Users\Jacob\AppData\Local\Temp\party-forge-live-loot-final-acceptance-d4f91f93-3a6d007186544632b4ca81c17ded266a\deferred-scope-feature-audit.log`
- `C:\Users\Jacob\AppData\Local\Temp\party-forge-live-loot-final-acceptance-d4f91f93-3a6d007186544632b4ca81c17ded266a\deferred-scope-diff-audit.log`
- `C:\Users\Jacob\AppData\Local\Temp\party-forge-live-loot-final-acceptance-d4f91f93-3a6d007186544632b4ca81c17ded266a\deferred-scope-targeted-audit.log`
- `C:\Users\Jacob\AppData\Local\Temp\party-forge-live-loot-final-acceptance-d4f91f93-3a6d007186544632b4ca81c17ded266a\deferred-scope-audit-final.log`

Increment 6 remains deferred: boss reward activation, the thirty-minute battle director, five-minute bosses, extraction timing/voting, and per-player run-summary/history behavior.
