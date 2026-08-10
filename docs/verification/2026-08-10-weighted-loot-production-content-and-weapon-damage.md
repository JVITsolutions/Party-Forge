# Weighted loot production content and weapon damage verification

Date: 2026-08-10

## Accepted revision and boundary

- Branch: `feat/weighted-loot-production-content`
- Main merge base: `e4466e180a7c6524590352d1fdcb9a117878fbbf`
- Exact functional HEAD under test: `bb280feddabadbdb4deabcff6ea9d5fb5fb20efb` (`fix: reject invalid resumed item sequences`)
- Final integration-test commit: `96a044fe919052cfd25907143e1802a61a2cc4ba` (`test: verify weighted loot integration`)
- Evidence lineage: `830ff6b10e9c32960faace2abb26e2b0f5d4ff6a` is the documentation-only child of the tested functional HEAD. This corrective documentation/scratch-hygiene commit is a child of `830ff6b10e9c32960faace2abb26e2b0f5d4ff6a`; resolve its immutable hash with `git log -1`. Neither evidence commit is represented as part of the functional bytes tested below.
- Godot: `4.7.1.stable.mono.official.a13da4feb`
- No merge to `main`, push, worktree deletion, or branch deletion was performed.

The verified functional history from the merge base through the exact head is:

| Commit | Subject |
| --- | --- |
| `869ab8f0f7fca184d93364f73b0c69d07edbee82` | `docs: design weighted loot production content` |
| `0cb49e9a798055aa91443baac5668a5ba6257224` | `docs: plan weighted loot production content` |
| `9d1ca6d23733d6bc6ca6b8f729b08ea59b1616c7` | `feat: add immutable weapon damage item data` |
| `be8203f7d126640fad22cd2a450424742a6d6686` | `fix: update schema two item issuance callers` |
| `e8e1838efaacc93771966a5474810fb4156487a6` | `feat: define typed weapon damage profiles` |
| `5cd547c1576bf83230a76c4a6601f532c5ff5ddf` | `feat: roll deterministic weapon base damage` |
| `13441fe7a22cf7aca8871b9219c4ab80e655bfac` | `fix: reject invalid weapon damage rolls` |
| `15abe6eef1b0448ea0cde17bf54ac5d209dc1a89` | `feat: author weighted loot affix manifest` |
| `08b91f4827f644acc98d13f614c4c4229cefe590` | `feat: author implicit and weapon profile rows` |
| `85e0274890ea1b60728a840e520dc83a0e78ca87` | `feat: generate production weighted loot content` |
| `6e0780a1cb11d740ae85403f6a4a4e51e9b6cdf5` | `fix: make weighted loot parity independent` |
| `0aa74bb90de16337c6514af08d2f67c749e6c957` | `feat: resolve active weapon damage snapshots` |
| `7ee9bf2048b74c9215f82aa467575a211593aa8e` | `feat: publish weapon projections atomically` |
| `e4eb5a7de66e1fb5e9e67a6a60effe58079b2035` | `fix: close weapon projection transaction gaps` |
| `9f21b267d0b61b64a700f6679d2724df73ad0305` | `fix: publish whole-party revisions before signals` |
| `4213ef0bedb2653caf9d264c222394038589155e` | `feat: use weapon damage in playable attacks` |
| `c368aaf3889964a48692e8a94a678162c5465752` | `feat: present weapon ranges and comparisons` |
| `ec04dd02f497108754b3775d8b767ca102ad66d4` | `fix: classify weapon range comparisons safely` |
| `3e1ad3ea6882c7179b1e774738a9d29ebced6cc2` | `test: record weighted loot balance evidence` |
| `96456c103ebd2bda87ad3acf9e470df82eabedfa` | `fix: make weighted loot evidence trustworthy` |
| `70f1a7312a722a443408188936dc100dce36bc65` | `fix: reject duplicate balance sample streams` |
| `1de3773c286f270319c63c7ba05b6d1595af0834` | `fix: normalize reloaded run bootstrap identity` |
| `96a044fe919052cfd25907143e1802a61a2cc4ba` | `test: verify weighted loot integration` |
| `bb280feddabadbdb4deabcff6ea9d5fb5fb20efb` | `fix: reject invalid resumed item sequences` |

## Commands and accepted results

`$godot` below is `F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe`. All Godot commands were executed sequentially in the authoritative weighted-loot worktree. `--quit-after` values are frame counts; shell budgets allowed each real process to exit.

| Gate | Command | Exit / runtime | Required result |
| --- | --- | --- | --- |
| Version | `& $godot --version` | `0` | `4.7.1.stable.mono.official.a13da4feb` |
| Cold editor import | `& $godot --headless --path . --editor --quit-after 600` | `0` / 11.473s | editor initialization completed; zero script/parser/loader failure markers |
| Exact 13-suite feature batch | `& $godot --headless --path . --quit-after 1800 --script res://tests/focused_test_runner.gd -- tests/unit/test_item_base_damage_component.gd tests/unit/test_weapon_damage_profile.gd tests/unit/test_weapon_base_damage_roller.gd tests/unit/test_weighted_loot_content_rows.gd tests/unit/test_weighted_loot_builder_parity.gd tests/unit/test_active_weapon_damage_resolver.gd tests/unit/test_equipment_transition_service.gd tests/unit/test_action_damage_component_projection.gd tests/unit/test_damage_resolver.gd tests/unit/test_action_combat_estimate_service.gd tests/unit/test_item_presentation_projector.gd tests/unit/test_item_tooltip_card.gd tests/unit/test_item_generation_balance_report.gd` | `0` / 11.209s | exactly one `TEST_SUMMARY: PASS (0 failures)`; zero FAIL/test-failure markers |
| Full ordinary suite | `& $godot --headless --path . --quit-after 2400 --script res://tests/test_runner.gd` | `0` / 169.601s | exactly one `TEST_SUMMARY: PASS (174 suites)`; zero FAIL/test-failure markers |
| Weighted integration | `& $godot --headless --path . --quit-after 1800 --script res://tests/integration/weighted_loot_production_runner.gd` | `0` / 4.746s | `WEIGHTED_LOOT_PRODUCTION_INTEGRATION: PASS` once |
| Progression/load | `& $godot --headless --path . --quit-after 1800 --script res://tests/integration/progression_24_member_runner.gd` | `0` / 18.971s | size markers for 1/6/12/24; isolation, weapon-isolation, and summary PASS markers once each |
| Tooltip responsiveness | `& $godot --headless --path . --quit-after 1200 --script res://tests/integration/item_tooltip_responsive_runner.gd` | `0` / 3.487s | 1280x720 compatibility; 1920x1080, 2560x1440, 3840x2160 size PASS; `ITEM_TOOLTIP_RESPONSIVE_SUMMARY: PASS (3 sizes)` |
| Rejected global-user startup | `& $godot --headless --path . --quit-after 600` | `0` / 6.515s | both readiness markers once, but rejected because three pre-existing Task 11 sentinel profiles emitted `PROFILE_BOOTSTRAP_ERROR`; this run is not accepted startup evidence |
| Accepted isolated startup | exact environment and command reproduced below | `0` / 6.513s | `PARTY_FORGE_BOOT_OK` exactly once; `PARTY_FORGE_CLASS_SELECTION_READY` exactly once; zero script/parse/load/bootstrap/failure diagnostics |
| Content regeneration | `& $godot --headless --path . --quit-after 900 --script res://tools/build_weighted_loot_content.gd` | `0` / 1.171s | `PARTY_FORGE_WEIGHTED_CONTENT_BUILD_OK documents=306` |
| Full balance regeneration | `& $godot --headless --path . --quit-after 1800 --script res://tools/export_weighted_loot_balance_report.gd` | `0` / 592.044s | `WEIGHTED_LOOT_BALANCE_REPORT: PASS rows=82 attempts=164000 unique_ids=164000` and expected hashes |
| Tracked-byte comparison | SHA-256 and size manifest for every `git ls-files` path before versus after both generators; `git diff --quiet`; `git diff --cached --quiet` | `0` / 2.3s | 2,618 rows before and after; zero row differences; both Git diff exits `0` |
| Final hygiene | exact generated-UID allowlist removal; protected path/hash comparison; `git diff --check` | `0` | 22 generated UIDs removed; exact protected 135 remain; zero protected mismatches |

### Reproducible accepted startup command

The accepted startup used the following literal PowerShell assignments and command from the authoritative worktree. The directories still resolve to the exact retained task-local structure used by the run.

```powershell
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
$task13UserDataRoot = Join-Path (Get-Location) '.superpowers\sdd\weighted-loot-task13-userdata'
$task13Roaming = Join-Path $task13UserDataRoot 'roaming'
$task13Local = Join-Path $task13UserDataRoot 'local'
New-Item -ItemType Directory -Force -Path $task13Roaming,$task13Local | Out-Null
$env:APPDATA = $task13Roaming
$env:LOCALAPPDATA = $task13Local
$startupLog = '.superpowers\sdd\weighted-loot-startup-isolated.log'
& $godot --headless --path . --quit-after 600 2>&1 | Tee-Object -LiteralPath $startupLog
```

The resolved environment paths were:

- `APPDATA`: `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\weighted-loot-production-content\.superpowers\sdd\weighted-loot-task13-userdata\roaming`
- `LOCALAPPDATA`: `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\weighted-loot-production-content\.superpowers\sdd\weighted-loot-task13-userdata\local`
- Accepted log target: `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\weighted-loot-production-content\.superpowers\sdd\weighted-loot-startup-isolated.log`

The polluted global-user startup was rejected. Only this task-local isolated invocation is the accepted startup result.

## Content and balance evidence

- Builder output: 306 canonical documents.
- Manifest: 99 bases; 195 affixes; 96 explicit affixes (64 focused, 24 standard hybrids, 8 premium hybrids); 99 unique implicits; 48 prefixes; 48 suffixes; 11 weapon-profile bases; twelve tiers.
- Balance artifact: schema 2, status `ok`, 82 deterministic scenarios, 164,000 attempts, 164,000 successes, zero failures, 164,000 unique instance IDs, zero duplicate instance IDs, and zero origin-identity mismatches.
- JSON SHA-256 before and after regeneration: `67fae56aa1c53a4fa886612e7747ee8eae588fbaf6149898e6e65f2ab67a8a9d`.
- Markdown SHA-256 before and after regeneration: `054cbd87290b555dc9f52a20b07d7d89915142869567a9eae6b841b5580f2cdd`.
- The 2,618-row tracked path/size/content manifest SHA-256 was `a599618a1421d9dde73d151659bc75dacc34423fd6cc18c7b664186bf11798c6` both before and after regeneration. A successful generator exit was not used as byte-parity proof by itself.

## Schema, integration, and 24-member cases

The weighted production runner exercised the literal schema-1 legendary sword fixture through codec migration to schema 2, explicit empty base-damage fallback state, durable profile storage, run checkout/resume, inactive weapon snapshot, and authored fallback combat components. The schema-2 path covered deterministic weapon/support issuance, immutable rolled damage ranges, persistent storage and assignment, canonical run bootstrap encode/decode, two-member activation, weapon tooltip/range presentation, runtime attack/damage resolution, save/reload/resume, and extraction back to leader loadout and personal stash.

Failure and atomicity cases included invalid persistent destination, failed save, wrong-owner run issuance, stale extraction source, extraction persistence failure/retry, failed generation without sequence consumption, and resumed sequence validation for duplicates, exhaustion, nonzero gaps, foreign namespaces, malformed origins, empty history, and schema-1 migration. Rejections preserved profile bytes, live ownership, equipment, revisions, signals, party state, and generation sequence as applicable.

The same runner also configured a public 24-member run, issued 24 distinct main-hand items, and proved that a transition for member one preserved all 24 immutable item byte records and the other 23 equipment records. The dedicated progression runner independently covered 1/6/12/24-member load sizes and reported:

- `PROGRESSION_24_MEMBER_ISOLATION_PASS members=24 untouched=23`
- `PROGRESSION_24_MEMBER_WEAPON_ISOLATION_PASS members=24 untouched=23 distinct_main_hands=24`
- `PROGRESSION_24_MEMBER_SUMMARY: PASS`

## Diagnostics and retained raw evidence

Cold import emitted 16 expected missing-UID warnings and no unexpected script/parser/loader failure. Later focused/integration/generator loads created six additional sidecars. All 22 exact task-generated paths and hashes were recorded before removal.

The focused batch deliberately emitted the asserted wrong-path weighted-builder error, invalid/stale combat packet errors, and non-finite-stat rejection; it retained the established exit-only warning of 18 leaked ObjectDB instances and five resources in use. The full suite emitted its assertion-owned negative-path domain errors and persistence warnings, but no FAIL/test-failure summary and no shutdown-leak marker. Tooltip responsiveness retained its known exit-only warning of two leaked ObjectDB instances and one resource in use. These messages are not represented as clean shutdowns. The accepted isolated startup and both generator logs had no unexpected parse/load/failure diagnostic.

Raw ignored evidence retained for inspection:

- `.superpowers/sdd/weighted-loot-task-13-report.md` — initial process/Git inventory plus exact protected and tracked UID path/content hashes.
- `.superpowers/sdd/weighted-loot-cold-import.log`
- `.superpowers/sdd/weighted-loot-focused-feature.log`
- `.superpowers/sdd/weighted-loot-full-suite.log`
- `.superpowers/sdd/weighted-loot-production-integration.log`
- `.superpowers/sdd/weighted-loot-progression-24-member.log`
- `.superpowers/sdd/weighted-loot-tooltip-responsive.log`
- `.superpowers/sdd/weighted-loot-startup.log` — preliminary global-user-data run.
- `.superpowers/sdd/weighted-loot-startup-isolated.log` — accepted diagnostic-clean startup.
- `.superpowers/sdd/weighted-loot-regenerate-content.log`
- `.superpowers/sdd/weighted-loot-regenerate-balance.log`
- `.superpowers/sdd/weighted-loot-tracked-before.tsv` and `.superpowers/sdd/weighted-loot-tracked-after.tsv`
- `.superpowers/sdd/weighted-loot-regeneration-before.log` and `.superpowers/sdd/weighted-loot-regeneration-after.log`
- `.superpowers/sdd/weighted-loot-generated-uids.log`

## Sidecar and worktree disposition

The protected pre-existing baseline contained exactly 135 untracked `.gd.uid` files. Its canonical sorted `path|content-SHA-256` digest was `ef4d9b2f5ee4ad845e565e485d4673f2e3c9618eb645432c4042eb4ba093f202` and its total byte count was 2,661. After all gates, the 22 paths absent from that baseline were removed individually only after the exact worktree Godot process count reached zero. The final protected count, bytes, and digest are identical, with zero missing, added, or byte-changed protected path. Tracked UIDs remained byte-identical through the full tracked manifest comparison.

## Explicit deferrals and locked scope

- Physical-controller acceptance was not performed.
- Human GPU-backed visual/pixel review was not performed. Headless tooltip geometry evidence is not a substitute for human visual acceptance.
- Ground drops and pickup remain out of scope.
- The ledger equipment-inventory page remains locked/out of scope.
- Upper-rarity product unlocks remain locked/out of scope; deterministic balance evidence does not enable them.
- This verification does not merge the branch into `main`.
