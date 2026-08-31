# Task 14 correction and pre-capture reconciliation report

Status: authorized correction in progress. This record preserves the superseded evidence provenance before replacement.

## Authorization and live preflight

- Jacob authorized expanding the Task 14 visual contract from 27 to 45 captures on 2026-08-30.
- Studio Lead authorized the bounded Task 14 correction, local-main reconciliation, exact-head recapture, independent UI/UX review, and stop at Jacob's visual gate.
- Feature branch: `feat/living-forge-combat-loop-ui`.
- Audited feature head: `6460b72ca67cf456c4c1496202b7f305ed5e8321`.
- Audited local `main`: `6ef03e3d11829bf04b3631ee1e7ba757932ea962`.
- Merge base: `4c4acb5e001b0cfbb64aa06358b42b7ed9a67eb9`.
- Divergence (`main...HEAD`): 16 main-only commits, 44 feature-only commits.
- Dirt: only the expected untracked `docs/validation/screenshots/living-forge-combat-loop/` evidence set.
- Exact overlap: `scripts/game/main.gd` and `tests/unit/test_main_wiring.gd`; no additional shared paths.
- No fetch was performed.

## Superseded schema-2 evidence provenance

- Source head: `6460b72ca67cf456c4c1496202b7f305ed5e8321`.
- Manifest SHA-256: `fc02cb9a602168de659c734a77f3341003f4be05274af47280e9c2a39ed9ed5f`.
- Capture-contract SHA-256: `f9995863704e4d80067f159acc0f9ab1cb5717fd33ade197f4d55eb02719e1ac`.
- Evidence-runner SHA-256: `0b2eb83ed51a20f47a4692d1ca4f0f6ec8e734fd1c03a5b03c8f8a2ef19d8edb`.
- Source-tree fingerprint: `f22e68c1b5aafad49e09b7efc61b7a1d6dd07b08b8061d5d74f20ebe1c152715` across 52 explicit source paths.
- Manifest entry count: 45.

### Exact 45-file inventory

- `hud-no-alert-rich-1.png` `a60822a45c581e3b4f76106eb278c67160c943e6bb943bc0fed1baf64bfdc53f`
- `hud-rich-6-three-alerts.png` `11f37585ab0ad5aa88bf9e0afa1209930961ff3ff6845251857b71eaa33d9739`
- `hud-compact-7.png` `7a4da2ee2c2229e10b33dbf3ff29386b3065bf4c11e426a43d3d0e1c3fd46924`
- `hud-compact-20-overflow.png` `0888f987c14c58d599bb00b2d4de10971a5252507ab7e8af0321852cc732cff6`
- `hud-compact-24-final-member-focus.png` `869eac9ed39863f49bc8003dab8dcd5c51a6ed3d04480afdaf0047fe5f715b02`
- `hud-alert-tray-focus.png` `966902ec4457538561d5bcecd22745a153427c1e3bbbc40dacbcfb2a6f6c1d3c`
- `hud-alert-inspect-return.png` `8a0ab1e16eb4903db639b96d9b2aecefbdb6c0938fdd0c11df632e4911c39df6`
- `hud-alert-ledger-return.png` `6fb9f25d2b87452057368933d62e5343e75ef78798fb83773596a8e6d2e8c5c5`
- `level-up-direct-and-targeted.png` `e24945b47748c8d66b7e928707e348a3bed24fa21b609fd1e9b86950fcea4832`
- `level-up-recipient-24.png` `f380a4e7fc55648f1511cd21c3138640bf85530ff71eb12c625f0dab92382e98`
- `extraction-automatic-selected-lost.png` `89dc445a4ddc9fa662a0f02886736be181a2b38fb7f4935321546ec523daf5fb`
- `result-victory-current-truth.png` `7e732daed7f3bd395ab9b75d50c4b19813dac829f9507a7d29be7681a6ac9fb2`
- `result-defeat-losses.png` `cb515d298ea7c2496f25d51cccabe2c7e41199bd3cef8edac80ccfc39d3a4cbc`
- `result-resolution-interrupted.png` `c91d31c1a2fd30c613f3460ae9928c28547a6a99164f4cfa3302268b3cb5e78f`
- `result-terminal-save-interrupted.png` `00da6374ab9c8b4f4f51a6897bc29834ce48566a5448f599d1123950df00e031`
- `result-projection-interrupted.png` `78b3af29bb9a0a6ade91974a8e8d406c4cbaa01267282bc4d0472d3e831dafd5`
- `result-automatic-overflow-recovery.png` `635f391468c33d8308e67eb1e338cee90ef56a959180e460abf932cbc2793c03`
- `combat-loop-720p-text-150.png` `9176a702d17a25e328e5e933c439a0bbaf8e06c064ecfc51e25d0694f88c60bc`
- `combat-loop-720p-ui-150-text-150.png` `edc60c45153e1302f2307f54fdca96fdc29b40a55e9a5f0a97a8f37fd1816ac2`
- `combat-loop-720p-ui-80-text-150.png` `dbdc45fc0d5520105dda83f146b5c6aad7ec07eec09e77488bbf03d35bc6ba63`
- `combat-loop-1440p.png` `647e1c06b3986303d881c31f4671d2231b08d49acb9879d764cee1d431ec8f47`
- `combat-loop-ultrawide.png` `7ad7b8e3ff2915675829492ad1e543ee21bbaa7f6563a1047c4b45fb177c812b`
- `combat-loop-high-contrast.png` `7063a33a50be955f6dc5845daf1f7b4b09f460be1d026cb555d5160a8c7ff89d`
- `combat-loop-reduced-motion.png` `a124e8434fd10af1a57ac4f1f0d0e8be2b1bdf27f83bf6546e58e3442bba8afe`
- `combat-loop-ui-scale-150.png` `79cb6080c6e7702ba97d2c7987729ac016d8a8a7ca250b2e7c751ed76d4695c9`
- `combat-loop-controller-focus.png` `69864ae1f8138e53cebd56cf9fb7ebcf327271fde5a28f693042a3000987e427`
- `combat-loop-mouse-hover.png` `079a40114e5fa4ab12a717ee3078298fd23850f4d6f965f0a668a57d1a3cd1a0`
- `result-pending-terminal-save.png` `3b6d57a6b929213840aa04275752d88ea3a52344c050d01e603398ab05ef0d24`
- `result-pending-terminal-refresh.png` `96bcf7a598ac5a9b2a10a9439cc884627604dd083a341ed4c31eff01846655a4`
- `result-pending-resolution.png` `9dcbfef71877d5ef81a9fd48c734978f14f5a016f6581ddca2c11f49a6f03922`
- `result-pending-projection.png` `1e68da2d9c4250bedbbd1efa1278256fdd76469ea804a7d541a7ce54b29fbf14`
- `result-pending-protection.png` `9c29c923648bb7b4409933d65852f708a4e2648a8b4981bc7b721fe7ada6f7eb`
- `result-pending-terminal-completion.png` `e9295c8290ff3b64d42d189a995051571cf5203aaab36456b603f4aa8502749a`
- `result-finalized-receipt-clear-error.png` `cec9b88d24b489ec8c728ba6540d1cce6f2f5cae3c6f6d1a928980022cb8861a`
- `result-finalized-committed-refresh-retry-only.png` `d6aab0fcad2db25c46beb448894c391f3ab153fedd196357e1a5f2238960b449`
- `result-terminal-refresh-interrupted.png` `2a739ad153e318bea54c09ab8729a605ed358973796b2c33b3613e6156a35f6e`
- `pause-abandon-committed-refresh.png` `65abcee4a873a71a7d03848ab34f52721af453870eb99e7a3b1906eaac1765ab`
- `restart-lobby-valid-preselection.png` `747fab434fc65e0146e18fcee72b8b0fb9901d22899ed6b29ea0cdb8b7a243a3`
- `restart-lobby-unresolved-selection.png` `5a0ab87fbdce92d7df87379e93077bc1311a7fef74bec0fd5d79b3d97771bdbb`
- `hud-alert-720p-ui-150-text-150.png` `ccd931f17b74729b3a172b23f82cd1b770b739327afcd22fcfc0afade2188ca7`
- `level-up-confirmation-safe-focus.png` `c18380c709d8542f1a8b64b5737ce12ef24bca1c494157d57ff4c68ec9514910`
- `extraction-pending-focus.png` `4d884ef44ca860fb22b233a47fb381834549baa1739fee33031f3ae0c647a132`
- `extraction-detail-720p-ui-150-text-150.png` `51cecdc3d8109854ec21d9c0cecf759d0c0f906680740ba2687748a17f8f9f16`
- `result-expanded-detail-ui-150-text-150.png` `e221e19d613d8d60b1c84c9ca286500d960169ecf11fac9a753caa9781bdb4c7`
- `result-expanded-detail-ui-80-text-150.png` `063dbd20c324333d4ae838fe9c5a06706fd132d6bbb964c18a8914c6f35432a8`

This evidence set is superseded by the authorized correction. Replacement authority is limited to this generated directory, its exact 45 PNGs, and `manifest.json`; no unrelated cleanup is authorized.

## Result expanded-detail RED/GREEN correction

Root cause: the recap's primary line was native `Button.text`, which Godot vertically centered across the expanded row, while the detail label began at a fixed top inset. As the row grew, the primary glyph rectangle moved into the detail rectangle. A first dedicated-Label repair exposed two additional pre-commit defects through independent review: it sampled fallback theme values before parenting and would publish duplicate static text to accessibility.

Final bounded production correction:

- `InertPrimaryText extends Container` custom-draws the primary line with the resolved Living Forge font, size, and semantic color without publishing a second `ROLE_STATIC_TEXT` value.
- The Button retains the one exact explicit accessibility name and has empty native text.
- The primary typography is synchronized only after the row enters the themed tree.
- Collapsed and expanded heights derive from measured themed primary/detail geometry.
- Exact semantic and deliberately multiline detail phases prove containment, vertical ordering, non-overlap, wrapping, and readable minimum geometry at UI150/Text150 and UI80/Text150, in normal and high contrast.

Accepted RED evidence before production correction:

- Responsive baseline: exit `1`, `COMBAT_LOOP_RESPONSIVE_SUMMARY: FAIL failures=2`; both required corners lacked a dedicated primary rectangle.
- Theme-parity expansion: exit `1`, `COMBAT_LOOP_RESPONSIVE_SUMMARY: FAIL failures=12`; font, size, and semantic color mismatched all four normal/high-contrast Text150 corners.
- Accessibility matrix: exit `1`, `COMBAT_LOOP_ACCESSIBILITY_SUMMARY: FAIL failures=27`; the same theme mismatches reproduced across nine variants.
- Disabled-state text: four failures proved `font_disabled_color` was not transparent.
- Forced AccessKit tree: exit `1`, nine failures proved the Label overlay still exposed static-text semantics.
- Effective-name check: exit `1`, nine failures proved native Button text could append duplicate accessible copy.

Controller verification from the exact pre-commit working tree:

- `--headless --path . --quit-after 1200 --script res://tests/integration/combat_loop_responsive_runner.gd`: exit `0`, `COMBAT_LOOP_RESPONSIVE_SUMMARY: PASS`, no script/parse/load marker.
- `--accessibility always --accessibility-driver accesskit --path . --rendering-method gl_compatibility --quit-after 1200 --script res://tests/integration/combat_loop_accessibility_runner.gd`: exit `0`, `COMBAT_LOOP_ACCESSIBILITY_SUMMARY: PASS`, OpenGL Compatibility on NVIDIA GeForce RTX 4070 Ti SUPER, no script/parse/load marker.
- `--headless --path . --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_run_result_panel.gd`: exit `0`, `TEST_SUMMARY: PASS (0 failures)`, no script/parse/load marker.
- `--headless --path . --quit-after 900 --script res://tests/integration/run_result_lifecycle_runner.gd`: exit `0`, `RUN_RESULT_LIFECYCLE_SUMMARY: PASS`, no script/parse/load marker. The expected injected optional-provider warning remained non-fatal.
- `git diff --check`: clean.

Independent code review initially returned changes required for pre-parent theme sampling, weakened long-wrap coverage, high-contrast parity, and duplicate static-text accessibility. Each finding went through a new RED/GREEN pass. Final independent verdict: `APPROVED` with no blocking functional, accessibility, geometry, or test-coverage finding.

## Local-main reconciliation

- Repair parent: `8b4bfdf4a77db7a4c807c18e1dfe5538d9c4cc57`.
- Local-main parent: `6ef03e3d11829bf04b3631ee1e7ba757932ea962`.
- Command: `git merge --no-ff --no-commit main`.
- Result: automatic merge exit `0`, no unresolved entries, and exactly the two pre-authorized shared paths: `scripts/game/main.gd` and `tests/unit/test_main_wiring.gd`.
- Independent two-parent review: `APPROVED`. All 25 main-only paths match main byte-for-byte; Warehouse/City bodies and tests match main authority; Living Forge level-up, recovery, terminal, result, and tests match the feature parent; combined signal wiring remains singular and guarded.
- The first focused Warehouse batch failed closed before assertions because this worktree's Godot class cache had not registered main's new `WarehousePresentationResult`. A headless editor import exited `0` and registered the merged classes. The 59 exact untracked legacy `.uid` sidecars created by that import were moved, not deleted, to `C:\Users\Jacob\AppData\Local\Temp\party-forge-task14-import-uids-20260830` before the clean rerun.

Exact reconciliation gate rerun:

- Exact 16-suite Warehouse/City/Main focused batch: exit `0`, `TEST_SUMMARY: PASS (0 failures)`.
- `city_access_snapshot_runner.gd`: exit `0`, `WAREHOUSE_PRESENTATION_ACTIVATION_OK location=city.warehouse rollback=legacy authority=warehouse_policy`, `CITY_ACCESS_SNAPSHOT_ACCEPTANCE_OK locations=7 profiles=7 rollback=legacy`.
- `main_menu_navigation_runner.gd`: exit `0`, `MAIN_MENU_NAVIGATION_SUMMARY: PASS`.
- `warehouse_locked_dialog_focus_runner.gd`: exit `0`, `WAREHOUSE_LOCKED_DIALOG_FOCUS_SUMMARY: PASS (0 failures)`.
- Windowed OpenGL `combat_loop_responsive_runner.gd`: exit `0`, `COMBAT_LOOP_RESPONSIVE_SUMMARY: PASS`.
- Forced AccessKit/OpenGL `combat_loop_accessibility_runner.gd`: exit `0`, `COMBAT_LOOP_ACCESSIBILITY_SUMMARY: PASS`.
- Windowed OpenGL `combat_loop_performance_runner.gd`: exit `0`, `COMBAT_LOOP_PERFORMANCE_SUMMARY: PASS cases=3 frames=900 party=24 items=36`.
- `run_result_lifecycle_runner.gd`: exit `0`, `RUN_RESULT_LIFECYCLE_SUMMARY: PASS`.
- `run_terminal_flow_runner.gd`: exit `0`, `RUN_TERMINAL_FLOW_SUMMARY: PASS`.
- `run_recovery_profile_lifecycle_runner.gd`: exit `0`, `RUN_RECOVERY_PROFILE_LIFECYCLE: PASS`.
- `profile_boot_main_flow_runner.gd`: exit `0`, `PROFILE_BOOT_MAIN_FLOW_SUMMARY: PASS`.
- `run_setup_lobby_panel_runner.gd`: exit `0`, `RUN_SETUP_LOBBY_PANEL_SUMMARY: PASS`.
- `live_loot_lifecycle_runner.gd`: exit `0`, `LIVE_LOOT_LIFECYCLE_INTEGRATION: PASS`.
- `personal_loot_defeat_runner.gd`: exit `0`, `PERSONAL_LOOT_DEFEAT_INTEGRATION: PASS`.
- Every accepted rerun had zero `TEST_SUMMARY: FAIL`, `TEST_FAILURE`, `SCRIPT ERROR`, `Parse Error`, failed-resource, or loader markers.
- Warehouse's separate six-image exact-tip evidence was not regenerated because replacement authority is limited to the Task 14 evidence directory.
