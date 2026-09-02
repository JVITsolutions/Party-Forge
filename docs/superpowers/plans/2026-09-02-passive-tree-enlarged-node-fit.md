# Passive Tree Enlarged Node Fit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render every City v3 node name in a uniformly enlarged production node control and automatically scale/center the complete approved graph inside the supported desktop canvas.

**Architecture:** `PassiveTreeNodeControl` owns one uniform 168-by-120 wrapped-label surface. `PassiveTreeCanvas` computes a production fit from authored node centers plus the actual control footprint, and `PassiveTreeScreen` requests that fit after rebuild/open/viewport resize. Runtime-v3 data, domain coordinates, connection topology, navigation, and allocation behavior remain unchanged.

**Tech Stack:** Godot 4.7.1 Mono, GDScript, Party Forge focused/unit/integration runners.

## Global Constraints

- The approved amendment is `docs/superpowers/specs/2026-09-02-passive-tree-enlarged-node-fit-design.md` at commit `0be82895`.
- Use the exact worktree `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\latticewright-city-v3-foundation` and the portable Godot 4.7.1 executable.
- Preserve every untracked `.gd.uid`, the frozen Task 8 index, and all unrelated worktree state.
- Do not alter LatticeWright source/runtime data, Party Forge node coordinates, connections, activation behavior, art, HUD, or unrelated UI.
- Use strict TDD. Do not add a test-only production API.
- Node controls are uniformly `Vector2(168, 120)`, use word-boundary wrapping, and never ellipsize names.
- Fit uses authored centers, actual control footprint, and a 24 px canvas margin; zoom remains clamped by `PassiveTreeCanvas.MIN_ZOOM` and `MAX_ZOOM`.
- At 1920-by-1080, all 37 controls and full label text regions must be inside the canvas and nonoverlapping; all 37 connections retain at least 95 percent pixel coverage with a maximum two-sample internal gap.

---

### Task 1: Enlarge wrapped nodes and fit the production graph

**Files:**
- Modify: `tests/unit/test_passive_tree_readability.gd`
- Modify: `tests/unit/test_passive_tree_screen.gd`
- Modify: `tests/integration/city_tree_v3_visual_runner.gd`
- Modify: `tests/integration/passive_tree_responsive_runner.gd`
- Modify: `scenes/ui/passive_tree/passive_tree_node_control.tscn`
- Modify: `scripts/ui/passive_tree/passive_tree_canvas.gd`
- Modify: `scripts/ui/passive_tree/passive_tree_screen.gd`

**Interfaces:**
- `PassiveTreeCanvas.fit_to_content(margin: Vector2 = Vector2(24.0, 24.0)) -> bool` returns `false` without mutation for no views, nonpositive canvas size, or nonpositive available space; otherwise it applies finite clamped zoom/pan and returns `true`.
- `PassiveTreeScreen` calls the production fit after its projected nodes are rebuilt and after viewport-size changes; manual pan/zoom behavior remains unchanged after that fit.

- [ ] **Step 1: Extend the existing RED contracts**

In `test_passive_tree_readability.gd`, instantiate the real node scene and assert:

```gdscript
TestAssertions.equal(node_control.custom_minimum_size, Vector2(168.0, 120.0), "passive nodes use the approved enlarged uniform footprint", failures)
TestAssertions.equal(node_control.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART, "passive node names wrap at word boundaries", failures)
TestAssertions.equal(node_control.text_overrun_behavior, TextServer.OVERRUN_NO_TRIMMING, "passive node names never ellipsize", failures)
```

In `test_passive_tree_screen.gd`, create a real canvas with nonzero size, rebuild three separated views, call `fit_to_content`, and assert it returns true, preserves copied authored positions, leaves every control inside the canvas, and produces finite clamped zoom/pan. Also assert empty/zero-sized canvases return false without changing prior zoom/pan.

Keep the strict visual runner assertions already producing RED: all 37 connection paths meet the 95-percent/two-gap proof, every full wrapped label fits its production control, all controls/text regions are contained and nonoverlapping, and the six charter names render real foreground pixels.

- [ ] **Step 2: Verify RED for the intended production gap**

Run:

```powershell
& $partyForgeGodot --headless --path $partyForgeWorktree --quit-after 1200 --script res://tests/focused_test_runner.gd -- res://tests/unit/test_passive_tree_readability.gd res://tests/unit/test_passive_tree_screen.gd
& $partyForgeGodot --path $partyForgeWorktree --rendering-method gl_compatibility --quit-after 1800 --script res://tests/integration/city_tree_v3_visual_runner.gd
```

Expected: focused failures cite the old `104x104`, no-wrap/ellipsis contract or missing `fit_to_content`; visual exit 1 cites full-label fit/collision failures while all 37 strict connection checks pass.

- [ ] **Step 3: Implement the enlarged node scene**

Set these exact properties on the root `Button` in `passive_tree_node_control.tscn`:

```text
custom_minimum_size = Vector2(168, 120)
text_overrun_behavior = 0
autowrap_mode = 2
```

Retain the native button label, existing node visual child, focusability, state colors, outline, tooltip, and activation signal.

- [ ] **Step 4: Implement production fit-to-content**

In `passive_tree_canvas.gd`, add `fit_to_content`. Compute lexical node bounds from the copied view positions, obtain the maximum instantiated control size, subtract that footprint plus `margin * 2.0` from `size`, derive one uniform zoom from both axes, clamp it, and center the authored bounds through `_pan`. Reject invalid/empty inputs before mutation. Call `_layout_nodes()` and `queue_redraw()` once after assigning both values.

In `passive_tree_screen.gd`, call the fit after `_canvas().rebuild(projected_nodes, ...)`. On viewport resize, apply the screen geometry first and defer one fit so container sizes have settled. Do not auto-fit during user pan or zoom.

- [ ] **Step 5: Verify GREEN and refactor without behavior changes**

Run the focused command from Step 2, then:

```powershell
& $partyForgeGodot --path $partyForgeWorktree --rendering-method gl_compatibility --quit-after 1800 --script res://tests/integration/city_tree_v3_visual_runner.gd
& $partyForgeGodot --path $partyForgeWorktree --rendering-method gl_compatibility --quit-after 1800 --script res://tests/integration/passive_tree_responsive_runner.gd
& $partyForgeGodot --path $partyForgeWorktree --rendering-method gl_compatibility --quit-after 1800 --script res://tests/integration/passive_tree_input_runner.gd
git diff --check
```

Expected markers exactly once with exit 0:

```text
CITY_TREE_V3_VISUAL_SUMMARY: PASS
PASSIVE_TREE_RESPONSIVE_SUMMARY: PASS (3 sizes)
PASSIVE_TREE_INPUT_SUMMARY: PASS
```

The visual runner reports its absolute PNG path outside the repository. Preserve and render that capture for Jacob.

- [ ] **Step 6: Sequential review and commit**

Freeze the complete remediation diff, obtain requirements review before code-quality review, resolve every Important/Critical finding, re-run Step 5, then stage only the seven listed production/test files plus the four Task 8 runners. Verify the 87-UID manifest is unchanged.

Commit: `fix: fit enlarged passive tree nodes`
