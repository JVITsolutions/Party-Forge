# Living Forge HUD, Level-Up, Extraction, and Results Verification

Date: 2026-08-30
Branch: `feat/living-forge-combat-loop-ui`
Approved visual/code candidate: `08239dcde22c94b2f10e961ea00333b0f29f912c`

## Candidate and reconciliation

- Candidate parents:
  - Task 14 repair: `8b4bfdf4a77db7a4c807c18e1dfe5538d9c4cc57`
  - Local main: `6ef03e3d11829bf04b3631ee1e7ba757932ea962`
- Merge base with main after reconciliation: `6ef03e3d11829bf04b3631ee1e7ba757932ea962`.
- Both parents are exact ancestors of the candidate.
- Complete combined diff from `4c4acb5e001b0cfbb64aa06358b42b7ed9a67eb9`: 293 files; `git diff --check` passed.
- Qualification ran in a detached disposable worktree at the exact approved candidate. No fetch, merge into main, push, publication, or production/harness edit was performed during qualification.

## Human and independent review gates

- Independent UI/UX review: **APPROVED** after inspecting all 45 PNGs at original resolution.
- Jacob visual decision: **APPROVED** for visual candidate `08239dcd` on 2026-08-30.
- Independent requirements review: **PASS**, with no Critical, Important, or Minor findings.
- Independent code-quality review: **APPROVED**, with no Critical or Important findings.
- Physical controller: **DEFERRED**. No real controller was used for this qualification; automated controller-focus/input coverage passed.

Two non-blocking visual polish notes remain: a tiny isolated dot below the final row in `level-up-recipient-24.png`, and an empty outlined idle strip in `extraction-automatic-selected-lost.png`. The code-quality reviewer also noted low-risk future hardening opportunities for duplicate JSON-key rejection and broader transitive dirty-dependency detection in retained-evidence validation.

## Cold qualification

Disposable worktree: `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\task14-qualification-08239dcd`

Godot:

`C:\Users\Jacob\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64_console.exe`

Cold import command:

```powershell
& $godot --headless --editor --path . --import --quit
```

Result: exit `0`; no `SCRIPT ERROR`, parse/load failure, or missing-resource marker.

Full-suite command:

```powershell
& $godot --headless --path . --quit-after 1800 --script res://tests/test_runner.gd
```

Result: exit `0`; exactly one `TEST_SUMMARY: PASS (258 suites)`; no prohibited failure marker.

The plan's `255` count predates the authorized main reconciliation. Candidate `08239dcd` adds exactly three discovered Warehouse suites relative to feature parent `8b4bfdf4`:

- `tests/unit/test_warehouse_locked_dialog.gd`
- `tests/unit/test_warehouse_presentation_reporter.gd`
- `tests/unit/test_warehouse_presentation_resolver.gd`

Therefore the reconciled exact count is `255 + 3 = 258`.

## Focused runner matrix

Headless runner command shape:

```powershell
& $godot --headless --path . --quit-after 1800 --script <runner>
```

All 14 headless runners exited `0`, emitted exactly one required marker, and emitted no prohibited failure marker:

| Runner | Required marker |
| --- | --- |
| `combat_hud_party_scale_runner.gd` | `COMBAT_HUD_PARTY_SCALE_SUMMARY: PASS` |
| `combat_hud_input_runner.gd` | `COMBAT_HUD_INPUT_SUMMARY: PASS` |
| `progression_arena_smoke_runner.gd` | `PROGRESSION_ARENA_SMOKE_SUMMARY: PASS` |
| `upgrade_recipient_controller_scroll_runner.gd` | `UPGRADE_RECIPIENT_CONTROLLER_SCROLL_SUMMARY: PASS` |
| `level_up_commit_flow_runner.gd` | `LEVEL_UP_COMMIT_FLOW_SUMMARY: PASS` |
| `temporary_popup_input_runner.gd` | `TEMPORARY_POPUP_INPUT_SUMMARY: PASS` |
| `terminal_extraction_flow_runner.gd` | `TERMINAL_EXTRACTION_FLOW_SUMMARY: PASS` |
| `run_result_lifecycle_runner.gd` | `RUN_RESULT_LIFECYCLE_SUMMARY: PASS` |
| `run_terminal_flow_runner.gd` | `RUN_TERMINAL_FLOW_SUMMARY: PASS` |
| `run_recovery_profile_lifecycle_runner.gd` | `RUN_RECOVERY_PROFILE_LIFECYCLE: PASS` |
| `live_loot_lifecycle_runner.gd` | `LIVE_LOOT_LIFECYCLE_INTEGRATION: PASS` |
| `personal_loot_defeat_runner.gd` | `PERSONAL_LOOT_DEFEAT_INTEGRATION: PASS` |
| `profile_boot_main_flow_runner.gd` | `PROFILE_BOOT_MAIN_FLOW_SUMMARY: PASS` |
| `run_setup_lobby_panel_runner.gd` | `RUN_SETUP_LOBBY_PANEL_SUMMARY: PASS` |

Windowed OpenGL command shape:

```powershell
& $godot --path . --display-driver windows --rendering-method gl_compatibility --quit-after 1800 --script <runner>
```

All seven windowed runners exited `0`, emitted exactly one required marker, and emitted no prohibited failure marker:

| Runner | Required marker |
| --- | --- |
| `living_forge_combat_state_board_runner.gd` | `LIVING_FORGE_COMBAT_STATE_BOARD_SUMMARY: PASS` |
| `responsive_ui_geometry_runner.gd` | `RESPONSIVE_GEOMETRY_SUMMARY: PASS` |
| `level_up_five_card_geometry_runner.gd` | `LEVEL_UP_FIVE_CARD_SUMMARY: PASS` |
| `combat_loop_responsive_runner.gd` | `COMBAT_LOOP_RESPONSIVE_SUMMARY: PASS` |
| `combat_loop_accessibility_runner.gd` | `COMBAT_LOOP_ACCESSIBILITY_SUMMARY: PASS` |
| `combat_loop_performance_runner.gd` | `COMBAT_LOOP_PERFORMANCE_SUMMARY: PASS` |
| `living_forge_combat_loop_visual_evidence_runner.gd -- --validate-only` | `LIVING_FORGE_COMBAT_LOOP_VISUAL_SUMMARY: PASS` |

Validation-only was used for the post-approval evidence gate so the approved pixels and manifest were not rewritten. Cold import had generated exactly 45 `.png.import` sidecars beside the evidence; those exact sidecars were archived outside Git, leaving the required manifest-plus-45-PNG path set. The state-board runner also refreshed a tracked legacy capture manifest; that generated copy was archived and the exact candidate blob restored before final hygiene verification.

## Evidence contract

- Schema: `2`
- Source head: `08239dcde22c94b2f10e961ea00333b0f29f912c`
- Manifest SHA-256: `d033117fafcd4982608ee9bab38405376e0eab86ec711accc81be6091214954a`
- Capture-contract SHA-256: `f9995863704e4d80067f159acc0f9ab1cb5717fd33ade197f4d55eb02719e1ac`
- Source-tree fingerprint SHA-256: `8c79af55b3564a0dfee1f434ad4f95d60969ea75fc2a6c2ce68af225247ab083`
- Exact file set: one manifest plus 45 PNGs.
- Manifest/PNG path parity: 45/45.
- Manifest/PNG hash parity: 45/45.
- Unique PNG hashes: 45/45.
- Disposable/source evidence byte parity: 46/46 files.

| Capture | SHA-256 |
| --- | --- |
| `combat-loop-1440p.png` | `647e1c06b3986303d881c31f4671d2231b08d49acb9879d764cee1d431ec8f47` |
| `combat-loop-720p-text-150.png` | `9176a702d17a25e328e5e933c439a0bbaf8e06c064ecfc51e25d0694f88c60bc` |
| `combat-loop-720p-ui-150-text-150.png` | `edc60c45153e1302f2307f54fdca96fdc29b40a55e9a5f0a97a8f37fd1816ac2` |
| `combat-loop-720p-ui-80-text-150.png` | `dbdc45fc0d5520105dda83f146b5c6aad7ec07eec09e77488bbf03d35bc6ba63` |
| `combat-loop-controller-focus.png` | `69864ae1f8138e53cebd56cf9fb7ebcf327271fde5a28f693042a3000987e427` |
| `combat-loop-high-contrast.png` | `7063a33a50be955f6dc5845daf1f7b4b09f460be1d026cb555d5160a8c7ff89d` |
| `combat-loop-mouse-hover.png` | `079a40114e5fa4ab12a717ee3078298fd23850f4d6f965f0a668a57d1a3cd1a0` |
| `combat-loop-reduced-motion.png` | `a124e8434fd10af1a57ac4f1f0d0e8be2b1bdf27f83bf6546e58e3442bba8afe` |
| `combat-loop-ui-scale-150.png` | `79cb6080c6e7702ba97d2c7987729ac016d8a8a7ca250b2e7c751ed76d4695c9` |
| `combat-loop-ultrawide.png` | `7ad7b8e3ff2915675829492ad1e543ee21bbaa7f6563a1047c4b45fb177c812b` |
| `extraction-automatic-selected-lost.png` | `89dc445a4ddc9fa662a0f02886736be181a2b38fb7f4935321546ec523daf5fb` |
| `extraction-detail-720p-ui-150-text-150.png` | `51cecdc3d8109854ec21d9c0cecf759d0c0f906680740ba2687748a17f8f9f16` |
| `extraction-pending-focus.png` | `4d884ef44ca860fb22b233a47fb381834549baa1739fee33031f3ae0c647a132` |
| `hud-alert-720p-ui-150-text-150.png` | `ccd931f17b74729b3a172b23f82cd1b770b739327afcd22fcfc0afade2188ca7` |
| `hud-alert-inspect-return.png` | `8a0ab1e16eb4903db639b96d9b2aecefbdb6c0938fdd0c11df632e4911c39df6` |
| `hud-alert-ledger-return.png` | `6fb9f25d2b87452057368933d62e5343e75ef78798fb83773596a8e6d2e8c5c5` |
| `hud-alert-tray-focus.png` | `966902ec4457538561d5bcecd22745a153427c1e3bbbc40dacbcfb2a6f6c1d3c` |
| `hud-compact-20-overflow.png` | `0888f987c14c58d599bb00b2d4de10971a5252507ab7e8af0321852cc732cff6` |
| `hud-compact-24-final-member-focus.png` | `869eac9ed39863f49bc8003dab8dcd5c51a6ed3d04480afdaf0047fe5f715b02` |
| `hud-compact-7.png` | `7a4da2ee2c2229e10b33dbf3ff29386b3065bf4c11e426a43d3d0e1c3fd46924` |
| `hud-no-alert-rich-1.png` | `a60822a45c581e3b4f76106eb278c67160c943e6bb943bc0fed1baf64bfdc53f` |
| `hud-rich-6-three-alerts.png` | `11f37585ab0ad5aa88bf9e0afa1209930961ff3ff6845251857b71eaa33d9739` |
| `level-up-confirmation-safe-focus.png` | `c18380c709d8542f1a8b64b5737ce12ef24bca1c494157d57ff4c68ec9514910` |
| `level-up-direct-and-targeted.png` | `e24945b47748c8d66b7e928707e348a3bed24fa21b609fd1e9b86950fcea4832` |
| `level-up-recipient-24.png` | `f380a4e7fc55648f1511cd21c3138640bf85530ff71eb12c625f0dab92382e98` |
| `pause-abandon-committed-refresh.png` | `65abcee4a873a71a7d03848ab34f52721af453870eb99e7a3b1906eaac1765ab` |
| `restart-lobby-unresolved-selection.png` | `2c922c6b787258f7f5adbe40379f4a68da4942e29f3eae672eeece35106c0545` |
| `restart-lobby-valid-preselection.png` | `0abd74697b2ca856b44c7704a0d785af75a59be1c12e8c650f3ee99f7a3d9b17` |
| `result-automatic-overflow-recovery.png` | `635f391468c33d8308e67eb1e338cee90ef56a959180e460abf932cbc2793c03` |
| `result-defeat-losses.png` | `da4032a1cadd1ab2259efe21ff34c9a49160cc03c604c845c29814e07ebf651b` |
| `result-expanded-detail-ui-150-text-150.png` | `a7c8f93d827fbae29f9b44817470fe7cddc6df1bec46528b8a0af8ee38949714` |
| `result-expanded-detail-ui-80-text-150.png` | `585661bc1f1bd82e654635b3d2165daad4452cdcc65c3e8475e13f3239ec3680` |
| `result-finalized-committed-refresh-retry-only.png` | `78aa1ef45bcccbf108233be98ae02486beb55d84a435d9599d1404e2d2db63c2` |
| `result-finalized-receipt-clear-error.png` | `c1381907bf9f7d582f1721a91e016bb5076f1451b22cc3fa035b55e3c107d679` |
| `result-pending-projection.png` | `1e68da2d9c4250bedbbd1efa1278256fdd76469ea804a7d541a7ce54b29fbf14` |
| `result-pending-protection.png` | `9c29c923648bb7b4409933d65852f708a4e2648a8b4981bc7b721fe7ada6f7eb` |
| `result-pending-resolution.png` | `9dcbfef71877d5ef81a9fd48c734978f14f5a016f6581ddca2c11f49a6f03922` |
| `result-pending-terminal-completion.png` | `e9295c8290ff3b64d42d189a995051571cf5203aaab36456b603f4aa8502749a` |
| `result-pending-terminal-refresh.png` | `96bcf7a598ac5a9b2a10a9439cc884627604dd083a341ed4c31eff01846655a4` |
| `result-pending-terminal-save.png` | `3b6d57a6b929213840aa04275752d88ea3a52344c050d01e603398ab05ef0d24` |
| `result-projection-interrupted.png` | `78b3af29bb9a0a6ade91974a8e8d406c4cbaa01267282bc4d0472d3e831dafd5` |
| `result-resolution-interrupted.png` | `c91d31c1a2fd30c613f3460ae9928c28547a6a99164f4cfa3302268b3cb5e78f` |
| `result-terminal-refresh-interrupted.png` | `2a739ad153e318bea54c09ab8729a605ed358973796b2c33b3613e6156a35f6e` |
| `result-terminal-save-interrupted.png` | `00da6374ab9c8b4f4f51a6897bc29834ce48566a5448f599d1123950df00e031` |
| `result-victory-current-truth.png` | `775bbd1d65e38a2b7efaa0ef82dc283643c8c7b7b46c90145d8f37adab2582eb` |

## Generated-artifact audit and final boundary

- Cold import generated 59 unrelated legacy `.gd.uid` sidecars; the exact generated set was moved to the external qualification archive before tests continued.
- Cold import generated 45 evidence `.png.import` sidecars; the exact generated set was archived outside Git before retained-evidence validation.
- The state-board runner's generated legacy manifest was archived, then its tracked candidate blob was restored and hash-verified.
- Final source worktree before the qualification commit had zero tracked dirt and only the exact 46 approved evidence files plus this verification record pending.
- This qualification authorizes no merge into main and no push.
