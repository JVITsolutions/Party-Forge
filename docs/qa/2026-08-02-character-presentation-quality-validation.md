# Character Presentation Quality Validation

Date: 2026-08-02
Implementation head: `25da23f0c2feccde382d1d11739e763d0f3736a0`
Base/main head before integration: `1e4a354b88517fb769419b8ddade8cd277fc89bf`

## Scope

This merge candidate corrects the shared rigid-component presentation for all nine player classes and both reusable body presets. It covers authored idle, walk, attack, and hit poses; equipment/arm separation; bounded visual turning; model-only grounding; contact shadows; adaptive health bars; palette-preserving hit feedback; and deterministic rendered QA.

The gameplay actor root, collision shapes, health, target selection, attack timing, sequence tokens, class/equipment IDs, equipment slot contract, fallback capsules, and icon paths remain owned by their existing systems.

## Deterministic Generation

Two consecutive complete builder passes were run with isolated app data:

- `build_forge_vanguard_equipment_source.gd`: `FORGE_VANGUARD_EQUIPMENT_SOURCE_BUILD_OK items=12`
- `build_equipment_assets.gd`: `EQUIPMENT_ASSET_BUILD_OK sets=9 items=99`
- `build_shared_humanoid_scene.gd`: `FORGE_HUMANOID_BUILD_OK`
- `build_class_presentation_profiles.gd`: `CLASS_PRESENTATION_PROFILE_BUILD_OK classes=9 attacks=10`
- `build_combat_presentation_scenes.gd`: `COMBAT_PRESENTATION_BUILD_OK projectiles=6 effects=5`

Result: `GENERATOR_DETERMINISM files=351 first_drift=0 repeat_drift=0`.

The visual renderer was also run twice against 325 generated evidence files. Result: `TASK6_RENDER_DETERMINISM files=325 drift=0`.

## Fresh Merge-Candidate Verification

Fresh application data root:

`F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\class-presentation-quality\.task-data\merge-verification-appdata-20260802-1615`

Every command exited `0`:

| Gate | Evidence |
|---|---|
| Godot editor import/compile | `FINAL_GATE name=editor exit=0` |
| Complete unit runner | `TEST_SUMMARY: PASS (95 suites)` |
| Presentation sandbox | `PARTY_FORGE_PLAYABLE_PRESENTATION_SMOKE_OK classes=9 bodies=2 slots=11 items=99 icons=198 animations=21 projectiles=6 effects=5` |
| Locomotion and equipment integration | `PARTY_FORGE_LOCOMOTION_SMOKE_OK directions=4 walk=1 idle=1 smooth_turn=1 attack_lock=1 equipment_independent=1 grounding=1 shadow=1` |
| All-class visual-quality smoke | `PARTY_FORGE_CHARACTER_VISUAL_QA_SMOKE_OK classes=9 bodies=2 combinations=18 grounding=18 shadows=18 bars=18 equipment=18 actions=18 projectiles=1` |
| Equipment icon validation | `EQUIPMENT_ICON_VALIDATION_OK sets=9 items=99 unique_master=99 unique_runtime=99` |
| Hardware-rendered QA | `PARTY_FORGE_CHARACTER_VISUAL_QA_OK classes=9 bodies=2 views=4 state_samples=17` |
| Whitespace/diff validation | `git diff --check`, exit `0` |

The hardware renderer used the NVIDIA GeForce RTX 4070 Ti SUPER through Godot 4.7.1 Forward+.

## Automated Regression Coverage

- All 18 class/body combinations remain grounded within `0.01` after body changes and boot removal/re-equipping.
- All 18 combinations have a separate, non-colliding contact shadow.
- Health bars clear current visible bounds after body, helmet, and equipment changes.
- Locomotion turns are bounded per frame, converge to the target yaw, and take the short arc across `-PI/PI` without rotating actor/collision roots.
- Attack facing remains locked through the transient and returns to the newest locomotion direction afterward.
- Held equipment exposes independent readability/action anchors; ranged weapons expose equipment-local projectile launch sockets.
- Sword, shield, bows, daggers, wands, tomes, focuses, staves, and hammer remain separate scene/mesh attachments rather than arm geometry.
- Every authored class action samples distinct hip/torso/arm phases instead of using a duration-scaled Fighter slash.
- Hit feedback restores base materials, retains readable saturation, limits luminance change, and caps emission energy at `0.45`.

## Rendered Review

The manifest contains exactly 306 rows: 9 classes x 2 bodies x 17 state samples. Four ranged release rows contain projectile overlays (Ranger and Marksman, both bodies). Every PNG and all 18 contact sheets were opened and reviewed.

Reviewed contact sheets:

- Fighter: masculine and feminine
- Ranger: masculine and feminine
- Marksman: masculine and feminine
- Mage: masculine and feminine
- Frost Mage: masculine and feminine
- Cleric: masculine and feminine
- Paladin: masculine and feminine
- Rogue: masculine and feminine
- Warlock: masculine and feminine

Review result:

- no persistent A-pose in idle, walk, attack, or hit samples;
- walk samples show alternating legs, knees, feet, hips, and counter-rotating torso;
- class attacks show distinct load, release/impact, follow-through, and recovery poses;
- Ranger and Marksman retain visibly different bow scale, stance width, and draw weight;
- held equipment remains readable outside the arm silhouette and disappears independently in hands-cleared samples;
- contact shadows and the floor line show no visible hovering;
- health bars clear helmets and tall equipment;
- ranged launch overlays originate from the equipped bow sockets;
- no blank, cropped, or materially washed-out frames were found.

Evidence root: `docs/qa/character-presentation-quality/`
Manifest: `docs/qa/character-presentation-quality/manifest.json`

## Branch and Main-Checkout Safety

- The feature branch has no diff for `scenes/game/main.tscn`.
- The pre-existing dirty main-checkout file remained byte-identical throughout verification: SHA-256 `88938B050B59081EDA7F898D164F200C9808BEB839C48D4D6BE04A17841D5E5F`.
- Generated `.uid` and `.png.import` sidecars were excluded from every commit.
- `git status --short --untracked-files=no` was clean before integration.

## Deferred Observation

The automated and rendered gates cover the reported failure modes, but a normal player-controlled gameplay session remains useful after merge to judge subjective turn speed and animation feel at the final camera zoom. It is not represented here as an automated pass.
