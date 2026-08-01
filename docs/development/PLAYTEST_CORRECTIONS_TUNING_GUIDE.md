# Playtest Corrections Tuning Guide

This guide describes the current July 31 playtest-correction slice. All numeric windows below are conservative playtest envelopes, not additional engine validation rules. Change one concern at a time, keep a before/after capture, and run the named focused coverage plus the full unit runner before merging.

## Verification commands

The unit runner discovers every `tests/unit/test_*.gd` file; it does not expose a single-suite filter. A “focused unit suite” below therefore identifies the assertions most directly affected, while the supported command remains:

```powershell
& $godot --headless --path $worktree --script res://tests/test_runner.gd
```

The slice also has dedicated focused integrations:

```powershell
& $godot --headless --path $worktree --script res://tests/integration/temporary_popup_input_runner.gd
& $godot --headless --path $worktree --script res://tests/integration/level_up_five_card_geometry_runner.gd
& $godot --headless --path $worktree --script res://tests/integration/ledger_24_member_runner.gd
& $godot --headless --path $worktree --editor --quit-after 2
```

## Spawn bands and weights

Edit `scripts/game/spawn_schedule.gd`, in `SpawnSchedule.sample()`. The band boundaries and returned `SpawnBand.new(interval, swarmer_weight, boltcaster_weight, spitter_weight)` literals are the editable values; there are no separate resource properties for these bands.

| Elapsed band | Current interval | Current weights S/B/P | Conservative envelope |
| --- | ---: | ---: | --- |
| `0 <= t < 60` | `0.56` s | `100 / 0 / 0` | interval `0.50-0.65`; keep the introduction Swarmer-only |
| `60 <= t < 150` | `0.40` s | `75 / 25 / 0` | interval `0.35-0.48`; S `70-80`, B `20-30`, P `0` |
| `150 <= t < 240` | `0.29` s | `60 / 32 / 8` | interval `0.25-0.34`; S `55-65`, B `27-37`, P `5-10` |
| `240 <= t < 300` | `0.20` s | `50 / 35 / 15` | interval `0.18-0.25`; S `45-55`, B `30-40`, P `10-20` |

Shorter `interval` means greater spawn intensity. Weights are relative, so their total need not be 100, but the total must stay positive and zero keeps an enemy out of that band. If moving boundaries, keep them strictly increasing; treat `300.0` as the ordinary-run stop and coordinate any change with run-duration behavior. The developer `enemy_density_percent` later scales the effective interval (`base_interval * 100 / density`), so validate schedule edits at 100% density first.

Focused coverage: `tests/unit/test_spawn_schedule.gd` (`_test_schedule_boundaries`, seeded weight ratios, density adjustment, stop behavior). Update exact boundary/ratio expectations only when the design intentionally changes, then run the full unit command.

## Boltcaster attack

Edit `data/attacks/boltcaster_bolt.tres`.

| Property | Current | Effect | Conservative envelope |
| --- | ---: | --- | --- |
| damage component `base_amount` | `9.0` | hit intensity | `8.0-11.0` |
| `cooldown` | `2.4` s | lower values fire more often | `2.1-2.8` s |
| `range` | `16.0` m | maximum firing and travel reach | `14.0-18.0` m |
| `projectile_speed` | `8.0` m/s | reaction window and travel time | `7.0-10.0` m/s |
| `area_radius` | `0.0` m | impact splash radius | keep `0.0` for a single-target bolt; trial `0.25-0.5` only as an intentional splash change |

Do not tune `id`, `kind`, `damage_type_id`, or `action_tags` as balance knobs. `scripts/enemies/boltcaster.gd` uses the resource `cooldown` after a shot and resolved `range` before beginning the tell; its `PREFERRED_DISTANCE = 9.0` and `RETREAT_DISTANCE = 5.5` are separate movement behavior constants.

Focused coverage: `tests/unit/test_spawn_schedule.gd` ranged-range, Boltcaster tell, sampled aim, and linear-projectile assertions; `tests/unit/test_resolved_attack_geometry.gd`; then the full unit command. A hands-on dodge/readability pass is still required after numerical changes.

## Spitter attack

Edit `data/attacks/spitter_projectile.tres`.

| Property | Current | Effect | Conservative envelope |
| --- | ---: | --- | --- |
| damage component `base_amount` | `10.0` | hit intensity | `8.0-12.0` |
| `cooldown` | `2.2` s | lower values fire more often | `2.0-2.6` s |
| `range` | `18.0` m | maximum firing and travel reach | `16.0-20.0` m |
| `projectile_speed` | `6.0` m/s | homing pressure and reaction time | `5.0-8.0` m/s |
| `area_radius` | implicit default `0.0` m | impact splash radius | keep omitted/`0.0` for the current single-target orb; trial `0.25-0.75` only as an intentional splash change |

`scripts/enemies/spitter.gd` uses the resource `cooldown` and resolved `range`; its `PREFERRED_DISTANCE = 8.0` and `RETREAT_DISTANCE = 5.0` independently control spacing.

Focused coverage: `tests/unit/test_spawn_schedule.gd` Spitter spacing/cadence, ranged-range, and homing-projectile assertions; `tests/unit/test_resolved_attack_geometry.gd`; then the full unit command and a hands-on pressure/readability pass.

> **Range and area warning:** `range` and `area_radius` are normalized through `ResolvedAttackGeometry` but remain distinct semantics. Range controls target/travel reach; area radius controls the impact/cleave footprint. Range multipliers scale only range, area multipliers scale only area, invalid multipliers fall back or clamp independently, and changing one is not a substitute for changing the other.

## Enemy projectile movement and color profiles

The two current profile resources are `data/projectiles/boltcaster_bolt.tres` and `data/projectiles/spitter_orb.tres`. They are wired by `data/enemies/boltcaster.tres` and `data/enemies/spitter.tres`.

| Property | Boltcaster | Spitter | Effect and conservative envelope |
| --- | ---: | ---: | --- |
| `movement` | `0` (`LINEAR`) | `1` (`HOMING`) | categorical behavior, not a numeric intensity knob; keep the current identities unless redesigning the enemy |
| `color` | `Color(1, 0.08, 0.05, 1)` | `Color(0.75, 0.15, 1, 1)` | readability; keep alpha `1`, keep bolt warm/red and orb purple, and preserve strong contrast from arena/background and each other |
| `hit_radius` | `0.4` m | `0.45` m | collision forgiveness/pressure; Bolt `0.30-0.50`, Spitter `0.35-0.55` |
| `max_lifetime` | `3.0` s | `3.0` s | hard travel lifetime; trial `2.5-4.0` and `3.0-4.0` respectively |
| `tell_duration` | `0.35` s | `0.2` s | pre-fire readability; Bolt `0.25-0.50`, Spitter `0.15-0.35` |

`scripts/enemies/enemy_projectile.gd` resolves actual lifetime as the smaller of `max_lifetime` and `range / projectile_speed + 0.5`; avoid setting `max_lifetime` below `range / projectile_speed` unless early expiry is intentional. Colors are applied directly to the projectile material.

Focused coverage: `tests/unit/test_enemy_projectile_profile.gd` and the linear/homing tests in `tests/unit/test_spawn_schedule.gd`, then the full unit command. Color contrast, tell clarity, and dodgeability need connected visual acceptance.

## Recruit probability and drought

Edit `scripts/progression/recruit_offer_policy.gd` in `count_for_roll()`.

The current thresholds produce 0 recruits for 45% of eligible rolls, 1 for 40%, 2 for 12%, and 3 for 3%. `DROUGHT_LIMIT = 3` forces at least one recruit after three consecutive eligible offers without one. Ineligible offers (for example, a full party) preserve rather than increase or clear the streak.

Conservative threshold windows are `0.40-0.50` for the first recruit boundary (current `0.45`), `0.82-0.88` for two (current `0.85`), and `0.95-0.98` for three (current `0.97`), always kept strictly ascending. A conservative drought window is `2-4`; lower is more generous, higher permits longer no-recruit runs. Probability edits change the width between thresholds, not independent percentage properties.

Focused coverage: `tests/unit/test_recruit_offer_policy.gd` for exact boundaries/drought transitions and `tests/unit/test_upgrade_choices.gd` for offer composition/capacity behavior, then the full unit command.

## Experience curve

Edit `data/progression/default_experience.tres`. It currently relies on exported defaults from `scripts/data/experience_tuning.gd`: `base_cost = 20.0`, `linear_growth = 8.0`, and `acceleration = 2.0`. To override them in the resource, add those exact property names under `[resource]`.

The requirement for current level `L` is `ceil(base_cost + linear_growth * n + acceleration * n^2)`, where `n = max(L, 1) - 1`, clamped to at least 1. The current requirements for levels 1 through 10 are `20, 30, 44, 62, 84, 110, 140, 174, 212, 254`.

Conservative first-pass windows are `base_cost 16-24`, `linear_growth 6-10`, and `acceleration 1.5-2.5`. `base_cost` moves the early floor, `linear_growth` changes each level steadily, and `acceleration` dominates the late curve. For faster testing without changing production progression, prefer Developer Mode `experience_multiplier_percent`.

Focused coverage: `tests/unit/test_progression.gd` threshold/overflow assertions and `tests/unit/test_main_wiring.gd` queued-level production flow, then the full unit command.

## Developer settings ranges and defaults

Edit `scripts/settings/party_forge_settings.gd` only when changing the settings contract. The settings UI/store consume these exact fields.

| Field | Default | Normalized range or values | Test effect |
| --- | ---: | --- | --- |
| `mode` | `PLAYER_SIMULATION` | `PLAYER_SIMULATION` or `DEVELOPER_MODE` | overrides apply only in Developer Mode |
| `unlock_all_implemented_content` | `false` | boolean | exposes implemented gated content |
| `god_mode` | `false` | boolean | prevents party health below the policy minimum |
| `party_capacity_override` | `4` | `1-24` | roster/recruit capacity; use `24` for ledger stress |
| `enemy_density_percent` | `100` | `0-1000` | `0` stops ordinary spawning; `1000` makes intervals one tenth of base |
| `experience_multiplier_percent` | `100` | `100-1000` | speeds level-up acquisition without editing the curve |
| `level_up_card_count` | `5` | `1-8` | offer/card count; the dedicated geometry runner specifically proves five cards |
| `reduced_motion` | `false` | boolean | resolves the level-up reveal immediately |

Keep the player-simulation defaults (`4`, `100`, `100`, `5`, toggles false) as the production baseline. High density and 24-member/8-card modes are stress settings, not claims of balanced play.

Focused coverage: `tests/unit/test_settings_screen.gd`, `tests/unit/test_run_rules_policies.gd`, and `tests/unit/test_main_wiring.gd`; then use the five-card and ledger integrations when changing the related extrema.

## Level-up layout, reveal, reduced motion, and tooltips

Layout edits start in `scenes/ui/level_up_panel.tscn` and `scenes/ui/upgrade_card.tscn`:

- `ContentPanel.custom_minimum_size.y = 560`, anchors left/top/right/bottom `0.02/0.06/0.98/0.94`, `Content` separation `18`, and `Cards` separation `16` control modal space and card breathing room. First-pass windows: minimum height `520-620`, horizontal anchors `0.02-0.04`/`0.96-0.98`, vertical anchors `0.05-0.08`/`0.92-0.95`, content separation `14-22`, card separation `12-18`.
- `UpgradeCard.custom_minimum_size = Vector2(168, 300)` and `Content` offsets `10/16/-10/-16` control card width/height and internal padding. First-pass windows: width `160-184`, height `280-320`, horizontal padding `8-14`, vertical padding `12-20`.
- `scripts/ui/level_up_panel.gd` uses `viewport_width >= 1400.0` to show `Eligibility`, `Recipient`, and `Inheritance`; below that width the card retains Name, Scope, Rank, and Summary. Trial the breakpoint only within `1360-1480` and re-run all four geometry sizes.

Reveal timing is in `scripts/ui/level_up_reveal_controller.gd`: `TOTAL_DURATION = 1.1`, `DROP_DURATION = 0.3`, `PREVIEW_INTERVAL = 0.075`, and `DROP_OFFSET = -520.0`. Conservative windows are total `0.8-1.4` s, drop `0.22-0.40` s (never greater than total), preview `0.06-0.12` s, and offset `-400` to `-600` px. During reveal cards are disabled; accept/cancel skips to the unchanged final bindings. `PartyForgeSettings.reduced_motion` defaults false, but `LevelUpPanel._reduced_motion` starts true defensively until the run snapshot configures it; reduced motion resolves immediately and focuses the first enabled card.

Tooltip size/layout is in `scenes/ui/upgrade_tooltip_panel.tscn`: minimum `420 x 360`, pin target `44 x 44`, body vertical scrolling enabled. `scripts/ui/upgrade_tooltip_panel.gd` sets `EDGE_MARGIN = 16`, `MAXIMUM_POPUP_HEIGHT = 680`, and `CONTENT_PADDING_ALLOWANCE = 32`; safe first-pass windows are width `380-480`, minimum height `320-420`, edge margin `12-24`, and maximum height `600-720`. Keep the pin target at least `44 x 44`. `scripts/ui/temporary_hover_popup.gd` owns hold/pin/source retention and controller scrolling (`CONTROLLER_SCROLL_SPEED = 560`, `INPUT_DEADZONE = 0.15`); trial `420-700` px/s and deadzone `0.12-0.22` only with controller acceptance.

Focused coverage: `tests/unit/test_level_up_reveal_controller.gd`, `tests/unit/test_level_up_targeting_ui.gd`, and `tests/unit/test_foundational_upgrade_presentation.gd`, followed by both `level_up_five_card_geometry_runner.gd` and `temporary_popup_input_runner.gd` at all four viewports.

## Ledger roster and layout through 24 members

Static layout starts in `scenes/ui/ledger/character_ledger.tscn`: desktop frame offsets `48/36/-48/-36`, body `split_offset = 280`, party rail minimum width `260`, one roster column, page minimum `600 x 420`, and `PartyScroll.follow_focus = true`. `scripts/ui/ledger/character_ledger.gd::apply_viewport_size()` is the runtime authority:

| Runtime value | Desktop | Compact | Conservative envelope |
| --- | ---: | ---: | --- |
| frame horizontal/vertical inset | `48 / 36` | `16 / 12` | desktop `32-64 / 24-48`; compact `12-20 / 8-16` |
| roster columns | `1` | `3` | keep `1`; compact `2-4` with navigation test updates |
| party scroll minimum | `260 x 0` | `0 x 112` | desktop width `240-320`; compact height `100-144` |
| page host minimum | `600 x 420` | `0 x 220` | desktop `560-720 x 380-480`; compact height `200-280` |
| body split offset | `280` | `132` | desktop `260-340`; compact `116-156` |

Compact mode is selected in `scripts/ui/ledger/ledger_responsive_layout.gd` below width `1100` or height `650`. Trial thresholds within width `1024-1200` and height `600-720`, then validate both sides of each boundary. Capacity 24 comes from `party_capacity_override`, not the ledger scene. Preserve `follow_focus`, `ensure_control_visible()`, the revision-keyed deferred visibility request, and directional focus-neighbor wiring; those are what keep members 1 through 24 reachable after focus, selection, refresh, and responsive relayout.

Focused coverage: `tests/unit/test_ledger_responsive_input.gd`, `tests/unit/test_character_ledger_shell.gd`, `tests/unit/test_stats_ledger_page.gd`, and `tests/unit/test_upgrades_ledger_page.gd`, then `tests/integration/ledger_24_member_runner.gd`. The integration must retain PASS at desktop `1920 x 1080` and compact `960 x 540`, including direct and directional access to member 24 and scrolling back to member 1.

## Final acceptance boundary

Headless/unit/integration/parser results establish automated correctness only. A connected windowed smoke must still cover class selection, run start, combat, the reveal and skip behavior, tooltip pin/scroll, pause ledger, Boltcaster and Spitter readability/behavior, and quit. Record those as `PENDING USER/CONNECTED ACCEPTANCE` until a person actually performs them; never infer a manual PASS from the headless suite.
