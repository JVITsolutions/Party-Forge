### Task 6: Generate production resources and enforce byte-identical parity

**Files:**
- Create: `tools/build_weighted_loot_content.gd`
- Modify: `data/items/affixes/fixtures/stout.tres`
- Modify: `data/items/affixes/fixtures/keen.tres`
- Modify: `data/items/affixes/fixtures/wise.tres`
- Modify: `data/items/affixes/fixtures/of_embers.tres`
- Modify: `data/items/affixes/fixtures/of_rime.tres`
- Modify: `data/items/affixes/fixtures/of_reach.tres`
- Modify: `data/items/affixes/fixtures/tempered_edge.tres`
- Generate: `data/items/affixes/production/focused/*.tres` (58 files; all focused IDs except the six retained explicit fixtures)
- Generate: `data/items/affixes/production/standard_hybrid/*.tres`
- Generate: `data/items/affixes/production/premium_hybrid/*.tres`
- Generate: `data/items/affixes/production/implicits/*.tres`
- Generate: `data/items/weapon_profiles/*.tres`
- Modify: `data/items/core_item_foundation_catalog.tres`
- Modify: `data/equipment/bases/**/*.tres`
- Modify: `scripts/items/item_foundation_catalog.gd`
- Modify: `scripts/items/item_affix_definition.gd`
- Modify: `scripts/items/item_generation_weight_policy.gd`
- Modify: `scripts/items/item_affix_assembler.gd`
- Modify: `scripts/equipment/equipment_base_definition.gd`
- Modify: `scripts/equipment/equipment_catalog.gd`
- Modify: `tests/unit/test_item_instance_codec.gd`
- Modify: `tests/unit/test_ranged_equipment_content.gd`
- Modify: `tests/unit/test_item_generation_service.gd`
- Modify: `tests/unit/test_item_generation_distribution.gd`
- Modify: `tests/unit/test_game_catalog.gd`
- Modify: `tests/unit/test_item_foundation_catalog.gd`
- Modify: `tests/unit/test_item_foundation_manifest.gd`
- Modify: `tests/unit/test_item_affix_assembler.gd`
- Test: `tests/unit/test_weighted_loot_builder_parity.gd`

**Interfaces:**
- Produces: `BuildWeightedLootContent.build_document_set(equipment, stats, damage_types) -> Dictionary` keyed by canonical `res://` path.
- Produces: exact production catalog registration and base assignment.
- Produces: `ItemGenerationWeightPolicy.affix_weight(affix, request, base_tags) -> float` with a `1.35` matching-affinity multiplier only when `accessory` is in `base_tags`.
- Consumes: Tasks 2, 4, and 5 typed rows.

- [ ] **Step 1: Write failing resource/count/parity tests**

Assert external resource paths, exact manifest counts, exact category/side counts, twelve tiers, one unique implicit per base, all 99 base references, profile links, rarity ceilings, known tags/families/affinities, reachability, and zero byte difference between generated canonical documents and checked-in resources. Add accessory selection tests showing a `1.35` matching-affinity multiplier, unchanged hard eligibility, and nonzero off-family weight.

- [ ] **Step 2: Run tests and verify RED**

```powershell
& $godot --headless --path . --quit-after 900 --script res://tests/focused_test_runner.gd -- tests/unit/test_weighted_loot_builder_parity.gd tests/unit/test_item_foundation_catalog.gd tests/unit/test_item_foundation_manifest.gd tests/unit/test_game_catalog.gd
```

Expected: non-zero exit because generated production resources are absent.

- [ ] **Step 3: Implement deterministic builder and strict validation**

Sort every row, tag, family, effect, tier, base assignment, resource path, and catalog reference by stable ID before saving. Build resources in memory first and run all cross-catalog validators before any write. A validation failure prints one stable `PARTY_FORGE_WEIGHTED_CONTENT_BUILD_ERROR stage=<stage> id=<id> reason=<reason>` and saves nothing; an I/O failure reports the exact path and leaves Git diff inspection as the recovery boundary.

```gdscript
static func build_document_set(
    equipment: EquipmentCatalog,
    stats: StatCatalog,
    damage_types: DamageTypeCatalog,
) -> Dictionary:
    var documents: Dictionary = {}
    for row: Dictionary in WeightedLootContentRows.explicit_rows():
        documents[_affix_path(row)] = _affix_from_row(row)
    for row: Dictionary in WeightedLootContentRows.implicit_rows(equipment):
        documents[_affix_path(row)] = _affix_from_row(row)
    for row: Dictionary in WeightedLootContentRows.weapon_profile_rows():
        documents[_weapon_profile_path(row)] = _weapon_profile_from_row(row)
    return _canonical_documents(documents)
```

`ItemFoundationCatalog.validate()` must enforce exact production totals and accept the six documented legacy-side exceptions without weakening other kind checks. Rarity ceilings are encoded through each tier's `allowed_rarity_ids`:

```gdscript
T1..T3  -> common, uncommon, rare, epic, legendary
T4..T5  -> uncommon, rare, epic, legendary
T6..T8  -> rare, epic, legendary
T9..T10 -> epic, legendary
T11..T12 -> legendary
```

Add `@export var affinity_tags: Array[StringName] = []` to `ItemAffixDefinition` with sorted, unique, known-tag validation. `ItemAffixAssembler` passes the selected base's normalized tags to the weight policy. The policy applies the `1.35` multiplier only when the base is an accessory and affinity intersects; combat equipment continues using authored hard required/excluded tags. A nonmatching accessory candidate retains its original positive weight.

- [ ] **Step 4: Run the builder twice and prove byte parity**

```powershell
& $godot --headless --path . --quit-after 900 --script res://tools/build_weighted_loot_content.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
git status --porcelain=v1 | Set-Content '.superpowers\sdd\weighted-loot-first-build.status'
& $godot --headless --path . --quit-after 900 --script res://tools/build_weighted_loot_content.gd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
git diff --check
```

Expected: both exits `0`; the second build changes zero tracked bytes relative to the first build.

- [ ] **Step 5: Run focused tests and verify GREEN**

Run Step 2. Expected: focused PASS marker and exit `0`.

- [ ] **Step 6: Commit generated production content deliberately**

Stage the builder, all named test files, four production affix directories, weapon profiles, item definition/weight/assembler changes, foundation catalog, both equipment validators, and only the 99 intentionally rewritten base resources. The approved regression-integration scope explicitly includes `scripts/equipment/equipment_base_definition.gd`, `tests/unit/test_game_catalog.gd`, `tests/unit/test_item_generation_service.gd`, `tests/unit/test_item_instance_codec.gd`, and `tests/unit/test_item_generation_distribution.gd`. Review `git diff --cached --name-status` before committing.

Review-fix staging is limited to this plan, `tools/build_weighted_loot_content.gd`, `tests/unit/test_weighted_loot_builder_parity.gd`, `tests/unit/test_ranged_equipment_content.gd`, and any generated base bytes changed by canonical set ordering.

```powershell
git diff --cached --check
git commit -m "feat: generate production weighted loot content"
```

---
