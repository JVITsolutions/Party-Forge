# Weighted Loot Production Balance Report

Deterministic schema 2 report. No timestamps, locale values, or environmental random inputs are included.

## Sample accounting

- Scenario rows: 82 (65 level x rarity, 8 archetype and party-bias, 9 Charisma x Heat)
- Sequences per row: 2000
- Attempts: 164000; successes: 164000; failures: 0

## Exact manifest and exclusions

| Bases | Weapon profiles | Affixes | Explicit | Implicit | Prefixes | Suffixes |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 99 | 11 | 195 | 96 | 99 | 48 | 48 |

- Ordinary rarities: common, epic, legendary, rare, uncommon
- Excluded nonordinary rarities: ascendant, divine, eternal, exotic, mythic
- Bases excluded from weapon percentiles: 88
- Unreachable affixes: 0

### Affix reachability

| Affix | Kind | Weight | Band | Min level | Max tier | Eligible bases | Eligible rarities | Reachable |
| --- | --- | ---: | --- | ---: | ---: | ---: | --- | --- |
| apex_force | prefix | 25.000000 | 0025_premium_hybrid | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| arcane | prefix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| battle_hardened | prefix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| benevolent | prefix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| bloodbound | prefix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| bloodstep_ring_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| brutal | prefix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| cinder_ring_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| commanding | prefix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| commanding_presence | prefix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| conflagration_ring_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| cryomantic | prefix | 500.000000 | 0500_specialized_focused | 1 | 12 | 43 | epic, legendary, rare, uncommon | yes |
| dawn_bulwark_belt_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| dawn_bulwark_crown_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| dawn_bulwark_gauntlets_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| dawn_bulwark_greaves_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| dawn_bulwark_plate_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| dawn_bulwark_sabatons_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| dawn_bulwark_shield_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| deadeye | prefix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| duelist | prefix | 500.000000 | 0500_specialized_focused | 1 | 12 | 1 | epic, legendary, rare, uncommon | yes |
| elemental_fury | prefix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| emberheart_amulet_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| emberweave_circlet_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| emberweave_flame_focus_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| emberweave_leggings_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| emberweave_robe_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| emberweave_rune_sash_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| emberweave_shoes_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| emberweave_spell_gloves_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| emberweave_wand_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| eternal_bulwark | prefix | 25.000000 | 0025_premium_hybrid | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| farshot | prefix | 500.000000 | 0500_specialized_focused | 1 | 12 | 2 | epic, legendary, rare, uncommon | yes |
| farshot_amulet_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| forceful | prefix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
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
| fortified_vitality | prefix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| glacial | prefix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
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
| hunter_born | prefix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| inspiring | prefix | 500.000000 | 0500_specialized_focused | 1 | 12 | 41 | epic, legendary, rare, uncommon | yes |
| ironclad | prefix | 500.000000 | 0500_specialized_focused | 1 | 12 | 5 | epic, legendary, rare, uncommon | yes |
| juggernaut | prefix | 500.000000 | 0500_specialized_focused | 1 | 12 | 5 | epic, legendary, rare, uncommon | yes |
| keen | prefix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| long_watch_ring_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| martial_edge | prefix | 500.000000 | 0500_specialized_focused | 1 | 12 | 34 | epic, legendary, rare, uncommon | yes |
| merciful | prefix | 500.000000 | 0500_specialized_focused | 1 | 12 | 1 | epic, legendary, rare, uncommon | yes |
| mercy_ring_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| nightstep_dagger_main_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| nightstep_dagger_off_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| nightstep_grip_gloves_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| nightstep_hood_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| nightstep_leathers_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| nightstep_leggings_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| nightstep_soft_boots_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| nightstep_utility_belt_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| of_agility | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| of_alacrity | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| of_arcane_focus | suffix | 500.000000 | 0500_specialized_focused | 1 | 12 | 43 | epic, legendary, rare, uncommon | yes |
| of_arcane_mastery | suffix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| of_balanced_form | suffix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| of_boundless_reach | suffix | 25.000000 | 0025_premium_hybrid | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| of_chaos_ward | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| of_cold_ward | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| of_deadly_precision | suffix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| of_deflection | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| of_drain | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| of_embers | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| of_endurance | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| of_evasion | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| of_expansion | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| of_exploration | suffix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| of_ferocity | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| of_fire_ward | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| of_gathering | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| of_guarded_resolve | suffix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| of_guarding | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| of_inexorable_time | suffix | 25.000000 | 0025_premium_hybrid | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| of_insight | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| of_intellect | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| of_lightning_ward | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| of_martial_haste | suffix | 500.000000 | 0500_specialized_focused | 1 | 12 | 34 | epic, legendary, rare, uncommon | yes |
| of_martial_mastery | suffix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| of_might | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| of_perfect_form | suffix | 25.000000 | 0025_premium_hybrid | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| of_precision | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| of_presence | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| of_reach | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| of_recovery | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| of_restoration | suffix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| of_rime | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| of_royal_command | suffix | 25.000000 | 0025_premium_hybrid | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| of_swiftness | suffix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| of_the_cryomancer | suffix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| of_the_duelist | suffix | 500.000000 | 0500_specialized_focused | 1 | 12 | 1 | epic, legendary, rare, uncommon | yes |
| of_the_healer | suffix | 500.000000 | 0500_specialized_focused | 1 | 12 | 1 | epic, legendary, rare, uncommon | yes |
| of_the_marksman | suffix | 500.000000 | 0500_specialized_focused | 1 | 12 | 2 | epic, legendary, rare, uncommon | yes |
| of_the_occultist | suffix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| of_the_pyromancer | suffix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| of_the_savant | suffix | 500.000000 | 0500_specialized_focused | 1 | 12 | 43 | epic, legendary, rare, uncommon | yes |
| of_the_stormcaller | suffix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| of_the_wind | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| of_velocity | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| of_vigor | suffix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| pact_ring_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| plated | prefix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| potent_weapon | prefix | 500.000000 | 0500_specialized_focused | 1 | 12 | 18 | epic, legendary, rare, uncommon | yes |
| primal_convergence | prefix | 25.000000 | 0025_premium_hybrid | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| profane | prefix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| pyromantic | prefix | 500.000000 | 0500_specialized_focused | 1 | 12 | 43 | epic, legendary, rare, uncommon | yes |
| reinforced | prefix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| rime_scholar_boots_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| rime_scholar_circlet_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| rime_scholar_crystal_sash_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| rime_scholar_gloves_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| rime_scholar_leggings_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| rime_scholar_robe_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| rime_scholar_staff_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| ring_of_mercy_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| ring_of_vigil_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| robust | prefix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| sacred_guard | prefix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| searing | prefix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
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
| sovereign_magic | prefix | 25.000000 | 0025_premium_hybrid | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| spell_forged | prefix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| spellwoven | prefix | 500.000000 | 0500_specialized_focused | 1 | 12 | 43 | epic, legendary, rare, uncommon | yes |
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
| stormcharged | prefix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| stormfire | prefix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| stout | prefix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| sun_oath_amulet_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| sunforged_warhammer_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| tempered | prefix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| tempered_edge | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| tempestuous | prefix | 500.000000 | 0500_specialized_focused | 1 | 12 | 43 | epic, legendary, rare, uncommon | yes |
| towerborn | prefix | 500.000000 | 0500_specialized_focused | 1 | 12 | 1 | epic, legendary, rare, uncommon | yes |
| trailmark_amulet_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| unyielding_force | prefix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| vital | prefix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| voidflame | prefix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| voidtouched | prefix | 500.000000 | 0500_specialized_focused | 1 | 12 | 43 | epic, legendary, rare, uncommon | yes |
| windrunner_band_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| winter_storm | prefix | 150.000000 | 0150_standard_hybrid | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| winterglass_amulet_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |
| wise | prefix | 1000.000000 | 1000_core_focused | 1 | 12 | 99 | epic, legendary, rare, uncommon | yes |
| withering_ring_implicit | implicit | 100.000000 | implicit | 1 | 12 | 1 | common, epic, legendary, rare, uncommon | yes |

## Distribution findings

### Explicit weight bands

Each count below is an explicit-affix selection, not an item. Expected proportions are averaged from the live effective candidate weights recorded at every explicit selection opportunity; relative-to-core divides each expected proportion by the core-focused expected proportion.

| Band | Definitions | Expected effective proportion | Expected relative to core | Selected explicit affixes | Explicit-affix denominator | Selected proportion |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 0025_premium_hybrid | 8 | 0.004954 | 0.005797 | 1342 | 285070 | 0.004708 |
| 0150_standard_hybrid | 24 | 0.086129 | 0.100789 | 24559 | 285070 | 0.086151 |
| 0500_specialized_focused | 20 | 0.054369 | 0.063623 | 15453 | 285070 | 0.054208 |
| 1000_core_focused | 44 | 0.854548 | 1.000000 | 243716 | 285070 | 0.854934 |

- Average explicit tier at level 1: 1.000000; at level 1000: 3.998500.
- Rarity fill: 5/5; tier fill: 12/12.

### Party bias

| Archetype | Neutral match | Biased match | Biased off-party count |
| --- | ---: | ---: | ---: |
| caster | 0.424500 | 0.682000 | 636 |
| global | 0.458000 | 0.720000 | 560 |
| melee | 0.354500 | 0.605000 | 790 |
| ranged | 0.224500 | 0.472000 | 1056 |

### Charisma, Heat, and weapon damage

- Charisma 0: generated selected effective/base-weight uplift 1.044153, expected premium selection proportion 0.004068, observed premium proportion 0.004191, maximum observed tier 1.
- Charisma 100: generated selected effective/base-weight uplift 1.061286, expected premium selection proportion 0.004516, observed premium proportion 0.003721, maximum observed tier 1.
- Charisma 1000: generated selected effective/base-weight uplift 1.073634, expected premium selection proportion 0.004877, observed premium proportion 0.003653, maximum observed tier 1.
- Heat 0: rare-or-better proportion 0.150833.
- Heat 25: rare-or-better proportion 0.198000.
- Heat 100: rare-or-better proportion 0.301500.
- Weapon percentile convention: linear interpolation at rank (n - 1) * p; P0 minimum, P50 median, P90 high.
- Weapon minimum damage percentiles: minimum 3.410000, median 75.270000, high (P90) 278.927000.
- Weapon maximum damage percentiles: minimum 5.960000, median 117.745000, high (P90) 430.575000.

## Scenario accounting

| Scenario | Attempts | Successes | Failures | Average explicit tier | Weapon samples |
| --- | ---: | ---: | ---: | ---: | ---: |
| Level 1 / Common | 2000 | 2000 | 0 | 0.000000 | 181 |
| Level 1 / Uncommon | 2000 | 2000 | 0 | 1.000000 | 221 |
| Level 1 / Rare | 2000 | 2000 | 0 | 1.000000 | 223 |
| Level 1 / Epic | 2000 | 2000 | 0 | 1.000000 | 211 |
| Level 1 / Legendary | 2000 | 2000 | 0 | 1.000000 | 228 |
| Level 10 / Common | 2000 | 2000 | 0 | 0.000000 | 256 |
| Level 10 / Uncommon | 2000 | 2000 | 0 | 1.470000 | 205 |
| Level 10 / Rare | 2000 | 2000 | 0 | 1.420750 | 231 |
| Level 10 / Epic | 2000 | 2000 | 0 | 1.440333 | 211 |
| Level 10 / Legendary | 2000 | 2000 | 0 | 1.443875 | 256 |
| Level 30 / Common | 2000 | 2000 | 0 | 0.000000 | 216 |
| Level 30 / Uncommon | 2000 | 2000 | 0 | 1.841500 | 234 |
| Level 30 / Rare | 2000 | 2000 | 0 | 1.851750 | 227 |
| Level 30 / Epic | 2000 | 2000 | 0 | 1.836000 | 210 |
| Level 30 / Legendary | 2000 | 2000 | 0 | 1.857375 | 225 |
| Level 60 / Common | 2000 | 2000 | 0 | 0.000000 | 230 |
| Level 60 / Uncommon | 2000 | 2000 | 0 | 2.227500 | 217 |
| Level 60 / Rare | 2000 | 2000 | 0 | 2.238000 | 207 |
| Level 60 / Epic | 2000 | 2000 | 0 | 2.218833 | 240 |
| Level 60 / Legendary | 2000 | 2000 | 0 | 2.231375 | 211 |
| Level 100 / Common | 2000 | 2000 | 0 | 0.000000 | 241 |
| Level 100 / Uncommon | 2000 | 2000 | 0 | 2.604000 | 233 |
| Level 100 / Rare | 2000 | 2000 | 0 | 2.571500 | 225 |
| Level 100 / Epic | 2000 | 2000 | 0 | 2.557333 | 227 |
| Level 100 / Legendary | 2000 | 2000 | 0 | 2.567750 | 209 |
| Level 160 / Common | 2000 | 2000 | 0 | 0.000000 | 202 |
| Level 160 / Uncommon | 2000 | 2000 | 0 | 2.596000 | 239 |
| Level 160 / Rare | 2000 | 2000 | 0 | 2.837500 | 224 |
| Level 160 / Epic | 2000 | 2000 | 0 | 2.833833 | 250 |
| Level 160 / Legendary | 2000 | 2000 | 0 | 2.922625 | 227 |
| Level 240 / Common | 2000 | 2000 | 0 | 0.000000 | 187 |
| Level 240 / Uncommon | 2000 | 2000 | 0 | 2.625000 | 222 |
| Level 240 / Rare | 2000 | 2000 | 0 | 3.212000 | 219 |
| Level 240 / Epic | 2000 | 2000 | 0 | 3.192667 | 239 |
| Level 240 / Legendary | 2000 | 2000 | 0 | 3.138125 | 230 |
| Level 340 / Common | 2000 | 2000 | 0 | 0.000000 | 238 |
| Level 340 / Uncommon | 2000 | 2000 | 0 | 2.672500 | 226 |
| Level 340 / Rare | 2000 | 2000 | 0 | 3.431500 | 229 |
| Level 340 / Epic | 2000 | 2000 | 0 | 3.407833 | 215 |
| Level 340 / Legendary | 2000 | 2000 | 0 | 3.432375 | 219 |
| Level 460 / Common | 2000 | 2000 | 0 | 0.000000 | 222 |
| Level 460 / Uncommon | 2000 | 2000 | 0 | 2.700500 | 205 |
| Level 460 / Rare | 2000 | 2000 | 0 | 3.550750 | 221 |
| Level 460 / Epic | 2000 | 2000 | 0 | 3.771333 | 217 |
| Level 460 / Legendary | 2000 | 2000 | 0 | 3.697625 | 221 |
| Level 600 / Common | 2000 | 2000 | 0 | 0.000000 | 219 |
| Level 600 / Uncommon | 2000 | 2000 | 0 | 2.788000 | 213 |
| Level 600 / Rare | 2000 | 2000 | 0 | 3.581250 | 235 |
| Level 600 / Epic | 2000 | 2000 | 0 | 3.898833 | 222 |
| Level 600 / Legendary | 2000 | 2000 | 0 | 3.951625 | 214 |
| Level 770 / Common | 2000 | 2000 | 0 | 0.000000 | 221 |
| Level 770 / Uncommon | 2000 | 2000 | 0 | 2.782500 | 220 |
| Level 770 / Rare | 2000 | 2000 | 0 | 3.708500 | 198 |
| Level 770 / Epic | 2000 | 2000 | 0 | 4.018667 | 226 |
| Level 770 / Legendary | 2000 | 2000 | 0 | 4.078750 | 206 |
| Level 950 / Common | 2000 | 2000 | 0 | 0.000000 | 249 |
| Level 950 / Uncommon | 2000 | 2000 | 0 | 2.802500 | 238 |
| Level 950 / Rare | 2000 | 2000 | 0 | 3.784750 | 217 |
| Level 950 / Epic | 2000 | 2000 | 0 | 4.097167 | 220 |
| Level 950 / Legendary | 2000 | 2000 | 0 | 4.267875 | 211 |
| Level 1000 / Common | 2000 | 2000 | 0 | 0.000000 | 197 |
| Level 1000 / Uncommon | 2000 | 2000 | 0 | 2.779000 | 200 |
| Level 1000 / Rare | 2000 | 2000 | 0 | 3.808250 | 221 |
| Level 1000 / Epic | 2000 | 2000 | 0 | 4.182500 | 216 |
| Level 1000 / Legendary | 2000 | 2000 | 0 | 4.260500 | 212 |
| Caster / Neutral | 2000 | 2000 | 0 | 3.272235 | 237 |
| Caster / Biased | 2000 | 2000 | 0 | 3.172470 | 223 |
| Global / Neutral | 2000 | 2000 | 0 | 3.296852 | 222 |
| Global / Biased | 2000 | 2000 | 0 | 3.343165 | 164 |
| Melee / Neutral | 2000 | 2000 | 0 | 3.277605 | 205 |
| Melee / Biased | 2000 | 2000 | 0 | 3.242057 | 220 |
| Ranged / Neutral | 2000 | 2000 | 0 | 3.358289 | 196 |
| Ranged / Biased | 2000 | 2000 | 0 | 3.231842 | 206 |
| Charisma 0 / Heat 0 | 2000 | 2000 | 0 | 1.000000 | 224 |
| Charisma 0 / Heat 25 | 2000 | 2000 | 0 | 1.000000 | 209 |
| Charisma 0 / Heat 100 | 2000 | 2000 | 0 | 1.000000 | 223 |
| Charisma 100 / Heat 0 | 2000 | 2000 | 0 | 1.000000 | 221 |
| Charisma 100 / Heat 25 | 2000 | 2000 | 0 | 1.000000 | 197 |
| Charisma 100 / Heat 100 | 2000 | 2000 | 0 | 1.000000 | 230 |
| Charisma 1000 / Heat 0 | 2000 | 2000 | 0 | 1.000000 | 225 |
| Charisma 1000 / Heat 25 | 2000 | 2000 | 0 | 1.000000 | 213 |
| Charisma 1000 / Heat 100 | 2000 | 2000 | 0 | 1.000000 | 207 |
