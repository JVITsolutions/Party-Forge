# Party Forge Swarmer Rat Asset Design

Date: 2026-08-11

Status: Approved design

This document defines the first production 3D enemy asset for Party Forge: a stylized low-poly giant rat that replaces the current Swarmer sphere while preserving the existing Swarmer gameplay wrapper and behavior.

## Goal

Create a feral, fast-reading giant rat suitable for Party Forge's high-angle gameplay camera and dense enemy groups. The rat must look like a finished game asset rather than a placeholder, remain inexpensive enough to spawn in packs, and retain an editable Blender source for later variants.

The asset is a Wedge Runner: a hunched quadruped with raised shoulders, a low forward head, narrow hips, and a trailing tail that visually points along its direction of travel.

## Approved decisions

- The rat replaces the enemy currently identified as `swarmer`; it does not introduce a second enemy type.
- Total nose-to-tail length is approximately `0.91 m` (3 ft), including the tail.
- Neutral-pose height is approximately `0.61 m` (2 ft) to the ear tips.
- The final exported asset must not exceed `3,000` triangles after triangulation.
- The preferred working target is `2,400-2,700` triangles, leaving a hard-budget safety margin.
- Use a hunched quadruped stance with an arched back, raised shoulders, low head, and rear legs folded for a pounce.
- Use the approved Wedge Runner silhouette rather than the heavier Cellar Scrapper or more irregular Bristleback alternatives.
- Use clean faceted surfaces with a few chunky fur tufts at the cheeks, shoulders, and upper spine.
- Use a feral face with small amber eyes, exposed incisors, and one nicked ear.
- Use a warm grey-brown coat, a broad dark dorsal stripe, lighter facial and underside planes, dusty-pink extremities, and aged ivory teeth and claws.
- Preserve real animal recognition. Do not add fantasy horns, armor, clothing, exposed bone, magical runes, or overt mutation to the base asset.
- Author the rat as a reusable independent asset. The Swarmer scene consumes it; the asset does not own gameplay logic.
- Review the rat from at least eight evenly spaced angles before approval, in addition to the actual Party Forge gameplay camera.

## Scope

Included:

- Blender 5.2 editable source;
- game-ready low-poly rat mesh and materials;
- clean deformable topology;
- rat skeleton and skin weights;
- movable jaw and articulated tail;
- five authored animation clips;
- glTF 2.0 `.glb` export;
- a reusable Godot visual scene or imported visual hierarchy;
- replacement of the current Swarmer sphere presentation;
- collision fit appropriate to the torso;
- Blender turntable and eight-angle visual review;
- Party Forge gameplay-camera and grouped-enemy review;
- topology, scale, animation, import, and runtime verification.

Deferred:

- alternate coat colors, diseased or magical variants;
- elite-specific geometry;
- gore, wounds, blood, or dismemberment;
- bespoke particles, aura, sound, or voice work;
- changes to Swarmer health, speed, damage, reward, spawn weighting, navigation, or targeting;
- root-motion gameplay;
- procedural rat generation;
- LOD meshes unless profiling later proves they are required.

## Silhouette and proportions

The neutral pose is a compressed, forward-driving crouch rather than a standing show pose. The shoulder mass is the visual peak, and the body tapers toward the hips. The head sits below the shoulders and projects forward so the entire upper contour forms a wedge aimed at the player.

Target dimensions in Blender and Godot units:

- overall nose-to-tail length: `0.91 m`, measured with the neutral tail pose;
- nose-to-rump body length: approximately `0.64 m`;
- tail contribution beyond the rump: approximately `0.27 m`;
- ground to ear-tip height: approximately `0.61 m`;
- maximum torso width: approximately `0.34-0.38 m`;
- feet rest on local `Y = 0`;
- asset origin is centered beneath the torso at ground level.

The forequarters use larger paws and more mass than the hindquarters. Rear legs remain visibly long but folded beneath the body. The paws receive short readable claws without long needle-like projections. The tail leaves the rump in a mostly straight line with one subtle upward hook; it may not coil into the torso silhouette.

The ears are slightly oversized to maintain rat recognition from above. One ear has a single large notch, implemented as silhouette geometry rather than a transparency mask. Fur tufts are large, sparse, and integral to the body mesh. They may not become thin cards or a noisy saw-tooth outline.

## Face and character

The expression is feral and animalistic:

- a low wedge-shaped muzzle;
- small amber eyes set far enough apart to remain visible from the gameplay camera;
- a restrained emissive eye response, not a large fantasy glow;
- two prominent upper incisors in aged ivory;
- a movable lower jaw that can open during the bite;
- faceted cheek tufts that widen the head near the ears;
- a muted pink nose with no separate fragile whisker geometry.

The rat should look hungry, quick, and willing to attack in numbers. It should not read as a tank, pet, comic mascot, or supernatural boss.

## Color and material treatment

The approved palette is:

- main coat: warm grey-brown;
- dorsal stripe: dark charcoal-brown from forehead across the raised spine to the tail base;
- secondary coat: lighter warm brown on muzzle, cheeks, chest, and belly planes;
- skin: muted dusty pink on ears, nose, paws, and segmented tail;
- hard details: aged ivory teeth and claws;
- eyes: amber with low-intensity emission.

The broad dorsal stripe is a gameplay readability feature. It must remain visible from the high-angle camera and help show facing direction when multiple rats overlap.

Materials are matte and stylized. Do not use realistic fur shaders, strand hair, transparency, wet gloss, or high-frequency procedural noise. Prefer a compact palette texture or vertex-color solution and no more than two rendered surfaces: one opaque primary surface for coat, skin, teeth, and claws, plus one eye surface when emission requires it. Use high roughness and restrained specular response. No normal map is required.

## Mesh and topology

The final triangle budget is measured on the exported triangulated render mesh, not Blender's pre-triangulation face count.

Working allocation:

| Region | Target triangles |
| --- | ---: |
| Torso, neck, head, and muzzle | 900-1,050 |
| Four legs and paws | 650-750 |
| Tail | 260-340 |
| Ears, jaw, teeth, claws, and eyes | 300-380 |
| Fur tufts and deformation reserve | 250-350 |
| Total target | 2,400-2,700 |
| Hard maximum | 3,000 |

Use continuous topology through the torso, neck, head, and limbs where deformation benefits from it. Maintain usable edge flow around shoulders, hips, elbows, knees, jaw hinge, neck, and tail base. Separate geometric islands for eyes and incisors may remain inside the single skinned mesh object so material control does not break the runtime presentation contract.

Acceptance topology rules:

- no non-manifold edges or accidental holes;
- no doubled vertices, duplicate faces, or hidden internal shells;
- no coplanar overlapping surfaces or z-fighting;
- no zero-area faces or uncontrolled degenerate triangles;
- no n-gons in deforming or exported geometry;
- outward-facing normals and consistent smoothing;
- applied object scale and rotation before export;
- no loose geometry except intentional closed eye or tooth islands;
- joint deformation remains clean in all five animations.

## Rig and skinning

The rat uses one compact armature with bones for:

- root and pelvis;
- three to four spine/shoulder segments;
- neck and head;
- lower jaw;
- four articulated legs with paw controls/deform bones;
- eight tail segments;
- optional ear bones only if they materially improve the animation within the rig budget.

The exported mesh is one skinned mesh object named `MeshInstance3D`. Eyes, incisors, claws, and fur tufts may be separate closed islands within that object. The armature and mesh remain separable in Blender, but the export may not scatter the character across multiple uncontrolled mesh nodes.

Weights must be normalized with no unassigned vertices. The torso may not collapse at the shoulders during the scurry, paws may not detach, the jaw may not tear the muzzle, and the tail may not form sharp weight discontinuities.

## Animation contract

Gameplay movement remains owned by the `CharacterBody3D`; every animation is authored in place with no gameplay root motion.

Required clips:

- `idle_sniff`: looping crouched breathing, nose movement, small ear response, and restrained tail motion;
- `scurry`: looping rapid quadruped locomotion with clear paw contacts and shoulder compression;
- `pounce_bite`: non-looping forward attack pose with readable anticipation, jaw opening, bite contact, and recovery;
- `hit_react`: short non-looping recoil that keeps the rat grounded and quickly returns control;
- `death_curl`: non-looping collapse onto the side followed by a curled final pose.

The `pounce_bite` clip conveys displacement through posing but returns to the root; gameplay code remains responsible for any actual movement or contact. Animation names must survive GLB import exactly. Loop flags must be correct. The implementation plan may add explicit event timing through the Godot wrapper, but the art asset does not change current damage rules by itself.

## Source and export contract

Reserved asset paths:

- editable source: `assets/models/enemies/source/swarmer_rat.blend`;
- imported exchange asset: `assets/models/enemies/swarmer_rat.glb`;
- optional compact palette texture: `assets/models/enemies/swarmer_rat_palette.png`;
- reusable Godot presentation scene: `scenes/enemies/swarmer_rat_visual.tscn` when a wrapper scene is needed.

Blender uses metres. Export glTF 2.0 with Y-up conversion suitable for Godot, normalized forward orientation beneath the gameplay wrapper, applied transforms, selected asset objects only, skinning, materials, and the five named animations. Do not export the Blender camera, lights, turntable, aura tests, measurement guides, or review helpers into the game GLB.

The `.blend` file contains clearly named collections separating the export asset from review-only objects. The final source remains independently editable and does not depend on the earlier sword, key, house, or turntable files.

## Party Forge integration

`scenes/enemies/swarmer.tscn` remains the gameplay-owned root. It retains:

- the `CharacterBody3D` root and `hostile_actors` group;
- collision layers and masks;
- `HealthComponent`;
- Swarmer script and enemy definition;
- current movement, target selection, contact attack, and death behavior;
- the direct-child `MeshInstance3D` presentation contract used by `enemy_actor.gd` for base color and damage flash.

The imported body mesh is exposed through that direct child rather than making the imported GLB hierarchy the gameplay root. The armature, animation player, and any presentation helper nodes remain subordinate to the gameplay wrapper. Damage flash must visibly affect the coat and not permanently overwrite the approved palette or eye material.

Replace the sphere collision with a simple torso-focused primitive, initially a horizontal capsule or similarly cheap convex shape fitted to the chest and abdomen. The collision excludes the tail, ears, claws, and extended muzzle. It remains centered enough for stable navigation and does not make tightly grouped rats appear unable to overlap. Existing `0.9 m` contact range remains unchanged during the asset replacement unless a separate gameplay design approves a balance change.

## Visual QA

Blender review uses the reusable scalable turntable and neutral three-point lighting. The rat is reviewed at a minimum of eight evenly spaced angles: front, front-right, right, rear-right, rear, rear-left, left, and front-left. Review also includes:

- an elevated top-down view approximating Party Forge's gameplay camera;
- side close-ups of jaw, neck, shoulders, belly, hips, and tail connection;
- underside inspection for gaps, floating paws, internal faces, and detached parts;
- solid and wireframe inspection;
- neutral pose plus representative frames from every animation;
- at least one grouped view with multiple rats facing different directions;
- a live Party Forge arena view at actual gameplay scale.

The review rejects:

- disconnected-looking joints or visible mesh gaps;
- intersecting limbs in the neutral pose;
- coplanar flicker or facade-like z-fighting;
- an unreadable head or dorsal stripe from above;
- feet visibly sliding during the scurry cycle;
- jaw, eye, tooth, or tail deformation failures;
- a silhouette that reads as a bulky bruiser instead of a fast Swarmer;
- clipping, missing materials, incorrect scale, or unintended transparency;
- animation or material differences between Blender and Godot that materially change the approved design.

## Verification and acceptance

The asset is accepted only when all of the following are recorded from the final candidate:

1. Blender reports no more than `3,000` triangles for the exported render mesh after triangulation.
2. Bounds match `0.91 m` total length and `0.61 m` ear-tip height within a practical `0.02 m` tolerance.
3. Mesh validation finds no non-manifold edges, duplicate faces, degenerate geometry, unintended loose parts, or inverted normals.
4. The Blender source and exported GLB exist at the reserved reusable paths.
5. Godot imports the GLB, materials, armature, and all five exactly named animation clips without errors.
6. The rat remains grounded and deformation-safe through every required animation.
7. The direct `MeshInstance3D` damage flash remains functional without destroying the base palette.
8. Swarmer movement, targeting, contact attack, damage, death, spawning, and reward behavior remain unchanged.
9. A representative pack runs without animation, import, collision, or presentation errors.
10. Eight-angle, top-down, underside, wireframe, animation, grouped-pack, and live gameplay-camera visual reviews are completed.
11. The user approves the final Blender and in-game appearance.
12. Relevant focused Party Forge tests, runtime smoke checks, cold import, and `git diff --check` pass from the exact candidate; a timeout or silent startup is reported as blocked rather than passed.

## Implementation boundary

This approved document authorizes planning, not immediate asset mutation. The next step is a written implementation plan covering Blender authoring, review checkpoints, export, Godot integration, automated checks, and live visual QA. Modeling begins only after that plan is reviewed under the normal Party Forge approval workflow.
