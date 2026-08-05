# Upgrade Recipient Controller Scroll Report

## Scope

- Worktree: `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\plan-4b-item-ownership`
- Branch: `feat/plan-4b-item-ownership`
- Clean parent: `40a58cd6ba961ab8f5324033677f5007dc473a67`
- Fix only the controller/keyboard focus and scroll behavior of the existing upgrade recipient picker. Plan 4B Task 10 was not started.

## Root cause

`UpgradeRecipientPicker.show_for()` created every recipient `Button` without focus visibility callbacks or deterministic focus neighbors. Disabled buttons retained `FOCUS_ALL`, so Godot's automatic spatial navigation could focus an ineligible row. `RecipientsScroll.follow_focus` was also false, and no code called `ensure_control_visible()` when later rows received focus.

The complete CharacterLedger reference uses three complementary protections: `follow_focus`, immediate `ensure_control_visible()`, and a revision-guarded deferred visibility request for layout/rebuild safety. The picker was missing all three.

## Genuine RED evidence

The real-tree runner instantiates the production `LevelUpPanel` with 24 alternating Fighter/Marksman members. Deadeye makes the odd rows visible but disabled and the even rows eligible. It drives D-pad and controller south through `Input.parse_input_event()` at 1920x1080, 2560x1440, and 3840x2160.

Before production changes:

```text
UPGRADE_RECIPIENT_CONTROLLER_SCROLL_SUMMARY: FAIL (54 failures, 3 viewports)
```

At every target resolution, the first D-pad Down from eligible `Member_2` focused disabled `Member_3`. Navigation never reached `Member_24`; the scroll remained at its minimum; member 24 stayed clipped; and the expected back-link and stable member-24 selection could not succeed. The runner loaded and parsed normally, so this was a behavioral RED rather than a parser, loader, or fixture failure.

Focused unit RED then reported exactly seven behavior failures: disabled focus mode, five missing neighbor links, and `follow_focus = false`.

## Fix

- Keep every ineligible row rendered, disabled, and explanatory, but set it to `FOCUS_NONE` so directional navigation cannot enter it.
- Build explicit enabled-only top/bottom neighbors in party-row order.
- Link the last enabled row down to Back to Offers and Back up to the last enabled row.
- Enable native `ScrollContainer.follow_focus`.
- On enabled-row focus, call `ensure_control_visible()` immediately and through a deferred request so both settled and pending layouts are covered.
- Invalidate deferred requests whenever `show_for()` rebuilds the list. Deferred work carries a monotonic revision and resolves the current button by stable member ID only after the revision check, so a freed row or an old offer cannot scroll the replacement list.
- Reset a rebuilt list to the scrollbar's actual minimum rather than a hard-coded pixel offset.

No upgrade eligibility, presentation, application, confirmation, choice identity, or mouse activation code changed.

## GREEN and regression evidence

All commands used Godot 4.7.1 stable mono console with task-specific `APPDATA` and `LOCALAPPDATA` roots.

| Gate | Result |
| --- | --- |
| Focused unit pair: level-up targeting and responsive UI | Exit 0; `TEST_SUMMARY: PASS (0 failures)` |
| Real controller and keyboard runner at all three target resolutions (`--quit-after 600`) | Exit 0; `UPGRADE_RECIPIENT_CONTROLLER_SCROLL_SUMMARY: PASS (0 failures, 3 viewports)` |
| 11-suite level-up, responsive, controller, upgrade, tooltip, integration, and main-wiring batch | Exit 0; `TEST_SUMMARY: PASS (0 failures)` |
| Full editor import | Exit 0; no script, parse, or loader failure |
| Complete unit suite | Exit 0 in 71.4 seconds; `TEST_SUMMARY: PASS (130 suites)` |

The accepted GREEN outputs contain no `SCRIPT ERROR`, `Parse Error`, `No loader found`, or `TEST_FAILURE`. Expected negative-path diagnostics from upgrade application, profile, combat, and main-wiring tests remain present. The complete suite's shutdown diagnostics are unchanged from the clean-parent Task 9 baseline: one TextServer font RID, five CanvasItem RIDs, 32 ObjectDB instances, and five resources reported at exit in both runs.

The editor import regenerated untracked `.uid` sidecars for existing Task 9 scripts plus the new integration runner. Those verified generated artifacts were removed; no tracked or user-authored file was deleted.

## Acceptance demonstrated by the real runner

- All 24 rows are present at every target resolution and overflow is verified.
- Real D-pad input traverses every enabled recipient in exact party-row order and skips disabled rows.
- Focus and scroll reach member 24; the focused button is fully inside the scroll viewport and the vertical scroll value moves above its minimum.
- Real keyboard Up/Down returns from member 24 to member 2 and traverses back to a fully visible member 24 through the same neighbor and visibility path.
- Last recipient -> Back to Offers -> last recipient works in both directions.
- Controller south emits exactly member ID 24 and enters the existing confirmation view with pending member ID 24.
- An immediate 24-row rebuild cannot let the old focused row's deferred request steal focus or scroll the new offer away from its first recipient.

The accepted real-tree run reported `member=24 scroll=2826 max=3602 page=776` at each physical target resolution. A preceding expanded keyboard run with the old 180-frame cap was rejected because the engine's frame cap stopped it during the third viewport before the runner summary; raising only the harness cap to 600 produced the complete explicit PASS above.
