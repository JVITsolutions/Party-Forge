# Warehouse Presentation Activation Verification

## Scope and exact commit

This record qualifies exact implementation commit
`38e136e86f515181057f276415de3feb844c709c` (`test: strengthen Warehouse
activation proof`). Every test, integration, rollback, hash, visual, and
repository-boundary check below ran while `HEAD` was exactly that commit and
tracked status was clean. The commit containing this record is a
documentation-only direct child of `38e136e`; it does not alter the tested
implementation.

The approved engine was
`F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe`.
The worktree already had a valid `.godot` import cache, the exact focused run
loaded the project successfully, and no untracked `.gd.uid` files existed, so
a cold import was not required. No cache was cleaned.

Only `city.warehouse` is active. `WarehouseAccessPolicy` remains the
authoritative access decision. The other six City locations --
`city.apothecary`, `city.coliseum_road`, `city.inn`, `city.merchant`,
`city.scholars_archive`, and `city.smithy` -- are inert: they are not evaluated
or dispatched by the Warehouse presentation consumer.

## Default-off and staged-state evidence

The exact focused gate replayed the four required states through the production
Main/menu refresh and route paths in one Godot process:

| State | Fresh result |
|---|---|
| Developer Mode, candidate flag on, no `stash` | One Warehouse shadow observation was emitted; Developer preview kept both Warehouse origins visible and enabled; active profile data stayed unchanged. |
| Player Mode, candidate flag on, no `stash` | Refresh changed the presentation to visible `LOCKED`; activating either origin opened the locked guidance dialog while the storage screen stayed closed. |
| Player Mode, candidate flag off, no `stash` | Refresh restored legacy `HIDDEN` presentation without a candidate load. Restoring the flag immediately returned `LOCKED`. |
| Player Mode, either candidate flag state, `stash` present | The legacy flag-off resolver and the candidate flag-on resolver both returned `AVAILABLE`; fresh production authorization opened only the Warehouse screen. |

These transitions required no process restart, snapshot regeneration, cache
cleanup, or settings-profile coupling. Refresh did not mutate the profile. The
`stash` case used an explicit, isolated fixture allocation as the staged input;
the production refresh then reloaded that exact durable state rather than
creating or changing authority itself. Default-off rollback works without
restart, regeneration, or profile mutation.

## Focused tests

The exact 16-suite command named in the implementation plan ran after the clean
baseline and exited `0` with terminal
`TEST_SUMMARY: PASS (0 failures)`. The persistent ignored log is
`.superpowers/warehouse-activation-focused.log`.

The batch included the atomic profile store, `WarehouseAccessPolicy`, strict
JSON reader, snapshot loader/provider/evaluator/shadow comparator, Warehouse
presentation resolver/reporter, settings, menu view/model/screen, locked dialog,
production Main wiring, and retained passive-tree loader suites. Its Main wiring
coverage supplied the in-process four-state replay above.

## City access and navigation integration

All three Task 5 runners were rerun after the fresh full suite on the exact
implementation tip; each had numeric exit `0`:

| Runner | Exact terminal evidence |
|---|---|
| `city_access_snapshot_runner.gd` | `WAREHOUSE_PRESENTATION_ACTIVATION_OK location=city.warehouse rollback=legacy authority=warehouse_policy` and `CITY_ACCESS_SNAPSHOT_ACCEPTANCE_OK locations=7 profiles=7 rollback=legacy` |
| `main_menu_navigation_runner.gd` | `MAIN_MENU_NAVIGATION_SUMMARY: PASS` |
| `main_menu_responsive_runner.gd` | `MAIN_MENU_RESPONSIVE_SUMMARY: PASS (3 root-window sizes)` |

The City runner observed the production evaluator receiving exactly
`city.warehouse`, and the only available destination it exposed was
`city.warehouse.interior`. The composed route observer recorded exactly the two
Warehouse attempts (locked and authorized), and only the authorized attempt
opened `WarehouseScreen`. No other City location or destination was evaluated
or dispatched.

The navigation runner exercised keyboard and controller activation from both
locked origins, modal focus trapping, Back focus restoration, the existing City
tree CTA, and return to the exact Warehouse origin. Its only durable fixture
change was the explicit `stash` allocation. Before the production close refresh
and after it, the expected document and `ProfileCodec` bytes were exact; the
active and durable post-refresh bytes matched.

## Responsive visual/input evidence

The direct headless responsive runner revalidated all six ignored real-pixel
artifacts at 1920x1080, 2560x1440, and 3840x2160. It emitted one
`MAIN_MENU_RESPONSIVE_SIZE_PASS` per size and the exact three-size terminal PASS
marker. The six retained PNGs were also reopened for this qualification. Menus
and dialogs were nonblank and preserved the approved hierarchy, exact locked
copy, distinct non-overlapping `LOCKED` badges, contained actions, readable
text, and deterministic primary focus at all three sizes.

The 1920x1080 accessibility pass reapplied the existing high-contrast and
reduced-motion settings and required at least 7:1 resolved-style contrast for
the title, body, and primary action. The fresh runner passed those direct style,
layout, focus, saved-settings, and profile-byte assertions. Screenshots and logs
remain ignored and unstaged.

## Full-suite result and prohibited-marker scan

The complete unit runner was executed fresh with `--quit-after 1200` on
`38e136e`. It exited `0` and its terminal line was exactly
`TEST_SUMMARY: PASS (241 suites)`. This is the suite count discovered by this
run, not a copied prior result.

A case-sensitive scan of the complete persistent log for
`TEST_SUMMARY: FAIL`, `TEST_FAILURE`, `SCRIPT ERROR`, `Parse Error`,
`Failed loading resource`, and `No loader found` returned `0` matches. The
ignored log is `.superpowers/warehouse-activation-full.log`.

## Authoring, runtime, and snapshot SHA-256

Exact byte counts, SHA-256 values, and Git blob IDs matched before and after all
qualification commands:

| Role and checked-in path | Bytes | SHA-256 | Git blob |
|---|---:|---|---|
| Authoring: `design/progression/latticewright/party-forge-city-access.pstree` | 11,055 | `49e990eb09720a5cbd590f3bcdc8d732b3b578aa8a61c77a11d7ed118409f10a` | `c5909bdc132f2ec52028f6b3a1d0b39c517aa8b1` |
| Runtime-v3: `design/progression/latticewright/party-forge-city-access.pstree.json` | 9,972 | `bb3abd94d6b86716d3c39840deef460e20596abb858ba6abd4535067d664ff78` | `955ee8d6afd8800f8a4ea3b32dfe6fd6fc700ee6` |
| Party Forge snapshot: `data/world/access/party-forge-city-access.snapshot.json` | 2,539 | `ca046f55eaaf28ff050c6d7ab240232d5663820d88c1551160a7a2c4476b6a55` | `6299dc673be6ba7c4f225a41cf44bfce2a9e74e7` |

The Task 6 command snippet named a nonexistent
`design/progression/latticewright/runtime-v3/party-forge-city-access.runtime.json`.
The live approved contract, importer, generated-artifact tests, and retained
verification records consistently identify the checked-in runtime-v3 file as
`party-forge-city-access.pstree.json`; the table therefore captures the three
real authoring/runtime/snapshot artifacts required by the task. Nothing was
regenerated or rewritten.

## Mutation and repository-boundary checks

Before this document was created, Party Forge was clean at exact
`38e136e86f515181057f276415de3feb844c709c`. `git diff --check` exited `0`,
and the before/after artifact byte evidence above matched. No untracked
`.gd.uid` sidecars appeared, so none required removal.

The read-only Latticewright boundary repository
`E:\Projects\Passive Skill Tree Creator` was clean on `main` at
`26098c0da6fa5c60597fc414cd2b4db79d0b1114` both before and after execution.
No Latticewright files changed, and Task 6 created no state there. No production
file, snapshot, runtime export, authoring file, screenshot, or log was staged.
Nothing was pushed or published.

## Operational rollback replay

The operational replay changed the in-memory/persisted test settings and called
the production projection refresh without restarting the process:

1. Developer Mode plus flag-on produced shadow evidence and unrestricted
   Developer preview while preserving the no-`stash` profile.
2. Player Mode plus flag-on refreshed to visible `LOCKED`; production route
   authorization remained blocked and displayed guidance.
3. Player Mode plus flag-off refreshed immediately to legacy `HIDDEN`, with no
   candidate load or regeneration.
4. Restoring flag-on returned `LOCKED`; refreshing an explicitly pre-authorized
   `stash` fixture returned `AVAILABLE` and opened Warehouse. The flag-off legacy
   resolver also retained `AVAILABLE` for the same authority.

`WarehouseAccessPolicy` decided whether the route could open in every Player
Mode state. Presentation never granted authority. The replay required no
restart, importer run, artifact regeneration, cache cleanup, or profile
mutation by the refresh path.

## Remaining activation boundary

Only `city.warehouse` is activated for Player-mode presentation. The other six
City locations remain inert, and arbitrary snapshot destinations remain
fail-closed. Gameplay consumes only the checked-in Party Forge snapshot;
Latticewright authoring/runtime files remain a replaceable, explicit import
edge and are not read by this presentation path.

This documentation-only commit records qualification; it does not merge,
push, publish, change the default setting, regenerate data, activate another
location, or authorize a release. Default-off rollback remains available
without restart, regeneration, or profile mutation. Any merge, push,
publication, additional City activation, or default-setting change remains a
separate user approval boundary.
