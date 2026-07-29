# Party Forge Prototype Validation

## Result

**PASS — the Task 13 prototype milestone is complete.** Every required validation entry below is `PASS`; none is `FAIL` or `DEFERRED`.

## Environment and automated checks

| Status | Requirement | Recorded evidence |
| --- | --- | --- |
| PASS | Engine version | `4.7.1.stable.mono.official.a13da4feb` |
| PASS | Source commit under validation | Baseline `1be1a69edadbd671bc6acc376f54487ed7d44d4c`; Task 13 production, sandbox, tests, report, and screenshot changes were the reviewed working-tree delta subsequently committed together. |
| PASS | Complete automated suite | `& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path 'F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\party-forge-prototype' --script res://tests/test_runner.gd` exited `0` with `TEST_SUMMARY: PASS (14 suites)`. |
| PASS | Parser/import check | `& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --editor --path 'F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\party-forge-prototype' --quit` exited `0`; filesystem scan, global-class registration, and screenshot import all reached `DONE`. |
| PASS | Godot error count | `0` `SCRIPT ERROR`/`ERROR:` lines across the final suite, parser/import, sandbox smoke, eligible victory run, and defeat run. The eligible victory process also recorded `0` stderr bytes. |
| PASS | Sandbox public-action smoke | Production-scene smoke exited `0` with `TASK_13_SANDBOX_SMOKE: PASS party=4 active_tiers=2`. |

## Developer sandbox

| Status | Requirement | Recorded evidence |
| --- | --- | --- |
| PASS | Explicit class buttons | Fighter, Ranger, Mage, and Cleric buttons call the sandbox's public `spawn_class` action, which delegates to `PartyManager.recruit`. |
| PASS | Explicit hostile buttons | Swarmer and Spitter delegate to `SpawnDirector.spawn_enemy`; Forge Guardian instances the production boss scene and calls its public `configure_boss` interface. |
| PASS | Companion and cleanup actions | `Down Selected Companion` calls the selected production actor's public `receive_damage`; `Clear Hostiles` clears the sandbox's hostile container. |
| PASS | Live composition data | Party size, class ranks, trait counts, active tiers, and selected companion are displayed and refreshed from `PartyManager`/production actor state. |
| PASS | Party cap | Ordinary launches use `PartyManager.MAX_PARTY_SIZE == 4` and the smoke observed exactly four. `cap_override_allowed` returns true only for editor hint plus exact `res://scenes/dev/combat_sandbox.tscn`; no production class received a sandbox-only method and ordinary sandbox actions do not bypass the cap. |

## Ordinary-timing boss-victory acceptance

The eligible run launched the production `scenes/game/main.tscn` graph in a visible D3D12 viewport. The driver passed no acceleration flag, asserted `GameRun.debug_time_scale == 1.0`, selected through production UI buttons, and used mapped movement input. Boss damage and victory came only from automatic production party combat.

| Status | Requirement | Recorded evidence |
| --- | --- | --- |
| PASS | Ordinary duration | Wall duration `343.537s`; unpaused production run time `300.000s`. |
| PASS | Party composition | `Fighter + Ranger + Fighter + Cleric` (four members with duplicate Fighter). Victory viewport ranks: Fighter 2, Ranger 4, Fighter 2, Cleric 4. |
| PASS | Overlapping traits | `martial:2` and `vanguard:2` active. |
| PASS | Companion down/revive | Companion #2 down observed at wall `176.118s`; automatic runtime revive observed at `184.117s` with `45.0` health. |
| PASS | Swarmer behavior | Production Swarmer scene observed pursuing with nonzero chase velocity. |
| PASS | Spitter behavior | Production Spitter scene observed; production enemy projectile observed in the effects container. |
| PASS | Boss trigger | `TASK_13_BOSS_TRIGGER game=300.000 wall=299.887`; state changed to `BOSS` and Forge Guardian was present. |
| PASS | Boss defeat and victory | Automatic party combat defeated Forge Guardian; terminal state `VICTORY` (`4`) at wall `343.537s`. |
| PASS | Victory screenshot | [boss-victory.png](screenshots/boss-victory.png), 70,536 bytes. Visual inspection confirms a real `1280×720` viewport with `05:00`, party ranks, active traits, arena state, and centered `VICTORY` result. |

## Separate leader-defeat acceptance

| Status | Requirement | Recorded evidence |
| --- | --- | --- |
| PASS | Leader death result | A separate production main scene run applied lethal damage through `HealthComponent.take_damage`; terminal state became `DEFEAT` (`5`), the tree paused, and the result title was `DEFEAT`. |
| PASS | Terminal lock | Calling the public `GameRun.boss_defeated()` transition after leader death left terminal state at `DEFEAT` (`5`) and left the visible title unchanged. Victory could not overwrite defeat. |
| PASS | Defeat screenshot | [leader-defeat.png](screenshots/leader-defeat.png), 29,571 bytes. Visual inspection confirms a real `1280×720` viewport with the centered `DEFEAT` result and terminal controls. |

## Acceptance-driven fixes and balance contract

All binding Task 10 spawn bands remain exact: `0–59.999s: 1.25 / 100:0`, `60–149.999s: 0.9 / 80:20`, `150–239.999s: 0.65 / 65:35`, `240–299.999s: 0.45 / 55:45`, and no ordinary band at `>=300s`.

| Status | Change | Reason and regression evidence |
| --- | --- | --- |
| PASS | Runtime revive clock | Added `HealthComponent._process(delta)` delegating to the existing public `advance_time`. RED: runtime component lacked `_process`; GREEN: real companion down/revive observation plus 14-suite pass. |
| PASS | Fighter durability | Fighter `max_health 140→260`, `armor 6→10`, reflected in generated data and catalog contract. This reinforces the frontline identity; regular raw `8/10` hits resolve to the engine's minimum `1/1` after armor. RED was recorded first for the changed resource contract. |
| PASS | Regular-enemy durability | Swarmer `max_health 24→12`; Spitter `42→18`, with damage, speed, behavior, rewards, and all spawn timing/weights unchanged. Telemetry showed a 48-hostile backlog at the first exact boss trigger; the final eligible run reached the boss with 24 and automatic combat completed victory. RED was recorded first for both resource values. |

Earlier exploratory attempts that ended in leader defeat were rejected as acceptance evidence. One run made with a temporary altered spawn schedule was explicitly stopped and rejected; the binding schedule and exact boundary regressions were restored before the eligible successful run began from zero.
