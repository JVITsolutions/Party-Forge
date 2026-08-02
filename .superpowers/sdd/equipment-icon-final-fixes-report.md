# Equipment Icon Final Review Fixes Report

Start: `8f609303ed5019433966c3582bce8904156648e6`

## Implemented contracts

- `EquipmentIconCpuRenderer.family_for` now rejects null definitions, invalid slots, and registered slots absent from the definition compatibility list. Non-handheld registered slots resolve from their slot family before legacy IDs are considered. The three Fighter ID overrides are restricted to compatible main/off-hand registrations, and unsupported handheld item types return an empty family.
- Added the pure callable `EquipmentIconValidationPolicy`. It validates the folder/manifest registries in both directions, rejects every global manifest duplicate occurrence, validates catalog null/empty/duplicate IDs, executes `CATALOG.validate()`, compares manifest and catalog IDs both ways, parses strict set arguments, validates committed image geometry, and owns the SHA-256 duplicate-pixel error contract.
- The standalone validator now uses the policy, keeps 256px and 128px duplicate detection independent, and requires all-set item, unique-master, unique-runtime, manifest, and catalog counts to agree before printing success.
- Both the standalone validator and the committed raw-PNG unit test enforce 16 transparent pixels around 256px masters and 8 transparent pixels around 128px runtime icons while retaining dimension, transparency, and non-empty-visible-bounds checks.
- The canonical set-to-folder mapping now lives beside `ClassEquipmentRows.SET_ITEM_IDS` and is consumed by the renderer, validator, contact-sheet builder, and raw-PNG asset test. No PNG path, ID, definition, scene, balance value, rarity boundary, or affix boundary changed.

## TDD evidence

Renderer RED, before the production edit:

```text
TEST_SUMMARY: FAIL (4 failures)
incompatible registered slot fails closed: expected empty, got bow
legacy override ID uses compatible non-handheld slot family: expected helmet, got sword
legacy override ID with incompatible handheld slot fails closed: expected empty, got shield
unknown handheld type fails closed: expected empty, got weapon
FOCUSED_RENDERER_RED_EXIT=1
```

Renderer GREEN after the minimal resolution change:

```text
TEST_SUMMARY: PASS (0 failures)
FOCUSED_RENDERER_GREEN_EXIT=0
```

Validation-policy RED, before creating the production helper:

```text
TEST_SUMMARY: FAIL (1 failures)
pure equipment icon validation policy exists: expected true
FOCUSED_POLICY_RED_EXIT=1
```

The behavioral policy and committed-asset GREEN run covered both registry drift directions, all invalid CLI examples, deterministic default/all/subset requests, duplicate/manifest-only/catalog-only IDs, catalog validation errors, null/empty/duplicate catalog definitions, and padded/edge-touching synthetic images:

```text
TEST_SUMMARY: PASS (0 failures)
FOCUSED_POLICY_ASSET_GREEN_EXIT=0
```

An initial runner attempt before the RED captures was not treated as test evidence: the isolated worktree did not yet have Godot's PNG import metadata, so it emitted resource-loader errors and did not complete normally. A bounded headless `--import` initialized the isolated worktree, after which the recorded RED/GREEN commands exited normally.

## Standalone CLI and catalog gate

The standalone matrix exercised six invalid forms plus default, subset, and all success:

```text
CASE=all_unknown EXIT=1
CASE=fighter_all EXIT=1
CASE=duplicate EXIT=1
CASE=empty_token EXIT=1
CASE=unknown EXIT=1
CASE=multiple EXIT=1
EQUIPMENT_ICON_VALIDATION_OK sets=1 items=12 unique_master=12 unique_runtime=12
EQUIPMENT_ICON_VALIDATION_OK sets=2 items=23 unique_master=23 unique_runtime=23
EQUIPMENT_ICON_VALIDATION_OK sets=9 items=99 unique_master=99 unique_runtime=99
STANDALONE_VALIDATOR_MATRIX_OK cases=9
```

The behavioral contract also caught that native `StringName` sorting is not lexical. Production sorting was corrected to compare string values, and the focused suite then passed with the exact deterministic nine-set order.

## Pixel preservation and integration evidence

All tracked equipment PNG SHA-256 values were captured before regeneration. All icons and contact sheets were regenerated, then all hashes and the Git PNG diff were compared:

```text
EQUIPMENT_ICON_RENDER_OK sets=9 items=99
EQUIPMENT_CONTACT_SHEET_BUILD_OK sets=9 items=99
EQUIPMENT_ICON_DETERMINISM_OK files=207
TRACKED_PNG_DIFF_OK files=0
```

No tracked PNG changed, so no pixel-difference diagnosis was required.

Fresh integration and complete-suite gates:

```text
PARTY_FORGE_PLAYABLE_PRESENTATION_SMOKE_OK classes=9 bodies=2 slots=11 items=99 icons=198 animations=21 projectiles=6 effects=5
PARTY_FORGE_LOCOMOTION_SMOKE_OK directions=4 walk=1 idle=1 attack_lock=1 equipment_independent=1
TEST_SUMMARY: PASS (92 suites)
FULL_SUITE_EXIT=0
SCRIPT_ERROR_COUNT=0
TEST_FAILURE_COUNT=0
```

## Scope and metadata boundary

The intended commit contains only the renderer and validator policy changes, the centralized equipment folder registry and its four consumers, three focused unit suites, and this report. It contains no PNG, equipment definition, presentation resource, scene, balance, user/editor state, historical report, or generated metadata change.

The required isolated Godot import created 290 untracked generated sidecars (`213 .import`, `77 .uid`). In accordance with the brief, none are staged or deleted. The task-specific redirected APPDATA is outside the repository and is not part of the commit.
