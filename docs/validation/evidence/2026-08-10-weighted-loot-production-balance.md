# Weighted Loot Production Balance Report

Deterministic schema 1 report. No timestamps, locale values, or environmental random inputs are included.

## Sample accounting

- Scenario rows: 82 (65 level x rarity, 8 archetype and party-bias, 9 Charisma x Heat)
- Sequences per row: 2000
- Attempts: 164000; successes: 164000; failures: 0

## Exact manifest and exclusions

| Bases | Weapon profiles | Affixes | Explicit | Implicit | Prefixes | Suffixes |
|---:|---:|---:|---:|---:|---:|---:|
| 99 | 11 | 195 | 96 | 99 | 48 | 48 |

- Ordinary rarities: common, epic, legendary, rare, uncommon
- Excluded nonordinary rarities: ascendant, divine, eternal, exotic, mythic
- Bases excluded from weapon percentiles: 88
- Unreachable affixes: 0

### Affix reachability

| Affix | Kind | Weight | Band | Min level | Max tier | Eligible bases | Eligible rarities | Reachable |
|---|---|---:|---|---:|---:|---:|---|---|
| apex_force | prefix | 25.000000 | 0025_premium_hybrid | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| arcane | prefix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| battle_hardened | prefix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| benevolent | prefix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| bloodbound | prefix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| bloodstep_ring_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| brutal | prefix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| cinder_ring_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| commanding | prefix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| commanding_presence | prefix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| conflagration_ring_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| cryomantic | prefix | 500.000000 | 0500_specialized_focused | 1 | 12 | 43 | common, epic, legendary, rare, uncommon | yes |
| dawn_bulwark_belt_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| dawn_bulwark_crown_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| dawn_bulwark_gauntlets_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| dawn_bulwark_greaves_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| dawn_bulwark_plate_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| dawn_bulwark_sabatons_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| dawn_bulwark_shield_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| deadeye | prefix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| duelist | prefix | 500.000000 | 0500_specialized_focused | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| elemental_fury | prefix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| emberheart_amulet_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| emberweave_circlet_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| emberweave_flame_focus_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| emberweave_leggings_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| emberweave_robe_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| emberweave_rune_sash_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| emberweave_shoes_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| emberweave_spell_gloves_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| emberweave_wand_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| eternal_bulwark | prefix | 25.000000 | 0025_premium_hybrid | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| farshot | prefix | 500.000000 | 0500_specialized_focused | 1 | 12 | 2 | common, epic, legendary, rare, uncommon | yes |
| farshot_amulet_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| forceful | prefix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| forge_vanguard_amulet_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| forge_vanguard_armour_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| forge_vanguard_belt_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| forge_vanguard_boots_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| forge_vanguard_gauntlets_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| forge_vanguard_greaves_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| forge_vanguard_hammer_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| forge_vanguard_helmet_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| forge_vanguard_ring_left_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| forge_vanguard_ring_right_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| forge_vanguard_shield_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| fortified_vitality | prefix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| glacial | prefix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| grave_covenant_bone_amulet_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| grave_covenant_bone_wand_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| grave_covenant_chained_sash_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| grave_covenant_grimoire_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| grave_covenant_hood_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| grave_covenant_leggings_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| grave_covenant_ritual_gloves_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| grave_covenant_robe_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| grave_covenant_wrapped_boots_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| greenwood_belt_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| greenwood_boots_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| greenwood_gloves_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| greenwood_hood_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| greenwood_jerkin_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| greenwood_leggings_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| greenwood_light_quiver_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| greenwood_recurve_bow_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| hawkeye_band_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| hoarfrost_ring_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| hunter_born | prefix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| inspiring | prefix | 500.000000 | 0500_specialized_focused | 1 | 12 | 41 | common, epic, legendary, rare, uncommon | yes |
| ironclad | prefix | 500.000000 | 0500_specialized_focused | 1 | 12 | 5 | common, epic, legendary, rare, uncommon | yes |
| juggernaut | prefix | 500.000000 | 0500_specialized_focused | 1 | 12 | 5 | common, epic, legendary, rare, uncommon | yes |
| keen | prefix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| long_watch_ring_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| martial_edge | prefix | 500.000000 | 0500_specialized_focused | 1 | 12 | 34 | common, epic, legendary, rare, uncommon | yes |
| merciful | prefix | 500.000000 | 0500_specialized_focused | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| mercy_ring_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| nightstep_dagger_main_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| nightstep_dagger_off_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| nightstep_grip_gloves_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| nightstep_hood_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| nightstep_leathers_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| nightstep_leggings_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| nightstep_soft_boots_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| nightstep_utility_belt_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| of_agility | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| of_alacrity | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| of_arcane_focus | suffix | 500.000000 | 0500_specialized_focused | 1 | 12 | 43 | common, epic, legendary, rare, uncommon | yes |
| of_arcane_mastery | suffix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| of_balanced_form | suffix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| of_boundless_reach | suffix | 25.000000 | 0025_premium_hybrid | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| of_chaos_ward | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| of_cold_ward | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| of_deadly_precision | suffix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| of_deflection | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| of_drain | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| of_embers | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| of_endurance | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| of_evasion | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| of_expansion | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| of_exploration | suffix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| of_ferocity | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| of_fire_ward | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| of_gathering | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| of_guarded_resolve | suffix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| of_guarding | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| of_inexorable_time | suffix | 25.000000 | 0025_premium_hybrid | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| of_insight | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| of_intellect | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| of_lightning_ward | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| of_martial_haste | suffix | 500.000000 | 0500_specialized_focused | 1 | 12 | 34 | common, epic, legendary, rare, uncommon | yes |
| of_martial_mastery | suffix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| of_might | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| of_perfect_form | suffix | 25.000000 | 0025_premium_hybrid | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| of_precision | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| of_presence | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| of_reach | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| of_recovery | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| of_restoration | suffix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| of_rime | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| of_royal_command | suffix | 25.000000 | 0025_premium_hybrid | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| of_swiftness | suffix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| of_the_cryomancer | suffix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| of_the_duelist | suffix | 500.000000 | 0500_specialized_focused | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| of_the_healer | suffix | 500.000000 | 0500_specialized_focused | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| of_the_marksman | suffix | 500.000000 | 0500_specialized_focused | 1 | 12 | 2 | common, epic, legendary, rare, uncommon | yes |
| of_the_occultist | suffix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| of_the_pyromancer | suffix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| of_the_savant | suffix | 500.000000 | 0500_specialized_focused | 1 | 12 | 43 | common, epic, legendary, rare, uncommon | yes |
| of_the_stormcaller | suffix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| of_the_wind | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| of_velocity | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| of_vigor | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| pact_ring_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| plated | prefix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| potent_weapon | prefix | 500.000000 | 0500_specialized_focused | 1 | 12 | 18 | common, epic, legendary, rare, uncommon | yes |
| primal_convergence | prefix | 25.000000 | 0025_premium_hybrid | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| profane | prefix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| pyromantic | prefix | 500.000000 | 0500_specialized_focused | 1 | 12 | 43 | common, epic, legendary, rare, uncommon | yes |
| reinforced | prefix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| rime_scholar_boots_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| rime_scholar_circlet_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| rime_scholar_crystal_sash_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| rime_scholar_gloves_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| rime_scholar_leggings_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| rime_scholar_robe_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| rime_scholar_staff_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| ring_of_mercy_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| ring_of_vigil_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| robust | prefix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| sacred_guard | prefix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| searing | prefix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| shadowchain_amulet_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| siege_archer_boots_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| siege_archer_braced_leggings_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| siege_archer_coat_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| siege_archer_cowl_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| siege_archer_draw_belt_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| siege_archer_draw_glove_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| siege_greatbow_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| siege_heavy_quiver_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| silent_edge_ring_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| sovereign_magic | prefix | 25.000000 | 0025_premium_hybrid | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| spell_forged | prefix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| spellwoven | prefix | 500.000000 | 0500_specialized_focused | 1 | 12 | 43 | common, epic, legendary, rare, uncommon | yes |
| steady_hand_ring_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| stillwater_ring_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| storm_chaplain_belt_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| storm_chaplain_boots_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| storm_chaplain_holy_tome_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| storm_chaplain_hood_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| storm_chaplain_leggings_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| storm_chaplain_prayer_gloves_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| storm_chaplain_reliquary_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| storm_chaplain_sceptre_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| storm_chaplain_vestments_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| storm_ring_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| stormcharged | prefix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| stormfire | prefix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| stout | prefix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| sun_oath_amulet_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| sunforged_warhammer_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| tempered | prefix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| tempered_edge | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| tempestuous | prefix | 500.000000 | 0500_specialized_focused | 1 | 12 | 43 | common, epic, legendary, rare, uncommon | yes |
| towerborn | prefix | 500.000000 | 0500_specialized_focused | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| trailmark_amulet_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| unyielding_force | prefix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| vital | prefix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| voidflame | prefix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| voidtouched | prefix | 500.000000 | 0500_specialized_focused | 1 | 12 | 43 | common, epic, legendary, rare, uncommon | yes |
| windrunner_band_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| winter_storm | prefix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| winterglass_amulet_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| wise | prefix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | common, epic, legendary, rare, uncommon | yes |
| withering_ring_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |

## Distribution findings

### Explicit weight bands

| Band | Definitions | Relative weight | Selected | Selected proportion |
|---|---:|---:|---:|---:|
| 0025_premium_hybrid | 8 | 0.025000 | 1342 | 0.004708 |
| 0150_standard_hybrid | 24 | 0.150000 | 24559 | 0.086151 |
| 0500_specialized_focused | 20 | 0.500000 | 15453 | 0.054208 |
| 1000_core_focused | 44 | 1.000000 | 243716 | 0.854934 |

- Average explicit tier at level 1: 1.000000; at level 1000: 3.998500.
- Rarity fill: 5/5; tier fill: 12/12.

### Party bias

| Archetype | Neutral match | Biased match | Biased off-party count |
|---|---:|---:|---:|
| caster | 0.424500 | 0.682000 | 636 |
| global | 0.458000 | 0.720000 | 560 |
| melee | 0.354500 | 0.605000 | 790 |
| ranged | 0.224500 | 0.472000 | 1056 |

### Charisma, Heat, and weapon damage

- Charisma 0: diminishing value 0.000000, premium proportion 0.004191, maximum observed tier 1.
- Charisma 100: diminishing value 0.500000, premium proportion 0.003721, maximum observed tier 1.
- Charisma 1000: diminishing value 0.909091, premium proportion 0.003653, maximum observed tier 1.
- Heat 0: rare-or-better proportion 0.150833.
- Heat 100: rare-or-better proportion 0.301500.
- Heat 25: rare-or-better proportion 0.198000.
- Weapon minimum damage percentiles: minimum 3.410000, median 75.260000, high (P90) 278.920000.
- Weapon maximum damage percentiles: minimum 5.960000, median 117.730000, high (P90) 430.540000.

## Scenario accounting

| Scenario | Attempts | Successes | Failures | Average explicit tier | Weapon samples |
|---|---:|---:|---:|---:|---:|
| archetype_party_bias|archetype=caster|mode=biased | 2000 | 2000 | 0 | 3.172470 | 223 |
| archetype_party_bias|archetype=caster|mode=neutral | 2000 | 2000 | 0 | 3.272235 | 237 |
| archetype_party_bias|archetype=global|mode=biased | 2000 | 2000 | 0 | 3.343165 | 164 |
| archetype_party_bias|archetype=global|mode=neutral | 2000 | 2000 | 0 | 3.296852 | 222 |
| archetype_party_bias|archetype=melee|mode=biased | 2000 | 2000 | 0 | 3.242057 | 220 |
| archetype_party_bias|archetype=melee|mode=neutral | 2000 | 2000 | 0 | 3.277605 | 205 |
| archetype_party_bias|archetype=ranged|mode=biased | 2000 | 2000 | 0 | 3.231842 | 206 |
| archetype_party_bias|archetype=ranged|mode=neutral | 2000 | 2000 | 0 | 3.358289 | 196 |
| charisma_heat|charisma=0000|heat=000 | 2000 | 2000 | 0 | 1.000000 | 224 |
| charisma_heat|charisma=0000|heat=025 | 2000 | 2000 | 0 | 1.000000 | 209 |
| charisma_heat|charisma=0000|heat=100 | 2000 | 2000 | 0 | 1.000000 | 223 |
| charisma_heat|charisma=0100|heat=000 | 2000 | 2000 | 0 | 1.000000 | 221 |
| charisma_heat|charisma=0100|heat=025 | 2000 | 2000 | 0 | 1.000000 | 197 |
| charisma_heat|charisma=0100|heat=100 | 2000 | 2000 | 0 | 1.000000 | 230 |
| charisma_heat|charisma=1000|heat=000 | 2000 | 2000 | 0 | 1.000000 | 225 |
| charisma_heat|charisma=1000|heat=025 | 2000 | 2000 | 0 | 1.000000 | 213 |
| charisma_heat|charisma=1000|heat=100 | 2000 | 2000 | 0 | 1.000000 | 207 |
| level_rarity|level=0001|rarity=common | 2000 | 2000 | 0 | 0.000000 | 181 |
| level_rarity|level=0001|rarity=epic | 2000 | 2000 | 0 | 1.000000 | 211 |
| level_rarity|level=0001|rarity=legendary | 2000 | 2000 | 0 | 1.000000 | 228 |
| level_rarity|level=0001|rarity=rare | 2000 | 2000 | 0 | 1.000000 | 223 |
| level_rarity|level=0001|rarity=uncommon | 2000 | 2000 | 0 | 1.000000 | 221 |
| level_rarity|level=0010|rarity=common | 2000 | 2000 | 0 | 0.000000 | 256 |
| level_rarity|level=0010|rarity=epic | 2000 | 2000 | 0 | 1.440333 | 211 |
| level_rarity|level=0010|rarity=legendary | 2000 | 2000 | 0 | 1.443875 | 256 |
| level_rarity|level=0010|rarity=rare | 2000 | 2000 | 0 | 1.420750 | 231 |
| level_rarity|level=0010|rarity=uncommon | 2000 | 2000 | 0 | 1.470000 | 205 |
| level_rarity|level=0030|rarity=common | 2000 | 2000 | 0 | 0.000000 | 216 |
| level_rarity|level=0030|rarity=epic | 2000 | 2000 | 0 | 1.836000 | 210 |
| level_rarity|level=0030|rarity=legendary | 2000 | 2000 | 0 | 1.857375 | 225 |
| level_rarity|level=0030|rarity=rare | 2000 | 2000 | 0 | 1.851750 | 227 |
| level_rarity|level=0030|rarity=uncommon | 2000 | 2000 | 0 | 1.841500 | 234 |
| level_rarity|level=0060|rarity=common | 2000 | 2000 | 0 | 0.000000 | 230 |
| level_rarity|level=0060|rarity=epic | 2000 | 2000 | 0 | 2.218833 | 240 |
| level_rarity|level=0060|rarity=legendary | 2000 | 2000 | 0 | 2.231375 | 211 |
| level_rarity|level=0060|rarity=rare | 2000 | 2000 | 0 | 2.238000 | 207 |
| level_rarity|level=0060|rarity=uncommon | 2000 | 2000 | 0 | 2.227500 | 217 |
| level_rarity|level=0100|rarity=common | 2000 | 2000 | 0 | 0.000000 | 241 |
| level_rarity|level=0100|rarity=epic | 2000 | 2000 | 0 | 2.557333 | 227 |
| level_rarity|level=0100|rarity=legendary | 2000 | 2000 | 0 | 2.567750 | 209 |
| level_rarity|level=0100|rarity=rare | 2000 | 2000 | 0 | 2.571500 | 225 |
| level_rarity|level=0100|rarity=uncommon | 2000 | 2000 | 0 | 2.604000 | 233 |
| level_rarity|level=0160|rarity=common | 2000 | 2000 | 0 | 0.000000 | 202 |
| level_rarity|level=0160|rarity=epic | 2000 | 2000 | 0 | 2.833833 | 250 |
| level_rarity|level=0160|rarity=legendary | 2000 | 2000 | 0 | 2.922625 | 227 |
| level_rarity|level=0160|rarity=rare | 2000 | 2000 | 0 | 2.837500 | 224 |
| level_rarity|level=0160|rarity=uncommon | 2000 | 2000 | 0 | 2.596000 | 239 |
| level_rarity|level=0240|rarity=common | 2000 | 2000 | 0 | 0.000000 | 187 |
| level_rarity|level=0240|rarity=epic | 2000 | 2000 | 0 | 3.192667 | 239 |
| level_rarity|level=0240|rarity=legendary | 2000 | 2000 | 0 | 3.138125 | 230 |
| level_rarity|level=0240|rarity=rare | 2000 | 2000 | 0 | 3.212000 | 219 |
| level_rarity|level=0240|rarity=uncommon | 2000 | 2000 | 0 | 2.625000 | 222 |
| level_rarity|level=0340|rarity=common | 2000 | 2000 | 0 | 0.000000 | 238 |
| level_rarity|level=0340|rarity=epic | 2000 | 2000 | 0 | 3.407833 | 215 |
| level_rarity|level=0340|rarity=legendary | 2000 | 2000 | 0 | 3.432375 | 219 |
| level_rarity|level=0340|rarity=rare | 2000 | 2000 | 0 | 3.431500 | 229 |
| level_rarity|level=0340|rarity=uncommon | 2000 | 2000 | 0 | 2.672500 | 226 |
| level_rarity|level=0460|rarity=common | 2000 | 2000 | 0 | 0.000000 | 222 |
| level_rarity|level=0460|rarity=epic | 2000 | 2000 | 0 | 3.771333 | 217 |
| level_rarity|level=0460|rarity=legendary | 2000 | 2000 | 0 | 3.697625 | 221 |
| level_rarity|level=0460|rarity=rare | 2000 | 2000 | 0 | 3.550750 | 221 |
| level_rarity|level=0460|rarity=uncommon | 2000 | 2000 | 0 | 2.700500 | 205 |
| level_rarity|level=0600|rarity=common | 2000 | 2000 | 0 | 0.000000 | 219 |
| level_rarity|level=0600|rarity=epic | 2000 | 2000 | 0 | 3.898833 | 222 |
| level_rarity|level=0600|rarity=legendary | 2000 | 2000 | 0 | 3.951625 | 214 |
| level_rarity|level=0600|rarity=rare | 2000 | 2000 | 0 | 3.581250 | 235 |
| level_rarity|level=0600|rarity=uncommon | 2000 | 2000 | 0 | 2.788000 | 213 |
| level_rarity|level=0770|rarity=common | 2000 | 2000 | 0 | 0.000000 | 221 |
| level_rarity|level=0770|rarity=epic | 2000 | 2000 | 0 | 4.018667 | 226 |
| level_rarity|level=0770|rarity=legendary | 2000 | 2000 | 0 | 4.078750 | 206 |
| level_rarity|level=0770|rarity=rare | 2000 | 2000 | 0 | 3.708500 | 198 |
| level_rarity|level=0770|rarity=uncommon | 2000 | 2000 | 0 | 2.782500 | 220 |
| level_rarity|level=0950|rarity=common | 2000 | 2000 | 0 | 0.000000 | 249 |
| level_rarity|level=0950|rarity=epic | 2000 | 2000 | 0 | 4.097167 | 220 |
| level_rarity|level=0950|rarity=legendary | 2000 | 2000 | 0 | 4.267875 | 211 |
| level_rarity|level=0950|rarity=rare | 2000 | 2000 | 0 | 3.784750 | 217 |
| level_rarity|level=0950|rarity=uncommon | 2000 | 2000 | 0 | 2.802500 | 238 |
| level_rarity|level=1000|rarity=common | 2000 | 2000 | 0 | 0.000000 | 197 |
| level_rarity|level=1000|rarity=epic | 2000 | 2000 | 0 | 4.182500 | 216 |
| level_rarity|level=1000|rarity=legendary | 2000 | 2000 | 0 | 4.260500 | 212 |
| level_rarity|level=1000|rarity=rare | 2000 | 2000 | 0 | 3.808250 | 221 |
| level_rarity|level=1000|rarity=uncommon | 2000 | 2000 | 0 | 2.779000 | 200 |
