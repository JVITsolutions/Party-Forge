# Combat HUD Collapse and Primary Focus Qualification

Status: AUTOMATED PASS; REQUIREMENTS REVIEW PASS; CODE-QUALITY REVIEW APPROVED; UI/UX REVIEW APPROVED; JACOB VISUAL APPROVAL APPROVED FOR EXACT CANDIDATE/EVIDENCE

## Exact Candidate and Boundary

- Worktree: `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\combat-hud-collapse-primary-focus`
- Branch: `feat/combat-hud-collapse-primary-focus`
- Exact source candidate: `bcdfe5b532e66af57e62f461b2c79b93dccf2685`
- Candidate parent: `b297cac8f057d58c1bc28c0528cb363c698f2214`
- Local `main` and `origin/main`: `b837c91954231ba808d2338b4bcc82efde720c84`
- Preserved live untracked inventory: exactly 68 Godot `.gd.uid` sidecars.
- Evidence and this report are approved for an evidence-only checkpoint commit; merge, push, and integration remain pending a separate authorization gate.
- No fetch, merge, rebase, push, reset, clean, worktree deletion, or `main` modification occurred.

Previous direct-run evidence candidates `a56936cc974864cc92fce100c29562faca26fbd6` and `a8c09f49844d111fc67347d63f9d8ef7cf54ed47` are superseded and are not approval candidates. The final candidate includes the reviewed zero-health and canonical-provenance chain:

- `efa5e2d085d8cf645213ada96ac990765259f013` — `fix: keep zero-health HUD track visible`
- `68398032aa15c7defa2621945af5f0089dbaa7f4` — `test: add canonical HUD capture orchestrator`
- `d7a0fb051f7f243f68e40ed2f466812745abbb3b` — `test: seal HUD capture provenance`
- `9844ab508dd4228833dd4780caf6e8a0d897ea5e` — `fix: preserve canonical capture process output`
- `7fbaa85edbcd9b4bff5d8fbc8b3178e56a923416` — `fix: preserve empty canonical source inventories`
- `e2ff45c9380a6debf09aa41600925cf743d5100d` — `fix: support Windows canonical inventory paths`
- `83715a2185efbb212909d984d218bf99f3aa383b` — `fix: seal canonical Godot binaries`
- `5bca91824aa8da1c1d7e4dc4dfcd305686982b8c` — `test: report exact sealed inventory drift`
- `6a362a7c57abe4e1fd1e09e40bc5b00bb1b10bbb` — `test: harden canonical evidence promotion`
- `83cf090b237212313658b78f22937467dcd9ada2` — `fix: pluralize extraction consequences`
- `f88a090fe53aa2906d5bb3952eb48ed3544a2776` — `fix: reflow the alerts tray responsively`
- `b297cac8f057d58c1bc28c0528cb363c698f2214` — `fix: give HUD headers single semantic owners`
- `bcdfe5b532e66af57e62f461b2c79b93dccf2685` — `fix: clarify collapsed HUD alert presentation`

## Owning Automated Gates

The approved 12-file focused command was:

```powershell
$focused = @(
  'tests/unit/test_party_forge_settings.gd',
  'tests/unit/test_combat_hud_projection.gd',
  'tests/unit/test_combat_hud_view_model.gd',
  'tests/unit/test_combat_hud_responsive_layout.gd',
  'tests/unit/test_combat_hud.gd',
  'tests/unit/test_main_wiring.gd',
  'tests/unit/test_living_forge_theme.gd',
  'tests/unit/test_class_selection_panel.gd',
  'tests/unit/test_terminal_extraction_panel.gd',
  'tests/unit/test_run_result_panel.gd',
  'tests/unit/test_level_up_targeting_ui.gd',
  'tests/unit/test_living_forge_components.gd'
)
& $godot --headless --path $worktree --quit-after 1200 `
  --script res://tests/focused_test_runner.gd -- $focused
```

Result: exit 0, exact `TEST_SUMMARY: PASS (0 failures)`, zero forbidden diagnostics.

Each runner used `--path $worktree --rendering-method gl_compatibility --quit-after 1800 --script`:

| Runner | Required marker | Exit | Diagnostics |
|---|---|---:|---|
| `level_up_commit_flow_runner.gd` | `LEVEL_UP_COMMIT_FLOW_SUMMARY: PASS` | 0 | clean |
| `combat_hud_input_runner.gd` | `COMBAT_HUD_INPUT_SUMMARY: PASS` | 0 | clean |
| `combat_hud_party_scale_runner.gd` | `COMBAT_HUD_PARTY_SCALE_SUMMARY: PASS` | 0 | clean |
| `combat_loop_responsive_runner.gd` | `COMBAT_LOOP_RESPONSIVE_SUMMARY: PASS` | 0 | clean |
| `combat_loop_accessibility_runner.gd` | `COMBAT_LOOP_ACCESSIBILITY_SUMMARY: PASS` | 0 | clean |
| `combat_loop_performance_runner.gd` | `COMBAT_LOOP_PERFORMANCE_SUMMARY: PASS` | 0 | clean |
| `run_setup_lobby_panel_runner.gd` | `RUN_SETUP_LOBBY_PANEL_SUMMARY: PASS` | 0 | clean |
| `level_up_five_card_geometry_runner.gd` | `LEVEL_UP_FIVE_CARD_SUMMARY: PASS` | 0 | clean |
| `terminal_extraction_flow_runner.gd` | `TERMINAL_EXTRACTION_FLOW_SUMMARY: PASS` | 0 | clean |

Logs: `C:\Users\Jacob\AppData\Local\Temp\party-forge-hud-collapse-final-bcdfe5b5-owning-e6c0d43d93f646479916ab936cda65c6`.

## Fresh Tracked-Only Cold Qualification

- Root: `C:\Users\Jacob\AppData\Local\Temp\party-forge-hud-collapse-final-bcdfe5b5-cold-15844c17725944f7906a9af6fdfdc8f2`
- Source: `C:\Users\Jacob\AppData\Local\Temp\party-forge-hud-collapse-final-bcdfe5b5-cold-15844c17725944f7906a9af6fdfdc8f2\source`
- Archive source commit: `bcdfe5b532e66af57e62f461b2c79b93dccf2685`
- APPDATA and LOCALAPPDATA were isolated beneath the cold root.

```powershell
git archive --format=zip --output=$archive bcdfe5b532e66af57e62f461b2c79b93dccf2685
Expand-Archive -LiteralPath $archive -DestinationPath $sourceRoot
& $godot --headless --editor --path $sourceRoot --import --quit-after 600
& $godot --headless --path $sourceRoot --quit-after 7200 --script res://tests/test_runner.gd
```

- Cold import: exit 0; zero forbidden diagnostics.
- Full suite: exit 0; exact `TEST_SUMMARY: PASS (262 suites)` once; zero forbidden diagnostics.
- Logs: `cold-import.log` and `cold-full-suite.log` under the preserved cold root.

## Canonical Capture Orchestration

The authoritative capture command was:

```powershell
& 'tools/validation/capture_living_forge_combat_loop.ps1' `
  -Mode Capture `
  -RepositoryRoot 'F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\combat-hud-collapse-primary-focus' `
  -CandidateHead 'bcdfe5b532e66af57e62f461b2c79b93dccf2685' `
  -GodotPath 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
```

- Orchestrator exit: 0.
- `CANONICAL_CAPTURE_COPY: PASS files=58`.
- `CANONICAL_CAPTURE_DRY_QUALIFICATION: PASS head=bcdfe5b532e66af57e62f461b2c79b93dccf2685 uid=68 png_import=213 ctex=213`.
- Canonical orchestrator self-test exit 0, including transactional rollback safety.
- Fresh detached no-hardlink clone, pre-import tracked/untracked/ignored inventories: 0/0/0.
- Clone capture: source inputs PASS count 2075; capture start 58; visual summary PASS; zero forbidden diagnostics.
- Clone validate-only: source inputs PASS count 2075; no capture-start marker; visual summary PASS; zero forbidden diagnostics.
- Transactional promotion copied only the manifest and 58 PNGs with source/staging/destination hash checks.
- Live 68 UID files were byte-identical before and after promotion: diff 0; aggregate `78c508f0793a9306860cdc40315afcadf6ab3de9a214c880a0b6088506ecc5e6`.

Preserved orchestration evidence:

- Top-level log: `C:\Users\Jacob\AppData\Local\Temp\party-forge-canonical-capture-bcdfe5b5-top-e542c9af09dc46d79de8d31fe689d80e.log`
- Run root: `C:\Users\Jacob\AppData\Local\Temp\party-forge-canonical-capture-bcdfe5b5-ada7bb8b41214bd0801fcaf15ab2b93f`
- Detached source: `C:\Users\Jacob\AppData\Local\Temp\party-forge-canonical-capture-bcdfe5b5-ada7bb8b41214bd0801fcaf15ab2b93f\source`
- Internal logs: `logs\clone.log`, `checkout.log`, `cold-import.log`, `capture.log`, `validate.log`, and `live-validate.log`.

## Manifest and Sealed Provenance

- Manifest SHA-256: `eff6238e05941d420f3333f15c1c4d01b64bef93c0a6507d26d4291fdbfe15bf`
- Captured UTC: `2026-09-01 13:08:15`; run ID: `25920-1788268057`.
- Schema version: 2; exact source head: `bcdfe5b532e66af57e62f461b2c79b93dccf2685`.
- Capture-contract SHA-256: `89925ee2ebe155eb775ccb887dac68bc5ed0e870177831277ec8e427ce56447c`.
- Source fingerprint: `2632b7449e28a47c1e83ac2ba255463f3388fb6b3d0e230003645ed2ccb8f7bb` across exactly 2075 exact-head inputs, including 509 tracked `.uid` files and the canonical orchestrator.
- Independent ordinal recomputation matched all 2075 source paths, all file hashes, and the aggregate fingerprint.
- Provenance envelope/payload schema: 1/1; payload SHA-256: `f6df1e6ebefadfc23b707268d459096425865fddc36e998fe297c82cc233ecab`.
- Orchestrator SHA-256: `13c5d3bee562f2fb21c5fa2b28eec5aaea6c82fb4146acc347e165eb323e8c2a`.
- Godot version: `4.7.1.stable.mono.official.a13da4feb`.
- Godot console/launcher SHA-256: `b2c334ff6bf1e07ded41b80bd6f4785485650db6ddbb2740b802930f35237c26`.
- Godot engine SHA-256: `8ec33ba6a6a953226170cda2a56a58810f6617261a71d6bd6d6ba7cce5e7b79d`.
- Generated UID inventory: 68, aggregate `bdbefd612ab0fa2913f882aa2bce8f1ada86c51cb66eda82419c0ffd7fede98e`.
- Runtime PNG-import inventory: 213, aggregate `c9acf5e989c65822ea3ab535e12689b3a9b7172e17d225be2a8e3fd28fbbb865`.
- Referenced CTEX inventory: 213, aggregate `fb2625ed25f291ba7dedd1b8c978639e6950a960a5900705d0adae1d063bf313`.
- Independent clone recomputation matched every sealed generated path/hash and all three aggregate hashes.
- Manifest entries/actual PNGs/unique PNG hashes: 58/58/58; hash, order, set, and stale/extra PNG differences: 0/0/0/0.
- Renderer: OpenGL Compatibility, NVIDIA GeForce RTX 4070 Ti SUPER, Windows display server; windowed.
- Independent audit: 58/58 valid PNG structures and dimensions, 58 unique hashes, 0 stale/extra, and 0 obvious blank/black outputs.
- Targeted inspection recorded the authentic 1920 and ultrawide Alerts header/tray on one inline row, the constrained 1280x720 Text150 tray wrapped below its header, and distinct semantic severity icons visible in both normal and high-contrast captures. This is evidence inspection, not the independent UI verdict.
- `extraction-confirm-primary-focus.png`: SHA-256 `0a9a7fe7f738f9208039925b0fd8703cd46a9e7821860ef6a78a496b30c8e78a`; 77,071 bytes; 13 valid chunks; 1920x1080.
- Corrected consequence copy: `You are leaving 1 extraction slot unused. 22 items will be lost.`
- Versus the superseded set, 29 PNG hashes changed and 29 stayed byte-identical.

## Final Live Validate-Only and No-Write Proof

```powershell
& $godot --path $worktree --rendering-method gl_compatibility --quit-after 900 `
  --script res://tests/integration/living_forge_combat_loop_visual_evidence_runner.gd -- --validate-only
```

- Exit 0; source inputs PASS count 2075; visual summary PASS; no capture-start marker; zero forbidden diagnostics.
- Live validation matched the sealed 68 UID, 213 PNG-import, and 213 CTEX inventories.
- Before/after inventory covered 598 files: 104 evidence-directory files, 68 generated UIDs, 213 PNG imports, and 213 CTEX files.
- Inventory SHA-256 before and after: `2ee50f0556534846733f82c5e5fe0696582d6460d99269b54303b836971bb84a`.
- No-write proof: PASS.
- Validate log: `C:\Users\Jacob\AppData\Local\Temp\party-forge-live-validate-bcdfe5b5-6f6ef0ea64584d5eb8b008d553040ab7.log`.

## Exact 58-File Inventory

| File | SHA-256 | Dimensions | Focus target |
|---|---|---:|---|
| hud-no-alert-rich-1.png | `96ec3427cafacb382b926ac11aeaa41b1f58e8bf450232b1c0588a8d88246d75` | 1920x1080 | `none` |
| hud-rich-6-three-alerts.png | `23d7332a7763f933b00c4d66008c2f95663bff3a6bbd49e736fbf5af2cd4932f` | 1920x1080 | `none` |
| hud-compact-7.png | `44e7ebe29832f19aeefd61f3d441b7d66e76b06421dcba9c9f67f15ccbc9f0b6` | 1920x1080 | `none` |
| hud-compact-20-overflow.png | `8c7af7f5d67386bddbf6b72431073411bb89b7b81828d9bb6a9747eecf7a3ea1` | 1920x1080 | `none` |
| hud-compact-24-final-member-focus.png | `5dd7bb1fa6db35f93c4d6e6307f7d7d7fb03d9d2857282cf1d4c6d6b3e900a39` | 1920x1080 | `member:24` |
| hud-alert-tray-focus.png | `ea055e154251df1aba95ea3890b634c62a2eb1c46a595846f9c78ed6c637d054` | 1920x1080 | `alert_tray:close` |
| hud-alert-inspect-return.png | `1ec8ac6cc69eee2ec9b23f76a2c243238f492e6a1eb44b02359e6c3252f1be02` | 1920x1080 | `alert:inspect` |
| hud-alert-ledger-return.png | `76cfcd79a65fb07db494f33a109bfe2afd2c6475bb7cebf1f4ffb19a73dc7002` | 1920x1080 | `alert:ledger` |
| level-up-direct-and-targeted.png | `e24945b47748c8d66b7e928707e348a3bed24fa21b609fd1e9b86950fcea4832` | 1920x1080 | `upgrade_card:1` |
| level-up-recipient-24.png | `f380a4e7fc55648f1511cd21c3138640bf85530ff71eb12c625f0dab92382e98` | 1920x1080 | `recipient:24` |
| extraction-automatic-selected-lost.png | `89dc445a4ddc9fa662a0f02886736be181a2b38fb7f4935321546ec523daf5fb` | 1920x1080 | `none` |
| result-victory-current-truth.png | `775bbd1d65e38a2b7efaa0ef82dc283643c8c7b7b46c90145d8f37adab2582eb` | 1920x1080 | `result:return_to_forge` |
| result-defeat-losses.png | `da4032a1cadd1ab2259efe21ff34c9a49160cc03c604c845c29814e07ebf651b` | 1920x1080 | `result:lost_row` |
| result-resolution-interrupted.png | `d9da93a07a7dd5b79cf4261f7330b06a9eaf87cee05b077c4335c1f1b0463943` | 1920x1080 | `result:retry_resolution` |
| result-terminal-save-interrupted.png | `0f0d48db8cbca93157f0c508326dd966214aa6c7baf5486ecdfd2bad10dea29f` | 1920x1080 | `result:retry_terminal_save` |
| result-projection-interrupted.png | `f402529e913d86984f3124b8093f06f19b35f3b1bcba4a050e3ca6e76ff7c4e5` | 1920x1080 | `result:retry_projection` |
| result-automatic-overflow-recovery.png | `635f391468c33d8308e67eb1e338cee90ef56a959180e460abf932cbc2793c03` | 1920x1080 | `confirmation:cancel` |
| combat-loop-720p-text-150.png | `9dcd2720b3491439b7ffa19943307fc5bf98821a0ed0f3e9873b38f008df40a7` | 1280x720 | `hud:member` |
| combat-loop-720p-ui-150-text-150.png | `9f21ae3ca00bea95cc23e17df1005b93e853b908c4dbccb76cf2bd671675dd7d` | 1280x720 | `hud:member` |
| combat-loop-720p-ui-80-text-150.png | `38a73bc53894ae4f2047568a296282d482a860040e1a3385539107435562fe7e` | 1280x720 | `member:24` |
| combat-loop-1440p.png | `593b8d45f87fb80d5b64589ba3368eac30721fe94ee36cb71ea920418f413a03` | 2560x1440 | `none` |
| combat-loop-ultrawide.png | `135d9770887d352415b62977ce283b84cdcc47033014fdc2b7e70eeba99fcdfc` | 3440x1440 | `hud:overflow` |
| combat-loop-high-contrast.png | `86d8afa82d1625043197e158905be8aeb1d41f6666690069ed4b03ab03aefd80` | 1920x1080 | `hud:alert_inspect` |
| combat-loop-reduced-motion.png | `c8bc6d3f4259b0953459525da4be70ceff63cacafac61543bcc682f4dd364648` | 1920x1080 | `none` |
| combat-loop-ui-scale-150.png | `f5470e66932886667acac33d870a870aec463d4d2ec43348d0b4aa421e7042e8` | 1920x1080 | `hud:overflow` |
| combat-loop-controller-focus.png | `d4419a54ae1be9cb7577275c43d763dfd8204dea3cfe378f2365ced7cfbb73bb` | 1920x1080 | `hud:member` |
| combat-loop-mouse-hover.png | `820403ad2e52fe814790860ace5bfbdcd083f13caafbbb3e0081bad8ed28fa34` | 1920x1080 | `hud:hover` |
| result-pending-terminal-save.png | `3b6d57a6b929213840aa04275752d88ea3a52344c050d01e603398ab05ef0d24` | 1920x1080 | `none` |
| result-pending-terminal-refresh.png | `96bcf7a598ac5a9b2a10a9439cc884627604dd083a341ed4c31eff01846655a4` | 1920x1080 | `none` |
| result-pending-resolution.png | `9dcbfef71877d5ef81a9fd48c734978f14f5a016f6581ddca2c11f49a6f03922` | 1920x1080 | `none` |
| result-pending-projection.png | `1e68da2d9c4250bedbbd1efa1278256fdd76469ea804a7d541a7ce54b29fbf14` | 1920x1080 | `none` |
| result-pending-protection.png | `9c29c923648bb7b4409933d65852f708a4e2648a8b4981bc7b721fe7ada6f7eb` | 1920x1080 | `none` |
| result-pending-terminal-completion.png | `e9295c8290ff3b64d42d189a995051571cf5203aaab36456b603f4aa8502749a` | 1920x1080 | `none` |
| result-finalized-receipt-clear-error.png | `c1381907bf9f7d582f1721a91e016bb5076f1451b22cc3fa035b55e3c107d679` | 1920x1080 | `result:return_to_forge` |
| result-finalized-committed-refresh-retry-only.png | `78aa1ef45bcccbf108233be98ae02486beb55d84a435d9599d1404e2d2db63c2` | 1920x1080 | `result:return_to_forge` |
| result-terminal-refresh-interrupted.png | `ba7deea78cb67f3e3b3751fa87e01111f4e77cf2330a90955c200b5df95c6a60` | 1920x1080 | `result:retry_terminal_refresh` |
| pause-abandon-committed-refresh.png | `0e251b413d97fdbc0792e16e3d92357ad623668a5190315562080f5592235915` | 1920x1080 | `pause:retry_return_to_forge` |
| restart-lobby-valid-preselection.png | `9c7645270bbbb286af29731e1770fe2b654176829ace518bc8865c7055af1c50` | 1920x1080 | `lobby:mage` |
| restart-lobby-unresolved-selection.png | `b9ae0585f29054e6b01238e193282aad4068c9c743390108697907478984e277` | 1920x1080 | `lobby:first_class` |
| hud-alert-720p-ui-150-text-150.png | `12b8aec45f2d769bc9836aeea89a07e60c166f53142e130cab9223e8aed5c512` | 1280x720 | `hud:alert_inspect` |
| level-up-confirmation-safe-focus.png | `c18380c709d8542f1a8b64b5737ce12ef24bca1c494157d57ff4c68ec9514910` | 1920x1080 | `confirmation:cancel` |
| extraction-pending-focus.png | `4d884ef44ca860fb22b233a47fb381834549baa1739fee33031f3ae0c647a132` | 1920x1080 | `extraction:show_auto` |
| extraction-detail-720p-ui-150-text-150.png | `51cecdc3d8109854ec21d9c0cecf759d0c0f906680740ba2687748a17f8f9f16` | 1280x720 | `extraction_detail:close` |
| result-expanded-detail-ui-150-text-150.png | `a7c8f93d827fbae29f9b44817470fe7cddc6df1bec46528b8a0af8ee38949714` | 1280x720 | `result:expanded_row` |
| result-expanded-detail-ui-80-text-150.png | `585661bc1f1bd82e654635b3d2165daad4452cdcc65c3e8475e13f3239ec3680` | 1280x720 | `result:expanded_row` |
| hud-party-collapsed-6-clear.png | `bc556f007c673af5cf48b6c1abeaae30603dc6cdfd9d610a417ce11e94fa8ddb` | 1920x1080 | `hud:party_header` |
| hud-party-collapsed-24-severity.png | `686fe86c5807b2bbfebff0e4de664a0184b6f7dcc9c3cc37f5dc1945963441b6` | 1920x1080 | `hud:party_header` |
| hud-alerts-collapsed-dead-focus.png | `7dcca25ae4579d78ee2efab6d95b60385be8099990daf41f74c2fd379f9c8b48` | 1920x1080 | `hud:alerts_header` |
| hud-alerts-collapsed-all-clear.png | `d8e055a60f4723e5fbf0dc18fa8c8f47759060c5eeb9c5d8738106880712d071` | 1920x1080 | `hud:alerts_header` |
| hud-both-collapsed-720p-text-150.png | `e1e4f5ee30f51e7a525d8b349f6dbc6cc5b89fccee4d7ed75c70344a4fa18228` | 1280x720 | `hud:party_header` |
| hud-both-collapsed-high-contrast.png | `e0c71127a62d33cec5aa6b14f47fc7737b713c1c126e9b69d8af54c68c337da3` | 1920x1080 | `hud:alerts_header` |
| hud-alerts-collapsed-controller-tray-focus.png | `72dc8b0a5d03949d928be5bf88f11b612020267b9861f6a3f1d7ba48adb1885c` | 1920x1080 | `hud:alerts_tray_action` |
| hud-both-collapsed-reduced-motion.png | `93aabae3a6b674ab67de6e5308069955bee3cd36df91d37ef8cd686e5d7d1ef4` | 1920x1080 | `hud:party_header` |
| lobby-start-run-primary-focus.png | `3aa262cc114ea4fe9bf0fbe8dc92029fb78a4ca3c0e2a5ce8bad617fb4cbe099` | 1920x1080 | `lobby:start` |
| extraction-confirm-primary-focus.png | `0a9a7fe7f738f9208039925b0fd8703cd46a9e7821860ef6a78a496b30c8e78a` | 1920x1080 | `extraction:confirm` |
| extraction-consequence-primary-focus.png | `e25303ee5e64ed72ade4e24057a6748de63486fda50d5cdbefa8526230a68280` | 1920x1080 | `extraction:acknowledge` |
| level-up-confirm-primary-focus.png | `135399109aff394e0694fc55cff9c34edb7eb476f64837ebc1aa7051c9b96812` | 1920x1080 | `level_up:confirm` |
| result-primary-retry-focus.png | `3ed666b80f3c782d5a8579b89e5ea5cbe90cbf8944320ef17ac6b174b340ea80` | 1920x1080 | `result:retry_resolution` |

## Review and Human Gates

- Automated qualification: PASS.
- Requirements review: PASS for exact candidate/evidence.
- Code-quality review: APPROVED for exact candidate/evidence.
- UI/UX original-resolution review: APPROVED for exact candidate/evidence.
- Jacob visual approval: APPROVED only for candidate `bcdfe5b532e66af57e62f461b2c79b93dccf2685`, schema-2 manifest SHA-256 `eff6238e05941d420f3333f15c1c4d01b64bef93c0a6507d26d4291fdbfe15bf`, and its exact 58-shot evidence set.
- Physical-controller validation: deferred/nonblocking; automated coverage uses the approved simulated-controller path.

## Rollback

- Revert only a rejected correction/orchestrator slice and its dependent later commits; never reset or clean the worktree.
- Preserve schema-v3 read compatibility if persistence changes are rolled back after release.
- Any source change invalidates this exact-head evidence and requires a complete canonical orchestration, all automated gates, and fresh independent reviews.
