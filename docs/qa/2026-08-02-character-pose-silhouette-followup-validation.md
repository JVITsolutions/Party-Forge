# Character Pose and Silhouette Follow-up Validation

Date: 2026-08-02

Verified implementation head: `e6f4be348f743b2468514dd382512977615f027d`

Base/main head before integration: `5ae959ef5765dc2d7860058aa952183a25b93d39`

## Corrected regressions

- Shared Fighter idle and walk now keep both reusable bodies in a compact forward guard instead of an A/T pose.
- All nine class idles keep the hands out from behind the torso.
- Every authored primary attack starts and recovers to the guarded stance.
- The legacy combo and hit/flinch source actions also retain guarded endpoints.
- Held equipment is rotated along the hand socket's outward axis and offset by equipment family rather than being built back through the forearm.
- Fighter sword, shield, and retained hammer remain independent equipment scenes and attachments.
- QA front views now observe the model's actual local `-Z` facing axis and include close equipped-hand and attack-release captures.

## Regression proof

The new pose test was witnessed red before the fix with 72 idle failures: Fighter hand span was `1.436`, and every non-Fighter idle placed the mean hand position behind the torso. The endpoint extension was then witnessed red with 40 attack start/recovery failures.

The real equipment-volume API was witnessed red across the equipped class set. Before correction, Fighter idle overlap measured `0.024704` for the sword and `0.048827` for the shield. On the verified render manifest, Fighter masculine and feminine both measure:

| State | Behind torso | Arm span ratio | Sword overlap | Shield overlap |
|---|---:|---:|---:|---:|
| Idle front | false | `0.469052` | `0.004223` | `0.001141` |
| Attack release | false | `0.427524` | `0.002669` | `0.005393` |
| Attack recovery | false | `0.470871` | `0.004181` | `0.001111` |

The small remaining volume is the allowed grip/forearm contact budget. The blade, crossguard, and shield body were visually reviewed separately from the arm meshes.

## Exact-head automated gates

All commands used isolated `APPDATA` and `LOCALAPPDATA` roots under `.task-data`.

| Gate | Result |
|---|---|
| Fresh Godot import and compile | exit `0` |
| Complete unit runner | `TEST_SUMMARY: PASS (96 suites)`, exit `0` |
| Playable presentation smoke | `PARTY_FORGE_PLAYABLE_PRESENTATION_SMOKE_OK classes=9 bodies=2 slots=11 items=99 icons=198 animations=21 projectiles=6 effects=5`, exit `0` |
| Locomotion and facing smoke | `PARTY_FORGE_LOCOMOTION_SMOKE_OK directions=4 walk=1 idle=1 smooth_turn=1 attack_lock=1 equipment_independent=1 grounding=1 shadow=1`, exit `0` |
| All-class visual smoke | `PARTY_FORGE_CHARACTER_VISUAL_QA_SMOKE_OK classes=9 bodies=2 combinations=18 grounding=18 shadows=18 bars=18 equipment=18 actions=18 projectiles=1`, exit `0` |
| Equipment icon validation | `EQUIPMENT_ICON_VALIDATION_OK sets=9 items=99 unique_master=99 unique_runtime=99`, exit `0` |
| Hardware-rendered QA | `PARTY_FORGE_CHARACTER_VISUAL_QA_OK classes=9 bodies=2 views=4 state_samples=19`, exit `0` |
| Exact-head rendered-evidence drift | `FINAL_RENDER_TRACKED_DRIFT_EXIT=0` |
| Whitespace validation | `git diff --check`, exit `0` |

The renderer used Godot 4.7.1 Forward+ on the NVIDIA GeForce RTX 4070 Ti SUPER. Two identical 361-file render passes had `RENDER_DETERMINISM_CHANGED=0`.

## Generation and manifest checks

- Shared humanoid builder repeat: `HUMANOID_DETERMINISTIC=True`.
- Meaningful equipment/source targets checked: `17`; repeat drift: `0`.
- Manifest rows: `342` (`9 classes x 2 bodies x 19 samples`).
- Guarded idle/start/recovery rows: `144`.
- Guarded rows with `hand_behind_torso=true`: `0`.
- Maximum guarded arm-span ratio: `0.544636`.
- Equipment remains independently unequippable and all equipment/item/icon counts remain unchanged.

## Visual review

All 18 regenerated contact sheets were reviewed, with full-resolution close inspection of Fighter masculine/feminine, Ranger, Marksman, Paladin, and Mage. The review found no idle A/T pose, no hands held behind the back, no attack recovery snap to the obsolete display pose, and no Fighter blade or shield body built through the arms. Ranged, heavy-melee, dual-wield, and caster equipment remain class-readable.

Evidence root: `docs/qa/character-presentation-quality/`

Manifest: `docs/qa/character-presentation-quality/manifest.json`

## Main-checkout safety and deferred observation

- The feature branch has no diff for `scenes/game/main.tscn`.
- The pre-existing main-checkout edit remains byte-identical at SHA-256 `88938B050B59081EDA7F898D164F200C9808BEB839C48D4D6BE04A17841D5E5F`.
- Generated `.uid` and `.png.import` sidecars were excluded from commits.
- A normal player-controlled session remains useful after integration for subjective animation feel at final gameplay zoom; it is not represented as an automated pass.
