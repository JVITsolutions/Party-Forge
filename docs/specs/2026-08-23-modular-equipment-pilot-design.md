# Party Forge Modular Equipment Pilot Design

**Status:** Approved for implementation on 2026-08-22 and amended on 2026-08-23 with expanded multi-angle review.

## Purpose

Prove a production-oriented character and equipment pipeline before replacing all 99 prototype equipment visuals. The pilot delivers two compatible humanoid bodies and the complete eleven-item Dawn Bulwark set, visually re-authored as **Sunweld Bastion**, while preserving Party Forge's gameplay IDs and runtime contracts.

The remaining 88 equipment visuals remain blocked until Jacob approves both bodies, all eleven equipped items, and the derived icon sheet.

## Approved decisions

- Both bodies use a close-fitting neutral underlayer instead of anatomical nudity.
- Masculine and feminine bodies share one canonical skeleton, height, bone lengths, rest pose, and animation library.
- Mesh silhouettes, faces, hair, and fitted wearable variants may differ between bodies.
- One gameplay item identity may reference multiple presentation fits. Rigid items should be shared when they fit both bodies; deforming wearables receive masculine and feminine variants.
- Fidelity target is stylized mid-detail: readable at Party Forge's high-angle camera without discarding the detail needed for inventory renders and close inspection.
- Item icons are rendered from the approved 3D master, not independently painted silhouettes.
- Blender 5.2 is the canonical cleanup, fitting, rig, render, and approval location. AI 3D Gen Studio produces candidates, not automatically approved masters.
- 3D Gen Studio auto-rigging may provide initial joints and weights, but generated rigs are candidates that must be retargeted/rebound and validated against `pf_humanoid_v1` before promotion.
- Existing prototype assets are preserved in a hashed baseline backup. They are not deleted or silently overwritten.
- Every asset is reviewed from enough views to expose its complete construction, not merely from a flattering hero angle.

## Stable gameplay identities

The pilot keeps these IDs byte-stable:

1. `dawn_bulwark_crown`
2. `dawn_bulwark_plate`
3. `dawn_bulwark_greaves`
4. `dawn_bulwark_gauntlets`
5. `dawn_bulwark_sabatons`
6. `dawn_bulwark_belt`
7. `sun_oath_amulet`
8. `ring_of_vigil`
9. `ring_of_mercy`
10. `sunforged_warhammer`
11. `dawn_bulwark_shield`

No affix, stat, rarity, drop, loadout, or class data changes are part of this visual pilot.

## Sunweld Bastion art direction

- Charcoal forged steel is the dominant structural material.
- Warm ivory cloth appears in protected gaps and the permanent underlayer.
- Antique gold is restrained to edges, fasteners, and status-defining motifs.
- Small amber sun-rune accents carry the magical identity.
- Forms favor broad, readable planes and a defensive silhouette over dense micro-detail.
- The hammer and shield remain distinguishable in the almost-isometric gameplay view.
- Jewelry must remain legible in icons even when its world model is intentionally subtle.

## Canonical humanoid contract

The versioned rig identity is `pf_humanoid_v1`.

- One canonical Skeleton3D hierarchy and bind pose owns deformation for both bodies.
- Both body meshes use identical world scale, origin, forward axis, height, and ground plane.
- The existing AnimationPlayer and its pivot-targeted tracks remain authoritative for the pilot. A direct `SkeletonModifier3D` child named `LegacyPivotSkeletonDriver` maps every canonical bone role to an existing animated pivot after AnimationPlayer evaluation. At validation time it captures each mapped pivot's rest transform in skeleton space. At runtime it converts the current pivot world transform into skeleton space, computes its delta from that captured pivot rest, applies the delta to the canonical bone global rest, converts the desired global result to parent-local space, then supplies only `canonical_local_rest.affine_inverse() * desired_local` to `set_bone_pose()`. This includes currently unmapped `HitPivot` and `BodyPivot` motion because mapped pivot globals include those ancestors. Modifier influence is fixed at 1.0 and is not manually blended in the callback. This bridge preserves every current action ID, duration, loop, method/event track, and release/impact timing without double-applying rest transforms.
- Native bone-track animation replacement is a later migration and is not required to approve this equipment pilot.
- The Godot-facing `ForgeHumanoidModel` API remains stable: body selection, palette, equipment application/clearing, action playback, grounding, bounds, sockets, and action events continue to work.
- Existing gameplay-facing wrapper paths remain available during migration. Imported Skeleton3D geometry sits below that wrapper; semantic socket resolution moves behind the public model API instead of leaking imported node names to gameplay code. `CharacterPresentation.set_body_preset()` must stage fit replacement and grounding validation before committing, or roll the complete body/equipment state back on failure.
- Gameplay wrappers such as CharacterBody3D, collision, targeting, health, and party ownership stay outside imported geometry.

Skinned equipment uses the actor's one canonical Skeleton3D. A staged wearable may contribute MeshInstance3D and Skin resources, but runtime promotion rebinds each mesh's skeleton path to the actor skeleton and validates three distinct signatures: canonical topology, canonical rest transforms quantized to 1e-6, and that Skin's ordered named binds plus bind-pose matrices quantized to 1e-6. Numeric-only or unnamed Skin binds are rejected; every bind name must uniquely resolve to a canonical bone. No equipped item may leave behind a second Skeleton3D or AnimationPlayer. Rigid equipment continues to attach through semantic sockets.

### Fit policy

Fit policy and attachment mode are independent. `fit_policy` is `shared` or `variant`; `attachment_mode` is `rigid_socket` or `shared_skin`.

| Slot | Fit policy | Attachment mode | Pilot expectation |
|---|---|---|---|
| helmet | shared unless fit review requires variant | rigid_socket | Crown must clear both heads/hair silhouettes |
| body_armour | variant | shared_skin | Separate masculine/feminine fitted plate meshes |
| legs | variant | shared_skin | Separate fitted greaves/leg armour meshes |
| gloves | variant unless a shared fit passes | shared_skin | Wrist/hand deformation must pass on both bodies |
| boots | variant unless a shared fit passes | shared_skin | Ankle and foot deformation must pass on both bodies |
| belt | shared unless fit review requires variant | rigid_socket | Must not float or cut through either waist |
| amulet | shared | rigid_socket | Bone-attached to upper torso/neck socket |
| rings | shared | rigid_socket | Attached to explicit left/right hand sockets |
| main_hand | shared | rigid_socket | Hammer uses the canonical hand grip and action origin |
| off_hand | shared | rigid_socket | Shield uses the canonical offhand grip/readability anchor |

Variant creation is evidence-driven. A second mesh is required when a shared mesh cannot pass fit and deformation review; it is not required merely because two body presets exist.

## Asset and wrapper layout

Source-of-truth working assets live outside Godot in an immutable pilot staging area:

`F:\Projects(root)\Game dev\Projects\party-forge-asset-staging\modular-equipment\pilot-0001\`

The Godot project receives reviewed exports only:

- `assets/models/characters/forge_humanoid/forge_humanoid_bodies.glb`
- eleven same-ID GLBs under `assets/models/equipment/dawn_bulwark/`
- the twelve source-adjacent `.glb.import` sidecars generated and reviewed by Godot
- `scenes/characters/presentation/forge_humanoid_model.tscn`
- `scenes/characters/presentation/forge_base_masculine.tscn`
- `scenes/characters/presentation/forge_base_feminine.tscn`
- the eleven same-ID wrappers under `scenes/equipment/dawn_bulwark/`
- the eleven same-ID resources under `data/presentation/equipment/dawn_bulwark/`
- existing 256px and 128px icon paths

Each `.tscn` equipment scene stays a stable gameplay-facing wrapper and instances its GLB below the root. Imported object names are never treated as gameplay IDs.

## Provenance manifest

`data/presentation/equipment_asset_manifest.v1.json` records one row per body or item. Required fields are:

- schema version and stable asset ID
- asset kind, set ID, slot IDs, fit policy, and body coverage
- generator, workflow, prompt hash, seed, and source-image hashes
- model name/version and license evidence
- content-addressed Blender revision ID/hash and Blender version
- GLB path/hash, canonical rig ID, topology hash, canonical-rest hash, and per-Skin bind hash
- fit policy, attachment mode, body coverage, hidden body-region IDs, dimensions, triangle count, material count, texture set, UV/tangent status, and skin-weight status
- master/runtime icon paths and hashes
- validation result, reviewer, review timestamp, and approval notes

The manifest contains fourteen rows: one `rig`, two `body`, and eleven `equipment`. Runtime paths are normalized `res://` paths. External provenance is represented by immutable attempt/revision IDs and hashes rather than machine-specific drive paths. The manifest validator fails closed on missing required fields, duplicate IDs, path escape, mismatched hashes, incomplete body coverage, or a topology/rest/Skin mismatch.

## Backup contract

Before replacing presentation assets, create a read-only baseline under:

`pilot-0001\baseline\legacy-equipment-v1\`

The builder reads from the explicit authoritative Party Forge working-tree root, even when that root is dirty, and never writes there. It records the complete source `git status` and hashes the bytes actually copied. It contains:

- all 99 current equipment scenes
- all 99 base definitions, all 99 canonical set presentation resources, and the eleven tracked top-level legacy Forge Vanguard presentation resources
- all 198 canonical icons and nine contact sheets
- both base-body scenes, the shared humanoid scene, profiles, and presentation scripts required to interpret the assets
- git commit, branch, dirty-status snapshot, relative path, size, and SHA-256 for every copied file

The untracked `scenes/equipment/test_equipment/` experiment is excluded and left untouched. Failed backup attempts remain immutable with a failure marker; no recursive cleanup is permitted in the external staging root. A validator must prove the backup file count and hashes before any promotion step.

### Backup threat model

This is a trusted local-workstation workflow. The backup must prevent accidental source writes, deletion, overwrite, path traversal, destination reuse, partial-copy promotion, stale Git metadata, and silent byte drift. Source and output must be explicit local absolute paths, the output must be outside the source checkout, every copied path must come from the exact inventory, and existing destination files must never be replaced.

An actively malicious local process changing junctions, drive aliases, filesystem objects, or helper-process state during the backup is out of scope. The builder does not need adversarial race resistance or a security boundary against another process with the user's filesystem permissions. Unexpected ordinary I/O or process failures still fail closed, preserve the bounded attempt when possible, and never trigger recursive cleanup.

## Icon contract

- Render from the approved 3D master using a fixed orthographic three-quarter camera and fixed neutral key/fill/rim lighting.
- Render a transparent 1024px intermediate into a revision-addressed staging directory.
- Downsample deterministically to the 256px master with Lanczos filtering.
- Derive the 128px runtime icon from the approved 256px master with Lanczos filtering.
- Preserve 16px master padding and 8px runtime padding.
- Do not paint, stretch, or redraw the silhouette independently of the master.
- Small exposure, color-management, and alpha cleanup are permitted when recorded in the manifest and applied deterministically.
- Produce separate eleven-item 256px and 128px contact sheets for human approval. Only exact approved staged files replace tracked icons; the existing tracked contact sheet remains the 128px grid.

## Technical budgets and gates

- Each visible body: 5,000-7,000 triangles target; 10,000 hard cap.
- Fully equipped character: 17,000-23,000 triangles target; 32,000 hard cap.
- Per-item target/hard triangle caps: crown 800/1,500; plate 2,200/3,500 per fit; greaves 1,500/2,500 per fit; gauntlets 1,200/2,000 per fit; sabatons 1,000/1,800 per fit; belt 600/1,200; amulet 500/1,000; each ring 250/500; hammer 1,000/2,000; shield 1,200/2,200.
- Body material slots: four maximum. Equipment material slots: four maximum for plate and three maximum for every other item. Fully equipped visible material slots: 24 hard cap.
- Texture limits: 2K maximum for bodies, plate, greaves, hammer, and shield; 1K maximum for the other items. Use a maximum of base color, normal, packed ORM, and emissive maps per material family.
- Skinned meshes: four bone weights maximum per vertex, no unweighted vertices, normalized weights, valid UV0, finite normals, and tangents whenever a normal map is used.
- Readability-anchor clearance: at least 0.06 m where the existing contract applies.
- Visible extent: at least 0.18 m for held readability-critical equipment.
- Arm/equipment AABB intersection: no more than 0.01 m3 for existing held-item checks.
- Ground gap: within 0.001 m after grounding refresh.
- Both body scenes remain between 1.60 m and 1.85 m in visible height unless a separately approved scale migration changes the gameplay contract.
- Every resource, GLB wrapper, icon, socket, action, and body preset must load and validate headlessly.

Triangle counts are budgets, not permission to retain hidden duplicate surfaces, non-manifold fragments, internal blades, or unused materials.

Each body exports exactly seventeen named skinned MeshInstance3D child nodes using the `BodyRegion__` prefix followed by one exact region ID for machine-verifiable coverage and visibility: `head`, `hair`, `neck`, `torso`, `upper_arm_left`, `upper_arm_right`, `forearm_left`, `forearm_right`, `hand_left`, `hand_right`, `hips`, `thigh_left`, `thigh_right`, `shin_left`, `shin_right`, `foot_left`, and `foot_right`. These node boundaries, not material names or Blender vertex-group names, are the runtime contract. The region nodes share no more than four body Material resources. Each fit descriptor names only the mesh roots for that body and declares `hide_body_regions`; runtime installs exactly those roots, applies region visibility transactionally, and restores it when the slot clears.

## Visual review matrix

### Standalone item review

Every item receives at least eight evenly spaced turntable views: front, front-right, right, rear-right, rear, rear-left, left, and front-left. Add top, underside, interior, edge, or close-up views whenever they expose otherwise hidden construction, texture seams, hollows, attachment surfaces, or material transitions.

### Equipped review

Each body and fit combination is reviewed in:

- neutral rest pose
- authored idle
- walk support and passing poses
- hit/flinch
- the relevant primary attack at anticipation, contact/release, follow-through, and recovery
- conventional third-person view, which is the default animation-review perspective
- Party Forge high-angle almost-isometric gameplay view
- front, three-quarter, side, and rear diagnostic views
- joint and attachment close-ups for wrists, ankles, neck, waist, hammer grip, and shield grip

The reviewer may require more views. Passing the minimum set never overrides a visible unresolved defect.

### Review output

Each review bundle contains deterministic filenames, camera metadata, body/fit ID, action/sample time, source hashes, images, contact sheets, and an explicit approval record. Local animation-video analysis may supplement this review but cannot replace human approval.

## Promotion sequence

1. Validate immutable backup and provenance foundation.
2. Approve both underlayer body masters and the canonical skeleton/bind pose.
3. Approve each Sunweld Bastion item master and necessary fit variants.
4. Approve standalone turntables and equipped multi-angle/body/action matrices.
5. Approve eleven-item 256px and 128px icon contact sheets.
6. Import reviewed GLBs behind stable Godot wrappers.
7. Pass focused contracts, full 202-suite-or-greater regression, headless visual capture, and an actual gameplay-camera review.
8. Obtain Jacob's explicit pilot approval.
9. Only then plan or begin the remaining 88 equipment replacements.

## Explicit non-goals

- Replacing the remaining 88 items before the pilot gate.
- Changing item balance, affixes, rarity, class loadouts, inventory behavior, or drop logic.
- Online services or paid generation APIs.
- Automatic promotion based only on AI generation or AI video review.
- Deleting prototype assets or the user's experimental scimitar files.
- Rebuilding Blender background automation or the retired approval-gate machinery.
