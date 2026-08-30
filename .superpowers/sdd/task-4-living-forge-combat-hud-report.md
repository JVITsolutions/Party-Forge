# Task 4 — Living Forge Combat HUD Report

## Revision and scope

- Required base and pre-commit HEAD under test: `9bd26e84c659b85395d811be2f2173231947a345`.
- Branch: `feat/living-forge-combat-loop-ui`.
- Scope: replace the fixed four-label combat HUD with the Living Forge responsive shell; add the complete alert tray and read-only member inspector; add exact-member Ledger routing; add `PlayerRunContext.actor_bound`; wire safe Main routes; migrate the progression smoke path; add Task 4 focused, scale/geometry, and real-input coverage.
- Excluded: Task 5+, tactics/gambit data or controls, unsupported objectives, visual-evidence capture, push, merge, and aesthetic acceptance.

## RED evidence

All production changes were withheld until the four prescribed RED commands had run.

1. `godot --headless --path <worktree> --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_combat_hud.gd tests/unit/test_main_wiring.gd tests/unit/test_party_manager.gd`
   - Marker: `TEST_SUMMARY: FAIL (30 failures)`
   - Exit: `1`
   - Failures identified the absent responsive HUD/routes, fixed `Party1..Party4` nodes, and missing five-argument composition.
2. `godot --headless --path <worktree> --quit-after 600 --script res://tests/integration/combat_hud_party_scale_runner.gd`
   - Marker: `COMBAT_HUD_PARTY_SCALE_SUMMARY: FAIL failures=1`
   - Windows process exit: `-1073741819` after the expected marker, reproduced three times in the pre-implementation missing-route branch.
3. `godot --headless --path <worktree> --quit-after 600 --script res://tests/integration/combat_hud_input_runner.gd`
   - Marker: `COMBAT_HUD_INPUT_SUMMARY: FAIL failures=1`
   - Exit: `1`
4. `godot --headless --path <worktree> --quit-after 900 --script res://tests/integration/progression_arena_smoke_runner.gd`
   - The first observation exposed an obsolete pre-run profile snapshot boundary in the new test. The test was corrected before production work to compare the authoritative post-checkout profile.
   - Corrected RED marker: `PROGRESSION_ARENA_PROFILE_IMMUTABLE ... values_equal=true bytes_equal=true`, then `PROGRESSION_ARENA_SMOKE_SUMMARY: FAIL failures=1`.
   - Exit: `1`; the only remaining failure was the missing new XP path.

## Implementation result

- `HUD.configure` now takes the five runtime authorities, enumerates already-bound party actors, subscribes to future `actor_bound`, and disconnects replaced health signals.
- Timer work remains per-frame, while party structure/control construction is signal/revision driven. Health changes re-present the existing card or marker instance.
- Parties 1–6 use a full leader anchor and rich follower controls; a solo party shows `No followers`. Parties 7–24 use bounded compact pages containing every party member, including the marked leader. The leader anchor is excluded from `combat_hud_member`; compact markers retain the Task 3 `280x84` basis.
- The supported alert surface diffs the first three alerts by stable ID and shows exact `+N alerts` overflow. The tray receives the complete ordered `all_alerts` projection and initially focuses the first non-expanded alert.
- The alert tray and inspector each own a `RunPauseLease`. Ledger `open_for_member` uses the Ledger's existing lease, exact member/page selection, and initiating-focus restoration. Closing any child preserves other pause owners.
- Inspector data is read-only. Main validates a member immediately before opening the inspector or Ledger and reports `That party member is no longer available.` when the route has gone stale.
- Boss decoration is hidden as a whole when unsupported/absent. Timer, XP, boss banner/health, loot status, and resolved-alert status remain supported. No objective, traits, tactics, or gambit surface was invented.

## GREEN evidence

Fresh final Task 4 gates:

- Focused Task 4 command: `TEST_SUMMARY: PASS (0 failures)`; exit `0`.
- Party scale/real geometry: `COMBAT_HUD_PARTY_SCALE_SUMMARY: PASS`; exit `0`.
- Keyboard/controller/mouse/cancel: `COMBAT_HUD_INPUT_SUMMARY: PASS`; exit `0`.
- Progression retention: `PROGRESSION_ARENA_PROFILE_IMMUTABLE ... values_equal=true bytes_equal=true`, `PROGRESSION_ARENA_SMOKE_SUMMARY: PASS`; exit `0`.

Retained coverage:

- Combined Task 1–4 focused suites, including projection, responsive policy, view model, Task 3 components, Task 4 HUD/Main/party, and Ledger shell/foundation: `TEST_SUMMARY: PASS (0 failures)`; exit `0`.
- `responsive_ui_geometry_runner.gd`: four `RESPONSIVE_GEOMETRY_SIZE_PASS` markers and `RESPONSIVE_GEOMETRY_SUMMARY: PASS (4 sizes)`; exit `0`.

The party-scale runner asserts actual post-layout rectangles at `1920x1080` and `1280x720` for six-member rich and twenty-four-member final-page compact states, three alerts plus overflow, boss hidden/shown, banner, loot, and 150% representative text. It also asserts viewport containment, non-collision, 48px actions, leader non-duplication, every final member reachable, and exact compact geometry.

A final modal-boundary assertion was added before changing the tray layout. It RED-proved the old fixed-height frame at `[P: (640, -140), S: (608, 1000)]` in `1280x720` (`COMBAT_HUD_PARTY_SCALE_SUMMARY: FAIL failures=2`, exit `1`). The tray now uses 32px top/bottom viewport margins; the same real-rectangle assertion passes at both supported viewports.

The input runner exercises explicit spatial neighbors, deterministic paging, no focus theft on health/alert refresh, keyboard Inspect/cancel, controller Ledger, mouse Inspect/overflow, full-tray focus, stable-alert fallback, complete resolution fallback, and nested pause ownership. Its initial mouse failure was traced to the fixture leaving the full-screen `ClassSelection` panel open; closing it through the production panel lifecycle made the real pointer routes pass without production mouse special cases.

## UID import classification

The checked-in `Resolve-GeneratedUidState` classifier was redeclared in the same PowerShell process as each final import. Final import exit: `0`; classifier exit: `0`. The exact intended untracked UID set was:

- `scripts/ui/hud/combat_alert_tray.gd.uid`
- `scripts/ui/hud/combat_member_inspect_panel.gd.uid`
- `tests/unit/test_combat_hud.gd.uid`
- `tests/integration/combat_hud_party_scale_runner.gd.uid`
- `tests/integration/combat_hud_input_runner.gd.uid`

Only classifier-validated unrelated generated sidecars, each belonging to an already tracked script, were removed. No unexpected UID remained.

## Diagnostics and integrity

- Final focused, party-scale, input, progression, and responsive runs emitted their exact PASS markers and exited `0`.
- Final Task 4 party-scale and input runners emitted no `SCRIPT ERROR`, parse/load error, ObjectDB leak, RID leak, retained-resource, or paged-allocator diagnostics. The pre-implementation party-scale crash did not recur on the final green runner.
- The broad focused suites retain intentional negative-path `push_error` evidence owned by existing Main and PartyManager tests. The retained responsive runner also emits its established settings-save negative-path diagnostics while still producing the exact PASS marker and exit `0`.
- `git diff --check` passed.
- The historical report was not edited. Worktree hash and base blob for `.superpowers/sdd/task-4-report.md` both equal `828fd5fab931aa8ef350de041e0f26dcfa147096`.
- No production test-only method was added. The HUD has one `_process`, limited to timer and transient-duration presentation; party projection/control refresh is signal driven.

## Assumptions and deviations

- The approved responsive policy allows a seven-member party to fit on one compact page at `1920x1080`; the real paging input fixture therefore uses twelve members so Next/Previous are genuinely enabled.
- A synchronous focused runner executes before nodes enter the live SceneTree. Unit traversal verifies descendant group metadata/control identity directly; the awaited integrations are authoritative for live SceneTree group registration and focus/input behavior.
- The boss banner uses clipping to keep its actual Label rectangle centered and noncolliding at `1280x720`; this was based on measured post-layout rectangles, not nominal offsets.
- This report does not claim Task 14 aesthetic acceptance or replace retained foundation evidence.

## Review repair — modal parity, stable focus, geometry, and fail-closed status

### Revision and bounded scope

- Required repair base and pre-commit HEAD under test: `adcc4f2210990d04b9e37a40f40a90d41a41bc7a` (`feat: replace the fixed combat HUD`). The repair result HEAD is the commit containing this report.
- Repair scope is limited to Task 4 HUD/tray/inspector/Ledger/Main behavior, matching focused and integration tests, and this durable report. No Task 5+, tactics, objective, push, merge, plan, or progress-ledger work was performed.
- The historical `.superpowers/sdd/task-4-report.md` remained untouched. Its worktree blob and the required base blob are both `828fd5fab931aa8ef350de041e0f26dcfa147096`.

### Repair RED evidence

Production remained unchanged until these review assertions had run:

1. `godot --headless --path <worktree> --quit-after 600 --script res://tests/focused_test_runner.gd -- tests/unit/test_combat_hud.gd`
   - Marker: `TEST_SUMMARY: FAIL (6 failures)`.
   - Exit: `1`.
   - Exact gaps: absent `HudUnavailable`, no visible reasons for party-context mismatch, invalid identity, or missing health, plus incorrect `+1 alerts` visible and accessibility copy.
2. `godot --headless --path <worktree> --quit-after 600 --script res://tests/integration/combat_hud_party_scale_runner.gd`
   - Marker: `COMBAT_HUD_PARTY_SCALE_SUMMARY: FAIL failures=33`.
   - Exit: `1`.
   - Exact gaps: post-layout alert child/action containment, missing tray/inspector resolved-theme propagation, and the explicit `1280x720` rich battlefield opening (`actual=72.0`, required at least `160.0`).
3. `godot --headless --path <worktree> --quit-after 600 --script res://tests/integration/combat_hud_input_runner.gd`
   - Marker: `COMBAT_HUD_INPUT_SUMMARY: FAIL failures=4`.
   - Exit: `1`.
   - Exact gaps: inert initial tray root focus, controller activation from initial focus, stable child-close fallback after alert removal, and named all-resolved fallback.

The actor-rebind old/new signal assertion and real Main route assertion were added as authentic retained coverage; they already exercised supported production seams rather than serving as artificial RED failures.

### Implemented review repairs

- The same `LivingForgeThemeCatalog.resolve(high_contrast, ui_scale_percent, text_scale_percent)` theme instance now reaches the shell, complete alert tray, and read-only inspector. At `1280x720`, the runner uses high contrast, `125%` UI, and `150%` text and verifies modal frame/layout containment plus alert and inspector accessibility semantics.
- Initial tray focus is the first non-expanded alert's enabled Inspect action, falling back to Ledger. Inert alert roots are no longer selected. Real controller accept opens the real inspector from this initial focus.
- Child routes capture stable descriptors containing alert ID, member ID, action, authoritative alert order, and party order. Close resolution prefers the exact surviving action, then the next/previous authoritative alert, visible overflow, expanded real alert action, exact/nearest member, and finally the named safe leader/page control. Tray and inspector return descriptors to HUD; Ledger returns them through its new close signal; Main connects that signal back to HUD. Weak controls remain an immediate optimization, not the sole authority.
- The `1280x720` rich shell now measures a `160px` horizontal opening between PartyRegion and AlertRegion. The alert band is bounded/reflowed to `472px` width and 172px cards; banner and loot bounds were narrowed so the supported transient surfaces do not intersect the alert region.
- `+1 alert` and `Open 1 additional combat alert` use exact singular copy.
- Invalid required authorities, party/context mismatch, invalid party identity, missing health, or invalid projection now produce a persistent visible `HUD unavailable: <reason>` status plus a transition-deduplicated `COMBAT_HUD_UNAVAILABLE reason=...` development diagnostic. The status clears only after a valid projection.
- Health actor rebinding disconnects the former actor: changing the old health component no longer changes HUD state, while the replacement component refreshes the same control instance.

### Authentic input, pause, focus, and route evidence

- The input runner uses real keyboard, controller, mouse, and Cancel events. Controller Ledger opens the actual production Ledger at the exact member and `stats` page, asserts its pause ownership, closes through controller Cancel, and restores exact focus.
- Rebinding the initiating member while Ledger is open removes the stale alert control; Ledger close then restores through the stable descriptor to a current HUD control.
- A real health refresh removes the initiating tray alert while the inspector is open; Cancel restores a surviving real tray action. A real projection refresh also preserves the current focus owner when the target survives. The all-resolved path closes the tray, announces `All alerts resolved.`, and focuses a named current member fallback.
- The Main focused integration emits the real HUD Ledger signal, observes exact-member/stats Ledger state, closes it through the production callback, and emits a stale member route that produces `That party member is no longer available.` without opening a child.
- Tray, inspector, and Ledger continue to use independent `RunPauseLease` ownership. No route directly changes `SceneTree.paused`; nested prior owners remain preserved.

### Measured geometry evidence

The party-scale runner uses post-layout `get_global_rect()` values, not policy or `custom_minimum_size` alone. At both `1920x1080` and `1280x720`, for six rich members and the 24-member compact final page, it verifies:

- each compact marker is exactly `280x84`, contains its content, does not overlap another marker, and remains reachable on the final page;
- every visible expanded/tray action is at least `48x48` and is contained by its alert card;
- expanded cards contain their child content and do not overlap;
- shell, leader, timer, party, alert region, modal frames/layout, boss band, banner, and loot rectangles remain viewport-bounded and follow the asserted non-collision contracts;
- the six-rich/three-alert-plus-overflow `1280x720` state has at least the concrete `160px` horizontal battlefield opening;
- boss-off hides the whole band and boss-on/banner/loot states remain measured separately.

### Final GREEN and retention evidence

- Task 4 focused HUD/Main/PartyManager: `TEST_SUMMARY: PASS (0 failures)`; exit `0`.
- Task 4 party scale/geometry: `COMBAT_HUD_PARTY_SCALE_SUMMARY: PASS`; exit `0`.
- Task 4 input routes: `COMBAT_HUD_INPUT_SUMMARY: PASS`; exit `0`.
- Combined Task 1–4 focused projection, responsive policy, view model, Task 3 combat components, Task 4 HUD/Main/party, and Ledger shell/foundation: `TEST_SUMMARY: PASS (0 failures)`; exit `0`.
- Progression retention: immutable profile marker with `values_equal=true bytes_equal=true`, then `PROGRESSION_ARENA_SMOKE_SUMMARY: PASS`; exit `0`.
- Responsive retention: four `RESPONSIVE_GEOMETRY_SIZE_PASS` markers and `RESPONSIVE_GEOMETRY_SUMMARY: PASS (4 sizes)`; exit `0`.

Focused output includes intentional negative-path diagnostics from HUD authority tests, Main, PartyManager, and Ledger foundation. Responsive output includes its retained settings-save negative-path diagnostics. The final party-scale and input outputs contained no parse/load error, ObjectDB leak, RID leak, retained-resource, or allocator diagnostics.

### Import, UID, and integrity evidence

- Fresh Godot import: `FINAL_IMPORT_EXIT=0`.
- The checked-in `Resolve-GeneratedUidState` function was redeclared in the same PowerShell process. `FINAL_UID_CLASSIFICATION_EXIT=0` retained exactly the five planned Task 4 UIDs: tray, inspector, focused HUD test, party-scale runner, and input runner. Only exact classifier-validated unrelated generated sidecars were removed.
- `git diff --check`: exit `0` with no output before report update; repeated after the report update and staging.
- The repair adds no production test-only method. Focus descriptor capture/restoration and close signals are runtime behavior used by HUD, Main, inspector, tray, and Ledger.

### Assumptions and boundaries

- The stable next/previous rule uses the captured authoritative order index: the same index after removal is the next alert; clamping the removed final index selects the previous alert.
- Scrolled tray cards may be outside the frame's visible rectangle by design; the ScrollContainer/frame/layout are contained, while each card still contains its own post-layout actions and the scroll clips non-visible rows.
- `COMBAT_HUD_UNAVAILABLE` may appear briefly during an authoritative party mutation before the corresponding actor is bound; this is the required honest fail-closed state and clears on the next valid projection.
- This remains engineering evidence, not Task 14 aesthetic acceptance or separate human/physical-controller acceptance.
