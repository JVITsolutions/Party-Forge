# Living Forge Foundation and Play Lobby Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish the reviewed Living Forge visual system and replace the one-click class selector with an informed, responsive Play lobby in which Player 1 can preview, select, and start a class while Seats 2-4 honestly remain `LOCAL CO-OP - COMING SOON`.

**Architecture:** Add normal and high-contrast Living Forge themes, durable accessibility settings, licensed fonts/icons, and only the reusable components required by this slice. Preserve `HUD/ClassSelection : ClassSelectionPanel` as the thin public lifecycle/focus adapter while replacing its contents with a full-screen Play-lobby panel driven by copy-owned typed projections. Extend the existing tested character-equipment preview with an isolated class-preview mode instead of duplicating its SubViewport/render lifecycle. `PartyForgeMain` remains the composition root and delegates all recovery, compatibility, checkout, warning, Armoury, profile, and persistence authority to the existing services. Class hover/focus previews, confirmation selects, and only the separate Start Run intent enters the existing authoritative start path.

**Tech Stack:** Godot 4.7.1 stable Mono, typed GDScript, `.tscn` scenes, `Theme`/`FontVariation` resources, SVG interface assets, existing profile/loadout/recovery services, focused unit suites, real-SceneTree integration runners, OpenGL Compatibility screenshot capture, Git, and PowerShell.

## Global Constraints

- Execute implementation in a fresh isolated Git worktree created with `superpowers:using-git-worktrees`; do not edit directly in the saved-project checkout.
- Create the implementation worktree from the commit that adds this plan. Its first parent must be exact commit `d2605dde626351288670696f54118077ad88bca5`, and approved Living Forge design commit `b211c8fcf152cac9ada3592f3ff907d92aaf5e2c` must be an ancestor. If either check fails, stop and re-audit the intervening diff before implementation.
- Use `superpowers:test-driven-development` for every behavior change and `superpowers:verification-before-completion` before any completion claim.
- Use subagents task-by-task. A fresh implementation subagent writes each task, a requirements reviewer checks it against this plan, and a code-quality reviewer checks the accepted diff before the task commit.
- Do not set `gui/theme/custom` in `project.godot` during this slice. Attach Living Forge themes only to the state board and Play lobby so deferred screens do not receive an unreviewed partial reskin.
- Preserve the public `HUD/ClassSelection : ClassSelectionPanel` path and lifecycle methods in this slice. Replace the internals with the new full-screen composition and move run-HUD visibility ownership out of the selector into explicit Main/HUD code.
- Existing profile, recovery, loadout compatibility, transition, checkout, Armoury, and persistence services remain authoritative. UI objects emit intent and present results; they never author durable gameplay state.
- A stale or direct run-setup route must refresh the active profile and re-check resumable-run precedence before opening the lobby.
- Class focus or mouse hover changes preview only. Class activation changes ephemeral selection only. Only Start Run invokes `_select_leader_class()`.
- Compatibility is calculated for the selected class only and recalculated again by the existing start path. Do not batch-project every class.
- Do not add playstyle, party-fit, synergy, controller ownership, join, ready-up, split-screen, or camera behavior that production does not provide.
- Seats 2-4 are visible, non-focusable, non-interactive, and use the exact text `LOCAL CO-OP - COMING SOON`.
- P1's device label reflects the active prompt device only; it is not a durable controller assignment.
- Keep technical diagnostics in logs and expose concise player-readable failure text in the lobby.
- Every changed input path must have mouse, keyboard, and simulated-controller outcome parity. Physical-controller acceptance remains separately labelled until performed.
- Use unique `user://tests/...` profile/settings roots. Never run fixtures against `ProfileStore.DEFAULT_ROOT` or live user documents.
- Pixel capture requires a windowed OpenGL Compatibility run. Do not accept a dummy-renderer headless image as visual evidence.
- Automated geometry and screenshots are evidence, not human visual approval. Present the state board and final lobby captures to Jacob before promoting the slice as visually accepted.
- Keep `scripts/game/main.gd` edits confined to run-setup wiring, recovery guard, settings/Armoury return state, and related helpers. Do not refactor unrelated combat/runtime code.
- This repository tracks `.gd.uid` files. Run the Godot editor import after each task that creates scripts and commit every generated UID beside its script in that task; no orphan or late untracked UID may remain.

The starting tree also has tracked legacy scripts without tracked UID sidecars, so an editor import can generate unrelated untracked UIDs. In every active implementation-worktree task that runs editor import, declare the task's exact intended new UID paths and run this classifier immediately after import (re-declare it in a new shell). It preserves intended UIDs, removes only exact sidecars whose corresponding `.gd` was already tracked, rejects any other untracked UID, and never broadens deletion:

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
	$missingIntended = @($intendedUids | Where-Object { -not (Test-Path -LiteralPath (Join-Path $repoRoot $_)) })
	if ($missingIntended.Count -gt 0) { throw "Expected task UID was not generated: $($missingIntended -join ', ')" }
}
```

---

## Architecture Decision Record

The UI/UX and Godot reviewers evaluated both preserving `HUD/ClassSelection` and creating a standalone lobby. This plan preserves the public selector seam for the first slice because it materially reduces recovery, checkout, Settings, Armoury, and focus churn without limiting the approved full-screen composition. `ClassSelectionPanel` becomes a thin adapter; Main/HUD explicitly owns run-HUD visibility so the adapter no longer reaches sideways into `HUD/Margin`.

The hero stage extends `CharacterEquipmentPreview` with a distinct `show_class()` mode. The existing `show_member()` contract remains unchanged, class/member cache signatures cannot collide, and class mode retains the complete production default equipment already applied by `CharacterPresentation.apply_profile()`.

---

## File and Responsibility Map

### Accessibility settings

- `scripts/settings/party_forge_settings.gd`: durable `high_contrast`, bounded `ui_scale_percent`, and bounded `text_scale_percent` values.
- `scripts/settings/party_forge_settings_store.gd`: backward-compatible config load/save defaults.
- `scenes/ui/settings/game_settings_page.tscn`, `scripts/ui/settings/game_settings_page.gd`: player controls for all three settings.
- `tests/unit/test_party_forge_settings.gd`, `test_settings_screen.gd`: normalization, persistence, and page projection.

### Living Forge foundation

- `assets/ui/living_forge/fonts/`: pinned Cinzel 2.000 and Source Sans 3 3.052 font files plus their OFL texts.
- `assets/ui/living_forge/icons/tabler-3.46.0/`: the exact reviewed SVG subset and MIT licence.
- `assets/ui/living_forge/frames/`: project-owned forged frame and neutral class-silhouette SVGs.
- `docs/third_party/living-forge-ui-assets.md`: upstream version, source URL, licence, selected files, and SHA-256 inventory.
- `scripts/ui/living_forge/living_forge_tokens.gd`: semantic color, spacing, sizing, typography, and motion roles.
- `scripts/ui/living_forge/living_forge_theme_catalog.gd`: normal/high-contrast theme selection and cached text-scale variants.
- `data/ui/living_forge/living_forge_theme.tres`, `living_forge_high_contrast_theme.tres`: canonical first-slice Theme resources.
- `tests/unit/test_living_forge_theme.gd`: token completeness, contrast, type variations, fallback assets, and scale variants.

### First-slice components and state board

- `scripts/ui/living_forge/components/forge_class_card.gd`, matching scene: preview, selection, lock, selected, compatibility, and pending presentation.
- `scripts/ui/living_forge/components/forge_seat_card.gd`, matching scene: P1 active and future seat states.
- `scripts/ui/living_forge/components/forge_status_badge.gd`, matching scene: semantic state plus non-color copy/icon.
- `scripts/ui/living_forge/components/forge_action_bar.gd`, matching scene: bounded footer actions and focus graph.
- `scripts/ui/living_forge/components/forge_input_prompt.gd`, matching scene: active-device action presentation only.
- `scripts/ui/input/active_input_device.gd`: keyboard/mouse versus controller prompt mode without player assignment.
- `scenes/dev/living_forge_state_board.tscn`, `scripts/dev/living_forge_state_board.gd`: visual inventory of implemented states.
- `tests/unit/test_living_forge_components.gd`, `test_living_forge_state_board.gd`: state/accessibility/action contracts.
- `tests/integration/living_forge_state_board_runner.gd`: rendered state-board evidence.

### Play lobby model and view

- `scripts/ui/run_setup/run_setup_class_projection.gd`: copy-owned class identity, role, traits, starting action, selection, lock, and compatibility presentation.
- `scripts/ui/run_setup/run_setup_seat_projection.gd`: exact four-seat presentation contract.
- `scripts/ui/run_setup/run_setup_lobby_projection.gd`: complete screen state, selected/previewed IDs, errors, pending state, settings, and defensive copy.
- `scripts/ui/run_setup/run_setup_lobby_view_model.gd`: authoritative profile/catalog/compatibility-to-presentation translation.
- `scripts/ui/run_setup/run_setup_responsive_layout.gd`: desktop/compact/ultrawide layout decision and metrics.
- `scripts/ui/ledger/character_equipment_preview.gd`, matching scene: add isolated class presentation, neutral fallback, and bounded render lifecycle while retaining member mode.
- `scripts/ui/class_selection_panel.gd`, `scenes/ui/run_setup/run_setup_lobby_panel.tscn`: stable adapter plus full-screen lobby composition, focus, input, presentation, and intent signals.
- Focused unit tests for each model/view boundary.

### Composition and qualification

- `scenes/ui/hud.tscn`, `scripts/game/main.gd`: instance the new lobby composition at the stable selector path, perform authoritative refresh/projection, consume intents, own run-HUD visibility, and restore exact focus.
- Existing main/recovery/warning/profile/responsive tests: preserve outer `HUD/ClassSelection` assumptions while migrating only obsolete inner paths/one-click-start expectations.
- `tests/integration/play_lobby_input_runner.gd`: real mouse/keyboard/controller input, focus, child-screen returns, warning, and recovery precedence.
- `tests/integration/play_lobby_responsive_runner.gd`: five supported size classes and SubViewport geometry.
- `tests/integration/living_forge_visual_evidence_runner.gd`: fresh normal/high-contrast, hover/focus, pending, fallback, and responsive screenshots.
- `docs/verification/2026-08-28-living-forge-foundation-play-lobby.md`: exact final head, commands, markers, captures, deferred manual gates, and human approval status.

---

### Task 1: Repair the Retained Main-Menu Navigation Baseline

**Files:**

- Modify: `tests/integration/main_menu_navigation_runner.gd`
- Test: `tests/integration/main_menu_navigation_runner.gd`

**Interfaces:**

- Consumes the current production Profiles order `ProfileName -> PreferredColor -> Create`.
- Produces a green retained navigation runner before Play-lobby assertions are changed.

- [ ] **Step 1: Reproduce and record the stale baseline**

Run:

```powershell
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/integration/main_menu_navigation_runner.gd
```

Expected at `b211c8f`: a nonzero exit with four navigation assertions caused by the runner expecting Profile Name to jump directly to Create. Confirm there is no production parse/loader failure.

- [ ] **Step 2: Update the fixture to traverse the real color control**

Add the exact node and expectation:

```gdscript
var preferred_color := profiles.get_node("Layout/CreateRow/PreferredColor") as OptionButton

await _joy_button(viewport, JOY_BUTTON_DPAD_DOWN)
_assert_focus(viewport, preferred_color, "D-pad moves from profile name to Preferred Color")
await _joy_button(viewport, JOY_BUTTON_DPAD_DOWN)
_assert_focus(viewport, profile_create, "D-pad moves from Preferred Color to Create")
```

Do not bypass the control, directly assign focus, or weaken the subsequent profile-creation assertions.

- [ ] **Step 3: Run GREEN and commit the baseline repair**

Run the Step 1 command again. Expected: `MAIN_MENU_NAVIGATION_SUMMARY: PASS` and exit `0`.

```powershell
git add -- tests/integration/main_menu_navigation_runner.gd
git commit -m "test: repair profile navigation baseline"
```

---

### Task 2: Persist High Contrast, UI Scale, and Text Scale

**Files:**

- Modify: `scripts/settings/party_forge_settings.gd`
- Modify: `scripts/settings/party_forge_settings_store.gd`
- Modify: `scenes/ui/settings/game_settings_page.tscn`
- Modify: `scripts/ui/settings/game_settings_page.gd`
- Modify: `tests/unit/test_party_forge_settings.gd`
- Modify: `tests/unit/test_settings_screen.gd`

**Interfaces:**

- Produces `PartyForgeSettings.high_contrast: bool`, `ui_scale_percent: int`, and `text_scale_percent: int`.
- Valid UI/text scale values are `[80, 90, 100, 110, 125, 150]`; invalid values normalize to the nearest supported value, with ties choosing the larger value.
- UI scale changes component geometry/spacing only. Text scale changes typography only. The two values never multiply.
- Existing settings documents without these keys load as `false`, `100`, and `100`; keep settings schema version 1 with optional-key defaults so current files remain readable.

- [ ] **Step 1: Write RED normalization and copy tests**

Add assertions equivalent to:

```gdscript
var settings := PartyForgeSettings.new()
settings.high_contrast = true
settings.ui_scale_percent = 85
settings.text_scale_percent = 124
settings.normalize()
TestAssertions.equal(settings.ui_scale_percent, 90, "UI scale tie normalizes upward", failures)
TestAssertions.equal(settings.text_scale_percent, 125, "text scale normalizes to a supported value", failures)
var copied := settings.copy()
TestAssertions.truthy(copied.high_contrast, "copy preserves high contrast", failures)
TestAssertions.equal(copied.ui_scale_percent, 90, "copy preserves UI scale", failures)
TestAssertions.equal(copied.text_scale_percent, 125, "copy preserves text scale", failures)
```

Add lower/upper clamp coverage and explicit proof that the values remain independent.

- [ ] **Step 2: Write RED store and page tests**

Use a unique `user://tests/living_forge_settings/...cfg` path. Assert legacy config defaults, round-trip persistence, exact OptionButton values, and the existing `GameSettingsPage.bind(settings)`/`write_to(settings)` parity for High Contrast, UI Scale, and Text Scale. Extend Settings Apply/Cancel tests so Apply persists all three and Cancel persists none.

- [ ] **Step 3: Run RED**

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 420 --script res://tests/focused_test_runner.gd -- tests/unit/test_party_forge_settings.gd tests/unit/test_settings_screen.gd
```

Expected: `TEST_SUMMARY: FAIL` identifies missing fields, store keys, and page controls only.

- [ ] **Step 4: Implement settings, store defaults, and page controls**

Add:

```gdscript
const UI_SCALE_OPTIONS: Array[int] = [80, 90, 100, 110, 125, 150]
var high_contrast := false
var ui_scale_percent := 100
var text_scale_percent := 100
```

Normalize both scales via one deterministic nearest-option helper; copy all three values. Load `high_contrast` only from a bool and each scale only from an int, then normalize. Save all three keys. Add `HighContrast` CheckButton, `UIScale` OptionButton, and `TextScale` OptionButton to the Game page with accessible labels; preserve the existing Reduced Motion behavior. Main applies the saved values to the lobby in Task 8; deferred screens remain visually unchanged.

- [ ] **Step 5: Run GREEN and commit**

Run Step 3. Expected: exactly one `TEST_SUMMARY: PASS (0 failures)`.

```powershell
git add -- scripts/settings/party_forge_settings.gd scripts/settings/party_forge_settings_store.gd scenes/ui/settings/game_settings_page.tscn scripts/ui/settings/game_settings_page.gd tests/unit/test_party_forge_settings.gd tests/unit/test_settings_screen.gd
git commit -m "feat: persist Living Forge accessibility settings"
```

---

### Task 3: Import Licensed Assets and Build the Theme Contract

**Files:**

- Create: `assets/ui/living_forge/fonts/cinzel-2.000/Cinzel[wght].ttf`
- Create: `assets/ui/living_forge/fonts/cinzel-2.000/OFL.txt`
- Create: `assets/ui/living_forge/fonts/source-sans-3.052/SourceSans3VF-Upright.ttf`
- Create: `assets/ui/living_forge/fonts/source-sans-3.052/LICENSE.md`
- Create: `assets/ui/living_forge/fonts/noto-sans-2.014/NotoSans[wdth,wght].ttf`
- Create: `assets/ui/living_forge/fonts/noto-sans-2.014/OFL.txt`
- Create: `assets/ui/living_forge/fonts/noto-sans-symbols-2.008/NotoSansSymbols2-Regular.ttf`
- Create: `assets/ui/living_forge/fonts/noto-sans-symbols-2.008/OFL.txt`
- Create: selected SVGs and `LICENSE` under `assets/ui/living_forge/icons/tabler-3.46.0/`
- Create: `assets/ui/living_forge/frames/forge_panel.svg`
- Create: `assets/ui/living_forge/frames/class_silhouette.svg`
- Create: `docs/third_party/living-forge-ui-assets.md`
- Create: `scripts/ui/living_forge/living_forge_tokens.gd`
- Create: `scripts/ui/living_forge/living_forge_theme_catalog.gd`
- Create: `data/ui/living_forge/living_forge_theme.tres`
- Create: `data/ui/living_forge/living_forge_high_contrast_theme.tres`
- Create: `tests/unit/test_living_forge_theme.gd`

**Interfaces:**

- Display face: Cinzel SemiBold instance from Cinzel 2.000, major titles only.
- Body/control face: Source Sans 3 release 3.052, weights 400/500/600/700, with tabular numerals where supported.
- Interface icons: Tabler Icons `v3.46.0`, 24-pixel outline grid, selected subset only: `arrow-left`, `settings`, `shield`, `check`, `player-play`, `alert-triangle`, `lock`, `user`, `keyboard`, `device-gamepad`, and `hourglass`.
- Deterministic fallback chain: Cinzel -> Source Sans 3 -> Noto Sans 2.014 -> Noto Sans Symbols 2.008. Godot's system fallback is last-resort only, not accepted as required coverage. No Unicode symbol is used as an action icon.

- [ ] **Step 1: Write the RED theme and asset contract**

Test exact semantic roles:

```gdscript
const REQUIRED_COLORS: Array[StringName] = [
	&"surface_forged", &"surface_inset", &"ember_primary", &"focus_outline",
	&"text_primary", &"text_muted", &"valid", &"warning", &"error", &"disabled",
]
const REQUIRED_VARIATIONS: Array[StringName] = [
	&"LivingForgePanel", &"LivingForgeInsetPanel", &"LivingForgePrimaryButton",
	&"LivingForgeSecondaryButton", &"LivingForgeUnavailableButton",
	&"LivingForgeDestructiveButton", &"LivingForgeDisplayLabel",
	&"LivingForgeSectionLabel", &"LivingForgeCaptionLabel", &"LivingForgeStatusChip",
]
```

Assert normal text contrast is at least `4.5:1`, large text and focus/state boundaries at least `3:1`, every asset path and licence file exists, required Latin/extended/symbol sample strings resolve through the packaged fallback chain, both themes expose every variation, independent UI/text-scale variants retain the same semantic roles, and `motion_ms(role, true) == 0`.

- [ ] **Step 2: Run RED**

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 420 --script res://tests/focused_test_runner.gd -- tests/unit/test_living_forge_theme.gd
```

Expected: failure because the theme contract and assets do not exist; no unrelated loader error.

- [ ] **Step 3: Import exact upstream assets and record provenance**

Use these reviewed upstreams:

- Cinzel 2.000 from Google Fonts commit `45071f0` (`cinzel: v2.000 added`), including the `ofl/cinzel` OFL text: <https://github.com/google/fonts/commit/45071f0>.
- Source Sans 3 release `3.052R` and its OFL licence: <https://github.com/adobe-fonts/source-sans/releases/tag/3.052R>.
- Noto Sans release `NotoSans-v2.014` and its OFL licence: <https://github.com/notofonts/latin-greek-cyrillic/releases/tag/NotoSans-v2.014>.
- Noto Sans Symbols 2 release `NotoSansSymbols2-v2.008` and its OFL licence: <https://github.com/notofonts/symbols/releases/tag/NotoSansSymbols2-v2.008>.
- Tabler Icons release `v3.46.0` and MIT licence: <https://github.com/tabler/tabler-icons/releases/tag/v3.46.0>.

Do not use floating CDN URLs in project resources. Copy only the listed font files, SVG subset, and licence texts. Record upstream tag/version, retrieval date, original path, local path, and SHA-256 for every imported file in `docs/third_party/living-forge-ui-assets.md`.

- [ ] **Step 4: Author project-owned frame and silhouette assets**

Create original SVGs on a consistent 8-pixel geometry grid. `forge_panel.svg` supplies clipped corners, a restrained upper notch, and no baked text/state color. `class_silhouette.svg` is a neutral bust shape with no class-specific identity. Record both as Party Forge-owned assets in the provenance document.

- [ ] **Step 5: Implement tokens and theme selection**

`LivingForgeTokens` exposes only semantic APIs:

```gdscript
static func color(role: StringName, high_contrast := false) -> Color
static func spacing(role: StringName) -> int
static func control_size(role: StringName) -> Vector2
static func motion_ms(role: StringName, reduced_motion: bool) -> int
```

Use an 8-pixel base grid, 48x48 minimum action target, 120 ms focus motion, and 180 ms selection/modal motion. `LivingForgeThemeCatalog.resolve(high_contrast, ui_scale_percent, text_scale_percent)` returns a cached owned Theme variant, applies geometry and typography scales independently, and never mutates the base `.tres` resources.

- [ ] **Step 6: Run import and GREEN, then commit**

```powershell
& $godot --headless --editor --path (Get-Location).Path --quit-after 300
Resolve-GeneratedUidState @(
	'scripts/ui/living_forge/living_forge_tokens.gd.uid',
	'scripts/ui/living_forge/living_forge_theme_catalog.gd.uid',
	'tests/unit/test_living_forge_theme.gd.uid'
)
& $godot --headless --path (Get-Location).Path --quit-after 420 --script res://tests/focused_test_runner.gd -- tests/unit/test_living_forge_theme.gd
```

Expected: clean import exit and exactly one `TEST_SUMMARY: PASS (0 failures)`.

```powershell
git add -- assets/ui/living_forge data/ui/living_forge scripts/ui/living_forge/living_forge_tokens.gd scripts/ui/living_forge/living_forge_tokens.gd.uid scripts/ui/living_forge/living_forge_theme_catalog.gd scripts/ui/living_forge/living_forge_theme_catalog.gd.uid docs/third_party/living-forge-ui-assets.md tests/unit/test_living_forge_theme.gd tests/unit/test_living_forge_theme.gd.uid
git commit -m "feat: establish Living Forge theme contract"
```

---

### Task 4: Build First-Slice Components and the State Board

**Files:**

- Create: `scripts/ui/living_forge/components/forge_class_card.gd`
- Create: `scenes/ui/living_forge/components/forge_class_card.tscn`
- Create: `scripts/ui/living_forge/components/forge_seat_card.gd`
- Create: `scenes/ui/living_forge/components/forge_seat_card.tscn`
- Create: `scripts/ui/living_forge/components/forge_status_badge.gd`
- Create: `scenes/ui/living_forge/components/forge_status_badge.tscn`
- Create: `scripts/ui/living_forge/components/forge_action_bar.gd`
- Create: `scenes/ui/living_forge/components/forge_action_bar.tscn`
- Create: `scripts/ui/living_forge/components/forge_input_prompt.gd`
- Create: `scenes/ui/living_forge/components/forge_input_prompt.tscn`
- Create: `scripts/ui/input/active_input_device.gd`
- Create: `scenes/dev/living_forge_state_board.tscn`
- Create: `scripts/dev/living_forge_state_board.gd`
- Create: `tests/unit/test_living_forge_components.gd`
- Create: `tests/unit/test_living_forge_state_board.gd`
- Create: `tests/integration/living_forge_state_board_runner.gd`

**Interfaces:**

- `ForgeClassCard.present(data)`, `set_previewed(bool)`, `set_interaction_locked(bool)`; emits `preview_requested(class_id)` and `selection_requested(class_id)`.
- `ForgeSeatCard.present(data)`; unavailable seats never emit an action.
- `ForgeActionBar.present(actions)`; emits one `action_requested(action_id)` for enabled actions.
- `ForgeInputPrompt.present(action_id, device_kind, label)`; presentation only.
- `ActiveInputDevice.observe(event) -> bool` returns whether prompt mode changed and never assigns a player.

- [ ] **Step 1: Write RED component contracts**

Cover focused, previewed, selected, locked, compatible, needs-attention, pending, disabled, success, warning, and error states. Assert every state has an icon/shape/text cue in addition to color and has an accessibility description. Assert Seats 2-4 have `FOCUS_NONE`, ignore mouse input, contain exact Coming Soon copy, and expose no fake join signal.

- [ ] **Step 2: Write the RED state-board inventory**

Assert the scene instantiates every implemented state in normal and high-contrast modes from the same component tree. No visible enabled board control may emit an unconsumed action.

- [ ] **Step 3: Run RED**

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_living_forge_components.gd tests/unit/test_living_forge_state_board.gd
```

- [ ] **Step 4: Implement components without domain mutation**

Use Theme type variations for ordinary buttons/panels; custom scenes own only meaningful composition. Resolve input labels through `InputBindingFormatter.events_for_device` and the active-device tracker. Do not hard-code controller assignment or add unconsumed controls.

- [ ] **Step 5: Run unit GREEN and rendered state-board evidence**

```powershell
& $godot --headless --editor --path (Get-Location).Path --quit-after 300
Resolve-GeneratedUidState @(
	'scripts/ui/living_forge/components/forge_class_card.gd.uid',
	'scripts/ui/living_forge/components/forge_seat_card.gd.uid',
	'scripts/ui/living_forge/components/forge_status_badge.gd.uid',
	'scripts/ui/living_forge/components/forge_action_bar.gd.uid',
	'scripts/ui/living_forge/components/forge_input_prompt.gd.uid',
	'scripts/ui/input/active_input_device.gd.uid',
	'scripts/dev/living_forge_state_board.gd.uid',
	'tests/unit/test_living_forge_components.gd.uid',
	'tests/unit/test_living_forge_state_board.gd.uid',
	'tests/integration/living_forge_state_board_runner.gd.uid'
)
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_living_forge_components.gd tests/unit/test_living_forge_state_board.gd
& $godot --windowed --path (Get-Location).Path --rendering-method gl_compatibility --quit-after 900 --script res://tests/integration/living_forge_state_board_runner.gd -- --capture-evidence
```

Expected: editor/import exits `0` without parse/loader errors, followed by `TEST_SUMMARY: PASS (0 failures)` and `LIVING_FORGE_STATE_BOARD_SUMMARY: PASS`.

- [ ] **Step 6: UI/UX review checkpoint and commit**

Present the normal and high-contrast state-board captures to the UI/UX reviewer and Jacob. Correct theme/component defects before committing; record human status honestly if Jacob defers review. Any file change made from that review invalidates the prior evidence: rerun the editor import, focused suites, and rendered state-board capture in Step 5 before committing.

```powershell
git add -- scenes/ui/living_forge scripts/ui/living_forge/components scripts/ui/input/active_input_device.gd scripts/ui/input/active_input_device.gd.uid scenes/dev/living_forge_state_board.tscn scripts/dev/living_forge_state_board.gd scripts/dev/living_forge_state_board.gd.uid tests/unit/test_living_forge_components.gd tests/unit/test_living_forge_components.gd.uid tests/unit/test_living_forge_state_board.gd tests/unit/test_living_forge_state_board.gd.uid tests/integration/living_forge_state_board_runner.gd tests/integration/living_forge_state_board_runner.gd.uid docs/validation/screenshots/living-forge-foundation
git commit -m "feat: add Living Forge component foundation"
```

---

### Task 5: Define Copy-Owned Play Lobby Projections

**Files:**

- Create: `scripts/ui/run_setup/run_setup_class_projection.gd`
- Create: `scripts/ui/run_setup/run_setup_seat_projection.gd`
- Create: `scripts/ui/run_setup/run_setup_lobby_projection.gd`
- Create: `scripts/ui/run_setup/run_setup_lobby_view_model.gd`
- Create: `scripts/ui/run_setup/run_setup_responsive_layout.gd`
- Create: `tests/unit/test_run_setup_lobby_projection.gd`
- Create: `tests/unit/test_run_setup_lobby_view_model.gd`
- Create: `tests/unit/test_run_setup_responsive_layout.gd`

**Interfaces:**

- Lobby states: `NO_SELECTION`, `CHECKING`, `READY`, `NEEDS_ATTENTION`, `UNAVAILABLE`, `STARTING`, `ERROR`. Preview is orthogonal presentation state carried by `previewed_class_id`; focusing class B must never erase class A's selected readiness.
- Seat states reserve `ACTIVE`, `COMING_SOON`, `JOINED`, `SELECTING`, `READY`, `DISCONNECTED`; this slice builds only `ACTIVE` and `COMING_SOON`.
- Projections contain value data only: IDs, strings, colors, arrays, enums, booleans, and safe error copy. They do not retain mutable `ProfileState`, `ClassDefinition`, or service references.

- [ ] **Step 1: Write RED projection-copy tests**

Mutate every returned array/nested dictionary and assert the source remains unchanged. Assert exactly four seats, only P1 focusable/active, and selected/previewed IDs are independent.

- [ ] **Step 2: Write RED view-model truth tests**

Use the real `GameCatalog`, a valid completed `ProfileState`, and real `LoadoutCompatibilityProjection` values. Assert class name, role, trait display names via `GameCatalog.trait_by_id`, and a starting-action label produced by the existing humanized `primary_attack.id` convention because `AttackDefinition` has no authored display-name field. Assert compatibility appears only on the selected class. Assert no playstyle, party-fit, or synergy fields exist.

- [ ] **Step 3: Write RED safe-failure and responsive tests**

No profile, malformed profile, missing class, invalid compatibility, and damaged inputs must produce a stable unavailable/error projection with safe copy. Layout policy is desktop only when width is at least 1600 and height at least 900; otherwise compact. Ultrawide content width is bounded to 1920 logical pixels.

- [ ] **Step 4: Run RED**

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_run_setup_lobby_projection.gd tests/unit/test_run_setup_lobby_view_model.gd tests/unit/test_run_setup_responsive_layout.gd
```

- [ ] **Step 5: Implement value projections and view model**

Build selected-class compatibility states as:

```gdscript
if compatibility == null:
	state = RunSetupClassProjection.Compatibility.UNKNOWN
elif not compatibility.valid:
	state = RunSetupClassProjection.Compatibility.UNAVAILABLE
elif compatibility.incompatible_items.is_empty():
	state = RunSetupClassProjection.Compatibility.COMPATIBLE
else:
	state = RunSetupClassProjection.Compatibility.NEEDS_ATTENTION
```

Do not place technical `compatibility.error` in a UI projection. Main owns the authoritative compatibility object, logs its technical error before projection, and passes only safe player-facing copy to the view model.

- [ ] **Step 6: Run GREEN and commit**

Run a required editor import, then Step 4:

```powershell
& $godot --headless --editor --path (Get-Location).Path --quit-after 300
Resolve-GeneratedUidState @(
	'scripts/ui/run_setup/run_setup_class_projection.gd.uid',
	'scripts/ui/run_setup/run_setup_seat_projection.gd.uid',
	'scripts/ui/run_setup/run_setup_lobby_projection.gd.uid',
	'scripts/ui/run_setup/run_setup_lobby_view_model.gd.uid',
	'scripts/ui/run_setup/run_setup_responsive_layout.gd.uid',
	'tests/unit/test_run_setup_lobby_projection.gd.uid',
	'tests/unit/test_run_setup_lobby_view_model.gd.uid',
	'tests/unit/test_run_setup_responsive_layout.gd.uid'
)
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_run_setup_lobby_projection.gd tests/unit/test_run_setup_lobby_view_model.gd tests/unit/test_run_setup_responsive_layout.gd
```

Expected: editor/import exits `0` without parse/loader errors and exactly one `TEST_SUMMARY: PASS (0 failures)`.

```powershell
git add -- scripts/ui/run_setup tests/unit/test_run_setup_lobby_projection.gd tests/unit/test_run_setup_lobby_projection.gd.uid tests/unit/test_run_setup_lobby_view_model.gd tests/unit/test_run_setup_lobby_view_model.gd.uid tests/unit/test_run_setup_responsive_layout.gd tests/unit/test_run_setup_responsive_layout.gd.uid
git commit -m "feat: define Play lobby presentation model"
```

---

### Task 6: Add an Isolated Class Mode to the Shared Character Preview

**Files:**

- Modify: `scenes/ui/ledger/character_equipment_preview.tscn`
- Modify: `scripts/ui/ledger/character_equipment_preview.gd`
- Modify: `tests/unit/test_character_equipment_preview.gd`

**Interfaces:**

- Existing `show_member(member, equipment_rows) -> bool` remains behaviorally unchanged.
- Add `show_class(definition: ClassDefinition) -> bool`.
- Add `show_fallback(class_id: StringName, safe_reason: String) -> void`.
- `clear() -> void`
- Preserve the existing `diagnostics: PackedStringArray` property and its tested access. Do not add a conflicting `diagnostics()` method; if a defensive accessor is later needed, name it `diagnostics_copy()`.
- `set_reduced_motion(enabled: bool) -> void`

- [ ] **Step 1: Write RED member-regression, class-success, and fallback tests**

Retain all existing `show_member()` assertions. Instantiate the real Fighter definition and assert `show_class()` loads its production `CharacterPresentation` with complete default equipment and the correct class color. Use a fresh `ClassDefinition` plus independently constructed invalid `CharacterVisualProfile` for failure coverage; never mutate or shallow-copy the cached Fighter resource graph. Assert the neutral silhouette plus unavailable-detail copy appears and no other class presentation is substituted.

- [ ] **Step 2: Write RED lifecycle tests**

Assert class/member signatures cannot collide; switching modes cannot leak explicit member equipment into class defaults. SubViewport updates are enabled only while visible and valid, repeated presentation of the same signature reuses the active presentation, class change replaces it, reduced motion avoids ornamental transitions, and `clear()` removes the model and disables rendering.

- [ ] **Step 3: Run RED**

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_character_equipment_preview.gd
```

- [ ] **Step 4: Implement a distinct class-preview signature**

Use the preview's existing `CharacterPresentation` instance path and call `CharacterPresentation.apply_profile(definition.visual_profile, definition.color)`. In class mode do not call the explicit equipment-row refresh that belongs to member mode; `apply_profile()` already applies the class profile's production defaults. Do not copy model-building, equipment application, lighting, caching, or animation validation logic.

- [ ] **Step 5: Run GREEN and commit**

Run Step 3. Expected: `TEST_SUMMARY: PASS (0 failures)`.

```powershell
git add -- scenes/ui/ledger/character_equipment_preview.tscn scripts/ui/ledger/character_equipment_preview.gd tests/unit/test_character_equipment_preview.gd
git commit -m "feat: add class mode to character preview"
```

---

### Task 7: Rebuild the Stable Selector Seam as a Full-Screen Lobby

**Files:**

- Create: `scenes/ui/run_setup/run_setup_lobby_panel.tscn`
- Modify: `scripts/ui/class_selection_panel.gd`
- Modify: `scenes/ui/hud.tscn`
- Modify: `tests/unit/test_class_selection_panel.gd`
- Modify: `tests/unit/test_responsive_ui.gd`

**Interfaces:**

- Signals: `class_preview_requested(class_id)`, `class_selection_requested(class_id)`, `start_requested(class_id)`, `settings_requested`, `armoury_requested(class_id)`, `back_requested`.
- Preserve methods: `open(preferred_focus = null)`, `close()`, `is_open()`, `selection_focus(class_id)`, `begin_compatibility_gate(class_id, origin = null)`, `end_compatibility_gate(restore_focus = true)`, `show_status(text)`, `clear_status()`.
- Add/adjust methods: `configure(catalog)`, `present(projection)`, `selected_class_id()`, `previewed_class_id()`, `action_focus(action_id)`, `set_pending(state, origin)`.

- [ ] **Step 1: Write the RED scene/lifecycle contract**

Assert the stable root remains `HUD/ClassSelection : ClassSelectionPanel`, instances the full-screen lobby panel, owns an opaque Backdrop/Header/Seats/ClassRoster/HeroStage/Details/ActionBar/Status composition, attaches the chosen theme, takes a defensive projection copy, and disables the shared preview SubViewport on close. Assert the selector no longer reaches sideways into `HUD/Margin`.

- [ ] **Step 2: Write RED preview/select/start tests**

Mouse hover and focus emit preview without selection. Class activation emits selection only. Start emits separately with the exact selected class. Unknown compatibility, no selection, Checking, Unavailable, Starting, and Error disable Start. Needs Attention enables Start so the existing warning path can explain the consequence. Explicitly test select A -> focus/preview B -> Start A: class A remains selected, readiness remains derived from A, and Start emits A.

- [ ] **Step 3: Write RED focus and pending tests**

Initial focus is the retained selected class or, with no selection, the first selectable preview card. Tab order is class cards, Back, Settings, Armoury, Select, Start. Directional movement follows the visible two- or three-column grid. Seats 2-4 are unreachable. Starting rejects duplicate activation and retains initiating focus. Failure restores a stable state and the Start/class origin.

Use this complete action matrix:

| State | Class focus/preview | Select | Back/Settings | Armoury | Start |
| --- | --- | --- | --- | --- | --- |
| `NO_SELECTION` | Enabled | Enabled for focused selectable class | Enabled | Enabled when authoritative route is available | Disabled |
| `CHECKING` | Focus retained; selection changes blocked | Disabled | Back enabled; Settings/Armoury disabled until check terminates | Disabled | Disabled |
| `READY` | Enabled | Enabled | Enabled | Enabled when available | Enabled |
| `NEEDS_ATTENTION` | Enabled | Enabled | Enabled | Enabled when available | Enabled; opens existing warning path |
| `UNAVAILABLE` / unknown compatibility | Enabled for explanation/alternate selection | Enabled only for another selectable class | Enabled | Enabled only if it can resolve the issue | Disabled |
| `STARTING` | Focus retained; navigation blocked | Disabled | Disabled unless the authority exposes safe cancellation | Disabled | Disabled; duplicate activation rejected |
| `ERROR` | Enabled | Enabled | Enabled | Enabled when available | Disabled until a new valid projection |

Prompt-mode changes never alter this matrix. Cancellation is exposed only where the underlying authoritative operation supports it.

Preview is not an exclusive row in this matrix. While `READY` or `NEEDS_ATTENTION` is derived from selected class A, focusing class B updates only the preview/details/hero presentation; selection styling, compatibility, and Start continue to target A until B is explicitly selected.

- [ ] **Step 4: Run RED**

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_class_selection_panel.gd tests/unit/test_responsive_ui.gd
```

- [ ] **Step 5: Implement responsive desktop and compact compositions**

Replace the inline selector block in `hud.tscn` with an instance of `run_setup_lobby_panel.tscn` named `ClassSelection`; preserve the outer path and adapter class. Desktop uses a bounded three-column composition with 2x2 seats above a three-column roster. Compact uses a horizontal four-seat strip, two-column scrollable roster, reduced hero stage, scrollable details, and fixed footer. At 4K the logical information density remains unchanged. Apply the theme chosen from the projection's accessibility settings.

- [ ] **Step 6: Run GREEN and commit**

Run Step 4. Expected: `TEST_SUMMARY: PASS (0 failures)`.

```powershell
git add -- scenes/ui/run_setup/run_setup_lobby_panel.tscn scripts/ui/class_selection_panel.gd scenes/ui/hud.tscn tests/unit/test_class_selection_panel.gd tests/unit/test_responsive_ui.gd
git commit -m "feat: build future-ready Play lobby"
```

---

### Task 8: Cut Main Over to the Lobby and Preserve Authority

**Files:**

- Modify: `scripts/game/main.gd`
- Modify: `tests/unit/test_main_wiring.gd`
- Modify: `tests/unit/test_main_loadout_checkout_recovery.gd`
- Modify: `tests/unit/test_developer_quick_start.gd`
- Modify: `tests/unit/test_profile_boot_integration.gd`
- Modify: `tests/unit/test_leader_movement.gd`
- Modify: `tests/unit/test_five_class_integration.gd`
- Modify: `tests/integration/main_menu_navigation_runner.gd`
- Modify: `tests/integration/profile_boot_main_flow_runner.gd`
- Modify: `tests/integration/responsive_ui_geometry_runner.gd`
- Modify: `tests/integration/run_recovery_profile_lifecycle_runner.gd`

**Interfaces:**

- Add `_run_setup_lobby() -> ClassSelectionPanel` as the only production selector lookup; it resolves the preserved `HUD/ClassSelection` seam.
- Add `_selected_lobby_class_id`, `_previewed_lobby_class_id`, and one enum-backed return context covering `MAIN_MENU`, `RUN_SETUP`, `LOADOUT_WARNING`, and `DEVELOPER_QUICK_START`.
- No second Armoury boolean or competing focus field is allowed.

- [ ] **Step 1: Write RED Main wiring assertions before scene cutover**

Require the full-screen lobby at the stable `HUD/ClassSelection` path, every signal consumer, and one typed accessor rather than scattered path lookups. Assert Developer Quick Start still enters the existing authority path directly.

- [ ] **Step 2: Write RED flow and return-focus assertions**

Cover no-profile bypass to Profiles, recovery precedence, valid lobby entry, selected-class-only compatibility, warning Cancel to Start, Choose Another Class to selected card, direct Armoury return to Armoury action, warning-to-Armoury return to selected card, Settings return to Settings, failed start return, and successful start clearing all front-end focus.

- [ ] **Step 3: Run RED focused matrix**

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 900 --script res://tests/focused_test_runner.gd -- tests/unit/test_main_wiring.gd tests/unit/test_main_loadout_checkout_recovery.gd tests/unit/test_developer_quick_start.gd tests/unit/test_profile_boot_integration.gd tests/unit/test_responsive_ui.gd tests/unit/test_leader_movement.gd tests/unit/test_five_class_integration.gd
```

- [ ] **Step 4: Wire the new selection and Start contracts**

Add the typed accessor, signals, selected/previewed state, profile refresh, recovery guard, and projection helper. A valid persisted `profile.leader_loadout_class_id` may initialize selection. Otherwise initialize focus/preview to Fighter if available, then the first selectable catalog class, but leave `selected_class_id` empty and Start disabled until explicit class confirmation. Lobby selection is not persisted.

`_on_lobby_start_requested(class_id)` must reject mismatched/empty/pending IDs, present Starting, then call the existing `_select_leader_class(class_id, LoadoutOrigin.RUN_SETUP)`. The existing profile refresh and compatibility re-projection remain the final gate.

- [ ] **Step 5: Consolidate Settings/Armoury return state**

Replace the run-setup-related boolean combination with one enum and one exact return Control/class identity. Settings remains visible and focusable beneath the existing opaque layer-10 Settings screen so its current close/apply/cancel behavior can restore the initiating lobby control; `_on_settings_applied` re-presents theme and independent scales before Settings closes. Armoury may close and reopen the lobby because Main consumes its close request. In both cases, store the initiating control and restore it if valid, otherwise use the deterministic action/class fallback.

- [ ] **Step 6: Migrate obsolete one-click and inner-path assumptions**

Run:

```powershell
rg -n 'HUD/ClassSelection/.+|(?:selector|run_setup)\.get_node\("Content/|class_selected\.connect\(select_leader_class\)' scenes scripts tests
```

Migrate every obsolete inner path and direct class-to-start connection to adapter accessors and separate selection/start intents. This step must update `main_menu_navigation_runner.gd`, `profile_boot_main_flow_runner.gd`, `responsive_ui_geometry_runner.gd`, and `run_recovery_profile_lifecycle_runner.gd` before Step 7 runs. Preserve the public selector path, script/UID, lifecycle tests, and focused regression suite. Do not leave dead hidden controls. Exit `1` means no obsolete matches; exit greater than `1` is a scan failure.

- [ ] **Step 7: Run GREEN focused and retained flow gates**

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 900 --script res://tests/focused_test_runner.gd -- tests/unit/test_main_wiring.gd tests/unit/test_main_loadout_checkout_recovery.gd tests/unit/test_developer_quick_start.gd tests/unit/test_profile_boot_integration.gd tests/unit/test_responsive_ui.gd tests/unit/test_leader_movement.gd tests/unit/test_five_class_integration.gd
& $godot --headless --path (Get-Location).Path --quit-after 1200 --script res://tests/integration/main_menu_navigation_runner.gd
& $godot --headless --path (Get-Location).Path --quit-after 900 --script res://tests/integration/profile_boot_main_flow_runner.gd
& $godot --headless --path (Get-Location).Path --quit-after 1200 --script res://tests/integration/run_recovery_profile_lifecycle_runner.gd
& $godot --headless --path (Get-Location).Path --quit-after 1200 --script res://tests/integration/responsive_ui_geometry_runner.gd
& $godot --headless --path (Get-Location).Path --script res://tests/integration/loadout_warning_input_runner.gd
```

Expected: focused `TEST_SUMMARY: PASS (0 failures)`, `MAIN_MENU_NAVIGATION_SUMMARY: PASS`, `PROFILE_BOOT_MAIN_FLOW_SUMMARY: PASS`, `RUN_RECOVERY_PROFILE_LIFECYCLE: PASS`, `RESPONSIVE_GEOMETRY_SUMMARY: PASS (4 sizes)` unless that runner deliberately expands its list, and exact terminal marker `TASK10_LOADOUT_WARNING_INPUT_SUMMARY: PASS (0 failures)`. Do not accept the earlier responsive marker or process exit alone as loadout-input completion.

- [ ] **Step 8: Commit the atomic cutover**

```powershell
git add -- scripts/game/main.gd tests/unit/test_main_wiring.gd tests/unit/test_main_loadout_checkout_recovery.gd tests/unit/test_developer_quick_start.gd tests/unit/test_profile_boot_integration.gd tests/unit/test_leader_movement.gd tests/unit/test_five_class_integration.gd tests/integration/main_menu_navigation_runner.gd tests/integration/profile_boot_main_flow_runner.gd tests/integration/responsive_ui_geometry_runner.gd tests/integration/run_recovery_profile_lifecycle_runner.gd
git commit -m "feat: route run setup through Play lobby"
```

---

### Task 9: Prove Input, Responsiveness, Recovery, and Visual Quality

**Files:**

- Create: `tests/integration/play_lobby_input_runner.gd`
- Create: `tests/integration/play_lobby_responsive_runner.gd`
- Create: `tests/integration/living_forge_visual_evidence_runner.gd`
- Modify: `tests/integration/main_menu_navigation_runner.gd`
- Modify: `tests/integration/profile_boot_main_flow_runner.gd`
- Modify: `tests/integration/responsive_ui_geometry_runner.gd`
- Modify: `tests/integration/run_recovery_profile_lifecycle_runner.gd`
- Test: `tests/integration/settings_profiles_navigation_runner.gd`
- Create: screenshots under `docs/validation/screenshots/living-forge-foundation/`
- Create: `docs/verification/2026-08-28-living-forge-foundation-play-lobby.md`

**Interfaces:**

- Required input marker: `PLAY_LOBBY_INPUT_SUMMARY: PASS`.
- Required responsive marker: `PLAY_LOBBY_RESPONSIVE_SUMMARY: PASS (5 sizes)`.
- Required evidence marker: `LIVING_FORGE_VISUAL_EVIDENCE_SUMMARY: PASS`.

- [ ] **Step 1: Write the real-input runner**

Add the production Main scene to a real SceneTree. Dispatch real viewport mouse motion/clicks, keyboard events, and simulated controller buttons/axes. Prove preview/select/start separation, closed focus graph, prompt switching without focus theft, exact Settings/Armoury return, duplicate-start rejection, warning flow, recovery precedence, and no hidden/disabled focus owner. Do not call `_ready()` or other lifecycle callbacks directly.

- [ ] **Step 2: Write the five-size geometry runner**

Exercise `1280x720`, `1920x1080`, `2560x1440`, `3440x1440`, and `3840x2160`. Assert compact/desktop modes, bounded ultrawide content, fixed footer, visible selected class/profile/compatibility/Start, 48x48 minimum actions, and no extra 4K information density. Include live hero success and forced fallback. At both 1280x720 and 1920x1080, test every text scale with UI scale 100, every UI scale with text scale 100, plus corner pairs `(80,150)`, `(150,80)`, and `(150,150)`. Assert containment, scrolling reachability, fixed-footer visibility, and closed focus for every pair; never multiply the two values.

- [ ] **Step 3: Update retained integration paths without weakening them**

Replace obsolete selector inner paths and one-click-start expectations with stable adapter accessors plus preview/select/start behavior. Preserve recovery, checkout, warning, profile, and focus assertions. The repaired profile color navigation from Task 1 remains covered.

- [ ] **Step 4: Run integration GREEN**

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 1200 --script res://tests/integration/play_lobby_input_runner.gd
& $godot --headless --path (Get-Location).Path --quit-after 1200 --script res://tests/integration/play_lobby_responsive_runner.gd
& $godot --headless --path (Get-Location).Path --quit-after 1200 --script res://tests/integration/main_menu_navigation_runner.gd
& $godot --headless --path (Get-Location).Path --quit-after 1200 --script res://tests/integration/profile_boot_main_flow_runner.gd
& $godot --headless --path (Get-Location).Path --quit-after 1200 --script res://tests/integration/run_recovery_profile_lifecycle_runner.gd
& $godot --headless --path (Get-Location).Path --quit-after 1200 --script res://tests/integration/responsive_ui_geometry_runner.gd
& $godot --headless --path (Get-Location).Path --quit-after 1200 --script res://tests/integration/settings_profiles_navigation_runner.gd
& $godot --headless --path (Get-Location).Path --script res://tests/integration/loadout_warning_input_runner.gd
```

Expected exactly once: `PLAY_LOBBY_INPUT_SUMMARY: PASS`, `PLAY_LOBBY_ACTION_CONSUMERS: PASS`, `PLAY_LOBBY_RESPONSIVE_SUMMARY: PASS (5 sizes)`, `MAIN_MENU_NAVIGATION_SUMMARY: PASS`, `PROFILE_BOOT_MAIN_FLOW_SUMMARY: PASS`, `RUN_RECOVERY_PROFILE_LIFECYCLE: PASS`, `RESPONSIVE_GEOMETRY_SUMMARY: PASS (4 sizes)` unless that retained runner deliberately expands its size list, `SETTINGS_PROFILES_NAVIGATION_SUMMARY: PASS`, and terminal `TASK10_LOADOUT_WARNING_INPUT_SUMMARY: PASS (0 failures)`.

- [ ] **Step 5: Capture fresh player-facing evidence**

The evidence runner captures: state board normal/high contrast; the Settings page with High Contrast, UI Scale, and Text Scale controls visible; a high-contrast Play lobby; P1 plus three Coming Soon seats; select-A/preview-B distinction; compatible; needs attention; Starting; safe error; Settings return; direct and warning Armoury returns; keyboard/mouse prompts; controller focus/prompts; live hero; missing-presentation fallback; reduced motion; 720p, 1080p, ultrawide, and 4K. Include 1280x720 at `(ui=100,text=150)` and the two 150% corner combinations so scaled-text reflow receives human review.

```powershell
& $godot --windowed --path (Get-Location).Path --rendering-method gl_compatibility --quit-after 1800 --script res://tests/integration/living_forge_visual_evidence_runner.gd -- --capture-evidence
```

- [ ] **Step 6: Run retained responsive, parser/import, and full-suite gates**

```powershell
& $godot --windowed --path (Get-Location).Path --rendering-method gl_compatibility --quit-after 1800 --script res://tests/integration/main_menu_responsive_runner.gd
& $godot --headless --editor --path (Get-Location).Path --quit-after 300
Resolve-GeneratedUidState @(
	'tests/integration/play_lobby_input_runner.gd.uid',
	'tests/integration/play_lobby_responsive_runner.gd.uid',
	'tests/integration/living_forge_visual_evidence_runner.gd.uid'
)
& $godot --headless --path (Get-Location).Path --quit-after 3000 --script res://tests/test_runner.gd
```

Expected: the responsive summary passes, editor/import exits `0` without parse/loader errors, and the full suite prints `TEST_SUMMARY: PASS (<freshly discovered suite count> suites)`. Record the discovered count; do not hard-code the pre-plan count of 222.

- [ ] **Step 7: Prove a cold-cache import from committed source**

After Tasks 1-8 are committed, create an exact temporary detached worktree from `HEAD`, verify its resolved path is beneath the system temporary directory, and run a fresh editor import plus the theme, component, selector, and shared-preview suites there. The temporary checkout must begin without `.godot/`.

```powershell
$coldRoot = Join-Path ([IO.Path]::GetTempPath()) ("party-forge-living-forge-cold-{0}-{1}" -f $PID, [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds())
$tempResolved = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$coldResolved = [IO.Path]::GetFullPath($coldRoot)
if (-not $coldResolved.StartsWith($tempResolved, [StringComparison]::OrdinalIgnoreCase)) { throw "Cold worktree escaped the temporary directory: $coldResolved" }
git worktree add --detach $coldRoot HEAD
& $godot --headless --editor --path $coldRoot --quit-after 600
& $godot --headless --path $coldRoot --quit-after 900 --script res://tests/focused_test_runner.gd -- tests/unit/test_living_forge_theme.gd tests/unit/test_living_forge_components.gd tests/unit/test_class_selection_panel.gd tests/unit/test_character_equipment_preview.gd
$coldStatus = @(git -C $coldRoot status --short)
$unexpected = @($coldStatus | Where-Object { $_ -notmatch '^\?\? .+\.gd\.uid$' })
if ($unexpected.Count -gt 0) { throw "Unexpected cold-worktree changes: $($unexpected -join ', ')" }
foreach ($entry in $coldStatus) {
	$relativeUid = $entry.Substring(3)
	$uidResolved = [IO.Path]::GetFullPath((Join-Path $coldRoot $relativeUid))
	if (-not $uidResolved.StartsWith($coldResolved + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or -not $uidResolved.EndsWith('.gd.uid', [StringComparison]::OrdinalIgnoreCase)) { throw "Unsafe generated UID path: $uidResolved" }
	Remove-Item -LiteralPath $uidResolved
}
if (@(git -C $coldRoot status --short).Count -ne 0) { throw "Cold worktree remained dirty after exact UID cleanup" }
git worktree remove $coldRoot
```

Expected: clean import, `TEST_SUMMARY: PASS (0 failures)`, no changes except generated untracked `.gd.uid` artifacts, exact validated removal of only those artifacts, and successful removal of only the exact validated temporary worktree. If validation or cleanup fails, report the retained path instead of broadening deletion.

- [ ] **Step 8: Run hygiene and action-consumer gates**

```powershell
rg -n -i 'TO[D]O|TB[D]|FI[X]ME|X[X]X|PLACEH[O]LDER|implement lat[e]r|fill in detai[l]s' assets/ui/living_forge data/ui/living_forge scenes/ui/run_setup scenes/ui/living_forge scripts/ui/run_setup scripts/ui/living_forge
rg -n -i 'TO[D]O|TB[D]|FI[X]ME|X[X]X|PLACEH[O]LDER|implement lat[e]r|fill in detai[l]s' tests/unit tests/integration --glob 'test_living_forge_*' --glob 'test_run_setup_*' --glob 'play_lobby_*' --glob 'living_forge_*'
rg -n 'HUD/ClassSelection/.+|(?:selector|run_setup)\.get_node\("Content/|class_selected\.connect\(select_leader_class\)' scenes scripts tests
git diff --check
git status --short
```

For each `rg`, exit `1` means clean no hits; exit greater than `1` is a scan failure and must not be accepted. Also require `PLAY_LOBBY_ACTION_CONSUMERS: PASS` from the input runner: every visible enabled class/footer action maps to a consumed lobby intent, and `test_main_wiring.gd` proves every lobby intent is connected in composed Main. Expected final state: no hygiene/obsolete-inner-path hits, clean diff check, and only intended files changed.

- [ ] **Step 9: UI/UX review, Jacob screenshot review, and verification record**

Have the UI/UX subagent review the state board and final capture set against the approved spec. Show the captures in chat because Jacob is remote. Record automated status, UI/UX review, Jacob's visual decision, and physical-controller status separately. Do not label deferred human or physical-controller work as passed. Any code, scene, asset, or test change made from either review invalidates prior evidence; rerun every affected focused, integration, rendered-capture, import, and full-suite gate before committing.

- [ ] **Step 10: Commit qualification evidence**

```powershell
git add -- tests/integration/play_lobby_input_runner.gd tests/integration/play_lobby_input_runner.gd.uid tests/integration/play_lobby_responsive_runner.gd tests/integration/play_lobby_responsive_runner.gd.uid tests/integration/living_forge_visual_evidence_runner.gd tests/integration/living_forge_visual_evidence_runner.gd.uid tests/integration/main_menu_navigation_runner.gd tests/integration/profile_boot_main_flow_runner.gd tests/integration/responsive_ui_geometry_runner.gd tests/integration/run_recovery_profile_lifecycle_runner.gd docs/validation/screenshots/living-forge-foundation docs/verification/2026-08-28-living-forge-foundation-play-lobby.md
git commit -m "test: qualify Living Forge Play lobby"
```

---

## Final Slice Acceptance Gate

The first slice is complete only when all of the following are true:

- The exact final implementation head is recorded.
- Normal and high-contrast theme contracts pass contrast and state tests.
- High Contrast, UI Scale, and Text Scale persist independently, and the lobby passes every supported scale plus the required cross-scale corner pairs.
- P1 preview/select/start is functional; Seats 2-4 are visible, honest, non-focusable Coming Soon states.
- Recovery precedence, loadout warning, Settings, Armoury, checkout, failure, and exact focus restoration remain green.
- Mouse, keyboard, and simulated-controller outcomes match.
- The five-size responsive runner passes.
- The complete discovered unit suite and retained integration runners pass on the exact final head.
- The UI/UX reviewer finds no open spec defect.
- Jacob has received fresh screenshots and his visual decision is recorded.
- Physical-controller status is reported as `PASS`, `FAIL`, or `DEFERRED`, never inferred from simulation.
- No global theme setting or deferred-screen reskin entered the diff.
- HUD/results, equipment, Warehouse, remaining screens, and final cross-screen qualification remain separate future plans under the approved master design.
