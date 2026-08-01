# Twenty-Four-Member Ledger Accessibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every party member through the developer cap of 24 reachable and inspectable in Stats and Current Upgrades with mouse, keyboard, and controller.

**Architecture:** The existing roster remains one responsive `ScrollContainer`. Explicit focus neighbors cover the desktop list and compact grid, focus/selection always calls `ensure_control_visible`, and a two-way focus bridge connects the roster to the active page. Integration tests prove actual scrolling and member-24 data selection rather than merely counting buttons.

**Tech Stack:** Godot 4.7.1 Mono, typed GDScript, ScrollContainer/GridContainer focus APIs, asynchronous headless UI integration runner.

## Global Constraints

- Execute after Plans 01–04 pass.
- Developer cap remains exactly 24.
- No roster pagination.
- Mouse wheel and scrollbar dragging continue using native `ScrollContainer` behavior.
- Keyboard/controller directional navigation must reach all members in desktop and compact layouts.
- Focused or selected off-screen members become fully visible.
- Member selection persists across Stats and Current Upgrades.
- Equipment & Inventory remains Coming Soon but continues sharing `LedgerPlayerContext.selected_member_id`.

---

### Task 1: Roster Follow-Focus and Explicit Directional Graph

**Files:**
- Modify: `scenes/ui/ledger/character_ledger.tscn:55-65`
- Modify: `scripts/ui/ledger/character_ledger.gd:130-145,179-186,312-360,422-457`
- Modify: `tests/unit/test_ledger_responsive_input.gd`
- Modify: `tests/unit/test_character_ledger_shell.gd`

**Interfaces:**
- Produces `_configure_member_focus_neighbors() -> void`.
- Produces `_ensure_member_visible(member_id: int) -> void`.
- Produces `_wire_roster_page_focus_bridge() -> void`.

- [ ] **Step 1: Replace the weak seven-button assertion with 24-member focus assertions**

Build members 2–24, refresh, and assert:

```gdscript
TestAssertions.equal(party_entries.get_child_count(), 24, "rail contains all developer members", failures)
var member_24 := party_entries.get_node("Member_24") as Button
TestAssertions.truthy(member_24.focus_mode == Control.FOCUS_ALL, "member 24 is focusable", failures)
TestAssertions.truthy(not member_24.focus_neighbor_top.is_empty(), "member 24 has an upward route", failures)
TestAssertions.truthy(ledger.select_member(24), "member 24 can be selected", failures)
TestAssertions.equal(ledger.context.selected_member_id, 24, "member 24 becomes ledger context", failures)
ledger.activate_page(&"current_upgrades")
TestAssertions.equal(ledger.context.selected_member_id, 24, "page change preserves member 24", failures)
```

For compact mode, assert member 4's top neighbor is member 1, left neighbor is member 3, and member 24's top neighbor is member 21. For desktop, assert member 24 top is member 23 and member 1 bottom is member 2.

- [ ] **Step 2: Enable native follow-focus**

Set on `PartyScroll`:

```text
follow_focus = true
horizontal_scroll_mode = 0
```

Keep vertical scrolling automatic.

- [ ] **Step 3: Connect focus visibility during rail creation**

In `_rebuild_member_rail`, add:

```gdscript
button.focus_entered.connect(_on_member_focused.bind(int(row.member_id)))
```

After the loop and `_sync_member_selection()`:

```gdscript
_configure_member_focus_neighbors()
_wire_roster_page_focus_bridge()
call_deferred("_ensure_member_visible", context.selected_member_id)
```

Handler:

```gdscript
func _on_member_focused(member_id: int) -> void:
	_ensure_member_visible(member_id)
```

- [ ] **Step 4: Build deterministic list/grid neighbors**

```gdscript
func _configure_member_focus_neighbors() -> void:
	var buttons: Array[Button] = []
	for child: Node in _party_entries().get_children():
		var button := child as Button
		if button != null and button.visible:
			buttons.append(button)
	var columns := maxi(_party_entries().columns, 1)
	for index: int in buttons.size():
		var button := buttons[index]
		var row := index / columns
		var column := index % columns
		_set_neighbor(button, &"focus_neighbor_left", buttons[index - 1] if column > 0 else null)
		_set_neighbor(button, &"focus_neighbor_right", buttons[index + 1] if column + 1 < columns and index + 1 < buttons.size() else null)
		_set_neighbor(button, &"focus_neighbor_top", buttons[index - columns] if row > 0 else null)
		_set_neighbor(button, &"focus_neighbor_bottom", buttons[index + columns] if index + columns < buttons.size() else null)

func _set_neighbor(control: Control, property_name: StringName, target: Control) -> void:
	control.set(property_name, control.get_path_to(target) if target != null else NodePath())
```

After `apply_viewport_size` changes columns, call `_configure_member_focus_neighbors()` and `_wire_roster_page_focus_bridge()` again.

- [ ] **Step 5: Ensure focus and selection visibility**

```gdscript
func _ensure_member_visible(member_id: int) -> void:
	var button := _member_buttons.get(member_id) as Button
	if button == null or not button.is_inside_tree() or not button.is_visible_in_tree():
		return
	_party_scroll().ensure_control_visible(button)
```

Call it from `select_member`, after remembered/default focus, and after valid-selection fallback.

- [ ] **Step 6: Bridge roster and active page**

Use the selected member button and `active_page.initial_focus()`. Set the member button's right neighbor to the page target and the page target's left neighbor to the member button. In compact vertical layout, set member's bottom/page's top only when member is in the last visible roster row; preserve internal roster down neighbors otherwise.

- [ ] **Step 7: Run and commit**

```powershell
& $godot --headless --path $worktree --script res://tests/test_runner.gd
git add -- scenes/ui/ledger/character_ledger.tscn scripts/ui/ledger/character_ledger.gd tests/unit/test_ledger_responsive_input.gd tests/unit/test_character_ledger_shell.gd
git commit -m "fix: navigate complete ledger roster"
```

### Task 2: Member-24 Data and Real Scroll Acceptance

**Files:**
- Create: `tests/integration/ledger_24_member_runner.gd`
- Modify: `tests/unit/test_stats_ledger_page.gd`
- Modify: `tests/unit/test_upgrades_ledger_page.gd`

**Interfaces:**
- Proves the existing `LedgerPlayerContext.selected_member_id` drives both pages at member 24.

- [ ] **Step 1: Add page-level member-24 tests**

Create a 24-member party. Give member 24 a unique name `Twenty Four` and a member-owned upgrade source not present on member 1. Select member 24, refresh Stats, and assert `Layout/Header/Identity.text` contains `Twenty Four`. Activate Current Upgrades and assert the unique upgrade row exists. Switch back to Stats and assert the context and identity still reference member 24.

- [ ] **Step 2: Create asynchronous desktop/compact scroll runner**

The integration runner extends `SceneTree`, instantiates the ledger, creates 24 members, opens it, and awaits two process frames after each focus change so containers finish sorting.

Desktop assertions:

```gdscript
ledger.apply_viewport_size(Vector2(1920, 1080))
var scroll := ledger.get_node("Overlay/Frame/Layout/Body/PartyScroll") as ScrollContainer
var member_24 := ledger.get_node("Overlay/Frame/Layout/Body/PartyScroll/PartyEntries/Member_24") as Button
member_24.grab_focus()
await process_frame
await process_frame
_assert(scroll.scroll_vertical > 0, "desktop focus scrolls member 24 into view")
member_24.pressed.emit()
_assert(ledger.context.selected_member_id == 24, "desktop selects member 24")
```

Then focus member 1 and assert vertical scroll returns to `0` or its minimum. Repeat at `Vector2(960, 540)` and assert the compact roster scroll changes enough that member 24's global rect intersects the scroll container's global rect.

Use `_assert(condition, message)` to collect failures and quit with `0/1`, matching existing integration-runner style.

- [ ] **Step 3: Exercise directional navigation, not direct focus only**

In compact mode, focus member 1 and dispatch `ui_down` seven times plus `ui_right` twice to reach member 24 through the configured 3-column graph. Assert the focus owner is `Member_24`. In desktop mode, dispatch `ui_down` 23 times and assert the same.

- [ ] **Step 4: Run and commit**

```powershell
& $godot --headless --path $worktree --script res://tests/test_runner.gd
& $godot --headless --path $worktree --script res://tests/integration/ledger_24_member_runner.gd
git add -- tests/integration/ledger_24_member_runner.gd tests/unit/test_stats_ledger_page.gd tests/unit/test_upgrades_ledger_page.gd
git commit -m "test: prove member 24 ledger access"
```

### Task 3: Mouse, Keyboard, Controller, and Refresh Manual Acceptance

**Files:**
- Create: `docs/validation/evidence/2026-07-31-plan-05-ledger-24.log`

- [ ] **Step 1: Run automated verification**

```powershell
& $godot --headless --path $worktree --script res://tests/test_runner.gd 2>&1 | Tee-Object -FilePath "$worktree\docs\validation\evidence\2026-07-31-plan-05-ledger-24.log"
& $godot --headless --path $worktree --script res://tests/integration/ledger_24_member_runner.gd
& $godot --headless --path $worktree --editor --quit-after 2
git -C $worktree diff --check
```

- [ ] **Step 2: Manual 24-member acceptance**

In Developer Mode set party capacity to 24 and use the developer content path to fill the party. Verify:

1. Mouse wheel reaches member 24 and clicking it updates Stats.
2. Scrollbar dragging reaches member 24.
3. Keyboard directional navigation reaches and selects member 24.
4. Controller directional navigation reaches and selects member 24.
5. Shoulder buttons change Stats/Current Upgrades without losing member 24.
6. Recruiting/refreshing while member 24 remains valid preserves selection and visibility.
7. Removing the selected fixture member falls back to the controlled/first member and reveals it.
8. Equipment & Inventory still reports Coming Soon without changing selection.

Record each item as PASS or FAIL with the observed behavior.

- [ ] **Step 3: Commit evidence**

```powershell
git add -- docs/validation/evidence/2026-07-31-plan-05-ledger-24.log
git commit -m "test: record full ledger roster acceptance"
```

### Task 4: Tuning Guide and Final Slice Verification

**Files:**
- Create: `docs/development/PLAYTEST_CORRECTIONS_TUNING_GUIDE.md`
- Create: `docs/validation/evidence/2026-07-31-playtest-corrections-final.log`

- [ ] **Step 1: Write the project-specific tuning guide**

Document the exact editable files and safe ranges:

```text
Spawn timing/weights: scripts/game/spawn_schedule.gd
Boltcaster attack: data/attacks/boltcaster_bolt.tres
Spitter attack: data/attacks/spitter_projectile.tres
Projectile movement/color: data/projectiles/*.tres
Recruit probabilities/drought: scripts/progression/recruit_offer_policy.gd
XP curve: data/progression/default_experience.tres
Developer ranges/defaults: scripts/settings/party_forge_settings.gd
Level-up layout: scenes/ui/level_up_panel.tscn and scenes/ui/upgrade_card.tscn
Ledger roster layout: scenes/ui/ledger/character_ledger.tscn
```

For each, explain which property changes intensity, reach, area, readability, or test speed and name the focused test to run afterward.

- [ ] **Step 2: Run final full verification**

```powershell
& $godot --headless --path $worktree --script res://tests/test_runner.gd 2>&1 | Tee-Object -FilePath "$worktree\docs\validation\evidence\2026-07-31-playtest-corrections-final.log"
& $godot --headless --path $worktree --script res://tests/integration/temporary_popup_input_runner.gd
& $godot --headless --path $worktree --script res://tests/integration/level_up_five_card_geometry_runner.gd
& $godot --headless --path $worktree --script res://tests/integration/ledger_24_member_runner.gd
& $godot --headless --path $worktree --editor --quit-after 2
git -C $worktree diff --check
git -C $worktree status --short --branch
```

Expected: all commands exit `0`, diff check is silent, and only the guide/evidence are uncommitted.

- [ ] **Step 3: Manual launch smoke**

Launch a windowed run from the feature worktree. Verify class selection, run start, combat, level-up reveal, tooltip pin/scroll, pause ledger, Boltcaster/Spitter behavior, and quit flow. Record any debugger errors verbatim in the final log.

- [ ] **Step 4: Commit final docs/evidence**

```powershell
git add -- docs/development/PLAYTEST_CORRECTIONS_TUNING_GUIDE.md docs/validation/evidence/2026-07-31-playtest-corrections-final.log
git commit -m "docs: explain playtest correction tuning"
```
