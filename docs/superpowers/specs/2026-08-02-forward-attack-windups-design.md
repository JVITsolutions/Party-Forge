# Forward Attack Wind-ups Design

## Problem

Party Forge's corrected idle and attack endpoint poses are forward-facing, but the authored intermediate loaded poses still rotate several shoulders and elbows behind the torso. The Fighter slash demonstrates the defect at 28 percent of the clip: its guarded right shoulder and elbow use positive forward rotations, then the loaded keyframe changes them to large negative rotations. The current automated silhouette gate checks attack start and recovery only, while the visual manifest records the loaded frame without enforcing its hand-depth result.

## Outcome

Every playable-class attack will wind up in a readable weapon-specific pose that stays in front of, beside, or above the character instead of passing behind the back. Existing action IDs, durations, release/event timings, class identity, modular equipment, and gameplay attack ownership remain unchanged.

## Pose Rules

- Party Forge gameplay forward remains local `-Z`; positive local `Z` is behind the character.
- Tests sample each attack from 0 through 100 percent in five-percent increments.
- Each hand is evaluated separately. One forward hand must not be allowed to hide a second hand behind the torso through an averaged measurement.
- Melee weapon hands load beside or above the corresponding shoulder. They may rotate laterally for anticipation but may not cross behind the torso/back plane.
- Shields and melee support hands remain visibly forward of the back plane throughout the wind-up.
- Bow support hands keep the bow in front. Draw hands may reach the side of the face, but not behind the shoulder line.
- Caster hands charge in front of the chest, near a forward-facing focus, or beside the torso without crossing behind the back.
- Start, release, follow-through, and recovery remain distinct. The correction must not reduce every class to the same attack curve.
- The current equipment-arm intersection budget and modular-equipment tests remain mandatory.

The test will use explicit per-hand and per-elbow local-depth limits derived from the shared humanoid proportions. Bow draw hands receive only the small additional allowance needed to reach the side of the face. Any exception must be tied to an attack family and documented in the test rather than hidden in a broad global tolerance.

## Implementation Boundary

`scripts/presentation/humanoid_animation_authoring.gd` remains the source of truth for attack curves. The shared humanoid scene is regenerated through the existing deterministic builder; generated scene tracks are not hand-edited. No runtime inverse kinematics or attack-state changes are introduced.

The ten authored primary attacks remain individually recognizable:

- Fighter: compact sword chamber beside the weapon shoulder, then diagonal slash.
- Paladin: hammer rises beside and above the shoulder before the smite.
- Ranger: quick bow presentation with a short draw beside the face.
- Marksman: longer braced greatbow draw, still forward of the shoulder line.
- Rogue: alternating forward dagger chambers without either hand sweeping behind the spine.
- Mage: wand/focus charge in front of the torso.
- Frost Mage: two-handed staff preparation in front of the body.
- Cleric lightning: sceptre/reliquary charge forward.
- Cleric healing: open blessing gesture in front of the chest.
- Warlock: asymmetric wand/grimoire charge kept forward and readable.

## Regression Tests

`tests/unit/test_humanoid_animation_quality.gd` will replace endpoint-only attack silhouette coverage with full-curve runtime sampling for both masculine and feminine bodies. Failure messages will identify the class attack, body, normalized time, joint, and measured local depth.

The test must be witnessed failing against the current authored curves before production values change. After the correction it must pass alongside the existing phase-distinction, walk, idle, modular-equipment, and equipment-intersection assertions.

`tools/render_character_visual_qa.gd` will add a close loaded-pose capture. The renderer contract will require that sample in every class/body set, and the generated manifest will record individual left/right hand depth rather than only a mean. Fighter masculine and feminine loaded/release frames plus every class contact sheet will receive visual review.

## Verification and Integration

Verification requires a fresh isolated Godot import, focused red/green evidence, the complete unit suite, presentation/locomotion/visual smoke runners, deterministic humanoid regeneration, hardware visual QA, manifest assertions, and `git diff --check`. A timeout or silent Godot startup is blocked, not passed.

The feature branch may merge locally only after those gates pass. The dirty main checkout and its user-owned Godot editor are not modified or terminated. Before merging, all overlapping paths and hashes of unrelated dirty files are checked and preserved.
