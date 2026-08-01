# 8. Visuals, Audio, Effects, and UI

> **Architecture baseline:** `a293f6208bd3a62246043c1b3e7c0a49ad5fef73`<br>
> **Godot version:** `4.7.1`<br>
> **Last checked:** `2026-08-01`

## What you will learn

- Import a 3D source asset without coupling gameplay to generated import data.
- Replace placeholder presentation while preserving scripts, health, attacks, collision, and targeting.
- Make per-instance material changes without mutating a shared Resource.
- Give effects and audio clear scene ownership.
- Modify UI without breaking Party Forge's responsive layout contract.
- Verify and roll back presentation work independently of combat behavior.

## Source assets, imported Resources, and wrapper scenes

For manually authored 3D exchange, prefer glTF 2.0 (`.glb` or `.gltf`). Godot also supports other documented formats, but glTF is the recommended interchange path for predictable scene, material, skeleton, and animation import.

Copy the source file inside the project, for example under `res://assets/models/`. Godot notices it and imports it automatically. Select the file and use the **Import** dock to inspect or change import options; press **Reimport** after changing them.

The source asset remains the durable input. Its `.import` metadata records how Godot should process it, while generated cache files under `.godot/imported/` are regenerable. Do not hand-edit generated cache artifacts or build game-owned logic inside them.

A wrapper scene is the stable boundary:

```text
TrainingActor (game-owned scripted root)
├── HealthComponent
├── AttackController
├── CollisionShape3D
├── MeshInstance3D or Presentation
└── other game-owned children
```

The visual child may use an imported mesh or instantiate an imported scene. The wrapper keeps the scripted root, collision, components, groups, and node-name contracts stable when the artist replaces and reimports the source file. An inherited scene can also preserve overrides, but review inherited changes after every source reimport.

> **Godot rule:** A source asset inside `res://` is imported into engine Resources. Import settings belong in the Import dock, and reimport can rebuild generated data.

> **Party Forge convention:** Gameplay owns the actor wrapper; imported art lives below its presentation boundary. Reimporting art must not replace the gameplay root.

## Implemented character-presentation adapter (Forge Vanguard)

Party Forge now has a game-owned `CharacterPresentation` adapter at `res://scenes/characters/presentation/character_presentation.tscn` (script: `res://scripts/presentation/character_presentation.gd`). Party actors retain their direct `MeshInstance3D` as the conservative fallback boundary; the adapter receives a `CharacterVisualProfile`, instantiates its `presentation_scene` below `Presentation`, and hides the fallback only after that profile has validated and applied. If a profile is absent, invalid, or cannot instantiate, the adapter keeps the capsule fallback visible and logs a `PARTY_FORGE_PRESENTATION_ERROR` once for the failed operation. Classes without an assigned profile therefore remain playable as capsules.

The Fighter is assigned the equipped `res://data/presentation/profiles/forge_vanguard.tres`, which instantiates `res://scenes/characters/presentation/forge_vanguard_model.tscn`. It defaults to the masculine body, red palette, and the seven visible Forge Vanguard starter items (sword, shield, helmet, body armour, gloves, boots, and belt). The generated in-project first draft has no external art-license dependency.

The neutral covered block-mannequin bodies are independently reusable with no equipment enabled by default:

- Masculine scene/profile: `res://scenes/characters/presentation/forge_base_masculine.tscn` and `res://data/presentation/profiles/forge_base_masculine.tres`.
- Feminine scene/profile: `res://scenes/characters/presentation/forge_base_feminine.tscn` and `res://data/presentation/profiles/forge_base_feminine.tres`.

Both base profiles expose the same public model API, the red/blue/green palettes, and all available equipment definitions while deliberately keeping `default_equipment_visuals` empty. This makes an unequipped base body a reusable presentation profile rather than a hidden variant of the equipped fighter.

### Equipment and feedback contract

The exact PoE1-style visual slots are `main_hand`, `off_hand`, `helmet`, `body_armour`, `gloves`, `boots`, `belt`, `amulet`, `ring_left`, and `ring_right`. Every equipped definition declares at least one readability channel: sword and shield use geometry; helmet uses geometry and silhouette; body armour uses geometry, silhouette, and palette; gloves, boots, and belt use geometry and palette; amulet uses emission and emblem; and each ring uses emission. Definitions live under `res://data/presentation/equipment/forge_vanguard_*.tres`, and `EquipmentSlotCatalog` is the authoritative ten-slot list.

`main_hand` currently exposes two visual definitions: `forge_vanguard_sword` and `forge_vanguard_hammer`. The Fighter equips sword first by default; the preserved hammer remains selectable without altering its original box geometry. Available profile equipment may contain multiple definitions for one slot, while default equipment remains one item per slot. Consumers should use equipment-ID lookup for an exact item or slot-variant lookup for cycling.

The model duplicates `StandardMaterial3D` resources for an instance before applying its palette or feedback. Palette, white hit flash, downed grayscale, and restored base color are therefore instance-local: one red actor and one blue actor can coexist without recoloring one another. The adapter maps Fighter `fighter_cleave` only to `attack_slash`; its model also supplies `idle`, `attack_combo`, and `hit_flinch`. The current in-place clip durations are idle 1.6 seconds, slash 0.55 seconds, combo 0.9 seconds, and flinch 0.25 seconds. Presentation does not alter combat damage timing.

### Sandbox and visual review

Launch `res://scenes/dev/character_presentation_sandbox.tscn` to review two simultaneous adapters, named Masculine and Feminine, with the fallback capsule comparison. Its controls are: `1`/`2` body, `R`/`B`/`G` palette, `I` idle, `A` slash, `C` combo, `H` hit, `Q`/`E` cycle the selected slot, `Space` toggle that slot, and `M` toggle the selected side between equipped and its separate unequipped base profile. The hermetic smoke entry point is `res://tests/integration/character_presentation_sandbox_runner.gd`.

The sandbox `V` control cycles the selected slot's available variants through `CharacterPresentation.apply_equipment_visual`; it does not toggle model nodes directly. The Fighter idle is a combat-ready guard with shield raised and the main-hand item carried forward/down. Slash, combo, and flinch retain their original durations and recover to the same guard without model-root motion or gameplay timing changes.

For live review, verify the high-angle red masculine / blue feminine / capsule composition, then inspect sword, shield, helmet, body armour, gloves, boots, belt, and jewelry readability at close range. Exercise the four clips, hit flash restoration, downed gray, and revival color with both models visible. Valid sandbox interactions must not add parser, import, runtime, or `PARTY_FORGE_PRESENTATION_ERROR` entries to the editor/game logs.

### Deferred Blender/glTF replacement contract

No Blender installation or Blender-authored asset is part of the current implementation. The reserved source and exchange paths are exactly `assets/models/characters/source/party_forge_humanoid.blend` and `assets/models/characters/party_forge_humanoid.glb`. A later replacement must use one metre per Godot unit, Y-up, feet at the source origin, normalized forward orientation below the gameplay root, a shared humanoid armature, semantic sockets, and exact animation-name preservation (`idle`, `attack_slash`, `attack_combo`, and `hit_flinch`). Import the GLB below the adapter boundary; do not make the imported hierarchy the gameplay root or replace the actor's collision, components, groups, health-bar ownership, or attack contracts.

## Replacing a placeholder model safely

Begin with a disposable duplicate of the actor scene. For a leader or companion, preserve all of these:

- The scripted `CharacterBody3D` root and its `party_actors` group.
- `HealthComponent` and `AttackController` children with their exact names.
- The direct `CollisionShape3D` and its gameplay dimensions.
- The mesh or presentation child used by visual feedback.
- The runtime health-bar contract.

Party Forge attaches `HealthBar3D` at runtime after an actor is created. Do not bake another bar into the art file or rename the actor root in a way that breaks the spawner's lookup. Confirm exactly one `HealthBar3D` exists in the Remote tree during play.

Enemies use the same principle but do not currently have an `AttackController` child: preserve their scripted `EnemyActor` root, `HealthComponent`, collision, hostile group, assigned definition, and presentation child.

The current party and enemy actor scripts look for a direct child named `MeshInstance3D` when applying damage-flash color. A single imported mesh can replace that node's Mesh Resource safely. A complex imported scene nested under `Presentation` will need an intentional visual adapter or recursive mesh handling plus tests; merely deleting the expected direct node silently removes the flash contract.

Use these replacement steps:

1. Duplicate the actor scene into `scenes/dev/` and open the duplicate.
2. Record its root script, groups, collision layers and masks, component paths, collision dimensions, and starting transform.
3. Keep the direct `MeshInstance3D` as the fallback boundary, then assign a validated `CharacterVisualProfile` through the `Presentation` adapter. An imported scene belongs in that profile's `presentation_scene`, never in place of the gameplay root.
4. Reset or deliberately normalize the visual child's transform. Imported scale and forward direction must not leak into the actor root.
5. Run only the duplicate in a sandbox and inspect the Remote tree before changing a production scene.

## Materials and per-instance changes

Mesh and material Resources can be shared by many instances. Changing a shared material at runtime can recolor every actor using it.

For a direct fallback mesh or a presentation-model mesh, duplicate a `StandardMaterial3D` and assign it as the `MeshInstance3D` node-wide override before changing its color:

```gdscript
var source_material := mesh_instance.material_override as StandardMaterial3D
if source_material == null:
    source_material = mesh_instance.get_active_material(0) as StandardMaterial3D
if source_material == null:
    push_warning("Assign a StandardMaterial3D before making an instance override.")
    return
var unique_material := source_material.duplicate() as StandardMaterial3D
if unique_material == null:
    return
unique_material.albedo_color = Color(0.25, 0.70, 0.95)
mesh_instance.material_override = unique_material
```

The casts and null guard reject a missing material or a different material type before `duplicate()` is called. `get_active_material(0)` is only the fallback source; the unique copy is assigned to `material_override`, which applies to the whole node.

This node-wide assignment remains appropriate for fallback meshes. The Forge Vanguard model uses the same duplication rule internally, but tracks its own base materials so its palette, white hit flash, downed gray, and restoration remain local to that adapter instance. `EnemyActor.configure()` records the current node-wide albedo as its base color, so a Training Swarmer can flash white and then restore the selected color.

Use a shared material when all instances should change together. Use a duplicated node-wide override when color, emission, transparency, or hit feedback belongs to one Party Forge actor. Verify with two simultaneous instances: changing one must not change the other.

> **Godot rule:** Resources are reference-counted data and may be shared. Editing one shared material affects every user of that Resource.

## Collision is separate from visible geometry

A visible mesh answers “what does this look like?” A `CollisionShape3D` answers “where can physics and attacks interact with it?” Replacing one does not automatically update the other.

Keep Party Forge actor collisions simple and gameplay-focused. A capsule, box, cylinder, or sphere is usually more stable and faster for a moving `CharacterBody3D` than detailed render geometry. `CollisionShape3D` nodes for a physics body must be direct children of that body to participate.

After a visual replacement, compare the collision outline with the silhouette from the combat camera. Adjust only when targeting, contact distance, navigation, or perceived hit fairness requires it. Do not trace every armor plate or animation pose.

## Effects and lifetime ownership

The active gameplay scene and combat sandbox provide an `Effects` container for transient visuals and reward objects. Spawn world effects there rather than under the HUD or an arbitrary actor, unless the effect must follow that actor and the ownership is explicit.

Every transient needs a complete lifetime:

- Start on an owned event such as attack, hit, death, or telegraph.
- End on animation completion, timer expiry, impact, invalid target, cancellation, or scene shutdown.
- Disconnect or tolerate signals that may arrive after the owner begins exiting.
- Call `queue_free()` exactly once and avoid unbounded timers or emitters.

Hostile projectiles and telegraphs must join `hostile_transient_effects`. Party Forge clears that group when the run reaches victory or defeat, and the combat sandbox clears it with **Clear Hostiles**. Existing examples include the enemy projectile, danger ring, and charge telegraph scenes.

Keep decorative, harmless effects out of the hostile group unless combat end should forcibly cancel them. Group membership is a lifecycle contract here, not only a label.

## Positional and non-positional audio

Use `AudioStreamPlayer3D` for sound that belongs to a world position: enemy attacks, impacts, footsteps, or spatial ambient emitters. Distance and direction are evaluated relative to the active listener, normally associated with the camera unless an `AudioListener3D` is active.

Use `AudioStreamPlayer` for non-positional sound: UI clicks, menu feedback, music, or narration that should not attenuate with world distance.

For either node, review:

- `stream`: the imported audio Resource.
- `volume_db`: gain without editing the source file.
- `pitch_scale`: playback pitch and speed; use variation deliberately.
- `bus`: the named Audio bus receiving the sound.
- Ownership and cleanup: whether the player lives with an actor, effect, UI scene, or persistent music owner.

For 3D audio, also test listener/camera position, attenuation distance, directionality if used, and whether freeing the actor cuts off an important sound. A one-shot impact may need an effect-owned player under `Effects` so it can finish after the projectile disappears.

> **Current limitation:** Party Forge does not define a custom audio-bus layout or an established audio integration in the reviewed project. Use only buses that actually exist in the project, and design a named bus layout as a separate reviewed change; do not assume Music, SFX, UI, or Voice buses are present.

## UI scenes, containers, anchors, and logical resolution

Read the focused [Responsive UI tutorial](../development/RESPONSIVE_UI_TUTORIAL.md) before changing HUD layout. This section is only the integration summary.

Party Forge uses a `1920 × 1080` logical viewport, `canvas_items` stretch mode, and `keep` aspect behavior. Anchors express a Control node's relationship to its parent. Containers own the layout of their child Controls and may override manual offsets, so resize through container settings, size flags, separation, and minimum sizes rather than fighting the container.

Keep world-space presentation under gameplay nodes and screen-space UI under the HUD's Control hierarchy. Test the tutorial's three target window sizes—`1280 × 720`, `1920 × 1080`, and fullscreen 4K—not only the editor preview; all three targets are 16:9. Also make a separate non-16:9 check: stretch aspect `keep` preserves the logical aspect ratio and leaves unused space as letterboxing or pillarboxing, so confirm the framed UI remains readable and reachable rather than expecting it to fill that window.

> **Party Forge convention:** The responsive UI tutorial is the single detailed procedure. Link to it and update it when the project-wide responsive contract changes instead of duplicating competing instructions in actor or content chapters.

### Upgrade cards, tooltips, and recipients

`LevelUpPanel` presents authored offers as three `UpgradeCard` controls. Hover and keyboard/controller focus both request the same dictionary from `UpgradePresentationService.tooltip()`, so the tooltip title, summary, resolved effect lines, and keyword explanations have one formatter instead of separate mouse and focus text paths. `UpgradeTooltipPanel` only renders that dictionary.

Selecting a single-recipient card opens `UpgradeRecipientPicker`. Its rows show each stable member ID, stored character name, class, live current/maximum health from the corresponding direct `PartyActor`, projected stat changes, and a disabled reason when the member is ineligible or capped. Party- and trait-scoped cards proceed without a character target. The confirmation view emits `confirmation_requested(choice, member_id)` once; `PartyForgeMain` revalidates and applies it centrally before telling the panel to complete. A stale or invalid target keeps the level pending and leaves the confirmation visible with an error.

The implemented upgrade UI is selection-time presentation, not an inventory or passive-tree screen. Rarity styling/scaling, save/load UI, and player-facing character-renaming controls remain deferred.

## Exercise: replace presentation without changing combat

This exercise changes only a disposable training copy.

1. Duplicate `scenes/enemies/swarmer.tscn` as `scenes/dev/training_swarmer_visual.tscn`.
2. Duplicate the combat sandbox as `scenes/dev/training_visual_sandbox.tscn`, then instance the training Swarmer under `Enemies`. Connect its reward signal to `SpawnDirector` as described in Chapter 7.
3. Before changing art, record the enemy definition path, root script, groups, collision layer and mask, collision shape and dimensions, starting position, movement speed, contact cadence, damage, health, and reward.
4. Replace only the existing `MeshInstance3D` Mesh Resource with a training mesh. If importing a source model, keep it inside a disposable assets folder and use its imported Mesh Resource.
5. Duplicate its `StandardMaterial3D`, assign the copy to the edited `MeshInstance3D.material_override`, and change the copy's `albedo_color`. Put two instances in the sandbox and confirm only the edited instance changes.
6. Run the sandbox before and after. Compare target choice, path, contact distance, hit cadence, damage, health, reward, and collision debug view. The visible silhouette may change; those combat observations must not.
7. Damage the edited Training Swarmer without defeating it. Confirm its node-wide material flashes white and returns to the selected color, one runtime `HealthBar3D` appears where applicable, and **Clear Hostiles** removes enemies and hostile transient effects.

> **Checkpoint:** Before cleanup, preserve a before/after visual comparison; confirm combat, collision, health, and reward behavior are unchanged; confirm the second instance keeps its own material and color when the edited instance changes; and confirm the edited instance restores its selected material color after damage flash. Do not continue if any observation fails.

8. Stop the run and remove the disposable scenes, training source asset, `.import` metadata that belongs to it, and generated UID files. Do not delete shared imported files.

The exercise is successful when the screenshots look different but the recorded combat observations match.

## Production checklist

- Source art and audio are inside intentional `assets/` folders with documented provenance and license.
- Import settings are reviewed in the Import dock and the asset reimports without errors.
- A game-owned wrapper preserves the scripted root, components, groups, collision, and node-name contracts.
- Actor scale and orientation are normalized below the gameplay root.
- Collision remains simple, fair, and independent from render detail.
- Party Forge actor color changes use a duplicated `StandardMaterial3D` assigned to the node-wide `MeshInstance3D.material_override` and are tested with two instances.
- Damage flash reaches the intended mesh node and restores the expected base color afterward.
- Transients spawn under `Effects`, own their lifetime, and hostile ones join `hostile_transient_effects`.
- 3D sounds are tested from near, far, left, and right of the active listener.
- UI and music sounds use non-positional playback and only verified project buses.
- HUD changes follow the responsive UI tutorial and pass its resolution matrix.
- Upgrade-card mouse hover and keyboard/controller focus show the same formatted tooltip; recipient health is read live and an invalid confirmation does not dismiss the pending level.
- The full automated suite and a before/after sandbox comparison pass before commit.

## Verification

Verify presentation independently from gameplay:

1. Reimport the source asset and reopen the wrapper. Confirm no missing dependencies, reset transforms, or lost overrides.
2. Run the disposable scene with visible collision shapes enabled. Compare its recorded collision and behavior before and after.
3. Place two instances together and trigger damage flash on only the edited actor. Confirm the other actor never changes and the edited actor returns to its selected color when the flash ends.
4. Inspect the Remote tree for the scripted root, components, one expected health bar, `Effects` ownership, groups, and cleanup.
5. Exercise hostile cleanup during an active projectile or telegraph, not only after effects finish naturally.
6. Test positional audio from multiple camera/listener positions and non-positional audio during camera movement.
7. Run the responsive UI tutorial's window-size checks after any HUD change.
8. Run focused scene-contract tests, the full suite once, `git diff --check`, and `git status --short`.

Automated tests can prove node contracts and cleanup. They cannot replace listening, visual comparison, collision-debug observation, and responsive-layout inspection.

## Common mistakes

- Editing generated files under `.godot/imported/` instead of the source asset or Import settings.
- Replacing the scripted actor root with an imported scene root.
- Deleting `HealthComponent`, `AttackController`, collision, groups, or the direct flash-target mesh while changing appearance.
- Scaling the gameplay root to compensate for a badly scaled visual child.
- Generating detailed collision from render geometry for a moving character.
- Mutating a shared material and recoloring every instance.
- Using only a per-surface override on a current Party Forge actor, then losing that appearance when damage flash assigns its node-wide override.
- Spawning effects under arbitrary owners with no timeout or completion cleanup.
- Forgetting `hostile_transient_effects` on a hostile projectile or telegraph.
- Using `AudioStreamPlayer3D` for UI or music, or positional sound without testing the active listener.
- Assigning audio to bus names that are not present in the project.
- Dragging Controls that are managed by a Container and expecting manual offsets to persist.
- Testing one editor viewport instead of the responsive resolution matrix.

## Rollback and reimport safety

Restore references before deleting source material:

1. Reassign the wrapper to its previous mesh, material, audio stream, or child scene. Restore its previous transform and import-dependent overrides.
2. Restore collision only if the presentation change deliberately altered it; compare against the recorded dimensions.
3. Remove presentation-specific scripts, effects, audio players, and tests after their scene references are gone.
4. Restore prior Import dock settings and press **Reimport**. Reopen every wrapper that uses the source and inspect inherited overrides.
5. Run scene-contract tests and sandbox comparisons while both old and new assets are still available.
6. Delete the unused source asset and its associated `.import` metadata only after repository search shows no remaining references. Generated `.godot/imported/` cache content can be regenerated; do not treat it as the source of truth.
7. Reopen the project, allow import to complete, run focused and full verification, and inspect the diff for unrelated reimports.

Never delete a shared source asset merely because one wrapper stopped using it. Search by `res://` path first.

## Official Godot references

- [Importing 3D scenes](https://docs.godotengine.org/en/4.7/tutorials/assets_pipeline/importing_3d_scenes/index.html)
- [Introduction to 3D](https://docs.godotengine.org/en/4.7/tutorials/3d/introduction_to_3d.html)
- [AudioStreamPlayer3D](https://docs.godotengine.org/en/4.7/classes/class_audiostreamplayer3d.html)
- [AudioStreamPlayer](https://docs.godotengine.org/en/4.7/classes/class_audiostreamplayer.html)
- [Multiple resolutions](https://docs.godotengine.org/en/4.7/tutorials/rendering/multiple_resolutions.html)
