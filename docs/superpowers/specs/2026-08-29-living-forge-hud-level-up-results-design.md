# Living Forge HUD, Level-Up, and Run Results Design

**Date:** 2026-08-29

**Status:** User-approved design; independent UI/UX written-spec review approved

**Authoritative checkout:** `F:\Projects(root)\Game dev\Projects\party-forge`

**Implementation worktree:** `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\living-forge-combat-loop-ui`

**Branch:** `feat/living-forge-combat-loop-ui`

**Baseline:** `4c4acb5e001b0cfbb64aa06358b42b7ed9a67eb9`

**Governing design:** `docs/superpowers/specs/2026-08-28-living-forge-ui-revamp-design.md`

## Purpose

This is the third Living Forge vertical slice. It replaces the current fixed four-entry HUD, visually generic level-up flow, and boolean-only result panel with one cohesive combat-loop experience that remains readable from one through twenty-four party members.

The slice preserves the existing gameplay, progression, run-item, extraction, profile, and lifecycle authorities. It adds typed presentation boundaries, scalable Living Forge components, explicit interaction semantics, and a truthful result recap that can grow as Party Forge gains enemies, items, upgrades, and combat telemetry.

This document narrows the master design for this slice. Where the master design says that level-up confirmation commits an offer, this detailed design distinguishes fast direct commits from the confirmation required by targeted and recruitment choices.

## Approved Product Decisions

1. Deliver the HUD, level-up screen, and run results as one complete combat-loop slice.
2. Use the Living Forge visual system and shared components established by the first slice.
3. Support every party size from one through twenty-four without silently truncating members.
4. Use rich party presentation at one through six members and a bounded compact roster at seven through twenty-four.
5. Show at most three expanded alerts plus a deterministic `+N alerts` overflow indicator.
6. Current alerts provide awareness plus explicit Inspect and Ledger routes. They do not expose combat commands.
7. A Final Fantasy XII-style gambit/tactics system is a future feature with per-member, group, and whole-team scopes, configured from the Ledger and a main-menu route. This slice preserves a data seam but does not design or expose fake tactic controls.
8. Simple self or whole-party upgrades commit directly from the offer card.
9. Recipient-targeted and recruitment choices require recipient/context confirmation before commit.
10. Run results show every authoritative fact available today and hide unsupported sections.
11. Terminal resolution includes an explicit extraction picker before durable resolution. The player chooses ordinary items up to current extraction capacity while automatic, selected, and lost outcomes remain visible.
12. Result architecture accepts future recap providers without requiring a screen redesign.
13. Missing icons may be created specifically for Party Forge by the assistant or with 3D Gen Studio. All shipped icons must be normalized to the Living Forge language; no mismatched placeholder pack is acceptable.

## Goals

- Make the entire combat loop feel like the same stylized game as the Living Forge Play lobby.
- Keep leader, party, timer, boss/objective, and urgent state readable without obscuring combat.
- Keep every party member reachable by mouse, keyboard, and controller at party counts up to twenty-four.
- Make upgrade effects, scope, eligibility, and recipients understandable before authority changes.
- Keep routine upgrade selection fast while retaining confirmation where the decision has a target or recruitment consequence.
- Make terminal extraction a deliberate, reviewable choice before any eligible ordinary item is lost.
- Capture terminal truth before live state is cleared.
- Make victory, defeat, retained value, losses, and navigation consequences explicit.
- Add extension points for future recap content without inventing statistics today.
- Require fresh runtime screenshots and human visual acceptance in addition to automated checks.

## Non-Goals

- Implementing gambit rules, priorities, conditions, automation, tactic editing, or tactical combat commands.
- Implementing split-screen, player joining, per-player viewports, or simultaneous local-player focus.
- Adding combat balance, new upgrades, new enemies, new items, or new progression rules.
- Creating damage, healing, kill, build-history, synergy, or highlight data that production does not record.
- Replacing `PartyManager`, upgrade application, run recovery, extraction, resolution, profile, or item-ownership authority with UI state.
- Redesigning Armoury, Ledger, Warehouse, Pause, or the remaining front-end screens in this branch.
- Shipping a broad final icon library when this slice needs only a bounded semantic set.
- Treating passing geometry or screenshot automation as human visual approval.

## Verified Starting Point

### HUD

- `scripts/ui/hud.gd` reads runtime nodes directly and refreshes only four party entries.
- `scenes/ui/hud.tscn` is a fixed legacy left column.
- Leader health, XP, timer, traits, boss health, and four text party rows exist.
- Follower health/status detail, alerts, large-party modes, Living Forge components, and a typed projection do not exist.

### Level-Up

- `scripts/ui/level_up_panel.gd` already supports one through eight offers, reduced motion, focus/hover tooltip parity, recipient selection, confirmation, errors, and real focus movement.
- Recipient selection can reach a twenty-four-member party.
- Existing offer presentation is visually generic and does not consistently foreground icon/category, optional rarity, or exact before-to-after effect.
- The existing production path confirms every non-legacy offer; it does not yet implement the approved fast direct-commit rule.

### Results

- `scripts/ui/run_result_panel.gd` accepts only `victory: bool` and exposes Restart and Quit.
- `Main._show_victory()` and `Main._show_defeat()` clear live loot before showing that boolean result.
- `RunExtractionProjection` can authoritatively distinguish automatic, selected, and lost run-owned item IDs.
- `RunResolutionService` is the durable authority for resolved profile/item consequences and resumable-run revocation, but the current result panel does not project its outcome.
- Outcome, elapsed duration, party membership, class/rank state, run-owned items, and extraction results have production sources. Consolidated combat totals, highlights, and complete upgrade history do not currently have an authoritative result projection.

### Baseline Verification

A fresh isolated worktree requires a complete Godot `--import` before the suite because source-adjacent image import sidecars and `.godot` import artifacts are intentionally not tracked. After that import, the unchanged baseline finished with exit code `0` and `TEST_SUMMARY: PASS (238 suites)`. This is branch-start evidence only, not completion evidence for this slice.

## Visual Direction

The three screens use the existing Living Forge theme catalog, semantic color roles, typography roles, eight-pixel spacing grid, input prompts, high-contrast variant, and reduced-motion setting.

- Forged blue-black and charcoal surfaces provide structure.
- Warm ember gold marks progression, selected identity, and primary actions.
- Ivory or cool steel marks keyboard/controller focus.
- Class color remains a restrained identity accent on portraits and class badges.
- Rarity color remains confined to a badge, icon frame, or edge marker and appears only when an authoritative rarity is supplied.
- Critical, invalid, and destructive states combine red-orange treatment with an icon and readable text.
- Metalwork, clipped corners, shallow inset wells, and restrained ember motion provide style without covering the battlefield or weakening text contrast.
- Timer and numerical comparisons use tabular numerals.

### Icon Production Contract

1. Reuse an existing Party Forge icon only when its meaning and Living Forge treatment match.
2. Create missing semantic icons specifically for Party Forge rather than mixing unrelated packs.
3. Prefer clean vector or flat rendered forms for HUD/status symbols. Use 3D Gen Studio when a category or relic-style symbol materially benefits from a modeled source or rendered silhouette.
4. Normalize every final icon to the same silhouette weight, camera/lighting convention, padding, contrast, and semantic color treatment.
5. Confirm redistribution/licensing rights for every source, generator output, font, and incorporated element before it enters the repository.
6. Store editable/source assets with provenance beside or in the project-approved source location; runtime derivatives use deterministic names and sizes.
7. Every icon has a text label, tooltip, or accessible semantic name. Color and silhouette alone never carry required meaning.
8. Generated or assistant-authored art remains subject to fresh in-game visual review. Mechanically valid files are not automatically accepted art.

## Architecture and Authority Boundaries

### Presentation Models

Each screen consumes a typed, copy-safe presentation model rather than assembling truth throughout its component tree.

- `CombatHudProjection` contains leader, ordered party, timer, optional boss/objective, and ordered alerts.
- `PartyMemberHudProjection` contains stable member identity, display/class identity, leader flag, level, health, optional XP/status values, and presentation-safe semantic tags.
- `CombatAlertProjection` contains stable alert identity, stable member identity, category, severity, readable reason, and the available Inspect/Ledger destinations.
- `UpgradeOfferProjection` contains the authoritative choice identity plus presentation fields for icon/category, name, optional rarity, effect, scope, rank, eligibility, recipient/class tags, and disabled reason.
- `RunTerminalSnapshot` captures terminal runtime facts before disposable world state is cleared.
- `TerminalExtractionProjection` contains automatic items, ordered eligible item choices, selected items, items that will be lost, current capacity, and validation state.
- `RunResultProjection` contains terminal state plus ordered typed recap sections and action availability.
- `RunRecapSectionProjection` is the bounded extension shape used by optional future providers.

Names may be adjusted during implementation planning to follow exact repository conventions, but the separation of authority, snapshot, projection, and component responsibilities is mandatory.

### Projection Rules

- Stable member, choice, run, item, and alert identities cross presentation boundaries; display text is never used as identity.
- Components render supplied data and emit explicit intent. They do not mutate party, upgrade, run, item, profile, or lifecycle state.
- The presenter/view model may read authoritative runtime services and nodes, but leaf controls do not query unrelated services.
- Projection collections preserve stable production order and are copy-safe so UI sorting cannot mutate authority.
- Optional data appears only when production supplies and validates it.
- Required invalid data produces a named unavailable/recovery state rather than a partial, misleading UI.
- Unsupported recap providers or fields are omitted. They do not render zeroes, `N/A` filler, fake categories, or inferred achievements.
- Authority-changing success is shown only after the relevant service returns success and the refreshed projection matches that result.

### Future Tactics Seam

Current alerts intentionally carry only member identity, semantic state, severity, reason, and navigation destinations. They do not carry or execute combat commands.

A future tactics slice may associate stable member/group/team identities with ordered condition-action policies and may use the same member/status semantics. That future design will define rule authoring, conflicts, evaluation order, persistence, group membership, and controller editing. No such policy is stored in HUD state now, and no disabled `Tactics` or `Gambit` button appears in this slice.

## Scalable Combat HUD

### Stable Composition

- **Top center:** run timer, with optional objective and boss state only when supplied.
- **Upper-left leader command card:** leader portrait/identity, health, level, class, XP when supplied, and urgent semantic status.
- **Bounded party region:** rich follower cards or compact full-party roster according to party count.
- **Alert stack:** at most three expanded alerts plus overflow.
- **Boss treatment:** boss identity/health remains visually distinct from party health and does not displace the timer.

Gameplay remains the visual priority. HUD regions use bounded maximum widths, intentional negative space, and transparency/contrast chosen against the actual arena rather than an isolated dark mockup.

### Party Count Definition

The scaling count is the total owned party including the leader.

- At one through six total members, the leader command card represents the leader and the party region presents every follower as a rich card without duplicating the leader.
- At seven through twenty-four total members, the compact roster includes every member, including a clearly marked leader entry, so stable ordering, paging, and controller navigation cover the complete party. The leader command card remains the full-detail anchor.
- A party above the supported maximum fails visibly in development/test projection validation. Production UI must never silently truncate.

### Rich Mode: One Through Six

Each follower card includes:

- portrait or approved neutral silhouette
- character name and class identity
- health value/bar
- level
- supported semantic status indicators
- focused/selected/critical/downed states where production supplies them

Cards remain large enough for couch readability. The layout reflows before reducing text or targets below accessibility minima.

### Compact Mode: Seven Through Twenty-Four

- The roster uses a bounded two-row rail or equivalent bounded column arrangement selected by the responsive layout service.
- Every marker includes portrait/class identity, health, leader identity where relevant, and semantic status indicators.
- The visible marker count is calculated from available space and accessible minimum marker dimensions; it is not hard-coded to twenty-four.
- Stable paging or scrolling reveals overflow without shrinking the markers.
- Focusing a member scrolls that member into view and expands a single readable detail treatment without reordering the party.
- Page movement retains the focused member when possible.
- Closing Inspect or Ledger restores the exact member marker, or the nearest surviving member in stable order.

### Alert Projection and Ordering

Only production-backed alerts are emitted. The approved deterministic priority is:

1. Downed or dying
2. Critical health
3. Crowd-controlled
4. Separated from reward or combat range
5. Objective-relevant
6. Other actionable temporary state

Severity is not inferred from display color. It is part of the typed alert. Ties use stable party order followed by stable alert identity so cards do not flicker between refreshes.

The first three alerts are expanded. Remaining alerts are represented by `+N alerts`, which opens the complete ordered alert tray without hiding any affected member.

### Complete Alert Tray

- Activating `+N alerts` enters a paused UI context and opens a bounded Living Forge tray containing every current alert in deterministic priority order.
- Initial focus lands on the highest-priority alert that was not already one of the three expanded cards. If no such alert survives the refresh, focus lands on the first current alert.
- The tray uses a scrollable single-column list with member identity, severity/category, readable reason, Inspect, and Ledger actions. It does not create a second alert taxonomy or expose combat commands.
- Alert refreshes preserve the focused stable alert when it still exists. If it resolves, focus moves to the next alert in priority order, then the previous alert, then Close.
- Close or Cancel returns to the `+N alerts` control when it still exists, otherwise the nearest surviving expanded alert or compact member marker.
- Opening Inspect or Ledger from the tray records the exact alert and returns to it on close when still available.
- Closing the tray restores the prior pause state and never unpauses a run that was already paused.
- When no alerts remain, the tray closes with a concise resolved-state message and restores safe HUD focus.

### Inspect and Ledger Actions

- Live combat controls never have focus stolen by a newly appearing alert.
- An explicit Inspect action enters a paused UI context and opens a transient member detail view.
- Ledger opens the existing run-owned character authority at the exact member.
- Opening either route records the exact alert/member and prior pause state.
- Closing restores exact focus where possible and restores the prior pause state; it does not unpause a run the player had already paused.
- If the member disappears or becomes unavailable, focus falls back to the nearest surviving member and a concise status explains the change.
- No current HUD action changes AI behavior or tactics.

### Responsive Rules

- Standard and wide layouts retain the stable top-center and upper-left anchors.
- Compact/720p layouts reduce decorative space, not semantic content or minimum text/control size.
- Ultrawide layouts bound HUD regions rather than stretching them toward screen edges.
- 4K increases physical UI scale instead of adding more simultaneous party data.
- Future split-screen can instantiate a projection/component set per owning viewport. This branch does not implement or simulate those viewports.

## Level-Up Flow

### Offer Card Hierarchy

Every offer card uses this visual order:

1. Icon and category
2. Name and optional production rarity
3. Exact effect or authoritative authored effect summary
4. Personal, recipient, or whole-party scope
5. Eligibility and compatible recipient/class tags
6. Rank and additional detail

Where the existing resolver can calculate before and after without mutation, the primary effect uses a concrete form such as `Damage 12 -> 15`. Where no exact authoritative projection exists, the card shows the authored production effect and omits the numerical comparison. Rarity is optional and is never inferred from rank, color, or perceived strength.

Focus and hover preview the same data without committing. Extended detail remains available through the existing tooltip/detail interaction.

### Direct Commit

A choice commits directly from its card only when all of the following are true:

- the choice is currently valid and enabled;
- it does not require selecting a recipient;
- it is not a recruitment choice;
- the authoritative application path does not require additional player input.

Card activation emits one exact application intent, locks duplicate activation, and shows a stable pending state. The panel closes only after authoritative application success. Failure restores the same offer set, exposes the readable reason, and restores focus to the initiating card.

Whole-party and ordinary self/scopeless upgrades follow this fast path when they satisfy the rule. Display presentation never decides eligibility; the production choice/application contracts do.

### Targeted and Recruitment Confirmation

- A recipient-targeted choice opens the scalable recipient roster.
- Every eligible member remains reachable at twenty-four members.
- Ineligible members remain readable when their explicit reason helps the decision; otherwise they may be omitted by the authoritative recipient projection.
- If no eligible recipient remains, the roster shows the authoritative reason, keeps Confirm unavailable, and gives default focus to Cancel so the player can return to the initiating offer.
- Selecting a recipient opens confirmation with offer identity, exact effect, recipient identity, and resulting scope.
- Recruitment opens an equivalent confirmation containing the authoritative recruit identity and consequences supplied by production.
- Confirm emits one exact application intent and enters the same duplicate-safe pending state.
- Cancel returns to the offer cards without mutation and restores the initiating card.

### Reveal, Motion, and Completion

- Retain the existing reveal controller, skip behavior, reduced-motion behavior, tooltip parity, and focus contracts unless implementation evidence requires a bounded correction.
- Reveal animation cannot enable a card before final binding is complete.
- Reduced motion makes offer state immediate while preserving hierarchy and feedback.
- After successful resolution, focus returns deterministically to gameplay or to the next pending level-up choice.

## Run Results

### Terminal Sequence

Terminal handling is an ordered authority pipeline:

1. Receive the victory/defeat terminal event exactly once.
2. Freeze terminal gameplay and cancel hostile transient effects without yet discarding result inputs.
3. Capture a copy-safe `RunTerminalSnapshot` from authoritative runtime state.
4. Project automatic and ordinary extraction candidates through `RunExtractionPolicy` and open the terminal extraction picker.
5. After explicit player confirmation, re-project the exact selected `ExtractionSelection` values and reject stale or over-capacity input.
6. Perform durable terminal resolution through `RunResolutionService` using that accepted selection.
7. On success, refresh profile/run truth and build `RunResultProjection` from the captured snapshot plus the accepted resolution.
8. Only then clear disposable live loot/effects and enable terminal result actions.

Duplicate terminal events and duplicate resolution requests are rejected or resolved idempotently by stable run/transaction identity. A UI boolean is not terminal authority.

### Core Snapshot

The terminal snapshot captures only facts available at the boundary, including:

- stable run/profile identity
- victory or defeat
- elapsed duration
- ordered party identity, class, leader flag, and final level
- run-owned item state needed to explain retained/extracted/lost results
- any other already-authoritative terminal fact explicitly accepted by the implementation plan

If upgrade selection history, kill totals, damage, healing, or highlights are not durably recorded by the terminal boundary, they are absent. The result UI does not reconstruct them from current rank, scene children, remaining enemies, or display text.

### Terminal Extraction Picker

The extraction picker is part of terminal resolution, not a result-screen quick action.

- The header states `Choose up to N items to extract`, using the authoritative profile extraction capacity.
- Automatic extraction appears in a locked retained group and does not consume ordinary capacity.
- Eligible equipped and carried items appear in a stable scrollable grid grouped by source member/container while preserving canonical policy order.
- Every item uses authoritative item identity, rarity, source owner/container, and available comparison/detail presentation.
- A persistent summary shows `Automatic`, `Selected X / N`, and `Will be lost Y` counts, plus expandable exact item lists.
- When eligible item count is greater than capacity, no ordinary item is preselected. The player makes the tradeoff explicitly.
- When every eligible item fits, all eligible items may start selected because no loss tradeoff exists; the player may still deselect before confirmation.
- Capacity zero still shows the eligible items and explicit all-lost consequence. It never silently skips the loss decision.
- The player may confirm fewer than capacity. If unused capacity remains while eligible items will be lost, confirmation requires an explicit second acknowledgement naming the unused slots and loss count.
- Confirm is disabled for invalid or over-capacity selections and while an exact request is pending.
- Before mutation, a service-owned preflight reuses the same resolution validation to project durable destination readiness, including stash space required by selected items and displaced permanent leader equipment. The UI does not duplicate or approximate those rules.
- A preflight capacity failure names required and available destination space and lets the player reduce ordinary selections. If automatic resolution alone cannot fit, the flow enters the durable recovery state rather than pretending that deselection can solve it.
- Cancel from item detail or the unused-capacity warning returns to the same item. The terminal picker itself cannot cancel back into combat after the run is terminal.
- Mouse, keyboard, and controller can select, deselect, inspect, scroll, confirm, and return from detail without losing the current selection.
- If a selected item becomes stale before resolution, the policy re-projection rejects the request, refreshes the eligible set, preserves still-valid selections, explains the changed item, and requires confirmation again.
- Resolution failure retains the confirmed selection and uses the stable retry identity; it does not silently choose a different set.

### Auditable Current Truth Register

The implementation plan may use only the following current recap claims unless this design is explicitly amended and reviewed:

| Claim | Authoritative source | Current result behavior |
| --- | --- | --- |
| Outcome | Exact terminal victory/defeat event captured once | Always shown after valid terminal capture |
| Duration | `GameRun.elapsed_time()` captured in `RunTerminalSnapshot` | Always shown |
| Party identity, class, leader, final level | Ordered `PartyManager` / `PartyMemberState` snapshot | Always shown for valid members |
| Automatic, eligible, selected, lost item identity | `RunExtractionPolicy` projection from exact run-owned item state and confirmed selections | Shown in picker and finalized loot recap |
| Item name, rarity, and source | `PlayerRunContext` item registry plus production item/equipment catalogs | Shown only for successfully resolved item identity |
| Durable retained/extracted result | Accepted `RunResolutionResult` plus refreshed persisted profile | Shown only after resolution success |
| Upgrade/build history | No consolidated authoritative terminal history today | Hidden |
| Damage, healing, kill totals, highlights | No consolidated authoritative terminal telemetry today | Hidden |
| Other profile/progression consequences | No approved typed delta provider in this slice baseline | Hidden until a reviewed provider exists |

An implementation plan cannot relabel current ranks, remaining scene nodes, inferred item value, or presentation text as a result claim.

### Extensible Recap Sections

The screen has a stable high-level order:

1. Outcome and duration
2. Party and final levels
3. Build/upgrades, when supplied
4. Loot retained, extracted, and lost, when supplied
5. Profile/progression consequences, when supplied
6. Recorded highlights, when supplied
7. Terminal actions

Core outcome and party sections are typed first-party projections. Optional providers emit bounded `RunRecapSectionProjection` values with a stable section ID, title, semantic kind, ordered entries, optional summary, and optional expandable details.

- Providers read the terminal snapshot and accepted resolution; they do not mutate either.
- A provider cannot overwrite a core section or another provider's stable ID.
- Provider order is deterministic.
- An empty provider result is omitted.
- An optional provider failure is logged and omitted without fabricating content.
- A required core projection failure enters the terminal recovery state instead of showing a partial recap.

This permits future enemy, item, damage, healing, upgrade-history, and highlight providers without changing the result screen's primary composition.

### Current Truth Presentation

- Outcome and duration always appear after a valid terminal projection.
- Party composition and final levels appear for every valid member.
- Loot uses authoritative item identity/presentation plus `RunExtractionProjection` and accepted resolution semantics to distinguish automatic retention, selected extraction, and loss.
- Build/upgrades, consequences, and highlights appear only where a current production source supplies complete enough data for the named claim.
- Victory emphasizes retained progression/value without hiding losses.
- Defeat explains confirmed losses and recoverable state without implying that unsupported recovery exists.
- Long party/item lists use bounded summaries and explicit expandable detail rather than tiny text.

### Action Semantics

- **Restart Run:** appears only after terminal resolution succeeds and the old recovery is revoked. It opens a prepopulated lobby using the prior profile and class where still valid; checkout and run creation occur only after the player explicitly starts.
- If the prior profile or class is no longer valid, Restart Run opens the lobby in an explicit unresolved-selection state with a readable reason and requires a valid profile/class choice before Start Run can become available.
- **Return to Forge:** appears only after terminal resolution succeeds and returns to the front end with the resolved retained/lost/extracted state.
- **Quit Application:** appears only when the terminal result is durably finalized and then closes the application without changing the accepted result.
- **Abandon Run:** never appears on a terminal result. It remains the separately styled destructive action for an active run and uses the authoritative forfeiture path.

Generic `Restart`, `Return`, or `Quit` labels are not used where their persistence consequences differ.

### Resolution Failure and Recovery

- While terminal resolution is pending, recap actions are disabled and duplicate requests are rejected.
- Failure retains the captured terminal inputs and shows a named `Resolution interrupted` state with the authoritative readable reason and Retry Resolution.
- The UI does not clear live run-owned data, claim victory consequences, or navigate as if resolution succeeded.
- Safe Return to Forge or Quit Application is offered only if the existing lifecycle/recovery authority verifies that the exact run and run-owned item state remain durable. Otherwise those routes remain unavailable with an explanation.
- Retrying reuses the same stable transaction/run identity so accepted work cannot duplicate.

## Focus, Input, and Accessibility

- Mouse, keyboard, and controller activation reach the same authoritative actions.
- Every party member, alert, offer, eligible recipient, recap section, and result action is reachable.
- Focus follows visible spatial layout and never enters hidden, disabled, or decorative controls.
- Opening a child view records the exact initiating control; close/cancel restores it or a deterministic nearby fallback.
- Destructive actions never receive default focus.
- Health, rarity, selection, eligibility, and alert severity use icon/text/shape in addition to color.
- Text and controls remain readable at supported UI/text scale settings.
- High contrast preserves the same semantics with stronger separation.
- Reduced motion removes nonessential transition/pulse motion without removing state feedback.
- Screen-reader/accessibility names use production identity and explicit action semantics where Godot exposes them.
- Active-device prompts may change glyphs without changing action names or focus order.

## Error and Empty States

- A valid one-member party shows the leader command card and an intentional no-followers state in rich mode.
- No active boss/objective hides those optional regions without leaving misleading empty frames.
- No alerts hides the stack while preserving stable HUD composition.
- Invalid required HUD/member identity produces a visible development/test failure and a bounded production unavailable state; it never drops the member silently.
- No eligible upgrade exposes the authoritative reason and a recovery path rather than an inert offer screen.
- An upgrade application failure restores the initiating choice and exact reason.
- Optional empty result sections disappear.
- Invalid terminal core data or failed durable resolution uses the terminal recovery state and keeps consequence-assuming actions unavailable.

## Performance Boundaries

- Party structure and static identity controls rebuild only when the ordered party revision changes, not every frame.
- Health, XP, timer, boss, and status values update existing controls through bounded signal/revision refreshes.
- Alert controls diff by stable alert identity; alert refresh does not recreate the complete HUD tree.
- The compact roster retains a bounded number of visible controls and scrolls/pages by stable member identity.
- The terminal extraction grid and long recap details reuse the repository's bounded scroll/grid behavior and do not instantiate unbounded off-screen detail controls.
- Optional recap providers run once per accepted terminal snapshot/resolution revision, not during frame processing.
- Motion and hover treatment avoid one unbounded `_process()` loop per party, alert, extraction, or recap entry.
- Performance evidence records viewport, party/item/alert counts, settings, renderer, and hardware context. A timeout or partial capture is not a pass.

## Verification and Acceptance

### Automated Contract Tests

Add focused unit coverage for:

- HUD/member/alert projection validation and copy safety
- stable party ordering and no truncation
- rich/compact threshold at six/seven
- responsive visible-count and paging calculations
- deterministic alert priority, tie-breaking, three-card cap, and `+N` count
- Inspect/Ledger route identity and focus restoration
- upgrade presentation, optional rarity, and exact-delta omission rules
- direct-commit classification and duplicate-pending rejection
- targeted/recruitment confirmation and cancellation
- failure restoration to the initiating offer
- terminal snapshot capture before disposable cleanup
- idempotent terminal orchestration and result-action gating
- core and optional recap provider validation, ordering, collision rejection, omission, and failure behavior
- exact Restart Run, Return to Forge, Quit Application, and Abandon Run visibility/semantics

### Integration Runners

Automated runtime/geometry/input evidence covers:

- party counts `1`, `6`, `7`, `12`, `20`, and `24`
- no-alert, one-alert, three-alert, and overflow-alert cases
- focus/paging to the final member at every large-party size
- Inspect and Ledger round trips with prior pause state preservation
- direct simple upgrade success/failure
- twenty-four-member targeted recipient selection, confirm, cancel, and error recovery
- terminal extraction at zero capacity, all-items-fit capacity, constrained capacity, unused capacity, stale selection, and resolution retry
- terminal pending, success, failure, retry, restart-lobby, return, and quit flows
- standard, compact/720p, ultrawide, and 4K-responsive layouts
- standard theme, high contrast, default motion, and reduced motion

### Full Regression

Final automated qualification requires:

1. complete Godot `--import` in the isolated/fresh checkout;
2. headless parser/import success without forbidden loader/script markers;
3. all focused unit and integration runners with exact PASS markers;
4. the complete suite with exit code `0` and a fresh `TEST_SUMMARY: PASS (<count> suites)` marker;
5. no unrelated tracked or untracked generated artifacts.

Expected negative-path diagnostics are acceptable only when owned by a passing test. Process exit code alone is never sufficient.

### Fresh Visual Evidence

Capture fresh windowed OpenGL Compatibility screenshots from the exact candidate commit. Dummy-renderer headless images are not visual evidence.

At minimum capture:

- no-alert, exactly-three-alert, and overflow-alert HUD states
- rich HUD at six members during representative combat
- compact HUD at seven members to prove the mode boundary
- compact HUD at twenty and twenty-four members, including alert overflow and a focused off-page member
- the complete alert tray, including focus and an Inspect/Ledger return
- level-up offers with direct and targeted examples
- twenty-four-member recipient selection
- terminal extraction with automatic, selected, and will-be-lost items visible
- victory recap with every currently supported section
- defeat recap with explicit loss/consequence treatment
- terminal resolution failure/retry state
- representative compact/720p and ultrawide compositions
- visible keyboard/controller focus and mouse hover where their treatments differ
- high-contrast, reduced-motion, enlarged UI-scale, and enlarged text-scale corner cases

The user is reviewing remotely, so the candidate screenshots must be shown in the conversation before visual acceptance. Automated checks may establish geometry and input behavior, but only explicit human review accepts style, hierarchy, density, clarity, and battlefield legibility.

## Delivery Boundaries

The later implementation plan should keep reviewable tasks in this order:

1. Typed projection/snapshot contracts and tests
2. Bounded Living Forge combat components and any required icons
3. Scalable HUD and alert navigation
4. Level-up presentation and direct/confirmed commit policy
5. Terminal orchestration, extensible recap, and exact result actions
6. Responsive/input/accessibility qualification
7. Fresh windowed screenshots and human visual gate
8. Full regression, cold-worktree qualification, written verification, review, and integration choice

No task may bypass an existing gameplay or persistence service to make its UI demonstration easier. Code completion, automated qualification, and visual acceptance remain separate gates.

## Completion Criteria

This slice is complete only when:

- one through twenty-four party members are all represented and reachable without truncation;
- the six/seven rich-to-compact boundary is proven;
- alert ordering, three-card cap, overflow, Inspect, and Ledger routes work without exposing tactics controls;
- simple upgrades commit directly and targeted/recruitment choices confirm exactly as approved;
- every displayed upgrade effect and recap fact is production-backed;
- terminal truth is captured before cleanup and durable resolution gates all consequence-assuming actions;
- Restart Run, Return to Forge, Quit Application, and active-run Abandon Run retain distinct semantics;
- optional future recap providers can be added without restructuring the result screen;
- all input, responsive, accessibility, focused, integration, and full-suite checks pass;
- fresh candidate screenshots are shown to the user and explicitly accepted;
- no generated or third-party icon is accepted without coherent Living Forge normalization and visual review;
- the branch contains no unrelated changes and is not pushed without user authorization.
