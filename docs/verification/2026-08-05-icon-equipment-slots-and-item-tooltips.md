# Icon equipment slots and item tooltips verification

## Scope and source

- Branch: `feat/icon-equipment-ui`
- Base `main`: `4088ef57c26e79f34bdccedecc77e3ad563674d6`
- Verified implementation HEAD before this evidence commit: `628c646bb04fe7eb2783c6cfafbce05c5005f0ac`
- Godot: `4.7.1.stable.mono.official.a13da4feb`
- Executable: `F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe`
- Hermetic user roots:
  - `.superpowers\sdd\icon-equipment-ui-final\appdata`
  - `.superpowers\sdd\icon-equipment-ui-final\localappdata`
- Live `tests/unit/*.gd` count: `149`

## Focused verification

Command:

```powershell
& $godot --headless --path . --quit-after 300 --script res://tests/focused_test_runner.gd -- tests/unit/test_item_presentation_projector.gd tests/unit/test_profile_storage_projection.gd tests/unit/test_storage_slot_button.gd tests/unit/test_item_comparison_resolver.gd tests/unit/test_item_tooltip_card.gd tests/unit/test_item_tooltip_panel.gd tests/unit/test_temporary_hover_popup.gd tests/unit/test_armoury_screen.gd tests/unit/test_warehouse_screen.gd tests/unit/test_developer_item_sandbox.gd
```

- Exit: `0`
- Duration: `16.48s`
- Marker: `TEST_SUMMARY: PASS (0 failures)` exactly once
- `TEST_FAILURE`, script, parse, and loader failure scan: `0`

## Integration acceptance

Each program was run separately with `--headless --path . --quit-after 180`.

| Program | Duration | Exact marker | Exit | Error scan |
| --- | ---: | --- | ---: | ---: |
| `item_tooltip_input_runner.gd` | 0.52s | `ITEM_TOOLTIP_INPUT_SUMMARY: PASS` | 0 | 0 |
| `item_tooltip_responsive_runner.gd` | 2.22s | `ITEM_TOOLTIP_RESPONSIVE_SUMMARY: PASS (3 sizes)` | 0 | 0 |
| `armoury_warehouse_responsive_runner.gd` | 1.20s | `TASK9_STORAGE_RESPONSIVE_SUMMARY: PASS (0 failures)` | 0 | 0 |
| `developer_item_sandbox_runner.gd` | 8.80s | `ITEM_SANDBOX_UI_SUMMARY: PASS` | 0 | 0 |
| `task9_developer_item_sandbox_focus_runner.gd` | 5.43s | `TASK9_SANDBOX_FOCUS_SUMMARY: PASS (0 failures)` | 0 | 0 |
| `temporary_popup_input_runner.gd` | 0.93s | `TEMPORARY_POPUP_INPUT_SUMMARY: PASS (4 sizes)` | 0 | 0 |

The error scan was case-sensitive for `FAILURE`, `SCRIPT ERROR`, `Parse Error`, `Failed to load`, and `No loader found`.

## Responsive rendered-layout inspection

The tooltip runner instantiated real panels in a `SubViewport`, waited for Godot container layout, and checked all four viewport edges. It exercised zero, one, and two comparison candidates with normal, comparison, advanced, and combined layers.

- Compatibility: `1280x720` passed.
- Targets: `1920x1080`, `2560x1440`, and `3840x2160` each emitted a size PASS marker.
- All supplied comparison candidates remained present; two equipped rings produced three visible cards including the inspected item.
- Panel, pin, and scrollbar rectangles remained inside the viewport.
- Player Mode rendered text did not expose the instance identifier.
- The final deferred sizing pass re-clamped Godot's first-pass content expansion, including bottom-edge placements.

The combined Armoury/Warehouse runner additionally confirmed icon-only occupied cells and shared tooltip activation at 1080p, 1440p, and 4K.

## Hermetic cold import and full suite

Environment:

```powershell
$env:APPDATA = Join-Path $verificationRoot 'appdata'
$env:LOCALAPPDATA = Join-Path $verificationRoot 'localappdata'
```

Cold import:

```powershell
& $godot --headless --path . --import
```

- Exit: `0`
- Duration: `5.32s`
- Script, parse, and loader failure scan: `0`

Complete suite:

```powershell
& $godot --headless --path . --quit-after 420 --script res://tests/test_runner.gd
```

- Exit: `0`
- Duration: `93.53s`
- Marker: `TEST_SUMMARY: PASS (149 suites)` exactly once
- `TEST_FAILURE`, script, parse, and loader failure scan: `0`

The full suite intentionally logs domain rejection errors from negative-path tests. Godot also reports resource/ObjectDB/RID cleanup diagnostics when the headless editor/test process exits. These diagnostics were recorded separately; they did not include the gated failure patterns and did not change the zero exit or exact suite marker.

Cold import generated 78 untracked `.gd.uid` files. The pre-import snapshot contained none, so all 78 were removed with an explicit workspace patch. The only remaining untracked file was the authored responsive runner.

## Startup smoke

```powershell
& $godot --headless --path . --quit-after 10
```

- Exit: `0`
- Duration: `1.92s`
- `PARTY_FORGE_BOOT_OK`: exactly once
- `PARTY_FORGE_CLASS_SELECTION_READY`: exactly once
- Script, parse, and loader failure scan: `0`

## Preserved behavior

- Armoury and Warehouse mouse drag/drop plus controller west-face pickup and south-face placement retained their exact item/container/slot intent routing.
- Warehouse filter/sort results retained authoritative source slots.
- Developer sandbox retained 5 inventory and 100 stash cells, real stash scrolling, move, occupied swap, outside-drop cancellation, controller cancellation, save/reload, integrity scan, reset, and failure-atomic persistence.
- Y/Triangle pinning, right-stick scrolling, mouse-wheel scrolling, Alt/LT comparison, and Shift/RT advanced-affix layers passed real input-event acceptance.
- Pinned main cards reject focus replacement; releasing comparison/advanced modifiers removes only those temporary layers.
