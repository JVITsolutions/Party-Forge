# Task 3 report: deterministic Fighter modular assets

Status: COMPLETE. Final staged diff check, focused commit, and clean-worktree verification are recorded with this delivery.

## Scope and generated output

- Worktree: `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\playable-class-presentations`
- Branch/start: `feat/playable-class-presentations` at `90519ce9e5944cad49e28a1682acea82a771f6f4`.
- Added canonical eleven-slot order: helmet, body armour, legs, gloves, boots, amulet, left ring, right ring, belt, main hand, off hand.
- Generated `ForgeHumanoidModel`, twelve independent Fighter equipment scenes, twelve base definitions, twelve visual definitions, and 24 transparent icon files (12 master 256x256 plus 12 runtime 128x128).
- The Fighter profile equips red sword plus shield by default; hammer remains available but absent from defaults. Both reusable base bodies are generated from the nude shared model.

## RED and builder investigation

The required first focused run of `test_fighter_modular_assets.gd` plus `test_equipment_icons.gd` was RED as expected: `TEST_SUMMARY: FAIL (52 failures)`, exit `1`, for the old ten-slot layout and missing shared scene/assets/icons.

`build_shared_humanoid_scene.gd` initially hung because `StringName` dictionary values were implicitly coerced into a typed `NodePath`. The failed path-splitting hypothesis was discarded. Storing values as `String` and explicitly calling `NodePath(String(...))` resolved it: `FORGE_HUMANOID_BUILD_OK`.

`build_equipment_assets.gd` then exposed a CLI `PackedStringArray` conversion error and missing ring socket map entries. The parser now creates a typed StringName array and both ring sockets map to their correct hand paths. Fresh generation completed with `EQUIPMENT_ASSET_BUILD_OK sets=1 items=12`.

## Icon render, validation, and determinism

The mandated headless SubViewport path was diagnosed, not bypassed silently: in Godot's dummy renderer, a bounded 180-frame condition observed no `frame_pre_draw` or `frame_post_draw`, and all texture reads reported null textures. The true scene renderer therefore runs in a short, direct hardware-backed Godot console session with `--display-driver windows --audio-driver Dummy --rendering-method gl_compatibility`; it reported the RTX 4070 Ti SUPER OpenGL compatibility driver and exits automatically.

The renderer uses transparent SubViewport output, a three-light rig, `UPDATE_ONCE`, `await RenderingServer.frame_post_draw`, computed square orthographic framing, and Lanczos runtime resize. The initial amulet transparency failure was traced to source-extracted attachment visibility. Attachment roots are now authored visible in the source; the renderer captures that authored state and does not force Node3D visibility.

The first strict raw-PNG validation caught sword runtime padding. Computed camera framing corrected it. Current alpha bounds are emitted by every hardware rerender rather than duplicated in this report; strict validation confirms every runtime icon has the required eight-pixel transparent padding.

Immediate rerender SHA-256 comparison reported `EQUIPMENT_ICON_DETERMINISM_OK files=24`; no pixel changed. Latest strict result: `EQUIPMENT_ICON_VALIDATION_OK items=12`.

## Runtime modularity and animation evidence

The test suite fail-closes on baked equipment: it instantiates the shared humanoid and both nude bases and requires zero `equipment_slot`/`equipment_visual_id` metadata and no node names containing sword, shield, hammer, or weapon. It then proves sword and shield are attached only to their exact hand sockets after applying the independent visual scenes, remain independent from all upper-arm/forearm meshes and mesh resources, survive masculine/feminine body swaps, and clear independently without removing arms or the opposite hand item.

Applying the Fighter profile is also required to start a looping `idle`; all four shoulder/elbow guard tracks must be non-neutral at time zero, preventing an A-pose baseline regression.

Shared animation inventory is exactly `idle`, `attack_slash`, `attack_combo`, and `hit_flinch`. `walk` is absent. No locomotion state machine, movement-facing integration, or gameplay visual claim was added in Task 3; those remain the dedicated follow-up task.

## Verification

- Focused modular/icon regression: `TEST_SUMMARY: PASS (0 failures)`.
- Expanded Fighter/presentation regression (including sandbox and party actor palette isolation): `TEST_SUMMARY: PASS (0 failures)`.
- Hermetic full suite using worktree-local APPDATA: `TEST_SUMMARY: PASS (76 suites)`, exit `0`.
- `git diff --check` was clean before final sidecar cleanup.

The full run emits intentional negative-case diagnostics from existing ledger, presentation, damage, and upgrade tests; it nevertheless exits zero with the PASS summary.

## Review follow-up

Review RED/GREEN: runtime visibility/socket coverage was added. After rebuild/import, hammer and amulet now install authored-visible attachment roots; all combat-visible Fighter scenes pass the focused suite. Single-root items use their declared visual socket, while paired gloves/boots/greaves retain animated limb-socket attachments. `has_equipment_slot` now verifies the socket node exists. The body-only compatibility source emits `FORGE_VANGUARD_BODY_SOURCE_BUILD_OK`; shared and base builders pass, focused assets/icons pass, and the fresh full suite exits zero with `TEST_SUMMARY: PASS (76 suites)`.

The review also found and corrected a generator self-dependency: `build_equipment_assets.gd` no longer reads `scenes/equipment/forge_vanguard/*.tscn` outputs. It now reads the committed, distinct `forge_vanguard_equipment_source.tscn`, generated once by `build_forge_vanguard_equipment_source.gd`; the focused regression asserts that source contract. A complete two-pass body/shared/equipment/base build produced identical SHA-256s for all 43 generated resource files: `GENERATION_DETERMINISM_OK files=43`. Current hardware icon generation and strict validation reported `EQUIPMENT_ICON_RENDER_OK sets=1 items=12`, `EQUIPMENT_ICON_VALIDATION_OK sets=1 items=12`, and a two-pass hash comparison reported `ICON_DETERMINISM_OK files=24`. The fresh final full suite again exited zero with `TEST_SUMMARY: PASS (76 suites)`.

### Final re-review follow-up

The equipment-source cycle was removed completely. `build_forge_vanguard_equipment_source.gd` now constructs all twelve low-poly Fighter items directly from canonical Fighter IDs and `ClassEquipmentRows.slot_for`; it contains no generated-item-scene load. The serialized `forge_vanguard_equipment_source.tscn` is fully flattened: a fail-closed test rejects any `res://scenes/equipment/forge_vanguard/` reference and requires every canonical ID to instantiate with geometry. A safe clean-regeneration check moved only the resolved generated target directory to a worktree-local backup, rebuilt from the standalone source, compared generated hashes, restored the original directory, and compared restored hashes: `CLEAN_REGENERATION_OK scenes=12`.

The builder marker now uses the requested-set and canonical-ID counts rather than literal values, and its former drift-prone parallel slot array is replaced with `ClassEquipmentRows.slot_for`. Final two-pass source/body/shared/equipment/base generation reported `GENERATION_DETERMINISM_OK files=44`; updated hardware icons reported `EQUIPMENT_ICON_RENDER_OK sets=1 items=12`, strict validation reported `EQUIPMENT_ICON_VALIDATION_OK sets=1 items=12`, and icon rerender hashes reported `ICON_DETERMINISM_OK files=24`.

The final full run initially exposed that stripping baked equipment had also stripped the body-owned primary palette surface expected by existing hit-feedback contracts. The body source now retains a `primary` Tabard mesh, while all equipment remains external and modular. After regeneration, the final focused suite reported `TEST_SUMMARY: PASS (0 failures)` and the fresh complete suite exited zero with `TEST_SUMMARY: PASS (76 suites)`.

### Geometry-preservation follow-up

The standalone constructors now reproduce the approved `90519ce` Fighter geometry/material contract exactly for helmet, armour and plates, sword (including the four-sided tip), shield, hammer, gauntlets, boots, belt, amulet, and rings. Greaves remain the explicit Task 3 paired-leg addition. The only intentional departure is source visibility for hammer, amulet, and rings: formerly hidden embedded alternatives are visible when extracted so modular runtime attachment and isolated icon capture cannot produce invisible geometry. A regression signature now fail-closes on every canonical item’s attachment count, socket tag, node name, transform, mesh type/dimensions, palette region, material color/metallic/roughness/emission, armour plates, and sword component/cylinder values.

This test first failed with 39 precise geometry-signature failures against the remodeled constructors, then passed after restoration. The standalone scan and safe isolated target rebuild/restore again reported `STANDALONE_SOURCE_SCAN_OK` and `CLEAN_REGENERATION_OK scenes=12`. Final evidence: `GENERATION_DETERMINISM_OK files=41`, `EQUIPMENT_ICON_RENDER_OK sets=1 items=12`, `EQUIPMENT_ICON_VALIDATION_OK sets=1 items=12`, `ICON_DETERMINISM_OK files=24`, focused `TEST_SUMMARY: PASS (0 failures)`, and fresh complete-suite `TEST_SUMMARY: PASS (76 suites)`.

---

# Plan 4B Task 3 report: canonical registry and fixed-slot ownership state

Status: implementation and local verification complete on `feat/plan-4b-item-ownership`; independent parent review remains the next sequential gate.

## Scope and contracts

- Worktree: `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\plan-4b-item-ownership`.
- Base: `e408532` (`docs: define item ownership snapshot schema`).
- Added schema-one `ItemRegistry`, `ItemSlotContainer`, `ItemOwnershipState`, and `ItemOwnershipStateDecodeResult`, plus the focused ownership suite and generated UIDs for the four production scripts.
- Registry items and containers serialize in ascending IDs; sparse slots serialize in ascending numeric order with canonical unsigned decimal string keys.
- Inventory capacities are restricted to `0..40`; stash capacities require exactly `100`.
- Strict decode rejects exact-field violations, duplicate item/container IDs, duplicate references, missing records, orphans, invalid capacities/slots/kinds, and owner mismatch without exposing partial state.
- All registry, item, container, list, and serialized-document accessors return defensive copies; no mutable dictionary reference is exposed.

## RED evidence

Command:

```powershell
& $godot --headless --path $project --quit-after 120 --script res://tests/focused_test_runner.gd -- tests/unit/test_item_ownership_state.gd
```

The pre-implementation run failed for the intended missing-feature reason with `Could not find type "ItemOwnershipState"`, `Identifier "ItemRegistry" not declared`, and `Identifier "ItemSlotContainer" not declared`. Because the focused runner crashed while loading the missing suite, Godot returned process exit `0` without a `TEST_SUMMARY`; that exit code was rejected as pass evidence, and the exact parse diagnostics were retained as RED evidence.

## GREEN and regression evidence

A complete import registered the four new global classes and exited `0`. The first executable GREEN run exposed invalid direct `Variant`-to-`String` casts in the new strict decoder. The engine printed runtime stack traces even though the focused runner had already printed a misleading PASS marker. Replacing those casts with explicit conversions fixed the implementation; no test was weakened.

Final focused commands and results:

```powershell
& $godot --headless --path $project --quit-after 120 --script res://tests/focused_test_runner.gd -- tests/unit/test_item_ownership_state.gd
& $godot --headless --path $project --quit-after 120 --script res://tests/focused_test_runner.gd -- tests/unit/test_item_ownership_state.gd tests/unit/test_item_instance_codec.gd tests/unit/test_profile_state.gd tests/unit/test_equipment_contract.gd
```

Both commands exited `0` with `TEST_SUMMARY: PASS (0 failures)` and no script, parse, loader, or test-failure diagnostics.

Full suite command:

```powershell
& $godot --headless --path $project --quit-after 300 --script res://tests/test_runner.gd
```

Result: exit `0`; `TEST_SUMMARY: PASS (123 suites)`; zero `TEST_FAILURE`, `SCRIPT ERROR`, `Parse Error`, `Failed to load`, or `No loader found` markers. The existing intentional negative-path errors and shutdown diagnostics (`18 ObjectDB` instances and five resources still in use) remained baseline noise.

## Hygiene and concerns

- The complete import generated UIDs for the new scripts/test and also recreated two unrelated missing test UIDs. All verification-created test sidecars were removed; only the four production-script UIDs remain scoped artifacts.
- `git diff --check` was clean before the final verification pass.
- The focused runner can print its PASS summary before later runtime errors reach the console, so every accepted focused result was checked for engine error markers rather than trusting the summary alone.
- No open Task 3 production concern is known. Task 4 mutation APIs were not implemented.

## Independent Task 3 review corrections

The sequential independent review identified two Important and two Minor issues. All four were addressed without starting Task 4:

- `ItemSlotContainer.create()` now rejects every non-`String` slot value before storage instead of coercing it. Constructor regressions include a `StringName` whose text exactly matches a valid registry ID and a second unknown `StringName`.
- Defensive-copy coverage now mutates `item()`, `ids()`, `occupied_slots()`, and `to_dictionary()` results from detached registry/container copies, then re-reads those same detached objects as well as the original state.
- Strict-schema coverage now includes missing fields on the ownership state, nested registry, and nested container.
- Registry-to-container diagnostic adaptation replaces only the leading prefix. Unusual field names containing `PARTY_FORGE_ITEM_REGISTRY_ERROR` retain their exact field/reason content.

Accepted review RED used the focused ownership command and exited `1` with exactly four assertions: two constructor coercion failures and two diagnostic-content corruption failures. It emitted no script, parse, or loader errors. The detached-copy and missing-field additions were already green, proving those changes strengthened coverage rather than masking a production defect.

After the minimal production changes, the same focused ownership command exited `0` with `TEST_SUMMARY: PASS (0 failures)`. The combined ownership, item codec, profile codec, and equipment contract batch also exited `0` with `PASS (0 failures)`. A complete import exited `0` with zero script/parse/loader failures, and the complete suite exited `0` with `TEST_SUMMARY: PASS (123 suites)` and zero `TEST_FAILURE`, script, parse, or loader markers.

The import recreated three untracked test `.uid` files; all three verification-generated test sidecars were removed. Only the four tracked production-script UIDs remain.
