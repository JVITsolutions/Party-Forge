# Party Forge Character and Blender Handoff

Party Forge's current playable characters are deliberately modular Godot-native source assets. A future Blender/GLB pass may replace their geometry and deformation, but it must preserve the runtime contract below.

## Reusable body sources

These are the reusable unequipped ("nude") handoff scenes requested for future class work:

```text
scenes/characters/presentation/forge_base_masculine.tscn
scenes/characters/presentation/forge_base_feminine.tscn
```

The shared equipped runtime model is:

```text
scenes/characters/presentation/forge_humanoid_model.tscn
```

All three use the same two body-fit presets, pivot hierarchy, sockets, action IDs, and presentation-model API. New classes should reuse these bodies; class identity belongs primarily to modular equipment, palette, stance, timing, projectile scale, and effects.

## Independent equipment handoff

For each item, preserve this path family:

```text
scenes/equipment/<set>/<item_id>.tscn
data/equipment/bases/<set>/<item_id>.tres
data/presentation/equipment/<set>/<item_id>.tres
assets/ui/equipment/master/<set>/<item_id>_256.png
assets/ui/equipment/runtime/<set>/<item_id>_128.png
```

The scene is presentation geometry, the base resource owns equipment eligibility and slot behavior, and the presentation resource links sockets, body fits, materials, icons, and weapon animation family. Do not merge a weapon or shield into an arm/body mesh.

## GLB replacement contract

A Blender-exported replacement must preserve:

- Scene root type/name expected by the Godot wrapper.
- Meter-based scale, presentation origin, ground contact, and Godot forward-axis behavior.
- Masculine and feminine body-fit compatibility.
- Every existing socket ID and the socket's semantic ownership.
- Stable item IDs, supported slot IDs, handedness, reserved slots, weapon family, and launch socket.
- Material/palette channel names, including item-owned color and wearer-accent channels.
- Action IDs, loop behavior, durations, and `release`/`impact` event names and timing.
- Visible bounds accepted by presentation tests.
- The 256/128 icon path and deterministic regeneration behavior.
- Gameplay wrappers: `CharacterBody3D`, collision, health, targeting, groups, and fallback visuals stay outside imported character geometry.

Required model actions currently include shared `idle`, `walk`, and `hit_flinch`, class idles, class primary attacks, and `cleric_healing_blessing`. Imported animation replacements must keep the same IDs unless profiles and all consumers are deliberately migrated together.

## Socket and separation rules

Weapons, shields, quivers, foci, tomes, grimoires, and wearable pieces remain independent scene instances below declared sockets. Tests must be able to clear or replace one slot without changing body geometry or another slot. Main/offhand items never become children of an arm mesh; they attach to hand/socket nodes.

Two-handed equipment reserves offhand through data, not merged geometry. Bows may pair only with compatible quivers through the explicit exception. Rings use loadout-side ownership so one ring resource may support either ring slot.

## Promotion gate

Before replacing a Godot-native asset with GLB output:

1. Open `scenes/dev/character_presentation_sandbox.tscn` and review both bodies from front, three-quarter, side, and rear views.
2. Play idle, walk, primary, and hit/flinch; also review Cleric heal and the Fighter hammer alternative.
3. Run the equipment, playable-presentation, locomotion, full-suite, icon, and fail-closed smoke gates recorded in `docs/qa/2026-08-01-playable-class-presentation-validation.md`.
4. Regenerate icons/contact sheets and require a deliberate reviewed diff.

An imported asset is not promoted merely because it opens in Godot. It must retain socket separation, action-event timing, gameplay wrapper behavior, both body fits, and deterministic item/icon contracts.
