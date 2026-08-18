# Ground Loot and Equipment Preview Corrections Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make player-owned ground loot compact, collectible, readable through a translucent icon-bearing ARPG tooltip, and keep the Equipment ledger preview isolated from the arena.

**Architecture:** Preserve `GroundItemWorldController` as the single input/projection coordinator, `GroundItemChest` as the pooled world presentation, and `ItemTooltipPanel`/`ItemTooltipCard` as the shared tooltip implementation. Correct authored geometry and pointer filters rather than introducing a ground-only tooltip. Give the Equipment preview viewport its own `World3D` and treat page activation as explicit preview ownership.

**Tech Stack:** Godot 4.7.1, typed GDScript, `.tscn` scenes, the repository focused unit runner, real viewport-dispatched integration runners, Godot MCP/editor screenshots.

## Global Constraints

- Implement in `feat/playtest-recovery-loot-ui` at the isolated worktree only.
- Follow strict RED-GREEN-REFACTOR. Record the failing assertion before changing production code.
- Preserve owner-only loot, controller D-pad/south-face input, mouse click, distance/full-inventory feedback, pooling, pin/Alt/Shift behavior, and the shared tooltip architecture.
- Do not add a ground-only tooltip implementation or a direct selection/pickup bypass.
- Do not mutate live profiles or persistent inventory unlocks in this plan.
- Do not manually invoke engine lifecycle callbacks in integration runners; attach nodes to the `SceneTree` and await frames.
- Run Godot with fresh `APPDATA` and `LOCALAPPDATA` roots for full-suite verification.
- Save before/after visual evidence outside imported/runtime cache directories.

---

## Task 1: Lock the compact P1/P2 pennant visual budget

**Files:**

- Modify: `tests/unit/test_ground_item_chest.gd`
- Modify: `scenes/world/ground_item_chest.tscn`
- Verify: `scripts/world/player_owner_marker_3d.gd`

- [ ] **Step 1: Add the failing authored-scene contract**

Load `ground_item_chest.tscn`, inspect `OwnerMarker/Pennant` and `OwnerMarker/OwnerLabel`, and assert:

```gdscript
TestAssertions.truthy(pennant.font_size <= 28, "owner pennant stays within compact font budget", failures)
TestAssertions.truthy(pennant.outline_size <= 6, "owner pennant outline stays compact", failures)
TestAssertions.truthy(owner_label.font_size <= 18, "owner label stays within compact font budget", failures)
TestAssertions.truthy(owner_label.outline_size <= 4, "owner label outline stays compact", failures)
```

Also bind both P1 and P2 colors and verify text/color/downward ownership language remains intact.

- [ ] **Step 2: Run RED**

```powershell
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
& $godot --headless --path (Get-Location).Path --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_ground_item_chest.gd
```

Expected: non-zero exit with the current 72/14 and 42/12 budgets failing; no parser or loader failure.

- [ ] **Step 3: Implement the compact pennant**

Change only the authored marker font/outline/offset values needed to reduce the combined fixed-size footprint to about one-third of the current presentation. Retain `fixed_size`, the owner color, `P1`/`P2`, and downward pointer.

- [ ] **Step 4: Run GREEN and commit**

Run the focused command again. Expected: `TEST_SUMMARY: PASS (0 failures)`.

```powershell
git add tests/unit/test_ground_item_chest.gd scenes/world/ground_item_chest.tscn
git commit -m "fix: compact ground loot owner markers"
```

---

## Task 2: Add the real item icon and aggregate transparency contract

**Files:**

- Modify: `tests/unit/test_item_tooltip_card.gd`
- Modify: `tests/unit/test_item_tooltip_panel.gd`
- Modify: `tests/integration/item_tooltip_responsive_runner.gd`
- Modify: `scripts/ui/storage/item_tooltip_card.gd`
- Modify: `scenes/ui/storage/item_tooltip_panel.tscn`

- [ ] **Step 1: Add RED tests for the Full ARPG Card**

Extend the shared detail fixture with the existing projected `icon_path` field. Assert the first card has a visible `TextureRect` whose texture resource path matches the fixture, whose accessibility text names the item, and whose minimum size is at least 48 by 48 pixels.

Assert the outer panel and inner card do not stack two near-opaque backgrounds. The aggregate target is a dark card near 85 percent opacity; encode a stable bound such as one owned background in `[0.80, 0.88]` and the other transparent or visually unowned.

Assert decorative card/header labels use `MOUSE_FILTER_IGNORE`; preserve `MOUSE_FILTER_STOP` only for the pin and scroll interaction surfaces.

- [ ] **Step 2: Run RED**

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_item_tooltip_card.gd tests/unit/test_item_tooltip_panel.gd
```

Expected: icon, opacity, and pointer-filter assertions fail against the text-only, stacked-opaque implementation.

- [ ] **Step 3: Implement the shared icon header**

In `_ensure_built()`, construct a header row containing the icon plus the existing title/rarity/classification labels. Load only the existing item-detail `icon_path`; do not derive a second icon from an unrelated base ID inside the card. If the projected path is empty or cannot load, show the established placeholder without collapsing the layout.

Make the outer panel own the approximately 85 percent dark background and make the card background transparent, or the inverse, but never both. Keep rarity framing/readability.

- [ ] **Step 4: Preserve ARPG controls**

Run both tooltip integration runners and prove:

- Shift still reveals roll ranges.
- Alt still shows comparisons.
- pin button and Y/Triangle still toggle pin state.
- mouse wheel/scrollbar and right stick still scroll.
- technical details remain developer-gated.

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 300 --script res://tests/integration/item_tooltip_input_runner.gd
& $godot --headless --path (Get-Location).Path --quit-after 300 --script res://tests/integration/item_tooltip_responsive_runner.gd
```

Expected: each runner exits 0 with its PASS summary and no leak diagnostics.

- [ ] **Step 5: Commit**

```powershell
git add tests/unit/test_item_tooltip_card.gd tests/unit/test_item_tooltip_panel.gd tests/integration/item_tooltip_responsive_runner.gd scripts/ui/storage/item_tooltip_card.gd scenes/ui/storage/item_tooltip_panel.tscn
git commit -m "fix: show translucent icon item tooltips"
```

---

## Task 3: Prove mouse pickup works while the tooltip is visible

**Files:**

- Modify: `tests/unit/test_ground_item_world_controller.gd`
- Modify: `tests/integration/ground_item_pickup_input_runner.gd`
- Modify: `scripts/world/ground_item_world_controller.gd`
- Modify if required by the failing test: `scripts/world/ground_item_chest.gd`
- Modify if required by the failing test: `scripts/ui/storage/item_tooltip_panel.gd`

- [ ] **Step 1: Add a real overlap regression**

Build a real `SubViewport`, camera, production controller, registry, owned ground record, and shared tooltip. Dispatch pointer motion to reveal the tooltip, then dispatch an actual left-button event at a part of the projected 44 by 44 chest anchor that is geometrically covered by a decorative tooltip region.

Assert:

```gdscript
_assert(tooltip.visible, "tooltip is visible before pickup click")
_assert(context.inventory_contains(instance_id), "real overlapped click collects owned item")
_assert(registry.record(drop_id) == null, "successful pickup consumes only collected chest")
```

Do not call `_on_anchor_gui_input`, `request_pickup`, `_collect_for_owner`, or a private lifecycle method from the test.

- [ ] **Step 2: Run RED**

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 420 --script res://tests/integration/ground_item_pickup_input_runner.gd
```

Expected: the overlap case fails because the tooltip consumes the click, while existing mouse/controller/full-inventory/foreign-owner cases remain green.

- [ ] **Step 3: Correct pointer ownership and tooltip placement**

Make noninteractive tooltip regions ignore pointer events and position the tooltip beside, not centered over, its projected item whenever viewport space permits. Pin/scroll surfaces remain interactive. Keep controller targeting independent of pointer filtering.

If a pinned tooltip intentionally overlaps the chest, route the click only when it lands on the chest anchor and not on pin/scroll controls. Do not add a broad global click listener.

- [ ] **Step 4: Add failure-state assertions**

In the same real-input runner, prove:

- out-of-range click leaves the chest and shows persistent `Move closer`;
- full inventory leaves the chest and shows `Inventory full`;
- foreign-owner click leaves both ownership states unchanged;
- retry after becoming eligible succeeds once.

- [ ] **Step 5: Run focused GREEN and commit**

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 420 --script res://tests/focused_test_runner.gd -- tests/unit/test_ground_item_chest.gd tests/unit/test_ground_item_world_controller.gd tests/unit/test_ground_item_pickup_service.gd tests/unit/test_item_tooltip_card.gd tests/unit/test_item_tooltip_panel.gd
& $godot --headless --path (Get-Location).Path --quit-after 420 --script res://tests/integration/ground_item_pickup_input_runner.gd
```

Expected: focused `PASS (0 failures)` and all real-input markers PASS.

```powershell
git add tests/unit/test_ground_item_world_controller.gd tests/integration/ground_item_pickup_input_runner.gd scripts/world/ground_item_world_controller.gd scripts/world/ground_item_chest.gd scripts/ui/storage/item_tooltip_panel.gd
git commit -m "fix: collect ground loot through visible tooltips"
```

Stage only files actually changed.

---

## Task 4: Isolate and lifecycle-own the Equipment preview

**Files:**

- Modify: `tests/unit/test_character_equipment_preview.gd`
- Modify: `tests/unit/test_equipment_inventory_ledger_page.gd`
- Modify: `tests/integration/equipment_ledger_preview_runner.gd`
- Modify: `scenes/ui/ledger/character_equipment_preview.tscn`
- Modify: `scripts/ui/ledger/character_equipment_preview.gd`
- Modify: `scripts/ui/ledger/equipment_inventory_ledger_page.gd`

- [ ] **Step 1: Add viewport isolation and teardown REDs**

Instantiate the production preview scene through a real tree and assert:

```gdscript
_assert(subviewport.own_world_3d, "equipment preview owns an isolated World3D")
_assert(preview.active_preview != null, "active equipment page renders selected member")
page.deactivate()
_assert(preview.active_preview == null, "deactivation releases preview actor")
```

Also compare the preview actor's world with the arena viewport's world and assert they are different. Re-activate and assert the selected member is rebuilt with equipment visuals and drag rotation still works.

- [ ] **Step 2: Run RED**

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_character_equipment_preview.gd tests/unit/test_equipment_inventory_ledger_page.gd
```

Expected: `own_world_3d` and deactivate cleanup fail.

- [ ] **Step 3: Implement isolation and idempotent cleanup**

Set `own_world_3d = true` on the preview `SubViewport`. Make `EquipmentInventoryLedgerPage.deactivate()` call the preview's public `clear()` after dismissing tooltip/held state. Keep `activate()`/`refresh()` rebuilding the current member. Ensure `_exit_tree()` defensively clears without manual test invocation.

- [ ] **Step 4: Run GREEN integrations**

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 420 --script res://tests/integration/equipment_ledger_preview_runner.gd
& $godot --headless --path (Get-Location).Path --quit-after 420 --script res://tests/integration/equipment_ledger_responsive_runner.gd
```

Expected: preview PASS; 1080p, 1440p, 4K, and member-24 responsive markers PASS; zero RID/ObjectDB/resource-leak markers.

- [ ] **Step 5: Commit**

```powershell
git add tests/unit/test_character_equipment_preview.gd tests/unit/test_equipment_inventory_ledger_page.gd tests/integration/equipment_ledger_preview_runner.gd scenes/ui/ledger/character_equipment_preview.tscn scripts/ui/ledger/character_equipment_preview.gd scripts/ui/ledger/equipment_inventory_ledger_page.gd
git commit -m "fix: isolate equipment ledger preview world"
```

---

## Task 5: Capture visual evidence at production resolutions

**Files:**

- Create: `docs/validation/screenshots/playtest-recovery/ground-loot-compact-1080p.png`
- Create: `docs/validation/screenshots/playtest-recovery/ground-loot-tooltip-1080p.png`
- Create: `docs/validation/screenshots/playtest-recovery/equipment-preview-open-1080p.png`
- Create: `docs/validation/screenshots/playtest-recovery/equipment-preview-closed-1080p.png`
- Create: `docs/verification/2026-08-18-playtest-recovery-and-ground-loot.md`

- [ ] **Step 1: Run the live game from the isolated worktree**

Use a disposable profile root or a test profile. Spawn at least P1 and P2 owned drops close enough to compare markers. Do not alter the user's real profiles.

- [ ] **Step 2: Capture and inspect screenshots**

Capture:

1. two compact pennants relative to chest and player;
2. tooltip with icon, readable item data, and visible arena behind it;
3. Equipment page open with preview inside the ledger;
4. Equipment page closed with no preview actor in the arena.

Inspect each image at full resolution before accepting it. Record viewport, profile isolation root, commit SHA, and observed result in the verification document.

- [ ] **Step 3: Exercise real controls**

Manually verify mouse click pickup, D-pad cycling, south-face pickup, Y/Triangle pin, right-stick scroll, Alt comparison, Shift roll ranges, and close/reopen preview. Mark any controller check not physically performed as DEFERRED rather than PASS.

- [ ] **Step 4: Commit evidence**

```powershell
git add docs/validation/screenshots/playtest-recovery docs/verification/2026-08-18-playtest-recovery-and-ground-loot.md
git commit -m "test: record ground loot visual acceptance"
```

---

## Task 6: Final isolated verification

- [ ] **Step 1: Run the affected gate**

```powershell
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_ground_item_chest.gd tests/unit/test_ground_item_world_controller.gd tests/unit/test_ground_item_pickup_service.gd tests/unit/test_item_tooltip_card.gd tests/unit/test_item_tooltip_panel.gd tests/unit/test_character_equipment_preview.gd tests/unit/test_equipment_inventory_ledger_page.gd
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/integration/ground_item_pickup_input_runner.gd
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/integration/item_tooltip_input_runner.gd
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/integration/item_tooltip_responsive_runner.gd
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/integration/equipment_ledger_preview_runner.gd
& $godot --headless --path (Get-Location).Path --quit-after 600 --script res://tests/integration/equipment_ledger_responsive_runner.gd
```

- [ ] **Step 2: Run the complete suite in isolated app-data roots**

```powershell
$verificationRoot = Join-Path $env:TEMP ("party-forge-loot-final-" + [guid]::NewGuid().ToString('N'))
$appData = Join-Path $verificationRoot 'AppData'
$localAppData = Join-Path $verificationRoot 'LocalAppData'
New-Item -ItemType Directory -Force -Path $appData,$localAppData | Out-Null
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
$env:APPDATA = $appData
$env:LOCALAPPDATA = $localAppData
try {
    & $godot --headless --editor --path (Get-Location).Path --quit-after 180
    if ($LASTEXITCODE -ne 0) { throw "Cold import failed: $LASTEXITCODE" }
    & $godot --headless --path (Get-Location).Path --quit-after 1800 --script res://tests/test_runner.gd
    if ($LASTEXITCODE -ne 0) { throw "Full suite failed: $LASTEXITCODE" }
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}
```

Expected: exactly one `TEST_SUMMARY: PASS (202 suites)` or the updated exact suite count, zero FAIL summaries, and zero parse/script/loader/RID/ObjectDB/resource-leak markers.

- [ ] **Step 3: Review scope and status**

```powershell
git diff --check
git status --short
git log --oneline --decorate -8
```

Document expected negative-path diagnostics separately. Do not claim controller or visual PASS without the recorded evidence.
