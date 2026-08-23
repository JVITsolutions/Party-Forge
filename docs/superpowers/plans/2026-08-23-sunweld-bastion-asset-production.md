# Sunweld Bastion Bodies and Equipment Asset Production Plan

> **Execution note:** Begin only after the immutable legacy backup and rig/fit contracts exist. Each asset is an atomic approval unit. Generated candidates never overwrite prior attempts.

**Goal:** Produce two approved `pf_humanoid_v1` bodies and eleven approved Sunweld Bastion equipment masters, including necessary body-fit variants and deterministic multi-angle evidence.

**Architecture:** FLUX/Qwen image workflows establish approved concepts where useful; 3D Gen Studio/TRELLIS creates candidates; Blender 5.2 performs topology cleanup, materials, canonical fitting, rigging, validation, and reviewed GLB export. Immutable attempt folders and provenance records preserve every promoted decision.

**Tech stack:** Local Asset Gen/3D Gen Studio, local FLUX/Qwen workflows, TRELLIS, Blender 5.2 through Blender MCP, GLB 2.0, Godot 4.7.1.

---

## Task 1: Create immutable pilot staging and capture tool versions

**Files outside repo:**

- Create: `F:\Projects(root)\Game dev\Projects\party-forge-asset-staging\modular-equipment\pilot-0001\README.md`
- Create directories: `concepts/`, `bodies/`, `equipment/`, `reviews/`, `exports/`, `provenance/`

**Step 1: Verify rather than duplicate installations**

Locate the existing 3D Gen Studio, ComfyUI, FLUX/Qwen, TRELLIS, Blender 5.2, and model caches. Record executable or repository version, workflow hash, model path/hash, and license source. Link to authoritative weights; do not copy them into pilot staging.

**Step 2: Define attempt allocation**

Every concept or model attempt uses `attempt-0001`, `attempt-0002`, and so on. An attempt directory is never rewritten after review. Promotion copies the exact approved source into a content-addressed revision directory below `exports/approved/` and records its hash. Mutable links are not approval evidence.

**Step 3: Record coordinate and render conventions**

Author in Blender meters with Blender `+Z` up, an explicitly recorded authoring-forward direction, and applied object transforms. Export through glTF's coordinate conversion. Validate imported Godot `+Y` up, forward `-Z`, ground at Y=0, and an identity presentation root. Record color management, GPU/driver, texture color space, render engine, Blender version, and exporter version.

## Task 2: Produce and approve the canonical body concepts

**Files outside repo:**

- Create: `concepts/bodies/masculine/attempt-*/`
- Create: `concepts/bodies/feminine/attempt-*/`
- Create: `provenance/body-concepts.json`

**Step 1: Generate orthographic-friendly body concept candidates**

Both concepts must show the same height and neutral A/T rest-pose proportions, permanent warm-ivory close-fitting underlayer, unobstructed hands/feet, and no loose accessories. Masculine and feminine silhouettes/faces may differ without changing canonical joint locations or limb lengths.

**Step 2: Review each candidate from front, rear, both sides, and both three-quarter views**

Reject inconsistent limbs, hidden hands, mismatched height, asymmetric rest pose, implausible joints, perspective distortion, or underlayer details that would interfere with armour.

**Step 3: Obtain Jacob's concept approval**

Record exact attempt IDs, source hashes, reviewer, and notes. Do not generate body meshes from an unapproved concept.

## Task 3: Produce, clean, and bind both body masters

**Files outside repo:**

- Create: `bodies/masculine/attempt-*/`
- Create: `bodies/feminine/attempt-*/`
- Create revision-addressed approved `.blend` and `.glb` copies below `exports/approved/bodies/` in a directory named by their exact SHA-256 revision

**Step 1: Generate multiple 3D candidates per approved concept**

Preserve raw output, workflow, seed, input image, mesh statistics, and textures. Prefer a candidate with coherent anatomy and surface flow over one whose apparent detail comes from noisy topology.

**Step 2: Inspect every candidate comprehensively**

Capture at least eight turntable angles plus top, underside/feet, face, hands, shoulders, hips, knees, and texture-seam close-ups. Inspect solid/wireframe, face orientation, non-manifold edges, disconnected components, duplicate internal shells, UVs, texture seams, and material assignments.

**Step 3: Clean the selected candidates in Blender 5.2**

Remove duplicate/internal/hidden generator debris, repair topology and normals, retopologize where deformation requires it, preserve silhouette, establish clean UVs/materials, and meet the 5k-7k triangle target or document why the result needs up to the 10k cap.

**Step 4: Bind both meshes to one canonical armature and stable regions**

Create one `pf_humanoid_v1` armature. Bind both meshes without changing bones, parentage, bone lengths, orientation, or rest transforms between bodies. Split each body into exactly seventeen named skinned MeshInstance3D exports using the `BodyRegion__` prefix and the exact design IDs; share no more than four body materials across those nodes. Store topology, 1e-6-quantized canonical-rest, per-Skin named-bind, and region-layout signatures in provenance.

**Step 5: Deformation review**

Test neutral, idle, walk support/passing, deep arm raise, elbow flexion, wrist rotation, hip flexion, knee flexion, hit/flinch, and representative melee attack poses. Review from third-person, Party Forge almost-isometric, front, side, rear, and joint close-ups.

**Step 6: Export and validate**

Export one reviewed GLB containing the canonical skeleton, both body meshes, underlayer materials, and stable body regions. Do not export replacement animations for this pilot: the tested Godot `LegacyPivotSkeletonDriver` drives the canonical skeleton from the current action/event library. Run the import-readiness validator before promotion.

**Step 7: Obtain Jacob's body/rig approval**

Both bodies and their shared rig are one approval gate. Record the exact `.blend` and `.glb` hashes.

## Task 4: Lock the eleven-item concept family

**Files outside repo:**

- Create one same-ID directory below `concepts/equipment/dawn_bulwark/` for each of the eleven stable IDs, with immutable `attempt-0001`, `attempt-0002`, and later attempt directories
- Create: `reviews/sunweld-bastion-concept-sheet/`

**Step 1: Create coordinated concept candidates**

Use the approved charcoal steel, ivory undercloth, antique gold, and amber-rune language. Produce separate, unobscured item presentations for all eleven IDs rather than one fused armour character.

**Step 2: Enforce item-specific readability**

- Crown: unmistakable defensive sun-crown profile without excessive vertical height.
- Plate: broad chest/shoulder defensive mass with clear ivory articulation gaps.
- Greaves: protected thigh/knee/shin read without merging into boots.
- Gauntlets: readable cuff, hand, and finger/mitten construction.
- Sabatons: grounded armoured foot silhouette with ankle articulation.
- Belt: structural waist piece, not a painted stripe.
- Amulet: distinct sun-oath centerpiece suitable for a close icon.
- Rings: Vigil and Mercy must be visually distinct at icon scale.
- Warhammer: one-handed proportions, clear grip, head orientation, and impact face.
- Shield: broad defensive silhouette, readable face motif, plausible hand/forearm mounting.

**Step 3: Review the family together**

Reject accidental scale changes, inconsistent gold/steel values, duplicated motifs that erase item identity, or details that disappear from the gameplay camera.

**Step 4: Obtain Jacob's concept-family approval**

Individual later mesh rejection does not invalidate approved family direction; it creates a new attempt for that item.

## Task 5: Produce deforming wearable masters

**Items:**

- `dawn_bulwark_plate`
- `dawn_bulwark_greaves`
- `dawn_bulwark_gauntlets`
- `dawn_bulwark_sabatons`

**For each item, execute this atomic sequence:**

1. Generate at least two candidates from the approved concept/multiview input.
2. Preserve raw meshes and provenance.
3. Inspect at least eight standalone angles, top/underside where relevant, interior, wireframe, normals, UV seams, and attachment boundaries.
4. Select and clean one master in Blender.
5. Produce masculine and feminine fitted/skinned variants from that same item identity.
6. Bind both variants to the unchanged `pf_humanoid_v1` armature.
7. Review both bodies in neutral, idle, walk, hit, and paladin hammer actions from third-person, almost-isometric, front, side, rear, and joint close-ups.
8. Measure triangle/material/texture budgets and visible intersections.
9. Export one item GLB containing clearly named masculine and feminine mesh roots, named shared-skin binds, stable hidden-region declarations, and topology/rest/per-Skin signatures. Record an explicit fit descriptor for each body containing that scene, only that body's mesh-root paths, and its hidden-region IDs. The GLB may contain an import skeleton needed to preserve Skin binds, but Godot's shared-skin binder must extract only the selected roots and install no duplicate Skeleton3D or AnimationPlayer.
10. Record source/master/export hashes and obtain item approval.

An item is incomplete until both fits pass. Do not defer the second fit until after Godot integration.

## Task 6: Produce rigid and semi-rigid wearable masters

**Items:**

- `dawn_bulwark_crown`
- `dawn_bulwark_belt`
- `sun_oath_amulet`
- `ring_of_vigil`
- `ring_of_mercy`

Apply the same candidate, cleanup, provenance, and multi-angle sequence. Test one shared rigid mesh on both bodies first. Create a body-specific variant only when objective fit review shows floating, clipping, scale, or deformation failure. Record `fit_policy` and `attachment_mode` independently.

Jewelry requires macro close-ups and icon-scale previews. Hidden backs, inner ring surfaces, clasp areas, and crown/belt interiors must be inspected even when they are rarely visible in gameplay.

## Task 7: Produce hammer and shield masters

**Items:**

- `sunforged_warhammer`
- `dawn_bulwark_shield`

**Step 1: Generate and clean standalone masters**

Inspect all eight turntable angles plus head/edge/underside/grip close-ups for the hammer and face/back/rim/grip/strap close-ups for the shield. Remove hidden duplicate shells and internal generator debris.

**Step 2: Establish canonical attachments**

Hammer exports include `ReadabilityAnchor` and `ActionOriginSocket`. Shield exports include the approved offhand attachment and readability anchor. Preserve item-owned material channels.

**Step 3: Action review**

Review idle, walk, anticipation, impact, follow-through, recovery, and hit poses on both bodies. Verify hand placement, shield forearm relationship, arm clearance, hammer impact-face direction, and silhouette in third-person and almost-isometric views.

**Step 4: Export, validate, and approve each item**

## Task 8: Assemble the final Blender pilot master

**Files outside repo:**

- Create a content-addressed `.blend` and eleven same-ID GLBs below `exports/approved/pilot/` in a directory named by the approved revision's exact SHA-256
- Create: `reviews/sunweld-bastion-final/manifest.json`

**Step 1: Assemble only exact approved revisions**

The master contains immutable copies of the approved body and item revisions. Do not use mutable links as approval evidence and do not overwrite a previous approved path.

**Step 2: Produce the final review matrix**

Include:

- at least eight standalone angles per item
- both bodies fully equipped
- both bodies with each deforming fit isolated
- default third-person and Party Forge almost-isometric views
- front, rear, side, and three-quarter diagnostics
- neutral, idle, walk, hit, and attack phase samples
- close-ups of every joint, attachment, obscured surface, hollow, and texture seam that warrants inspection
- solid, material, and selected wireframe evidence

**Step 3: Run technical validation**

Verify canonical signatures, finite transforms, origin/scale, stable body regions, per-fit hidden regions, design-specified per-item/body/full-loadout budgets, four-weights-per-vertex and zero-unweighted rules, UV0/normals/tangents, non-manifold/duplicate/internal geometry findings, socket presence, current action IDs/events through the pivot bridge, and deterministic GLB hashes.

**Step 4: Obtain final Blender-master approval**

This approval authorizes Godot import and icon rendering. It does not authorize the remaining 88 items.

## Completion criteria

- Both bodies and all eleven item masters have explicit approved revision IDs.
- All necessary fit variants are complete.
- Every asset has comprehensive multi-angle evidence and provenance.
- Final `.blend` and GLB hashes validate.
- No Godot production wrapper or icon has yet been promoted from an unapproved export.
