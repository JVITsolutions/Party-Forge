# Party Forge Playtest Recovery and Ground Loot Design

Date: 2026-08-18
Status: Approved design, pending implementation plan
Branch: `feat/playtest-recovery-loot-ui`

## Objective

Correct the regressions observed in a live Party Forge playtest without weakening the existing ownership, input, tooltip, or profile-persistence contracts:

- P1/P2 ground-item ownership markers dominate the item and combat space.
- Ground-item pickup can fail without a usable interaction path or adequate explanation.
- Ground-item tooltips are effectively opaque and lack the item icon.
- Opening the Equipment page can expose its preview character in the arena and leave it there.
- A durable `resumable_run` blocks new runs, but the front end provides no recovery route.
- Profiles cannot be permanently deleted from Settings.
- A sandbox test can leave sentinel JSON files in the real profile directory when interrupted.

The implementation must preserve controller support, owner-only loot, existing ARPG tooltip controls, strict profile validation, and the rule that full mid-wave saving is a later milestone.

## Evidence and Root Causes

### Ground ownership marker

The live editor capture of `ground_item_chest.tscn` shows the fixed-size P1 pennant larger than the chest. The current scene uses a 72-point pennant label and 42-point owner label with large outlines and `fixed_size = true`, so the marker retains an excessive screen footprint regardless of camera distance.

### Pickup

The production input route is present and its existing unit/integration tests pass, but those tests click the exact projected anchor without an overlapping tooltip. The tooltip root currently captures mouse input, so an overlapping panel can intercept a click intended for the chest.

The active real profiles also contain interrupted run inventories with capacity zero. In Developer Mode a recovered context is supposed to receive the established five-slot minimum, but the missing recovery route prevents that context normalization from occurring.

### Tooltip

The outer tooltip and inner card both use near-opaque backgrounds. Their stacked opacity hides the arena. The shared item tooltip card is text-only even though item projections already expose icon data.

### Equipment preview

The Equipment page preview `SubViewport` does not own an independent `World3D`. Its preview actor can therefore share the arena world. Deactivating the page hides the UI but does not clear the preview actor.

### Interrupted runs

`resumable_run` currently persists strict item ownership, run identity, seed, player identity, and leader member ID. It does not persist timer, wave, enemies, upgrades, or the selected leader class. The main-menu view model ignores completed-profile resumable state and routes Play to new class selection. A second checkout is correctly rejected as an active resumable run.

The user's three current legacy recovery records have no selected class and zero-capacity inventories. This must be migrated safely rather than requiring new profiles.

### Profile deletion and stale test data

`ProfileManager` supports create, select, refresh, and bootstrap but has no delete operation. The Profiles settings page has no delete control or confirmation.

The developer-item-sandbox test writes sentinel files under `ProfileStore.DEFAULT_ROOT`. It normally removes them, but an interrupted process leaves invalid JSON in the real profile folder and produces the current profile-health warning.

## Approved Player Experience

### Ground marker

Use the approved **Compact Pennant** treatment:

- Keep the player-colored P1/P2 label and downward pointer.
- Reduce the combined screen footprint to roughly one-third of the current marker.
- Keep ownership readable at the 1080p, 1440p, and 4K targets.
- Do not replace the pennant with a ground ring or side badge.

### Ground tooltip

Use the approved **Full ARPG Card** treatment:

- Show the real item icon in the header.
- Retain name, rarity, item level, base stats, requirements, affixes, and keyword text.
- Retain Shift roll-range details, Alt comparison, pinning, mouse-wheel/scrollbar scrolling, Y/Triangle pinning, and right-stick scrolling.
- Use a translucent dark background near 85 percent opacity without stacking multiple near-opaque layers.
- Place the card beside the projected item rather than directly over it when space permits.
- Noninteractive card regions must not block chest pickup. Only explicit interactive controls such as pin and scroll surfaces capture pointer input.

### Pickup feedback

- Mouse users click the projected chest/item target.
- Controller users retain D-pad target cycling and the south-face pickup action.
- A valid Developer Mode recovery expands a legacy zero-capacity run inventory to the five-slot developer minimum without mutating the profile's persistent inventory-column unlock.
- Genuine capacity failure remains a visible `Inventory full` result.
- Distance failure remains a persistent `Move closer` result until state changes.
- Foreign-owner items remain visible but cannot be targeted or collected by the wrong player.

### Equipment preview

- The preview `SubViewport` owns an isolated `World3D`.
- Closing or deactivating the Equipment page clears its preview actor.
- Reopening the page reconstructs the selected member's preview.
- Preview rotation and equipment visual refresh remain available.
- No preview actor may appear in, persist in, or affect the arena world.

### Interrupted-run recovery

- Any valid active `resumable_run` overrides the normal Play route.
- The main action becomes **Resume Run** and opens a recovery confirmation surface.
- Resume restarts the arena from the beginning with the existing run identity and checked-out item state.
- Resume does not claim to restore unsaved timer, wave, enemy, upgrade, or ground-drop state.
- Future checkout documents persist `selected_leader_class_id`.
- A legacy recovery with no class opens **Choose Class to Recover Run** once. The choice binds to the existing checkout; it must not perform a second checkout.
- The chosen legacy class is persisted before context creation so a later retry is deterministic.
- **Abandon Run** requires confirmation and clearly states that run-owned items will be lost.
- Abandon uses the existing strict forfeit contract, clears the matching recovery, and never reconstructs run-only items in profile storage.

### Profile deletion

- Settings > Profiles adds **Delete Selected Profile**.
- Deletion is permanent and requires a confirmation that names the profile.
- The active profile can be deleted when no arena run is active.
- After active-profile deletion, the most recently used remaining profile becomes active.
- Deleting the last profile returns to the no-profile state and the existing create-profile flow.
- Healthy, recovered, and damaged profile entries can be selected for deletion.
- Damaged entries remain non-activatable, but the list permits selecting them for the separate delete action.
- Deletion is disabled while an arena run is active.
- A successful delete removes the exact profile's primary, backup, and known atomic/recovery artifacts and updates the profile index without touching neighboring profiles.
- Irreversible deletion prioritizes erasure. If index cleanup fails after verified file removal, the result records committed cleanup debt and rebuilds the in-memory index; the deleted profile must not reappear.

## Architecture

### Shared ground-loot presentation

Keep `GroundItemChest`, `GroundItemWorldController`, and the shared tooltip stack as the single production path.

1. Reduce the authored `Label3D` marker sizes/outlines and add an explicit visual-size contract test.
2. Add an icon surface to `ItemTooltipCard` driven by the existing item-detail icon projection.
3. Consolidate tooltip background opacity so the combined card remains translucent.
4. Set pointer filters deliberately: decorative regions ignore mouse input; pin and scrolling controls capture it.
5. Preserve tooltip positioning, comparison refresh, pin state, and pooled-chest reset behavior.

Do not create a second ground-only tooltip implementation. That would duplicate the comparison, affix, input, accessibility, and pinning contracts already shared by equipment and stash surfaces.

### Equipment preview isolation

Set `own_world_3d = true` on the preview viewport. Treat the page activation boundary as ownership:

- `activate`/refresh creates or reuses the correct preview snapshot.
- `deactivate` clears the preview actor and rendering state.
- scene-tree teardown also clears defensively.

### Recovery data and service boundary

Advance the current profile schema and resumable-run codec together.

- Add `selected_leader_class_id` to the strict recovery document.
- Migrate older strict recovery documents with an empty class marker while preserving every existing run/item byte semantically.
- New checkouts always write a valid class ID.
- A dedicated recovery service validates the active profile, strict bootstrap, selected class, item eligibility, and run rules before the main scene creates a context.
- Binding a class to a legacy recovery is an atomic profile mutation with deterministic replay behavior.
- Main routes resume through the recovery service and directly into context creation; it never calls checkout again.

The existing in-memory `_pending_checkout_recovery` remains the same-process retry mechanism for a checkout that just committed. Durable recovery after restart uses the new service rather than synthesizing that private in-memory state.

### Profile deletion service

Add a narrow deletion result/service boundary used by `ProfileManager`.

- Validate the exact selected status/profile ID before filesystem access.
- Healthy/recovered deletion uses the normal profile-ID validator. Damaged-artifact deletion is accepted only for an ID already discovered by this manager bootstrap, then revalidated as a confined basename under the exact profile root; callers cannot supply an arbitrary path-like ID.
- Enumerate only the primary and known same-profile artifact suffixes.
- Permanently remove those exact artifacts.
- Remove the profile/status from manager memory.
- Select the most recent remaining profile or empty the active ID.
- Persist the rebuilt index and expose committed cleanup debt distinctly from a pre-commit failure.
- Emit `profiles_changed`; emit `active_profile_changed` only when another active profile exists. The no-profile transition is represented by refreshed main-menu projection rather than a fake profile.

The UI owns confirmation and run-active gating. The service owns identity, filesystem confinement, irreversibility, and index consistency.

### Test-data isolation

Move developer-sandbox sentinel tests to unique `user://tests/...` roots. They must never write to `ProfileStore.DEFAULT_ROOT`.

The current machine cleanup is not a shipping migration. During implementation verification, remove only files whose names match the known test sentinel patterns and whose bytes exactly match the known sentinel payloads. Preserve every other file.

## Failure Handling

- Invalid or mismatched resumable data fails closed and opens a recovery error with Abandon available; it does not silently start a fresh run.
- A legacy class choice incompatible with checked-out equipment is rejected without changing the durable recovery.
- Context-creation failure preserves the durable recovery for retry.
- Abandon failure preserves the recovery and its run-owned items.
- Pickup failure never consumes or hides the chest.
- Preview teardown is idempotent.
- Delete preflight failure performs no deletion.
- A deletion that has already erased all exact profile artifacts is reported as committed even if index cleanup needs repair.

## TDD and Verification Strategy

Implementation follows strict RED-GREEN-REFACTOR phases.

### Ground loot and preview REDs

- Marker visual budget fails against the current 72/42-point scene.
- Tooltip card fails icon and aggregate-transparency assertions.
- A real viewport-dispatched click fails when the tooltip overlaps the chest anchor.
- Preview world-isolation and deactivate-cleanup tests fail against the current shared world.

### Recovery and deletion REDs

- Main-menu projection fails to expose Resume Run for an active strict recovery.
- Durable resume fails without a second checkout.
- Legacy recovery fails to request and persist a one-time class choice.
- Developer minimum-capacity recovery fails for a zero-slot saved run.
- ProfileManager fails active, last, damaged, neighbor-isolation, and injected-filesystem deletion cases.
- The sandbox isolation test fails if any sentinel path begins with `ProfileStore.DEFAULT_ROOT`.

### Green gates

- Focused unit suites for each changed service/component.
- Real input integration for mouse, controller, overlap, distance, full inventory, and foreign ownership.
- Main-menu/profile integration for future and legacy recovery, Abandon, and deletion.
- Equipment-ledger preview and responsive integrations at 1080p, 1440p, and 4K.
- Complete isolated Godot unit suite with an exact PASS summary and no parse, loader, RID, ObjectDB, or resource-leak markers.
- Separate boot smoke against a disposable profile root.

### Visual QA

Capture before/after screenshots showing:

1. Compact P1/P2 marker relative to the chest and nearby combat space.
2. Full ARPG tooltip with item icon and visible arena behind it.
3. Equipment page open and closed, proving no preview actor remains in the arena.
4. Resume/Abandon recovery surface and permanent profile-delete confirmation.

## Out of Scope

- True mid-wave save/resume of timer, wave, enemies, upgrades, health, positions, or ground drops.
- Automatic run saving from the pause menu.
- Trading, extraction voting, or shared loot.
- Replacing the approved P1/P2 pennant with another ownership language.
- Redesigning equipment/stash tooltip behavior beyond the shared icon, transparency, and pointer-safety corrections.
- Soft-delete, recycle bin, cloud backup, or profile restoration after confirmed deletion.

## Acceptance Criteria

The increment is complete when:

- Ownership markers no longer obscure their item or nearby combat.
- A player can collect an eligible owned ground item with real mouse/controller input while its tooltip is visible.
- Ground tooltips show the item icon, retain full ARPG information, and leave the arena visible.
- Equipment preview actors never enter or persist in the arena world.
- Existing interrupted profiles can recover after one legacy class choice instead of requiring replacement profiles.
- Future interrupted runs resume without class re-selection.
- Abandon clears only the matching strict recovery with the approved loss warning.
- Profiles can be permanently deleted with confirmation, including the active or final profile when no run is active.
- Tests cannot pollute the real profile root.
- All focused, integration, full-suite, boot, and visual QA gates pass with recorded evidence.
