# Fighter Main-Hand Variants and Combat-Ready Guard

Status: approved design

Date: 2026-08-01

## Context

The current Forge Vanguard `main_hand` visual is named and configured as a sword, but it is a single narrow `BoxMesh`. In the current mild mannequin/A-like idle pose, that geometry reads as a hammer or club rather than a sword. The geometry should not be discarded or reshaped: it will be preserved as a legitimate hammer equipment visual that can later support a Paladin or another equipment-driven class.

Party Forge is moving toward equipment-based character presentation. This correction therefore needs to prove a real item-variant swap: unequip the hammer visual, equip a separate sword visual, and keep only the selected `main_hand` geometry visible.

## Goals

- Preserve the current weapon geometry and transform unchanged as `forge_vanguard_hammer`.
- Add a separate, unmistakably sword-shaped `forge_vanguard_sword` visual.
- Equip sword and shield by default on the Fighter.
- Allow multiple available equipment definitions for the same slot.
- Allow the sandbox to switch between the hammer and sword through the normal presentation API.
- Replace the mannequin-like idle with a combat-ready guard that raises the shield and carries the equipped main-hand weapon forward and down.
- Preserve animation durations, gameplay collision, targeting, damage timing, actor ownership, palettes, and body reuse contracts.

## Non-goals

- Do not remodel, resize, or otherwise alter the preserved hammer geometry.
- Do not build inventory UI, item statistics, loot generation, or persistence.
- Do not introduce a global equipment database yet.
- Do not add Blender or GLB source assets in this correction.
- Do not change combat hit timing, movement, navigation, or collision shapes.

## Equipment-variant architecture

`CharacterVisualProfile.default_equipment_visuals` continues to allow at most one definition per slot. That preserves the rule that only one item is equipped by default.

`CharacterVisualProfile.available_equipment_visuals` will allow multiple definitions with the same slot, provided every definition has a unique non-empty `id` and `geometry_key`. The Fighter and both reusable base profiles will list sword before hammer for `main_hand`, followed by the existing definitions for the other nine PoE1-style slots.

The existing `get_available_equipment_visual(slot_id)` method remains for backward compatibility and returns the first matching definition. Sword remains first, so existing callers continue to select the Fighter's sword. Two explicit APIs will be added:

- `get_available_equipment_visual_by_id(equipment_id)` returns one exact definition.
- `get_available_equipment_visuals_for_slot(slot_id)` returns all available variants for that slot in declared order.

Profile validation will continue to reject duplicate slots in the default collection. For the available collection it will reject duplicate definition IDs and duplicate geometry keys while permitting repeated slot IDs.

`ForgeVanguardModel.apply_equipment_visual()` already selects geometry by `geometry_key` and hides the other nodes in the same slot. It remains the authoritative equip operation. Invalid or unmatched definitions return `false` without changing the currently visible item.

## Hammer and sword resources

The current `MainHandVisual` node will be renamed to `HammerVisual`. Its mesh dimensions, material, local transform, parent socket, palette channel, and current visible shape will remain unchanged. Its metadata becomes:

- `equipment_slot = main_hand`
- `equipment_visual_id = forge_vanguard_hammer`

A new `forge_vanguard_hammer.tres` definition will declare the `main_hand` slot, `forge_vanguard_hammer` geometry key, and geometry readability channel.

The existing `forge_vanguard_sword.tres` path and `forge_vanguard_sword` ID remain stable, but its geometry key will address a new `SwordVisual` node. The sword is a separate low-poly Godot-first item made from distinct blade, pointed tip, crossguard, grip, and pommel meshes. It shares the right-hand socket but does not reuse or modify the hammer mesh. Metal parts use the existing metal palette region; the grip uses a dark leather material. The overall proportions must read as a one-handed sword from the normal high-angle gameplay camera.

Both weapon roots are present in the equipped model and generated masculine/feminine base scenes. The Fighter profile equips `forge_vanguard_sword` by default. Base profiles continue to equip nothing by default, so their sword and hammer roots remain hidden until an equipment definition is applied.

## Combat-ready guard and animation recovery

The idle pose will no longer use straight, slightly separated mannequin arms. Its rest silhouette will:

- raise the shield across the left side of the torso;
- bend the left elbow so the shield protects rather than hangs;
- bend and lower the right arm;
- angle the equipped main-hand item forward and down, clear of the legs and shield;
- retain subtle breathing and weight motion without root translation.

The idle clip remains 1.6 seconds. `attack_slash`, `attack_combo`, and `hit_flinch` retain their current durations and gameplay-independent timing. Their first and final keyed poses will use the new guard so playback does not snap through the former mannequin pose. Attack peak poses may retain the existing functional shoulder, elbow, sword, and shield motion as long as they begin and recover cleanly to guard.

The pose is presentation-only. `PartyActor`, collision nodes, combat targets, attack execution, damage timing, and navigation transforms remain unchanged.

## Sandbox interaction

The existing sandbox retains Q/E slot selection and Space visibility toggling. A new `V` control cycles the selected slot's available visual variants. For `main_hand`, repeated use switches sword to hammer and hammer to sword independently for the masculine and feminine sides.

Variant cycling calls the same profile lookup and `CharacterPresentation.apply_equipment_visual()` path intended for future equipment consumers. It must not set node visibility directly. The instruction label will document the new control.

## Error handling and compatibility

- Unknown equipment IDs return no definition.
- Slots with no available definitions return an empty typed array.
- Duplicate available IDs or geometry keys invalidate the profile.
- A failed equip leaves the previously equipped item visible.
- Existing slot-only callers continue to receive the first declared definition.
- Existing equipment resources, palette behavior, hit flash, downed state, and fallback capsule behavior remain compatible.

## Verification design

Implementation will follow RED-GREEN-REFACTOR with focused tests that initially fail against the current model.

Automated coverage will verify:

- available collections accept sword and hammer in `main_hand` while default collections still reject duplicate slots;
- duplicate available IDs and geometry keys are rejected;
- lookup by ID and lookup of every variant for a slot return deterministic results;
- the current hammer mesh dimensions and transform remain unchanged;
- sword and hammer use distinct equipment roots and geometry keys;
- equipping one hides the other, and failed equips do not change visibility;
- the Fighter defaults to sword while reusable base profiles remain unequipped;
- sandbox variant cycling switches through the presentation adapter;
- idle shoulder/elbow keys form a non-mannequin guard;
- slash, combo, and flinch begin and recover to guard without root motion;
- scene generation remains deterministic;
- the existing full suite and presentation smoke still pass.

Live Godot QA will inspect masculine and feminine Fighters from the sandbox's normal high-angle camera, confirm sword-versus-hammer readability, sample the guard and action recovery poses, and check game/editor logs for new presentation errors.

## Expected file scope

The implementation is expected to touch the Fighter presentation builder, generated Fighter/base scenes, hammer and sword equipment resources, visual-profile validation/query code, sandbox controls, presentation tests, smoke coverage, and the visual handbook. No gameplay scene, collision shape, combat executor, or inventory implementation is in scope.
