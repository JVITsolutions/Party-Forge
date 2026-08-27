# Dawn Bulwark Plate Fit Proof Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce and review one armor-only Sunweld Bastion plate master plus masculine and feminine fitted derivatives that reuse the validated Party Forge body skeletons without importing anything into Party Forge.

**Architecture:** Keep all generated assets, helper code, tests, and evidence in the external immutable pilot staging root. Establish skeleton-reuse feasibility with a synthetic carrier before final concept or mesh generation, then run Qwen concept work, TRELLIS.2 armor generation, deterministic body-envelope fitting, SkinTokens skin-only binding, structural validation, and human review as separately gated units.

**Tech Stack:** Python 3.13 from the installed 3D Gen Studio rig environment, `unittest`, NumPy, trimesh, Pillow, pygltflib 1.16.5 installed into the pilot-local dependency directory, 3D Gen Studio 2.4.1, managed ComfyUI 0.33.0, Qwen Image/Edit 2511/2512, TRELLIS.2-4B, SkinTokens rig service on `127.0.0.1:8300`, GLB 2.0.

## Global Constraints

- Authoritative game checkout: `F:\Projects(root)\Game dev\Projects\party-forge`.
- External pilot root: `F:\Projects(root)\Game dev\Projects\party-forge-asset-staging\modular-equipment\pilot-0001`.
- Do not modify, import into, run an import against, or write generated sidecars into the Party Forge checkout.
- Preserve the validated masculine body rig at `bodies\masculine\rigging\attempt-0002\output\pf_humanoid_v1_masculine_body_master_rigged_mixamo_attempt_0002.glb`.
- Preserve the validated feminine body rig at `bodies\feminine\rigging\attempt-0001\output\pf_humanoid_v1_feminine_body_master_rigged_mixamo_attempt_0001.glb`.
- Both body rigs must remain GLB 2.0 assets with one skin, 52 Mixamo-compatible joints, `JOINTS_0`, `WEIGHTS_0`, inverse bind matrices, and zero embedded animations.
- No Blender application, Blender MCP, manual Blender authoring, production retopology, or production import is authorized.
- The SkinTokens service's existing internal transfer implementation is allowed only through the 3D Gen Studio rig service; do not invoke Blender directly.
- Generated and edited attempts are immutable. A failed or rejected attempt receives the next `attempt-NNNN` directory.
- The armor-only master remains unchanged after selection; body fits are derived artifacts.
- The plate uses charcoal steel, restrained antique gold, warm-ivory articulation gaps, amber sun-runes, a fitted cuirass/backplate, separate collar, modest pauldrons, and layered waist plates.
- This proof records triangle/material counts but does not enforce the final 3,500-triangle plate cap.
- Stop at each human approval gate. Do not infer approval from technical success.
- External staging is not a Git repository. Each external task ends with exclusive-write JSON, SHA-256 hashes, and a verification command instead of a Git commit.
- The unrelated untracked Party Forge plan `docs/superpowers/plans/2026-08-27-resumable-run-recovery-and-profile-deletion.md` belongs to another task and must remain untouched.

---

## File Map

All paths in this section are relative to the external pilot root unless explicitly prefixed with the Party Forge checkout.

- `tools/attempt_records.py`: exclusive attempt allocation, canonical JSON writing, and SHA-256 helpers.
- `tests/test_attempt_records.py`: immutability and hash tests for attempt records.
- `.python_deps/`: pilot-local `pygltflib` installation; never copy it into Party Forge.
- `tools/glb_carrier.py`: construct a skeleton-bearing armor GLB and strip reference-body geometry after skinning.
- `tests/test_glb_carrier.py`: synthetic GLB merge, index-remap, and extraction tests.
- `tools/skin_only_probe.py`: call the local SkinTokens SSE endpoint with `use_skeleton=true` and preserve its exact result.
- `tests/test_skin_only_probe.py`: local HTTP contract test using an in-process deterministic SSE server.
- `reviews/plate-fit-skeleton-reuse-feasibility-0001.json`: immutable feasibility verdict.
- `concepts/equipment/dawn_bulwark/dawn_bulwark_plate/reference-prompts.v1.json`: approved equipped and isolated prompts.
- `tools/reference_manifest.py`: validate the five-view reference package and its hashes.
- `tests/test_reference_manifest.py`: missing-view, inconsistent-ID, and byte-drift tests.
- `concepts/equipment/dawn_bulwark/dawn_bulwark_plate/<view>/attempt-NNNN/`: immutable Qwen concept attempts.
- `reviews/dawn_bulwark_plate-reference-sheet/attempt-NNNN/`: reference contact sheet and approval record.
- `tools/plate_master_validator.py`: armor-only GLB structural and geometric validation.
- `tests/test_plate_master_validator.py`: synthetic clean, body-contaminated, degenerate, and internal-duplicate cases.
- `equipment/dawn_bulwark/dawn_bulwark_plate/master/attempt-NNNN/`: immutable TRELLIS.2 candidates.
- `reviews/dawn_bulwark_plate-master/attempt-NNNN/`: selected-master evidence and approval.
- `tools/plate_fit.py`: deterministic body-envelope alignment and masculine/feminine fitting.
- `tests/test_plate_fit.py`: synthetic shell fitting, symmetry, clearance, and source-immutability tests.
- `equipment/dawn_bulwark/dawn_bulwark_plate/fits/<body>/attempt-NNNN/`: unskinned and rigged fit outputs.
- `tools/plate_skin_validator.py`: validate exact skeleton, skin, weights, node identities, and absence of body/animation data.
- `tests/test_plate_skin_validator.py`: valid and deliberately corrupted GLB cases.
- `tools/plate_review_sheet.py`: deterministic labeled contact sheets from captured review frames.
- `tests/test_plate_review_sheet.py`: ordering, dimensions, labels, and byte-stability tests.
- `reviews/dawn_bulwark_plate-fit-proof/attempt-NNNN/`: final evidence bundle and user approval record.

---

### Task 1: Immutable attempt records and authorization

**Files:**
- Create: `tools/attempt_records.py`
- Create: `tests/test_attempt_records.py`
- Create: `reviews/dawn-bulwark-plate-fit-proof-authorization-0001.json`

**Interfaces:**
- Produces: `sha256_file(path: Path) -> str`, `allocate_attempt(parent: Path) -> Path`, and `write_json_exclusive(path: Path, payload: dict) -> None`.
- Produces: an immutable authorization record that permits the bounded plate fit proof and explicitly denies Party Forge import and Blender work.

- [ ] **Step 1: Write the failing attempt-record tests**

```python
class AttemptRecordTests(unittest.TestCase):
    def test_allocate_attempt_uses_first_unused_zero_padded_number(self):
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            (root / "attempt-0001").mkdir()
            self.assertEqual(allocate_attempt(root).name, "attempt-0002")

    def test_write_json_exclusive_refuses_overwrite(self):
        with tempfile.TemporaryDirectory() as raw:
            path = Path(raw) / "record.json"
            write_json_exclusive(path, {"schema_version": 1})
            with self.assertRaises(FileExistsError):
                write_json_exclusive(path, {"schema_version": 2})

    def test_sha256_file_matches_known_bytes(self):
        with tempfile.TemporaryDirectory() as raw:
            path = Path(raw) / "payload.bin"
            path.write_bytes(b"party-forge")
            self.assertEqual(
                sha256_file(path),
                "501129db565235004bfbfb0b7607b1dca80840542eaf534e388d1195facaad1a",
            )
```

- [ ] **Step 2: Run the test and verify the missing module failure**

Run:

```powershell
& 'C:\Users\Jacob\AppData\Local\Packages\OpenAI.Codex_2p2nqsd0c76g0\LocalCache\Roaming\3DGenStudio\rig-venv\Scripts\python.exe' -m unittest tests.test_attempt_records -v
```

Expected: FAIL because `tools/attempt_records.py` does not exist.

- [ ] **Step 3: Implement the attempt-record helpers**

```python
import hashlib
import json
from pathlib import Path


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def allocate_attempt(parent: Path) -> Path:
    parent = Path(parent)
    parent.mkdir(parents=True, exist_ok=True)
    index = 1
    while (parent / f"attempt-{index:04d}").exists():
        index += 1
    destination = parent / f"attempt-{index:04d}"
    destination.mkdir(exist_ok=False)
    return destination


def write_json_exclusive(path: Path, payload: dict) -> None:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("x", encoding="utf-8", newline="\n") as handle:
        json.dump(payload, handle, indent=2, sort_keys=True)
        handle.write("\n")
```

- [ ] **Step 4: Run the attempt-record tests**

Expected: three tests PASS.

- [ ] **Step 5: Write the authorization record exclusively**

The JSON must record `status: authorized`, the approved design commit `eda1c0a`, the two exact rigged-body paths and SHA-256 hashes, `equipment_fitting_authorized: true`, `party_forge_import_authorized: false`, and `blender_work_authorized: false`.

- [ ] **Step 6: Verify the record and source hashes**

Run a Python one-liner using `sha256_file` and compare masculine `8f589e35f16f02fe4aa0f45b5f2c85377a41f9ecc188670bf59159518e6cdbe4` and feminine `173198e3d044418b9765971e8b698664176c05dadd6a5aaa4ddb8df8d4c08667`.

Expected: both hashes match and the authorization file exists once.

---

### Task 2: Existing-skeleton reuse feasibility gate

**Files:**
- Create: `.python_deps/`
- Create: `tools/glb_carrier.py`
- Create: `tests/test_glb_carrier.py`
- Create: `tools/skin_only_probe.py`
- Create: `tests/test_skin_only_probe.py`
- Create: `reviews/plate-fit-skeleton-reuse-feasibility-0001.json`

**Interfaces:**
- Consumes: the approved body GLBs and `attempt_records` helpers.
- Produces: `build_skeleton_carrier(body_glb: Path, armor_glb: Path, output_glb: Path, mode: str) -> dict`.
- Produces: `extract_plate_only(rigged_glb: Path, output_glb: Path) -> dict`.
- Produces: `run_skin_only_probe(input_glb: Path, output_glb: Path, service_url: str) -> dict`.
- Gate: stop the entire plan if neither skeleton-only nor reference-body carrier mode returns a separable, 52-joint armor result.

- [ ] **Step 1: Install the one pilot-local GLB dependency**

Run:

```powershell
& 'C:\Users\Jacob\AppData\Local\Packages\OpenAI.Codex_2p2nqsd0c76g0\LocalCache\Roaming\3DGenStudio\rig-venv\Scripts\python.exe' -m pip install --target 'F:\Projects(root)\Game dev\Projects\party-forge-asset-staging\modular-equipment\pilot-0001\.python_deps' 'pygltflib==1.16.5'
```

Record the installed package metadata, local file hashes, MIT license text, and command output under `provenance/dependencies/pygltflib-1.16.5/`.

- [ ] **Step 2: Write synthetic carrier tests**

Tests must create a two-bone skinned reference mesh and a separate box-shaped armor mesh, then assert:

```python
report = build_skeleton_carrier(body, armor, carrier, mode="skeleton_only")
self.assertEqual(report["joint_count"], 2)
self.assertEqual(report["plate_nodes"], ["PlateFit__KEEP"])
self.assertEqual(report["reference_body_nodes"], [])

report = build_skeleton_carrier(body, armor, carrier, mode="reference_body")
self.assertEqual(report["reference_body_nodes"], ["ReferenceBody__REMOVE_AFTER_SKIN"])

extract = extract_plate_only(rigged, plate_only)
self.assertEqual(extract["removed_reference_nodes"], 1)
self.assertEqual(extract["remaining_plate_nodes"], 1)
```

- [ ] **Step 3: Run the carrier tests and verify failure**

Expected: FAIL because `glb_carrier` does not exist.

- [ ] **Step 4: Implement GLB carrier composition**

Add the pilot-local `.python_deps` directory to `sys.path`, then use `pygltflib.GLTF2` to load both GLBs. Append the armor binary blob on a four-byte boundary; remap armor buffer-view offsets and all armor accessor, material, texture, image, sampler, mesh, node, and scene indices; preserve the body skin, joint nodes, inverse-bind accessor, hierarchy, and node transforms. In `skeleton_only` mode remove mesh references from body mesh nodes. In `reference_body` mode rename body mesh nodes `ReferenceBody__REMOVE_AFTER_SKIN`. Name inserted armor nodes `PlateFit__KEEP`. Write to a new path only.

The implementation must raise `ValueError` on multiple body skins, absent joints, embedded armor skins, embedded armor animations, non-finite node transforms, or an output that fails a reload check.

- [ ] **Step 5: Run carrier tests**

Expected: PASS, including reload and node-name assertions.

- [ ] **Step 6: Write the SSE client contract test**

Start an in-process `ThreadingHTTPServer` that accepts multipart form data at `/meshes/rig`, asserts `use_skeleton` is true, and returns progress plus a base64 GLB result. Assert the client writes the decoded bytes exclusively and returns the final stats.

- [ ] **Step 7: Implement `run_skin_only_probe`**

POST multipart fields `meshFile`, `options`, and `format` to `http://127.0.0.1:8300/meshes/rig`. Use this exact options object:

```json
{
  "use_transfer": true,
  "use_postprocess": false,
  "rename_bones": "mixamo",
  "use_skeleton": true,
  "keep_loaded": false,
  "top_k": 5,
  "top_p": 0.95,
  "temperature": 1.0,
  "repetition_penalty": 2.0,
  "num_beams": 10
}
```

Parse SSE frames until `type=done` or `type=error`, enforce a 45-minute request timeout, decode `mesh_b64`, and write the result using exclusive creation.

- [ ] **Step 8: Run client tests**

Expected: PASS without starting the GPU service.

- [ ] **Step 9: Create a low-cost synthetic torso shell**

Use trimesh primitives to create six disconnected armor sections around the masculine body torso bounds. Export this diagnostic asset under `equipment/dawn_bulwark/dawn_bulwark_plate/feasibility/attempt-0001/` and record its hash.

- [ ] **Step 10: Run the exact feasibility probe**

Start the 3D Gen Studio rig service only. Verify `GET http://127.0.0.1:8300/health` returns `status=ok`. Run `skeleton_only` carrier mode once. If it fails because the parser ignores an unreferenced skin, run `reference_body` carrier mode once. Do not make a third GPU attempt in this task.

- [ ] **Step 11: Validate and record the feasibility verdict**

Pass only when the extracted diagnostic plate reloads as GLB 2.0, has one skin, exactly 52 Mixamo joints, `JOINTS_0`, `WEIGHTS_0`, no reference-body mesh, no animations, and no unexpected second skeleton. Write the exact attempt, input/output hashes, service settings, and failure text when applicable.

- [ ] **Step 12: Stop or continue at the gate**

If feasibility fails, stop this plan and ask Jacob whether to authorize a different fitting tool. If it passes, stop the rig service, confirm auto-start remains false, and continue.

---

### Task 3: Plate reference package and concept approval

**Files:**
- Create: `concepts/equipment/dawn_bulwark/dawn_bulwark_plate/reference-prompts.v1.json`
- Create: `tools/reference_manifest.py`
- Create: `tests/test_reference_manifest.py`
- Create attempts below: `concepts/equipment/dawn_bulwark/dawn_bulwark_plate/`
- Create review bundle below: `reviews/dawn_bulwark_plate-reference-sheet/`

**Interfaces:**
- Produces: `validate_reference_manifest(manifest_path: Path) -> dict` with exact required views `equipped`, `front`, `rear`, `profile`, and `three_quarter`.
- Produces: five approved, identity-consistent concept images and one approval record.

- [ ] **Step 1: Write manifest validation tests**

Assert a valid five-view manifest passes, a missing view fails, duplicate paths fail, mismatched asset IDs fail, and byte drift from a recorded SHA-256 fails.

- [ ] **Step 2: Run tests and verify the missing module failure**

Expected: FAIL because `reference_manifest.py` does not exist.

- [ ] **Step 3: Implement the validator**

Require `schema_version=1`, `asset_id=dawn_bulwark_plate`, exact view names, existing PNG paths inside the pilot root, unique paths, positive dimensions, consistent `concept_family_id`, and matching SHA-256 values.

- [ ] **Step 4: Run validator tests**

Expected: PASS.

- [ ] **Step 5: Write the exact prompt package**

The equipped prompt must request the approved masculine neutral T-pose body wearing only the heavy articulated Sunweld Bastion cuirass. The four isolated prompts must request the same empty wearable shell on a neutral gray studio background, with charcoal forged steel, restrained antique-gold fasteners and edges, warm-ivory articulation gaps, amber sun-runes, separate collar, modest separate pauldrons, and layered waist plates. Every prompt must reject helmets, gloves, weapons, shields, body anatomy, people, mannequins, text, watermarks, cropped edges, oversized pauldrons, dense filigree, and fused openings.

- [ ] **Step 6: Generate equipped concept candidates**

Use 3D Gen Studio project `1787537617058` and the installed Qwen image workflow. Generate four candidates into a new equipped attempt, preserving prompt, workflow path/hash, prompt ID, seed when exposed, duration, output path, dimensions, and SHA-256.

- [ ] **Step 7: Select the equipped identity**

Create a four-candidate contact sheet. Stop for Jacob to select one exact image before generating isolated views.

- [ ] **Step 8: Generate isolated views from the selected identity**

Use `Edit Image with QwenImageEdit2511.json` for front, rear, profile, and three-quarter views. Generate at least two candidates per view. Preserve every rejected attempt.

- [ ] **Step 9: Build and validate the reference manifest**

Run `reference_manifest.py` and save its report beside the contact sheet.

- [ ] **Step 10: Human concept gate**

Stop for Jacob to approve one exact equipped image and four exact isolated images. Record reviewer, timestamp, notes, relative paths, and hashes. No TRELLIS generation begins without this approval.

---

### Task 4: TRELLIS armor-only master generation and selection

**Files:**
- Create: `tools/plate_master_validator.py`
- Create: `tests/test_plate_master_validator.py`
- Create attempts below: `equipment/dawn_bulwark/dawn_bulwark_plate/master/`
- Create review bundles below: `reviews/dawn_bulwark_plate-master/`

**Interfaces:**
- Consumes: the approved isolated reference manifest.
- Produces: `inspect_plate_master(armor_path: Path, body_path: Path) -> dict`.
- Produces: one approved armor-only working master and a logical component map.

- [ ] **Step 1: Write master-validator tests**

Use trimesh fixtures to assert a clean six-part upper-body shell passes, a full humanoid contaminant fails, an animation-bearing GLB fails, a skin-bearing GLB fails, non-finite vertices fail, degenerate faces fail, and fewer than six connected components fail.

- [ ] **Step 2: Run tests and verify failure**

Expected: FAIL because `plate_master_validator.py` does not exist.

- [ ] **Step 3: Implement structural inspection**

Load with trimesh and a minimal GLB JSON reader. Report geometry count, connected components, vertices, faces, extents, materials, skins, animations, degenerate faces, non-finite values, and suspicious node names. Compare normalized extents against the masculine body bounds and fail when a component extends through head, hands, pelvis, or legs after torso alignment.

- [ ] **Step 4: Run master-validator tests**

Expected: PASS.

- [ ] **Step 5: Generate two armor-only TRELLIS candidates**

Use 3D Gen Studio's `Gen MultiView Mesh Only with Trellis2` route with background removal enabled and only the four isolated armor images. Generate two high-detail candidates in distinct immutable attempts. Do not use the equipped concept as a mesh input.

- [ ] **Step 6: Run automated inspection**

Preserve validation JSON for both candidates. Technical failure removes a candidate from human selection but does not delete it.

- [ ] **Step 7: Capture comprehensive standalone evidence**

Capture front, front-right, right, rear-right, rear, rear-left, left, front-left, top, underside, interior, collar opening, shoulder openings, waist opening, and wireframe views. Record camera and source hashes.

- [ ] **Step 8: Map logical components**

Write `component-map.json` mapping exact geometry or connected-component IDs to `cuirass`, `backplate`, `collar`, `pauldron_left`, `pauldron_right`, and `waist_plates`. Fail the candidate if those roles cannot be separated without reconstruction.

- [ ] **Step 9: Human master gate**

Stop for Jacob to select one exact working master. Record the candidate hash, component map hash, review evidence, and known defects. The selected source remains immutable.

---

### Task 5: Deterministic masculine and feminine fitting

**Files:**
- Create: `tools/plate_fit.py`
- Create: `tests/test_plate_fit.py`
- Create outputs below: `equipment/dawn_bulwark/dawn_bulwark_plate/fits/masculine/`
- Create outputs below: `equipment/dawn_bulwark/dawn_bulwark_plate/fits/feminine/`

**Interfaces:**
- Consumes: approved armor master, component map, and one approved body GLB.
- Produces: `fit_plate_to_body(master_path: Path, body_path: Path, component_map_path: Path, output_path: Path, clearance_m: float = 0.03) -> dict`.
- Guarantee: the source master bytes remain unchanged.

- [ ] **Step 1: Write synthetic fitting tests**

Create masculine and feminine ellipsoid torso fixtures plus a six-part shell. Assert the outputs remain symmetric, preserve six component identities, clear the body envelope by at least 0.02 m at sampled torso points, keep pauldron ordering, preserve materials, contain no body vertices, and leave the source hash unchanged.

- [ ] **Step 2: Run tests and verify failure**

Expected: FAIL because `plate_fit.py` does not exist.

- [ ] **Step 3: Implement body-envelope sampling**

Use Y-up normalized body coordinates. Sample 21 horizontal torso bands between 42% and 86% of visible body height. Exclude arm vertices beyond the central 32% of body height in X when measuring torso width. Record robust X and Z percentiles per band and linearly interpolate missing bands.

- [ ] **Step 4: Implement component-aware fitting**

Center the master on the body torso, scale its vertical span into the sampled torso range, and apply smoothly interpolated X/Z scale factors per vertex. Apply equal-and-opposite X offsets to left and right pauldrons, preserve collar and waist ordering, and add the requested clearance along the radial X/Z direction. Do not mutate the input scene.

- [ ] **Step 5: Run fitting tests**

Expected: PASS with source-hash equality.

- [ ] **Step 6: Create the masculine fit**

Allocate a new attempt, run `fit_plate_to_body`, save the unskinned GLB and report, and run `plate_master_validator` against it.

- [ ] **Step 7: Create the feminine fit**

Repeat from the same immutable master and the feminine body. Do not derive the feminine fit from the masculine fitted output.

- [ ] **Step 8: Capture neutral-fit evidence**

Capture both bodies wearing their unskinned aligned shells in front, three-quarter, side, rear, collar, armpit, shoulder, and waist views. Stop if either fit has structural floating or clipping before spending GPU time on skinning.

---

### Task 6: Skin-only binding to the validated body skeletons

**Files:**
- Modify: `tools/glb_carrier.py`
- Reuse: `tools/skin_only_probe.py`
- Create: `tools/plate_skin_validator.py`
- Create: `tests/test_plate_skin_validator.py`
- Create rigged outputs beneath both body-fit attempt directories.

**Interfaces:**
- Consumes: one unskinned fitted plate and its corresponding validated body rig.
- Produces: one plate-only GLB using the body's 52 named joints and bind transforms.
- Produces: `validate_plate_skin(plate_glb: Path, body_glb: Path) -> dict`.

- [ ] **Step 1: Write skin-validator tests**

Assert pass for one skin with 52 uniquely named matching joints, inverse bind matrices, `JOINTS_0`, normalized `WEIGHTS_0`, four influences maximum, no unweighted vertices, no animations, plate nodes only, and rest matrices matching the body within `1e-6`. Assert failure for each violated condition.

- [ ] **Step 2: Run tests and verify failure**

Expected: FAIL because `plate_skin_validator.py` does not exist.

- [ ] **Step 3: Implement the skin validator**

Parse GLB JSON and binary accessors without altering the file. Compare ordered joint names and inverse-bind matrices to the corresponding body GLB. Decode weights, check finiteness, normalize sums within `1e-5`, reject more than four nonzero influences, reject zero-weight vertices, and reject any mesh/node name matching `body`, `human`, `referencebody`, or the approved body asset IDs.

- [ ] **Step 4: Run skin-validator tests**

Expected: PASS.

- [ ] **Step 5: Bind the masculine plate once**

Build the carrier with the feasibility-approved mode. Start the rig service, call `run_skin_only_probe` with `keep_loaded=false`, extract the plate-only result, validate it, and preserve all SSE progress plus hashes. Do not retry automatically after a technical failure.

- [ ] **Step 6: Bind the feminine plate once**

Repeat against the feminine validated rig. Keep the two body-specific results as derivatives of the same armor master.

- [ ] **Step 7: Verify the pair**

Both reports must show exact 52/52 names and rest-transform parity, no body meshes, no embedded animations, and source lineage back to the same armor master hash.

- [ ] **Step 8: Stop the rig service**

Confirm `rigtools.autoStart=false` and verify GPU memory is released before review capture.

---

### Task 7: Deformation review, final evidence, and approval gate

**Files:**
- Create: `tools/plate_review_sheet.py`
- Create: `tests/test_plate_review_sheet.py`
- Create: `reviews/dawn_bulwark_plate-fit-proof/attempt-NNNN/`

**Interfaces:**
- Consumes: the two validated plate fits and their matching body rigs.
- Produces: deterministic labeled PNG sheets and one immutable approval record.

- [ ] **Step 1: Write review-sheet tests**

Generate colored fixture frames and assert fixed ordering, 384-pixel cells, labels, padding, output dimensions, and identical SHA-256 across two runs.

- [ ] **Step 2: Run tests and verify failure**

Expected: FAIL because `plate_review_sheet.py` does not exist.

- [ ] **Step 3: Implement deterministic sheet composition**

Use Pillow with a bundled font path recorded in the manifest. Sort frames by explicit `body`, `pose`, and `view` order rather than filesystem order. Write PNG with fixed compression and no timestamp metadata.

- [ ] **Step 4: Run review-sheet tests**

Expected: PASS with byte-identical outputs.

- [ ] **Step 5: Capture required deformation states**

For both bodies capture neutral, walk support, walk passing, forward arm raise, overhead arm raise, torso twist, and representative melee stance. For each state capture front, three-quarter, side, rear, Party Forge high-angle, collar close-up, armpit close-up, shoulder close-up, and waist close-up.

- [ ] **Step 6: Build the evidence bundle**

Include source/fitted/rigged hashes, validator reports, frame manifests, camera metadata, contact sheets, tool versions, service settings, and known limitations. Verify every referenced relative path stays inside the pilot root.

- [ ] **Step 7: Run final technical verification**

Run all pilot unit tests with the rig environment Python. Re-run both `plate_skin_validator` reports and compare the immutable body source hashes. Confirm `git -C 'F:\Projects(root)\Game dev\Projects\party-forge' status --short` contains no files created or modified by this plan.

- [ ] **Step 8: Human approval gate**

Show Jacob the armor-only master sheet plus both fitted deformation sheets. Record one of `approved`, `revision_requested`, or `rejected` with reviewer notes and exact hashes. Only `approved` authorizes a separate production-preparation design; it still does not authorize Party Forge import or the other ten items.

---

## Plan completion conditions

- Skeleton reuse passed before final concept generation.
- One equipped and four isolated concept references were explicitly approved.
- One armor-only master was explicitly approved and remained byte-immutable.
- Masculine and feminine fits came directly from the same master.
- Both plate derivatives matched their corresponding validated 52-bone skeleton names and rest transforms.
- Required structural, skin, deformation, and provenance checks passed.
- Jacob reviewed the final evidence and recorded an explicit verdict.
- Party Forge remained unmodified and no Godot import or direct Blender work occurred.
