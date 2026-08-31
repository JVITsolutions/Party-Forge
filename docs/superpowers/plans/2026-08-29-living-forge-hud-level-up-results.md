# Living Forge HUD, Level-Up, and Run Results Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Party Forge's fixed four-member HUD, generic level-up flow, and boolean result popup with one stylized Living Forge combat-loop slice that remains truthful, responsive, and fully reachable for parties of one through twenty-four.

**Architecture:** Add copy-owned typed projections between gameplay truth and each screen, then compose them from the existing Living Forge theme/components. Keep `PartyManager`, `UpgradeApplicationService`, `RunExtractionPolicy`, `RunResolutionService`, and `PartyForgeMain` authoritative; UI objects present truth and emit bounded intent only. Terminal handling captures immutable run truth before cleanup, performs an explicit extraction choice and service-owned preflight, resolves durably, and only then enables the recap and terminal actions.

**Tech Stack:** Godot 4.7.1 stable, typed GDScript, `.tscn` scenes, existing Living Forge `Theme` and component resources, SVG assets, focused unit suites, real-SceneTree integration runners, windowed OpenGL Compatibility screenshot capture, Git, and PowerShell.

## Global Constraints

- Execute in the existing isolated worktree `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\living-forge-combat-loop-ui` on branch `feat/living-forge-combat-loop-ui`; do not edit the saved-project checkout.
- The commit that adds this plan must have exact first parent `b1b87e18bf488c48e6e6955adc4a235e7d4ee589`, and baseline `4c4acb5e001b0cfbb64aa06358b42b7ed9a67eb9` must remain an ancestor. Stop and re-audit if either invariant fails.
- Use `superpowers:test-driven-development` for every behavior change and `superpowers:verification-before-completion` before any completion claim.
- Use subagents task-by-task. A fresh implementation worker completes one task, a requirements reviewer checks it against this plan, and a code-quality reviewer checks the accepted diff before the task commit.
- Preserve the approved Living Forge style: forged dark surfaces, warm metal hierarchy, restrained ember accents, Source Sans 3 body copy, Cinzel display copy, non-color state cues, and the existing normal/high-contrast theme catalog.
- Do not set a project-wide theme in `project.godot`. Attach Living Forge themes only to this slice's changed screens.
- Support ordered parties of `1..24` without truncation: rich mode for `1..6`, compact mode for `7..24`.
- Show no more than three expanded alerts and one deterministic `+N alerts` control. Current production-backed alert kinds are critical health, downed, and dead; do not invent crowd-control, separation, objective, or tactics state.
- The HUD exposes Inspect and Ledger routes only. Do not add combat commands or the future Final Fantasy XII-style per-member/group/team tactics editor in this slice.
- Simple non-recipient upgrades commit directly. Recipient-targeted and recruitment choices require confirmation. Visual presentation never decides application authority.
- Do not infer exact authored deltas before a recipient is selected. Show an authored summary unless a mutation-free identical consensus is proven; show exact recipient deltas in confirmation.
- Terminal UI emits item IDs only. It never authors `expected_source_container_id` or `expected_source_slot`; the terminal flow maps selected IDs back to fresh `RunExtractionPolicy` selections.
- Capture terminal truth before `_clear_live_loot()`. Do not show a result recap or enable consequence-assuming actions before durable `RunResolutionService` success and a matching `RESOLVED_AWAITING_PROJECTION` receipt.
- Result claims are restricted to current authoritative truth: outcome, duration, ordered party identity/class/leader/final level, automatic/eligible/selected/lost item identity, catalog-backed item presentation, protected displaced-gear placement, and accepted durable extraction. Hide unsupported upgrade history, damage, healing, kills, highlights, and unrelated profile deltas.
- `Restart Run` opens a prefilled lobby and requires explicit Start Run; `Return to Forge` reloads the resolved front end; `Quit Application` exits only after durable resolution; `Abandon Run` never appears on terminal results.
- Every changed action must have mouse, keyboard, and simulated-controller outcome parity. Physical-controller acceptance remains separately labelled until performed.
- Use unique `user://tests/living_forge_combat_loop/...` roots. Never run fixtures against `ProfileStore.DEFAULT_ROOT` or live user documents.
- Party structure rebuilds only on ordered-party revision/change; health, XP, timer, boss, and alert values update bounded existing controls. Do not add a `_process()` loop per member, alert, item, or recap entry.
- Pixel capture requires a windowed OpenGL Compatibility run. Dummy-renderer or headless screenshots are not visual evidence. Because Jacob is remote, show the candidate screenshots in the conversation before visual acceptance.
- Third-party or generated icons require one coherent Living Forge normalization pass plus source/generator, licence, and SHA-256 records in `docs/third_party/living-forge-ui-assets.md`.
- Run a complete editor import with `--headless --import`; do not use `--editor --quit-after 300` as an import gate because it can abort before `.godot/imported` is populated.
- A complete-suite pass requires exit `0`, a fresh exact `TEST_SUMMARY: PASS (255 suites)` marker (baseline `238` plus the `17` new unit suites declared here), and no parser/loader/script-error markers. Exit code alone is insufficient.
- This repository tracks `.gd.uid` files. Import after each task that creates scripts, commit intended UIDs beside those scripts, and remove only unrelated generated sidecars whose corresponding `.gd` was already tracked.
- Do not push, merge, or delete the worktree without explicit user authorization.

Use this classifier immediately after every import that creates scripts. Re-declare it in each new PowerShell process and pass the exact intended UID list for that task:

```powershell
function Resolve-GeneratedUidState([string[]] $intendedUids) {
	$repoRoot = [IO.Path]::GetFullPath((Get-Location).Path)
	$intended = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
	$intendedUids | ForEach-Object { [void]$intended.Add($_.Replace('\', '/')) }
	$untrackedUids = @(git ls-files --others --exclude-standard -- '*.gd.uid')
	foreach ($uid in $untrackedUids) {
		$normalizedUid = $uid.Replace('\', '/')
		if ($intended.Contains($normalizedUid)) { continue }
		$scriptPath = $normalizedUid.Substring(0, $normalizedUid.Length - 4)
		git ls-files --error-unmatch -- $scriptPath *> $null
		if ($LASTEXITCODE -ne 0) { throw "Unexpected UID without a previously tracked script: $normalizedUid" }
		$uidResolved = [IO.Path]::GetFullPath((Join-Path $repoRoot $normalizedUid))
		if (-not $uidResolved.StartsWith($repoRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or -not $uidResolved.EndsWith('.gd.uid', [StringComparison]::OrdinalIgnoreCase)) { throw "Unsafe generated UID path: $uidResolved" }
		Remove-Item -LiteralPath $uidResolved
	}
	$missing = @($intendedUids | Where-Object { -not (Test-Path -LiteralPath (Join-Path $repoRoot $_)) })
	if ($missing.Count -gt 0) { throw "Expected task UID was not generated: $($missing -join ', ')" }
}
```

---

## File and Responsibility Map

### Combat HUD

- `scripts/ui/hud/party_member_hud_projection.gd`: copy-owned member identity, class, level/rank, health, leader, and condition presentation.
- `scripts/ui/hud/combat_alert_projection.gd`: stable alert identity, severity, member identity, readable state, and Inspect/Ledger availability.
- `scripts/ui/hud/combat_hud_projection.gd`: ordered complete party, complete ordered alert set, derived three-alert surface/overflow count, XP/timer/boss values, and validation.
- `scripts/ui/hud/combat_hud_view_model.gd`: translates `PartyManager`, health providers, `ExperienceSystem`, run clock, and boss truth into projections; owns stable sorting and diff keys.
- `scripts/ui/hud/combat_hud_responsive_layout.gd`: pure rich/compact and visible-window calculations for supported viewport/UI/text scales.
- `scripts/ui/living_forge/components/forge_party_member_card.gd` and scene: rich member presentation.
- `scripts/ui/living_forge/components/forge_party_member_marker.gd` and scene: compact member presentation.
- `scripts/ui/living_forge/components/forge_alert_card.gd` and scene: alert severity plus non-color icon/text/shape cues.
- `scripts/ui/hud/combat_alert_tray.gd` and scene: complete overflow list, focus, pause lease, Inspect/Ledger routes, and exact return focus.
- `scripts/ui/hud/combat_member_inspect_panel.gd` and scene: bounded read-only member summary opened from HUD or alert tray.
- `scripts/ui/hud.gd`, `scenes/ui/hud.tscn`: stable public HUD adapter/composition, signal subscriptions, bounded refresh, focus graph, and existing boss/banner/loot surfaces.

### Level-up

- `scripts/ui/level_up/upgrade_offer_projection.gd`: copy-owned offer identity, category/icon/name/rarity/effect/scope/rank/eligibility/tags/disabled reason.
- `scripts/ui/level_up/upgrade_offer_projection_service.gd`: builds truthful projections from exact choices, party, catalogs, and existing presentation services.
- `scripts/progression/level_up_application_result.gd`: typed accepted/rejected result with exact choice/recipient identity and player-readable reason.
- `scripts/progression/level_up_application_policy.gd`: validates direct/recipient/context application routing without mutating party state.
- `scripts/progression/upgrade_choice.gd`: adds authoritative `ApplicationRoute` and `application_route()`.
- `scripts/ui/upgrade_card.gd`, `scripts/ui/level_up_reveal_controller.gd`, `scripts/ui/level_up_panel.gd`, and matching scenes: Living Forge offer presentation, direct activation, recipient/context confirmation, pending state, and exact focus restoration.
- `scripts/game/main.gd`: consumes one unified `application_requested(choice, recipient_member_id)` signal and remains the only UI composition route into the authoritative application service.

### Terminal extraction and durable resolution

- `scripts/extraction/run_resolution_source.gd`, `run_resolution_source_result.gd`: immutable live-or-recovered run authority containing exact run identity, ordered member/class/leader rows, run item ownership, leader class, and resolved leader attributes.
- `scripts/extraction/run_resolution_evaluation.gd`: copy-owned evaluation facts, extraction projection, stash requirements/availability, and exact error.
- `scripts/extraction/run_resolution_evaluator.gd`: the single candidate-evaluation/mutation algorithm shared by preflight and durable resolution.
- `scripts/extraction/run_resolution_preflight_result.gd`: non-mutating UI-safe readiness result.
- `scripts/extraction/run_resolution_service.gd`: preflights a caller-supplied defensive profile copy, delegates candidate evaluation, and retains durable mutation/idempotency authority. It must not load through `ProfileStore` because profile loading can persist schema promotion.
- `scripts/run/run_terminal_party_member_snapshot.gd`, `run_terminal_snapshot.gd`, `run_terminal_snapshot_builder.gd`: immutable terminal truth captured before disposable cleanup.
- `scripts/run/run_terminal_recovery_record.gd`, `run_terminal_recovery_record_result.gd`, `run_terminal_recovery_codec.gd`, `run_terminal_recovery_service.gd`: profile-owned schema-1 pre-resolution/resolved receipt, typed decode result, strict codec, persistence/resume/completion authority, protected displaced-gear mutation, and front-end recovery precedence.
- `scripts/items/item_slot_container.gd`, profile storage projection/service, and Armoury: profile-owned Recovery Overflow that is terminal-write-only, visible in Armoury, and source-only for later manual moves to stash.
- `scripts/ui/run_result/terminal_extraction_item_projection.gd`, `terminal_extraction_projection.gd`, `terminal_extraction_view_model.gd`: picker-ready automatic/eligible/selected/lost item truth and readable service-owned capacity errors.
- `scripts/run/run_terminal_flow.gd`: once-only terminal state machine, stable transaction/request identity, stale-selection refresh, preflight, durable resolution, retry, and result gating.
- `scripts/ui/run_result/terminal_extraction_panel.gd` and scene: selection/detail/unused-capacity acknowledgement UI that emits item IDs only.

### Recap and result actions

- `scripts/ui/run_result/run_recap_entry_projection.gd`, `run_recap_section_projection.gd`: typed bounded recap rows/sections.
- `scripts/ui/run_result/run_recap_provider.gd`, `run_recap_provider_result.gd`: provider interface and explicit success/error result reading snapshot plus accepted resolution without mutation.
- `scripts/ui/run_result/run_loot_recap_provider.gd`: current automatic/selected/lost section.
- `scripts/ui/run_result/run_result_projection.gd`, `run_result_projection_result.gd`, `run_result_view_model.gd`: core outcome/duration/party sections, explicit build result, optional provider ordering/collision checks, and action availability.
- `scripts/ui/run_result_panel.gd`, `scenes/ui/run_result_panel.tscn`: stylized success/recovery result screen and exact terminal action labels.
- `scripts/game/main.gd`: terminal orchestration, cleanup ordering, profile refresh, one-shot restart intent, front-end return, and quit.

### Qualification and evidence

- Focused unit tests beside each boundary and retained extraction/application tests.
- `tests/integration/combat_hud_party_scale_runner.gd`, `combat_hud_input_runner.gd`: party/alert scaling, focus, pause, Inspect/Ledger round trips.
- `tests/integration/level_up_commit_flow_runner.gd`: direct and confirmed application behavior through Main.
- `tests/integration/terminal_extraction_flow_runner.gd`, `run_result_lifecycle_runner.gd`: terminal picker, resolution, retry, and result action lifecycle.
- `tests/integration/living_forge_combat_loop_visual_evidence_runner.gd`: separate schema-2 visual evidence set for this slice.
- `docs/validation/screenshots/living-forge-combat-loop/`: exact candidate PNGs plus manifest/fingerprint.
- `docs/verification/2026-08-29-living-forge-hud-level-up-results.md`: exact head, commands, markers, evidence inventory, review verdicts, and deferred physical-controller status.

---

### Task 1: Add Copy-Safe Combat HUD Projections and Responsive Math

**Files:**

- Create: `scripts/ui/hud/party_member_hud_projection.gd`
- Create: `scripts/ui/hud/combat_alert_projection.gd`
- Create: `scripts/ui/hud/combat_hud_projection.gd`
- Create: `scripts/ui/hud/combat_hud_responsive_layout.gd`
- Create: `tests/unit/test_combat_hud_projection.gd`
- Create: `tests/unit/test_combat_hud_responsive_layout.gd`

**Interfaces:**

- Produces `PartyMemberHudProjection.create(member_id: int, display_name: String, class_id: StringName, class_name: String, level: int, rank: int, health: float, max_health: float, is_leader: bool, is_downed: bool, is_dead: bool) -> PartyMemberHudProjection` and `copy()`.
- Produces `CombatAlertProjection.Severity { CRITICAL, DOWNED, DEAD }`, `category: StringName`, `CombatAlertProjection.create(stable_id: StringName, member_id: int, category: StringName, summary: String, detail: String, severity: Severity, can_inspect: bool, can_open_ledger: bool)`, and `copy()`.
- Produces `CombatHudProjection.create(members, all_alerts, elapsed_seconds, experience, experience_next, boss_name, boss_health, boss_max_health)`, `validate() -> PackedStringArray`, and deep `copy()`. `all_alerts` retains the complete ordered copy-owned set; `visible_alerts` defensively returns its first three and `overflow_alert_count` is derived as `max(0, all_alerts.size() - 3)` so the tray and compact surface share one authority.
- Produces `CombatHudResponsiveLayout.resolve(viewport_size: Vector2i, ui_scale_percent: int, text_scale_percent: int, party_count: int) -> Metrics`, where `Metrics.mode` is `RICH` for `1..6` and `COMPACT` for `7..24`, and `visible_member_count`, `column_count`, `page_count`, and `clamped_page()` never hide the final member.

- [ ] **Step 1: Write RED projection tests**

Create tests with the exact behavioral core:

```gdscript
var members: Array[PartyMemberHudProjection] = []
for member_id: int in range(1, 25):
	members.append(PartyMemberHudProjection.create(member_id, "Member %d" % member_id, &"fighter", "Fighter", member_id, 1, 50.0, 100.0, member_id == 1, false, false))
var alerts: Array[CombatAlertProjection] = [
	CombatAlertProjection.create(&"dead:003", 3, &"downed_or_dying", "Member 3 is dead", "No longer active", CombatAlertProjection.Severity.DEAD, true, true),
]
var projection := CombatHudProjection.create(members, alerts, 61.0, 4, 10, "", 0.0, 0.0)
TestAssertions.equal(projection.members.size(), 24, "all twenty-four members are retained", failures)
var copied := projection.copy()
copied.members[0].display_name = "Changed"
TestAssertions.equal(projection.members[0].display_name, "Member 1", "copy owns nested members", failures)
TestAssertions.equal(projection.validate(), PackedStringArray(), "valid projection has no errors", failures)
```

Also assert duplicate/non-positive member IDs, invalid health bounds, duplicate alert IDs across the complete set, exact first-three derivation, exact derived overflow, and invalid XP/boss ranges are rejected.

- [ ] **Step 2: Write RED layout boundary tests**

```gdscript
for count: int in [1, 6]:
	TestAssertions.equal(CombatHudResponsiveLayout.resolve(Vector2i(1920, 1080), 100, 100, count).mode, CombatHudResponsiveLayout.Mode.RICH, "one through six use rich mode", failures)
for count: int in [7, 12, 20, 24]:
	var metrics := CombatHudResponsiveLayout.resolve(Vector2i(1280, 720), 150, 150, count)
	TestAssertions.equal(metrics.mode, CombatHudResponsiveLayout.Mode.COMPACT, "seven through twenty-four use compact mode", failures)
	TestAssertions.truthy(metrics.visible_member_count > 0, "compact view has a bounded visible window", failures)
	TestAssertions.equal(metrics.clamped_page(metrics.page_count - 1), metrics.page_count - 1, "final page is reachable", failures)
```

Cover `1280x720`, `1920x1080`, `2560x1440`, `3840x2160`, and supported ultrawide `2560x1080`, plus party counts `1, 6, 7, 12, 20, 24`. At `1280x720`, explicitly cover combined `ui=150/text=150` and `ui=80/text=150` corners in addition to default and single-axis extremes.

- [ ] **Step 3: Run RED**

```powershell
$godot = (Get-Command Godot_v4.7.1-stable_win64_console.exe).Source
& $godot --headless --path (Get-Location).Path --quit-after 420 --script res://tests/focused_test_runner.gd -- tests/unit/test_combat_hud_projection.gd tests/unit/test_combat_hud_responsive_layout.gd
```

Expected: nonzero exit and `TEST_SUMMARY: FAIL` caused only by the missing projection/layout classes.

- [ ] **Step 4: Implement minimal typed projections and pure layout math**

Use private backing arrays and deep-copy getters. Sort nothing in these data objects; preserve the view model's authoritative order. `resolve()` must normalize supported scales through existing Living Forge settings and calculate pages with ceiling division:

```gdscript
var rich := party_count <= 6
var visible := party_count if rich else clampi(_compact_visible_count(viewport_size, ui_scale_percent, text_scale_percent), 1, party_count)
var pages := maxi(1, ceili(float(party_count) / float(visible)))
return Metrics.create(Mode.RICH if rich else Mode.COMPACT, visible, _columns(viewport_size, rich), pages)
```

- [ ] **Step 5: Import UIDs, run GREEN, and commit**

```powershell
& $godot --headless --path (Get-Location).Path --import
Resolve-GeneratedUidState @(
	'scripts/ui/hud/party_member_hud_projection.gd.uid',
	'scripts/ui/hud/combat_alert_projection.gd.uid',
	'scripts/ui/hud/combat_hud_projection.gd.uid',
	'scripts/ui/hud/combat_hud_responsive_layout.gd.uid',
	'tests/unit/test_combat_hud_projection.gd.uid',
	'tests/unit/test_combat_hud_responsive_layout.gd.uid'
)
& $godot --headless --path (Get-Location).Path --quit-after 420 --script res://tests/focused_test_runner.gd -- tests/unit/test_combat_hud_projection.gd tests/unit/test_combat_hud_responsive_layout.gd
git diff --check
```

Expected: `TEST_SUMMARY: PASS (0 failures)`, exit `0`, and no diff-check output.

```powershell
git add -- scripts/ui/hud tests/unit/test_combat_hud_projection.gd tests/unit/test_combat_hud_projection.gd.uid tests/unit/test_combat_hud_responsive_layout.gd tests/unit/test_combat_hud_responsive_layout.gd.uid
git commit -m "feat: add scalable combat HUD projections"
```

---

### Task 2: Project Runtime Party and Alert Truth Without Frame Rebuilds

**Files:**

- Create: `scripts/ui/hud/combat_hud_view_model.gd`
- Create: `tests/unit/test_combat_hud_view_model.gd`
- Modify: `tests/unit/test_party_manager.gd`

**Interfaces:**

- Consumes Task 1 projections.
- Produces `CombatHudViewModel.build(party: PartyManager, context: PlayerRunContext, health_provider: Callable, experience: ExperienceSystem, elapsed_seconds: float, boss: Node) -> CombatHudProjection`; follower levels come only from `context.progression_for(member_id)`, while the existing `ExperienceSystem` remains leader XP-bar authority.
- Produces `ordered_party_revision(party: PartyManager) -> String` from stable member identity/order/static presentation only; dynamic health never changes this revision.
- Stable alert order uses priority tier `0` for `DEAD` and `DOWNED`, tier `1` for `CRITICAL`, then stable party order and stable alert ID. `CombatHudViewModel.CRITICAL_HEALTH_RATIO := 0.25` is a presentation threshold over authoritative health; it does not change combat behavior.

- [ ] **Step 1: Write RED truth and ordering tests**

Create fixtures for 24 members whose health provider returns `{current, max, downed, dead}`. Assert all members are present, the leader remains first according to `PartyManager.members`, only production-backed alerts are emitted, visible alerts are the first three, and overflow is `all_alerts.size() - 3`.

```gdscript
var projection := CombatHudViewModel.new().build(party, context, health_provider, experience, 125.0, null)
TestAssertions.equal(projection.members.size(), 24, "view model never truncates the party", failures)
TestAssertions.equal(projection.visible_alerts.size(), 3, "only three alerts expand", failures)
TestAssertions.equal(projection.overflow_alert_count, expected_alerts - 3, "overflow is exact", failures)
TestAssertions.truthy(projection.visible_alerts[0].severity in [CombatAlertProjection.Severity.DEAD, CombatAlertProjection.Severity.DOWNED], "downed or dying sorts first", failures)
```

Assert changing health changes projection values but not `ordered_party_revision`; adding a member or changing its class/static identity changes it.

- [ ] **Step 2: Run RED**

Run the focused command from Task 1 with `tests/unit/test_combat_hud_view_model.gd tests/unit/test_party_manager.gd`. Expected: `TEST_SUMMARY: FAIL` for the missing view model or revision contract only.

- [ ] **Step 3: Implement the view model and explicit party revision seam**

Subscribe later at the HUD adapter; this class stays pure. Use `PartyManager.members` order and the existing `stats_for()`/class-rank APIs. Build all alerts before slicing:

```gdscript
alerts.sort_custom(_alert_less)
return CombatHudProjection.create(members, alerts, elapsed_seconds, xp, xp_next, boss_name, boss_health, boss_max)
```

If `PartyManager` lacks one structural signal needed for a valid production mutation, add only that precise signal and emit it from the corresponding existing mutation path; do not poll member structure per frame.

- [ ] **Step 4: Import UIDs, run GREEN, and commit**

Import and classify exactly `scripts/ui/hud/combat_hud_view_model.gd.uid` and `tests/unit/test_combat_hud_view_model.gd.uid`. Run:

```powershell
& $godot --headless --path (Get-Location).Path --import
Resolve-GeneratedUidState @(
	'scripts/ui/hud/combat_hud_view_model.gd.uid',
	'tests/unit/test_combat_hud_view_model.gd.uid'
)
& $godot --headless --path (Get-Location).Path --quit-after 420 --script res://tests/focused_test_runner.gd -- tests/unit/test_combat_hud_projection.gd tests/unit/test_combat_hud_responsive_layout.gd tests/unit/test_combat_hud_view_model.gd tests/unit/test_party_manager.gd
git diff --check
git add -- scripts/ui/hud/combat_hud_view_model.gd scripts/ui/hud/combat_hud_view_model.gd.uid tests/unit/test_combat_hud_view_model.gd tests/unit/test_combat_hud_view_model.gd.uid tests/unit/test_party_manager.gd
git commit -m "feat: project combat HUD runtime truth"
```

Expected: exact focused PASS marker and exit `0`.

---

### Task 3: Add Living Forge Combat Cards, Markers, Alerts, and Icon Inventory

**Files:**

- Create: `scripts/ui/living_forge/components/forge_party_member_card.gd`
- Create: `scenes/ui/living_forge/components/forge_party_member_card.tscn`
- Create: `scripts/ui/living_forge/components/forge_party_member_marker.gd`
- Create: `scenes/ui/living_forge/components/forge_party_member_marker.tscn`
- Create: `scripts/ui/living_forge/components/forge_alert_card.gd`
- Create: `scenes/ui/living_forge/components/forge_alert_card.tscn`
- Create only if existing Tabler assets cannot express the approved states: `assets/ui/living_forge/icons/party-forge/critical-health.svg`, `downed.svg`, `dead.svg`, `leader-crown.svg`
- Modify if icons are added: `docs/third_party/living-forge-ui-assets.md`
- Create: `tests/unit/test_living_forge_combat_components.gd`
- Create: `scenes/dev/living_forge_combat_state_board.tscn`
- Create: `scripts/dev/living_forge_combat_state_board.gd`
- Create: `tests/integration/living_forge_combat_state_board_runner.gd`
- Create: exact PNGs under `docs/validation/screenshots/living-forge-combat-components/`

**Interfaces:**

- Consumes Task 1 projections and existing Living Forge themes.
- Produces `present(member: PartyMemberHudProjection)`, `present_alert(alert: CombatAlertProjection)`, `activated(member_id: int)`, `inspect_requested(member_id: int)`, and `ledger_requested(member_id: int)`.
- Re-presentation preserves current focus/hover and emits no activation signal.

- [ ] **Step 1: Write RED component contract tests**

Instantiate each packed scene and assert name/class/rank/level/health/leader state, critical/downed/dead copy and icons, accessibility names, disabled behavior, high-contrast semantic parity, and no color-only state. Include:

```gdscript
card.present(member)
card.grab_focus()
card.present(member.copy())
TestAssertions.truthy(card.has_focus(), "re-presentation preserves focus", failures)
TestAssertions.equal(card.accessibility_name, "Inspect Aria, Fighter, Level 7, 20 of 100 health", "member action is explicit", failures)
alert.present_alert(dead_alert)
TestAssertions.truthy((alert.get_node("Surface/StateIcon") as TextureRect).visible, "dead state has a visible icon", failures)
TestAssertions.truthy("Dead" in (alert.get_node("Surface/StateText") as Label).text, "dead state has visible text", failures)
```

- [ ] **Step 2: Extend the state-board RED capture contract**

Add rich normal/critical/downed/dead cards, compact markers for the same states, three alert severities, focus/hover, and normal/high-contrast sections to the new combat-only state board. Declare its exact filenames and schema-2 manifest assertions before implementing scenes. Do not modify or invalidate the accepted foundation/lobby evidence set.

- [ ] **Step 3: Run RED**

Run focused component tests and the windowed state-board runner. Expected: missing component resources/nodes fail; retained state-board assertions still pass.

- [ ] **Step 4: Implement bounded Living Forge components and assets**

Reuse the existing Tabler 3.46 subset when semantically suitable. If authoring SVGs, use original project geometry and record `generator=Party Forge authored SVG`, `license=project-owned`, and exact SHA-256 values. Components must update existing children, never create a `_process()` loop. Their binding core is:

```gdscript
func present(member: PartyMemberHudProjection) -> void:
	_bound_member_id = member.member_id
	_name_label.text = member.display_name
	_health.max_value = member.max_health
	_health.value = member.health
	_apply_semantic_state(member.is_dead, member.is_downed, member.health / maxf(member.max_health, 1.0) <= CombatHudViewModel.CRITICAL_HEALTH_RATIO)
```

- [ ] **Step 5: Import, inspect, run GREEN, and commit**

Import and classify exactly:

```powershell
& $godot --headless --path (Get-Location).Path --import
Resolve-GeneratedUidState @(
	'scripts/ui/living_forge/components/forge_party_member_card.gd.uid',
	'scripts/ui/living_forge/components/forge_party_member_marker.gd.uid',
	'scripts/ui/living_forge/components/forge_alert_card.gd.uid',
	'scripts/dev/living_forge_combat_state_board.gd.uid',
	'tests/unit/test_living_forge_combat_components.gd.uid',
	'tests/integration/living_forge_combat_state_board_runner.gd.uid'
)
& $godot --headless --path (Get-Location).Path --quit-after 420 --script res://tests/focused_test_runner.gd -- tests/unit/test_living_forge_combat_components.gd
& $godot --path (Get-Location).Path --rendering-method gl_compatibility --quit-after 900 --script res://tests/integration/living_forge_combat_state_board_runner.gd
```

Expected: `TEST_SUMMARY: PASS (0 failures)` and `LIVING_FORGE_COMBAT_STATE_BOARD_SUMMARY: PASS`, both exit `0`. Inspect every new PNG at original resolution, verify exact expected count and unique hashes, then:

```powershell
git diff --check
git add -- assets/ui/living_forge/icons/party-forge docs/third_party/living-forge-ui-assets.md scripts/ui/living_forge/components scenes/ui/living_forge/components tests/unit/test_living_forge_combat_components.gd tests/unit/test_living_forge_combat_components.gd.uid scenes/dev/living_forge_combat_state_board.tscn scripts/dev/living_forge_combat_state_board.gd scripts/dev/living_forge_combat_state_board.gd.uid tests/integration/living_forge_combat_state_board_runner.gd tests/integration/living_forge_combat_state_board_runner.gd.uid docs/validation/screenshots/living-forge-combat-components
git commit -m "feat: add Living Forge combat components"
```

If no new icons were needed, omit the absent asset/doc paths from `git add`. Expected: focused and state-board PASS markers, exit `0`, and visually coherent normal/high-contrast states.

---
### Task 4: Replace the Fixed HUD and Add Pause-Safe Inspect, Ledger, and Alert Navigation

**Files:**

- Create: `scripts/ui/hud/combat_alert_tray.gd`
- Create: `scenes/ui/hud/combat_alert_tray.tscn`
- Create: `scripts/ui/hud/combat_member_inspect_panel.gd`
- Create: `scenes/ui/hud/combat_member_inspect_panel.tscn`
- Modify: `scripts/ui/hud.gd`
- Modify: `scenes/ui/hud.tscn`
- Modify: `scripts/run/player_run_context.gd`
- Modify: `scripts/ui/ledger/character_ledger.gd`
- Modify: `scripts/game/main.gd`
- Create: `tests/unit/test_combat_hud.gd`
- Modify: `tests/unit/test_main_wiring.gd`
- Modify: `tests/unit/test_party_manager.gd`
- Create: `tests/integration/combat_hud_party_scale_runner.gd`
- Create: `tests/integration/combat_hud_input_runner.gd`
- Modify: `tests/integration/progression_arena_smoke_runner.gd`

**Interfaces:**

- `HUD.configure(run: Node, party: PartyManager, experience: ExperienceSystem, context: PlayerRunContext, settings: PartyForgeSettings) -> void` remains the one composition entry point.
- `PlayerRunContext` emits `actor_bound(member_id: int, actor: Node3D)` after a successful `bind_actor()` so existing generic Node3D fixtures remain valid and the HUD can disconnect/reconnect exact health signals without polling nodes.
- `HUD.inspect_requested(member_id: int, return_focus: Control)` and `HUD.ledger_requested(member_id: int, return_focus: Control)` carry stable identity and the initiating control.
- The stable scene paths are `Margin/CombatStatus/PartyRegion/RichRoster`, `Margin/CombatStatus/PartyRegion/CompactRoster/MemberWindow`, `CompactRoster/PagePrevious`, `CompactRoster/PageNext`, `AlertRegion/ExpandedAlerts`, and `AlertRegion/Overflow`. Focusable real member controls join `combat_hud_member` and store stable `member_id` metadata for navigation/accessibility.
- `CharacterLedger.open_for_member(member_id: int, page_id: StringName = &"stats", return_focus: Control = null) -> bool` acquires its normal `RunPauseLease`, selects the exact member, opens the page, and restores valid initiating focus on close.
- `CombatAlertTray.open(all_alerts: Array[CombatAlertProjection], return_focus: Control)`, `close()`, `inspect_requested`, and `ledger_requested` use their own `RunPauseLease`; HUD passes `current_projection.all_alerts` directly, never reconstructs discarded alerts, and closing one lease must not unpause a run already paused by another owner.

- [ ] **Step 1: Write RED HUD structure, diff, and signal tests**

Instantiate the HUD with synthetic parties of `1, 6, 7, 12, 20, 24`. Assert rich/compact mode, every member ID represented exactly once across the complete view/paging model, the final member reachable, no fixed `Party1..Party4` nodes, bounded live controls, and health updates changing an existing control rather than rebuilding the party tree.

```gdscript
hud.configure(run, party_24, experience, context, settings)
await get_tree().process_frame
var reached_ids := await _collect_member_ids_across_pages(hud)
TestAssertions.equal(reached_ids.size(), 24, "focus paging reaches all party members", failures)
var member_control := _member_control(hud, 24)
var control_instance_id := member_control.get_instance_id()
health.apply_damage(80.0)
await get_tree().process_frame
TestAssertions.equal(member_control.get_instance_id(), control_instance_id, "health refresh preserves the real member control", failures)
TestAssertions.near((_health_bar(member_control) as Range).value, 20.0, 0.001, "signal refresh updates the real health bar", failures)

func _collect_member_ids_across_pages(hud: HUD) -> Dictionary:
	var reached: Dictionary = {}
	var next := hud.get_node("Margin/CombatStatus/PartyRegion/CompactRoster/PageNext") as Button
	while true:
		for node: Node in hud.get_tree().get_nodes_in_group("combat_hud_member"):
			if hud.is_ancestor_of(node):
				reached[int(node.get_meta("member_id", 0))] = true
		if next.disabled:
			break
		next.pressed.emit()
		await hud.get_tree().process_frame
	return reached
```

- [ ] **Step 2: Write RED alert and child-route tests**

Assert zero/one/three/overflow alert presentation, `+N alerts` opening `projection.all_alerts` as the complete sorted tray, initial focus on the highest-priority non-expanded alert, focused stable-alert preservation across refresh, resolved-alert next/previous/Close fallback, all-alerts-resolved closure message, final alert reachability, Inspect round trip, Ledger exact member/page round trip, initiating focus restoration, Cancel parity, no combat-focus theft when a new alert appears, and prior-pause preservation. Also assert a one-member rich party shows an intentional no-followers treatment and unsupported objective data renders no objective frame.

```gdscript
pause_owner.acquire(get_tree())
overflow_button.grab_focus()
overflow_button.pressed.emit()
TestAssertions.truthy(get_tree().paused, "alert tray pauses terminal-safe UI", failures)
tray.close()
TestAssertions.truthy(get_tree().paused, "closing tray preserves another pause owner", failures)
TestAssertions.truthy(overflow_button.has_focus(), "closing tray restores initiating focus", failures)
pause_owner.release(get_tree())
```

- [ ] **Step 3: Run RED**

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_combat_hud.gd tests/unit/test_main_wiring.gd tests/unit/test_party_manager.gd
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/integration/combat_hud_party_scale_runner.gd
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/integration/combat_hud_input_runner.gd
& $godot --headless --path (Get-Location).Path --quit-after 900 --script res://tests/integration/progression_arena_smoke_runner.gd
```

Expected: focused and integration failures identify only missing new HUD/routes and obsolete fixed-four expectations.

- [ ] **Step 4: Implement the responsive HUD composition**

Replace the four labels with reusable rich/compact containers, one bounded alert stack, overflow button, complete alert tray, and inspector. Retain current timer, XP, boss bar/banner, and loot-status behavior. Migrate `test_party_manager.gd` from the old three-argument `configure`, `_refresh_party`, and `Party1..Party4` contract to the typed five-argument composition and real member controls. Migrate `progression_arena_smoke_runner.gd` from `_refresh_status` and `HUD/Margin/Status/Experience` to the new public signal-driven HUD and stable `Margin/CombatStatus` paths. During `configure()`, enumerate `context.party.members` and call `context.actor_for(member_id)` so leader/companions bound before HUD setup are observed; then subscribe to future `actor_bound`. Replace `_refresh_status()` every-frame tree work with:

```gdscript
func _process(delta: float) -> void:
	_refresh_elapsed_time()
	_tick_temporary_messages(delta)

func _on_party_structure_changed() -> void:
	_present(_view_model.build(party_manager, active_context, _health_provider, experience_system, _elapsed(), boss))

func _on_member_health_changed(member_id: int) -> void:
	_update_member_and_alerts(member_id)
```

The compact roster may recycle a bounded visible window, but focus paging must preserve the complete ordered projection and expose stable `member_id` metadata on real focusable member controls. No active boss hides the boss region without an empty decorative frame. Do not add production methods used only by tests; test helpers inspect and exercise the real component tree.

- [ ] **Step 5: Implement exact-member child routes and Main wiring**

Add `actor_bound`, connect/disconnect health lifecycle signals by member ID, add `CharacterLedger.open_for_member`, and wire Main:

```gdscript
func _on_hud_ledger_requested(member_id: int, return_focus: Control) -> void:
	if not character_ledger.open_for_member(member_id, &"stats", return_focus):
		_show_player_error("That party member is no longer available.")
```

Inspect remains a read-only HUD child. Ledger remains the full detail authority. Do not add a tactics button or tactic data.

- [ ] **Step 6: Import, run GREEN, and commit**

Classify exact new production/test UIDs for the tray, inspector, and three new tests/runners. Run all Task 1-4 focused suites plus both new integration runners and retained `tests/integration/responsive_ui_geometry_runner.gd` and `tests/integration/progression_arena_smoke_runner.gd`. Expected exact PASS markers and exit `0`.

```powershell
& $godot --headless --path (Get-Location).Path --import
Resolve-GeneratedUidState @(
	'scripts/ui/hud/combat_alert_tray.gd.uid',
	'scripts/ui/hud/combat_member_inspect_panel.gd.uid',
	'tests/unit/test_combat_hud.gd.uid',
	'tests/integration/combat_hud_party_scale_runner.gd.uid',
	'tests/integration/combat_hud_input_runner.gd.uid'
)
git diff --check
git add -- scripts/ui/hud scripts/ui/hud.gd scenes/ui/hud scenes/ui/hud.tscn scripts/run/player_run_context.gd scripts/ui/ledger/character_ledger.gd scripts/game/main.gd tests/unit/test_combat_hud.gd tests/unit/test_combat_hud.gd.uid tests/unit/test_main_wiring.gd tests/unit/test_party_manager.gd tests/integration/combat_hud_party_scale_runner.gd tests/integration/combat_hud_party_scale_runner.gd.uid tests/integration/combat_hud_input_runner.gd tests/integration/combat_hud_input_runner.gd.uid tests/integration/progression_arena_smoke_runner.gd
git commit -m "feat: replace the fixed combat HUD"
```

---

### Task 5: Add Typed Upgrade Offers and Authoritative Application Routes

**Files:**

- Create: `scripts/ui/level_up/upgrade_offer_projection.gd`
- Create: `scripts/ui/level_up/upgrade_offer_projection_service.gd`
- Create: `scripts/progression/level_up_application_result.gd`
- Create: `scripts/progression/level_up_application_policy.gd`
- Modify: `scripts/progression/upgrade_choice.gd`
- Modify: `scripts/progression/upgrade_presentation_service.gd`
- Modify: `scripts/progression/foundational_upgrade_presentation_service.gd`
- Create: `tests/unit/test_upgrade_offer_projection.gd`
- Create: `tests/unit/test_level_up_application_policy.gd`
- Modify: `tests/unit/test_upgrade_choices.gd`
- Modify: `tests/unit/test_upgrade_presentation.gd`
- Modify: `tests/unit/test_foundational_upgrade_presentation.gd`

**Interfaces:**

- `UpgradeOfferProjection` fields are `choice_key`, `target_id`, `category_id`, `icon_id`, `display_name`, `rarity_label`, `effect_text`, `scope_text`, `rank_text`, `eligibility_text`, `recipient_tags`, `class_tags`, and `disabled_reason`; `enabled()` and `copy()` are deterministic.
- `UpgradeOfferProjectionService.build(choice: UpgradeChoice, party: PartyManager, catalog: GameCatalog, disabled_reason: String = "") -> UpgradeOfferProjection` and `build_all(...) -> Array[UpgradeOfferProjection]` adapt existing authoritative presentation services.
- `UpgradeChoice.ApplicationRoute { DIRECT, RECIPIENT_CONFIRMATION, CONTEXT_CONFIRMATION }`; `RECRUIT` is context confirmation, `requires_recipient()` is recipient confirmation, all current other kinds are direct.
- `LevelUpApplicationPolicy.evaluate(choice: UpgradeChoice, party: PartyManager, catalog: GameCatalog, member_id: int) -> LevelUpApplicationResult` validates route/recipient/recruit definition against the same current catalog authority and reports a readable reason without mutation.
- Visual projection fields never determine `ApplicationRoute`.

- [ ] **Step 1: Write RED projection truth tests**

```gdscript
var projection := service.build(choice, party, catalog)
TestAssertions.equal(projection.choice_key, choice.key(), "projection retains stable choice identity", failures)
TestAssertions.equal(projection.rarity_label, "", "foundational choices omit unsupported rarity", failures)
var copy := projection.copy()
copy.recipient_tags.append(&"mutated")
TestAssertions.truthy(not (&"mutated" in projection.recipient_tags), "projection arrays are copy-owned", failures)
```

Assert authored rarity uses the schema's current value including `COMMON`, recruitment shows only catalog-backed class/role/trait consequences, and authored targeted offers do not claim a pre-recipient exact delta. After a recipient is selected, assert `UpgradeApplicationService.preview_values()` supplies the exact before/after confirmation values.

- [ ] **Step 2: Write RED route and readable-result tests**

```gdscript
TestAssertions.equal(simple_choice.application_route(), UpgradeChoice.ApplicationRoute.DIRECT, "whole-party choice is direct", failures)
TestAssertions.equal(targeted_choice.application_route(), UpgradeChoice.ApplicationRoute.RECIPIENT_CONFIRMATION, "targeted choice confirms recipient", failures)
TestAssertions.equal(recruit_choice.application_route(), UpgradeChoice.ApplicationRoute.CONTEXT_CONFIRMATION, "recruit confirms context", failures)
TestAssertions.truthy(not policy.evaluate(targeted_choice, party, catalog, 0).ok(), "targeted choice requires a member", failures)
TestAssertions.truthy("no longer" in policy.evaluate(stale_choice, party, catalog, 0).reason, "rejection is player-readable", failures)
```

- [ ] **Step 3: Run RED**

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_upgrade_offer_projection.gd tests/unit/test_level_up_application_policy.gd tests/unit/test_upgrade_choices.gd tests/unit/test_upgrade_presentation.gd tests/unit/test_foundational_upgrade_presentation.gd
```

Expected: nonzero exit and `TEST_SUMMARY: FAIL` for missing typed classes/routes and obsolete dictionary assumptions only.

- [ ] **Step 4: Implement projections, route enum, and mutation-free policy**

Reuse existing foundational/card presentation services internally, but return typed copy-owned values at the new boundary. Do not store `PartyManager`, `UpgradeDefinition`, or other mutable authority inside `UpgradeOfferProjection`. Implement the route exactly:

```gdscript
func application_route() -> ApplicationRoute:
	if kind == Kind.RECRUIT:
		return ApplicationRoute.CONTEXT_CONFIRMATION
	if requires_recipient():
		return ApplicationRoute.RECIPIENT_CONFIRMATION
	return ApplicationRoute.DIRECT
```

- [ ] **Step 5: Import, run GREEN, and commit**

```powershell
& $godot --headless --path (Get-Location).Path --import
Resolve-GeneratedUidState @(
	'scripts/ui/level_up/upgrade_offer_projection.gd.uid',
	'scripts/ui/level_up/upgrade_offer_projection_service.gd.uid',
	'scripts/progression/level_up_application_result.gd.uid',
	'scripts/progression/level_up_application_policy.gd.uid',
	'tests/unit/test_upgrade_offer_projection.gd.uid',
	'tests/unit/test_level_up_application_policy.gd.uid'
)
```

Repeat the Step 3 command across all five suites and require `TEST_SUMMARY: PASS (0 failures)` with exit `0`, then:

```powershell
git diff --check
git add -- scripts/ui/level_up scripts/progression/level_up_application_result.gd scripts/progression/level_up_application_result.gd.uid scripts/progression/level_up_application_policy.gd scripts/progression/level_up_application_policy.gd.uid scripts/progression/upgrade_choice.gd scripts/progression/upgrade_presentation_service.gd scripts/progression/foundational_upgrade_presentation_service.gd tests/unit/test_upgrade_offer_projection.gd tests/unit/test_upgrade_offer_projection.gd.uid tests/unit/test_level_up_application_policy.gd tests/unit/test_level_up_application_policy.gd.uid tests/unit/test_upgrade_choices.gd tests/unit/test_upgrade_presentation.gd tests/unit/test_foundational_upgrade_presentation.gd
git commit -m "feat: type level-up offers and application routes"
```

---

### Task 6: Revamp the Level-Up Screen and Unify Direct and Confirmed Application

**Files:**

- Modify: `scripts/ui/upgrade_card.gd`
- Modify: `scenes/ui/upgrade_card.tscn`
- Modify: `scripts/ui/level_up_reveal_controller.gd`
- Modify: `scripts/ui/level_up_panel.gd`
- Modify: `scenes/ui/level_up_panel.tscn`
- Modify: `scripts/ui/upgrade_recipient_picker.gd`
- Modify: `scenes/ui/upgrade_recipient_picker.tscn`
- Modify: `scripts/game/main.gd`
- Modify: `tests/unit/test_level_up_reveal_controller.gd`
- Modify: `tests/unit/test_level_up_targeting_ui.gd`
- Modify: `tests/unit/test_main_wiring.gd`
- Modify: `tests/integration/level_up_five_card_geometry_runner.gd`
- Modify: `tests/integration/upgrade_recipient_controller_scroll_runner.gd`
- Create: `tests/integration/level_up_commit_flow_runner.gd`

**Interfaces:**

- `UpgradeCard.present(projection: UpgradeOfferProjection)`, `present_preview(projection)`, `bound_choice_key() -> StringName`, and `activated(choice_key: StringName)` replace the dictionary/choice binding seam.
- `LevelUpPanel` retains a private `choice_key -> exact UpgradeChoice` map and emits one `application_requested(choice: UpgradeChoice, recipient_member_id: int)` signal for direct, recipient-confirmed, and recruit-confirmed paths.
- The panel stores `_initiating_choice_key`, rejects duplicate activation while pending, closes only after Main reports success, and restores the exact initiating card plus readable reason after failure/cancel.
- Stable real-state nodes are `Frame/Content/Confirmation` and `Frame/Content/ReadableError`; tests inspect their visibility/text rather than adding diagnostic methods to production.
- Main's `_on_level_up_application_requested(choice, recipient_member_id)` funnels into its existing central `_apply_choice_for_member` authority; one pending level is consumed only on accepted application.

- [ ] **Step 1: Convert reveal/card tests to typed RED contracts**

Assert reveal preview does not replace the activation key, re-presentation preserves focus/hover, a card cannot activate before final binding, reduced motion reveals immediately, and tooltip mouse/keyboard/controller parity remains intact.

- [ ] **Step 2: Write RED commit-flow tests**

Cover direct success/failure, targeted 24-member recipient selection, recipient confirmation/cancel, recruitment confirmation/cancel, no-eligible-recipient Cancel default focus, duplicate pending rejection, and exact initiating-card restoration.

```gdscript
panel.show_choices([simple_choice], party)
card.activated.emit(card.bound_choice_key())
TestAssertions.equal(application_intents.size(), 1, "direct offer emits one application intent", failures)
TestAssertions.equal(application_intents[0].member_id, 0, "direct offer has no invented recipient", failures)
TestAssertions.truthy(not (panel.get_node("Frame/Content/Confirmation") as Control).visible, "direct offer skips confirmation", failures)
panel.reject_application("Selection is no longer available.")
TestAssertions.truthy(card.has_focus(), "failure restores initiating offer", failures)
TestAssertions.equal((panel.get_node("Frame/Content/ReadableError") as Label).text, "Selection is no longer available.", "failure reason remains exact", failures)
```

- [ ] **Step 3: Run RED**

Run the three unit suites, both existing integration runners, and the new commit-flow runner. Expected: failures document universal-confirmation and dictionary-binding behavior being intentionally replaced.

- [ ] **Step 4: Implement the Living Forge level-up state machine**

Use explicit states `REVEALING`, `CHOOSING`, `CHOOSING_RECIPIENT`, `CONFIRMING`, and `PENDING`. Direct activation enters `PENDING` and emits `(choice, 0)`. Recipient selection builds exact preview values then enters confirmation. Recruitment enters context confirmation directly. Cancel/failure returns to `CHOOSING` and `_focus_choice(_initiating_choice_key)`. A valid empty offer set presents the authoritative no-choice reason plus recovery action; it never leaves an inert blank panel. Accepted application closes only when no pending level remains; otherwise it reveals the next pending choice, and final close restores deterministic gameplay focus.

Remove hidden legacy `Choices` and `choice_selected` only after every test/caller uses the unified signal. Apply the shared normal/high-contrast/UI-scale/text-scale/reduced-motion configuration to the screen; do not fork a second theme catalog.

- [ ] **Step 5: Wire Main through one duplicate-safe result seam**

Retain the current authoritative application method if other callers depend on its `bool`, but add an exact-result wrapper for UI feedback:

```gdscript
func _on_level_up_application_requested(choice: UpgradeChoice, member_id: int) -> void:
	var result := _apply_level_up_choice(choice, member_id)
	if result.ok():
		level_up_panel.accept_application()
	else:
		level_up_panel.reject_application(result.reason)
```

- [ ] **Step 6: Run GREEN and commit**

Import and classify exactly `tests/integration/level_up_commit_flow_runner.gd.uid`, then run:

```powershell
& $godot --headless --path (Get-Location).Path --import
Resolve-GeneratedUidState @('tests/integration/level_up_commit_flow_runner.gd.uid')
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_upgrade_offer_projection.gd tests/unit/test_level_up_application_policy.gd tests/unit/test_upgrade_choices.gd tests/unit/test_upgrade_presentation.gd tests/unit/test_foundational_upgrade_presentation.gd tests/unit/test_level_up_reveal_controller.gd tests/unit/test_level_up_targeting_ui.gd tests/unit/test_main_wiring.gd
& $godot --path (Get-Location).Path --rendering-method gl_compatibility --quit-after 900 --script res://tests/integration/level_up_five_card_geometry_runner.gd
& $godot --headless --path (Get-Location).Path --quit-after 900 --script res://tests/integration/upgrade_recipient_controller_scroll_runner.gd
& $godot --headless --path (Get-Location).Path --quit-after 900 --script res://tests/integration/level_up_commit_flow_runner.gd
& $godot --headless --path (Get-Location).Path --quit-after 900 --script res://tests/integration/temporary_popup_input_runner.gd
```

Require `TEST_SUMMARY: PASS (0 failures)`, `LEVEL_UP_FIVE_CARD_SUMMARY: PASS`, `UPGRADE_RECIPIENT_CONTROLLER_SCROLL_SUMMARY: PASS`, `LEVEL_UP_COMMIT_FLOW_SUMMARY: PASS`, and `TEMPORARY_POPUP_INPUT_SUMMARY: PASS`, each with exit `0`.

```powershell
git diff --check
git add -- scripts/ui/upgrade_card.gd scenes/ui/upgrade_card.tscn scripts/ui/level_up_reveal_controller.gd scripts/ui/level_up_panel.gd scenes/ui/level_up_panel.tscn scripts/ui/upgrade_recipient_picker.gd scenes/ui/upgrade_recipient_picker.tscn scripts/game/main.gd tests/unit/test_level_up_reveal_controller.gd tests/unit/test_level_up_targeting_ui.gd tests/unit/test_main_wiring.gd tests/integration/level_up_five_card_geometry_runner.gd tests/integration/upgrade_recipient_controller_scroll_runner.gd tests/integration/level_up_commit_flow_runner.gd tests/integration/level_up_commit_flow_runner.gd.uid
git commit -m "feat: revamp the Living Forge level-up flow"
```

---

### Task 7: Share Exact Resolution Preparation Between Pure Preflight and Durable Resolve

**Files:**

- Create: `scripts/extraction/run_resolution_source.gd`
- Create: `scripts/extraction/run_resolution_source_result.gd`
- Create: `scripts/extraction/run_resolution_evaluation.gd`
- Create: `scripts/extraction/run_resolution_evaluator.gd`
- Create: `scripts/extraction/run_resolution_preflight_result.gd`
- Modify: `scripts/extraction/run_resolution_result.gd`
- Modify: `scripts/extraction/run_resolution_service.gd`
- Modify: `scripts/extraction/run_extraction_policy.gd`
- Create: `tests/unit/test_run_resolution_preflight.gd`
- Modify: `tests/unit/test_run_resolution_service.gd`
- Modify: `tests/unit/test_run_extraction_policy.gd`

**Interfaces:**

- `RunResolutionSource.from_context(context: PlayerRunContext, leader_member_id: int) -> RunResolutionSourceResult` captures exact run/profile identity, ordered `{member_id, class_id, is_leader}` rows, copied run item ownership, leader class ID, and the leader's resolved core attributes. `to_dictionary()`/`from_dictionary()` are strict, copy-safe, and contain no nodes.
- `RunExtractionPolicy.project(context, profile, selections)` remains backward-compatible and delegates to `project_source(source: RunResolutionSource, profile: ProfileState, selections: Array[ExtractionSelection])`.
- `RunResolutionEvaluator.evaluate(candidate: ProfileState, source: RunResolutionSource, request: RunResolutionRequest) -> RunResolutionEvaluation` runs the exact current identity, extraction, ownership, eligibility, stash, and candidate mutation algorithm on the caller-owned candidate.
- `RunResolutionEvaluation` exposes defensive `extraction`, `mandatory_stash_slots`, `ordinary_stash_slots`, `required_stash_slots`, `available_stash_slots`, `automatic_only_blocked`, `error`, and `ok()`; no mutable candidate escapes.
- `RunResolutionService.preflight(profile: ProfileState, context: PlayerRunContext, request: RunResolutionRequest)` wraps `preflight_source(profile, source, request)` after exact source capture; both copy `profile` and perform no file/store/context mutation.
- `resolve()` wraps `resolve_source(profile_id, source, request, root)`; the source method re-runs the same evaluator inside `apply_with_resumable_run_revocation` against the fresh durable mutation candidate.
- `RunResolutionResult.success(profile, duplicate, accepted_extraction)` exposes a defensive accepted projection. For a duplicate transaction whose callback is skipped, `resolve_source()` reconstructs and validates the exact accepted projection from request/source before returning success.

- [ ] **Step 1: Write RED preflight purity and capacity tests**

Cover live source capture, strict source dictionary round-trip, ordinary selection, automatic leader replacement, displaced permanent equipment, zero capacity, insufficient capacity, automatic-only blockage, stale source, identity mismatch, and invalid ownership. Assert required/available counts and structurally equal profile/context documents before/after.

```gdscript
var before_profile := JSON.stringify(profile.to_dictionary())
var before_context := JSON.stringify(context.item_state().to_dictionary())
var preflight := service.preflight(profile, context, request)
TestAssertions.equal(preflight.required_stash_slots, preflight.mandatory_stash_slots + preflight.ordinary_stash_slots, "required slots are auditable", failures)
TestAssertions.equal(JSON.stringify(profile.to_dictionary()), before_profile, "preflight does not mutate profile", failures)
TestAssertions.equal(JSON.stringify(context.item_state().to_dictionary()), before_context, "preflight does not mutate run context", failures)
```

- [ ] **Step 2: Extend RED resolve parity/idempotency tests**

For every accepted/rejected fixture, assert `preflight.ok() == resolve.ok()` when durable state is unchanged. Assert resolve still revalidates a freshly changed durable candidate, duplicate replay remains duplicate-safe, and accepted extraction is identical and copy-owned on first and duplicate success.

- [ ] **Step 3: Run RED**

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_run_extraction_policy.gd tests/unit/test_run_resolution_preflight.gd tests/unit/test_run_resolution_service.gd
```

Expected: missing preflight/evaluator types fail while retained resolution tests describe the existing green authority.

- [ ] **Step 4: Extract the evaluator without changing durable semantics**

Move the body of `_resolve_candidate()` into the evaluator. Calculate counts before mutation and return a typed error instead of parsing UI text. Keep `ProfileMutationService.apply_with_resumable_run_revocation()` and its canonical request fingerprint unchanged. `preflight()` must never call `ProfileStore.load_profile()`:

```gdscript
func preflight(profile: ProfileState, context: PlayerRunContext, request: RunResolutionRequest) -> RunResolutionPreflightResult:
	var request_error := _validate_request(profile.profile_id if profile != null else "", context, request)
	if not request_error.is_empty():
		return RunResolutionPreflightResult.failure(request_error)
	var source_result := RunResolutionSource.from_context(context, request.leader_member_id)
	if not source_result.ok():
		return RunResolutionPreflightResult.failure(source_result.error)
	return preflight_source(profile, source_result.source, request)
```

- [ ] **Step 5: Import, run GREEN, and commit**

Import/classify exact production UIDs `run_resolution_source.gd.uid`, `run_resolution_source_result.gd.uid`, `run_resolution_evaluation.gd.uid`, `run_resolution_evaluator.gd.uid`, `run_resolution_preflight_result.gd.uid`, plus `test_run_resolution_preflight.gd.uid`. Run the three focused suites plus retained recovery/profile lifecycle integration. Expected exact PASS markers, exit `0`, and unchanged durable documents after every preflight.

```powershell
& $godot --headless --path (Get-Location).Path --import
Resolve-GeneratedUidState @(
	'scripts/extraction/run_resolution_source.gd.uid',
	'scripts/extraction/run_resolution_source_result.gd.uid',
	'scripts/extraction/run_resolution_evaluation.gd.uid',
	'scripts/extraction/run_resolution_evaluator.gd.uid',
	'scripts/extraction/run_resolution_preflight_result.gd.uid',
	'tests/unit/test_run_resolution_preflight.gd.uid'
)
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_run_extraction_policy.gd tests/unit/test_run_resolution_preflight.gd tests/unit/test_run_resolution_service.gd
& $godot --headless --path (Get-Location).Path --quit-after 1200 --script res://tests/integration/run_recovery_profile_lifecycle_runner.gd
git diff --check
git add -- scripts/extraction/run_resolution_source.gd scripts/extraction/run_resolution_source.gd.uid scripts/extraction/run_resolution_source_result.gd scripts/extraction/run_resolution_source_result.gd.uid scripts/extraction/run_resolution_evaluation.gd scripts/extraction/run_resolution_evaluation.gd.uid scripts/extraction/run_resolution_evaluator.gd scripts/extraction/run_resolution_evaluator.gd.uid scripts/extraction/run_resolution_preflight_result.gd scripts/extraction/run_resolution_preflight_result.gd.uid scripts/extraction/run_resolution_result.gd scripts/extraction/run_resolution_service.gd scripts/extraction/run_extraction_policy.gd tests/unit/test_run_resolution_preflight.gd tests/unit/test_run_resolution_preflight.gd.uid tests/unit/test_run_resolution_service.gd tests/unit/test_run_extraction_policy.gd
git commit -m "refactor: share run resolution preflight authority"
```

---

### Task 8: Capture Immutable Terminal Truth Before Cleanup

**Files:**

- Create: `scripts/run/run_terminal_party_member_snapshot.gd`
- Create: `scripts/run/run_terminal_snapshot.gd`
- Create: `scripts/run/run_terminal_snapshot_result.gd`
- Create: `scripts/run/run_terminal_snapshot_builder.gd`
- Create: `tests/unit/test_run_terminal_snapshot.gd`

**Interfaces:**

- `RunTerminalSnapshot.Outcome { VICTORY, DEFEAT }`.
- `RunTerminalPartyMemberSnapshot.create(member_id, display_name, class_id, class_name, is_leader, final_level)` stores values only and provides `copy()`.
- `RunTerminalSnapshot.to_dictionary()` and `RunTerminalSnapshot.from_dictionary(document) -> RunTerminalSnapshotResult` use exact fields and the strict Task 7 resolution-source decoder so terminal truth can be durably recovered without scene objects.
- `RunTerminalSnapshotBuilder.capture(outcome: RunTerminalSnapshot.Outcome, elapsed_seconds: float, context: PlayerRunContext) -> RunTerminalSnapshotResult` returns either one copy-owned snapshot or an exact readable error.
- The snapshot stores stable profile/run/seed/player/leader identity, ordered member snapshots, a defensive `RunResolutionSource` (including copied item ownership and resolved leader attributes), and elapsed seconds. It retains no `PartyMemberState`, `PartyActor`, `HealthComponent`, scene `Node`, or mutable `PlayerRunContext` reference.

- [ ] **Step 1: Write RED capture and copy-safety tests**

```gdscript
var result := RunTerminalSnapshotBuilder.new().capture(RunTerminalSnapshot.Outcome.VICTORY, 125.8, context)
TestAssertions.truthy(result.ok(), "valid terminal truth captures", failures)
TestAssertions.equal(result.snapshot.members.size(), context.party.members.size(), "all ordered members capture", failures)
TestAssertions.equal(result.snapshot.elapsed_seconds, 125.8, "duration captures exactly", failures)
var first_name := result.snapshot.members[0].display_name
context.party.members[0].character_name = "Mutated after capture"
TestAssertions.equal(result.snapshot.members[0].display_name, first_name, "snapshot owns member truth", failures)
```

Assert one exact leader, positive member IDs, unique member IDs, valid class identity, available progression/final level, configured strict run identity, valid item ownership, nonnegative duration, and both outcomes. Mutate/free all source objects after capture and prove the snapshot remains readable and unchanged.

- [ ] **Step 2: Run RED**

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 420 --script res://tests/focused_test_runner.gd -- tests/unit/test_run_terminal_snapshot.gd
```

Expected: nonzero exit and `TEST_SUMMARY: FAIL` for missing snapshot types only.

- [ ] **Step 3: Implement value-only capture**

Read levels from `PlayerRunContext.progression_for(member_id)` and build the resolution source through Task 7's exact capture boundary. Copy through typed copy/codec boundaries rather than dictionary references. Return failure for invalid required core truth; never skip a bad member silently.

- [ ] **Step 4: Import, run GREEN, and commit**

Import/classify all five new script/test UIDs. Run:

```powershell
& $godot --headless --path (Get-Location).Path --import
Resolve-GeneratedUidState @(
	'scripts/run/run_terminal_party_member_snapshot.gd.uid',
	'scripts/run/run_terminal_snapshot.gd.uid',
	'scripts/run/run_terminal_snapshot_result.gd.uid',
	'scripts/run/run_terminal_snapshot_builder.gd.uid',
	'tests/unit/test_run_terminal_snapshot.gd.uid'
)
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_run_terminal_snapshot.gd tests/unit/test_player_run_context.gd tests/unit/test_run_extraction_policy.gd
```

Require `TEST_SUMMARY: PASS (0 failures)` and exit `0`.

```powershell
git diff --check
git add -- scripts/run/run_terminal_party_member_snapshot.gd scripts/run/run_terminal_party_member_snapshot.gd.uid scripts/run/run_terminal_snapshot.gd scripts/run/run_terminal_snapshot.gd.uid scripts/run/run_terminal_snapshot_result.gd scripts/run/run_terminal_snapshot_result.gd.uid scripts/run/run_terminal_snapshot_builder.gd scripts/run/run_terminal_snapshot_builder.gd.uid tests/unit/test_run_terminal_snapshot.gd tests/unit/test_run_terminal_snapshot.gd.uid
git commit -m "feat: capture immutable terminal run truth"
```

---

### Task 9: Build the Extraction Projection, Selection Controller, and Living Forge Picker

**Files:**

- Create: `scripts/ui/run_result/terminal_extraction_item_projection.gd`
- Create: `scripts/ui/run_result/terminal_extraction_projection.gd`
- Create: `scripts/ui/run_result/terminal_extraction_view_model.gd`
- Create: `scripts/ui/run_result/terminal_extraction_selection_controller.gd`
- Create: `scripts/ui/living_forge/components/forge_extraction_item_card.gd`
- Create: `scenes/ui/living_forge/components/forge_extraction_item_card.tscn`
- Create: `scripts/ui/run_result/terminal_extraction_panel.gd`
- Create: `scenes/ui/run_result/terminal_extraction_panel.tscn`
- Modify: `scenes/ui/hud.tscn`
- Modify: `scripts/ui/hud.gd`
- Create: `tests/unit/test_terminal_extraction_view_model.gd`
- Create: `tests/unit/test_terminal_extraction_selection_controller.gd`
- Create: `tests/unit/test_terminal_extraction_panel.gd`
- Create: `tests/integration/terminal_extraction_flow_runner.gd`

**Interfaces:**

- `TerminalExtractionViewModel.build(policy: RunExtractionProjection, source: RunResolutionSource, profile: ProfileState) -> TerminalExtractionProjection` preserves canonical policy order and uses source-owned item/class/stat truth plus `ItemPresentationProjector`/catalogs for name, rarity, owner/container, detail, and comparison. Live and cold-resume picker presentation use the same value-only boundary.
- `TerminalExtractionSelectionController.initialize(policy)`, `toggle(item_id) -> bool`, `reconcile(policy) -> Array[String]`, `selected_item_ids() -> Array[String]`, `selected_selections() -> Array[ExtractionSelection]`, `needs_unused_capacity_acknowledgement() -> bool`, `acknowledge_unused_capacity()`, and `set_pending(bool)`.
- Defaults: if `eligible <= capacity`, select all; if `eligible > capacity`, select none; capacity zero still presents every eligible item and explicit loss.
- The panel emits `item_toggle_requested(item_id)`, `inspect_requested(item_id, anchor)`, `confirm_requested`, `unused_capacity_acknowledged`, and `retry_resolution_requested`. It has no route back to combat.
- `HUD/TerminalExtraction : TerminalExtractionPanel` is the stable always-processing composition owner. `HUD.show_terminal_extraction(projection)`, `HUD.show_terminal_resolution_pending()`, and `HUD.hide_terminal_extraction()` delegate presentation only; Main connects the panel's intent signals.

- [ ] **Step 1: Write RED selection-controller tests**

```gdscript
controller.initialize(all_fit_projection)
TestAssertions.equal(controller.selected_item_ids(), all_fit_projection.eligible_items.map(func(value: ExtractionSelection) -> String: return value.item_id), "all-fit defaults selected", failures)
controller.initialize(constrained_projection)
TestAssertions.equal(controller.selected_item_ids(), [], "constrained choice starts empty", failures)
TestAssertions.truthy(not controller.toggle(automatic_item_id), "automatic item cannot toggle", failures)
controller.toggle(first_eligible_id)
controller.set_pending(true)
TestAssertions.truthy(not controller.toggle(second_eligible_id), "pending state rejects mutation", failures)
```

Cover zero capacity, over-capacity rejection, stable policy order, unused-slot acknowledgement only when items will be lost, acknowledgement reset on selection change, stale reconcile preserving exact still-valid tokens, changed source invalidation, and duplicate item IDs.

- [ ] **Step 2: Write RED view-model and panel tests**

Assert automatic locked group, eligible stable grid, `Automatic A`, `Selected X / N`, `Will be lost Y`, exact expandable lists, selected/hover/focus/non-color states, player-readable preflight errors, invalid Confirm disabled, 24 items reachable, detail Cancel returning to the same item, keyboard/mouse/simulated-controller parity, and byte-equivalent live-versus-cold-resume item detail/comparison from the same `RunResolutionSource`.

- [ ] **Step 3: Write RED integration cases**

In `terminal_extraction_flow_runner.gd`, exercise capacity zero, all-fit, constrained/no-preselection, fewer-than-capacity second acknowledgement, item detail, stale re-projection with valid-selection retention, a reducible stash error, automatic-only blockage, and pending duplicate clicks. End with exact `TERMINAL_EXTRACTION_FLOW_SUMMARY: PASS`.

- [ ] **Step 4: Run RED**

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_terminal_extraction_view_model.gd tests/unit/test_terminal_extraction_selection_controller.gd tests/unit/test_terminal_extraction_panel.gd
& $godot --headless --path (Get-Location).Path --quit-after 900 --script res://tests/integration/terminal_extraction_flow_runner.gd
```

Expected: nonzero exits; `TEST_SUMMARY: FAIL` and `TERMINAL_EXTRACTION_FLOW_SUMMARY: FAIL` identify missing projection/controller/panel contracts with no unrelated parser/loader noise.

- [ ] **Step 5: Implement typed projections, controller, card, and panel**

The card stores/emits only its stable item ID. The controller privately stores copied exact `ExtractionSelection` tokens so later code can reconstruct a service request without trusting display text. Reuse `ItemTooltipPanel`; do not use draggable storage slots in a terminal decision.

For a stale policy refresh:

```gdscript
func reconcile(next: RunExtractionProjection) -> Array[String]:
	var changed: Array[String] = []
	var next_by_id := _exact_selection_map(next.eligible_items)
	for item_id: String in _selected.keys():
		var exact := next_by_id.get(item_id) as ExtractionSelection
		var prior := _selected[item_id] as ExtractionSelection
		if exact == null or prior.expected_source_container_id != exact.expected_source_container_id or prior.expected_source_slot != exact.expected_source_slot:
			_selected.erase(item_id)
			changed.append(item_id)
	_policy = next.copy()
	_unused_acknowledged = false
	return changed
```

- [ ] **Step 6: Import, run GREEN, and commit**

Import/classify all new production/test/runner UIDs. Repeat Step 4 and require `TEST_SUMMARY: PASS (0 failures)` and `TERMINAL_EXTRACTION_FLOW_SUMMARY: PASS`, each with exit `0`.

```powershell
& $godot --headless --path (Get-Location).Path --import
Resolve-GeneratedUidState @(
	'scripts/ui/run_result/terminal_extraction_item_projection.gd.uid',
	'scripts/ui/run_result/terminal_extraction_projection.gd.uid',
	'scripts/ui/run_result/terminal_extraction_view_model.gd.uid',
	'scripts/ui/run_result/terminal_extraction_selection_controller.gd.uid',
	'scripts/ui/living_forge/components/forge_extraction_item_card.gd.uid',
	'scripts/ui/run_result/terminal_extraction_panel.gd.uid',
	'tests/unit/test_terminal_extraction_view_model.gd.uid',
	'tests/unit/test_terminal_extraction_selection_controller.gd.uid',
	'tests/unit/test_terminal_extraction_panel.gd.uid',
	'tests/integration/terminal_extraction_flow_runner.gd.uid'
)
git diff --check
git add -- scripts/ui/run_result scenes/ui/run_result scripts/ui/living_forge/components/forge_extraction_item_card.gd scripts/ui/living_forge/components/forge_extraction_item_card.gd.uid scenes/ui/living_forge/components/forge_extraction_item_card.tscn scenes/ui/hud.tscn scripts/ui/hud.gd tests/unit/test_terminal_extraction_view_model.gd tests/unit/test_terminal_extraction_view_model.gd.uid tests/unit/test_terminal_extraction_selection_controller.gd tests/unit/test_terminal_extraction_selection_controller.gd.uid tests/unit/test_terminal_extraction_panel.gd tests/unit/test_terminal_extraction_panel.gd.uid tests/integration/terminal_extraction_flow_runner.gd tests/integration/terminal_extraction_flow_runner.gd.uid
git commit -m "feat: add terminal extraction picker"
```

---

### Task 10: Orchestrate the Once-Only Terminal State Machine and Recovery Safety

**Files:**

- Create: `scripts/run/run_terminal_flow.gd`
- Create: `scripts/run/run_terminal_begin_result.gd`
- Create: `scripts/run/run_terminal_recovery_record.gd`
- Create: `scripts/run/run_terminal_recovery_record_result.gd`
- Create: `scripts/run/run_terminal_recovery_codec.gd`
- Create: `scripts/run/run_terminal_recovery_service.gd`
- Create: `scripts/run/run_terminal_recovery_safety_result.gd`
- Modify: `scripts/run/run_recovery_service.gd`
- Modify: `scripts/extraction/run_resolution_evaluator.gd`
- Modify: `scripts/extraction/run_resolution_result.gd`
- Modify: `scripts/extraction/run_resolution_service.gd`
- Modify: `scripts/profile/profile_state.gd`
- Modify: `scripts/profile/profile_codec.gd`
- Modify: `scripts/profile/profile_migrator.gd`
- Modify: `scripts/profile/profile_mutation_service.gd`
- Modify: `scripts/items/item_slot_container.gd`
- Modify: `scripts/profile/profile_item_storage_service.gd`
- Modify: `scripts/profile/profile_storage_reconciler.gd`
- Modify: `scripts/equipment/profile_loadout_assignment_request.gd`
- Modify: `scripts/equipment/profile_loadout_assignment_service.gd`
- Modify: `scripts/equipment/loadout_compatibility_service.gd`
- Modify: `scripts/equipment/loadout_transition_service.gd`
- Modify: `scripts/run/run_loadout_checkout_service.gd`
- Modify: `scripts/ui/storage/profile_storage_projection.gd`
- Modify: `scripts/ui/armoury/armoury_screen.gd`
- Modify: `scenes/ui/armoury/armoury_screen.tscn`
- Modify: `scripts/game/main.gd`
- Create: `tests/unit/test_run_terminal_flow.gd`
- Create: `tests/unit/test_run_terminal_recovery_safety.gd`
- Modify: `tests/unit/test_profile_state.gd`
- Modify: `tests/unit/test_profile_item_schema_migration.gd`
- Modify: `tests/unit/test_atomic_profile_store.gd`
- Modify: `tests/unit/test_profile_mutation_service.gd`
- Modify: `tests/unit/test_profile_item_storage_service.gd`
- Modify: `tests/unit/test_profile_storage_reconciler.gd`
- Modify: `tests/unit/test_profile_loadout_assignment_service.gd`
- Modify: `tests/unit/test_loadout_transition_service.gd`
- Modify: `tests/unit/test_run_loadout_checkout_service.gd`
- Modify: `tests/unit/test_profile_storage_projection.gd`
- Modify: `tests/unit/test_armoury_screen.gd`
- Modify: `tests/unit/test_main_wiring.gd`

**Interfaces:**

- `ProfileState.SCHEMA_VERSION` becomes `6` and adds exact top-level `terminal_resolution: Dictionary = {}` plus `terminal_recovery_overflow: Dictionary = {}`. The v5-to-v6 migration adds only those empty dictionaries; the current v6 codec validates terminal resolution as empty or `RunTerminalRecoveryCodec` schema `1`, and overflow as empty or the exact profile-owned overflow container.
- `ItemSlotContainer.PROFILE_TERMINAL_RECOVERY_OVERFLOW := &"profile_terminal_recovery_overflow"` has stable container ID `&"terminal-recovery-overflow"` and capacity `EquipmentSlotIndex.capacity()`. It is not general extra storage: only terminal recovery may move permanent leader-loadout items into it, ordinary storage rejects it as a destination, and Armoury exposes it only as a source whose items may later move out to ordinary stash.
- Every profile ownership decoder/fingerprint includes the overflow container after leader loadout and stored stash tabs: profile storage reconciliation, profile assignment request/service, compatibility/transition, run checkout, terminal evaluator, and storage projection. These services preserve its document unchanged unless they own the explicit source-only move below; compatibility and checkout never count it as stash capacity or a loadout. Assignment explicitly rejects overflow as either endpoint, so comparison preview cannot silently equip it.
- `ProfileItemStorageService` accepts overflow only as the source of `MOVE_TO_EMPTY` into an existing ordinary stash container. It rejects Create, Swap, any destination overflow, overflow-to-leader, nonempty destinations, and movement of an item listed in the current terminal record's `protected_displaced_item_ids` until terminal completion; older overflow contents may still be drained during a later interruption. Its candidate rebuild writes leader, stash, and unchanged-or-drained overflow back together. Main's Armoury move handler branches on the real projected source: overflow-to-empty-stash uses this storage service, every ordinary leader/stash assignment keeps the existing assignment route, and `_storage_item_location`/`_storage_item_at` include overflow. Armoury disables invalid overflow drops with a readable source-only or `Available after terminal resolution` explanation.
- `RunTerminalRecoveryRecord.Stage { CHOOSING_EXTRACTION, RESOLUTION_INTERRUPTED, RESOLVED_AWAITING_PROJECTION }`. Pre-resolution stages store schema version, exact `RunTerminalSnapshot`, canonical selected item IDs, transaction ID, protected displaced item IDs, and readable interruption reason. The resolved stage additionally stores the accepted extraction and applied transaction ID needed to rebuild the accepted result from durable profile truth. It never stores scene nodes or display-derived identity.
- `RunTerminalRecoveryService.persist_initial(profile_id, snapshot, root) -> ProfileMutationResult` uses transaction `terminal-capture:<run_id>` to verify exact profile/run/seed/player/leader identity, atomically replace the strict resumable bootstrap's `item_state` with the snapshot's validated `RunResolutionSource.item_state`, and write the terminal record in the same profile mutation. This terminal checkpoint prevents legitimate live loot changes from making recovery persistence impossible. `persist_selection(...)` uses `terminal-selection:<resolution-transaction-id>`; `inspect(profile) -> RunTerminalRecoveryRecordResult` requires strict structural equality between the now-checkpointed resumable item state and terminal source. None revoke the run before accepted resolution.
- Task 7's generic `resolve()`/`resolve_source()` and shared `RunResolutionEvaluator` remain terminal-agnostic and continue to support existing strict-resumable direct callers with `terminal_resolution == {}`. Task 10 adds `RunResolutionService.resolve_terminal_source(profile_id, source, request, root) -> RunResolutionResult`, used only by `RunTerminalFlow`; inside its one durable candidate mutation it requires the matching nonempty terminal record, applies the shared evaluation, clears `candidate.resumable_run`, and calls `RunTerminalRecoveryService.mark_resolved_candidate(candidate, request, accepted_extraction) -> String` instead of clearing `terminal_resolution`. Thus extraction, run revocation, and `RESOLVED_AWAITING_PROJECTION` commit atomically, while retained generic resolution tests and callers need no invented record.
- `ProfileMutationService.apply_irreversible_terminal_completion(profile_id: String, transaction_id: String, terminal_run_id: StringName, terminal_instance_ids: Array[String], mutate: Callable, root: String = ProfileStore.DEFAULT_ROOT, now_unix: int = -1, operation: String = "", request: Dictionary = {}) -> ProfileMutationResult` extends the existing irreversible boundary with exact terminal-run sanitation. It rejects an empty run ID, invalid/duplicate instance IDs, or missing mutation/operation before load. After the supplied mutation clears the matching receipt, historical transaction snapshots are replaced when either their `terminal_resolution` owns that run or they contain any supplied terminal-source instance ID—even when the run contained zero items—and the new completion transaction's `result_profile` is built only from the sanitized candidate. Existing generic mutation entry points remain unchanged.
- `RunTerminalRecoveryService.complete_terminal(profile_id, run_id, root) -> ProfileMutationResult` uses stable transaction `terminal-complete:<run_id>` and `apply_irreversible_terminal_completion` to clear the matching resolved receipt only when an exact Restart Run, Return to Forge, or Quit Application action is accepted. It supplies every terminal-source instance ID before clearing. The canonical mutation document is the stable `{profile_id, run_id}`; the mutation callback itself requires the exact resolved receipt/applied resolution transaction before clearing. Therefore a committed retry can replay by run ID after the receipt is gone, while a first call against a mismatched or pre-resolution record fails closed. Success requires irreversible storage verification of sanitized primary and backup generations and cleanup/sanitization of `.tmp`, displaced, and prior irreversible artifacts. Navigation/reload/quit must not occur unless this entire boundary succeeds.
- `RunTerminalRecoveryService.protect_displaced_gear(profile_id, record, root) -> ProfileMutationResult` is legal only when preflight reports `automatic_only_blocked`. It verifies terminal/run identity, requires an empty overflow with enough capacity, moves every occupied permanent leader-loadout item into its same numbered overflow slot, clears those leader slots, leaves the item registry unchanged, updates the recovery record, and commits idempotently as `terminal-protect-displaced:<run_id>:<full-loadout-sha256>`. It never deletes or silently replaces permanent gear.
- Task 10 extends `RunResolutionResult.success(profile, duplicate, accepted_extraction, protected_displaced_item_ids)` with a defensive protected-ID list. First resolve copies the IDs from the validated terminal record; duplicate/recovered resolve reconstructs them from the matching durable resolved receipt. No caller infers protected gear by scanning unrelated profile containers.
- `RunTerminalFlow.State { IDLE, PERSISTING_RECOVERY, CHOOSING_EXTRACTION, PREFLIGHTING, RESOLVING, RESOLUTION_INTERRUPTED, RESOLVED_AWAITING_PROJECTION, PROJECTION_INTERRUPTED, FINALIZED }`.
- `RunTerminalBeginResult.Code { READY, CAPTURE_FAILED, PERSISTENCE_FAILED }` exposes defensive snapshot/error and prevents Main from inferring failure stage from copy.
- `begin(outcome, elapsed_seconds, context, profile, profile_root) -> RunTerminalBeginResult` captures once, stores stable base identity `terminal-resolution:<run_id>`, durably persists the initial recovery record, and only then exposes the extraction picker. Persistence failure enters `RESOLUTION_INTERRUPTED` without cleanup or consequence actions.
- `retry_persist_initial(profile_root: String) -> ProfileMutationResult` is valid only after initial persistence failure, reuses the in-memory snapshot and exact initial-record identity, rejects duplicate pending activation, and enters `CHOOSING_EXTRACTION` only after durable success. It is distinct from resolution retry.
- `resume(record: RunTerminalRecoveryRecord, profile: ProfileState, profile_root: String) -> RunTerminalSnapshotResult` reconstructs the same source/projection from typed durable truth. Pre-resolution records reopen extraction/interruption; a resolved receipt validates the applied transaction and current durable placements, rebuilds the accepted `RunResolutionResult`, and retries recap projection without resolving again. On boot a valid terminal record takes precedence over ordinary Resume/Abandon and new-run setup.
- `confirm_extraction(item_ids: Array[String], profile: ProfileState) -> RunResolutionPreflightResult` reprojects exact selections from policy truth, rejects stale/over-capacity input, and never trusts UI-authored source data.
- `resolve(profile_id, profile_root) -> RunResolutionResult` reuses the exact request while pending/retrying and delegates only to `resolve_terminal_source`. Before resolve, the canonical selection/transaction is persisted in the recovery record. Confirmation rebuilds selections in `RunExtractionProjection.eligible_items` order and derives `transaction_id = "terminal-resolution:<run_id>:<full-canonical-selection-sha256>"`; input permutations of the same set share one ID, changed sets receive a different ID, and exact retry reuses it.
- Query methods are `can_begin() -> bool`, `state() -> State`, `transaction_base() -> String`, `transaction_id() -> String`, `extraction_projection() -> RunExtractionProjection`, `snapshot() -> RunTerminalSnapshot`, and `accepted_result() -> RunResolutionResult`; every returned object is defensive.
- `protect_displaced_gear(profile_id: String, profile_root: String) -> ProfileMutationResult` is exposed only for the typed automatic-only capacity interruption. On success the flow refreshes durable truth, reruns preflight, and returns to the picker/resolution path; because the leader loadout is then empty, mandatory displaced-gear stash use is zero.
- `retry_projection(profile: ProfileState) -> RunResolutionResult` is valid only from `PROJECTION_INTERRUPTED` with a matching durable resolved receipt. It revalidates applied transaction/placements, rebuilds the accepted result defensively, and returns to `RESOLVED_AWAITING_PROJECTION`; it never calls the evaluator, mutation service, or resolution service. Failure remains `PROJECTION_INTERRUPTED` with the updated readable reason, so repeated retries are bounded and idempotent.
- Main-owned post-resolution work transitions through `mark_projection_interrupted(reason: String) -> bool` and `finalize() -> bool`. Both require a valid durable `RESOLVED_AWAITING_PROJECTION` receipt; `finalize()` does not clear it while the result screen is open. `mark_projection_interrupted()` is valid only after resolution success but before cleanup. Result actions key only from `FINALIZED` and clear the receipt durably before navigation.
- Signals: `extraction_ready(projection)`, `resolution_pending`, `result_ready(snapshot, result)`, `resolution_failed(reason, retry_allowed)`, and `projection_failed(reason)`.
- `RunRecoveryService.verify_terminal_safety(profile: ProfileState, snapshot: RunTerminalSnapshot) -> RunTerminalRecoverySafetyResult` validates by stage. Pre-resolution stages require a valid typed record whose snapshot/source and strict resumable run match structurally. A resolved stage requires no resumable run and instead validates exact snapshot/source, accepted extraction, applied transaction, and durable item placements. Only that persisted match permits safe recovery actions.

- [ ] **Step 1: Write RED state, identity, and duplicate tests**

```gdscript
var first := flow.begin(RunTerminalSnapshot.Outcome.VICTORY, 90.0, context, profile, root)
var duplicate := flow.begin(RunTerminalSnapshot.Outcome.VICTORY, 90.0, context, profile, root)
TestAssertions.equal(first.code, RunTerminalBeginResult.Code.READY, "first terminal event persists and opens", failures)
TestAssertions.truthy(duplicate.code != RunTerminalBeginResult.Code.READY, "duplicate terminal event is rejected", failures)
TestAssertions.equal(flow.transaction_base(), "terminal-resolution:%s" % context.run_id, "run transaction base is stable", failures)
TestAssertions.equal(flow.state(), RunTerminalFlow.State.CHOOSING_EXTRACTION, "flow waits for explicit extraction", failures)
```

Cover invalid snapshot, initial-record persistence before picker, persistence failure with Return/Quit unavailable, duplicate-pending rejection and success/failure of `retry_persist_initial`, durable resume precedence, all-fit/constrained/zero capacity, stale selection refresh, exact-selection mapping, selection-order permutation stability, persisted selection before mutation, unused-capacity ack gating, preflight reducer error, automatic-only durable interruption, duplicate Confirm, and resolution retry with identical request. Prove generic `resolve_source` still succeeds with an empty terminal record, `resolve_terminal_source` rejects an empty/mismatched record without write, accepted terminal resolution atomically writes `RESOLVED_AWAITING_PROJECTION` while clearing the resumable run, a crash immediately afterward cold-resumes recap without resolving again, and projection failure retains the receipt. Exercise same-session `retry_projection` failure/success/repeated success, assert zero resolution/evaluator/mutation calls, then prove `finalize()` retains the receipt while actions are visible, action-time clear failure blocks navigation, successful action clear permits navigation, and no transition leaves `FINALIZED` except exact terminal completion.

- [ ] **Step 2: Write RED recovery-safety tests**

Assert schema-6 empty/default round trip, v5 migration adds empty record/overflow without invented contents, valid pre-resolution and resolved-record round trips, malformed/unknown fields fail closed, terminal capture atomically checkpoints a newer valid live item state, stale run identity rejects without write, injected save failure exposes neither checkpoint nor record, and exact terminal-record/strict-bootstrap structure passes pre-resolution safety. For resolved safety, prove the absent resumable run plus exact applied transaction, accepted extraction, item registry, loadout, stash, and overflow placements passes; any run ID, seed, player, leader, member/source, item record, container, slot, selection, transaction, or stage mismatch fails. Prove input profile/snapshot remain unchanged. For completion, seed old primary/backup/temp artifacts and multiple applied-transaction `result_profile` snapshots (including a zero-item run), then assert successful irreversible completion leaves primary and `.bak` with an empty receipt, no stale temp/displaced artifact containing the receipt, and no transaction snapshot containing that terminal run or a lost terminal-source instance ID. Inject precommit/promotion/sanitation failures and prove navigation authorization stays false and the last recoverable generations remain exact.

Also assert the recovery overflow contract: automatic-only blockage alone exposes protection; ordinary reducible failures do not; the exact confirmation count/copy is stable; mutation failure is atomic; nonempty/full overflow reports a readable failure; general storage cannot target overflow; protection preserves every item and moves permanent leader gear to matching overflow slots; rerun preflight becomes accepted; cold resume retains the overflow and record; Armoury displays overflow and permits only move-to-empty out to ordinary stash. Prove older overflow items can drain during a later terminal interruption, current-record protected IDs remain locked until completion, and both cases show exact readable reasons. Run fixtures with nonempty overflow through assignment fingerprint/preview, compatibility projection/transition, checkout, storage reconciliation, terminal evaluation, and storage projection to prove all decode successfully, preserve overflow byte-structurally when not the owner, exclude it from ordinary destination/capacity sets, and keep item ownership unique. Assert Main routes overflow sources through `ProfileItemStorageService` and never `ProfileLoadoutAssignmentService`.

- [ ] **Step 3: Run RED**

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 900 --script res://tests/focused_test_runner.gd -- tests/unit/test_run_terminal_flow.gd tests/unit/test_run_terminal_recovery_safety.gd tests/unit/test_run_resolution_preflight.gd tests/unit/test_run_resolution_service.gd tests/unit/test_run_extraction_policy.gd tests/unit/test_profile_state.gd tests/unit/test_profile_item_schema_migration.gd tests/unit/test_atomic_profile_store.gd tests/unit/test_profile_mutation_service.gd tests/unit/test_profile_item_storage_service.gd tests/unit/test_profile_storage_reconciler.gd tests/unit/test_profile_loadout_assignment_service.gd tests/unit/test_loadout_transition_service.gd tests/unit/test_run_loadout_checkout_service.gd tests/unit/test_profile_storage_projection.gd tests/unit/test_armoury_screen.gd tests/unit/test_main_wiring.gd
```

Expected: nonzero exit and `TEST_SUMMARY: FAIL` for missing flow/recovery/schema-6, irreversible-sanitation, and overflow ownership/routing contracts only.

- [ ] **Step 4: Implement the flow as a RefCounted authority coordinator**

Keep runtime effect cleanup/navigation out of this class. It owns immutable snapshot/request/accepted result, rejects invalid transitions, and calls existing policy/preflight/resolve/recovery services. UI item IDs map through the current policy projection:

```gdscript
var wanted: Dictionary = {}
for item_id: String in item_ids:
	if wanted.has(item_id):
		return RunResolutionPreflightResult.failure("Selection contains a duplicate item.")
	wanted[item_id] = true
for exact: ExtractionSelection in _extraction_projection.eligible_items:
	if wanted.has(exact.item_id):
		selections.append(exact.copy())
if selections.size() != wanted.size():
	return RunResolutionPreflightResult.failure("Selection changed; review extraction again.")
```

The transaction ID is derived only after exact selections are canonicalized:

```gdscript
func _transaction_id_for(selections: Array[ExtractionSelection]) -> String:
	var documents: Array[Dictionary] = []
	for selection: ExtractionSelection in selections:
		documents.append(selection.to_dictionary())
	var digest := JSON.stringify(documents).sha256_text()
	return "%s:%s" % [_transaction_base, digest]
```

When automatic-only capacity is blocked, the flow exposes one explicit, confirmed `Protect Displaced Gear` transition. The service computes the full-loadout digest from canonical slot/item records, performs one copy-on-write profile mutation, preserves the registry, and reruns the same pure preflight against refreshed truth. The UI never writes overflow directly.

- [ ] **Step 5: Implement exact terminal durability verification**

Decode the profile's strict resumable run through `ResumableRunItemCodec`, decode `terminal_resolution` through the strict recovery codec, and compare typed identity fields plus `ItemOwnershipState.to_dictionary()` using structural dictionary equality. Pre-resolution reload resumes the terminal picker/interruption—not combat and not ordinary run recovery—preserving the confirmed canonical selection when present. Resolved reload validates the absent resumable run, applied transaction, accepted extraction, and durable placements, then rebuilds the accepted result and recap without reapplying extraction. Overflow participates in every profile ownership uniqueness/placement check that previously covered only leader loadout and stash.

- [ ] **Step 6: Import, run GREEN, and commit**

Import/classify exact UIDs, repeat Step 3, then run:

```powershell
& $godot --headless --path (Get-Location).Path --import
Resolve-GeneratedUidState @(
	'scripts/run/run_terminal_flow.gd.uid',
	'scripts/run/run_terminal_begin_result.gd.uid',
	'scripts/run/run_terminal_recovery_record.gd.uid',
	'scripts/run/run_terminal_recovery_record_result.gd.uid',
	'scripts/run/run_terminal_recovery_codec.gd.uid',
	'scripts/run/run_terminal_recovery_service.gd.uid',
	'scripts/run/run_terminal_recovery_safety_result.gd.uid',
	'tests/unit/test_run_terminal_flow.gd.uid',
	'tests/unit/test_run_terminal_recovery_safety.gd.uid'
)
& $godot --headless --path (Get-Location).Path --quit-after 900 --script res://tests/focused_test_runner.gd -- tests/unit/test_run_terminal_flow.gd tests/unit/test_run_terminal_recovery_safety.gd tests/unit/test_run_resolution_preflight.gd tests/unit/test_run_resolution_service.gd tests/unit/test_run_extraction_policy.gd tests/unit/test_profile_state.gd tests/unit/test_profile_item_schema_migration.gd tests/unit/test_atomic_profile_store.gd tests/unit/test_profile_mutation_service.gd tests/unit/test_profile_item_storage_service.gd tests/unit/test_profile_storage_reconciler.gd tests/unit/test_profile_loadout_assignment_service.gd tests/unit/test_loadout_transition_service.gd tests/unit/test_run_loadout_checkout_service.gd tests/unit/test_profile_storage_projection.gd tests/unit/test_armoury_screen.gd tests/unit/test_main_wiring.gd
& $godot --headless --path (Get-Location).Path --quit-after 1200 --script res://tests/integration/run_recovery_profile_lifecycle_runner.gd
```

Require `TEST_SUMMARY: PASS (0 failures)`, `RUN_RECOVERY_PROFILE_LIFECYCLE: PASS`, `RUN_RECOVERY_CURRENT: PASS`, `RUN_RECOVERY_LEGACY_CLASS: PASS`, and `RUN_RECOVERY_ABANDON: PASS`, each with exit `0`.

```powershell
git diff --check
git add -- scripts/run/run_terminal_flow.gd scripts/run/run_terminal_flow.gd.uid scripts/run/run_terminal_begin_result.gd scripts/run/run_terminal_begin_result.gd.uid scripts/run/run_terminal_recovery_record.gd scripts/run/run_terminal_recovery_record.gd.uid scripts/run/run_terminal_recovery_record_result.gd scripts/run/run_terminal_recovery_record_result.gd.uid scripts/run/run_terminal_recovery_codec.gd scripts/run/run_terminal_recovery_codec.gd.uid scripts/run/run_terminal_recovery_service.gd scripts/run/run_terminal_recovery_service.gd.uid scripts/run/run_terminal_recovery_safety_result.gd scripts/run/run_terminal_recovery_safety_result.gd.uid scripts/run/run_recovery_service.gd scripts/run/run_loadout_checkout_service.gd scripts/extraction/run_resolution_evaluator.gd scripts/extraction/run_resolution_result.gd scripts/extraction/run_resolution_service.gd scripts/profile/profile_state.gd scripts/profile/profile_codec.gd scripts/profile/profile_migrator.gd scripts/profile/profile_mutation_service.gd scripts/profile/profile_item_storage_service.gd scripts/profile/profile_storage_reconciler.gd scripts/items/item_slot_container.gd scripts/equipment/profile_loadout_assignment_request.gd scripts/equipment/profile_loadout_assignment_service.gd scripts/equipment/loadout_compatibility_service.gd scripts/equipment/loadout_transition_service.gd scripts/ui/storage/profile_storage_projection.gd scripts/ui/armoury/armoury_screen.gd scenes/ui/armoury/armoury_screen.tscn scripts/game/main.gd tests/unit/test_run_terminal_flow.gd tests/unit/test_run_terminal_flow.gd.uid tests/unit/test_run_terminal_recovery_safety.gd tests/unit/test_run_terminal_recovery_safety.gd.uid tests/unit/test_profile_state.gd tests/unit/test_profile_item_schema_migration.gd tests/unit/test_atomic_profile_store.gd tests/unit/test_profile_mutation_service.gd tests/unit/test_profile_item_storage_service.gd tests/unit/test_profile_storage_reconciler.gd tests/unit/test_profile_loadout_assignment_service.gd tests/unit/test_loadout_transition_service.gd tests/unit/test_run_loadout_checkout_service.gd tests/unit/test_profile_storage_projection.gd tests/unit/test_armoury_screen.gd tests/unit/test_main_wiring.gd
git commit -m "feat: orchestrate durable terminal resolution"
```

Expected: all exact PASS markers, exit `0`, and no mutation before the durable resolve call.

---

### Task 11: Build Truth-Only Recap Providers and the Stylized Result Panel

**Files:**

- Create: `scripts/ui/run_result/run_recap_entry_projection.gd`
- Create: `scripts/ui/run_result/run_recap_section_projection.gd`
- Create: `scripts/ui/run_result/run_recap_provider.gd`
- Create: `scripts/ui/run_result/run_recap_provider_result.gd`
- Create: `scripts/ui/run_result/run_loot_recap_provider.gd`
- Create: `scripts/ui/run_result/run_result_party_member_projection.gd`
- Create: `scripts/ui/run_result/run_result_projection.gd`
- Create: `scripts/ui/run_result/run_result_projection_result.gd`
- Create: `scripts/ui/run_result/run_result_view_model.gd`
- Modify: `scripts/ui/run_result_panel.gd`
- Modify: `scenes/ui/run_result_panel.tscn`
- Create: `tests/unit/test_run_recap_projection.gd`
- Create: `tests/unit/test_run_result_projection.gd`
- Create: `tests/unit/test_run_result_panel.gd`
- Create: `tests/integration/run_result_lifecycle_runner.gd`

**Interfaces:**

- `RunRecapProvider.provider_id() -> StringName`, `display_order() -> int`, and `project(snapshot: RunTerminalSnapshot, resolution: RunResolutionResult) -> RunRecapProviderResult`; the result contains either one defensive section or an exact error.
- `RunRecapSectionProjection.SemanticKind { OUTCOME, PARTY, BUILD, LOOT, CONSEQUENCE, HIGHLIGHT }` defines stable high-level ordering.
- Reserved core IDs are `&"outcome"`, `&"party"`, and `&"loot"`. `RunResultViewModel` builds outcome/party directly and invokes the required first-party `RunLootRecapProvider` for `&"loot"`; optional providers cannot overwrite a core ID or another provider ID.
- `RunResultViewModel.build(snapshot, resolution, refreshed_profile, providers) -> RunResultProjectionResult` validates core outcome/duration/party/loot truth, sorts optional providers by semantic-kind order, `display_order`, then `provider_id`, omits empty/failed optional providers, and fails the whole projection if a required core claim is invalid.
- `RunResultProjection.section_ids() -> Array[StringName]` returns defensive stable order.
- `RunResultProjection.TerminalState { PENDING, INTERRUPTED, FINALIZED }`, `InterruptionKind { TERMINAL_STATE_SAVE, RESOLUTION, PROJECTION }`, plus typed `readable_reason`, `retry_terminal_save_allowed`, `retry_resolution_allowed`, `retry_projection_allowed`, `protect_displaced_gear_allowed`, `open_armoury_allowed`, `restart_run_allowed`, `return_to_forge_allowed`, and `quit_application_allowed` fields carries every result/action state.
- Exact constructors are `RunResultViewModel.pending(snapshot)`, `terminal_save_interrupted(snapshot, reason)`, `resolution_interrupted(snapshot, reason, recovery_safety)`, `projection_interrupted(snapshot, accepted_resolution, reason)`, and `build(snapshot, accepted_resolution, refreshed_profile, providers)`; all return `RunResultProjectionResult` and set one exact `InterruptionKind`/retry action without loose booleans.
- `RunResultPanel.present(projection: RunResultProjection)` is the only presentation entry point; signals are `restart_run_requested`, `return_to_forge_requested`, `open_armoury_requested(return_focus: Control)`, `quit_application_requested`, `retry_terminal_save_requested`, `retry_resolution_requested`, `retry_projection_requested`, and `protect_displaced_gear_requested(return_focus: Control)`.
- Exact labels are `Retry Save Terminal State`, `Retry Resolution`, `Retry Results`, `Protect Displaced Gear`, `Open Armoury`, `Restart Run`, `Return to Forge`, and `Quit Application`. `Retry Results` appears only for `InterruptionKind.PROJECTION` and is initially focused because it is non-destructive and stage-accurate. `Protect Displaced Gear` requires an explicit confirmation reading `Move N current leader items to Recovery Overflow so automatic extraction can continue.` `Restart Run` and consequence-assuming recap actions exist only in finalized state; interrupted navigation is exposed only by typed durable-recovery authorization.

- [ ] **Step 1: Write RED projection/provider tests**

Assert core outcome and duration always show, every valid party member appears in order, loot claims match accepted extraction plus refreshed durable profile, unsupported sections are absent, optional empty providers omit, optional error/invalid providers log+omit, and duplicate/reserved IDs reject deterministically.

```gdscript
var built := view_model.build(snapshot, resolution, refreshed_profile, [empty_provider, highlights_provider])
TestAssertions.truthy(built.ok(), "valid current truth builds", failures)
TestAssertions.equal(built.projection.section_ids(), [&"outcome", &"party", &"loot", &"highlights"], "provider order is deterministic", failures)
TestAssertions.truthy(not (&"build_history" in built.projection.section_ids()), "unsupported build history is hidden", failures)
TestAssertions.truthy(not view_model.build(snapshot, resolution, refreshed_profile, [duplicate_a, duplicate_b]).ok(), "duplicate provider IDs reject", failures)
```

Core loot validation must prove automatic IDs exist in refreshed leader loadout, selected IDs exist in refreshed stash, `resolution.protected_displaced_item_ids` exist in refreshed Recovery Overflow, and lost IDs are absent before claiming durable success. The provider emits `Protected displaced gear` only when the accepted typed result and refreshed placement both prove it; it never infers the claim from capacity arithmetic or unrelated overflow contents.

- [ ] **Step 2: Write RED panel/action tests**

Assert exact labels including `Retry Save Terminal State`, `Retry Results`, and `Protect Displaced Gear`, destructive action not default-focused, finalized-only Restart visibility, initial-save retry pending/failure/success behavior, resolution-interrupted retry behavior, projection-interrupted Retry Results visibility/default focus and duplicate-pending suppression, protection visibility only for typed automatic-only blockage, exact protection confirmation copy/count, durable-recovery Armoury/Return/Quit visibility only when typed authorization is present, long party/item detail scrolling, 24-member reachability, and mouse/keyboard/simulated-controller parity. Call only `present(projection)` in every state test.

- [ ] **Step 3: Write RED lifecycle runner**

Exercise victory and defeat projections, pending disabled state, interrupted retry state, safe/unsafe navigation availability, provider omission/collision, exact action signals, and focus restoration. End with `RUN_RESULT_LIFECYCLE_SUMMARY: PASS`.

- [ ] **Step 4: Run RED**

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_run_recap_projection.gd tests/unit/test_run_result_projection.gd tests/unit/test_run_result_panel.gd
& $godot --headless --path (Get-Location).Path --quit-after 900 --script res://tests/integration/run_result_lifecycle_runner.gd
```

Expected: nonzero exits; `TEST_SUMMARY: FAIL` and `RUN_RESULT_LIFECYCLE_SUMMARY: FAIL` identify missing typed recap/result APIs and replacement of boolean `show_result()`.

- [ ] **Step 5: Implement typed recap registry and Living Forge panel**

Use bounded summary rows and expandable scroll detail. Providers run once per accepted snapshot/resolution revision; never from `_process()`. Inspect each explicit `RunRecapProviderResult`; log an optional provider's stable ID and returned error, then omit it. Do not synthesize a build/upgrades, telemetry, consequence, or highlight provider.

- [ ] **Step 6: Import, run GREEN, and commit**

Import/classify nine projection/provider/result UIDs, three unit-test UIDs, and the runner UID. Repeat Step 4 and require `TEST_SUMMARY: PASS (0 failures)` and `RUN_RESULT_LIFECYCLE_SUMMARY: PASS`, each with exit `0`.

```powershell
& $godot --headless --path (Get-Location).Path --import
Resolve-GeneratedUidState @(
	'scripts/ui/run_result/run_recap_entry_projection.gd.uid',
	'scripts/ui/run_result/run_recap_section_projection.gd.uid',
	'scripts/ui/run_result/run_recap_provider.gd.uid',
	'scripts/ui/run_result/run_recap_provider_result.gd.uid',
	'scripts/ui/run_result/run_loot_recap_provider.gd.uid',
	'scripts/ui/run_result/run_result_party_member_projection.gd.uid',
	'scripts/ui/run_result/run_result_projection.gd.uid',
	'scripts/ui/run_result/run_result_projection_result.gd.uid',
	'scripts/ui/run_result/run_result_view_model.gd.uid',
	'tests/unit/test_run_recap_projection.gd.uid',
	'tests/unit/test_run_result_projection.gd.uid',
	'tests/unit/test_run_result_panel.gd.uid',
	'tests/integration/run_result_lifecycle_runner.gd.uid'
)
git diff --check
git add -- scripts/ui/run_result scripts/ui/run_result_panel.gd scenes/ui/run_result_panel.tscn tests/unit/test_run_recap_projection.gd tests/unit/test_run_recap_projection.gd.uid tests/unit/test_run_result_projection.gd tests/unit/test_run_result_projection.gd.uid tests/unit/test_run_result_panel.gd tests/unit/test_run_result_panel.gd.uid tests/integration/run_result_lifecycle_runner.gd tests/integration/run_result_lifecycle_runner.gd.uid
git commit -m "feat: add truthful Living Forge run results"
```

---

### Task 12: Cut Main Over to the Terminal Pipeline, Exact Result Actions, and Authoritative Abandon

**Files:**

- Create: `scripts/ui/run_setup/run_setup_restart_intent.gd`
- Modify: `scripts/ui/run_setup/run_setup_lobby_view_model.gd`
- Modify: `scripts/game/main.gd`
- Modify: `scripts/ui/run_pause_menu.gd`
- Modify: `scenes/ui/run_pause_menu.tscn`
- Modify: `tests/unit/test_main_wiring.gd`
- Modify: `tests/unit/test_run_setup_lobby_view_model.gd`
- Modify: `tests/unit/test_run_pause_menu.gd`
- Modify: `tests/integration/live_loot_lifecycle_runner.gd`
- Modify: `tests/integration/personal_loot_defeat_runner.gd`
- Modify: `tests/integration/profile_boot_main_flow_runner.gd`
- Modify: `tests/integration/run_setup_lobby_panel_runner.gd`
- Create: `tests/integration/run_terminal_flow_runner.gd`

**Interfaces:**

- Main owns one `RunTerminalFlow` and enters it from a shared `_on_terminal(outcome)` handler. Main alone owns hostile-effect cancellation, live-loot cleanup, profile refresh, scene reload, and application exit.
- Main's `_on_terminal_resolution_accepted(snapshot: RunTerminalSnapshot, resolution: RunResolutionResult)` refreshes the exact profile, verifies the durable resolved receipt, builds/validates the result projection, requires `_terminal_flow.finalize()` success, then clears disposable loot and presents; the method never clears before both projection build and finalize succeed and never clears the receipt merely because the panel opened.
- At boot, Main inspects `profile.terminal_resolution` before ordinary resumable-run recovery. A valid pre-resolution record calls `_terminal_flow.resume(...)` and reopens extraction/interrupted UI; a valid `RESOLVED_AWAITING_PROJECTION` receipt rebuilds the accepted result and recap without resolving again. Play/new-run setup stays unavailable until a terminal action durably clears the receipt.
- Initial terminal-save failure presents typed `InterruptionKind.TERMINAL_STATE_SAVE` with only `Retry Save Terminal State` enabled. Main retries `_terminal_flow.retry_persist_initial(profile_root)` from the retained in-memory snapshot; Return/Armoury/Quit remain unavailable until the record is durably saved.
- Projection failure presents typed `InterruptionKind.PROJECTION` with `Retry Results`. Main refreshes the exact profile, calls only `_terminal_flow.retry_projection(profile)`, and re-enters recap validation/cleanup/finalization from the rebuilt accepted result; it never resolves or mutates extraction again.
- `RunSetupRestartIntent.create(profile_id: String, class_id: StringName, reason: String = "")`, `copy()`, and `valid()` are one-shot ephemeral route data stored as SceneTree metadata immediately before reload and consumed/removed once after Main boot.
- `RunPauseMenu` emits `abandon_run_confirmed`; its exact visible copy is `Abandon Run`, with a confirmation explaining that run-owned progress/items are forfeited. After durable forfeit but failed profile refresh it enters a committed non-dismissible error state with exact action `Retry Return to Forge`, emits `retry_abandon_refresh_requested`, and cannot emit Abandon again. In that state Resume, Settings, Abandon, generic close, `ui_cancel`, and `pause_menu` are hidden/disabled or consumed; the SceneTree stays paused and Retry is the only focusable action until refresh succeeds.
- Main routes active-run abandon through `RunRecoveryService.forfeit(profile_id, run_id, profile_root)`, refreshes the exact profile, then returns to the front end. It never implements a second deletion path.
- For automatic-only capacity blockage, Main presents the typed `Protect Displaced Gear` action. Confirmation calls `_terminal_flow.protect_displaced_gear(...)`, refreshes the exact profile, reruns the same preflight, and returns to picker/resolve only after durable success. Ordinary `Open Armoury` remains available for inspection and manual stash organization but is not falsely presented as sufficient to free fixed capacity.

- [ ] **Step 1: Write RED terminal ordering and action-wiring tests**

Replace obsolete boolean-result/direct-quit/fixed-HUD expectations in `test_main_wiring.gd` with exact assertions for typed pending/interrupted/finalized projection wiring, terminal-record recovery precedence, and:

```gdscript
var terminal_body := _function_body(main_source, "_on_terminal")
var accepted_body := _function_body(main_source, "_on_terminal_resolution_accepted")
TestAssertions.truthy("_terminal_flow.begin" in terminal_body and not ("_clear_live_loot" in terminal_body), "terminal entry captures and never clears", failures)
TestAssertions.truthy(accepted_body.find("_build_terminal_result") >= 0 and accepted_body.find("_build_terminal_result") < accepted_body.find("_clear_live_loot"), "validated result precedes cleanup", failures)
TestAssertions.truthy(accepted_body.find("_terminal_flow.finalize") > accepted_body.find("_build_terminal_result") and accepted_body.find("_terminal_flow.finalize") < accepted_body.find("_clear_live_loot"), "fallible finalize succeeds before cleanup", failures)
TestAssertions.truthy("_terminal_flow.confirm_extraction" in main_source, "picker confirmation routes through coordinator", failures)
TestAssertions.truthy("profile_manager.refresh_profile" in main_source, "durable result refreshes profile before recap", failures)
TestAssertions.truthy("restart_run_requested" in main_source, "Restart Run has a distinct handler", failures)
TestAssertions.truthy("return_to_forge_requested" in main_source, "Return to Forge has a distinct handler", failures)
TestAssertions.truthy("open_armoury_requested" in main_source, "durable terminal recovery has a storage-management route", failures)
TestAssertions.truthy("quit_application_requested" in main_source, "Quit Application has a distinct handler", failures)
TestAssertions.truthy("protect_displaced_gear_requested" in main_source, "automatic-only recovery has a distinct protected-overflow handler", failures)
TestAssertions.truthy("retry_projection_requested" in main_source, "projection recovery has a distinct Retry Results handler", failures)

func _function_body(source: String, function_name: String) -> String:
	var start := source.find("func %s(" % function_name)
	if start < 0:
		return ""
	var next := source.find("\nfunc ", start + 1)
	return source.substr(start) if next < 0 else source.substr(start, next - start)
```

Prefer runtime outcome assertions over source-text checks where the fixture can instantiate Main; retain source checks only for ordering that cannot be observed without destructive teardown.

- [ ] **Step 2: Write RED restart-intent tests**

Assert restart appears only after finalized resolution, reload stores exact prior profile/class, boot consumes metadata once, lobby opens without checkout/auto-start, valid intent preselects, missing profile/class produces an explicit unresolved-selection reason and disabled Start, and subsequent ordinary reload cannot replay the intent.

- [ ] **Step 3: Write RED active-run Abandon tests**

Rename the signal/copy expectations, assert Cancel default focus, duplicate Confirm rejection, exact profile/run identity passed to `RunRecoveryService.forfeit`, durable resumable run revoked before front-end return, forfeit failure leaves the run/menu state recoverable, and no terminal result shows Abandon. Migrate `profile_boot_main_flow_runner.gd` from `quit_run_confirmed`/`Quit Run` to `abandon_run_confirmed`/`Abandon Run`; assert successful refresh precedes its existing reset/front-end checks. Inject post-forfeit refresh failure and prove the menu shows only `Retry Return to Forge`, cannot forfeit twice, remains paused, rejects programmatic `close()`, and consumes mouse close, keyboard/controller Cancel, and pause-toggle inputs without resuming combat. Retry calls refresh only; retry failure remains bounded/non-dismissible and retry success returns to the front end.

- [ ] **Step 4: Update lifecycle runners to RED terminal semantics**

Change `live_loot_lifecycle_runner.gd` and `personal_loot_defeat_runner.gd`: victory/defeat preserves live loot while choosing/pending/interrupted, accepted durable resolution clears it, and failure/retry retains it. Add `run_terminal_flow_runner.gd` cases for duplicate terminal event, initial-save failure with exact retry-only action/focus, recovery-record persistence before picker, extraction confirmation, reducible preflight failure, automatic-only durable interruption, exact Protect confirmation/focus, failed protection atomicity, successful protected-overflow preflight, cold reload before resolution, cold reload after accepted resolution before recap, Open Armoury/return-to-terminal recovery focus, resolution retry, durable resolved receipt, profile refresh, projection failure with exact Retry Results focus, same-session retry failure/success/duplicate-click suppression and zero resolve calls, cold projection recovery, success cleanup, action-time receipt-clear failure, action-time receipt-clear success, victory/defeat recap, restart-lobby, return, and quit signal interception.

- [ ] **Step 5: Run RED**

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 900 --script res://tests/focused_test_runner.gd -- tests/unit/test_main_wiring.gd tests/unit/test_run_setup_lobby_view_model.gd tests/unit/test_run_pause_menu.gd
& $godot --headless --path (Get-Location).Path --quit-after 1200 --script res://tests/integration/live_loot_lifecycle_runner.gd
& $godot --headless --path (Get-Location).Path --quit-after 1200 --script res://tests/integration/personal_loot_defeat_runner.gd
& $godot --headless --path (Get-Location).Path --quit-after 1200 --script res://tests/integration/profile_boot_main_flow_runner.gd
& $godot --headless --path (Get-Location).Path --quit-after 1200 --script res://tests/integration/run_setup_lobby_panel_runner.gd
& $godot --headless --path (Get-Location).Path --quit-after 1500 --script res://tests/integration/run_terminal_flow_runner.gd
```

Expected: nonzero exits; current immediate cleanup, generic reload/quit, and generic Quit Run behavior produce exact FAIL markers in their owning test/runner only.

- [ ] **Step 6: Implement the exact terminal sequence in Main**

Replace `_show_victory()`/`_show_defeat()` bodies with a shared handler whose observable order is:

```gdscript
func _on_terminal(outcome: RunTerminalSnapshot.Outcome) -> void:
	if not _terminal_flow.can_begin():
		return
	_cancel_hostile_effects()
	var begun := _terminal_flow.begin(outcome, game_run.elapsed_time(), active_run_context, profile_manager.active_profile(), profile_root)
	match begun.code:
		RunTerminalBeginResult.Code.CAPTURE_FAILED:
			_show_terminal_projection_failure(begun.error)
		RunTerminalBeginResult.Code.PERSISTENCE_FAILED:
			run_result.present(_run_result_view_model.terminal_save_interrupted(begun.snapshot, begun.error).projection)
		RunTerminalBeginResult.Code.READY:
			_show_terminal_extraction(_terminal_flow.extraction_projection())
```

On picker confirmation: reproject/reconcile; request unused-capacity acknowledgement; persist canonical selection; refresh exact profile; pure preflight; resolve stable request; refresh exact profile again; verify `RESOLVED_AWAITING_PROJECTION`; build/validate recap; require `_terminal_flow.finalize()` success; only then call `_clear_live_loot()` and final transient cleanup and present the typed finalized projection. A false finalize result calls `mark_projection_interrupted("Results could not be finalized.")`, retains all live/transient state, and presents Retry Results. Runtime and source-order tests require `_build_terminal_result` before `finalize`, and `finalize` before `_clear_live_loot`; injected finalize failure proves no cleanup. A recap failure calls `mark_projection_interrupted(reason)` and presents a typed interrupted projection backed by the same receipt. `Retry Results` immediately presents pending/disabled state, refreshes the profile, calls `retry_projection`, and passes its rebuilt result back through this recap-only tail; any failure re-presents projection interruption and restores focus to Retry Results. Automatic-only blockage presents `Protect Displaced Gear`; confirmed success refreshes the profile and reruns preflight, while failure keeps the same interruption and readable error.

- [ ] **Step 7: Implement restart, return, quit, and interrupted safety**

Every finalized terminal exit handler first calls `RunTerminalRecoveryService.complete_terminal(profile_id, run_id, profile_root)` and remains on the result panel with a readable error if that durable clear fails. Only after success does `Restart Run` store one typed intent in SceneTree metadata and reload; `_ready()` consumes/removes it and calls `_open_run_setup_from_restart()`, with existing checkout behind explicit Start. Successful finalized `Return to Forge` reloads without intent. Successful finalized `Quit Application` calls `get_tree().quit()`. In pre-resolution interrupted state, refresh and call `verify_terminal_safety`; exact durable record match enables only the recovery actions valid for its stage, and safe Return/Quit intentionally preserve the record for the next boot. Reload resumes the terminal record before ordinary run recovery. `Open Armoury` records its exact initiating result control, keeps the record, opens the existing profile storage UI, refreshes preflight on close, announces the updated reason, and returns focus to `Open Armoury` when still enabled; otherwise it focuses the enabled stage action in order `Retry Results`, `Protect Displaced Gear`, `Retry Resolution`, then the first enabled recovery action.

- [ ] **Step 8: Implement authoritative active-run Abandon**

Rename only the pause action/confirmation/signal and route it through the same exact forfeit authority already used by the recovery dialog:

```gdscript
func _on_active_run_abandon_confirmed() -> void:
	var result := _run_recovery.forfeit(active_run_context.profile_id, active_run_context.run_id, profile_root)
	if not result.ok():
		run_pause_menu.reject_abandon("Unable to abandon this run.")
		return
	_abandon_committed_profile_id = active_run_context.profile_id
	var refresh_error := profile_manager.refresh_profile(_abandon_committed_profile_id)
	if not refresh_error.is_empty():
		run_pause_menu.present_abandon_committed_refresh_error("Run abandoned, but the profile could not refresh. Retry Return to Forge.")
		return
	_abandon_committed_profile_id = ""
	_return_to_front_end()
```

`_on_retry_abandon_refresh_requested()` requires a nonempty committed profile ID, calls only `refresh_profile`, and on success clears the marker and returns to the front end. It never calls `forfeit` again. `RunPauseMenu.close()` is a no-op while the committed marker is set, and its input handler consumes both close actions in that state. Do not redesign the pause menu or add other pause features.

- [ ] **Step 9: Import, run GREEN, and commit**

Import/classify `run_setup_restart_intent.gd.uid` and `run_terminal_flow_runner.gd.uid`. Repeat Step 5 and additionally run Task 7/10 focused resolution/recovery suites. Require `TEST_SUMMARY: PASS (0 failures)`, `LIVE_LOOT_LIFECYCLE_INTEGRATION: PASS`, `PERSONAL_LOOT_DEFEAT_INTEGRATION: PASS`, `FORGE_GUARDIAN_VICTORY_REGRESSION: PASS`, `PROFILE_BOOT_MAIN_FLOW_SUMMARY: PASS`, `RUN_SETUP_LOBBY_PANEL_SUMMARY: PASS`, and `RUN_TERMINAL_FLOW_SUMMARY: PASS`, each with exit `0`.

```powershell
& $godot --headless --path (Get-Location).Path --import
Resolve-GeneratedUidState @(
	'scripts/ui/run_setup/run_setup_restart_intent.gd.uid',
	'tests/integration/run_terminal_flow_runner.gd.uid'
)
git diff --check
git add -- scripts/ui/run_setup/run_setup_restart_intent.gd scripts/ui/run_setup/run_setup_restart_intent.gd.uid scripts/ui/run_setup/run_setup_lobby_view_model.gd scripts/game/main.gd scripts/ui/run_pause_menu.gd scenes/ui/run_pause_menu.tscn tests/unit/test_main_wiring.gd tests/unit/test_run_setup_lobby_view_model.gd tests/unit/test_run_pause_menu.gd tests/integration/live_loot_lifecycle_runner.gd tests/integration/personal_loot_defeat_runner.gd tests/integration/profile_boot_main_flow_runner.gd tests/integration/run_setup_lobby_panel_runner.gd tests/integration/run_terminal_flow_runner.gd tests/integration/run_terminal_flow_runner.gd.uid
git commit -m "feat: cut over the terminal run lifecycle"
```

---

### Task 13: Qualify Responsive Layout, Input, Accessibility, and Performance

**Files:**

- Modify: `tests/unit/test_responsive_ui.gd`
- Modify: `tests/unit/test_living_forge_theme.gd`
- Create: `tests/integration/combat_loop_responsive_runner.gd`
- Create: `tests/integration/combat_loop_accessibility_runner.gd`
- Create: `tests/integration/combat_loop_performance_runner.gd`

**Interfaces:**

- Produces exact automated evidence for party sizes `1, 6, 7, 12, 20, 24`; alert counts `0, 1, 3, overflow`; viewports `1280x720`, `1920x1080`, `2560x1440`, `3840x2160`, and ultrawide `2560x1080`; normal/high contrast; default/reduced motion; default/150 UI scale; default/150 text scale; combined `ui=150/text=150`; and combined `ui=80/text=150`.
- Performance evidence records viewport, party/item/alert counts, settings, renderer, hardware context, stable real-control instance IDs, live control count, and frame-time sample. A timeout or missing sample is a failure.

- [ ] **Step 1: Write RED responsive and accessibility matrices**

For each matrix row, assert no clipping/overlap, final member/item/action reachability, spatial focus order, visible focus, minimum control-target bounds, hidden/disabled controls excluded from focus, exact return focus, destructive actions not default-focused, semantic text/icon/shape parity, and accessibility names using production identity/action wording. The `1280x720` matrix must include `ui=150/text=150` and `ui=80/text=150` through HUD paging, extraction detail/confirmation, long recap detail, and terminal actions.

- [ ] **Step 2: Write RED bounded-performance assertions**

In a windowed OpenGL Compatibility run with 24 members, overflow alerts, and a long extraction list, record real member-control instance IDs and assert they remain stable across 300 health/timer frames, alert-only changes do not replace party controls, visible compact controls remain within calculated bounds, a complete test provider's call count is one per accepted revision, and the runner completes within its declared timeout. Run the bounded-control and completion sample at default settings, `1280x720 ui=150/text=150`, and `1280x720 ui=80/text=150`. Do not add diagnostic methods to production solely for this test.

- [ ] **Step 3: Run RED and make bounded corrections**

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_responsive_ui.gd tests/unit/test_living_forge_theme.gd
& $godot --path (Get-Location).Path --rendering-method gl_compatibility --quit-after 1200 --script res://tests/integration/combat_loop_responsive_runner.gd
& $godot --path (Get-Location).Path --rendering-method gl_compatibility --quit-after 1200 --script res://tests/integration/combat_loop_accessibility_runner.gd
& $godot --path (Get-Location).Path --rendering-method gl_compatibility --quit-after 1200 --script res://tests/integration/combat_loop_performance_runner.gd
```

Expected RED: new runners identify concrete geometry/focus/bounds gaps. Correct only measured screen/component/layout defects; do not weaken thresholds or invent gameplay truth.

- [ ] **Step 4: Import, run GREEN, and commit**

Import/classify the three runner UIDs. Repeat all commands and require `COMBAT_LOOP_RESPONSIVE_SUMMARY: PASS`, `COMBAT_LOOP_ACCESSIBILITY_SUMMARY: PASS`, `COMBAT_LOOP_PERFORMANCE_SUMMARY: PASS`, exit `0`, and no parser/loader/script markers.

```powershell
& $godot --headless --path (Get-Location).Path --import
Resolve-GeneratedUidState @(
	'tests/integration/combat_loop_responsive_runner.gd.uid',
	'tests/integration/combat_loop_accessibility_runner.gd.uid',
	'tests/integration/combat_loop_performance_runner.gd.uid'
)
git diff --check
git add -- tests/unit/test_responsive_ui.gd tests/unit/test_living_forge_theme.gd tests/integration/combat_loop_responsive_runner.gd tests/integration/combat_loop_responsive_runner.gd.uid tests/integration/combat_loop_accessibility_runner.gd tests/integration/combat_loop_accessibility_runner.gd.uid tests/integration/combat_loop_performance_runner.gd tests/integration/combat_loop_performance_runner.gd.uid
git commit -m "test: qualify the Living Forge combat loop UI"
```

---

### Task 14: Capture Fresh Visual Evidence, Obtain Human Approval, and Run Cold Final Qualification

**Files:**

- Create: `tests/integration/living_forge_combat_loop_visual_evidence_runner.gd`
- Create: `docs/validation/screenshots/living-forge-combat-loop/manifest.json`
- Create: exact PNGs under `docs/validation/screenshots/living-forge-combat-loop/`
- Create: `docs/verification/2026-08-29-living-forge-hud-level-up-results.md`

**Interfaces:**

- Produces a separate schema-2 evidence set without modifying the already accepted foundation/lobby manifest.
- Every capture name is declared once in the runner, exists once on disk, is nonempty, has a unique SHA-256, and contributes to the exact source-tree fingerprint.
- Human visual approval is separate from automated geometry/input acceptance.

- [ ] **Step 1: Write the visual-evidence runner and exact manifest test first**

Jacob authorized expanding the Task 14 evidence contract from 27 to 45 captures on 2026-08-30. Declare this exact canonical capture set with deterministic fixtures:

```gdscript
const CAPTURES := [
	"hud-no-alert-rich-1.png", "hud-rich-6-three-alerts.png", "hud-compact-7.png",
	"hud-compact-20-overflow.png", "hud-compact-24-final-member-focus.png", "hud-alert-tray-focus.png",
	"hud-alert-inspect-return.png", "hud-alert-ledger-return.png",
	"level-up-direct-and-targeted.png", "level-up-recipient-24.png",
	"extraction-automatic-selected-lost.png", "result-victory-current-truth.png",
	"result-defeat-losses.png", "result-resolution-interrupted.png", "result-terminal-save-interrupted.png",
	"result-projection-interrupted.png", "result-automatic-overflow-recovery.png",
	"combat-loop-720p-text-150.png", "combat-loop-720p-ui-150-text-150.png",
	"combat-loop-720p-ui-80-text-150.png", "combat-loop-1440p.png", "combat-loop-ultrawide.png",
	"combat-loop-high-contrast.png", "combat-loop-reduced-motion.png",
	"combat-loop-ui-scale-150.png", "combat-loop-controller-focus.png", "combat-loop-mouse-hover.png",
	"result-pending-terminal-save.png", "result-pending-terminal-refresh.png",
	"result-pending-resolution.png", "result-pending-projection.png", "result-pending-protection.png",
	"result-pending-terminal-completion.png", "result-finalized-receipt-clear-error.png",
	"result-finalized-committed-refresh-retry-only.png", "result-terminal-refresh-interrupted.png",
	"pause-abandon-committed-refresh.png", "restart-lobby-valid-preselection.png",
	"restart-lobby-unresolved-selection.png", "hud-alert-720p-ui-150-text-150.png",
	"level-up-confirmation-safe-focus.png", "extraction-pending-focus.png",
	"extraction-detail-720p-ui-150-text-150.png",
	"result-expanded-detail-ui-150-text-150.png", "result-expanded-detail-ui-80-text-150.png",
]
```

Assert exact path set, exact nonempty hash set, global hash uniqueness, schema version `2`, exact candidate Git head, viewport/settings/renderer metadata, and source fingerprint. Fail if any old or extra PNG remains.

- [ ] **Step 2: Import and commit the evidence harness before capture**

Import/classify `tests/integration/living_forge_combat_loop_visual_evidence_runner.gd.uid`, then run its write-free validation mode to prove the manifest contract is RED before capture:

```powershell
& $godot --headless --path (Get-Location).Path --import
Resolve-GeneratedUidState @('tests/integration/living_forge_combat_loop_visual_evidence_runner.gd.uid')
& $godot --path (Get-Location).Path --rendering-method gl_compatibility --quit-after 600 --script res://tests/integration/living_forge_combat_loop_visual_evidence_runner.gd -- --validate-only
```

Expected: nonzero exit and `LIVING_FORGE_COMBAT_LOOP_VISUAL_SUMMARY: FAIL` naming the absent exact manifest/PNGs, with no file created. Then commit the harness:

```powershell
git add -- tests/integration/living_forge_combat_loop_visual_evidence_runner.gd tests/integration/living_forge_combat_loop_visual_evidence_runner.gd.uid
git commit -m "test: add combat loop visual evidence harness"
```

The next capture's manifest records this exact committed candidate head. Do not capture from a dirty production-code tree.

- [ ] **Step 3: Capture in a real windowed renderer**

```powershell
& $godot --path (Get-Location).Path --rendering-method gl_compatibility --quit-after 1800 --script res://tests/integration/living_forge_combat_loop_visual_evidence_runner.gd
```

Expected: `LIVING_FORGE_COMBAT_LOOP_VISUAL_SUMMARY: PASS`, exit `0`, exactly 45 current-run PNGs, 45 unique hashes, and a reproducible schema-2 fingerprint.

- [ ] **Step 4: Perform independent UI/UX review and correct findings through RED/GREEN**

Have a UI/UX designer inspect all 45 PNGs at original resolution for Living Forge consistency, battlefield legibility, hierarchy, density, rich/compact mode clarity, alert urgency, distinct terminal-save/resolution/projection retry wording and focus, automatic-only Recovery Overflow explanation/confirmation, level-up decision clarity, extraction consequence clarity, result truth, focus/hover, high contrast, reduced motion, the `2560x1440` desktop composition, ultrawide composition, both combined 720p scale corners, the expanded result-detail Text150 corners, pending/finalized result lifecycle states, committed-Abandon recovery, restart-lobby selection states, safe confirmation focus, and extraction pending/detail states. If the reviewer finds a defect, return it to the exact owning task, add the concrete failing assertion described there, make the smallest bounded correction, rerun that task's GREEN checks, and regenerate the entire evidence set.

- [ ] **Step 5: Show the screenshots to Jacob and stop at the visual gate**

Open or attach the original-resolution captures in the conversation because Jacob is remote. Report automated and UI/UX review status separately. Do not label style/hierarchy/legibility accepted until Jacob explicitly approves the shown candidate.

- [ ] **Step 6: After approval, cold-import and run every focused/integration gate**

Use a clean disposable worktree at the exact candidate commit. Run:

```powershell
$godot = (Get-Command Godot_v4.7.1-stable_win64_console.exe).Source
& $godot --headless --path (Get-Location).Path --import
& $godot --headless --path (Get-Location).Path --quit-after 1800 --script res://tests/test_runner.gd
```

Also run every new/changed integration runner from Tasks 3, 4, 6, 9, 11, 12, 13, and this task. Require exit `0`, a fresh exact `TEST_SUMMARY: PASS (255 suites)`, each runner's exact PASS marker, and absence of `SCRIPT ERROR`, `Parse Error`, `Failed loading`, and missing-resource markers. Classify/remove only unrelated generated legacy sidecars and require a clean disposable checkout afterward.

Use this exact runner matrix; the wrapper fails on a missing marker even when the process exits `0`:

```powershell
$headlessRunners = @(
	@('res://tests/integration/combat_hud_party_scale_runner.gd','COMBAT_HUD_PARTY_SCALE_SUMMARY: PASS'),
	@('res://tests/integration/combat_hud_input_runner.gd','COMBAT_HUD_INPUT_SUMMARY: PASS'),
	@('res://tests/integration/progression_arena_smoke_runner.gd','PROGRESSION_ARENA_SMOKE_SUMMARY: PASS'),
	@('res://tests/integration/upgrade_recipient_controller_scroll_runner.gd','UPGRADE_RECIPIENT_CONTROLLER_SCROLL_SUMMARY: PASS'),
	@('res://tests/integration/level_up_commit_flow_runner.gd','LEVEL_UP_COMMIT_FLOW_SUMMARY: PASS'),
	@('res://tests/integration/temporary_popup_input_runner.gd','TEMPORARY_POPUP_INPUT_SUMMARY: PASS'),
	@('res://tests/integration/terminal_extraction_flow_runner.gd','TERMINAL_EXTRACTION_FLOW_SUMMARY: PASS'),
	@('res://tests/integration/run_result_lifecycle_runner.gd','RUN_RESULT_LIFECYCLE_SUMMARY: PASS'),
	@('res://tests/integration/run_terminal_flow_runner.gd','RUN_TERMINAL_FLOW_SUMMARY: PASS'),
	@('res://tests/integration/run_recovery_profile_lifecycle_runner.gd','RUN_RECOVERY_PROFILE_LIFECYCLE: PASS'),
	@('res://tests/integration/live_loot_lifecycle_runner.gd','LIVE_LOOT_LIFECYCLE_INTEGRATION: PASS'),
	@('res://tests/integration/personal_loot_defeat_runner.gd','PERSONAL_LOOT_DEFEAT_INTEGRATION: PASS'),
	@('res://tests/integration/profile_boot_main_flow_runner.gd','PROFILE_BOOT_MAIN_FLOW_SUMMARY: PASS'),
	@('res://tests/integration/run_setup_lobby_panel_runner.gd','RUN_SETUP_LOBBY_PANEL_SUMMARY: PASS')
)
$windowedRunners = @(
	@('res://tests/integration/living_forge_combat_state_board_runner.gd','LIVING_FORGE_COMBAT_STATE_BOARD_SUMMARY: PASS'),
	@('res://tests/integration/responsive_ui_geometry_runner.gd','RESPONSIVE_GEOMETRY_SUMMARY: PASS'),
	@('res://tests/integration/level_up_five_card_geometry_runner.gd','LEVEL_UP_FIVE_CARD_SUMMARY: PASS'),
	@('res://tests/integration/combat_loop_responsive_runner.gd','COMBAT_LOOP_RESPONSIVE_SUMMARY: PASS'),
	@('res://tests/integration/combat_loop_accessibility_runner.gd','COMBAT_LOOP_ACCESSIBILITY_SUMMARY: PASS'),
	@('res://tests/integration/combat_loop_performance_runner.gd','COMBAT_LOOP_PERFORMANCE_SUMMARY: PASS'),
	@('res://tests/integration/living_forge_combat_loop_visual_evidence_runner.gd','LIVING_FORGE_COMBAT_LOOP_VISUAL_SUMMARY: PASS')
)
foreach ($runner in $headlessRunners) {
	$output = (& $godot --headless --path (Get-Location).Path --quit-after 1800 --script $runner[0] 2>&1 | Out-String)
	$output
	if ($LASTEXITCODE -ne 0 -or -not $output.Contains($runner[1])) { throw "Runner failed: $($runner[0])" }
}
foreach ($runner in $windowedRunners) {
	$output = (& $godot --path (Get-Location).Path --rendering-method gl_compatibility --quit-after 1800 --script $runner[0] 2>&1 | Out-String)
	$output
	if ($LASTEXITCODE -ne 0 -or -not $output.Contains($runner[1])) { throw "Runner failed: $($runner[0])" }
}
```

- [ ] **Step 7: Write the verification record and run final reviews**

Record exact candidate head, parent/ancestor checks, commands, exit codes, markers, suite count, runner markers, renderer, evidence names/hashes/fingerprint, UID audit, `git diff --check`, UI/UX verdict, Jacob visual verdict, and `Physical controller: DEFERRED` unless a real controller was used. Run fresh requirements and code-quality reviewers across the complete branch diff. If either reviewer requires a code or visual correction, return to the owning task, complete its focused RED/GREEN cycle, commit the repair, then repeat Task 14 Steps 3-7 including fresh screenshots and renewed Jacob approval.

- [ ] **Step 8: Commit final evidence and verification**

```powershell
git diff --check
git status --short
git add -- tests/integration/living_forge_combat_loop_visual_evidence_runner.gd tests/integration/living_forge_combat_loop_visual_evidence_runner.gd.uid docs/validation/screenshots/living-forge-combat-loop docs/verification/2026-08-29-living-forge-hud-level-up-results.md
git commit -m "test: qualify Living Forge combat loop UI"
git status --short --branch
```

Expected: clean worktree at the committed candidate. Report commit/hash and all gates. Do not push or merge until the user chooses the integration action.

---

## Final Acceptance Checklist

- [ ] Parties `1..24` are represented and reachable; `1..6` rich and `7..24` compact are proven.
- [ ] Alerts use current health/downed/dead truth, cap at three, expose exact overflow, and preserve Inspect/Ledger/pause/focus semantics without tactics controls.
- [ ] Direct, targeted, and recruitment upgrade routes match authoritative policy; duplicate pending/failure/cancel restore exact state.
- [ ] Terminal snapshot precedes cleanup, extraction is explicit, preflight is pure/shared, durable resolution gates recap/actions, and retry identity is stable.
- [ ] Recap contains every supported current fact and no inferred telemetry/history/consequences.
- [ ] Restart Run, Return to Forge, Quit Application, and active-run Abandon Run retain exact distinct persistence semantics.
- [ ] Responsive, input, accessibility, performance, focused, integration, cold-import, and full-suite gates pass with exact markers.
- [ ] Fresh windowed screenshots pass schema-2 integrity, independent UI/UX review, and Jacob's explicit visual approval.
- [ ] Third-party/generated assets have coherent styling, provenance, licence, and hashes.
- [ ] Final branch diff contains no unrelated changes; worktree is clean; no push/merge occurred without authorization.
