# Playable Class Model and Equipment Expansion Design

**Status:** Implemented and validated (89-suite gate plus presentation and locomotion smoke)

**Date:** 2026-08-01

## Purpose

Expand Party Forge's reusable Forge Vanguard presentation into complete Godot-native presentation for every current playable class while preserving one coherent visual family. The milestone adds eight class starter equipment sets, matching item icons, class- and weapon-specific animations, specialized projectile/effect visuals, and foundational synchronization between animation release events and combat execution.

The existing Fighter is the visual and technical baseline. New characters are not separately interpreted hero models. They reuse the existing masculine and feminine bodies, scale, proportions, material language, and attachment system. Class readability comes primarily from shared archetype uniforms, weapon size, stance, animation tempo, projectile scale, and ability-specific motion.

## Live Baseline

Party Forge currently provides:

- `CharacterPresentation` as the adapter between gameplay-owned party actors and render presentation.
- `forge_vanguard_model.tscn` with masculine and feminine body presets.
- Red, blue, and green palette support.
- Ten presentation slots: main hand, offhand, helmet, body armour, gloves, boots, amulet, two rings, and belt.
- Forge Vanguard sword, shield, preserved hammer, armour, and accessories.
- `idle`, `attack_slash`, `attack_combo`, and `hit_flinch` animations.
- Fighter attack, damage, downed, and revive feedback wired through real `PartyActor` gameplay.
- A generic sphere projectile and generic area/heal effects.

Gameplay-owned `CharacterBody3D`, collision, health, attack controllers, groups, fallback capsule visuals, and party behavior remain outside model ownership and must remain intact.

## Goals

- Add one complete starter equipment sheet for Paladin, Ranger, Marksman, Rogue, Mage, Frost Mage, Cleric, and Warlock.
- Normalize the existing Fighter assets into the same modular item format without redesigning the Fighter.
- Add `legs` as the eleventh equipment slot.
- Save every item as a stable independent resource suitable for the future equipment, loot, inventory, stash, and save systems.
- Save every combat-visible item as an independent 3D scene.
- Produce matching transparent master and runtime icons for equipment-sheet, inventory, tooltip, and ground-pickup UI.
- Preserve class/archetype and equipment-weight restrictions from the approved equipment contract.
- Synchronize melee impact, projectile launch, spell release, and healing application with presentation release events.
- Give each class readable idle, primary attack, and hit/flinch presentation; Cleric also receives a distinct healing action.
- Add specialized arrow, spell, and ability presentation that matches existing class attack data.
- Preserve a later Blender/GLB replacement path without requiring Blender for this milestone.

## Non-Goals

- Implementing the full inventory or equipment UI.
- Implementing random item generation, rarity rolls, affix pools, implicit-stat resolution, crafting, ground cleanup, stash persistence, or extraction.
- Balancing final equipment stats or class combat numbers.
- Adding player-facing body/gender selection UI.
- Adding locomotion animation, skeletal retargeting, or Blender shape keys.
- Replacing gameplay collision or party movement with model geometry.
- Creating three item bases per archetype and slot in this milestone. This milestone contributes one complete originating set per class; later content expands each archetype to the approved minimum of three bases per slot.

## Fighter Visual Bible

Every new model must look native beside the current Forge Vanguard.

### Body and scale

- Reuse the exact existing masculine and feminine base bodies.
- Preserve the current actor scale, body proportions, hand positions, ground contact, and presentation origin.
- Preserve the existing gameplay collision footprint; equipment never changes collision.
- Equipment must fit both body presets without creating a separate character system.

### Geometry

- Use the same Godot-native low-poly primitive construction as the Fighter.
- Prefer broad, hard-readable shapes over small surface detail.
- Match the Fighter's polygon density and silhouette simplicity.
- Avoid texture-dependent detail, photoreal materials, smooth high-poly cloth, or ornament density that makes a class look imported from another art set.

### Materials

- Keep matte material response near the Fighter's `0.78` roughness baseline.
- Reuse the established skin, dark metal, leather, gold, and primary/accent material language.
- Metallic surfaces use the Fighter's restrained metal response rather than mirror-like reflections.
- Equipment owns its primary item color so swapping gear remains visually readable.
- The wearer class color is retained as a secondary accent channel where the item exposes one.
- Default class equipment colors match the class resource closely enough that the original equipped lineup remains immediately readable.

### Icon presentation

- Every icon uses one fixed orthographic camera, light rig, transparent background, object orientation, padding, and scale policy.
- Item color is baked into the transparent item render; rarity frames, comparison state, selection, and cannot-equip overlays remain runtime UI layers.

## Approved Class-Identity Strategy

Party Forge uses shared archetype uniforms. Armour sets within a family share construction language and interchange cleanly. Class identity comes primarily from weapon family, weapon scale, stance, attack tempo, release motion, projectile/effect size, and class color.

### Heavy martial family

- Fighter remains the grounded sword-and-shield Forge Vanguard reference.
- Paladin uses the same heavy-family proportions with gold divine treatment, a preserved hammer-derived main hand, a sun shield, and a slower weighty smite.

### Ranged physical family

- Ranger and Marksman armour sets can be worn by both classes when weight requirements are satisfied.
- Ranger uses light and medium bows, a nimble stance, fast draw, fast recovery, and standard arrows.
- Marksman adds heavy bows and greatbows, a wide braced stance, slow full draw, visible strain, larger arrows, and forceful recoil.
- Rogue shares eligible light pieces, but its originating set uses a lower profile and paired daggers with rapid alternating strikes.

### Caster family

- Mage, Frost Mage, Cleric, and Warlock share robe, focus, and implement construction language.
- Mage uses expansive fire-casting gestures with wand and focus.
- Frost Mage uses a controlled two-handed staff channel and sharp frost-shard release.
- Cleric uses a direct lightning gesture for attacks and a separate open-handed blessing for healing.
- Warlock uses compressed inward channeling, a one-hand chaos release, and lingering recoil.

## Equipment Slot Contract

The equipment sheet exposes these eleven positions in stable order:

1. `helmet`
2. `body_armour`
3. `legs`
4. `gloves`
5. `boots`
6. `amulet`
7. `ring_left`
8. `ring_right`
9. `belt`
10. `main_hand`
11. `off_hand`

Ring items use item type `ring` and declare both ring positions as compatible slots. A ring is not permanently authored as left-only or right-only. Presentation may mirror a small ring visual when a readable combat model is later justified.

A two-handed item is stored in `main_hand` and reserves `off_hand`. It is never duplicated into two inventory records. Compatibility tags may override the reservation; bow and quiver is the initial explicit exception.

## Equipment Eligibility Contract

Eligibility is data-driven and combines:

- Required class/archetype capability tags.
- Equipment weight class.
- Weapon-family capability tags.
- Attribute requirements when the equipment system implements character attributes.
- Item-specific compatibility or override tags.

Eligibility must not branch on display names, scene node names, or hard-coded class IDs.

### Armour families

- Heavy martial pieces require the martial/vanguard family plus the authored heavy or medium weight capability.
- Ranger and Marksman sets require ranged-physical compatibility plus light or medium weight capability.
- Rogue pieces require light martial/skirmisher compatibility.
- Caster pieces require caster compatibility plus their authored light or medium weight capability.
- Cleric's reinforced vestments are medium caster/support equipment.
- Accessories—amulets, rings, and belts—remain universally equippable unless an individual future item explicitly declares another rule.

### Weapon families

- Fighter sword requires one-hand sword capability.
- Paladin hammer requires one-hand hammer capability.
- Shields require shield capability.
- Ranger recurve bow requires light/medium bow capability.
- Marksman greatbow requires greatbow/heavy-bow capability.
- Quivers require bow compatibility and explicitly coexist with their allowed two-handed bow family.
- Rogue daggers require dagger and dual-wield compatibility.
- Mage wand and focus require caster wand/focus capability.
- Frost staff requires caster staff capability and reserves the offhand.
- Cleric sceptre and tome require divine caster/sceptre/tome compatibility.
- Warlock bone wand and grimoire require occult caster/wand/grimoire compatibility.

Future passives, upgrades, or exceptional items may grant additional capability tags. Animation selection follows the equipped weapon family, so a class later granted greatbow capability uses the greatbow animation rather than its original light-bow action.

## Item Asset Contract

Each equipment item has two linked resources with stable IDs.

### Equipment base definition

The gameplay-facing item-base resource contains:

- Stable `id` and display name.
- Item type.
- Compatible sheet slots.
- Weight class.
- Required capability tags.
- Handedness and occupied/reserved slots.
- Offhand compatibility and override tags.
- Weapon family when applicable.
- A stable implicit-family hook for the later implicit-stat system.
- Reference to its presentation definition.

This milestone does not resolve or roll implicit values. The stable hook permits the equipment-system milestone to attach the approved implicit definitions without renaming visual assets or save identifiers.

### Equipment presentation definition

The presentation resource contains:

- The same stable item ID.
- The supported presentation slot or slots.
- Independent packed 3D scene reference for combat-visible equipment.
- Transparent master icon reference.
- Optimized runtime icon reference.
- Attachment socket ID.
- Body-preset support metadata.
- Item-owned primary, metal, leather, accent, and emissive palette values.
- Optional wearer-accent channel.
- Weapon animation family and launch socket when applicable.
- Readability channel metadata used by validation and the developer sandbox.

Missing gameplay stats do not make a presentation resource invalid. Missing IDs, scenes for required visible items, icons, sockets, body support, or slot compatibility do.

## Modular 3D Scene Architecture

The shared humanoid scene owns:

- Masculine and feminine bodies.
- Stable equipment sockets.
- Body preset switching.
- Wearer accent application.
- Animation player and action-event forwarding.
- Hit/flinch and downed presentation.

Equipment scenes own only their item geometry and materials. Equipping instantiates the selected item scene at its declared socket. Unequipping removes that instance. The humanoid model no longer depends on one class scene containing every possible item as hidden geometry.

The migration extracts the current Fighter sword, shield, hammer, armour, helmet, gauntlets, boots, belt, amulet, and ring visuals into the same item-scene format. Their geometry and default appearance remain unchanged. A matching Forge Vanguard legs item is added to complete the eleven-slot sheet.

## Combat-Visible and Icon-Only Items

Every item receives its own base resource, presentation resource, and icons.

Independent combat-visible scenes are required for:

- Helmet.
- Body armour.
- Legs.
- Gloves.
- Boots.
- Belt.
- Main hand.
- Offhand.
- Amulets whose pendant is large enough to survive combat camera distance.

Rings are resource/icon complete but do not require combat-scale geometry in this milestone. This preserves accurate item ownership without adding unreadable micro-geometry.

## Class Starter Item Manifests

The eight new class sets contribute 87 item bases. Seven sheets use eleven item instances. Frost Mage uses ten because its staff occupies main hand and reserves offhand. Fighter normalization produces eleven default sheet items plus the preserved alternative hammer, for 99 presentation-ready catalog entries after this milestone.

### Paladin — Dawn Bulwark

| Slot | Stable item ID | Display name |
|---|---|---|
| Helmet | `dawn_bulwark_crown` | Dawn Bulwark Crown |
| Body armour | `dawn_bulwark_plate` | Dawn Bulwark Plate |
| Legs | `dawn_bulwark_greaves` | Dawn Bulwark Greaves |
| Gloves | `dawn_bulwark_gauntlets` | Dawn Bulwark Gauntlets |
| Boots | `dawn_bulwark_sabatons` | Dawn Bulwark Sabatons |
| Amulet | `sun_oath_amulet` | Sun Oath Amulet |
| Ring | `ring_of_vigil` | Ring of Vigil |
| Ring | `ring_of_mercy` | Ring of Mercy |
| Belt | `dawn_bulwark_belt` | Dawn Bulwark Belt |
| Main hand | `sunforged_warhammer` | Sunforged Warhammer |
| Offhand | `dawn_bulwark_shield` | Dawn Bulwark Shield |

### Ranger — Greenwood Strider

| Slot | Stable item ID | Display name |
|---|---|---|
| Helmet | `greenwood_hood` | Greenwood Hood |
| Body armour | `greenwood_jerkin` | Greenwood Jerkin |
| Legs | `greenwood_leggings` | Greenwood Leggings |
| Gloves | `greenwood_gloves` | Greenwood Gloves |
| Boots | `greenwood_boots` | Greenwood Boots |
| Amulet | `trailmark_amulet` | Trailmark Amulet |
| Ring | `hawkeye_band` | Hawkeye Band |
| Ring | `windrunner_band` | Windrunner Band |
| Belt | `greenwood_belt` | Greenwood Belt |
| Main hand | `greenwood_recurve_bow` | Greenwood Recurve Bow |
| Offhand | `greenwood_light_quiver` | Greenwood Light Quiver |

### Marksman — Siege Archer

| Slot | Stable item ID | Display name |
|---|---|---|
| Helmet | `siege_archer_cowl` | Siege Archer Cowl |
| Body armour | `siege_archer_coat` | Siege Archer Coat |
| Legs | `siege_archer_braced_leggings` | Siege Archer Braced Leggings |
| Gloves | `siege_archer_draw_glove` | Siege Archer Draw Glove |
| Boots | `siege_archer_boots` | Siege Archer Boots |
| Amulet | `farshot_amulet` | Farshot Amulet |
| Ring | `steady_hand_ring` | Steady Hand Ring |
| Ring | `long_watch_ring` | Long Watch Ring |
| Belt | `siege_archer_draw_belt` | Siege Archer Draw Belt |
| Main hand | `siege_greatbow` | Siege Greatbow |
| Offhand | `siege_heavy_quiver` | Siege Heavy Quiver |

### Rogue — Nightstep

| Slot | Stable item ID | Display name |
|---|---|---|
| Helmet | `nightstep_hood` | Nightstep Hood |
| Body armour | `nightstep_leathers` | Nightstep Leathers |
| Legs | `nightstep_leggings` | Nightstep Leggings |
| Gloves | `nightstep_grip_gloves` | Nightstep Grip Gloves |
| Boots | `nightstep_soft_boots` | Nightstep Soft Boots |
| Amulet | `shadowchain_amulet` | Shadowchain Amulet |
| Ring | `silent_edge_ring` | Silent Edge Ring |
| Ring | `bloodstep_ring` | Bloodstep Ring |
| Belt | `nightstep_utility_belt` | Nightstep Utility Belt |
| Main hand | `nightstep_dagger_main` | Nightstep Dagger |
| Offhand | `nightstep_dagger_off` | Nightstep Companion Dagger |

### Mage — Emberweave

| Slot | Stable item ID | Display name |
|---|---|---|
| Helmet | `emberweave_circlet` | Emberweave Circlet |
| Body armour | `emberweave_robe` | Emberweave Robe |
| Legs | `emberweave_leggings` | Emberweave Leggings |
| Gloves | `emberweave_spell_gloves` | Emberweave Spell Gloves |
| Boots | `emberweave_shoes` | Emberweave Shoes |
| Amulet | `emberheart_amulet` | Emberheart Amulet |
| Ring | `cinder_ring` | Cinder Ring |
| Ring | `conflagration_ring` | Conflagration Ring |
| Belt | `emberweave_rune_sash` | Emberweave Rune Sash |
| Main hand | `emberweave_wand` | Emberweave Wand |
| Offhand | `emberweave_flame_focus` | Emberweave Flame Focus |

### Frost Mage — Rime Scholar

| Slot | Stable item ID | Display name |
|---|---|---|
| Helmet | `rime_scholar_circlet` | Rime Scholar Circlet |
| Body armour | `rime_scholar_robe` | Rime Scholar Robe |
| Legs | `rime_scholar_leggings` | Rime Scholar Leggings |
| Gloves | `rime_scholar_gloves` | Rime Scholar Gloves |
| Boots | `rime_scholar_boots` | Rime Scholar Boots |
| Amulet | `winterglass_amulet` | Winterglass Amulet |
| Ring | `hoarfrost_ring` | Hoarfrost Ring |
| Ring | `stillwater_ring` | Stillwater Ring |
| Belt | `rime_scholar_crystal_sash` | Rime Scholar Crystal Sash |
| Main hand and reserved offhand | `rime_scholar_staff` | Rime Scholar Staff |

### Cleric — Storm Chaplain

| Slot | Stable item ID | Display name |
|---|---|---|
| Helmet | `storm_chaplain_hood` | Storm Chaplain Hood |
| Body armour | `storm_chaplain_vestments` | Storm Chaplain Vestments |
| Legs | `storm_chaplain_leggings` | Storm Chaplain Leggings |
| Gloves | `storm_chaplain_prayer_gloves` | Storm Chaplain Prayer Gloves |
| Boots | `storm_chaplain_boots` | Storm Chaplain Boots |
| Amulet | `storm_chaplain_reliquary` | Storm Chaplain Reliquary |
| Ring | `storm_ring` | Storm Ring |
| Ring | `mercy_ring` | Mercy Ring |
| Belt | `storm_chaplain_belt` | Storm Chaplain Belt |
| Main hand | `storm_chaplain_sceptre` | Storm Chaplain Sceptre |
| Offhand | `storm_chaplain_holy_tome` | Storm Chaplain Holy Tome |

### Warlock — Grave Covenant

| Slot | Stable item ID | Display name |
|---|---|---|
| Helmet | `grave_covenant_hood` | Grave Covenant Hood |
| Body armour | `grave_covenant_robe` | Grave Covenant Robe |
| Legs | `grave_covenant_leggings` | Grave Covenant Leggings |
| Gloves | `grave_covenant_ritual_gloves` | Grave Covenant Ritual Gloves |
| Boots | `grave_covenant_wrapped_boots` | Grave Covenant Wrapped Boots |
| Amulet | `grave_covenant_bone_amulet` | Grave Covenant Bone Amulet |
| Ring | `withering_ring` | Withering Ring |
| Ring | `pact_ring` | Pact Ring |
| Belt | `grave_covenant_chained_sash` | Grave Covenant Chained Sash |
| Main hand | `grave_covenant_bone_wand` | Grave Covenant Bone Wand |
| Offhand | `grave_covenant_grimoire` | Grave Covenant Grimoire |

### Fighter — Forge Vanguard normalization

The existing stable Forge Vanguard IDs remain authoritative. Add `forge_vanguard_greaves` for the new legs slot. Preserve `forge_vanguard_sword` as the default main hand, `forge_vanguard_shield` as the default offhand, and `forge_vanguard_hammer` as a selectable alternative. Generate matching icons and independent packed scenes from the existing geometry rather than remodeling these items.

## Class Presentation Profiles

Each current class receives a `CharacterVisualProfile` that references the shared humanoid scene, default body preset, class accent, default item-base/presentation IDs, required action names, and attack-presentation mappings.

Default gameplay body preset remains masculine until a player-facing body selection system exists. Both presets must be fully functional through the presentation API and developer sandbox.

## Animation and Combat Synchronization

### Foundational sequence

1. `AttackController` selects a valid target and requests an attack sequence.
2. The actor locks the definition, target identity, timing, and one unique sequence token.
3. `CharacterPresentation` resolves the action from class stance, attack ID, and equipped weapon family.
4. The animation begins and exposes an explicit `release` or `impact` event.
5. `AttackExecutor` applies melee damage, spawns a projectile, applies healing, or creates the spell effect exactly once when that event fires.
6. Recovery completes before the actor may begin another sequence.
7. The presentation returns to idle.

`AttackDefinition.cooldown` remains the start-to-next-start cadence so this presentation milestone does not silently rebalance existing classes. Windup, release, and recovery fit inside that cadence; any remaining time is idle recovery. An action profile whose phases exceed the authored cooldown is invalid. Attack-speed modifiers scale the cadence, animation playback, release timing, and recovery together. They must never make gameplay execute before the visible release.

### Target and movement behavior

- The selected target is locked at sequence start.
- At release, the same target is revalidated for existence, team, availability, and applicable range rules.
- If it is invalid, the sequence cancels cleanly. It does not silently redirect to another target.
- Root movement may continue unless an attack explicitly declares movement lock.
- Ordinary visual hit/flinch does not interrupt a sequence.
- Future stun, freeze, knockdown, or explicit interruption may cancel through a dedicated sequence-cancellation contract.

### Failure behavior

- A missing required release/impact event cancels execution and emits a stable `PARTY_FORGE_ATTACK_SEQUENCE_ERROR` containing attack ID, action ID, sequence token, and reason.
- Duplicate release events execute only once and report the duplicate.
- A stale event from a previous action token is rejected.
- Downed or dead actors cannot release a pending attack.
- Pause halts both sequence time and animation time.

## Required Class Actions

Every class profile requires:

- A class-readable looping `idle`.
- One primary attack action selected by the equipped weapon family.
- `hit_flinch`.

Additional required actions are:

- Fighter: sword slash; preserved preview combo remains optional.
- Paladin: hammer smite.
- Ranger: quick light/medium bow shot.
- Marksman: slow greatbow/heavy-bow shot.
- Rogue: paired-dagger flurry.
- Mage: wand-and-focus fire burst.
- Frost Mage: two-handed staff frost shard.
- Cleric: sceptre lightning bolt and separate tome-assisted healing blessing.
- Warlock: bone-wand/grimoire chaos bolt.

Class idle poses carry posture and temperament while remaining compatible with all legal equipment in the class's families.

## Attack Presentation Definitions

Presentation-specific attack data stays separate from damage and targeting numbers. An attack presentation definition contains:

- Stable action ID.
- Required animation/event names.
- Weapon animation family.
- Launch socket.
- Projectile or effect packed scene.
- Projectile orientation and visual scale.
- Impact packed scene and color/material parameters.

Current attack definitions continue to own gameplay damage, cooldown, range, projectile speed, area radius, tags, and crit eligibility.

## Specialized Projectile and Effect Visuals

- Ranger receives a standard low-poly arrow launched from the bow socket.
- Marksman receives a visibly larger and heavier arrow with greatbow-scale launch treatment.
- Mage receives a fire projectile and area-burst treatment.
- Frost Mage receives a crystalline frost shard and cold area treatment.
- Cleric receives a lightning bolt visual and a separate healing blessing effect.
- Warlock receives a slower chaos bolt and occult impact treatment.
- Melee attacks use weapon impact timing without creating a projectile.

The existing generic projectile remains an emergency visual fallback when a specialized projectile scene fails to instantiate. The error is reported with attack and presentation IDs. The fallback does not bypass the synchronized release event.

## Icon Generation Pipeline

Icons are rendered from the authoritative 3D item scenes rather than independently illustrated interpretations. This guarantees that inventory and pickup art matches equipped geometry.

For every item:

- Render a transparent square master at 256 by 256 pixels.
- Produce an optimized 128 by 128 runtime icon.
- Use fixed per-item-type orientation presets so bows, staves, armour, and rings fill the frame consistently.
- Keep at least eight transparent pixels of safe padding at runtime size.
- Do not bake rarity color, class restriction, stat restriction, selection, comparison, or quantity UI into the icon.
- Save a contact sheet grouped by class set for visual review.

The icon renderer is deterministic and can regenerate outputs after a 3D scene changes. Validation checks dimensions, alpha presence, non-empty visible bounds, naming, and source-to-runtime pairing.

## Runtime Data Flow

### Class spawn

1. Class selection resolves `ClassDefinition`.
2. `PartyActor.configure()` passes the class visual profile to `CharacterPresentation`.
3. Presentation instantiates the shared humanoid body.
4. Default item presentation definitions instantiate at their sockets.
5. The fallback capsule hides only after body, API, equipment, and idle action validation succeed.

### Future equipment change

1. The equipment system validates the item base against the character's capability, weight, slot, handedness, attribute, and item-specific rules.
2. The character equipment sheet commits the item ID and slot reservation transaction.
3. Presentation receives the resulting equipped visual definition for the changed slot.
4. The old item scene is removed and the new scene is instantiated at its declared socket.
5. Weapon-family animation selection refreshes without rebuilding the actor.

This milestone implements the presentation consumer and validated item metadata; it does not implement the inventory transaction UI.

## Error Handling and Fallbacks

- Duplicate or empty item IDs fail catalog validation.
- Invalid or unsupported slots fail closed without removing currently valid equipment.
- Missing visible item scenes or required body preset support reject that item presentation.
- Missing icons reject item catalog completion but do not crash gameplay boot.
- Missing sockets reject equip and preserve the previous item.
- Invalid handedness, two-hand reservation, or offhand compatibility rejects the loadout.
- Missing class profile or invalid model API keeps the gameplay capsule fallback visible.
- A specialized projectile scene failure uses the generic projectile after the synchronized release and reports the failure.
- A missing release/impact event cancels the attack; it never deals invisible early damage.
- All errors use stable grep-friendly Party Forge error prefixes and include relevant IDs.

## Delivery Sequence

### Phase 1: Foundation and Fighter normalization

- Protect the live worktree and unrelated user/peer changes.
- Add the legs slot.
- Add item-base and presentation-definition contracts.
- Convert shared humanoid presentation to instantiate item scenes.
- Extract current Fighter geometry into independent scenes.
- Add Forge Vanguard greaves and all Fighter icons.
- Add deterministic icon rendering.
- Implement synchronized attack sequence tokens and release events.
- Re-prove Fighter attack damage, hit/flinch, downed/revive, fallback, collision, and palette behavior.

### Phase 2: Heavy and ranged families

- Add Paladin, Ranger, Marksman, and Rogue item manifests, scenes, icons, profiles, and actions.
- Add hammer-smite, quick-bow, greatbow, and dagger-flurry synchronization.
- Add standard and heavy arrow visuals.
- Prove ranged wearable overlap and weapon-family restrictions.

### Phase 3: Caster family

- Add Mage, Frost Mage, Cleric, and Warlock item manifests, scenes, icons, profiles, and actions.
- Add fire, frost, lightning, healing, and chaos presentation.
- Prove staff reservation, wand/focus, sceptre/tome, and wand/grimoire behavior.

### Phase 4: Full integration and visual QA

- Register all class profiles with their class definitions.
- Expand the presentation sandbox to show Fighter plus all eight new classes.
- Validate both body presets, class accents, equipment swapping, actions, and effects.
- Generate class contact sheets and icon contact sheets.
- Run full automated and gameplay smoke verification.

## Testing Strategy

Implementation follows test-first red-green-refactor cycles.

### Data and catalog tests

- Exact eleven-slot order including legs.
- Unique stable item IDs and valid linked presentation IDs.
- Exactly the approved class manifests and default loadouts.
- Ring compatibility with either ring slot.
- Frost staff main-hand ownership and offhand reservation.
- Bow/quiver tagged reservation exception.
- Ranger/Marksman armour overlap.
- Ranger rejection of greatbow/heavy-bow without the capability tag.
- Invalid weight, archetype, weapon, slot, and offhand combinations reject cleanly.
- All required icon and scene paths exist and instantiate.

### Model and presentation tests

- Both body presets remain available for every class profile.
- Every combat-visible item attaches to a valid socket and stays inside approved visual bounds.
- Equipping one item removes only the prior item in the affected slot.
- Item-owned colors survive cross-class equip while wearer accent remains instance-local.
- Fighter default appearance remains red sword-and-shield Forge Vanguard.
- Fighter hammer remains selectable but non-default.
- Invalid presentation leaves the fallback capsule visible.

### Attack-sequence tests

- No damage, projectile, or healing occurs before release.
- Exactly one execution occurs at release.
- Duplicate and stale release events do not execute twice.
- Invalidated targets cancel without retargeting.
- Downed/dead actors cannot release pending actions.
- Pause freezes animation and sequence time.
- Attack-speed modifiers scale action and release together.
- Real emitted actions still reach `AttackExecutor` and affect valid targets.

### Projectile/effect tests

- Ranger arrow uses standard visual scale.
- Marksman arrow uses larger heavy visual scale.
- Projectiles launch from the declared weapon socket rather than actor origin.
- Fire, frost, lightning, healing, and chaos effects select the correct presentation definitions.
- Specialized projectile instantiation failure uses the generic fallback only after release.

### Icon tests

- Every item has 256-pixel master and 128-pixel runtime icon outputs.
- Icons have transparent backgrounds and non-empty visible pixels.
- Crops respect safe padding.
- Master/runtime pairs correspond to the same item ID.
- Regeneration is deterministic.

### Integration and smoke tests

- Every playable class activates a valid non-fallback presentation in actual leader and companion scenes.
- Class attacks remain functional in live party combat.
- Cleric heal remains functional and synchronized.
- Gameplay collision and groups remain unchanged.
- Presentation sandbox covers nine classes, two body presets, all default equipment sheets, alternative Fighter hammer, class actions, and hit feedback.
- The complete Party Forge automated suite passes.
- The presentation smoke reports class, body, slot, item, icon, animation, and specialized-effect counts.

### Visual review

- Fighter and all new classes are reviewed side by side at the gameplay camera distance.
- Masculine and feminine lineups are reviewed separately.
- Front, three-quarter, side, and rear views catch clipping and attachment errors.
- Action playback confirms visible release matches gameplay release.
- Icon contact sheets catch crop, lighting, background, and scale inconsistencies.

## Acceptance Criteria

The milestone is complete when:

1. Every current playable class uses a valid shared-family humanoid presentation in actual gameplay.
2. Paladin, Ranger, Marksman, Rogue, Mage, Frost Mage, Cleric, and Warlock each have the approved complete starter sheet.
3. Fighter retains its established appearance, gains legs-slot support and icons, and keeps sword default plus hammer alternative.
4. The catalog contains all 87 new class items plus 12 normalized Fighter entries with stable IDs and icon coverage.
5. Every combat-visible item is an independent scene and can be equipped without rebuilding a class model.
6. Both body presets accept every legal default item sheet.
7. Ranger and Marksman can exchange eligible armour sets while Ranger cannot use heavy/great bows without an additional capability.
8. Two-handed and bow/quiver slot behavior matches the approved contract.
9. Inventory, equipment-sheet, tooltip, and pickup UI can use the same matching item icon assets.
10. Every class has readable idle, primary attack, and hit/flinch presentation; Cleric also has a healing action.
11. Combat execution occurs exactly once at the synchronized visible release/impact event.
12. Ranger and Marksman visibly differ through draw speed, stance, bow scale, arrow scale, and recoil.
13. Specialized class projectiles/effects select correctly and retain a safe generic projectile fallback.
14. Gameplay wrappers, collision, fallback visuals, health, targeting, and attack ownership remain intact.
15. Automated suites, presentation smoke, gameplay smoke, class/body visual review, and icon contact-sheet review all pass with recorded evidence.

## Later Blender Pipeline

The Godot-native item scenes are replaceable presentation assets. A later Blender pipeline may add smooth deformations, higher-quality rigging, and GLB exports while retaining:

- Stable item IDs.
- Equipment-base resources.
- Compatibility and restriction metadata.
- Sheet slot semantics.
- Presentation profiles.
- Icon naming and UI contracts.
- Attack action and release-event identifiers.
- Gameplay collision and actor wrappers.

Blender replacement assets must pass the same body-fit, socket, bounds, animation-event, icon, and gameplay smoke tests before promotion.
