# Task 3 report: deterministic Fighter modular assets

Status: COMPLETE. Final staged diff check, focused commit, and clean-worktree verification are recorded with this delivery.

## Scope and generated output

- Worktree: `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\playable-class-presentations`
- Branch/start: `feat/playable-class-presentations` at `90519ce9e5944cad49e28a1682acea82a771f6f4`.
- Added canonical eleven-slot order: helmet, body armour, legs, gloves, boots, amulet, left ring, right ring, belt, main hand, off hand.
- Generated `ForgeHumanoidModel`, twelve independent Fighter equipment scenes, twelve base definitions, twelve visual definitions, and 24 transparent icon files (12 master 256x256 plus 12 runtime 128x128).
- The Fighter profile equips red sword plus shield by default; hammer remains available but absent from defaults. Both reusable base bodies are generated from the nude shared model.

## RED and builder investigation

The required first focused run of `test_fighter_modular_assets.gd` plus `test_equipment_icons.gd` was RED as expected: `TEST_SUMMARY: FAIL (52 failures)`, exit `1`, for the old ten-slot layout and missing shared scene/assets/icons.

`build_shared_humanoid_scene.gd` initially hung because `StringName` dictionary values were implicitly coerced into a typed `NodePath`. The failed path-splitting hypothesis was discarded. Storing values as `String` and explicitly calling `NodePath(String(...))` resolved it: `FORGE_HUMANOID_BUILD_OK`.

`build_equipment_assets.gd` then exposed a CLI `PackedStringArray` conversion error and missing ring socket map entries. The parser now creates a typed StringName array and both ring sockets map to their correct hand paths. Fresh generation completed with `EQUIPMENT_ASSET_BUILD_OK sets=1 items=12`.

## Icon render, validation, and determinism

The mandated headless SubViewport path was diagnosed, not bypassed silently: in Godot's dummy renderer, a bounded 180-frame condition observed no `frame_pre_draw` or `frame_post_draw`, and all texture reads reported null textures. The true scene renderer therefore runs in a short, direct hardware-backed Godot console session with `--display-driver windows --audio-driver Dummy --rendering-method gl_compatibility`; it reported the RTX 4070 Ti SUPER OpenGL compatibility driver and exits automatically.

The renderer uses transparent SubViewport output, a three-light rig, `UPDATE_ONCE`, `await RenderingServer.frame_post_draw`, computed square orthographic framing, and Lanczos runtime resize. The initial amulet transparency failure was traced to source-extracted attachment visibility. The generic correction enables every item Node3D before render; no per-item fallback geometry is used.

The first strict raw-PNG validation caught sword runtime padding. Computed camera framing corrected it. The final master alpha bounds are: helmet `(58,65)+(139,125)`, armour `(43,73)+(169,109)`, greaves `(87,56)+(81,143)`, gauntlets `(85,92)+(85,71)`, boots `(75,90)+(105,75)`, amulet `(107,107)+(41,41)`, both rings `(113,113)+(29,29)`, belt `(50,113)+(155,29)`, sword `(106,42)+(43,172)`, shield `(48,48)+(159,159)`, hammer `(120,44)+(15,167)`. Every runtime icon passed the required eight-pixel transparent padding.

Immediate rerender SHA-256 comparison reported `EQUIPMENT_ICON_DETERMINISM_OK files=24`; no pixel changed. Latest strict result: `EQUIPMENT_ICON_VALIDATION_OK items=12`.

## Runtime modularity and animation evidence

The test suite fail-closes on baked equipment: it instantiates the shared humanoid and both nude bases and requires zero `equipment_slot`/`equipment_visual_id` metadata and no node names containing sword, shield, hammer, or weapon. It then proves sword and shield are attached only to their exact hand sockets after applying the independent visual scenes, remain independent from all upper-arm/forearm meshes and mesh resources, survive masculine/feminine body swaps, and clear independently without removing arms or the opposite hand item.

Applying the Fighter profile is also required to start a looping `idle`; all four shoulder/elbow guard tracks must be non-neutral at time zero, preventing an A-pose baseline regression.

Shared animation inventory is exactly `idle`, `attack_slash`, `attack_combo`, and `hit_flinch`. `walk` is absent. No locomotion state machine, movement-facing integration, or gameplay visual claim was added in Task 3; those remain the dedicated follow-up task.

## Verification

- Focused modular/icon regression: `TEST_SUMMARY: PASS (0 failures)`.
- Expanded Fighter/presentation regression (including sandbox and party actor palette isolation): `TEST_SUMMARY: PASS (0 failures)`.
- Hermetic full suite using worktree-local APPDATA: `TEST_SUMMARY: PASS (76 suites)`, exit `0`.
- `git diff --check` was clean before final sidecar cleanup.

The full run emits intentional negative-case diagnostics from existing ledger, presentation, damage, and upgrade tests; it nevertheless exits zero with the PASS summary.
