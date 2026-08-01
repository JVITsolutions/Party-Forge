# Party Forge Modular Character Presentation Design

## Purpose

Party Forge needs its first readable three-dimensional class character without coupling gameplay to one final art asset. The first deliverable is a stylized low-poly Fighter called the Forge Vanguard. It replaces the Fighter capsule visually while preserving the current actor root, collision, movement, targeting, health, and combat timing.

The same presentation foundation must support later humanoid classes through reusable masculine and feminine base bodies, modular equipment, class-specific silhouettes, palette changes, and swappable animation sets. A later Blender-authored glTF pipeline must be able to replace the Godot-native draft without changing gameplay code.

## Repository Context

Party Forge runs on Godot 4.7.1. `leader.tscn` and `companion.tscn` currently use a direct `MeshInstance3D` capsule beneath a scripted `CharacterBody3D`. `PartyActor` expects that direct mesh when applying class color, damage flash, downed gray, and revival color. Fighter presentation work must therefore introduce an intentional presentation adapter instead of deleting the current flash target and hoping an imported hierarchy behaves the same way.

The existing capsule collision remains authoritative. Presentation geometry does not change the `CharacterBody3D`, collision layers, collision mask, `CollisionShape3D`, `HealthComponent`, `AttackController`, party groups, runtime health-bar attachment, or actor scale.

The other active development task uses `.worktrees/playtest-corrections`. Character-presentation implementation must use a separate worktree and must not modify that checkout.

## Approved First-Draft Scope

The first draft includes:

- One reusable Godot-native humanoid presentation system.
- Masculine and feminine humanoid body presets sharing the same pivot names, equipment anchors, scale, and animation contract.
- The Forge Vanguard Fighter silhouette: broad shoulders, compact heroic proportions, sword, shield, heavy armour, dark steel, restrained brass, and Fighter-red accents.
- Red, blue, and green palette presets.
- Ten Path of Exile 1-style equipment slots represented by the visual data contract.
- Four animation clips: `idle`, `attack_slash`, `attack_combo`, and `hit_flinch`.
- Optional Fighter integration through `ClassDefinition`, with safe placeholder behavior for every class that has no visual profile.
- A presentation sandbox that previews body presets, palettes, equipment visibility, and all four clips.
- Automated contract tests plus Godot import, parse, runtime-log, screenshot, and full-suite verification.
- A documented Blender/glTF replacement contract.

## Out of Scope

This draft does not add:

- Inventory, loot generation, item statistics, affixes, sockets, gems, requirements, or equipment UI.
- A unique visible mesh for every future item.
- Final production character art.
- A Blender installation or an authored `.blend` source file when Blender is not currently discoverable.
- Character locomotion animations, class-specific spellcasting, ranged attacks, death, revival, emotes, or facial animation.
- Root-motion-driven gameplay.
- A real two-hit Fighter attack. `attack_combo` is an available presentation clip for a future multi-hit definition; it does not change `fighter_cleave` damage.
- Non-humanoid retargeting.

## Visual Direction

The Forge Vanguard uses a chunky, high-angle-readable silhouette. Shoulder plates, shield, sword, helmet, chest mass, and stance must remain distinguishable from Party Forge's fixed combat camera without relying on texture detail.

The default palette uses the Fighter class color `Color(0.8509804, 0.30980393, 0.30980393, 1)` (`#D94F4F`) for cloth and armour accents. The blue and green preview palettes use `#4F78D9` and `#4FAF72`. Dark steel, brass, skin, and neutral leather remain separate material regions so changing the class accent does not recolor the entire actor.

The two body presets are presentation choices on one humanoid structure. They use the same total height, foot origin, pivot hierarchy, slot anchors, and animation names. Proportion changes may affect shoulders, torso, waist, limbs, and face shape, but cannot require separate gameplay collision or separate animation logic.

## Reuse Rule

Base bodies provide anatomy. Equipment, stance, palette, action animation, and effects provide class readability.

Ordinary humanoid classes reuse the body presets, presentation adapter, collision boundary, equipment slot contract, palette system, idle clip, and hit reaction. Rangers, Mages, Gunslingers, Paladins, Rogues, and similar classes add or replace class-specific gear, stance, weapons, and action clips. Significantly different anatomy may use a different body and rig while still implementing the same presentation adapter API.

Godot-native body variation uses modular geometry and parameterized proportions rather than continuous sculpted morphs. The later Blender source may add shape keys, but class identity must not depend on shape keys alone.

## Scene and Resource Architecture

### Character presentation adapter

Add a game-owned `CharacterPresentation` scene below the existing actor wrapper. It exposes these presentation-only operations:

- `apply_profile(profile)`
- `set_body_preset(preset_id)`
- `set_palette(palette_id, primary_color)`
- `apply_equipment_visual(slot_id, visual_definition)`
- `play_action(animation_id)`
- `flash_hit()`
- `set_downed(is_downed)`

The adapter owns visual nodes, duplicated per-instance materials, animation playback, equipment attachments, and fallbacks. Gameplay code never reaches into imported or native mesh internals.

The initial native hierarchy uses named transform pivots and low-poly `MeshInstance3D` children. The exact mesh construction may change without changing the adapter API. A later wrapper may instance an imported GLB beneath the adapter and map the same operations to a `Skeleton3D`, `AnimationPlayer`, or `AnimationTree`.

### Character visual profile

Add an optional `visual_profile: CharacterVisualProfile` property to `ClassDefinition`. A profile defines:

- `presentation_scene`
- `default_body_preset`
- `default_palette_id`
- `default_equipment_visuals`
- `attack_animation_by_id`
- required animation names

Fighter receives a Forge Vanguard profile. Existing class resources keep `visual_profile` null and continue using the capsule placeholder. This makes the migration incremental and prevents an unfinished presentation library from blocking gameplay content.

### Equipment visual definition

An `EquipmentVisualDefinition` identifies one equipment slot and one or more visual channels:

- Instanced geometry or geometry-family key.
- Attachment socket.
- Palette-region overrides.
- Material or emission accents.
- Optional decal, emblem, or particle hook.
- Optional silhouette modifier.

This is visual metadata only. It does not contain item statistics and does not establish an inventory system.

## Equipment Slot Contract

The initial extensible slot IDs are:

- `main_hand`
- `off_hand`
- `helmet`
- `body_armour`
- `gloves`
- `boots`
- `belt`
- `amulet`
- `ring_left`
- `ring_right`

Visibility is tiered:

- Major silhouette slots: main hand, off hand, helmet, and body armour normally change geometry.
- Secondary readability slots: gloves, boots, and belt normally change a small mesh region, trim, or palette region.
- Abstract readability slots: amulet and rings may use an emblem, emission, restrained particle, or material accent instead of literal jewelry geometry.

Every equipped item must resolve to at least one visible channel. Multiple item definitions may intentionally share a visual family; unique art for every item is not required. Unknown future slots are rejected by validation until the slot registry is intentionally extended.

Draft-one Forge Vanguard defaults are sword in `main_hand`, shield in `off_hand`, heavy helmet, heavy body armour, gauntlet accents, boot accents, and a neutral belt. Amulet and rings have no gameplay items in this milestone, but the sandbox must prove their abstract visual channel can be applied.

## Animation Contract

All clips are in-place and preserve the presentation root transform. Gameplay movement remains authoritative.

- `idle`: approximately 1.6 seconds, looping; breathing, shield weight, and subtle stance shift.
- `attack_slash`: approximately 0.55 seconds; readable wind-up, broad one-handed cleave, and recovery. The current `fighter_cleave` attack maps to this clip and retains its existing damage timing and 0.8-second cooldown.
- `attack_combo`: approximately 0.9 seconds; sword strike followed by shield bash. It is previewable and reusable but is not selected for the current single-hit attack.
- `hit_flinch`: approximately 0.25 seconds; short backward recoil with shoulder and shield response, then return to idle.

The first draft may use an `AnimationPlayer` and an explicit action state. A hit reaction may visually interrupt an attack, but it cannot cancel or repeat gameplay damage. Missing clips fall back to `idle` and produce a presentation error without stopping combat.

## Runtime Data Flow

1. `PartyActor.configure()` reads the class definition.
2. If the class has a valid visual profile, the actor's `CharacterPresentation` applies it. Otherwise the current placeholder remains active.
3. The profile selects a default body, palette, equipment visuals, and attack-animation mapping.
4. Fighter class color supplies the primary palette color. The adapter duplicates relevant materials per actor before applying it.
5. `AttackController.attack_ready` continues to execute gameplay damage through the existing executor and also requests the mapped presentation clip. Presentation playback does not delay the executor.
6. Existing health and damage signals request hit flash, flinch, downed gray, and revival restoration through the adapter.
7. If any presentation operation fails, gameplay continues with the last valid presentation or placeholder.

## Error Handling

Presentation failures use grep-friendly messages beginning with `PARTY_FORGE_PRESENTATION_ERROR` and include class ID, profile ID, operation, and reason where available.

Required fallback behavior:

- Null or invalid visual profile: keep or restore the capsule placeholder.
- Unknown body preset: use the profile default, then the first valid preset.
- Unknown palette: use the profile default and class primary color.
- Invalid or missing equipment visual: hide only that slot and continue.
- Missing attack mapping or animation: remain in or return to `idle`.
- Missing material region: skip that region without mutating shared Resources.
- Invalid presentation scene: log once per actor configuration and preserve gameplay nodes.

Validation must prevent repeated per-frame error spam.

## Blender and glTF Replacement Contract

The long-term source is one master humanoid armature shared by both body presets and ordinary humanoid classes. Blender output uses glTF 2.0 `.glb`, one Godot unit per metre, Y-up, feet at local origin, and Godot-facing forward orientation normalized below the gameplay root. Exported animation names match the adapter contract exactly.

The Blender asset must preserve semantic equipment sockets for head, main hand, off hand, back, belt, and effect attachments. Gloves, boots, body armour, jewelry, and other visual regions may be mesh swaps or material/effect mappings. Both body presets must remain compatible with the same animation and socket contract.

The future durable locations are:

- Editable source: `assets/models/characters/source/party_forge_humanoid.blend`
- Imported exchange asset: `assets/models/characters/party_forge_humanoid.glb`
- Game-owned wrapper: under `scenes/characters/presentation/`

The `.blend` file is not a first-draft requirement because no active Blender executable was found through PATH, Windows installation records, Microsoft Store packages, Steam libraries, or mounted-drive scans. Reconnecting or reinstalling Blender is a separate explicit action.

## Presentation Sandbox

Add a developer presentation sandbox that does not alter ordinary run progression. It must allow a reviewer to:

- Toggle masculine and feminine body presets.
- Select red, blue, and green palettes.
- Toggle each of the ten equipment visual slots.
- Play `idle`, `attack_slash`, `attack_combo`, and `hit_flinch`.
- Place at least two actors together to verify instance-local materials.
- View the model from the approved high-angle gameplay framing and a closer inspection camera.
- Trigger hit flash, downed gray, and revival restoration.

The sandbox must not invent inventory rules or write equipment state into production run data.

## Automated Verification

Focused tests cover:

- Fighter loads a valid Forge Vanguard profile.
- Classes without profiles retain the placeholder path.
- Both body preset IDs resolve on the same presentation contract.
- Red, blue, and green palettes resolve without shared-material mutation.
- All ten equipment slot IDs validate.
- Each draft equipment definition changes at least one visual channel.
- Required animation names exist and `fighter_cleave` maps only to `attack_slash`.
- `attack_combo` exists but does not change or duplicate `fighter_cleave` damage.
- Hit flash affects only the damaged instance and restores its palette.
- Downed and revived states restore the correct presentation colors.
- Actor collision dimensions, layers, masks, groups, and required gameplay child names remain unchanged.
- Invalid profile, palette, slot, material, and animation inputs produce bounded fallback behavior.

Completion also requires:

1. Godot import and parser exit successfully.
2. Focused presentation tests pass.
3. The full existing suite passes without new failures.
4. The sandbox demonstrates both bodies, all palettes, all clips, and equipment visibility.
5. A high-angle screenshot proves Fighter readability beside at least one capsule placeholder.
6. Two simultaneous Forge Vanguards prove independent palettes and hit flashes.
7. Godot editor and game logs contain no new errors.
8. `git diff --check` is clean and the implementation diff contains no changes from the playtest-corrections worktree.

## Acceptance Criteria

The first draft is accepted when a Fighter leader or companion can display the Forge Vanguard through the optional profile, animate idle and the current cleave, preview the future combo, visibly flinch on a hit, switch between both body presets and three palettes in the sandbox, demonstrate all equipment readability channels, and fall back safely without affecting gameplay.

The implementation must remain useful even if the native meshes are later deleted: a Blender-authored GLB can replace the visual internals by implementing the same adapter, profile, animation, material, scale, and socket contracts.
