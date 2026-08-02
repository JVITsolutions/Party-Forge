# Shared Humanoid Locomotion and Facing Design

Date: 2026-08-01
Status: Approved design

## Goal

Fix the live Fighter presentation defects before any other class models are generated:

- sword, shield, and future weapons remain independent socketed equipment rather than arm geometry;
- idle uses a visibly bent combat-ready guard instead of a neutral A-pose;
- moving actors play an authored walk cycle;
- the presentation faces planar movement direction;
- attacks face their locked target until the authored action finishes, then restore current locomotion facing and animation.

The contract applies to both reusable body presets and every player class profile built from the shared humanoid.

## Chosen Behavior

The approved facing rule is target-priority during attacks. Normal movement faces travel direction. Starting an attack temporarily locks facing to the selected target. The lock persists through the authored attack action even when the actor keeps moving. When the action finishes or is canceled, presentation state is recomputed from the actor's latest post-slide velocity.

Hit/flinch is also transient and cannot be overwritten by locomotion. Downed actors cannot enter idle or walk locomotion. A revived actor recomputes idle or walk from current velocity.

## Architecture

### Authored shared animations

`tools/build_forge_vanguard_scene.gd` remains the authoritative shared body, pivot, material, and animation source. It will add a looping `walk` action while preserving the existing attack and hit actions.

The walk cycle animates body bob, torso counter-rotation, hips, knees, and modest arm motion. Arms remain recognizably combat-ready so socketed weapons and shields stay readable. Idle retains bent shoulders and elbows across the loop. Both body presets use the same pivot hierarchy and animation library.

`CharacterVisualProfile` gains `walk_action_id`, defaulting to `walk`. Validation requires both idle and walk actions to exist in `required_animation_names`. Generated Fighter and nude profiles declare the shared walk action. Later classes may provide class-specific action IDs while keeping the same runtime contract.

### Presentation state arbitration

`CharacterPresentation` owns presentation-only state:

- latest planar movement velocity;
- current locomotion request (`idle` or `walk`);
- current facing mode (`movement`, `target`, or retained last facing);
- transient action lock for attack or hit/flinch;
- downed lock.

The public locomotion entry point accepts actual world-space post-slide velocity. A nonzero planar vector updates the retained movement direction and requests walk. Zero velocity requests idle without discarding the last facing direction. Repeating the same locomotion state does not restart the animation every physics frame.

Attack playback stores the locked target actor/position, faces it, and starts a transient action. The presentation subscribes to the model's `action_finished` signal. Completion clears the transient lock and reapplies the most recent locomotion request. Invalid or freed attack targets retain the last valid attack facing until the action finishes; the presentation does not retarget.

Hit/flinch replaces any current transient visual action, keeps current facing, and returns to current locomotion after completion. Downed state clears transient and locomotion playback and prevents subsequent movement updates from starting walk.

### Facing transform

Only the `CharacterPresentation` visual root rotates; `PartyActor`, collision, navigation, health bars, target origin, and gameplay coordinates remain unchanged. The shared model uses Godot's `-Z` forward direction.

For a normalized planar direction, local yaw is computed so:

- `-Z` faces `0` radians;
- `+X` faces `-PI / 2`;
- `+Z` faces `PI`;
- `-X` faces `PI / 2`.

Facing snaps immediately for this pass. Turn smoothing, strafing, root motion, foot IK, and camera-relative remapping are deferred.

### Gameplay bridge

`Leader` and `Companion` call one shared `PartyActor` presentation update after `move_and_slide()`, using the resulting `CharacterBody3D.velocity`. Every early stationary branch also sends zero velocity, including pause, missing configuration, downed, dead, and missing leader states.

The existing `play_attack(definition, target)` bridge provides the attack-facing target. The later animation-event attack-sequence task may add tokens and release events, but it must preserve this presentation state contract rather than creating a second locomotion state machine.

## Equipment Separation Invariant

Locomotion work must not weaken the Task 3 modularity gate:

- shared and nude body scenes contain no equipment metadata or weapon-named geometry;
- sword and shield are distinct packed scenes and mesh resources;
- runtime attachments exist only beneath their declared hand sockets;
- no equipment attachment descends from body-preset, upper-arm, or forearm mesh nodes;
- clearing one hand removes only that item and leaves both arms and the opposite item intact;
- switching masculine/feminine body presets does not hide, merge, or duplicate equipped items.

The same invariant applies to every later class and equipment set.

## Failure Handling

- A profile missing idle or walk validation fails closed and keeps the capsule fallback visible.
- A model missing the locomotion action rejects the request without clearing a valid active presentation.
- A missing target never causes retargeting or actor-root rotation.
- An invalid movement vector is treated as stationary; non-finite direction values are rejected and logged once.
- Transient completion from a stale action ID cannot release a newer transient lock.

## Tests and Live QA

Test-first coverage will include:

1. Profile validation fails when `walk_action_id` is empty or absent from required animations.
2. The shared animation library contains looping idle and walk actions. Walk samples prove alternating hip/knee movement, body bob, and non-static arm motion.
3. Idle samples prove all shoulder/elbow guard tracks remain non-neutral and elbows remain visibly bent, preventing a neutral A-pose baseline.
4. Locomotion requests select walk/idle exactly once per transition and do not restart each frame.
5. Cardinal movement vectors produce the required yaws; zero velocity retains the last facing.
6. Attack facing overrides movement, ignores movement-facing changes while locked, and restores the latest movement state only after the matching action finishes.
7. Hit/flinch and downed states cannot be overwritten by walk; revival restores locomotion.
8. Leader and companion tests use actual post-slide velocity and cover every stationary early return.
9. Existing arm/weapon separation and independent-clear tests remain green.
10. A live Godot QA run captures idle, four movement directions, walk frames, attack lock, post-attack restoration, hit recovery, sword/shield attachment, and a nude body. Logs must contain no presentation errors and shutdown must be clean.

## Scope Boundary

This task adds shared idle/walk/facing behavior and the minimum state arbitration required to protect attacks and hit reactions. It does not add navigation behavior, root motion, animation blending, turning interpolation, foot IK, inventory UI, new equipment, new classes, or the later exactly-once attack release sequence.
