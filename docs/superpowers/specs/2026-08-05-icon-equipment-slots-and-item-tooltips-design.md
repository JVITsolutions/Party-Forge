# Icon Equipment Slots and Item Tooltips Design

## Purpose

Party Forge's equipment interfaces should present items as recognizable objects rather than numbered text records. The developer equipment sandbox currently places slot numbers and truncated item names inside generic buttons even though the item catalog already links equipment to authored icons. The current inspector also exposes debug-oriented text instead of the layered, readable equipment cards expected from an action RPG.

This design replaces those presentation gaps with one shared system inspired by Path of Exile's compact icon grids and Last Epoch's readable item inspection. It preserves Party Forge's existing item ownership, drag-and-drop, controller movement, and progression boundaries.

## Goals

- Use each item's real icon as the primary slot visual.
- Remove occupied-slot numbers and truncated names from item cells.
- Share one slot and tooltip presentation contract across the developer sandbox, Armoury, and Warehouse.
- Provide normal, comparison, and advanced-affix tooltip layers.
- Support mouse, keyboard, and controller inspection without changing item ownership.
- Compare multi-slot equipment against every valid equipped replacement candidate.
- Scale cleanly at 1920x1080, 2560x1440, and 3840x2160.
- Keep technical identifiers available in Developer Mode without exposing them in player-facing presentation.

## Non-Goals

This milestone does not:

- Implement weighted affix selection, new affix pools, crafting, or rerolling.
- Generate rare-item names where none currently exist.
- Change item equip eligibility, storage ownership, extraction, or destruction rules.
- Add new equipment art.
- Create follower equipment sheets.
- Expose hidden equipment systems to Player Mode before their progression unlocks.
- Invent roll ranges or requirements when catalog data is missing or invalid.

## Selected Direction

The selected hybrid direction combines:

- Path of Exile-style dense icon grids, rarity framing, and modifier inspection.
- Last Epoch-style readable card hierarchy and side-by-side comparison.
- Party Forge's existing temporary-popup, pinning, controller, and Developer Mode conventions.

The item grid remains visually compact. Detailed text belongs in an item card that appears on hover or controller focus.

## Shared Item Slot Component

`StorageSlotButton` becomes the shared equipment-slot presentation component used by the developer inventory, developer stash, Armoury, and Warehouse.

### Occupied Slot

An occupied slot displays:

- The item's `icon_path` texture, scaled while preserving aspect ratio.
- A rarity frame and restrained rarity glow.
- A distinct hover or controller-focus outline.
- State overlays only when they communicate an active interaction, such as held, selected, valid destination, or invalid destination.

The slot does not display:

- Its numerical storage index.
- The item name.
- Item level.
- Affix text.
- Internal identifiers.

The item icon must remain legible beneath state overlays. A held state may use an edge treatment, corner glyph, or mild tint, but it must not replace the icon with the word `HELD`.

### Empty Slot

An empty general-storage cell displays a neutral recessed background. An empty named equipment slot may additionally display a subtle equipment-type silhouette or short accessible label. Empty storage indices remain available to accessibility and automation metadata but are not rendered as primary text.

### Missing Icon

If an icon cannot be loaded, the slot renders a deliberate missing-item fallback with the rarity frame intact. Missing-icon handling must not fall back to the current slot-number and truncated-name layout.

### Rarity Communication

Rarity uses more than hue alone:

- Border color.
- Border shape or intensity.
- Restrained glow or accent treatment.
- The written rarity name in the tooltip.

This keeps rarity understandable when color perception or display conditions reduce color distinction.

## Item Tooltip Composition

Hovering or focusing an occupied slot opens a temporary item tooltip. The normal card is organized into stable visual bands.

### Header

The header contains:

- Item display name in the rarity color.
- Base item type or base display name.
- Written rarity name.

Until generated rare-item names exist, the base display name is the item display name. The tooltip must not fabricate a generated name from affix text.

### Classification and Requirements

The next band contains relevant structured facts:

- Compatible equipment slot or slots.
- Item level.
- Handedness when relevant.
- Attribute requirements.
- Class or tag restrictions when relevant.

When the active character cannot equip the item, the card displays a clear warning and the unmet requirement. Compatibility errors are presentation only; the tooltip cannot bypass or mutate the equipment rules.

### Core Values

The core-value band displays relevant base equipment values, such as damage, attack rate, armor, or another item-type-specific value. Empty or irrelevant categories are omitted instead of showing zero-filled boilerplate.

### Modifiers

Modifiers are separated by kind:

- Implicit modifiers.
- Explicit modifiers.
- Special modifiers when present.

Normal view shows each effect as a player-readable stat line, for example `+18% Fire Damage`. It does not show the affix identity, affix kind, tier, or roll range until advanced details are requested.

### Footer

The footer shows compact contextual input hints for compare, advanced details, pinning, and scrolling. Hints adapt to the current input device.

Developer Mode may expose a collapsed technical footer containing:

- Item instance ID.
- Base-definition ID.
- Container ID.
- Slot index.
- Other diagnostics that are genuinely available from the projection.

The technical footer is absent in Player Mode.

The developer sandbox's current plain-text inspector is no longer the primary item-detail surface. The shared item card replaces its duplicated player-facing details. Any diagnostics that remain useful move into the collapsed Developer Mode footer or a clearly separate diagnostics region, so the page does not present two competing item descriptions.

## Advanced Affix Layer

Holding Shift on keyboard or RT/R2 on controller expands every modifier with available affix metadata:

- Affix display name, such as `Of Flame`.
- Affix kind: implicit, prefix, suffix, or special.
- Tier.
- Current rolled value.
- Minimum and maximum roll for that tier.
- A subtle visual indication of the roll's position within its valid range.

An example advanced line is:

```text
+18% Fire Damage
Of Flame - Suffix - Tier 3 - Range: 15-20%
```

`ItemAffixDefinition.roll_bounds()` is authoritative for the tier range. If the definition, tier, or bounds are unavailable or invalid, the card omits the unavailable range rather than estimating or inventing it.

Affix-selection weights remain hidden from players. A later weighted-affix milestone may add weight diagnostics to the Developer Mode footer without changing the player card.

## Comparison Layer

Holding Alt on keyboard or LT/L2 on controller opens comparison cards beside the inspected item.

### Candidate Resolution

The comparison resolver uses compatible replacement slots, not item names or arbitrary class assumptions.

- An item with one valid occupied replacement slot compares against that equipped item.
- An item that can replace either of two occupied items compares against both simultaneously.
- Rings therefore show both equipped ring candidates.
- One-handed equipment shows both equipped candidates when both are valid replacements.
- Empty compatible slots do not create empty comparison cards.
- If no valid equipped candidate exists, the inspected card remains visible and comparison communicates that no item is equipped in a compatible slot.

Comparison is read-only and does not preselect, move, or equip an item.

### Presentation

The inspected item and equipped candidate cards share the same hierarchy. The layout distinguishes the inspected item from `Equipped` candidates without treating one equipped candidate as preferred.

Directly comparable numeric values may show green or red deltas. Arbitrary affix lines are not collapsed into a misleading aggregate upgrade score. Effects that do not have a reliable semantic match remain individually readable.

At narrow available widths, the group may compact its spacing and card widths while preserving all candidates. It must not silently discard the second ring or weapon comparison.

## Tooltip Lifecycle

The tooltip controller owns one inspected item and three independent state dimensions:

- Temporary versus pinned lifecycle.
- Comparison modifier active or inactive.
- Advanced-details modifier active or inactive.

### Temporary Tooltip

- Mouse hover or controller focus opens the normal card.
- Leaving the item closes the card after a short grace interval.
- The grace interval prevents flicker during ordinary pointer movement.
- Holding Alt keeps the mouse tooltip alive while the pointer moves from the slot to the card and also activates comparison.

### Pinning

- A pin icon appears at the tooltip's top-right corner.
- The mouse can reach and click it while Alt keeps the temporary tooltip active.
- When no card is pinned, Y/Triangle pins the controller-focused item.
- When a card is already pinned, Y/Triangle unpins that card regardless of where grid focus has moved.
- A pinned tooltip remains bound to the pinned item until explicitly unpinned.
- Hovering or focusing another slot does not replace the pinned card.
- Pinning preserves only the main inspected card, not the modifier layers.

### Modifier Layers While Pinned

- Alt/LT temporarily adds comparison to the pinned card.
- Shift/RT temporarily adds advanced affix details to the pinned card.
- Alt+Shift or LT+RT displays both layers together.
- Releasing a modifier removes its layer even while the main card remains pinned.

This prevents a pinned card from becoming permanently cluttered while retaining a stable reference item.

### Scrolling

- Mouse wheel scrolls the active card group when its content exceeds the viewport.
- A visible scrollbar can be dragged with the mouse.
- Right-stick up/down scrolls the active card group on controller.
- Scrolling does not move controller focus away from the originating item slot.

## Input Contract

| Intent | Keyboard and mouse | Controller |
| --- | --- | --- |
| Inspect | Hover or keyboard focus | Controller focus |
| Keep temporary card reachable | Hold Alt | Not required; focus persists |
| Compare | Hold Alt | Hold LT/L2 |
| Advanced affix details | Hold Shift | Hold RT/R2 |
| Compare plus advanced | Hold Alt+Shift | Hold LT/L2+RT/R2 |
| Pin or unpin | Click pin icon | Y/Triangle |
| Scroll card | Wheel or drag scrollbar | Right stick up/down |
| Pick up or move item | Existing mouse drag behavior | Existing left-face-button behavior |
| Place item | Existing mouse drop behavior | Existing south-face-button behavior |

The tooltip implementation must coexist with existing inventory movement. Inspect, compare, pin, and scroll inputs cannot consume the established pick-up/place actions when the tooltip does not own them.

## Shared Presentation Architecture

### Storage Slot View

`StorageSlotButton` owns cell rendering and emits semantic interaction signals. It receives an immutable presentation record rather than formatting item names itself. Armoury, Warehouse, and the developer sandbox configure context-specific empty-slot visuals but use the same occupied-item renderer.

### Item Presentation Projection

`ProfileStorageProjection` or a shared item-presentation projection supplies presentation-ready records containing:

- Item and base display names.
- Icon path.
- Rarity ID and display name.
- Item level.
- Compatible slots and handedness.
- Attribute and tag requirements.
- Equip compatibility results for the current character context.
- Relevant base values when those catalogs expose them.
- Modifier values, definitions, kinds, tiers, and validated roll bounds.
- Developer-only identifiers.

Screens do not independently reconstruct affixes or tooltip strings. One projection contract prevents the developer sandbox, Armoury, and Warehouse from drifting into different rules.

### Tooltip Controller and View

A shared controller resolves:

- Current inspected record.
- Pin state.
- Modifier input state.
- Comparison candidates.
- Screen-aware placement.
- Active scroll target.

A shared view renders one inspected card and zero, one, or two equipped cards from those records. The controller and view do not own item movement or persistence.

### Ownership Boundary

All equip, unequip, swap, drag, controller move, drop, destroy, and storage mutations continue through the existing ownership and transaction systems. Tooltip and slot presentation code may request actions through existing signals but cannot edit item state directly.

## Responsive Layout

Shared UI metrics control slot size, gap, frame thickness, card width, font scale, and card spacing.

### 1920x1080

- The inventory grid remains readable without item-name text consuming cells.
- One inspected card plus two equipped comparison cards fits by compacting cards and spacing when necessary.
- Card content scrolls internally rather than leaving the viewport.

### 2560x1440

- The layout gains breathing room without materially increasing information density.
- Side-by-side three-card comparison is the preferred arrangement.

### 3840x2160

- Metrics scale for physical readability rather than leaving controls at 1080p pixel size.
- Icons use their authored resolution without unbounded enlargement.

At every target, the placement solver chooses the side with the most usable space, flips inward at screen edges, and keeps the pin and scroll controls reachable.

## Accessibility and Fallbacks

- Rarity is conveyed with written text and frame treatment as well as color.
- Mouse, keyboard, and controller focus states are visually distinct.
- The tooltip uses readable contrast and consistent section separators.
- Missing icons, records, or metadata produce deliberate fallbacks without parser errors.
- Player-facing text uses stat display names when available rather than raw stat IDs.
- Developer identifiers remain selectable or inspectable only in Developer Mode.

## Migration Strategy

1. Enrich the shared item presentation projection without changing ownership serialization.
2. Add focused projection coverage for requirements, affix definitions, tiers, and roll bounds.
3. Upgrade `StorageSlotButton` to render icons and states while preserving drag-and-drop signals.
4. Add the shared tooltip controller and card view with normal inspection first.
5. Add pinning and scrolling using the existing temporary-popup conventions.
6. Add single- and dual-candidate comparison.
7. Add advanced affix details and combined modifier behavior.
8. Migrate the developer sandbox, Armoury, and Warehouse to the shared components.
9. Validate responsive presentation and input behavior at all three target resolutions.

Each migration step retains existing ownership and movement tests. The old text-in-cell rendering is removed only after the replacement passes focused checks on every consuming screen.

## Validation Plan

### Projection Tests

- Icon, rarity, name, item level, requirements, and compatibility fields project correctly.
- Affix kind, tier, rolled value, and valid bounds project correctly.
- Missing definitions and invalid bounds omit unavailable advanced data safely.
- Player Mode omits technical identifiers while Developer Mode may expose them.

### Slot Tests

- Occupied cells show icons without rendered slot numbers or item names.
- Empty and missing-icon cells use their intended fallback.
- Rarity, focus, held, valid-target, and invalid-target states remain distinguishable.
- Existing mouse drag/drop and controller pick-up/place signals remain unchanged.

### Tooltip Tests

- Hover/focus opens normal content.
- Alt/LT opens comparison.
- Shift/RT opens advanced affix data.
- Both modifiers combine correctly.
- Pinning locks only the main card.
- Releasing modifiers collapses their layers while a pinned card remains.
- Hovering another item does not replace a pinned card.
- Mouse wheel, scrollbar, and right-stick scrolling reach overflow content.

### Comparison Tests

- Single-slot equipment resolves one occupied candidate.
- Rings resolve both valid equipped ring candidates.
- Multi-slot one-handed equipment resolves both valid equipped candidates.
- Empty compatible slots do not create blank cards.
- Numeric deltas are shown only for genuinely comparable values.

### Responsive and Integration Tests

- Developer sandbox, Armoury, and Warehouse use the shared slot and tooltip system.
- Rendered checks cover 1920x1080, 2560x1440, and 3840x2160.
- Cards remain on-screen and usable with zero, one, or two comparison candidates.
- Player Mode and Developer Mode reveal only their permitted information.
- Full import, focused storage/UI tests, integration runners, and the complete suite pass after migration.

## Acceptance Criteria

The milestone is accepted when:

- Occupied equipment and stash cells use real item icons rather than slot numbers and truncated names.
- The developer sandbox, Armoury, and Warehouse share the same occupied-slot presentation.
- Normal tooltips are readable and player-facing.
- Alt/LT compares against every valid equipped replacement candidate, including both rings.
- Shift/RT displays real affix names, kinds, tiers, values, and roll ranges.
- Pinning, modifier release, and scrolling follow the approved lifecycle.
- Existing mouse and controller item-movement behavior still works.
- The UI remains usable at 1080p, 1440p, and 4K.
- No tooltip or slot component mutates item ownership directly.
- Focused and complete automated verification pass with recorded evidence.
