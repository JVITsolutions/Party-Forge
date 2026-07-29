# Party Forge Prototype Validation

## Result

**PASS — every required Task 13 validation entry is satisfied.** The qualifying gameplay paths use the production main scene at ordinary speed and preserve their drivers, raw logs, structured JSON, and inspected viewport frames in this repository.

## Provenance and automated checks

The production source under validation is exactly commit `89b40f72714195403b97077e72ffc876bed6e7ce`. The evidence correction consists only of validation drivers, logs, JSON, report text, and replacement screenshots; it does not change core production code.

| Status | Requirement | Recorded evidence |
| --- | --- | --- |
| PASS | Engine version | `4.7.1.stable.mono.official.a13da4feb` |
| PASS | Complete automated suite after source commit | `& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path 'F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\party-forge-prototype' --script res://tests/test_runner.gd` exited `0` with `TEST_SUMMARY: PASS (14 suites)`. Raw output: [full-suite.log](evidence/full-suite.log). |
| PASS | Parser/import check after source commit | `& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --editor --path 'F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\party-forge-prototype' --quit` exited `0`; the filesystem scan and editor initialization reached `DONE`. Raw output: [parser-import.log](evidence/parser-import.log). |
| PASS | Error scan | The final qualifying suite, parser/import, acceptance, and sandbox logs contain no `SCRIPT ERROR` or `ERROR:` line; both qualifying visible-run stderr files are zero bytes. |

## Preserved acceptance evidence

| Path | Purpose |
| --- | --- |
| [task_13_victory_acceptance.gd](../../tools/validation/task_13_victory_acceptance.gd) | Reproducible automated ordinary-speed victory driver. Uses only production UI button signals, mapped input actions, and read-only observations. It contains no direct damage call. |
| [victory-acceptance.log](evidence/victory-acceptance.log) / [victory-acceptance.json](evidence/victory-acceptance.json) | Raw stdout and structured result for the qualifying victory run. |
| [task_13_defeat_acceptance.gd](../../tools/validation/task_13_defeat_acceptance.gd) | Reproducible automated ordinary-speed natural-defeat driver. It contains no direct damage call. |
| [defeat-acceptance.log](evidence/defeat-acceptance.log) / [defeat-acceptance.json](evidence/defeat-acceptance.json) | Raw stdout and structured result for the qualifying defeat run. |
| [task_13_sandbox_smoke.gd](../../tools/validation/task_13_sandbox_smoke.gd) / [sandbox-smoke.log](evidence/sandbox-smoke.log) | Reproducible sandbox public-action smoke driver and raw output. |

## Automated ordinary-speed boss-victory acceptance

The qualifying driver launched `scenes/game/main.tscn` in a visible D3D12 viewport, asserted `GameRun.debug_time_scale == 1.0`, selected the leader and upgrades through production UI button signals, and moved the leader only through mapped input actions. It used an ordinary square route through game time 300, then mapped hover/approach/retreat movement during boss shockwaves. No driver code called a damage, health, movement, teleport, boss-defeat, or victory method. The boss died only from automatic production party combat.

| Status | Requirement | Recorded evidence |
| --- | --- | --- |
| PASS | Ordinary duration | Wall duration `344.003s`; unpaused production run time `300.000s`; `debug_time_scale: 1.0`; no acceleration argument. |
| PASS | Party composition and duplicate | `Fighter + Ranger + Fighter + Mage`, four members with duplicate Fighter. The viewport shows Fighter Rank 4, Ranger Rank 2, Fighter Rank 4, Mage Rank 2. |
| PASS | Overlapping traits | `ranged:2`, `vanguard:2`, and `martial:2` were simultaneously active. |
| PASS | Natural companion down | Production boss shockwaves reduced Ranger #2 from `90→69→48→27→6→0`; its `downed` signal fired at wall `332.896s`, game `300.000s`. The driver recorded the health transitions but never wrote health or invoked damage. |
| PASS | Automatic companion revive | The same Ranger #2 emitted `revived` at wall `340.897s`, game `300.000s`, with `45.0` health after the production eight-second revive clock. |
| PASS | Swarmer behavior | Production Swarmer scene observed pursuing with nonzero chase velocity. |
| PASS | Spitter behavior | Production Spitter scene and production enemy projectile both observed. |
| PASS | Boss trigger | `TASK_13_BOSS_TRIGGER game=300.000 wall=299.898`; terminal-time progression stopped at exactly `300.000s`. |
| PASS | Automatic boss defeat and victory | Automatic party attacks defeated Forge Guardian; terminal state `VICTORY` (`4`) at wall `344.003s`. |
| PASS | Victory screenshot | [boss-victory.png](screenshots/boss-victory.png), 69,119 bytes. Visual inspection confirms a real `1280×720` viewport with `05:00`, the qualifying ranks/traits, arena state, and centered `VICTORY` panel. |

## Separate automated natural-defeat acceptance

This qualifying path launched a fresh production main scene at `debug_time_scale == 1.0`, selected Mage through the production class-selection button, released mapped movement, and allowed ordinary spawned enemies to kill the leader. It did not call `take_damage`, `receive_damage`, or any equivalent method.

| Status | Requirement | Recorded evidence |
| --- | --- | --- |
| PASS | Natural leader defeat | Production enemies reduced the Mage leader to `0.0` health and `is_dead: true` at wall `75.296s`, game `75.402s`; state became `DEFEAT` (`5`) and the tree paused. |
| PASS | Result UI | The visible result panel title was `DEFEAT`. |
| PASS | Terminal lock | Only after natural `DEFEAT`, the driver called public `GameRun.boss_defeated()` as a terminal-lock probe. State remained `DEFEAT` (`5`), the tree remained paused, and the title remained `DEFEAT`. |
| PASS | Defeat screenshot | [leader-defeat.png](screenshots/leader-defeat.png), 52,475 bytes. Visual inspection confirms a real `1280×720` viewport at `01:15` with the centered `DEFEAT` panel and terminal controls. |

## Developer sandbox

The exact smoke command reproducible from a fresh checkout is:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path 'F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\party-forge-prototype' --script res://tools/validation/task_13_sandbox_smoke.gd
```

It exited `0` with `TASK_13_SANDBOX_SMOKE: PASS party=4 active_tiers=2`. The smoke verifies the explicit class actions, production Swarmer/Spitter/boss spawning, the sandbox-only selected-companion tuning action, hostile cleanup, active trait display, and four-member cap. The sandbox tuning action intentionally exercises its public down control; it is not part of either qualifying acceptance path.

## Production contract retained at the source commit

The validated source retains the exact binding spawn bands: `0–59.999s: 1.25 / 100:0`, `60–149.999s: 0.9 / 80:20`, `150–239.999s: 0.65 / 65:35`, `240–299.999s: 0.45 / 55:45`, and no ordinary band at `>=300s`.

It also retains the accepted runtime revive clock (`HealthComponent._process(delta)` delegates to `advance_time`), Fighter durability (`260` health, `10` armor), Swarmer health `12`, and Spitter health `18`. The post-source 14-suite run covers those resource and boundary contracts.
