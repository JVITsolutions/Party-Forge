# Level-Up Presentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Present five readable upgrade cards with exact class-rank text, a gold pending-level count, and a synchronized skippable slot-reel reveal with reduced-motion support.

**Architecture:** A foundational presentation service reads progression data instead of embedding values in UI. `LevelUpRevealController` owns only visual state and receives preselected outcomes. `LevelUpPanel` dynamically binds the configured number of card controls, gates input during reveal, and continues using the existing tooltip/recipient/confirmation flows.

**Tech Stack:** Godot 4.7.1 Mono, typed GDScript, Control containers, Animation/Tween-compatible process logic, InputMap, custom headless and geometry tests.

## Global Constraints

- Execute after Plans 01–03 pass.
- Production offers display five cards in one row.
- Final choices are generated before reveal begins and never changed by preview cycling.
- Reveal duration target is 1.1 seconds.
- Fast-forward resolves immediately and does not activate a card.
- Reduced motion resolves without descent/reel movement.
- Full details remain available through the existing Alt/pin temporary popup behavior.
- Class-rank values come from `ClassDefinition.class_rank_power_step`.
- Rarity mechanics, rarity lighting, and rarity audio remain outside this plan.

---

### Task 1: Exact Foundational Upgrade Presentation

**Files:**
- Create: `scripts/progression/foundational_upgrade_presentation_service.gd`
- Modify: `scripts/ui/level_up_panel.gd:113-140,276-304`
- Create: `tests/unit/test_foundational_upgrade_presentation.gd`

**Interfaces:**
- Produces: `FoundationalUpgradePresentationService.card(choice: UpgradeChoice, party: PartyManager, catalog: GameCatalog) -> Dictionary`.
- Produces: `FoundationalUpgradePresentationService.tooltip(choice: UpgradeChoice, party: PartyManager, catalog: GameCatalog) -> Dictionary`.

- [ ] **Step 1: Write failing class-rank presentation tests**

Create a Fighter party at class rank 1 and assert the offered Fighter rank card returns:

```gdscript
TestAssertions.equal(card.rank_text, "Rank 1 -> 2", "class rank shows transition", failures)
TestAssertions.truthy("0%" in card.summary and "20%" in card.summary, "class rank shows exact damage change", failures)
TestAssertions.truthy("current and future Fighters" in card.inheritance_text, "class rank explains inheritance", failures)
TestAssertions.truthy("all current Fighters" in card.recipient_text, "class rank explains current ownership", failures)
```

Rank up once and assert the next card reads `Rank 2 -> 3` and `20% -> 40%`. Change a fixture definition's `class_rank_power_step` to `0.15` and assert text becomes `15% -> 30%`, proving the UI does not hardcode 20.

- [ ] **Step 2: Implement the presentation service**

For `CLASS_RANK`, resolve class definition and compute:

```gdscript
var current_rank := party.get_class_rank(choice.target_id)
var next_rank := current_rank + 1
var step := definition.class_rank_power_step
var current_percent := roundi(float(maxi(current_rank - 1, 0)) * step * 100.0)
var next_percent := roundi(float(maxi(next_rank - 1, 0)) * step * 100.0)
var plural := "%ss" % definition.display_name
```

Return this card dictionary:

```gdscript
return {
	"name": "Train %s" % definition.display_name,
	"scope_badge": "Class Rank",
	"rank_text": "Rank %d -> %d" % [current_rank, next_rank],
	"summary": "%d%% -> %d%% increased Damage." % [current_percent, next_percent],
	"eligibility_text": "Requires the class to be represented in the party.",
	"recipient_text": "Applies to all current %s." % plural,
	"inheritance_text": "All current and future %s inherit this class rank." % plural,
}
```

Tooltip uses the same computed values and returns title, rank text, description, exact effect line, eligibility, inheritance, and keyword lines for `Damage` and `Increased`. Recruit, trait, and party-stat kinds retain concise specific descriptions rather than the old generic sentence.

- [ ] **Step 3: Route all non-authored card/tooltip content through the service**

In `_presentation_for`, keep authored routing and replace the legacy dictionary with `FoundationalUpgradePresentationService.card(choice, _party, _catalog)`.

In `_on_card_detail_requested`, remove the authored-only guard. Route authored choices through `UpgradePresentationService.tooltip`; route other kinds through `FoundationalUpgradePresentationService.tooltip`. Present the result with the same `_tooltip().show_content(...)` call.

- [ ] **Step 4: Run and commit**

```powershell
& $godot --headless --path $worktree --script res://tests/test_runner.gd
git add -- scripts/progression/foundational_upgrade_presentation_service.gd scripts/ui/level_up_panel.gd tests/unit/test_foundational_upgrade_presentation.gd
git commit -m "fix: explain class rank effects exactly"
```

### Task 2: Reduced-Motion Game Setting

**Files:**
- Create: `scripts/ui/settings/game_settings_page.gd`
- Create: `scenes/ui/settings/game_settings_page.tscn`
- Modify: `scenes/ui/settings/settings_screen.tscn`
- Modify: `scripts/ui/settings/settings_screen.gd`
- Modify: `scripts/settings/party_forge_settings.gd`
- Modify: `scripts/settings/party_forge_settings_store.gd`
- Modify: `scripts/game/run_rules_snapshot.gd`
- Modify: `tests/unit/test_party_forge_settings.gd`
- Modify: `tests/unit/test_settings_screen.gd`

**Interfaces:**
- Adds `PartyForgeSettings.reduced_motion: bool`.
- Adds `RunRulesSnapshot.reduced_motion() -> bool` for both Player Simulation and Developer Mode.
- Adds Game Settings path `Layout/ReducedMotion`.

- [ ] **Step 1: Write failing persistence and settings-screen tests**

Assert false default, copy/save/load round trip, snapshot true in both modes, Game Settings tab is no longer `Coming Soon`, the CheckButton is focusable/controller reachable, Apply writes the value, and Cancel preserves the prior value.

- [ ] **Step 2: Add the setting to data/store/snapshot**

Add `var reduced_motion := false`, copy it, load a bool key with false fallback, and save the key. In `RunRulesSnapshot.from_settings`, copy `normalized.reduced_motion` outside the developer-only block. Add:

```gdscript
func reduced_motion() -> bool: return _reduced_motion
```

- [ ] **Step 3: Implement the Game Settings page**

Scene structure:

```text
Game Settings (MarginContainer, script)
  Layout (VBoxContainer)
    Heading (Label: Game Settings)
    ReducedMotion (CheckButton: Reduce motion in interface animations)
```

Script:

```gdscript
class_name GameSettingsPage
extends MarginContainer

func initial_focus() -> Control:
	return _reduced_motion()

func bind(settings: PartyForgeSettings) -> void:
	_reduced_motion().button_pressed = settings.reduced_motion if settings != null else false

func write_to(settings: PartyForgeSettings) -> void:
	if settings != null:
		settings.reduced_motion = _reduced_motion().button_pressed

func _reduced_motion() -> CheckButton:
	return get_node("Layout/ReducedMotion") as CheckButton
```

Replace the existing Game Settings `Coming Soon` node in `settings_screen.tscn` with this scene. Bind it in `open()` and write it before normalize/save in `_apply_and_return()`.

- [ ] **Step 4: Run and commit**

```powershell
& $godot --headless --path $worktree --script res://tests/test_runner.gd
git add -- scripts/ui/settings/game_settings_page.gd scenes/ui/settings/game_settings_page.tscn scenes/ui/settings/settings_screen.tscn scripts/ui/settings/settings_screen.gd scripts/settings/party_forge_settings.gd scripts/settings/party_forge_settings_store.gd scripts/game/run_rules_snapshot.gd tests/unit/test_party_forge_settings.gd tests/unit/test_settings_screen.gd
git commit -m "feat: add reduced-motion game setting"
```

### Task 3: Pending-Level Indicator

**Files:**
- Modify: `scenes/ui/level_up_panel.tscn`
- Modify: `scripts/ui/level_up_panel.gd:7-69`
- Modify: `tests/unit/test_level_up_targeting_ui.gd`
- Modify: `tests/unit/test_main_wiring.gd`

**Interfaces:**
- Uses the optional `pending_count: int = 1` argument introduced in Plan 02.
- Adds node `ContentPanel/OfferView/Content/PendingLevels`.

- [ ] **Step 1: Add failing indicator tests**

Call `show_choices(..., 3)`, assert the label is visible and reads `3 upgrades ready`; call with `1` and assert `1 upgrade ready`; complete one selection and present the next with `2`, asserting immediate update and no duplicate labels.

- [ ] **Step 2: Add the indicator scene node**

Place a centered Label directly above `Title`, with gold font color `Color(1.0, 0.78, 0.18, 1.0)`, font size `22`, and no fixed screen coordinates.

- [ ] **Step 3: Store and render the pending count**

Add `_pending_level_count := 1` and in `show_choices`:

```gdscript
_pending_level_count = maxi(pending_count, 1)
var pending_label := get_node("ContentPanel/OfferView/Content/PendingLevels") as Label
pending_label.text = "%d %s ready" % [
	_pending_level_count,
	"upgrade" if _pending_level_count == 1 else "upgrades",
]
pending_label.visible = _pending_level_count > 0
```

Animation pulse is owned by the reveal controller in Task 5; reduced motion leaves the label static.

- [ ] **Step 4: Run and commit**

```powershell
& $godot --headless --path $worktree --script res://tests/test_runner.gd
git add -- scenes/ui/level_up_panel.tscn scripts/ui/level_up_panel.gd tests/unit/test_level_up_targeting_ui.gd tests/unit/test_main_wiring.gd
git commit -m "feat: show queued level-up count"
```

### Task 4: Responsive Five-Card Row

**Files:**
- Modify: `scenes/ui/level_up_panel.tscn`
- Modify: `scenes/ui/upgrade_card.tscn`
- Modify: `scripts/ui/level_up_panel.gd:22-69,105-110,156-169,256-264`
- Modify: `tests/unit/test_responsive_ui.gd`
- Modify: `tests/unit/test_level_up_targeting_ui.gd`
- Create: `tests/integration/level_up_five_card_geometry_runner.gd`

**Interfaces:**
- Produces `_ensure_card_count(count: int) -> void` supporting 1–8 developer cards.
- Production choices bind five visible `UpgradeCard` instances in one `HBoxContainer` row.

- [ ] **Step 1: Add failing five-card and geometry tests**

Assert five production choices create/bind five enabled cards, every focus neighbor left/right reaches the adjacent card, and geometry at 1280×720, 1920×1080, 2560×1440, and 3840×2160 keeps all five card rectangles inside the panel with no pair intersection.

- [ ] **Step 2: Make card and panel layout container-driven**

Change `UpgradeCard.custom_minimum_size` to `Vector2(168, 300)`. Reduce inner horizontal padding to `10`. In the panel, replace fixed center offsets with anchors `0.02/0.06/0.98/0.94`, zero symmetric offsets, and minimum size `Vector2(0, 560)`. Keep the `Cards` HBox and set each card `SIZE_EXPAND_FILL` with equal stretch ratio.

Add Card4 and Card5 scene instances. Their paths must be stable for editor inspection.

- [ ] **Step 3: Support developer counts dynamically**

Preload the card scene and implement:

```gdscript
func _ensure_card_count(count: int) -> void:
	var cards := get_node("ContentPanel/OfferView/Content/Cards") as HBoxContainer
	var needed := clampi(count, 1, 8)
	while cards.get_child_count() < needed:
		var card := UPGRADE_CARD_SCENE.instantiate() as UpgradeCard
		card.name = "Card%d" % (cards.get_child_count() + 1)
		cards.add_child(card)
	for index: int in cards.get_child_count():
		(cards.get_child(index) as Control).visible = index < needed
	_connect_cards()
	_configure_card_focus_neighbors()
```

Change all fixed `range(3)`/`mini(3, ...)` production loops to iterate visible card count or `choices.size()`. Keep the hidden legacy controls only until every existing test no longer depends on them; do not expand the hidden legacy row.

- [ ] **Step 4: Shorten only visible card summaries at narrow widths**

At viewport width below `1400`, hide `Eligibility`, `Recipient`, and `Inheritance` labels on the card face while retaining Name, Scope, Rank, and Summary. Tooltip dictionaries remain complete and unchanged.

- [ ] **Step 5: Run unit/integration geometry and commit**

```powershell
& $godot --headless --path $worktree --script res://tests/test_runner.gd
& $godot --headless --path $worktree --script res://tests/integration/level_up_five_card_geometry_runner.gd
git add -- scenes/ui/level_up_panel.tscn scenes/ui/upgrade_card.tscn scripts/ui/level_up_panel.gd tests/unit/test_responsive_ui.gd tests/unit/test_level_up_targeting_ui.gd tests/integration/level_up_five_card_geometry_runner.gd
git commit -m "feat: lay out five responsive upgrade cards"
```

### Task 5: Synchronized Slot-Reel Reveal Controller

**Files:**
- Create: `scripts/ui/level_up_reveal_controller.gd`
- Modify: `scripts/ui/upgrade_card.gd:8-59`
- Modify: `scripts/ui/level_up_panel.gd:1-110,191-207`
- Modify: `scenes/ui/level_up_panel.tscn`
- Create: `tests/unit/test_level_up_reveal_controller.gd`
- Modify: `tests/unit/test_level_up_targeting_ui.gd`

**Interfaces:**
- Produces `LevelUpRevealController.play(cards, final_bindings, preview_presentations, reduced_motion) -> void`.
- Produces `LevelUpRevealController.skip() -> void`, `advance(delta: float) -> void`, `is_revealing() -> bool`.
- Emits `resolved` once.
- Adds `UpgradeCard.bind_preview(presentation: Dictionary) -> void` without changing `_choice`.

- [ ] **Step 1: Write failing state, outcome, and skip tests**

Build five final bindings, begin reveal, and assert cards are disabled and none can emit activation. Advance `0.5` and assert preview text has changed while each `bound_choice()` still equals its preselected final choice. Advance beyond `1.1` and assert all final text is bound and cards enable according to their final disabled reason. Start again, call `skip`, and assert the same final state and exactly one `resolved` signal. Start with reduced motion and assert immediate final resolution.

- [ ] **Step 2: Implement non-binding preview support**

Add to `UpgradeCard`:

```gdscript
func bind_preview(presentation: Dictionary) -> void:
	_set_text("Content/Name", presentation.get("name", ""))
	_set_text("Content/Scope", presentation.get("scope_badge", ""))
	_set_text("Content/Rank", presentation.get("rank_text", ""))
	_set_text("Content/Summary", presentation.get("summary", ""))
```

Do not assign `_choice` in this method.

- [ ] **Step 3: Implement reveal timing/state**

Controller constants:

```gdscript
const TOTAL_DURATION := 1.1
const DROP_DURATION := 0.3
const PREVIEW_INTERVAL := 0.075
const DROP_OFFSET := -520.0
```

`play` stores base positions/final dictionaries, disables cards, moves them to `base_position + Vector2(0, DROP_OFFSET)`, and resets elapsed/cycle counters. `advance` interpolates the Y offset through the first `0.3` seconds, cycles the supplied preview dictionaries every `0.075` seconds, and calls one `_resolve()` at `1.1`. `_resolve()` restores base positions and calls `bind_choice(final.choice, final.presentation, final.disabled_reason)` for each card before emitting `resolved`.

Preview selection uses only the supplied array and the local cycle index; it does not call gameplay RNG.

- [ ] **Step 4: Integrate panel gating and fast-forward**

In `show_choices`, build and store final bindings before calling the controller. Do not focus a card until `resolved`. `_on_card_activated` returns immediately while `is_revealing()`.

In `_unhandled_input`:

```gdscript
if visible and _reveal_controller.is_revealing() and (
	event.is_action_pressed(&"ui_accept")
	or event.is_action_pressed(&"ui_cancel")
):
	_reveal_controller.skip()
	get_viewport().set_input_as_handled()
	return
```

`ui_accept` only skips during reveal; it cannot activate a card in the same event. On resolve, focus the first enabled card. On complete/close, force resolution or reset controller state so no stale callback modifies the next offer.

Configure the panel with the snapshotted reduced-motion flag from `active_run_rules.reduced_motion()` when a run starts.

- [ ] **Step 5: Add pending-label pulse**

While not reduced-motion, use the same controller elapsed phase to modulate the pending label between alpha `0.75` and `1.0` after cards resolve. Reduced motion sets alpha to `1.0` without oscillation.

- [ ] **Step 6: Run and commit**

```powershell
& $godot --headless --path $worktree --script res://tests/test_runner.gd
git add -- scripts/ui/level_up_reveal_controller.gd scripts/ui/upgrade_card.gd scripts/ui/level_up_panel.gd scenes/ui/level_up_panel.tscn scripts/game/main.gd tests/unit/test_level_up_reveal_controller.gd tests/unit/test_level_up_targeting_ui.gd
git commit -m "feat: animate synchronized upgrade reveals"
```

### Task 6: Input, Tooltip, and Resolution Acceptance

**Files:**
- Modify: `tests/integration/level_up_five_card_geometry_runner.gd`
- Modify: `tests/integration/temporary_popup_input_runner.gd`
- Create: `docs/validation/evidence/2026-07-31-plan-04-level-up-ui.log`

- [ ] **Step 1: Extend integration coverage**

For all four target resolutions, verify five-card focus movement, full tooltip opening, Alt-held mouse-wheel scrolling, pinning, controller Y/Triangle toggle, right-stick scrolling, reveal skip, and reduced-motion resolution.

- [ ] **Step 2: Run all verification**

```powershell
& $godot --headless --path $worktree --script res://tests/test_runner.gd 2>&1 | Tee-Object -FilePath "$worktree\docs\validation\evidence\2026-07-31-plan-04-level-up-ui.log"
& $godot --headless --path $worktree --script res://tests/integration/level_up_five_card_geometry_runner.gd
& $godot --headless --path $worktree --script res://tests/integration/temporary_popup_input_runner.gd
& $godot --headless --path $worktree --editor --quit-after 2
git -C $worktree diff --check
```

- [ ] **Step 3: Manual acceptance and commit**

Manually earn two pending levels, confirm count `2 -> 1`, inspect all five tooltips, skip one reveal, observe one full reveal, enable reduced motion for the next run, and verify direct resolution. Append facts/errors to the log and commit:

```powershell
git add -- tests/integration/level_up_five_card_geometry_runner.gd tests/integration/temporary_popup_input_runner.gd docs/validation/evidence/2026-07-31-plan-04-level-up-ui.log
git commit -m "test: verify five-card level-up presentation"
```
