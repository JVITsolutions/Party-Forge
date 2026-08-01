# Task 6 Report: Reusable Base Bodies and Presentation Review Sandbox

## Status

Completed for the modular-fighter-presentation worktree. The bounded commit adds two separately openable unequipped base-body packages, a deterministic base-scene builder, and the non-production review sandbox. `PartyActor` and Fighter class integration were not modified.

## RED

The test-first run added `test_forge_base_bodies.gd` and `test_character_presentation_sandbox.gd` before their assets existed:

```powershell
& $godot --headless --path $worktree --script res://tests/test_runner.gd --quit-after 120
```

Result: `TEST_SUMMARY: FAIL (7 failures)`: the two approved Rogue range baselines plus five expected Task 6 failures. The new failures were the absent sandbox scene and absent masculine/feminine base scenes and profiles.

## Delivered contract

- `scenes/characters/presentation/forge_base_masculine.tscn` and `forge_base_feminine.tscn` are direct Godot scenes generated from the Forge Vanguard model. Each retains the exact shared `HitPivot` hierarchy, all four animation clips, public body/palette/equipment/action methods, actor scale, and covered primitive mannequin geometry; every equipment root is hidden by default.
- `data/presentation/profiles/forge_base_masculine.tres` and `forge_base_feminine.tres` select their named preset, validate with empty `default_equipment_visuals`, and expose all ten existing Forge Vanguard visuals for later Ranger/Mage/Gunslinger layering.
- `ForgeVanguardModel.clear_equipment_visual(slot_id)` and `CharacterPresentation.clear_equipment_visual(slot_id)` provide the narrow public off path used by the sandbox. Re-enabling resolves the profile's real visual definition through the existing adapter.
- `CharacterPresentationSandbox` provides `set_body`, `set_palette`, `toggle_slot`, `play_clip`, `trigger_hit`, `set_downed`, and `set_base_profile`. It hosts independently-instanced masculine/red and feminine/blue models, a base/equipped profile switch on either side, a high-angle camera, directional light, neutral floor, and capsule comparison. Its key handling uses raw key events only; no input-map or production run state changed.

## Deterministic base output

The base builder was run twice consecutively. Both generated outputs had matching SHA-256 hashes across the two runs:

- `forge_base_masculine.tscn`: `3959F52ACBD60E0A0B52EB5EE50933536018D2C21D0021AC8D0CC0CE58995DC6`
- `forge_base_feminine.tscn`: `AE8C5EEED26CB8E4BE4B77F550BC39087E078CC72A049760BB92C3577B588A47`

The main Forge Vanguard builder was not modified in Task 6, so it was not regenerated.

## GREEN verification

```powershell
& $godot --headless --path $worktree --editor --quit-after 2
& $godot --headless --path $worktree --script res://tests/test_runner.gd --quit-after 120
& $godot --headless --path $worktree --script res://tests/integration/character_presentation_sandbox_runner.gd --quit-after 30
```

Results:

- Headless editor import: exit `0`.
- Full unit runner: `TEST_SUMMARY: FAIL (2 failures)`, exactly and only the approved historical Rogue range assertions: `test_expanded_class_content.gd` and `test_game_catalog.gd` both expect `rogue_flurry` range `1.600` while the saved value is `2.000`. There were no base-body or sandbox failures.
- Smoke runner: exit `0`, exact marker `PARTY_FORGE_PRESENTATION_SMOKE_OK bodies=2 palettes=3 slots=10 animations=4`.

## File handoff

- Generator: `tools/build_forge_base_body_scenes.gd`
- Base scenes: `scenes/characters/presentation/forge_base_masculine.tscn`, `scenes/characters/presentation/forge_base_feminine.tscn`
- Base profiles: `data/presentation/profiles/forge_base_masculine.tres`, `data/presentation/profiles/forge_base_feminine.tres`
- Sandbox: `scripts/dev/character_presentation_sandbox.gd`, `scenes/dev/character_presentation_sandbox.tscn`
- Tests: `tests/unit/test_forge_base_bodies.gd`, `tests/unit/test_character_presentation_sandbox.gd`, `tests/integration/character_presentation_sandbox_runner.gd`

## Concern

The repository's two pre-existing Rogue range assertions continue to make the full runner exit `1`; Task 6 adds no new unit, import, parser, or smoke failures.
