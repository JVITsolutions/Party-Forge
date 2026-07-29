# Party Forge Prototype Validation

## Result

**PASS - every required Task 13 validation entry is satisfied.** The qualifying gameplay paths use the production main scene at ordinary speed and preserve their drivers, raw logs, structured JSON, and inspected viewport frames in this repository.

## Provenance and automated checks

The production source under validation is exactly commit `66fd17aeaedb782ec491607035e07ce5ae974c14`. The evidence commit contains only validation drivers, logs, JSON, report text, and replacement screenshots; it does not change production behavior.

| Status | Requirement | Recorded evidence |
| --- | --- | --- |
| PASS | Engine version | `4.7.1.stable.mono.official.a13da4feb` |
| PASS | Complete automated suite after source commit | The headless test runner exited `0` with `TEST_SUMMARY: PASS (15 suites)`. Raw output: [full-suite.log](evidence/full-suite.log). |
| PASS | Parser/import check after source commit | The headless editor initialization exited `0`; filesystem scan, class registration, import, and editor layout all reached `DONE`. Raw output: [parser-import.log](evidence/parser-import.log). |
| PASS | Acceptance-driver parser check | Both preserved drivers exited `0` in parse-only mode. Raw output: [acceptance-driver-parser.log](evidence/acceptance-driver-parser.log). |
| PASS | Sandbox smoke | The public-action sandbox driver exited `0` with `TASK_13_SANDBOX_SMOKE: PASS party=4 active_tiers=2`. Raw output: [sandbox-smoke.log](evidence/sandbox-smoke.log). |
| PASS | Error scan | The final suite, parser/import, driver-parser, sandbox, victory, defeat, and visible-run stderr logs contain no `SCRIPT ERROR` or `ERROR:` line. Both visible-run stderr files are zero bytes. |

## Preserved acceptance evidence

| Path | Purpose |
| --- | --- |
| [task_13_victory_acceptance.gd](../../tools/validation/task_13_victory_acceptance.gd) | Reproducible automated ordinary-speed victory driver using production UI button signals, mapped input actions, and read-only observations. It contains no direct damage or state write. |
| [victory-acceptance.log](evidence/victory-acceptance.log) / [victory-acceptance.json](evidence/victory-acceptance.json) | Raw stdout and structured result for the qualifying victory run. |
| [task_13_defeat_acceptance.gd](../../tools/validation/task_13_defeat_acceptance.gd) | Reproducible automated ordinary-speed natural-defeat driver. It contains no direct damage call. |
| [defeat-acceptance.log](evidence/defeat-acceptance.log) / [defeat-acceptance.json](evidence/defeat-acceptance.json) | Raw stdout and structured result for the qualifying defeat run. |
| [task_13_sandbox_smoke.gd](../../tools/validation/task_13_sandbox_smoke.gd) / [sandbox-smoke.log](evidence/sandbox-smoke.log) | Reproducible sandbox public-action smoke driver and raw output. |

## Automated ordinary-speed boss-victory acceptance

The qualifying driver launched `scenes/game/main.tscn` in a visible D3D12 viewport, asserted `GameRun.debug_time_scale == 1.0`, selected the leader and upgrades through production UI button signals, and moved the leader only through mapped input actions. It used ordinary square movement through game time 300, then a simple boss hover, shockwave approach, and retreat route. After observing a natural down it fled the boss until the production revive occurred. No driver code called a damage, health, teleport, boss-defeat, or victory method. The boss died only from automatic production party combat.

| Status | Requirement | Recorded evidence |
| --- | --- | --- |
| PASS | Ordinary duration | Wall duration `367.603s`; unpaused production run time `300.000s`; `debug_time_scale: 1.0`; no acceleration argument. |
| PASS | Party composition and duplicate | `Fighter + Ranger + Ranger + Mage`, four members with duplicate Ranger. The viewport shows Fighter Rank 3, Ranger Rank 1, Ranger Rank 1, and Mage Rank 1. |
| PASS | Overlapping traits | `martial:2` and `ranged:2` were simultaneously active. |
| PASS | Natural companion downs | Ranger #2 and Mage #4 emitted `downed` at walls `340.399s` and `340.401s`; Ranger #3 emitted `downed` at `355.399s`. All health loss is recorded in JSON and came from production enemies. |
| PASS | Same-member automatic revive | Ranger #2 and Mage #4 emitted `revived` at walls `348.399s` and `348.401s`, exactly eight seconds after their downs, with `47.25` and `39.375` health. Ranger #3 also revived at `363.400s`. |
| PASS | Swarmer behavior | Production Swarmer scene observed pursuing with nonzero chase velocity. |
| PASS | Spitter behavior | Production Spitter scene and production enemy projectile both observed. |
| PASS | Boss trigger and actions | `TASK_13_BOSS_TRIGGER game=300.000 wall=299.904`; terminal-time progression stopped at exactly `300.000s`; seven boss shockwaves were observed. |
| PASS | Automatic boss defeat and victory | Automatic party attacks defeated Forge Guardian; terminal state `VICTORY` (`4`) at wall `367.603s`. |
| PASS | Victory screenshot | [boss-victory.png](screenshots/boss-victory.png), 51,608 bytes. Visual inspection confirms a real `1280x720` viewport with `05:00`, the qualifying roster and traits, arena state, and centered `VICTORY` panel. |

## Separate automated natural-defeat acceptance

This qualifying path launched a fresh production main scene at `debug_time_scale == 1.0`, selected Mage through the production class-selection button, released mapped movement, and allowed ordinary spawned enemies to kill the leader. It did not call `take_damage`, `receive_damage`, or any equivalent method.

| Status | Requirement | Recorded evidence |
| --- | --- | --- |
| PASS | Natural leader defeat | Production enemies reduced the Mage leader to `0.0` health and `is_dead: true` at wall `74.948s`, game `75.064s`; state became `DEFEAT` (`5`) and the tree paused. |
| PASS | Result UI | The visible result panel title was `DEFEAT`. |
| PASS | Terminal lock | Only after natural `DEFEAT`, the driver called public `GameRun.boss_defeated()` as a terminal-lock probe. State remained `DEFEAT` (`5`), the tree remained paused, and the title remained `DEFEAT`. |
| PASS | Defeat screenshot | [leader-defeat.png](screenshots/leader-defeat.png), 54,120 bytes. Visual inspection confirms a real `1280x720` viewport at `01:15` with the centered `DEFEAT` panel and terminal controls. |

## Developer sandbox

The reproducible smoke command is:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path 'F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\party-forge-prototype' --script res://tools/validation/task_13_sandbox_smoke.gd
```

It exited `0` with `TASK_13_SANDBOX_SMOKE: PASS party=4 active_tiers=2`. The smoke verifies explicit class actions, production Swarmer/Spitter/boss spawning, the sandbox-only selected-companion tuning action, hostile cleanup, active trait display, and the four-member cap. The sandbox tuning action intentionally exercises its public down control; it is not part of either qualifying acceptance path.

## Production contract retained at the source commit

The validated source retains the exact ordinary spawn bands: `0-59.999s: 1.25 / 100:0`, `60-149.999s: 0.9 / 80:20`, `150-239.999s: 0.65 / 65:35`, `240-299.999s: 0.45 / 55:45`, and no ordinary band at `>=300s`.

It also retains the data-defined eight-second revive clock, Fighter durability (`260` health, `10` armor), Swarmer health `12`, Spitter health `18`, and Forge Guardian health `3000`. Boss damage, action timings, and spawn bands were not changed by the balance correction. The post-source 15-suite run covers these resource and boundary contracts.
