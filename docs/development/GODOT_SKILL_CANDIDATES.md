# Godot Skill Candidates

This is a living backlog of repeatable Party Forge workflows that may be worth turning into reusable Codex skills. A candidate should be promoted only after the workflow has been used enough to identify stable inputs, steps, safety checks, and expected evidence.

## Active Candidates

### Responsive Godot UI Audit and Repair

- Detect controls that rely on resolution-specific offsets.
- Classify each control by intended attachment: corner, edge, center, or full viewport.
- Convert layout to anchors plus logical offsets without changing visual intent.
- Test center and margin invariants at multiple viewport sizes.
- Capture visual evidence at the project's target resolution.

### Scene, Resource, and Parser Validation

- Run headless Godot import and parser checks.
- Detect broken resource paths, malformed scenes, and script parse failures.
- Report exact scene or script locations and preserve generated import metadata appropriately.

### Data-Driven Content Addition

- Add a class, enemy, attack, trait, or upgrade through the project's data/resource conventions.
- Validate required fields and cross-resource references.
- Exercise the new content in focused tests and the combat sandbox.

### Godot Save-State and Git-Diff Hygiene

- Distinguish intentional editor saves from serialization-only churn.
- Preserve user changes in a dirty worktree.
- Stage and commit only the requested scope.
- Explain which Godot files must be saved and which files are generated.

### Multi-Resolution Visual Testing

- Launch controlled test runs at common logical and physical resolutions.
- Verify anchors, scaling, readability, and safe margins.
- Store screenshots with reproducible viewport metadata.

### Runtime Combat Sandbox Generation

- Create small deterministic scenarios for attacks, status effects, traits, enemies, and projectiles.
- Separate simulation checks from presentation checks.
- Produce evidence that a gameplay interaction works without requiring a full run.

### Pause-Safe Full-Screen Modal

- **Trigger:** A full-screen in-run UI must pause gameplay without resuming a pause already owned by progression, confirmation, or another modal.
- **Inputs:** Eligible run states, open/close InputMap actions, modal priority, current `SceneTree.paused` state, process mode, and the owning overlay scene/script.
- **Outputs:** A full-screen modal with an explicit pause lease, deterministic open/close eligibility, restoration of only the pause it acquired, and tests for already-paused and nested-modal cases.
- **Safety checks:** Never assign `get_tree().paused = false` unconditionally on close; reject conflicting opens before acquiring a lease; give the deepest confirmation first refusal of Cancel; preserve the prior game state and unrelated modal visibility.
- **Verification commands:**

  ```powershell
  $godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
  $project = (Get-Location).Path
  & $godot --headless --path $project --editor --quit-after 2
  & $godot --headless --path $project --script res://tests/test_runner.gd
  rg -n "RunPauseLease|is_action_pressed|paused" scripts/ui tests/unit
  git diff --check
  ```

### Registry-Backed Controller-Focusable Page Tabs

- **Trigger:** A multi-page Godot interface needs stable data-driven ordering, availability states, mouse/keyboard/controller parity, and disabled pages that still explain themselves.
- **Inputs:** Descriptor Resource schema, descriptor catalog, feature-gate policy, page-scene contract, InputMap actions, focus-neighbor rules, and required baseline page IDs.
- **Outputs:** Duplicate-safe ordered tabs, gate-resolved Hidden/Coming Soon/Preview/Available behavior, deterministic bumper cycling, focusable explanations for unavailable pages, and an initial focus target for every functional page.
- **Safety checks:** Validate IDs and scenes before instancing; exclude later duplicate IDs; never cycle to or directly activate hidden/Coming Soon pages; keep display order independent of scene-tree order; preserve focus when a page or selected record changes.
- **Verification commands:**

  ```powershell
  $godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
  $project = (Get-Location).Path
  & $godot --headless --path $project --editor --quit-after 2
  & $godot --headless --path $project --script res://tests/test_runner.gd
  rg -n "LedgerPageDefinition|LedgerPageCatalog|LedgerFeatureGate|focus_neighbor" scripts/ui scenes/ui tests/unit
  git diff --check
  ```

### Responsive Desktop and Compact Godot UI Testing

- **Trigger:** A container-based UI must remain readable and navigable at a desktop target and a smaller future pane or compact viewport.
- **Inputs:** Desktop and compact viewport sizes, explicit responsive threshold, minimum readable dimensions, overflow policy, detail-pane behavior, and focus-return expectations.
- **Outputs:** Deterministic layout modes, container/anchor assertions, overflow and containment evidence, focus restoration checks, and screenshots or live observations labeled with viewport dimensions.
- **Safety checks:** Test logical viewport size rather than monitor resolution alone; do not encode full-screen layout with physical pixel positions; require independent scrolling where content can overflow; verify hover/focus parity and that compact details return focus to their originating row.
- **Verification commands:**

  ```powershell
  $godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
  $project = (Get-Location).Path
  & $godot --headless --path $project --editor --quit-after 2
  & $godot --headless --path $project --script res://tests/test_runner.gd
  rg -n "COMPACT_WIDTH|COMPACT_HEIGHT|apply_compact|minimum_size|ScrollContainer" scripts/ui scenes/ui tests/unit
  git diff --check
  ```

### Read-Only UI Adapter over Resources and Resolver Snapshots

- **Trigger:** UI needs canonical definitions and live resolved values without owning gameplay math, walking the SceneTree, or reading private domain collections.
- **Inputs:** Resource registries, public manager queries, immutable/resolver snapshots and breakdowns, runtime-only callbacks, domain signals, and the page-facing record schema.
- **Outputs:** One read-only adapter that emits stable dictionaries or typed records for lists/details, canonical formatting and definitions, deliberate empty/missing states, and signal-driven refresh points.
- **Safety checks:** Do not duplicate resolver formulas or mutate domain state; do not inspect underscore-prefixed collections; format through canonical definitions/services; bound runtime-node queries and return conservative missing-data records; compare displayed effective values and sources to the source snapshot.
- **Verification commands:**

  ```powershell
  $godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
  $project = (Get-Location).Path
  & $godot --headless --path $project --editor --quit-after 2
  & $godot --headless --path $project --script res://tests/test_runner.gd
  rg -n "stats_for|breakdown|member_rows|stat_rows|stat_detail|upgrade_rows|upgrade_detail" scripts/ui tests/unit
  git diff --check
  ```

## Promotion Checklist

A candidate is ready to become a skill when:

- it has been used successfully more than once;
- its inputs and outputs are clear;
- failure modes and safety boundaries are known;
- verification can produce objective evidence;
- the workflow is broader than one Party Forge file or one isolated bug.
