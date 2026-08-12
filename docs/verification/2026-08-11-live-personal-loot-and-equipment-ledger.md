# Live Personal Loot and Equipment Ledger Verification

Date: 2026-08-11

Status: Automated final acceptance passed after the approved readiness fixes; manual visual and physical-controller acceptance deferred.

## Verified tree and environment

- Readiness-fix commit under test: `c28723be985f395b0bf2a18f6bf2c233490ac103`
- Prior acceptance evidence commit: `cef988278a881cb9f53b38c8253b41bf5aa140e7`
- Task 13 base: `7b70000e5279434fc889cf51fb8ca5c180444902`
- Feature fork point used by the deferred-scope audit: `4021a98326488e08d1cbd0ac511de04434b1721c`
- Branch: `feat/live-personal-loot`
- Godot: `F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe`
- Working project: `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\live-personal-loot`
- Evidence root: `C:\Users\Jacob\AppData\Local\Temp\party-forge-live-loot-final-acceptance-c28723be-1bb9b0c5f8e24e47a6464f3fb51c45a3`
- Cold project: `C:\Users\Jacob\AppData\Local\Temp\party-forge-live-loot-final-cold-c28723be-3e11d648318f473196617160f346a6c8\party-forge`

The working tree was clean and exactly at the cited readiness-fix commit before acceptance began. Every Step 2 and cold process used a newly created, command-specific `APPDATA` and `LOCALAPPDATA` pair under the evidence root (`runtime-step2-01` through `runtime-step2-08`, then `runtime-cold-01-import` through `runtime-cold-03-boot`). No shared user application-data root was used.

## Step 2 focused acceptance batch

Every row was a separate Godot process run from the working project. Durations are fresh wall-clock observations from `System.Diagnostics.Stopwatch`.

| # | Exact command after the Godot executable | Exit | Duration | Exact PASS evidence / suites | Viewport | Caveat | Log |
|---|---|---:|---:|---|---|---|---|
| 1 | `--headless --path . --quit-after 420 --script res://tests/focused_test_runner.gd -- tests/unit/test_personal_loot_roll_service.gd tests/unit/test_ground_item_registry.gd tests/unit/test_personal_loot_drop_coordinator.gd tests/unit/test_ground_item_targeting_service.gd tests/unit/test_ground_item_pickup_service.gd tests/unit/test_ledger_item_provider.gd tests/unit/test_equipment_inventory_ledger_page.gd tests/unit/test_character_equipment_preview.gd tests/unit/test_main_wiring.gd` | 0 | 26.812 s | `TEST_SUMMARY: PASS (0 failures)`; 9 focused suites | Headless/default | Expected negative paths emit `PARTY_FORGE_RUN_CONTEXT_ERROR field=test` and `PARTY_FORGE_PERSONAL_LOOT_TUNING_ERROR field=seconds_per_item_level`; no parse, loader, or leak marker occurred. | `C:\Users\Jacob\AppData\Local\Temp\party-forge-live-loot-final-acceptance-c28723be-1bb9b0c5f8e24e47a6464f3fb51c45a3\step2-01-focused.log` |
| 2 | `--headless --path . --quit-after 240 --script res://tests/integration/personal_loot_defeat_runner.gd` | 0 | 3.177 s | `PERSONAL_LOOT_DEFEAT_INTEGRATION: PASS`; `PERSONAL_LOOT_XP_REGRESSION: PASS`; `FORGE_GUARDIAN_VICTORY_REGRESSION: PASS`; 1 integration runner | Headless/default | Automated defeat/victory integration, not a manual playtest. The Guardian marker proves the zero-chance boss path creates no chest and still transitions directly to victory. | `C:\Users\Jacob\AppData\Local\Temp\party-forge-live-loot-final-acceptance-c28723be-1bb9b0c5f8e24e47a6464f3fb51c45a3\step2-02-personal-loot-defeat.log` |
| 3 | `--headless --path . --quit-after 240 --script res://tests/integration/ground_item_pickup_input_runner.gd` | 0 | 2.250 s | `GROUND_ITEM_PICKUP_MOUSE: PASS`; `GROUND_ITEM_PICKUP_CONTROLLER: PASS`; `GROUND_ITEM_PICKUP_FULL_INVENTORY: PASS`; `GROUND_ITEM_PICKUP_FOREIGN_OWNER: PASS`; `GROUND_ITEM_PICKUP_INPUT_INTEGRATION: PASS`; 1 integration runner | Actual viewport-dispatched input with automated viewport fixtures | Updated readiness coverage includes exact clicked-chest selection before collection, retained out-of-range selection/ring/distance/status, typed player-visible pickup feedback, pooled reset, stable next selection, and natural teardown. Events are automated, not physical-controller acceptance. | `C:\Users\Jacob\AppData\Local\Temp\party-forge-live-loot-final-acceptance-c28723be-1bb9b0c5f8e24e47a6464f3fb51c45a3\step2-03-ground-item-pickup-input.log` |
| 4 | `--headless --path . --quit-after 300 --script res://tests/integration/equipment_ledger_responsive_runner.gd` | 0 | 2.897 s | `TASK10_EQUIPMENT_LEDGER_RESOLUTION_PASS size=1920x1080`; `TASK10_EQUIPMENT_LEDGER_RESOLUTION_PASS size=2560x1440`; `TASK10_EQUIPMENT_LEDGER_RESOLUTION_PASS size=3840x2160`; `TASK10_EQUIPMENT_LEDGER_MEMBER_24_PASS`; `TASK10_EQUIPMENT_LEDGER_RESPONSIVE_SUMMARY: PASS (0 failures)`; 1 integration runner | 1920x1080, 2560x1440, 3840x2160 | Automated geometry, closed focus graph, tooltip-layer, and equipment-refresh checks; no screenshots or visual judgment. | `C:\Users\Jacob\AppData\Local\Temp\party-forge-live-loot-final-acceptance-c28723be-1bb9b0c5f8e24e47a6464f3fb51c45a3\step2-04-equipment-ledger-responsive.log` |
| 5 | `--headless --path . --quit-after 240 --script res://tests/integration/equipment_ledger_preview_runner.gd` | 0 | 1.791 s | `TASK11_EQUIPMENT_LEDGER_PREVIEW_SUMMARY: PASS (0 failures)`; 1 integration runner | 1280x720 | Automated isolated-preview state and input isolation, not manual visual acceptance. | `C:\Users\Jacob\AppData\Local\Temp\party-forge-live-loot-final-acceptance-c28723be-1bb9b0c5f8e24e47a6464f3fb51c45a3\step2-05-equipment-ledger-preview.log` |
| 6 | `--headless --path . --quit-after 240 --script res://tests/integration/live_loot_lifecycle_runner.gd` | 0 | 4.745 s | `LIVE_LOOT_LIFECYCLE_INTEGRATION: PASS`; 1 integration runner | Headless/default | Automated victory, defeat, restart, front-end, aborted-startup, and subsequent-run cleanup. | `C:\Users\Jacob\AppData\Local\Temp\party-forge-live-loot-final-acceptance-c28723be-1bb9b0c5f8e24e47a6464f3fb51c45a3\step2-06-live-loot-lifecycle.log` |
| 7 | `--headless --path . --quit-after 300 --script res://tests/integration/live_personal_loot_multiplayer_runner.gd` | 0 | 1.890 s | `LIVE_PERSONAL_LOOT_MULTIPLAYER_SUMMARY: PASS`; 1 integration runner | 1280x720 automated projection | Four real contexts/profiles use devices 0-3 and red/blue/yellow/green identities. One forced ordinary defeat yields independent P1/P2 successes and out-of-range P3/P4 failures. Production projection, targeting, and pickup verify foreign visibility without targeting/collection, P1-only mutation, and P2 full-inventory persistence. | `C:\Users\Jacob\AppData\Local\Temp\party-forge-live-loot-final-acceptance-c28723be-1bb9b0c5f8e24e47a6464f3fb51c45a3\step2-07-live-personal-loot-multiplayer.log` |
| 8 | `--headless --path . --quit-after 300 --script res://tests/integration/live_personal_loot_performance_runner.gd` | 0 | 3.641 s | `LIVE_LOOT_MEMORY_SUMMARY: before_bytes=120373336 after_bytes=268140088 peak_bytes=268384320 projected=2003 pool_limit=64 frame_samples=60`; `LIVE_LOOT_SCALE_SUMMARY: chests=2003 owners=4 peak_frame_ms=0.031`; `LIVE_LOOT_MOVING_CAMERA_SUMMARY: records=2003 samples=60 peak_frame_ms=0.031 peak_projection_work=32 peak_pending=1942 settle_frames=71 memory_peak_bytes=268384320`; `LIVE_LOOT_PERFORMANCE_SUMMARY: PASS`; 1 integration runner | Alternating 1920x1080 and 2560x1440 during camera motion | Headless process-frame observation on this machine, not a rendered gameplay benchmark. The test includes 2,000 ordinary records plus selected/hovered/focused critical records. | `C:\Users\Jacob\AppData\Local\Temp\party-forge-live-loot-final-acceptance-c28723be-1bb9b0c5f8e24e47a6464f3fb51c45a3\step2-08-live-personal-loot-performance.log` |

The scan across all eight Step 2 logs and all three cold logs found zero `SCRIPT ERROR`, `Parse Error`, `No loader found`, `leaked at exit`, `ObjectDB instances were leaked`, or `resources still in use` markers.

## Readiness-fix acceptance

The refreshed focused and full gates cover the approved readiness corrections: Player Mode requires feature access and positive run inventory capacity; Developer Mode plus Unlock All receives an explicit run-only five-slot inventory without changing the profile; difficulty and Heat stay consistent through roll, generation, and provenance; unsupported/invalid tuning fails closed; successful pickup replay is owner/drop-safe, defensive, and idempotent; and typed pickup results reach the HUD. The Step 2 focused command includes the roll/coordinator/pickup/Main suites directly exercising these paths, while the complete cold suite includes their expanded generator, feature-access, checkout, and HUD dependencies.

## Performance observations

The runner registered 2,000 ordinary records across four owners and three late-sorting critical records before measurement. It moved the camera and alternated viewport sizes while reserving the production 32-projection budget for selected, hovered, and focus-inspected records first; ordinary work converged after motion stopped.

- Records/chests: 2,003 total (2,000 ordinary plus 3 critical)
- Owners: 4, at least 500 ordinary records each
- Measured moving frames: 60
- Peak process frame: 0.031 ms
- Hard gate: <=33.4 ms; PASS
- Peak combined projection work / production limit: 32 / 32
- Peak pending projection count: 1,942
- Convergence after motion stopped: 71 frames, within the 128-frame runner bound
- Static memory before / after / peak: 120,373,336 / 268,140,088 / 268,384,320 bytes
- Projected chest count: 2,003
- Inactive pool bound: 64

These values are fresh observations, not a cross-hardware performance guarantee.

## Cold archive acceptance

The cold project was created in a new temporary extraction from exactly `c28723be985f395b0bf2a18f6bf2c233490ac103`:

```powershell
git archive c28723be985f395b0bf2a18f6bf2c233490ac103 -o $archive
Expand-Archive -LiteralPath $archive -DestinationPath $coldProject
```

- Archive path: `C:\Users\Jacob\AppData\Local\Temp\party-forge-live-loot-final-cold-c28723be-3e11d648318f473196617160f346a6c8\tracked.zip`
- Archive SHA-256: `6edc2e94b9d59bf6926cf0cf29cf93dba2e73432a0199c970866906366ff1bda`
- `git archive` exit: 0
- Archive file entries / extracted files: 2,889 / 2,889
- Clean extraction: `True`
- Before import: `.git` absent, `.godot` absent, `.worktrees` absent
- Before import: focused, full, multiplayer, and performance runners present
- Before import: `GODOT_IMPORT_PERFORMED=False`
- Trace log: `C:\Users\Jacob\AppData\Local\Temp\party-forge-live-loot-final-acceptance-c28723be-1bb9b0c5f8e24e47a6464f3fb51c45a3\cold-paths.txt`

| Run | Exact command | Exit | Duration | Exact PASS evidence / suites | Viewport | Caveat | Log |
|---|---|---:|---:|---|---|---|---|
| Cold import | `& $godot --headless --path $coldProject --import` | 0 | 30.191 s | Import completed; zero `ERROR:` lines and zero forbidden parse/loader/leak markers | Editor import/headless | Fresh exact-commit archive; isolated command-specific application-data roots. | `C:\Users\Jacob\AppData\Local\Temp\party-forge-live-loot-final-acceptance-c28723be-1bb9b0c5f8e24e47a6464f3fb51c45a3\cold-01-import.log` |
| Complete suite | `& $godot --headless --path $coldProject --quit-after 600 --script res://tests/test_runner.gd` | 0 | 240.398 s | Exactly one `TEST_SUMMARY: PASS (201 suites)` marker | Headless/default | Negative-path tests intentionally emitted 80 structured `ERROR:` diagnostics and 10 JSON-store cleanup/corrupt-primary warnings. The added tuning error is expected fail-closed coverage. Zero parse/loader/leak markers occurred. | `C:\Users\Jacob\AppData\Local\Temp\party-forge-live-loot-final-acceptance-c28723be-1bb9b0c5f8e24e47a6464f3fb51c45a3\cold-02-full-suite.log` |
| Boot smoke | `& $godot --headless --path $coldProject --quit-after 20` | 0 | 3.737 s | Exactly one `PARTY_FORGE_BOOT_OK` and one `PARTY_FORGE_CLASS_SELECTION_READY` | Headless/default | Startup readiness only; zero `ERROR:` and zero forbidden parse/loader/leak markers; no visual interaction. | `C:\Users\Jacob\AppData\Local\Temp\party-forge-live-loot-final-acceptance-c28723be-1bb9b0c5f8e24e47a6464f3fb51c45a3\cold-03-boot.log` |

## Manual visual and physical-controller acceptance

Automated simulation is not counted as manual acceptance.

| Manual row | Status | Reason |
|---|---|---|
| Arena chest, rarity glow, owner pennant/label at all three target resolutions | DEFERRED | No rendered screenshot capture or human visual review was performed. |
| Mouse hover/click, pickup feedback, and `Move closer` persistence | DEFERRED | Updated actual-input contracts passed; no manual pointer playtest was performed. |
| Equipment & Inventory page at 1920x1080, 2560x1440, and 3840x2160 | DEFERRED | Automated geometry markers passed; no manual screenshot review was performed. |
| Member 24 selection and visible equipment refresh | DEFERRED | Automated member-24 and preview-refresh assertions passed; no human visual confirmation. |
| Pinned tooltip plus Alt/Shift layers | DEFERRED | Automated layer and safe-margin assertions passed; no manual visual confirmation. |
| Accepted equipment visual refresh | DEFERRED | Automated isolated preview replacement passed; no manual art/readability judgment. |
| Physical controller D-pad chest cycling | DEFERRED | No physical controller was used. |
| Physical controller south-face pickup/place | DEFERRED | No physical controller was used. |
| Physical controller west-face hold/release | DEFERRED | No physical controller was used. |
| Physical controller LT/RT tooltip layers | DEFERRED | No physical controller was used. |
| Physical controller right-stick roster/inventory scroll | DEFERRED | No physical controller was used. |
| Physical controller out-of-range `Move closer` selection persistence | DEFERRED | Automated controller-event simulation passed; no physical-controller playtest was performed. |

## Deferred-scope audit

The exact Task 13 search was rerun over `scripts`, `tests`, and this document, with `run history` / `run_history` included. Full-tree hits were reviewed as pre-existing extraction/profile code, validation tests, vocabulary, typed seams, or verification text. Targeted feature/readiness diff and production searches found:

- Boss drop: `PersonalLootTuning.drop_basis_points[&"boss"] == 0`; fresh `FORGE_GUARDIAN_VICTORY_REGRESSION: PASS` proves no Guardian chest and direct victory.
- Extraction: no `scripts/extraction` file changed from the feature fork or during the readiness-fix range `cef98827...c28723be`.
- Trading / deliberate player item drop: zero targeted production hits and no readiness-diff addition.
- Timed despawn: zero despawn or ground-timeout hits in `scripts/loot`, `scripts/world`, and `scripts/run`.
- Ground save/resume: zero ground references in `scripts/profile`; the runtime ground container is not serialized.
- Run History: the only write-shaped production hit is the existing codec decode assignment `profile.run_history = _dictionaries(...)`; no producer or mutation path was added.
- Readiness diff: no added deferred keyword line in production/tests, and no extraction file changed.

No boss reward activation, extraction-loop work, trading, timed despawn, ground persistence, or run-history behavior slipped into the readiness fixes. Audit logs are under the evidence root: `deferred-scope-audit.log`, `task13-scope-search-pre-doc.log`, and `task13-scope-search-final.log`.

Increment 6 remains deferred: boss reward activation, the thirty-minute battle director, five-minute bosses, extraction timing/voting, and per-player run-summary/history behavior.
