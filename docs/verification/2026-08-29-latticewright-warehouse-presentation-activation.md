# Warehouse Presentation Activation Verification

## Scope and exact commit

This record qualifies exact implementation commit
`ba477f25d32c796abe9e6e54bb0c68167d409f17` (`fix: close Warehouse
activation review findings`). Every test, integration, rollback, hash, visual, and
repository-boundary check below ran while `HEAD` was exactly that commit and
tracked status was clean. The commit containing this record is a
documentation-only direct child of `ba477f25`; it does not alter the tested
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

The final whole-branch review's three Important findings are closed at this
exact implementation commit:

- The resolver validates the exact `city.warehouse` snapshot record and exact
  `city.warehouse.interior` destination before evaluation can erase a
  non-available destination. Wrong destinations in candidate `HIDDEN`,
  `LOCKED`, and `AVAILABLE` states return the authoritative legacy
  presentation with sanitized `candidate_destination_invalid` evidence.
- The locked dialog explicitly contains left, up, right, down, next, and
  previous focus traversal for both two-control and Back-only guidance. Real
  root-viewport keyboard-arrow and controller-D-pad actions cannot focus or
  activate the Main Menu underneath it.
- Responsive evidence is bound to a clean exact Git tip by an ignored manifest
  containing exact commit, path, dimensions, and SHA-256 for all six PNGs.
  Windowed OpenGL generation overwrites every capture and publishes the
  manifest only after all existing direct assertions succeed; headless mode
  rejects missing, stale-tip, wrong-dimension, or wrong-hash evidence.

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

All three Task 5 runners and the mounted dialog-focus runner were rerun after
the fresh full suite on the exact implementation tip; each had numeric exit
`0`:

| Runner | Exact terminal evidence |
|---|---|
| `city_access_snapshot_runner.gd` | `WAREHOUSE_PRESENTATION_ACTIVATION_OK location=city.warehouse rollback=legacy authority=warehouse_policy` and `CITY_ACCESS_SNAPSHOT_ACCEPTANCE_OK locations=7 profiles=7 rollback=legacy` |
| `main_menu_navigation_runner.gd` | `MAIN_MENU_NAVIGATION_SUMMARY: PASS` |
| `main_menu_responsive_runner.gd` | `MAIN_MENU_RESPONSIVE_MANIFEST_OK implementation_commit=ba477f25d32c796abe9e6e54bb0c68167d409f17 captures=6` and `MAIN_MENU_RESPONSIVE_SUMMARY: PASS (3 root-window sizes)` |
| `warehouse_locked_dialog_focus_runner.gd` | `WAREHOUSE_LOCKED_DIALOG_FOCUS_SUMMARY: PASS (0 failures)` |

The City runner observed the production evaluator receiving exactly
`city.warehouse`, and the only available destination it exposed was
`city.warehouse.interior`. The composed route observer recorded exactly the two
Warehouse attempts (locked and authorized), and only the authorized attempt
opened `WarehouseScreen`. No other City location or destination was evaluated
or dispatched.

The invalid-candidate acceptance matrix also supplied wrong-destination
snapshots whose Warehouse projections would otherwise be `HIDDEN`, `LOCKED`,
and `AVAILABLE`. Every case returned its authoritative legacy state with
`CANDIDATE_FAILED` and sanitized `candidate_destination_invalid`; candidate
state and destination were never dispatched.

The navigation runner exercised keyboard and controller activation from both
locked origins, modal focus trapping, Back focus restoration, the existing City
tree CTA, and return to the exact Warehouse origin. Its only durable fixture
change was the explicit `stash` allocation. Before the production close refresh
and after it, the expected document and `ProfileCodec` bytes were exact; the
active and durable post-refresh bytes matched.

On the real root viewport, both the two-action and Back-only dialog states
received all four keyboard arrows and all four controller D-pad actions. Focus
remained on a visible, enabled control under `WarehouseLockedDialog`, no
underlying Main Menu route signal was emitted, and `WarehouseScreen` remained
closed. Tab, `ui_cancel`, Back, CTA, and exact origin restoration remained
green. The separate mounted-focus runner independently retained deterministic
initial focus, cancel/Back restoration, and CTA-origin handoff.

## Responsive visual/input evidence

On the clean exact implementation tip, the approved console executable ran the
responsive generator without `--headless` and with
`--rendering-method gl_compatibility`. The renderer identified OpenGL 3.3
Compatibility on NVIDIA GeForce RTX 4070 Ti SUPER. The runner removed the old
manifest and all six old captures, overwrote every 1920x1080, 2560x1440, and
3840x2160 menu/dialog PNG, and published the manifest only after all generation
and accessibility assertions passed. Windowed generation exited `0`, emitted
one `MAIN_MENU_RESPONSIVE_SIZE_PASS` per size, emitted the exact-tip manifest
marker, and ended with the exact three-size PASS.

The ignored manifest has schema
`party-forge-main-menu-responsive-evidence`, version `1`, implementation commit
`ba477f25d32c796abe9e6e54bb0c68167d409f17`, and exactly six entries containing
only `path`, `width`, `height`, and `sha256`. Its own SHA-256 is
`cef9609452d0da0db807d604421c54c24ff3b6307b6d60ed9b67fe1a8445595f`.

| Ignored capture | Dimensions | SHA-256 |
|---|---:|---|
| `locked-menu-1920x1080.png` | 1920x1080 | `6c51a259061275421effa8b891537b1d0fbf1f70c6cb7ab3915263e51b498731` |
| `locked-dialog-1920x1080.png` | 1920x1080 | `ff975b0985680af4d39c8a3c0d58ab729b46802e52e4c39803de34163a94f697` |
| `locked-menu-2560x1440.png` | 2560x1440 | `09dc52609f1574c5e98b8cc1a723f5b62062f668caa0fdd0d099fee1349a48b8` |
| `locked-dialog-2560x1440.png` | 2560x1440 | `d7b1fd3834887bbdfe80de042bcd570d598ee3ec1d04162dad216c8cb8125968` |
| `locked-menu-3840x2160.png` | 3840x2160 | `cf526f1a6b48f09fc0159d1666c38b5440ebe66f0aabcec3b4ff2f09d81c8813` |
| `locked-dialog-3840x2160.png` | 3840x2160 | `b03ee0638bb40bc1e8b72dca9ce4bd7ab486cffc8c7d08196bee20e9826d2d5f` |

Direct headless validation then reopened the manifest and all six PNGs on the
same exact implementation tip. It exited `0` only after matching current commit,
exact paths, dimensions, and file SHA-256 values, while retaining the direct
nonblank, layout, exact-copy, badge-separation, focus, settings, and profile-byte
assertions. A stale manifest from the immediately preceding implementation tip
was deliberately presented once and failed closed on the commit mismatch.

The 1920x1080 accessibility pass reapplied the existing high-contrast and
reduced-motion settings and required at least 7:1 resolved-style contrast for
the title, body, and primary action. Screenshots, manifest, and logs remain
ignored and unstaged.

## Full-suite result and prohibited-marker scan

The complete unit runner was executed fresh with `--quit-after 1200` on
`ba477f25`. It exited `0` and its terminal line was exactly
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
`ba477f25d32c796abe9e6e54bb0c68167d409f17`. `git diff --check` exited `0`,
and the before/after artifact byte evidence above matched. No untracked
`.gd.uid` sidecars appeared, so none required removal.

The read-only Latticewright boundary repository
`E:\Projects\Passive Skill Tree Creator` was clean on `main` at
`26098c0da6fa5c60597fc414cd2b4db79d0b1114` both before and after execution.
No Latticewright files changed, and Task 6 created no state there. No production
file, snapshot, runtime export, authoring file, screenshot, manifest, or log was staged.
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
