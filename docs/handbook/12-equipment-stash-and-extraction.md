# 12. Equipment, Stash, and Extraction Continuity

> **Leader loadout architecture:** Tasks 1-11 through `3c753f41c24df7c7a3093e253f775109e21afb75`<br>
> **Creator artifact authority:** `86fa8c2ef41352f4508da8eb72c456f1741435d0`<br>
> **Godot version:** `4.7.1`<br>
> **Last checked:** `2026-08-05`

## What you will learn

By the end of this chapter, you will be able to:

- inspect a profile's leader equipment and stash through the game instead of editing save JSON;
- explain which records the Armoury and Warehouse share and which jobs belong to each screen;
- author and verify equipment eligibility tags;
- update the City extraction node in Latticewright and copy both authoritative artifacts safely;
- distinguish ordinary extraction from full leader-loadout extraction;
- diagnose stable loadout, extraction, and local-setup errors;
- use Developer Mode previews without granting Player Mode progression; and
- name the leader-only and local-multiplayer boundaries that remain deferred.

## Start with the ownership model

Chapter 11 introduced the rule that every issued item has exactly one record and exactly one serialized location. Leader continuity extends that rule across profile and run ownership; it does not add a second copy of equipped gear.

| Domain | Exact container | Kind | Owner | Purpose |
| --- | --- | --- | --- | --- |
| Profile | `leader-loadout` | `profile_leader_equipment` | `profile.profile_id` | Eleven sparse canonical leader equipment positions |
| Profile | `stash-tab-###` | `profile_stash_tab` | `profile.profile_id` | Persistent 100-slot tabs |
| Run | `run-equipment-%03d` | `run_member_equipment` | `context.run_player_id` | Eleven sparse equipment positions for one run member |
| Run | `run-inventory` | `run_inventory` | `context.run_player_id` | Run-owned inventory capacity materialized from the profile |

Starting a resumable item run checks the persistent leader loadout out of profile ownership and into the leader's run equipment container. A successful resolution moves retained records back into the profile; a failed or abandoned run does not leave a profile-owned duplicate behind. A save, replay, identity, or eligibility failure preserves the previous committed profile generation.

> **Party Forge convention:** The leader loadout and every stash tab are containers in the same profile item registry. Armoury and Warehouse project that same registry; neither screen owns a second stash or staging tray.

## Inspect loadout and stash without editing JSON

Do not open the profile JSON in a text editor to equip, move, inspect, or repair an item. Even a syntactically valid edit can break owner IDs, container capacity, slot identity, registry references, the transaction journal, or atomic recovery evidence.

Use the game instead:

1. Start Party Forge with the intended profile active.
2. In Player Mode, allocate the required permanent City unlocks. `equipment_inventory` exposes the Armoury and `stash` exposes the Warehouse.
3. Open **Armoury** to inspect the active leader class, all eleven leader equipment positions, every unlocked stash tab, and the selected item's icon, name, rarity, item level, and affixes.
4. Switch the Armoury stash tabs to compare the same persistent placements without moving them.
5. Open **Warehouse** for storage-wide inspection and organization.
6. If a route is intentionally not unlocked yet, use a saved Developer Mode session only for the labelled preview described later in this chapter.

The stable main-menu routes are `MainMenuViewModel.ROUTE_ARMOURY` (`armoury`) and `MainMenuViewModel.ROUTE_WAREHOUSE` (`warehouse`). Direct route calls recheck the active profile and the current saved mode; a stale menu projection is not authorization.

> **Checkpoint:** Select an occupied stash slot in Armoury, note its instance ID and serialized slot in the inspector/projection, then locate it in Warehouse. Both views must show the same item identity and placement.

## Armoury and Warehouse have separate jobs

**Armoury v1 is leader-only.** Its left side is the leader equipment sheet in canonical eleven-slot order. Its right side can browse every unlocked Warehouse stash tab directly. Equip, unequip, and occupied-slot swap intents go through `ProfileLoadoutAssignmentService`, which rechecks the selected class, the complete resulting loadout, exact source/destination slots, and the item records before one profile commit.

Armoury does not own storage, create a staging tray, compact slots, or silently change a nonempty loadout to another class. An empty loadout may select its target class. Changing the class of a nonempty loadout enters the compatibility/transition flow.

**Warehouse is storage-focused.** It provides tab navigation, search, stable sorting, rarity and item-type filters, category labels, bulk-selection intents, and exact-slot move requests. Search, sorting, filtering, and categories change only the displayed projection. They do not rewrite serialized placement. Warehouse has no character equipment sheet.

Both interfaces read the same profile item registry and the same ordered stash-tab containers. A move committed in one interface is followed by a profile reload and a fresh defensive projection before either view renders again.

> **Current limitation:** Armoury v1 has no follower-sheet selector. Starting followers, repeated `+1 starting follower` nodes, follower equipment sheets, and the global `followers_bring_gear` permission belong to a separate later Barracks-tree design. They are not silently supplied by this leader-loadout work.

## Author equipment eligibility tags

Eligibility joins an equipment definition to a class definition. The authoritative files are:

- equipment: `data/equipment/bases/<family>/<item>.tres`, using `EquipmentBaseDefinition`;
- class: `data/classes/<class_id>.tres`, using `ClassDefinition`;
- rules: `scripts/equipment/equipment_eligibility.gd`.

For an equipment item, review these fields deliberately:

- `compatible_slot_ids` names the exact equipment positions;
- `weight_class_id` automatically requires `armour_light`, `armour_medium`, or `armour_heavy` for worn armour;
- `required_all_tags` requires every listed class tag;
- `required_any_tags` requires at least one listed class tag;
- `excluded_tags` rejects a class carrying any listed tag;
- `attribute_requirements` applies numeric requirements when authoritative attributes are provided; and
- `reserved_slot_ids`, `compatible_offhand_item_types`, and `weapon_family_id` define two-hand/offhand and bow/quiver compatibility.

For the class, add genuine capabilities to `traits` or `capability_tags`. `ClassDefinition.normalized_eligibility_tags()` combines, deduplicates, and sorts both arrays. Do not add a tag merely to silence one test; confirm it describes the class. The Fighter, for example, declares `martial` and `vanguard` traits plus capabilities including `armour_heavy`, `one_hand_sword`, and `shield`.

After an eligibility change, run from the Party Forge root:

```powershell
$godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
$project = (Get-Location).Path
& $godot --headless --path $project --quit-after 180 --script res://tests/focused_test_runner.gd -- tests/unit/test_equipment_contract.gd tests/unit/test_equipment_assignment_service.gd tests/unit/test_profile_loadout_assignment_service.gd tests/unit/test_loadout_transition_service.gd
```

Accept only exit `0` with `TEST_SUMMARY: PASS (0 failures)` and no parse, script, or loader failure. Inspect both a compatible and an incompatible class in Armoury; a catalog-only pass does not prove the persistent assignment boundary.

## Edit the City node in Latticewright

Latticewright is authoritative for the editable City tree. Party Forge's runtime JSON is derived data, not the authoring source.

The Creator artifacts are:

- editable source: `samples/party-forge-city.pstree`;
- deterministic runtime export: `samples/party-forge-city.pstree.json`;
- Creator Godot demo copy: `integrations/godot/demo/party-forge-city.pstree.json`.

Party Forge consumes copies at:

- editable source copy: `data/passive_trees/city/party-forge-city.pstree`;
- runtime copy: `data/passive_trees/city/party-forge-city.pstree.json`.

Use this workflow:

1. Open the Creator project with **Open Project**; do not use **Import Runtime** for a `.pstree` source.
2. Select the `leader-loadout-extraction` node. Keep its permanent `feature_unlock` effect with `featureId: leader_loadout_extraction`, and keep the intended connection from `secured-loadout` unless the progression design explicitly changes.
3. Make the approved node, requirement, cost, position, or wording edit. Use **Validate** and resolve errors.
4. Choose **Save** to update `samples/party-forge-city.pstree`.
5. Choose **Export** and write the deterministic runtime to `samples/party-forge-city.pstree.json`.
6. Copy that runtime byte-for-byte to `integrations/godot/demo/party-forge-city.pstree.json`.
7. Copy the Creator source and runtime byte-for-byte to the two Party Forge paths above. Never update only Party Forge's runtime JSON.
8. Run the Creator City fixture test, then Party Forge's passive-tree artifact-sync, contract, loader, progression, and view-model suites.
9. Compare SHA-256 values and byte equality for all source/runtime pairs before committing.

The focused Creator command is:

```powershell
npx.cmd vitest run src/core/serialization/party-forge-city-fixture.test.ts
```

> **Checkpoint:** Creator source equals Party Forge source; Creator runtime equals both the Creator demo and Party Forge runtime; the City fixture and Party Forge artifact-sync suites pass.

## Ordinary extraction versus full leader extraction

`RunExtractionPolicy` applies one precedence rule on successful run resolution:

1. Before the permanent `leader_loadout_extraction` unlock, leader equipment, follower equipment, and run-inventory items are all ordinary extraction candidates. The player may retain no more than the profile's ordinary `extraction_capacity`; unselected candidates are lost.
2. After `leader_loadout_extraction`, every equipped leader item is retained automatically. These items consume zero ordinary extraction slots and are excluded from the ordinary selection list.
3. Follower equipment and run-inventory items remain ordinary candidates after the unlock. The unlock does not grant follower loadout persistence.
4. A request that selects an automatic leader item, exceeds capacity, duplicates an item, or names a stale source container/slot is rejected before profile mutation.

The pure policy and atomic resolution seams are implemented, but there is not yet a production end-of-run extraction picker described by this chapter. Verify the behavior through the focused suites:

```powershell
& $godot --headless --path $project --quit-after 180 --script res://tests/focused_test_runner.gd -- tests/unit/test_run_extraction_policy.gd tests/unit/test_run_resolution_service.gd
```

The suites cover ordinary capacity, automatic leader retention, follower/inventory precedence, exact placement, full-stash rejection, replay/collision handling, and save-failure byte preservation. Do not hand-edit a profile to grant the unlock or manufacture a result.

## Understand the class-change warnings

Selecting a compatible class proceeds to the guarded loadout checkout. Incompatible equipment opens an explicit state machine:

1. `INCOMPATIBLE` lists each exact item and eligibility reason. The available actions are **Go to Armoury**, **Choose Another Class**, **Continue Anyway**, and cancel.
2. If all incompatible items fit in the stash, **Continue Anyway** submits the non-destructive transition.
3. If the stash is too full, `DESTRUCTIVE_CONFIRMATION` lists the exact moved and destroyed items. A tap, ordinary accept, interrupted hold, focus loss, or hold shorter than `1.25` seconds cannot authorize destruction.
4. Only one uninterrupted 1.25-second hold on the dedicated destructive action emits the projection's exact confirmation token.
5. Cancel/back at either stage changes nothing. After a successful transition the profile is reloaded, compatibility is rechecked, and checkout starts from committed data.

Go to Armoury carries the pending run class for display only. Returning does not silently approve it; the player must select or confirm again.

## Diagnose stable error prefixes

Start with the first stable prefix rather than searching only for the final human-readable phrase:

| Prefix | Boundary to inspect |
| --- | --- |
| `PARTY_FORGE_EQUIPMENT_ERROR` | Slot, weight capability, required/any/excluded tags, attributes, reserved offhand, or quiver family |
| `PARTY_FORGE_PROFILE_LOADOUT_ASSIGNMENT_ERROR` | Persistent equip/unequip/swap request, exact item/slot fingerprints, class, or save |
| `PARTY_FORGE_LOADOUT_COMPATIBILITY_ERROR` | Projection of a nonempty loadout against the selected class |
| `PARTY_FORGE_LOADOUT_TRANSITION_ERROR` | Stash destinations, exact item records, confirmation token, transaction identity, or irreversible save |
| `PARTY_FORGE_RUN_LOADOUT_CHECKOUT_ERROR` | Profile/run identity, resumable-run authorization, class, or eligibility during checkout |
| `PARTY_FORGE_EXTRACTION_ERROR` | Ordinary/automatic selection precedence, capacity, or stale run location |
| `PARTY_FORGE_RUN_RESOLUTION_ERROR` | Successful-run identity, extraction projection, ownership transfer, or atomic profile mutation |
| `PARTY_FORGE_LOCAL_RUN_SETUP_ERROR` | Duplicate profile/device, stale decision, participant swap, unresolved participant, or locked coordinator |

The `field=` segment identifies the rejected boundary and `reason=` explains it. Preserve the complete diagnostic in a bug report. A nested prefix can be useful: for example, run resolution may wrap a `PARTY_FORGE_EXTRACTION_ERROR` under its extraction field.

## Player Mode, Developer Mode, and sandbox removal

Player Mode obeys the active profile's permanent feature unlocks. The Armoury is gated by `equipment_inventory`; Warehouse is gated by `stash`. Changing an in-memory projection or calling a route directly does not grant either feature.

Developer Mode may expose labelled Armoury and Warehouse previews for an active profile even when the corresponding permanent unlock is absent. That preview changes visibility/availability only. It must not append production unlocks, allocate City nodes, increase extraction capacity, or mutate Player Mode progression. Save Developer Mode first; routes reload the saved mode authoritatively.

The Chapter 11 Developer Item Sandbox remains a separate disposable owner and file root. `ItemTransactionRequest.SANDBOX_REMOVE` exists only so that sandbox fixture items can be removed from that isolated state. Production loadout destruction uses the exact compatibility projection, a separate confirmation token, and the guarded `LoadoutTransitionService`. **Sandbox removal is never a production destruction API**, and production scripts must not call or expose `SANDBOX_REMOVE`.

## Local multiplayer boundary

`LocalRunSetupCoordinator` coordinates join-before-run decisions in per-profile isolation. Each participant has one profile ID, device ID, player slot, selected class, and decision state. One player's Armoury inspection or transition addresses only that profile; another profile's bytes, item IDs, stash capacity, extraction capacity, and loadout cannot be shared or rewritten. The coordinator returns contexts only after every participant is ready, in stable player-slot order.

> **Current limitation:** Task 11 supplies the join-before-run backend coordination seam. It does not supply the full split-screen participant UI, multiple windows, split cameras, or Adventure drop-in behavior. Synthetic input runners do not prove physical-controller behavior; physical two-controller and four-controller acceptance remains a manual hardware gate.

## Verification checklist

After changing equipment, stash, extraction, warning, or local-setup behavior:

1. Run the focused suite that owns the changed boundary.
2. Run `armoury_warehouse_responsive_runner.gd` and `loadout_warning_input_runner.gd`; both exercise 1920x1080, 2560x1440, and 3840x2160 where applicable.
3. Treat their injected Godot events as synthetic controller/input evidence, not physical-controller certification.
4. Run a clean Godot import, the resource probe, and the complete unit suite.
5. Run the Creator fixture/unit/typecheck/lint gates if either City artifact changes.
6. Compare Creator-to-game source/runtime bytes and hashes.
7. Scan for production `SANDBOX_REMOVE` use and verification-created `.uid`/`.import` sidecars.
8. Perform and record the deferred physical/manual checks before making a hardware or human-visual acceptance claim.

> **Party Forge convention:** A passing backend suite proves its contract, not an unbuilt screen or unperformed hardware session. Keep synthetic, physical-controller, split-screen/camera, and human visual acceptance separate in every verification record.
