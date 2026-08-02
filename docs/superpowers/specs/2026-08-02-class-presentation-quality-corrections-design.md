# Class Presentation Quality Corrections Design

**Status:** Approved design

**Date:** 2026-08-02

## Purpose

Correct the shared visual defects exposed by live Fighter and Ranger recordings before additional character content builds on them. The correction applies to all nine playable classes and both reusable body presets. It preserves Party Forge's Godot-native modular-equipment architecture and keeps the later Blender/GLB replacement path open.

The reported defects are systemic rather than isolated to two class scenes:

- runtime idle poses remain too close to the authoring A-pose;
- direction changes rotate the complete presentation like a rigid display model;
- locomotion and attacks lack planted feet, weight transfer, anticipation, and recovery;
- hand equipment is structurally separate but can visually collapse into an arm;
- boots and lighting do not consistently establish floor contact;
- class actions are derived from one Fighter slash rather than authored for their weapon families;
- the existing tests prove scene-tree wiring but do not prove gameplay-camera readability.

## Chosen Approach

Use a Godot-first shared presentation overhaul. Retain the two reusable rigid-component bodies, stable equipment IDs, item scenes, item icons, gameplay wrappers, collision, combat sequencing, and `CharacterPresentation` adapter. Improve the shared rig, animation authoring, equipment attachment contract, grounding, and quality gates in place.

Blender rigging, skin deformation, foot IK, root motion, and imported animation retargeting remain later pipeline work. A socket, action, and validation contract introduced by this correction must remain usable by that later pipeline.

## Scope

The correction covers:

- Fighter, Paladin, Ranger, Marksman, Rogue, Mage, Frost Mage, Cleric, and Warlock;
- masculine and feminine body presets;
- idle, walk, direction changes, every current primary attack, Cleric healing, and hit/flinch;
- every default visible main-hand and off-hand item;
- equipment grip and projectile-release alignment;
- body, boots, contact shadow, and health-bar grounding/readability;
- automated structural, motion, bounds, timing, and render-capture verification.

The correction does not add inventory UI, new equipment types, new classes, new combat mechanics, new character stats, player-facing body selection, Blender files, or final high-detail art.

## Runtime Architecture

### Shared body and pose hierarchy

`forge_humanoid_model.tscn` remains the presentation scene used by all class profiles. Both body presets retain the same pivot and socket names. A dedicated grounding transform separates floor calibration from authored animation transforms so animation tracks never overwrite the model's floor offset.

The source A-pose remains available only as an authoring/reference pose. It is not a valid runtime idle or locomotion frame. Runtime actions always animate shoulders and elbows into a readable stance.

### Presentation state

`CharacterPresentation` continues to arbitrate locomotion, attacks, hit feedback, and downed state. It adds target-facing state and bounded angular interpolation:

- moving records the latest nonzero planar velocity and requests the class walk action;
- stopping requests class idle and retains the last facing;
- attacks request target facing and keep attack priority until the sequence finishes;
- direction changes update a target yaw rather than assigning the final yaw immediately;
- the visible root turns at a bounded rate while gameplay collision and actor coordinates remain unchanged;
- downed state freezes the visible action contract and revival recomputes locomotion.

The standard turn rate is `10.0` radians per second. Attack targeting uses the same interpolation but may use a `16.0` radians-per-second combat turn rate so a fast action remains readable without delaying gameplay execution. Angle changes use the shortest planar arc. A single frame may never rotate farther than `turn_rate * delta`.

### Grounding

Grounding is calculated after body selection and after any boots or leg equipment change. The presentation measures effective visible bounds and applies a model-only vertical correction so the lowest visible footwear point is at local floor `y = 0.0`, within `0.01` world units. It never moves the `PartyActor`, collision shape, health components, attack origin, or navigation position.

Walk actions use in-place animation. At the two support phases, at least one foot remains within `0.015` units of the calibrated floor. Hips and torso may bob, but the entire model may not translate upward as one rigid object.

Every active character presentation owns a subtle matte contact-shadow mesh centered under the feet. It remains independent of directional-light shadows, follows the actor, does not receive input, and does not affect collision. The shadow's local top is between `y = 0.002` and `y = 0.01` to avoid z-fighting.

### Health-bar clearance

Leader and companion health bars remain gameplay-owned UI. Their presentation anchor is raised from the active model's visible top bound plus a minimum `0.12` unit clearance. The anchor refreshes after body or helmet changes so it does not cross the head, helmet, weapon, or shoulders at the gameplay camera angle.

## Animation Design

### Runtime stance invariant

Every idle loop is asymmetrical and class-readable. Across all sampled idle frames:

- neither shoulder may remain at the source A-pose rotation;
- both elbows retain visible bend;
- the hands stay closer to the torso than the source A-pose hand positions unless a held two-handed weapon requires a wider stance;
- hips or torso include subtle nonzero motion so the actor is not perfectly frozen;
- the first and last loop samples match.

Fighter and Paladin use compact guarded heavy stances. Ranger and Marksman use bow-ready stances with distinguishable draw weights. Rogue uses a low asymmetric stance. Mage, Frost Mage, Cleric, and Warlock use implement-specific casting guards.

### Shared locomotion family

All classes use one grounded humanoid walk foundation with profile-selectable posture offsets. The walk includes:

- alternating hip rotations;
- alternating knee flexion;
- foot-pivot motion and support phases;
- small vertical hip movement;
- torso counter-rotation;
- equipment-safe arm motion;
- a seamless loop.

Heavy classes use reduced stride frequency and stronger vertical settling. Ranger and Rogue use quicker, lighter cycles. Marksman retains a wider braced upper-body posture. Caster implements remain controlled rather than swinging through the torso.

### Weapon-family actions

Class actions are authored from explicit weapon-family keyframes, not duration-scaled copies of `attack_slash`.

- `one_hand_sword_shield`: guarded anticipation, planted lead foot, hip-led slash, shield counterbalance, follow-through, recovery.
- `one_hand_hammer_shield`: slower overhead windup, lowered hips, planted impact, rebound and settle.
- `bow_light_medium`: bow held independently, draw hand travels rearward, torso turns, release event at full draw, quick recovery.
- `greatbow`: wide braced stance, slow full-body draw, visible strain, release recoil, long recovery.
- `dual_dagger`: alternating arm strikes with torso rotation and low-footed balance.
- `wand_focus`: focus hand stabilizes while wand hand leads a compact fire release.
- `two_hand_staff`: both hands participate in a controlled staff channel and forward release.
- `sceptre_tome`: sceptre attack and tome-assisted healing use distinct whole-body gestures.
- `occult_wand_grimoire`: inward channel, asymmetric release, and lingering recoil.

Every attack has anticipation, release or impact, follow-through, and recovery phases. The existing exactly-once combat event names and sequence tokens remain authoritative.

### Hit/flinch

Hit/flinch remains a short overlay but includes torso displacement and shoulder reaction without moving equipment independently from its sockets. The flash must not bleach the entire model to featureless white; material feedback is capped so base palette and weapon silhouette remain visible.

## Equipment Readability Contract

Structural independence remains mandatory: equipment scenes, nodes, and mesh resources cannot be body or arm geometry. This correction adds visual contracts.

Every combat-visible held item provides:

- a root transform whose origin is the intended hand grip;
- a `ReadabilityAnchor` child positioned on the recognizable portion of the item outside the hand;
- a distinct material value or accent from the adjacent forearm;
- a visible bound extending at least `0.18` units beyond the gripping hand;
- no mesh-resource identity shared with upper-arm, forearm, or hand meshes.

At runtime, the `ReadabilityAnchor` must remain at least `0.06` units outside the combined arm mesh bounds in idle and at attack release. The grip origin may overlap the hand; the recognizable weapon or shield body may not be swallowed by the forearm silhouette.

Bow scenes additionally provide an equipment-local `ProjectileLaunchSocket`. The first projectile frame originates at that socket, and its forward direction differs from the weapon forward direction by no more than `3` degrees. Sword, hammer, dagger, wand, sceptre, and staff items expose an equivalent `ActionOriginSocket` for effects where required.

Unequipping either hand must leave both body arms and the opposite item intact. Changing body presets or class equipment may not duplicate attachments.

## Authoring and Generation

The generated humanoid scene remains reproducible from checked-in Godot scripts. Animation construction is separated from scene packing so weapon-family keyframe authoring and validation can be understood and tested independently.

Generated scene output must be deterministic. Running the builder twice from the same source produces the same tracked scene content after generated node identifiers are normalized.

Equipment item scenes remain individually saved and linked to their existing gameplay resources and icons. Stable item IDs and paths do not change solely for this correction.

## Tests

Implementation follows witnessed red-green-refactor cycles.

### Structural and catalog tests

For every class and body preset:

- the profile activates without fallback;
- idle, walk, attack, and hit/flinch actions exist;
- default equipment attaches once to valid sockets;
- every visible hand item is a separate scene, node, and mesh resource from all arm meshes;
- every held item supplies its required readability and action/launch anchors;
- clearing main hand or off hand preserves both arms and the opposite equipment;
- switching body presets preserves exactly one instance of every equipped item.

### Pose and motion tests

Animation sampling uses the real `Animation` resources and pivot hierarchy. It verifies:

- no runtime idle sample equals the source A-pose shoulder/elbow transform set;
- elbows remain bent and hands meet the stance-distance rule;
- idle loops contain subtle torso or hip motion and close seamlessly;
- walk contains alternating hip, knee, and foot movement;
- walk support samples keep at least one foot grounded;
- weapon-family attacks contain distinct whole-body keyframes rather than sharing the Fighter slash track data;
- release/impact time falls after anticipation and before follow-through/recovery;
- Fighter, Ranger, and Marksman actions meet their heavy, quick-draw, and greatbow timing distinctions.

### Runtime behavior tests

- nonzero velocity enters walk and zero velocity returns to idle without restarting the same action each frame;
- target yaw changes immediately, while visible yaw advances only within the configured angular bound;
- cardinal and wraparound turns use the shortest arc;
- attack facing overrides movement target facing until the matching sequence completes;
- hit/flinch, downed, revive, and stale completion behavior remain correct;
- grounding calibration stays within `0.01` units for all 18 class/body combinations and after boots are cleared/re-equipped;
- the contact shadow exists at floor height and remains outside collision ownership;
- the health-bar anchor clears the model top by at least `0.12` units;
- projectiles originate and face within the bow launch tolerances;
- real attack events still execute exactly once and damage, heal, or launch the intended presentation.

### Visual render verification

A deterministic Godot QA runner produces contact sheets at the actual gameplay camera scale. It captures each class and both body presets in:

- idle from front, three-quarter, side, and rear views;
- two walk support phases and two passing phases;
- attack anticipation, release/impact, follow-through, and recovery;
- hit/flinch;
- equipped and unequipped hand comparisons;
- a side orthographic grounding view with floor line;
- projectile launch for Ranger and Marksman.

The runner records class, body, action, sample time, equipment IDs, ground gap, arm/readability-anchor clearance, and output path. Missing or blank captures fail. Contact sheets are reviewed for A-pose appearance, hovering, foot sliding, equipment/arm silhouette collapse, clipping, health-bar overlap, and attack readability before merge.

Automated pixel checks are limited to blank-frame detection, alpha/coverage, framing, and floor-line intersection. Semantic appearance remains a required human visual gate; it is not falsely represented as fully automatable.

## Failure Handling

- A missing action, pivot, grip, readability anchor, or launch socket fails the affected profile closed and preserves the fallback visual.
- A non-finite velocity, yaw, bounds value, or grounding offset is rejected and logged once with class/body/item context.
- Invalid grounding does not move gameplay-owned nodes.
- A failed equipment replacement preserves the previously equipped valid item.
- A missing release/impact event cancels combat execution under the existing attack-sequence rules.
- Visual QA capture failures report a stable `PARTY_FORGE_CHARACTER_VISUAL_QA_ERROR` and exit nonzero.
- Runtime presentation failures retain grep-friendly IDs for class, body, item, action, and reason.

## Acceptance Criteria

The correction is complete only when:

1. All nine classes and both body presets pass the structural, pose, runtime, grounding, equipment-readability, projectile-alignment, and combat-event tests.
2. No runtime idle or sampled locomotion frame presents as the source A-pose.
3. Moving characters visibly play a grounded walk, face travel direction through bounded interpolation, and retain target-facing priority during attacks.
4. Every default weapon, shield, focus, tome, grimoire, bow, and staff is structurally independent and visually identifiable outside the arm silhouette.
5. Ranger and Marksman bows have aligned equipment-local launch sockets and visibly different draw/recoil timing.
6. Fighter sword and shield read as held equipment in idle and attack while remaining independently unequippable.
7. Every body/boot combination contacts the floor within tolerance and retains a contact shadow.
8. Health bars no longer cross the head or upper-body silhouette.
9. Existing combat, equipment eligibility, icons, fallback, collision, downed/revive, and attack-sequence behavior remains green.
10. The complete automated suite, focused presentation smoke tests, deterministic generation check, and reviewed contact sheets pass from the exact merge candidate.

## Later Blender Pipeline

The later Blender/GLB pipeline must retain stable body preset IDs, item IDs, equipment slots, grip and readability anchors, action IDs, release/impact event names, launch/action sockets, grounding origin, and gameplay wrapper boundaries. Imported assets replace presentation implementation, not the contracts or tests established here.
