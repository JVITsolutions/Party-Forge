# Combat HUD Collapse and Primary Focus Design

**Status:** Approved behavior documented; implementation is not authorized by this document.

**Date:** 2026-08-31

**Verified source:** `b837c91954231ba808d2338b4bcc82efde720c84` on both local `main` and locally recorded `origin/main`

**Scope:** Combat HUD Party/Alerts collapse behavior, settings schema v3 persistence, and shared Living Forge primary-action focus treatment.

## Purpose

Reduce combat-screen obstruction without hiding critical state or weakening keyboard, controller, mouse, and accessibility behavior. Party and Alerts become independently collapsible, remember their state across runs and app restarts, and retain an in-place summary. The same batch corrects primary-action focus styling once at the Living Forge theme layer so Start Run, Confirm Extraction, and equivalent confirmation actions share a readable treatment.

This specification records Jacob's approved design. It does not authorize production code, tests, generated evidence, a merge, or a push.

## Decision labels

- **Live fact** describes behavior verified in the source tree at the commit above.
- **Approved decision** restates Jacob's approved behavior contract.
- **Derived design decision** makes the approved behavior implementable without expanding its scope. These choices remain reviewable at the written-spec gate.

## Live-code facts

### HUD scene and controller

- **Live fact:** `scenes/ui/hud.tscn` places `LeaderCard`, `Experience`, `PartyRegion`, and `AlertRegion` under `Margin/CombatStatus`. `PartyRegion` contains rich and compact roster surfaces. `AlertRegion` contains `ExpandedAlerts` and the focusable `Overflow` button.
- **Live fact:** `scripts/ui/hud.gd` owns HUD presentation, responsive rebuilds, dynamic member and alert controls, page and alert focus neighbors, stable focus descriptors, modal return focus, and visual-settings application.
- **Live fact:** `HUD.configure()` receives the authoritative run, party, experience, run context, and a `PartyForgeSettings` value. `HUD.apply_visual_settings()` refreshes the resolved theme, high contrast, scale, and character-HUD background opacity.
- **Live fact:** Batch 1's accepted recruit repair is in `_refresh_after_actor_binding()`, `_flush_actor_binding_refresh()`, and `_has_unbound_party_actor()`. It coalesces presentation refresh until party actor binding can provide health. This batch must not change that ordering or reintroduce transient `COMBAT_HUD_UNAVAILABLE` output.
- **Live fact:** `focus_descriptor_for()` and `restore_focus_descriptor()` already describe member, alert-action, overflow, and compact-page focus anchors. Modal focus restoration already validates visibility and focus eligibility.

### Runtime truth and layout

- **Live fact:** `scripts/ui/hud/combat_hud_view_model.gd` builds an all-or-nothing `CombatHudProjection` from validated party, progression, health, experience, timer, and boss authorities. It generates health alerts and orders them deterministically.
- **Live fact:** `scripts/ui/hud/combat_hud_projection.gd` defensively owns the complete ordered member and alert sets. It exposes at most three `visible_alerts` and the exact overflow count. It does not contain presentation preference state.
- **Live fact:** The only current alert severities are `CRITICAL`, `DOWNED`, and `DEAD`. Alert cards pair an icon/shape with visible severity text; severity is not color-only.
- **Live fact:** `scripts/ui/hud/combat_hud_responsive_layout.gd` selects rich or compact roster presentation for parties up to 24 and accounts for viewport, UI scale, and text scale. `hud.gd` separately budgets vertical alert-card space and routes hidden cards to `Overflow` and the complete alert tray.

### Settings and application ownership

- **Live fact:** `scripts/settings/party_forge_settings.gd` is schema v2. It defaults character-HUD dark-panel opacity to 50%, normalizes bounded settings, and copies every stored field.
- **Live fact:** `scripts/settings/party_forge_settings_store.gd` accepts schema 1 or 2, migrates to the current schema in memory, applies typed fallbacks, and saves through temporary/backup/promotion semantics.
- **Live fact:** `scripts/game/main.gd` owns `PartyForgeSettingsStore`, loads `saved_settings`, passes settings to the HUD, and applies settings-screen changes back to active surfaces. The HUD does not currently own persistence.

### Theme and primary actions

- **Live fact:** `data/ui/living_forge/living_forge_theme.tres` and `living_forge_high_contrast_theme.tres` define `LivingForgePrimaryButton`. Its current focus StyleBox is outline-only, and the normal theme does not explicitly define a primary `font_focus_color`.
- **Live fact:** `scripts/ui/living_forge/living_forge_theme_catalog.gd` currently creates `LivingForgeStartButton` at resolve time and gives it a separate filled focus treatment. This makes Start Run diverge from generic primary confirmation actions.
- **Live fact:** `LivingForgePrimaryButton` is used by Confirm Extraction and Accept Consequence in `scenes/ui/run_result/terminal_extraction_panel.tscn`; confirmation/retry actions in `scenes/ui/run_result_panel.tscn`; and Retry Offers/Confirm in `scenes/ui/level_up_panel.tscn`. `ForgeActionBar` also maps primary actions to the generic variation. Start Run uses `LivingForgeStartButton` through `scripts/ui/class_selection_panel.gd`.

### Existing verification surfaces

- **Live fact:** Current ownership includes `test_combat_hud.gd`, `test_combat_hud_projection.gd`, `test_combat_hud_view_model.gd`, `test_combat_hud_responsive_layout.gd`, `test_party_forge_settings.gd`, `test_settings_screen.gd`, and `test_living_forge_theme.gd`.
- **Live fact:** Integration coverage includes `combat_hud_input_runner.gd`, `combat_hud_party_scale_runner.gd`, `combat_loop_responsive_runner.gd`, `combat_loop_accessibility_runner.gd`, and the schema-2 Living Forge visual-evidence runner.
- **Live fact:** The supplied fresh tracked-only baseline for the exact source commit is `TEST_SUMMARY: PASS (262 suites)`, exit 0, with no parser, loader, import, script, or crash diagnostics.

## Approaches considered

### A. Independent in-place disclosure headers — approved

Party and Alerts each retain an always-visible header inside their current HUD territory. The headers toggle only their own content and present a concise collapsed summary. This preserves spatial context, allows independent preferences, and provides a stable focus anchor.

### B. One combined Combat HUD collapse — rejected

A single toggle would be simpler to implement but would prevent a player from retaining party state while reducing alert noise, or vice versa. It also cannot satisfy independent persistence.

### C. Auto-hide, edge tabs, or popovers — rejected

Those treatments reduce discoverability, complicate controller focus and accessibility ownership, and can move information without player intent. The approved design explicitly excludes auto-hide and edge popovers.

## Approved interaction design

### Independent headers

- **Approved decision:** Party and Alerts are independent collapsible regions.
- **Approved decision:** Each region has an in-place `Button` header with a post-layout target of at least 48 by 48 pixels. It uses `FOCUS_ALL`, a visible semantic focus ring, an explicit accessibility name/description, and parity across mouse click, keyboard accept, and controller accept.
- **Derived design decision:** Add `PartyHeader` as a direct child of `Margin/CombatStatus`, immediately above the existing leader card. Add `Header` inside `AlertRegion`, immediately above its content. Existing leader, experience, party roster, expanded-alert, and overflow paths stay intact to minimize routing and regression risk.
- **Derived design decision:** Header visuals are non-interactive children of the real Button. Child labels, icons, and the compact leader health bar ignore mouse input and do not create duplicate accessibility announcements; the header owns the combined accessible text.
- **Derived design decision:** The header disclosure glyph uses the bundled symbol-font fallback and includes visible `EXPANDED` or `COLLAPSED` text in its accessibility description. State is never communicated by glyph rotation or color alone.

### Party region

- **Approved decision:** Party collapse hides and reveals the leader card, leader XP bar, and roster as one unit. Run timer, boss state, loot status, and other HUD surfaces are unaffected.
- **Approved decision:** The collapsed header presents `PARTY`, total member count including the leader, leader name, a compact leader health bar, and the highest party severity with critical/downed/dead counts.
- **Derived design decision:** Severity precedence is `DEAD > DOWNED > CRITICAL > CLEAR`, independent of current alert display ordering. Counts are calculated from the complete projection and all three labels remain textual, including zero counts when space allows. At constrained widths/text scales they wrap into a second row rather than truncate semantic content.
- **Derived design decision:** Existing semantic assets are reused: `alert-triangle.svg`, `downed.svg`, and `dead.svg`. Clear state uses a visible check glyph from the existing Noto symbol fallback plus `ALL CLEAR`. No new art asset is required.
- **Derived design decision:** The header accessibility name includes numeric leader health and all severity counts, for example: `Party, 6 members. Leader Mira, health 72 of 100. Highest severity downed. 0 dead, 1 downed, 2 critical.` The visual ProgressBar is not a separate focus stop.

### Alerts region and tray

- **Approved decision:** Alerts collapse hides expanded alert cards and the existing overflow action. The header remains visible.
- **Approved decision:** The collapsed Alerts summary shows the complete alert count and highest-severity alert summary, or `ALL CLEAR` when there are no alerts.
- **Approved decision:** A new alert while collapsed updates the header on the normal projection refresh. It does not expand Alerts, move focus, open the tray, or announce a new unrelated focus target.
- **Derived design decision:** Highest-severity selection uses `DEAD > DOWNED > CRITICAL`, then the existing deterministic projection order, then stable ID as a final tie-break. The header shows both icon and text, for example `ALERTS 4 · DEAD · Mira is dead`.
- **Derived design decision:** To keep the complete tray directly discoverable while the existing `Overflow` is collapsed, add an adjacent `AlertsTrayAction` Button. It is visible and focusable whenever the complete alert count is greater than zero, uses at least a 48-pixel target, is labelled `VIEW ALL ALERTS (N)`, and opens the existing tray with `current_projection.all_alerts`. It is hidden, disabled, and `FOCUS_NONE` for `ALL CLEAR`. This action is not an overflow count and does not change collapse state.
- **Derived design decision:** Existing `Overflow` behavior remains unchanged while Alerts is expanded. Both tray entry points use the same open/close and stable return-focus path.

## State and persistence design

### Schema v3

- **Approved decision:** Raise `PartyForgeSettings.SCHEMA_VERSION` from 2 to 3 and add exact Boolean fields `hud_party_collapsed` and `hud_alerts_collapsed`.
- **Approved decision:** Both fields default to `false`, meaning expanded. First-run, unversioned-safe-default, schema-1 migration, schema-2 migration, missing-field, and malformed-field paths all resolve to expanded.
- **Derived design decision:** Replace the single legacy-version check with an explicit supported-version set containing schemas 1, 2, and 3. Schema 1 continues to receive the 50% HUD-opacity default; schemas 1 and 2 both receive expanded collapse defaults. A future or unsupported schema continues to fail to the complete safe default rather than partially enabling fields.
- **Derived design decision:** `copy()`, `load_settings()`, and `save_settings()` handle both fields. They are ordinary user-interface preferences in Player Simulation and Developer Mode and are not captured into `RunRulesSnapshot`; they do not alter deterministic gameplay or recovery truth.

### Ownership and save flow

- **Derived design decision:** HUD owns only the current presentation state and emits `collapse_preferences_changed(party_collapsed, alerts_collapsed)` after a user toggle. It never creates a settings store or mutates the settings object supplied by Main.
- **Derived design decision:** `main.gd` connects the signal in `_wire_static_ui()`, copies the current authoritative settings, changes only the two collapse fields, and saves through the existing `PartyForgeSettingsStore` and configured `settings_path`.
- **Derived design decision:** On successful save, Main replaces `saved_settings` with a normalized copy. On save failure, the HUD keeps the user's current session presentation, the prior valid settings file remains authoritative, and the existing exact settings-save error is reported. A later run/app restart therefore returns to the last successfully persisted state. No new modal or gameplay interruption is introduced.
- **Approved decision:** `HUD.configure()` and `HUD.apply_visual_settings()` initialize or reconcile both region states from the supplied authoritative settings, so the preference persists across a new run and a full app restart while preserving character-HUD opacity.

## Projection and update flow

Collapse is presentation preference, not combat truth:

1. Party, health, progression, experience, timer, and boss authorities continue to enter `CombatHudViewModel.build()` unchanged.
2. `CombatHudProjection` continues to carry the complete immutable member and alert sets even when either region is collapsed.
3. Add pure derived accessors on `CombatHudProjection` for leader lookup, exact severity counts, highest severity, and deterministic highest-severity alert. They calculate from the defensively owned collections and do not accept collapse state.
4. `HUD._refresh_projection()` continues to validate and replace runtime truth. It updates both header summaries on every successful refresh before deciding whether expanded content needs rebuilding.
5. When a region is collapsed, its full projection remains available to the alert tray, modal routes, and a later expansion. Collapse does not filter or mutate runtime state.
6. The Batch 1 actor-binding defer/flush path remains the only special handling for temporarily incomplete recruit binding. Collapse summary updates occur after that path yields a valid projection.

## Focus and accessibility contract

### Collapse

1. Determine whether the viewport focus owner is the region header, the persistent Alerts tray action, or a descendant that will be hidden.
2. If focus is inside hidden content, record the existing stable descriptor before changing visibility.
3. Move focus to that region's header.
4. Hide the region content roots. Hidden roots and their descendants must be absent from keyboard/controller traversal and accessibility enumeration and must not own focus.
5. Recompute explicit focus neighbors so traversal crosses the remaining visible controls, including both headers and `AlertsTrayAction` when eligible.

### Expand

1. Reveal the region content and reapply its current presentation/focus eligibility.
2. Attempt to restore the stored region-local stable descriptor.
3. If it is no longer valid, Party falls back to the leader card, then the first visible roster member or compact page action. Alerts falls back to the first meaningful visible alert action, then expanded `Overflow` when eligible.
4. If Alerts is `ALL CLEAR`, focus stays on the Alerts header. No invisible or disabled control is selected.

### Dynamic updates

- Projection refresh, recruitment, health changes, paging, responsive rebuilds, and new alerts do not steal focus.
- If a previously remembered descendant disappears while collapsed, the descriptor may remain stored, but expansion must validate it and use the documented fallback.
- Existing modal focus ownership remains authoritative. Tray, inspector, Ledger, extraction, and result overlays cannot have focus pulled back to a HUD header during their lifetime.
- Header `accessibility_name` is complete and current. Decorative child glyphs, labels, and health bar do not duplicate it.
- Severity, disclosure state, availability, and focus use text/shape/ring in addition to color.

## Motion behavior

- **Approved decision:** There is no auto-hide and no edge popover.
- **Derived design decision:** Content visibility and layout change atomically in every mode. With normal motion, only the disclosure glyph may rotate for `LivingForgeTokens.motion_ms("focus", false)`; no moving content delays focus/accessibility exclusion. With reduced motion, the glyph changes immediately and no tween is created.
- **Approved decision:** `reduced_motion = true` therefore produces no collapse animation.

## Responsive layout

- Party's expanded layout reserves the measured header height plus the standard gap before positioning `LeaderCard`. `Experience` remains below the leader, and `PartyRegion` remains below Experience.
- `CombatHudResponsiveLayout` must account for the added Party header height when calculating rich-card fit. Its 24-member cap, rich/compact threshold logic, pagination, and 720p Text150 safeguards remain intact.
- Alert cards begin below the measured Alerts header. The persistent tray action shares the header row when width permits and wraps to its own 48-pixel row when required. The alert vertical budget is calculated from the remaining space; it never overlaps the header, tray action, or existing overflow action.
- Collapsed summaries grow vertically rather than clip at Text150. The compact health bar and text stay inside the Party header. Both headers, the tray action, expanded overflow, leader, roster, timer, boss, and transient status surfaces remain within the viewport and do not overlap at supported UI/text scales.
- Collapsing Party or Alerts frees only that region's occupied content area. It does not move the timer, boss region, or the opposite HUD region into an edge popover.

## Shared primary-action focus correction

- **Approved decision:** Correct the theme, not individual scenes. `LivingForgePrimaryButton` and `LivingForgeStartButton` share a readable filled focused background, explicit focus font color, and semantic focus ring.
- **Derived design decision:** Make the canonical primary focus StyleBox in both theme resources draw its center using `surface_inset`, use `focus_outline` for the opaque ring, and use `ember_primary` for `font_focus_color`. These token pairs must be verified at a text contrast ratio of at least 4.5:1 in normal and high-contrast themes; the focus boundary must remain visually distinct from surrounding forged/inset surfaces.
- **Derived design decision:** Replace `_configure_start_button()` with shared primary-action configuration that copies the complete primary state contract to `LivingForgeStartButton`, including normal, hover, pressed, hover-pressed, focus, all matching font colors, font, and font size. Start and generic primary variations may own separate duplicated StyleBoxes for safe scaling, but their semantic signatures must match.
- **Approved decision:** Representative real-screen checks include Start Run; Confirm Extraction and Accept Consequence; run-result confirmation and retry actions; level-up Retry Offers and Confirm; and a primary action produced by `ForgeActionBar`.
- No screen-specific focus override is permitted for these actions.

## Error handling and invariants

- Invalid runtime authority continues to fail closed through the existing `COMBAT_HUD_UNAVAILABLE` path. Collapse code must not suppress a real authority error or create a transient one during valid recruitment.
- Malformed collapse settings use expanded defaults. Unknown settings schema behavior remains fail-closed.
- A settings save failure must not corrupt or replace the last valid file; existing temporary/backup/promotion behavior remains intact.
- A null/invalid projection does not produce stale summaries. Headers remain available and announce HUD unavailability consistently with the existing unavailable label.
- The alert tray always receives a defensive complete alert set from the current valid projection, regardless of expanded/collapsed state.
- Region toggles are idempotent: setting an already-current state does not save again, restart animation, rebuild content, or move focus.

## Verification design for the later implementation

### Unit and settings

- Extend `test_party_forge_settings.gd` for schema-3 defaults, copy isolation, both Boolean round trips, schema-1 migration, schema-2 migration, missing fields, malformed types, unsupported future schema, and failed-save preservation.
- Extend `test_combat_hud_projection.gd` and/or `test_combat_hud_view_model.gd` for total member count, leader health, all three severity counts, severity precedence, deterministic highest summary, and `ALL CLEAR`, including defensive-copy behavior.
- Extend `test_combat_hud.gd` for independent state, content-root visibility, header text/accessibility semantics, persistent tray-action eligibility, idempotence, no focus theft on new collapsed alerts, and preservation of the deferred recruit refresh.
- Extend `test_combat_hud_responsive_layout.gd` for measured header reservation and rich/compact calculations without regressing 1, 6, 7, 20, or 24-member boundaries.
- Extend `test_living_forge_theme.gd` to require filled focus StyleBoxes, explicit `font_focus_color`, >=4.5:1 focused text contrast, semantic focus-ring contrast, and semantic parity between Primary and Start across normal/high-contrast and supported scale matrices.
- Extend `test_main_wiring.gd` for the HUD-to-Main persistence signal, exact two-field save, successful authoritative update, save-failure preservation, and reload into a later run.

### Input and focus restoration

- Extend `combat_hud_input_runner.gd` to exercise mouse, keyboard, and controller activation for both headers; collapse from leader, XP-adjacent roster, paging, alert card/action, and overflow focus; exact header fallback; valid descendant restoration; stale-descendant fallback; cross-region traversal; direct collapsed tray access; and controller Cancel back to the initiating tray action.
- Verify that hidden descendants cannot take focus, are not reached by D-pad/Tab traversal, and are absent from accessibility exposure.
- Verify new alerts and severity changes update a collapsed header without expansion or focus movement.
- Verify modal ownership still wins when a collapsed-region refresh occurs behind the alert tray, member inspector, or Ledger.

### Responsive and accessibility

- Extend `combat_hud_party_scale_runner.gd` and `combat_loop_responsive_runner.gd` across supported viewport/UI/text matrices, including 1280x720 with Text150, 1/6/7/20/24 members, zero/one/three/overflow alerts, both regions independently collapsed, and both collapsed together.
- Assert real post-layout 48x48 minimums, containment, no overlap, summary wrapping, compact leader health-bar containment, and exact alert-budget behavior after header reservation.
- Extend `combat_loop_accessibility_runner.gd` for header names/descriptions, icon-plus-text severity, `ALL CLEAR`, non-color focus/disclosure cues, no duplicate decorative announcements, reduced-motion behavior, and hidden-control exclusion.

### Representative visual and theme parity

- Extend the existing exact-head visual contract or a focused schema-2 visual runner with reviewed captures for Party expanded/collapsed, Alerts expanded/collapsed, all-clear Alerts, critical/downed/dead summaries, 24-member Party summary, 1280x720 Text150, normal/high contrast, keyboard/controller focus, and reduced motion metadata.
- Capture real Start Run, Confirm Extraction, run-result primary confirmation/retry, and level-up primary confirmation actions with focus. Automated checks must bind each focused control to the shared resolved theme and calculate contrast; screenshot inspection is additional evidence, not the only proof.
- Generated screenshots and manifest are a later implementation/qualification artifact and are not created by this documentation gate.

### Qualification gates

1. Focused unit suites pass with terminal summary and exit 0.
2. HUD input, party-scale, responsive, accessibility, and representative visual/theme runners pass with their terminal markers and exit 0.
3. The complete headless suite passes with terminal `TEST_SUMMARY` and exit 0 in a fresh tracked-only imported environment.
4. Any windowed OpenGL visual/performance harness is run with its required renderer/window contract.
5. Independent code review separates requirements, code quality, automated evidence, and visual verdicts.
6. Jacob reviews the exact-head visual candidate before any post-approval qualification, merge, or push.

## Acceptance criteria

1. Party and Alerts collapse independently and retain their exact last successfully saved states across runs and app restarts.
2. Fresh, schema-1, and schema-2 settings start both regions expanded; malformed values safely expand.
3. Both headers are real, visible, focusable Buttons with at least 48x48 targets and mouse/keyboard/controller parity.
4. Party collapse hides leader, XP, and roster together. Its summary reports total members, leader name/health, highest severity, and exact dead/downed/critical counts with icon plus text.
5. Alerts collapse hides alert cards and existing overflow. Its summary reports exact count and deterministic highest summary, or icon-plus-text `ALL CLEAR`.
6. `AlertsTrayAction` keeps the complete tray directly discoverable when Alerts is collapsed and passes the unchanged complete projection.
7. New alerts update collapsed summaries without expansion, focus theft, or modal disruption.
8. Collapse moves hidden descendant focus to the correct header. Expand restores a still-valid descendant or the documented meaningful fallback. Hidden content is not focusable or exposed to accessibility.
9. Reduced motion creates no collapse tween. No auto-hide or edge popover exists.
10. Character-HUD opacity remains independently persisted/applied and semantic foreground information remains readable.
11. `LivingForgePrimaryButton` and `LivingForgeStartButton` share a filled, explicit, semantic focused treatment with >=4.5:1 text contrast in normal and high-contrast modes.
12. Start Run, Confirm Extraction, extraction consequence, run-result, level-up, and `ForgeActionBar` primary actions inherit the shared treatment without per-screen patches.
13. Batch 1 recruit binding produces no transient HUD-unavailable state and all unrelated gameplay behavior remains unchanged.
14. The focused, integration, visual, and full qualification gates above pass from an exact clean committed candidate before integration is considered.

## Dependencies

- Existing HUD scene, projection, view model, responsive layout, focus descriptors, alert tray, and member/alert component contracts.
- Existing settings object/store and Main ownership of persistent settings.
- Existing Living Forge tokens, normal/high-contrast theme resources, catalog scaling/cache, fonts, and severity icons.
- Existing automated runners and exact-head evidence rules.
- Batch 1 commits already present in the verified base, especially deferred recruit refresh and 50% character-HUD opacity.

## Risks and mitigations

- **Focus loss during visibility changes:** Capture a stable descriptor and focus the header before hiding; validate every restore target.
- **Dynamic controls regain focus eligibility while collapsed:** Apply collapse visibility after every structure/presentation rebuild and test health/recruit/resize refreshes in collapsed state.
- **Header text clips at Text150:** Measure content, allow controlled wrapping/growth, and exercise the supported scale matrix at 720p.
- **Alert tray becomes unreachable:** Keep the explicit persistent tray action and test mouse, keyboard, controller, modal return focus, and all-clear removal.
- **Projection and summary disagree:** Derive summaries only from the complete immutable projection; do not cache independent combat counts.
- **Settings migration drops Batch 1 opacity:** Test schema 1 -> 3 and schema 2 -> 3 separately, including the 50% legacy opacity default and retained schema-2 custom opacity.
- **Frequent toggles cause save churn:** Save only on actual Boolean changes; never save from projection refresh.
- **Theme fix regresses primary states:** Preserve normal/hover/pressed/hover-pressed semantics and add focused-state contrast/parity tests across both resources and catalog-scaled copies.
- **Shared-file collision:** `scripts/game/main.gd`, settings files, HUD files, theme resources, and broad integration runners are active shared surfaces. Reconcile current local `main` before final qualification if it moves; do not resolve ambiguous overlap by discarding either authority.

## Rollback

- Before integration, rollback is removal of the isolated feature branch/worktree; no user settings file has changed.
- After integration, code rollback removes the two headers/tray action and Main persistence signal, restores schema v2 settings handling, and restores the prior primary focus resources/catalog behavior.
- Schema rollback must tolerate already-written schema-3 files deliberately. A production rollback plan must either retain read compatibility for the two harmless Boolean fields or ship an explicit downgrade migration; it must not make all settings unreadable merely because schema 3 was saved.
- Visual evidence is regenerated from the rollback head; old exact-head evidence is never relabelled.

## Explicit exclusions

- No art production, icon acquisition, procedural or imported character/equipment geometry, body-hide region, character model, Blender asset, camera, or preview-depth change.
- No gameplay balance, combat authority, seed/randomization, class weighting, progression, loot, extraction policy, or run-recovery change.
- No auto-hide, edge popover, combined one-toggle HUD, tactic/gambit system, onboarding, or unrelated UI redesign.
- No per-screen primary focus patch.
- No production code, tests, implementation plan, generated evidence, merge, push, rebase, cleanup, or release is authorized by this design-document commit.

## Approval gates

1. **Current gate:** Jacob reviews this committed written specification, including the derived persistent `AlertsTrayAction` choice.
2. After written-spec approval, a separate authorization may create an implementation plan.
3. Implementation proceeds only from an approved plan and preserves explicit review checkpoints.
4. Automated/code review does not substitute for exact-head visual approval.
5. No merge or push occurs without a later explicit authorization.
