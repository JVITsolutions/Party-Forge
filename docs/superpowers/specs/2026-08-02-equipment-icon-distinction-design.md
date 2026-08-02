# Equipment Icon Distinction Design

**Date:** 2026-08-02
**Status:** Approved for implementation planning

## Goal

Correct the generated equipment icons so all 99 registered equipment items have the right slot silhouette and visibly distinct artwork while retaining the current clean, flat presentation style.

The correction covers the 99 transparent 256x256 master icons, their 99 transparent 128x128 runtime counterparts, and the nine class-set contact sheets. It does not change equipment gameplay data, eligibility, balance, presentation scenes, or 3D models.

## Current defect

The icon renderer currently infers an item's visual category from words in its ID. This fails for valid names that omit expected keywords. Examples include `greenwood_jerkin`, `siege_archer_cowl`, `emberweave_circlet`, `hawkeye_band`, and several sash or reliquary items.

All icon files exist, but this inference produces two problems:

1. Some items receive a silhouette for the wrong equipment slot.
2. Several different item IDs produce byte-identical artwork, making them indistinguishable in inventory interfaces.

## Source-of-truth rules

- The equipment base definition and registered sheet slot are authoritative for the icon's slot.
- Item IDs may select an intentional subtype or decorative variant, but must never determine the equipment slot.
- Weapon and offhand subtypes use existing authored equipment metadata where available. Explicit registered mappings are acceptable for exceptional alternatives such as the Fighter hammer.
- Every catalog item must resolve to exactly one master icon and one runtime icon.

## First equipment-system content set

These 99 models and their equipment base definitions are the first canonical content set for Party Forge's equipment, affix, and rarity systems. Each resource represents a stable base item: its identity, compatible slots, class/weight requirements, 3D presentation, and base icon remain independent from a particular dropped or owned item instance.

Future item instances may add rolled affixes, rarity, tier, quality, corruption, sockets, or other progression data without duplicating or rewriting the base resource. The base item ID is the durable link shared by drops, inventories, equipment sheets, saves, tooltips, and presentation.

The corrected icons therefore depict the base item itself. Rarity borders, rarity color treatments, affix badges, influenced/corrupted effects, and similar state are applied as UI or presentation layers at runtime. They are not baked into separate copies of the 99 source icons. This keeps one authoritative icon pair per base item while allowing the same model to represent many generated item instances.

## Visual system

The renderer keeps the established transparent, flat-icon style and class palettes. It defines a clear base silhouette for every supported visual family:

- helmet
- body armour
- leggings
- gloves
- boots
- amulet
- ring
- belt or sash
- melee weapon
- bow
- staff, wand, or sceptre
- focus, tome, shield, or quiver

The eleven equipment-sheet slots remain the data contract; the additional visual families distinguish weapon and offhand forms without changing slot behavior.

Each item also receives a deterministic identity treatment. This may change accent geometry, jewel shape, emblem, trim, orientation, or another clearly visible feature. The treatment must be derived reproducibly from authored identity, not runtime randomness. Paired rings, paired daggers, and similar equipment must remain recognizable as a family while still producing different artwork for their different item IDs.

Identity differences must be visible at 128x128. A hidden pixel, transparent metadata mark, or imperceptible color adjustment does not count as distinction.

## Generation flow

For every item in `ClassEquipmentRows.SET_ITEM_IDS`:

1. Resolve its registered slot and equipment definition.
2. Select the correct slot-driven base silhouette.
3. Select the authored weapon/offhand subtype when applicable.
4. Apply the class-set palette.
5. Apply the deterministic item-identity treatment.
6. Save the 256x256 transparent master.
7. Downsample it to the 128x128 transparent runtime icon.
8. Rebuild the class contact sheet after all items in that set succeed.

Generation remains fail-closed. Missing definitions, unsupported slots, invalid dimensions, empty alpha bounds, or save failures terminate the generator with an actionable item ID and reason.

## Regression coverage

Automated validation must prove:

- the catalog still contains exactly 99 unique equipment IDs;
- all 99 master icons and all 99 runtime icons exist at the expected paths;
- each icon has the expected dimensions, transparency, non-empty visible bounds, and safe padding;
- every icon's recorded visual family agrees with its declared slot and equipment subtype;
- no two different item IDs have byte-identical master artwork;
- no two different item IDs have byte-identical runtime artwork;
- master/runtime resource links remain valid;
- all nine contact sheets build successfully;
- regenerating the full set twice produces identical hashes;
- presentation smoke, locomotion smoke, and the complete project test suite remain green.

The duplicate-art test compares same-resolution outputs. A master icon and its own downsampled runtime counterpart are intentionally related and are not considered duplicates.

## Visual review

The nine regenerated contact sheets are reviewed at original resolution. Review checks:

- slot silhouettes read correctly without relying on labels;
- every item is distinguishable from the other items in its set;
- class palettes remain coherent;
- weapons and offhands retain recognizable archetypal forms;
- no icon is clipped, excessively small, off-center, or visually noisy;
- details remain readable at runtime size.

## Compatibility and scope boundaries

The existing file paths and item IDs remain stable, so downstream inventory, tooltip, equipment, save, and presentation systems do not require migration. Godot may regenerate local `.import` sidecars, but those are not part of the authored icon correction unless the repository already tracks them.

Out of scope:

- changing equipment statistics, rarities, affixes, or eligibility;
- replacing or remodeling the 3D equipment scenes;
- changing class palettes or presentation profiles;
- implementing the inventory/equipment user interface;
- implementing rarity rolls, affix generation, or item-instance persistence;
- producing painterly or photorealistic icons.

## Acceptance criteria

The work is accepted when all 99 items have correct and visibly distinct flat icons at both resolutions, all nine contact sheets pass visual review, deterministic regeneration passes, and the existing Godot validation gates complete without new errors or regressions.
