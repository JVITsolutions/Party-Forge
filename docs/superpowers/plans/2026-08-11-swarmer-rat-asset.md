# Party Forge Swarmer Rat Asset Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build, rig, animate, export, integrate, and visually approve a production low-poly giant rat that replaces Party Forge's Swarmer sphere without changing Swarmer gameplay balance.

**Architecture:** Blender 5.2 owns the editable source, palette, rig, animations, turntable review, and glTF export. Party Forge keeps `scenes/enemies/swarmer.tscn` as the gameplay-owned `CharacterBody3D` wrapper and consumes the imported visual through a direct `MeshInstance3D`, sibling skeleton/animation hierarchy, and a small presentation controller. Automated Blender and Godot contract tests fail closed on scale, triangle count, topology, node names, animation names, collision ownership, and gameplay-data drift.

**Tech Stack:** Blender 5.2.0 LTS through Blender MCP and `bpy`, glTF 2.0 GLB, Godot 4.7.1, GDScript, PowerShell, Party Forge focused/full test runners.

## Global Constraints

- Preserve the currently open building kit before changing Blender state: `C:\Users\Jacob\Documents\Codex\2026-08-11\usi\outputs\party_forge_asset_kit\party_forge_medieval_building_kit_master.blend` currently contains 1,490 objects.
- Work in the isolated Party Forge worktree `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\swarmer-rat-asset`, created at execution time; do not mutate unrelated user changes.
- Use Blender 5.2.0 LTS and Blender MCP for all live authoring and viewport review.
- Reserve `assets/models/enemies/source/swarmer_rat.blend` for editable source and `assets/models/enemies/swarmer_rat.glb` for the game exchange asset.
- Keep overall head-to-tail length at `1.22 m` and neutral ear-tip height at `0.61 m`, each within `0.02 m`.
- Keep the exported render mesh at or below `3,000` triangles after triangulation; target `2,400-2,700`.
- Keep feet on Blender `Z = 0`; Godot import must ground the rat at local `Y = 0`.
- Use the approved Wedge Runner silhouette, warm grey-brown palette, broad dark dorsal stripe, clean chunky fur tufts, amber eyes, incisors, and one nicked ear.
- Use one skinned mesh object named `MeshInstance3D`, no more than two rendered surfaces, and one compact armature.
- Export exactly `idle_sniff`, `scurry`, `pounce_bite`, `hit_react`, and `death_curl`; do not use gameplay root motion.
- Preserve the Swarmer's existing health, speed, experience, damage, cooldown, range, spawn weighting, targeting, and reward behavior.
- Keep the gameplay root, health component, collision, and combat scripts owned by `scenes/enemies/swarmer.tscn`; the imported GLB may not become the gameplay root.
- Review every final candidate from at least eight evenly spaced angles plus top-down gameplay, underside, wireframe, animation, grouped-pack, and live-arena views.
- Do not export Blender cameras, lights, turntable geometry, aura tests, measurement helpers, or other assets into the rat GLB.
- A timeout, silent Blender/Godot process, missing screenshot, or unreviewed contact sheet is blocked, not passed.

---

## File map

**Create:**

- `assets/models/enemies/source/swarmer_rat.blend` — editable Blender source containing export and review collections.
- `assets/models/enemies/swarmer_rat.glb` — selected-object glTF exchange asset.
- `assets/models/enemies/swarmer_rat_palette.png` — compact opaque palette texture when vertex colors do not survive import identically.
- `tools/blender/validate_swarmer_rat.py` — Blender-side geometry, scale, material, rig, and action validator.
- `tools/blender/render_swarmer_rat_qa.py` — deterministic eight-angle and diagnostic Blender renderer.
- `scripts/enemies/swarmer_rat_presentation.gd` — animation-priority adapter used only by the Swarmer wrapper.
- `tests/unit/test_swarmer_rat_asset_contract.gd` — GLB, scene, collision, presentation, and gameplay-data contract suite.
- `tests/integration/swarmer_rat_runtime_runner.gd` — grouped spawn, animation, damage flash, attack, and death smoke runner.
- `tools/render_swarmer_rat_visual_qa.gd` — Party Forge gameplay-camera/contact-sheet renderer.
- `docs/qa/swarmer-rat/` — reviewed Blender and Godot PNGs plus machine-readable manifests.
- `docs/qa/2026-08-11-swarmer-rat-validation.md` — final evidence and human visual-review record.

**Modify:**

- `scenes/enemies/swarmer.tscn` — replace sphere presentation and collision while retaining the gameplay root contract.
- `scripts/enemies/swarmer.gd` — drive presentation states without changing combat resolution.
- `scripts/enemies/enemy_actor.gd` — make damage flash palette-safe across the rat's approved rendered surfaces while retaining direct-child lookup.

**Do not modify:**

- `data/enemies/swarmer.tres`;
- `data/attacks/swarmer_contact.tres`;
- `scripts/game/spawn_schedule.gd`;
- `scripts/game/spawn_director.gd`.

---

### Task 1: Isolate the source and establish a failing asset contract

**Files:**

- Create: `tools/blender/validate_swarmer_rat.py`
- Create during Blender execution: `assets/models/enemies/source/swarmer_rat.blend`

**Interfaces:**

- Consumes: Blender 5.2 scene data and the exact object/action names in the approved specification.
- Produces: exit code `0` and a final `SWARMER_RAT_BLENDER_VALIDATION_OK` marker only when the candidate satisfies the Blender-side contract.

- [x] **Step 1: Create an isolated Party Forge worktree and record the baseline**

Use `superpowers:using-git-worktrees`, then run from the isolated checkout:

```powershell
git status --short --branch
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
& $godot --headless --path (Get-Location).Path --import
& $godot --headless --path (Get-Location).Path --script res://tests/test_runner.gd
```

Expected: the worktree is clean before this increment, the dedicated import completes before tests, and the baseline ends with `TEST_SUMMARY: PASS`. A fresh worktree without `.godot` import/class caches is not a valid test baseline. Record any pre-existing failure before asset work and do not relabel it as a rat regression.

- [x] **Step 2: Preserve the live building-kit file and start a separate rat source**

Through `mcp__blender__execute_blender_code`, execute this exact state transition:

```python
import bpy
from pathlib import Path

expected = Path(r"C:\Users\Jacob\Documents\Codex\2026-08-11\usi\outputs\party_forge_asset_kit\party_forge_medieval_building_kit_master.blend")
if Path(bpy.data.filepath) != expected:
    raise RuntimeError(f"Unexpected live Blender file: {bpy.data.filepath}")
bpy.ops.wm.save_as_mainfile(filepath=str(expected), check_existing=False)
bpy.ops.wm.read_factory_settings(use_empty=True)
rat_source = Path(r"F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\swarmer-rat-asset\assets\models\enemies\source\swarmer_rat.blend")
rat_source.parent.mkdir(parents=True, exist_ok=True)
bpy.context.scene.unit_settings.system = 'METRIC'
bpy.context.scene.unit_settings.length_unit = 'METERS'
bpy.context.scene.render.fps = 24
for name in ("PF_RAT_EXPORT", "PF_RAT_REVIEW"):
    collection = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(collection)
bpy.ops.wm.save_as_mainfile(filepath=str(rat_source), check_existing=False)
print(f"SWARMER_RAT_SOURCE_ISOLATED path={rat_source}")
```

Expected: the building kit saves first, the active Blender file becomes the new rat source in the reserved isolated worktree, and only the two named empty collections exist.

Execution note: `bpy.ops.wm.read_factory_settings(use_empty=True)` unregisters the live Blender MCP addon. Re-register it from Blender's Python Console with `import addon; addon.register()`, verify the socket, return the area to `VIEW_3D`, and save the isolated rat source before continuing.

- [x] **Step 3: Write the Blender validator before creating the rat**

Implement `tools/blender/validate_swarmer_rat.py` with these exact public constants and checks:

```python
import bpy
import bmesh
import json
import math
import sys
from mathutils import Vector

MESH_NAME = "MeshInstance3D"
RIG_NAME = "SwarmerRatRig"
EXPORT_COLLECTION = "PF_RAT_EXPORT"
REVIEW_COLLECTION = "PF_RAT_REVIEW"
EXPECTED_ACTIONS = {"idle_sniff", "scurry", "pounce_bite", "hit_react", "death_curl"}
MAX_TRIANGLES = 3000
TARGET_LENGTH = 1.22
TARGET_HEIGHT = 0.61
TOLERANCE = 0.02

errors = []
mesh_object = bpy.data.objects.get(MESH_NAME)
rig_object = bpy.data.objects.get(RIG_NAME)
export_collection = bpy.data.collections.get(EXPORT_COLLECTION)

if mesh_object is None or mesh_object.type != 'MESH':
    errors.append(f"missing mesh object {MESH_NAME}")
if rig_object is None or rig_object.type != 'ARMATURE':
    errors.append(f"missing armature {RIG_NAME}")
if export_collection is None:
    errors.append(f"missing collection {EXPORT_COLLECTION}")

report = {}
if mesh_object is not None and mesh_object.type == 'MESH':
    evaluated = mesh_object.evaluated_get(bpy.context.evaluated_depsgraph_get())
    evaluated_mesh = evaluated.to_mesh()
    evaluated_mesh.calc_loop_triangles()
    triangles = len(evaluated_mesh.loop_triangles)
    corners = [evaluated.matrix_world @ Vector(corner) for corner in evaluated.bound_box]
    xs = [corner.x for corner in corners]
    ys = [corner.y for corner in corners]
    zs = [corner.z for corner in corners]
    length = max(ys) - min(ys)
    height = max(zs) - min(zs)
    ground = min(zs)
    report.update(triangles=triangles, length=length, height=height, ground=ground)
    if triangles > MAX_TRIANGLES:
        errors.append(f"triangle cap exceeded: {triangles} > {MAX_TRIANGLES}")
    if abs(length - TARGET_LENGTH) > TOLERANCE:
        errors.append(f"length out of tolerance: {length:.4f}")
    if abs(height - TARGET_HEIGHT) > TOLERANCE:
        errors.append(f"height out of tolerance: {height:.4f}")
    if abs(ground) > 0.002:
        errors.append(f"feet not grounded: min_z={ground:.5f}")
    if len(mesh_object.material_slots) > 2:
        errors.append(f"too many rendered surfaces: {len(mesh_object.material_slots)}")
    armature_modifiers = [modifier for modifier in mesh_object.modifiers if modifier.type == 'ARMATURE']
    if len(armature_modifiers) != 1 or armature_modifiers[0].object != rig_object:
        errors.append("mesh requires exactly one SwarmerRatRig armature modifier")
    bm = bmesh.new()
    bm.from_mesh(mesh_object.data)
    if any(not edge.is_manifold for edge in bm.edges):
        errors.append("non-manifold edge found")
    if any(face.calc_area() <= 1e-10 for face in bm.faces):
        errors.append("zero-area face found")
    bm.free()
    evaluated.to_mesh_clear()

action_names = {action.name for action in bpy.data.actions}
missing_actions = sorted(EXPECTED_ACTIONS - action_names)
if missing_actions:
    errors.append(f"missing actions: {missing_actions}")
if mesh_object is not None:
    unweighted = [vertex.index for vertex in mesh_object.data.vertices if not vertex.groups]
    if unweighted:
        errors.append(f"unweighted vertices: {unweighted[:16]}")
if export_collection is not None:
    unexpected = sorted(obj.name for obj in export_collection.objects if obj.name not in {MESH_NAME, RIG_NAME})
    if unexpected:
        errors.append(f"unexpected export objects: {unexpected}")

print(json.dumps({"report": report, "errors": errors}, sort_keys=True))
if errors:
    raise SystemExit(1)
print("SWARMER_RAT_BLENDER_VALIDATION_OK")
```

- [x] **Step 4: Run the validator and prove that the empty source fails**

```powershell
$blender = 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
& $blender --factory-startup --background 'assets/models/enemies/source/swarmer_rat.blend' --python 'tools/blender/validate_swarmer_rat.py'
```

Expected: non-zero exit with missing `MeshInstance3D`, `SwarmerRatRig`, and the five actions. A passing empty file means the validator is defective. `--factory-startup` prevents a headless validation process from loading the globally enabled Blender MCP addon and competing with the live Blender session for port `9876`.

- [x] **Step 5: Commit the failing contract and source boundary**

```powershell
git add tools/blender/validate_swarmer_rat.py assets/models/enemies/source/swarmer_rat.blend docs/superpowers/specs/2026-08-11-swarmer-rat-asset-design.md docs/superpowers/plans/2026-08-11-swarmer-rat-asset.md
git commit -m "test: define swarmer rat asset contract"
```

---

### Task 2: Model and shade the approved Wedge Runner

**Files:**

- Modify: `assets/models/enemies/source/swarmer_rat.blend`
- Modify: `tools/blender/validate_swarmer_rat.py`
- Create: `assets/models/enemies/swarmer_rat_palette.png`

**Interfaces:**

- Consumes: the validator constants and approved Wedge Runner design.
- Produces: one grounded, manifold `MeshInstance3D` candidate and its two-surface material contract.

- [ ] **Step 1: Change the length contract and prove the current candidate fails**

In `tools/blender/validate_swarmer_rat.py`, change only the approved length constant:

```python
TARGET_LENGTH = 1.22
```

Run:

```powershell
$blender = 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
& $blender --factory-startup --background 'assets/models/enemies/source/swarmer_rat.blend' --python 'tools/blender/validate_swarmer_rat.py'
```

Expected: non-zero exit with `length out of tolerance` for the existing `0.91 m` candidate, plus the five expected missing actions. A pass before rebuilding means the length contract is defective.

- [ ] **Step 2: Rebuild the connected body/head blockout at the approved four-foot scale**

Use Blender MCP in small `bpy` steps. Preserve the approved head and shoulder dimensions while adding the extra foot through the rib cage and abdomen. Build the main form along Blender `-Y` forward from elliptical rings with 12 vertices per ring. Use this exact ring table `(y, center_z, radius_x, radius_z)`:

```python
BODY_RINGS = [
    (-0.38, 0.20, 0.045, 0.055),  # nose
    (-0.34, 0.22, 0.075, 0.075),  # muzzle
    (-0.28, 0.27, 0.115, 0.125),  # skull
    (-0.20, 0.31, 0.145, 0.155),  # neck
    (-0.10, 0.35, 0.185, 0.205),  # raised shoulders
    ( 0.08, 0.34, 0.180, 0.210),  # lengthened rib cage
    ( 0.28, 0.30, 0.150, 0.175),  # lengthened abdomen
    ( 0.43, 0.28, 0.115, 0.135),  # hips
    ( 0.53, 0.27, 0.078, 0.088),  # tail base
]
```

Bridge adjacent rings, cap the nose only, and leave the tail-base ring open for the tail. Bias top vertices on the shoulder and rib-cage rings upward enough to form an arched wedge without exceeding the final `0.61 m` ear-tip height.

- [ ] **Step 3: Rebuild distinct hind legs, separated paws, tail root, and chunky tufts**

Use six- or eight-sided tapered tubes for limbs and tail. Boolean-union each upper limb deeply into the torso and remove hidden internal faces. Keep the forelegs comparatively straight and slim. Build each rear leg as a folded Z silhouette: a large haunch, thigh angled forward to the knee, shin angled back to the hock, and a long rear paw extending forward. Use these neutral contact points:

```text
front paws: x = +/-0.15, center y = -0.205, min z = 0.00
front elbows: x = +/-0.16, y = -0.11, z = 0.17
rear hip/haunch centers: x = +/-0.14, y = 0.36, z = 0.30
rear knees: x = +/-0.20, y = 0.24, z = 0.17
rear hocks: x = +/-0.15, y = 0.45, z = 0.055
rear paws: x = +/-0.15, span y = 0.31 through 0.47, min z = 0.00
tail fur-to-skin transition: x = 0.015, y = 0.61, z = 0.235
tail end: x = 0.025, y = 0.80, z = 0.16
ear tips: left/right x near +/-0.10, y near -0.24, z = 0.61
```

Make one ear notch part of the silhouette mesh. Keep incisors, eyes, and the movable lower jaw as closed islands inside the same mesh object. Fuse every claw into its paw and sink each lower-leg endpoint into the paw volume. Add a short furred ankle cuff and a narrow dark crease above each dusty-pink paw so the skin color cannot visually merge into the leg. Build the tail as a thick furred root continuing the dorsal stripe through `y = 0.61`, then a smoothly tapered pink section with one restrained upward hook. Add three to five large cheek/shoulder/spine tufts, then remove any coplanar or unseen overlap. Do not add whisker geometry.

- [ ] **Step 4: Preserve the two-surface palette with explicit paw and tail transitions**

Create one opaque primary material named `PF_Rat_Primary` and one emissive eye material named `PF_Rat_Eyes`. The primary surface must carry all non-eye colors through one `64 x 64` nearest-filtered palette texture or verified vertex colors:

```text
main coat      #806E60
dorsal stripe  #463B35
light coat     #A58D79
skin           #C78482
teeth/claws    #D8CAA8
eyes           #D89A2B, restrained emission strength 0.6
```

Set high roughness, low metallic, full opacity, and no normal map. Paint/map the dorsal stripe broadly from forehead through shoulder ridge and across the furred tail root. Restrict dusty pink on the feet to the paw geometry below each ankle cuff. Save the palette to `assets/models/enemies/swarmer_rat_palette.png` if used.

- [ ] **Step 5: Normalize, triangulate for measurement, and run geometry checks**

Join all render islands into `MeshInstance3D`, apply transforms, recalculate outward normals, merge accidental doubles, and use weighted flat/smooth shading that preserves faceted planes. Add a non-destructive Triangulate modifier last. Temporarily create the armature object and modifier so the validator can measure the candidate; create placeholder normalized weights to `root` only, without calling the mesh rigged.

Run:

```powershell
$blender = 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
& $blender --factory-startup --background 'assets/models/enemies/source/swarmer_rat.blend' --python 'tools/blender/validate_swarmer_rat.py'
```

Expected at this stage: geometry, material, scale, grounding, and triangle checks pass; the only failures are the five missing actions until Task 3.

- [ ] **Step 6: Perform the revised eight-angle silhouette checkpoint**

Use the scalable turntable only in `PF_RAT_REVIEW`. Capture front, front-right, right, rear-right, rear, rear-left, left, front-left, and a camera-matched elevated view. Inspect shoulder-to-neck, grip-like limb connections, belly-to-floor clearance, folded rear-leg readability, ankle-cuff/paw separation, rump-to-tail connection, fur-to-skin tail transition, jaw, ear notch, and dorsal stripe. Include dedicated close-ups of both rear legs and the tail root. Show the contact sheet to the user and pause for approval before rigging.

Expected: the user either approves the mesh/colors or gives concrete revision notes. Apply revisions and repeat all nine views until approved.

- [ ] **Step 7: Save and commit the approved static candidate**

```powershell
git add assets/models/enemies/source/swarmer_rat.blend assets/models/enemies/swarmer_rat_palette.png tools/blender/validate_swarmer_rat.py
git commit -m "art: model approved swarmer rat silhouette"
```

Omit the PNG from `git add` only if verified vertex colors replace it and the GLB imports identically.

---

### Task 3: Rig and animate the rat

**Files:**

- Modify: `assets/models/enemies/source/swarmer_rat.blend`
- Modify: `tools/blender/validate_swarmer_rat.py`

**Interfaces:**

- Consumes: approved static `MeshInstance3D` and `SwarmerRatRig` placeholder.
- Produces: normalized skin weights and five exactly named in-place actions.

- [ ] **Step 1: Replace the placeholder rig with the production bone hierarchy**

Create these deform bones and parent relationships, using `.L`/`.R` symmetry:

```text
root
  pelvis
    spine_01 -> spine_02 -> shoulders -> neck -> head -> jaw
    thigh.L -> shin.L -> rear_paw.L
    thigh.R -> shin.R -> rear_paw.R
    tail_01 -> tail_02 -> tail_03 -> tail_04 -> tail_05 -> tail_06 -> tail_07 -> tail_08
  shoulders
    upper_arm.L -> forearm.L -> front_paw.L
    upper_arm.R -> forearm.R -> front_paw.R
```

Keep `root` fixed at ground origin. Put limb joints at the visible elbow/knee bends and tail bones through the geometric centerline. The jaw pivots at the rear of the lower jaw.

- [ ] **Step 2: Paint and validate normalized weights**

Weight torso rings between adjacent spine bones, keep muzzle and skull primarily on `head`, bind the lower-jaw island entirely to `jaw`, and distribute each tail ring only across its two neighboring tail bones. Limit each deforming vertex to four influences. Deep shoulder/hip attachment vertices blend between torso and limb bones; paw contact vertices remain dominated by paw bones.

Run Blender's normalize-all and clean operations at threshold `0.001`, then verify there are no unweighted vertices and no weight sums outside `1.0 +/- 0.001`.

- [ ] **Step 3: Author the exact in-place clips**

Use 24 fps and these action ranges:

```text
idle_sniff    frames 1-48, loop
scurry        frames 1-16, loop
pounce_bite   frames 1-24, non-loop
hit_react     frames 1-12, non-loop
death_curl    frames 1-36, non-loop
```

Key `idle_sniff` at frames `1, 12, 24, 36, 48`; `scurry` at `1, 5, 9, 13, 16`; `pounce_bite` at `1, 6, 11, 15, 24`; `hit_react` at `1, 4, 8, 12`; and `death_curl` at `1, 10, 20, 30, 36`. Duplicate first loop poses at the final loop frame. Keep root translation zero in every action. The bite is maximally open at frame 11 and visually contacts at frame 15. The death ends grounded on one side with the tail curled inward.

- [ ] **Step 4: Extend the validator for weight sums, root motion, and clip ranges**

Add exact checks for:

```python
EXPECTED_RANGES = {
    "idle_sniff": (1.0, 48.0),
    "scurry": (1.0, 16.0),
    "pounce_bite": (1.0, 24.0),
    "hit_react": (1.0, 12.0),
    "death_curl": (1.0, 36.0),
}
```

For each action, reject a mismatched `frame_range`; reject any `root` location F-curve with a non-zero key value; reject vertex weight totals outside tolerance; and reject any vertex with more than four positive influences.

- [ ] **Step 5: Run the complete Blender contract**

```powershell
$blender = 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
& $blender --background 'assets/models/enemies/source/swarmer_rat.blend' --python 'tools/blender/validate_swarmer_rat.py'
```

Expected: exit `0`, JSON report at `2,400-2,700` target triangles or a documented lower count that still passes visual review, and `SWARMER_RAT_BLENDER_VALIDATION_OK`.

- [ ] **Step 6: Review representative animation frames and commit**

Capture neutral plus every named key frame listed in Step 3. Inspect ground contacts, shoulder/hip volume, jaw seam, eye/teeth stability, tail continuity, and silhouette from the gameplay angle. Correct any defect, rerun the validator, then commit:

```powershell
git add assets/models/enemies/source/swarmer_rat.blend tools/blender/validate_swarmer_rat.py
git commit -m "art: rig and animate swarmer rat"
```

---

### Task 4: Export GLB and produce Blender visual-QA evidence

**Files:**

- Create: `assets/models/enemies/swarmer_rat.glb`
- Create: `tools/blender/render_swarmer_rat_qa.py`
- Create: `docs/qa/swarmer-rat/blender-eight-angle.png`
- Create: `docs/qa/swarmer-rat/blender-animation-contact-sheet.png`
- Create: `docs/qa/swarmer-rat/blender-manifest.json`

**Interfaces:**

- Consumes: validated Blender source with `PF_RAT_EXPORT` and `PF_RAT_REVIEW` separation.
- Produces: one selected-object GLB and deterministic review images/manifests.

- [ ] **Step 1: Export only the rat collection**

Through Blender MCP, hide `PF_RAT_REVIEW`, select only `MeshInstance3D` and `SwarmerRatRig`, verify all five actions have stashed NLA tracks or exporter-visible action slots, and run:

```python
bpy.ops.export_scene.gltf(
    filepath=r"F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\swarmer-rat-asset\assets\models\enemies\swarmer_rat.glb",
    export_format='GLB',
    use_selection=True,
    export_yup=True,
    export_animations=True,
    export_skins=True,
    export_morph=False,
    export_cameras=False,
    export_lights=False,
)
```

Expected: the GLB contains the mesh, armature, materials, skin, and five actions only. Reopen the GLB in a fresh temporary Blender file and rerun equivalent bounds, triangle, material, and action-name checks against the exported result.

- [ ] **Step 2: Write the deterministic Blender QA renderer**

`tools/blender/render_swarmer_rat_qa.py` must:

- render transparent `512 x 512` frames using a fixed orthographic camera and neutral three-light rig;
- render azimuths `0, 45, 90, 135, 180, 225, 270, 315` degrees at a constant elevation;
- render top-down, underside, and wireframe diagnostics;
- render every key frame listed in Task 3;
- assemble the named contact sheets without timestamps;
- write `blender-manifest.json` with Blender version, source path, triangle count, bounds, materials, actions, camera angles, and output paths;
- print `SWARMER_RAT_BLENDER_QA_OK views=11 actions=5` only after every PNG is nonblank.

- [ ] **Step 3: Render, inspect, and record the Blender checkpoint**

```powershell
$blender = 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
& $blender --background 'assets/models/enemies/source/swarmer_rat.blend' --python 'tools/blender/render_swarmer_rat_qa.py'
```

Expected: `SWARMER_RAT_BLENDER_QA_OK views=11 actions=5`. Open both contact sheets at original resolution. Record explicit pass/fail notes for all eight angles, top-down readability, underside closure, wireframe cleanliness, jaw, shoulders, belly, hips, paws, tail connection, dorsal stripe, and every animation.

- [ ] **Step 4: Show the exported candidate to the user in live Blender**

Use Blender MCP viewport screenshots from the user's current viewing direction plus at least the front, rear, side, and top-down diagnostic angles. Pause for user approval. If revised, update the source, rerun Tasks 3-4 validators/renders, and replace the GLB and evidence with the approved candidate.

- [ ] **Step 5: Commit the exact approved export and evidence**

```powershell
git add assets/models/enemies/swarmer_rat.glb assets/models/enemies/swarmer_rat_palette.png tools/blender/render_swarmer_rat_qa.py docs/qa/swarmer-rat
git commit -m "art: export and review swarmer rat"
```

---

### Task 5: Integrate the rat behind the Swarmer gameplay wrapper

**Files:**

- Create: `scripts/enemies/swarmer_rat_presentation.gd`
- Create: `tests/unit/test_swarmer_rat_asset_contract.gd`
- Modify: `scenes/enemies/swarmer.tscn`
- Modify: `scripts/enemies/swarmer.gd`
- Modify: `scripts/enemies/enemy_actor.gd`

**Interfaces:**

- Consumes: imported `swarmer_rat.glb` with the exact mesh, skeleton, material, and animation names.
- Produces: `SwarmerRatPresentation.play_locomotion(bool)`, `play_attack()`, `play_hit()`, and `play_death() -> float`, plus a gameplay-owned Swarmer scene with unchanged combat data.

- [ ] **Step 1: Write the failing Godot asset contract**

Create `tests/unit/test_swarmer_rat_asset_contract.gd` with a `run() -> Array[String]` suite that asserts:

```gdscript
extends RefCounted

const REQUIRED_ANIMATIONS: Array[StringName] = [
    &"idle_sniff", &"scurry", &"pounce_bite", &"hit_react", &"death_curl",
]

func run() -> Array[String]:
    var failures: Array[String] = []
    TestAssertions.truthy(ResourceLoader.exists("res://assets/models/enemies/swarmer_rat.glb"), "rat GLB exists", failures)
    var scene := load("res://scenes/enemies/swarmer.tscn") as PackedScene
    TestAssertions.truthy(scene != null, "swarmer scene loads", failures)
    if scene == null:
        return failures
    var enemy := scene.instantiate() as CharacterBody3D
    TestAssertions.truthy(enemy != null, "swarmer remains CharacterBody3D", failures)
    if enemy == null:
        return failures
    TestAssertions.truthy(enemy.is_in_group("hostile_actors"), "swarmer remains hostile actor", failures)
    TestAssertions.truthy(enemy.get_node_or_null("HealthComponent") is HealthComponent, "health component preserved", failures)
    TestAssertions.truthy(enemy.get_node_or_null("MeshInstance3D") is MeshInstance3D, "direct mesh contract preserved", failures)
    var collision := enemy.get_node_or_null("CollisionShape3D") as CollisionShape3D
    TestAssertions.truthy(collision != null and collision.shape is CapsuleShape3D, "torso capsule replaces sphere", failures)
    var animation_player := enemy.find_child("AnimationPlayer", true, false) as AnimationPlayer
    TestAssertions.truthy(animation_player != null, "rat animation player exists", failures)
    if animation_player != null:
        var names := animation_player.get_animation_list()
        for animation_name: StringName in REQUIRED_ANIMATIONS:
            TestAssertions.truthy(names.has(animation_name), "animation %s imported" % animation_name, failures)
    var definition := enemy.get("definition") as EnemyDefinition
    TestAssertions.near(definition.max_health, 12.0, 0.001, "health unchanged", failures)
    TestAssertions.near(definition.move_speed, 4.8, 0.001, "speed unchanged", failures)
    TestAssertions.equal(definition.experience, 2, "experience unchanged", failures)
    var attack := definition.attack_by_id(&"swarmer_contact")
    TestAssertions.near(attack.cooldown, 0.8, 0.001, "cooldown unchanged", failures)
    TestAssertions.near(attack.range, 0.9, 0.001, "range unchanged", failures)
    TestAssertions.equal(attack.damage_components.size(), 1, "one damage component preserved", failures)
    if attack.damage_components.size() == 1:
        TestAssertions.equal(attack.damage_components[0].damage_type_id, &"physical", "physical damage type unchanged", failures)
        TestAssertions.near(attack.damage_components[0].base_amount, 8.0, 0.001, "damage unchanged", failures)
    enemy.free()
    return failures
```

- [ ] **Step 2: Run the focused test and verify the pre-integration failure**

```powershell
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
& $godot --headless --path (Get-Location).Path --script res://tests/focused_test_runner.gd -- res://tests/unit/test_swarmer_rat_asset_contract.gd
```

Expected: `TEST_SUMMARY: FAIL` because the scene still contains a `SphereMesh`, `SphereShape3D`, and no imported animation player.

- [ ] **Step 3: Add the presentation adapter**

Implement `scripts/enemies/swarmer_rat_presentation.gd` as one focused adapter:

```gdscript
class_name SwarmerRatPresentation
extends Node

@export var animation_player_path: NodePath
var _locked := false
var _dead := false

@onready var _player := get_node(animation_player_path) as AnimationPlayer

func play_locomotion(moving: bool) -> void:
    if _dead or _locked or _player == null:
        return
    var desired: StringName = &"scurry" if moving else &"idle_sniff"
    if _player.current_animation != desired:
        _player.play(desired, 0.08)

func play_attack() -> void:
    _play_locked(&"pounce_bite", 0.04)

func play_hit() -> void:
    if not _dead:
        _play_locked(&"hit_react", 0.02)

func play_death() -> float:
    _dead = true
    _locked = true
    if _player == null or not _player.has_animation(&"death_curl"):
        return 0.0
    _player.play(&"death_curl", 0.03)
    return _player.get_animation(&"death_curl").length

func _play_locked(animation_name: StringName, blend: float) -> void:
    if _player == null or not _player.has_animation(animation_name):
        return
    _locked = true
    _player.play(animation_name, blend)
    if not _player.animation_finished.is_connected(_on_animation_finished):
        _player.animation_finished.connect(_on_animation_finished)

func _on_animation_finished(animation_name: StringName) -> void:
    if animation_name != &"death_curl":
        _locked = false
```

- [ ] **Step 4: Replace the scene presentation while retaining ownership boundaries**

Import the GLB, create or edit the inherited visual hierarchy so the primary skinned body is the direct child `MeshInstance3D`, and keep its referenced `Skeleton3D` and `AnimationPlayer` under the Swarmer wrapper. The final owned node tree must be:

```text
Swarmer (CharacterBody3D)
  HealthComponent
  MeshInstance3D (skinned rat body, direct child)
  Skeleton3D
  AnimationPlayer
  RatPresentation (SwarmerRatPresentation)
  CollisionShape3D (horizontal CapsuleShape3D around torso)
```

Set the mesh's skeleton path to the sibling `Skeleton3D`. Set `RatPresentation.animation_player_path` to `../AnimationPlayer`. Fit the capsule to the chest/abdomen only, rotate it horizontally along the body axis, and exclude tail, ears, claws, and muzzle. Do not copy the GLB root over the `CharacterBody3D` root.

- [ ] **Step 5: Drive presentation without changing combat outcomes**

In `swarmer.gd`, cache `RatPresentation`, call `play_locomotion(not velocity.is_zero_approx())` after target/velocity resolution, call `play_attack()` only after a valid contact result, and connect an additional health-change callback that calls `play_hit()` only when health decreases and the rat is not dead.

Override `defeat()` in `Swarmer` to preserve the base method's idempotence, immediate reward drop, stopped velocity, and health state; disable collision; play `death_curl`; wait its returned duration; then `queue_free()`. Do not delay or duplicate the reward. Add a focused test covering two defeat calls and exactly one reward.

In `enemy_actor.gd`, retain the direct `MeshInstance3D` lookup but duplicate and flash every material surface on that mesh. Cache/restore the original per-surface albedo colors so the coat palette and eye emission survive the flash. Do not change hit timing or health rules.

- [ ] **Step 6: Run the asset and existing combat suites**

```powershell
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
& $godot --headless --path (Get-Location).Path --script res://tests/focused_test_runner.gd -- res://tests/unit/test_swarmer_rat_asset_contract.gd res://tests/unit/test_enemy_typed_combat.gd res://tests/unit/test_final_review.gd
```

Expected: `TEST_SUMMARY: PASS (0 failures)` with the exact health, speed, experience, cooldown, range, and damage assertions unchanged.

- [ ] **Step 7: Commit the integrated wrapper**

```powershell
git add scenes/enemies/swarmer.tscn scripts/enemies/swarmer.gd scripts/enemies/enemy_actor.gd scripts/enemies/swarmer_rat_presentation.gd tests/unit/test_swarmer_rat_asset_contract.gd
git commit -m "feat: replace swarmer sphere with animated rat"
```

---

### Task 6: Add runtime visual QA and complete final verification

**Files:**

- Create: `tests/integration/swarmer_rat_runtime_runner.gd`
- Create: `tools/render_swarmer_rat_visual_qa.gd`
- Create: `docs/qa/swarmer-rat/godot-gameplay-contact-sheet.png`
- Create: `docs/qa/swarmer-rat/godot-animation-contact-sheet.png`
- Create: `docs/qa/swarmer-rat/godot-manifest.json`
- Create: `docs/qa/2026-08-11-swarmer-rat-validation.md`

**Interfaces:**

- Consumes: the exact integrated Swarmer scene and five animation clips.
- Produces: runtime smoke markers, gameplay-scale contact sheets, final reviewed evidence, and a merge-ready candidate.

- [ ] **Step 1: Write the grouped runtime smoke runner**

`tests/integration/swarmer_rat_runtime_runner.gd` must instantiate at least twelve Swarmers under one root, arrange them in a compact pack with varied facing, and assert:

- every instance owns a direct `MeshInstance3D`, torso capsule, skeleton, animation player, and presentation adapter;
- idle and moving rats select `idle_sniff` and `scurry` respectively;
- one valid contact attack still removes the existing expected health amount;
- a damage event produces a visible flash and restores the approved material values;
- `defeat()` drops exactly one reward, disables collision, plays `death_curl`, and releases the node after the clip;
- the runner emits `SWARMER_RAT_RUNTIME_OK count=12 animations=5` and exits `0`.

- [ ] **Step 2: Run the runtime smoke test**

```powershell
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
& $godot --headless --path (Get-Location).Path --script res://tests/integration/swarmer_rat_runtime_runner.gd
```

Expected: `SWARMER_RAT_RUNTIME_OK count=12 animations=5`, no parser/import errors, and exit `0`.

- [ ] **Step 3: Build the gameplay-camera QA renderer**

`tools/render_swarmer_rat_visual_qa.gd` must use a `SubViewport`, the current Party Forge camera angle/FOV, neutral arena lighting, and the actual `swarmer.tscn`. It must capture:

- one rat from the eight compass facings at gameplay distance;
- one close three-quarter frame;
- one twelve-rat pack with varied facing;
- representative frames of all five animations;
- one white damage-flash frame and one restored-palette frame;
- nonblank PNG checks and a JSON manifest containing scene path, GLB path, imported animation names, AABB, camera transform, rat count, frame labels, and output paths.

Print `SWARMER_RAT_GODOT_VISUAL_QA_OK directions=8 pack=12 animations=5` only after all captures and the contact sheets are written.

- [ ] **Step 4: Cold-import and render the exact candidate**

Use an isolated temporary import cache or move only the worktree's `.godot` cache to a verified temporary location before this command; do not delete a broad directory. Then run:

```powershell
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
& $godot --headless --path (Get-Location).Path --editor --quit-after 120
& $godot --headless --path (Get-Location).Path --script res://tools/render_swarmer_rat_visual_qa.gd
```

Expected: the import process exits `0`, the renderer prints `SWARMER_RAT_GODOT_VISUAL_QA_OK directions=8 pack=12 animations=5`, and both contact sheets are nonblank.

- [ ] **Step 5: Perform live Blender and Party Forge visual review**

Open the final rat source in the user's Blender 5.2 session and show it from the user's current viewing direction plus all eight required angles. Launch Party Forge visibly and inspect the rat alone and in a twelve-rat pack through the real gameplay camera. Reject flicker, gaps, floating feet, bad intersections, clipped jaw/teeth, unreadable facing, lost dorsal stripe, wrong scale, palette changes after damage, animation snapping, or a bruiser-like silhouette.

Record each reviewed angle and each animation as an explicit pass/fail entry in `docs/qa/2026-08-11-swarmer-rat-validation.md`. Obtain the user's final visual approval.

- [ ] **Step 6: Run focused tests, the complete suite, and repository checks**

```powershell
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
& $godot --headless --path (Get-Location).Path --script res://tests/focused_test_runner.gd -- res://tests/unit/test_swarmer_rat_asset_contract.gd res://tests/unit/test_enemy_typed_combat.gd res://tests/unit/test_final_review.gd
& $godot --headless --path (Get-Location).Path --script res://tests/integration/swarmer_rat_runtime_runner.gd
& $godot --headless --path (Get-Location).Path --script res://tests/test_runner.gd
git diff --check
git status --short
```

Expected: every command exits `0`; focused and full runs end in `TEST_SUMMARY: PASS`; the runtime marker is present; `git diff --check` is silent; only intentional rat files, QA evidence, and documentation remain changed.

- [ ] **Step 7: Record evidence and commit the completed increment**

The validation document must record exact commands, exit codes, Blender/Godot versions, triangle count, dimensions, material count, animation names/ranges, imported node tree, collision bounds, eight-angle review results, contact-sheet paths, pack count, user approval, focused/full test summaries, and any explicitly deferred work.

```powershell
git add tests/integration/swarmer_rat_runtime_runner.gd tools/render_swarmer_rat_visual_qa.gd docs/qa/swarmer-rat docs/qa/2026-08-11-swarmer-rat-validation.md
git commit -m "test: validate swarmer rat in gameplay"
git status --short --branch
```

Expected: a clean implementation worktree after the final commit. Use `superpowers:requesting-code-review` and `superpowers:verification-before-completion` before offering integration options.

---

## Final acceptance checklist

- Blender source remains independently editable and the prior building-kit file is preserved.
- Rat bounds are `1.22 m` long and `0.61 m` tall within `0.02 m`.
- Exported mesh is at or below `3,000` triangles and has at most two rendered surfaces.
- Mesh is grounded, manifold, outward-facing, clean of duplicate/degenerate/coplanar geometry, and fully weighted.
- Wedge Runner silhouette, broad dorsal stripe, palette, fur tufts, amber eyes, incisors, and nicked ear match the approved design.
- All five exact animation names import and play; no action contains gameplay root motion.
- `swarmer.tscn` remains the gameplay root and owns its health, collision, scripts, groups, and combat identity.
- Direct-child `MeshInstance3D` damage flash works and restores every approved surface color.
- Existing Swarmer gameplay numbers and spawn behavior are unchanged.
- Blender and Godot eight-angle, top-down, underside, wireframe, animation, pack, and live-arena reviews pass.
- The user gives final visual approval.
- Focused tests, runtime smoke, cold import, full suite, and `git diff --check` pass from the exact candidate.
