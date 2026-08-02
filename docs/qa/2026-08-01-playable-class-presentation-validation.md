# Playable Class Presentation Validation

**Implementation branch:** `feat/playable-class-content`

**Godot:** 4.7.1 stable

**Validation completed:** 2026-08-02

## Result

The playable-class presentation expansion passed its automated, fail-closed smoke, deterministic-generation, and rendered visual-review gates.

- 99 unique equipment bases, 99 linked equipment-presentation resources, and 99 independent item scenes are tracked.
- 198 tracked item icons are present: one transparent 256x256 master and one transparent 128x128 runtime icon per item.
- Nine class profiles use the shared humanoid presentation with masculine and feminine body presets.
- The eleven equipment-sheet slots are supported. The two reusable unequipped body scenes remain tracked.
- Fighter defaults to the red sword-and-shield Forge Vanguard and retains its hammer as a selectable non-default item.

## Recorded automated evidence

All commands ran from the feature worktree with a hermetic `APPDATA` and the Godot 4.7.1 console executable.

| Gate | Recorded result |
| --- | --- |
| Full unit suite | `TEST_SUMMARY: PASS (89 suites)`, exit code 0 |
| Playable presentation smoke | `PARTY_FORGE_PLAYABLE_PRESENTATION_SMOKE_OK classes=9 bodies=2 slots=11 items=99 icons=198 animations=21 projectiles=6 effects=5`, exit code 0 |
| Locomotion smoke | `PARTY_FORGE_LOCOMOTION_SMOKE_OK directions=4 walk=1 idle=1 attack_lock=1 equipment_independent=1`, exit code 0 |
| Icon validation | `EQUIPMENT_ICON_VALIDATION_OK sets=9 items=99`, exit code 0 |
| Contact sheets | `EQUIPMENT_CONTACT_SHEET_BUILD_OK sets=9 items=99` and identical second-run SHA-256 hashes |
| Complete asset regeneration | `PLAYABLE_CLASS_REGEN_DETERMINISTIC builders=9 files=136` after the intentional canonical normalization pass |
| Rendered QA capture | `PLAYABLE_CLASS_QA_CAPTURE_OK classes=9 bodies=2 views=4 files=18` using the NVIDIA OpenGL renderer |

The full suite deliberately exercises fail-closed paths that write expected warning/error markers. The process nevertheless returned exit code 0 and printed the passing suite marker.

## Contract coverage

- `EquipmentEligibility` accepts eligible Ranger/Marksman armour exchange, rejects Ranger greatbows, reserves Frost Mage offhand while its staff is equipped, and permits the explicit bow/quiver exception.
- Release/impact sequencing prevents damage, projectile launch, and healing before the declared event; a valid event executes once, while duplicate or stale events fail closed.
- Ranger and Marksman use different draw durations (`0.42` versus `1.55` seconds), release times (`0.18` versus `1.15` seconds), bow silhouettes, and projectile scale (Marksman `1.45`).
- Fire, frost, lightning, healing, chaos, standard-arrow, and heavy-arrow presentation definitions instantiate. Specialized-scene failure retains the post-release generic fallback.
- Leader and companion scenes activate every class profile without exposing the fallback capsule. Collision, groups, palettes, hit/flinch, downed/revive, damage, and Cleric healing are covered by the automated suite.
- Equipment roots attach below declared sockets. Focused equipment tests verify that arms/body geometry and every weapon or shield remain separate nodes; no weapon or shield mesh is baked into either body preset.
- Idle, walk, primary attacks, Cleric heal, and hit/flinch actions are present. Pose-sampling tests reject A-pose-like arm extension in shipped idle/attack samples.

## Rendered visual matrix

The nine classes were rendered for each body preset at the gameplay review distance. Each class/body pair was inspected from front, three-quarter, side, and rear views, followed by its primary action at release and hit/flinch feedback.

Observed results:

- Fighter sword and shield remain visually distinct from the hands and arms through idle and attack poses; the hammer remains a clean alternative attachment.
- Both body presets keep ground contact and use the same socket hierarchy. No missing equipment, detached weapons, full A-pose idle, or gross bounds failure was visible.
- Ranger and Marksman remain distinguishable by bow size, stance, release pose, and arrow presentation.
- Paladin/Rogue silhouettes read as heavy shield-and-hammer versus light dual-dagger equipment.
- Mage, Frost Mage, Cleric, and Warlock remain distinguishable through palette, focus/staff/sceptre/tome/grimoire silhouettes, and action pose.
- Contact-sheet review found non-empty, transparent, consistently padded icons. Fighter icons were normalized through the same current renderer as the other eight sets.

The interactive review scene is `scenes/dev/character_presentation_sandbox.tscn`. It exposes nine class choices, both bodies, eleven slots, item/action diagnostics, primary/hit/effect controls, base-body toggling, and Fighter weapon cycling.

## Reproduction

Run these final gates after any presentation or equipment change:

```powershell
& $godot --headless --path . --script res://tests/test_runner.gd
& $godot --headless --path . --script res://tests/integration/character_presentation_sandbox_runner.gd
& $godot --headless --path . --script res://tests/integration/character_locomotion_smoke.gd
& $godot --headless --path . --script res://tools/validate_equipment_icons.gd -- --sets=all
```

Open the sandbox for the visual matrix whenever body geometry, sockets, equipment scenes, animations, or materials change.

## 2026-08-02 icon distinction correction

- Replaced filename-guessed slot silhouettes with catalog- and registered-slot-driven icon families.
- Regenerated 99 transparent 256px masters, 99 transparent 128px runtime icons, and nine class contact sheets.
- Verified 99 unique master pixel hashes and 99 unique runtime pixel hashes through independent SHA-256 maps.
- Verified deterministic regeneration across all 207 PNG outputs with `EQUIPMENT_ICON_DETERMINISM_OK files=207`.
- Reviewed all nine contact sheets at original resolution. Every sheet passed for correct slot silhouette, visible distinction within the set, class-palette coherence, runtime-size readability, transparent padding, centering, clipping, and visual noise. The related Ranger and Marksman palettes remain intentionally earthy while their bow, quiver, and identity details remain distinguishable.
- A clean Godot editor import scan exited 0 without script or resource-import errors.
- Standalone validation exited 0 with `EQUIPMENT_ICON_VALIDATION_OK sets=9 items=99 unique_master=99 unique_runtime=99`.
- Presentation smoke exited 0 with `PARTY_FORGE_PLAYABLE_PRESENTATION_SMOKE_OK classes=9 bodies=2 slots=11 items=99 icons=198 animations=21 projectiles=6 effects=5`.
- Locomotion smoke exited 0 with `PARTY_FORGE_LOCOMOTION_SMOKE_OK directions=4 walk=1 idle=1 attack_lock=1 equipment_independent=1`.
- The complete regression suite exited 0 with `TEST_SUMMARY: PASS (92 suites)`. Its existing negative-case diagnostics and exit-time leak notices remained present without changing the passing result.
- Preserved the 99 resources as canonical base items for the equipment system. Rarity and affix visuals remain future runtime item-instance layers rather than duplicated base resources.
