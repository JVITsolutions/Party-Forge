# Latticewright Warehouse Presentation Activation Design

**Date:** 2026-08-29
**Status:** Approved design; awaiting written-spec review; implementation is not authorized

## Purpose

Activate the checked-in City access snapshot for one bounded Player Mode presentation decision: a player without `stash` may see a visible, selectable, locked Warehouse and receive clear guidance to unlock **Stash Access** in the City tree.

The snapshot remains presentation input only. `WarehouseAccessPolicy` remains the final authority for opening the Warehouse, and Party Forge continues to own all runtime behavior.

## Decision summary

- Scope is exactly `city.warehouse` and `city.warehouse.interior`.
- The existing **Use City Access Snapshot** setting remains default-off.
- A developer stages the feature by enabling the setting in Developer Mode and then switching to Player Mode.
- Player Mode plus the setting uses the checked-in Party Forge snapshot to choose `HIDDEN`, `LOCKED`, or `AVAILABLE` presentation.
- Developer Mode keeps its unrestricted Warehouse preview and existing shadow comparison.
- Snapshot failure immediately restores the legacy Player Mode presentation.
- A locked Warehouse remains focusable and selectable, but selection opens a dedicated explanation dialog rather than the Warehouse.
- `WarehouseAccessPolicy` is rechecked immediately before any Warehouse open.
- The dialog may route through the existing City tree path. It never allocates a node or mutates progression.
- Disabling the setting restores the legacy hidden-when-locked behavior without migration or cleanup.

## Reconciled context

The accepted compatibility boundary is:

`Latticewright runtime-v3 -> version-specific importer -> Party Forge-owned canonical snapshot -> Party Forge consumer`

The Warehouse shadow pilot established the following evidence:

- the snapshot and legacy policy agree that `stash` controls Warehouse access;
- the expected locked-profile divergence is presentation only: legacy hides the Warehouse while the snapshot exposes it as locked;
- the checked-in snapshot loader, evaluator, duplicate-key rejection, destination comparison, and default-off gate are qualified;
- `WarehouseAccessPolicy` is already the extracted Player Mode route rule;
- Developer Mode's unrestricted preview is already outside the candidate comparison.

This activation accepts the known presentation divergence. It does not make Latticewright, the importer, or the snapshot authoritative for navigation or progression.

## Goals

- Teach the Warehouse dependency before it is unlocked.
- Keep navigation authorization inside Party Forge.
- Preserve an immediate, tested rollout rollback.
- Keep Latticewright updates replaceable at the importer/snapshot boundary.
- Preserve Developer Mode preview and shadow evidence behavior.
- Support mouse, keyboard, and controller interaction with deterministic focus.
- Fail silently for players and diagnostically for developers.

## Non-goals

- No activation of the other six City snapshot locations.
- No generic City destination registry.
- No routing from arbitrary snapshot destination strings.
- No node allocation, automatic unlock, progression write, profile migration, or settings-schema migration.
- No change to the `stash` gameplay contract.
- No Latticewright rebuild, reinstall, publication, authoring-project mutation, or gameplay-time Latticewright document load.
- No broad Main Menu or Living Forge UI revamp.
- No removal or consolidation of the existing Warehouse button and City hotspot in this bounded phase.
- No analytics, external telemetry, or persistent activation report.

## Activation model

### Existing setting

`PartyForgeSettings.use_city_access_snapshot` remains the single rollout switch and remains `false` by default. Enabling it does not change profile state or snapshot files.

The setting may be enabled while Developer Mode is active. Switching to Player Mode preserves the stored boolean and activates the Warehouse presentation candidate. Switching back to Developer Mode preserves the unrestricted preview and shadow comparator behavior.

No new setting or schema version is introduced. Turning the setting off takes effect on the next authoritative menu refresh and restores legacy presentation immediately.

### Separate loading from consumer policy

`CityAccessProvider` currently embeds the shadow pilot's Developer-Mode restriction. Activation separates snapshot loading from the policy of each consumer:

- the provider remains default-off and loads only the checked-in Party Forge-owned snapshot when the setting is enabled;
- `CityAccessShadowComparator` independently retains its Developer Mode-only gate;
- `WarehousePresentationResolver` independently uses the candidate only in Player Mode;
- no other consumer is added.

This change does not make the provider authoritative. It only prevents a reusable Party Forge snapshot seam from owning presentation-mode policy.

## Warehouse presentation resolver

Add a small, pure `WarehousePresentationResolver` and typed `WarehousePresentationResult`. The result exposes exactly one state:

- `HIDDEN`
- `LOCKED`
- `AVAILABLE`

The resolver receives immutable inputs:

- current `PartyForgeSettings`;
- current validated `ProfileState`;
- the current `WarehouseAccessPolicy` result;
- a candidate provider/evaluator result for `city.warehouse`.

It performs no file I/O, navigation, UI mutation, profile mutation, or settings mutation.

### Resolution rules

1. Invalid profile or settings inputs use the current fail-closed legacy presentation.
2. Developer Mode bypasses activation presentation and keeps the existing unrestricted preview.
3. Player Mode with the setting off returns legacy presentation.
4. Player Mode with candidate load, validation, evaluation, unknown-location, or destination-contract failure returns legacy presentation.
5. A legacy `AVAILABLE` result remains `AVAILABLE`; candidate data cannot hide or lock an authorized Warehouse.
6. A legacy `BLOCKED` result plus candidate `HIDDEN` returns `HIDDEN`.
7. A legacy `BLOCKED` result plus candidate `LOCKED` returns `LOCKED`.
8. A legacy `BLOCKED` result plus candidate `AVAILABLE` returns `LOCKED`, never `AVAILABLE`, and records a sanitized divergence. Candidate data cannot grant apparent or actual authorization.

The candidate is valid for activation only when the checked-in snapshot evaluates the exact `city.warehouse` record and its available destination is the exact comparison contract `city.warehouse.interior`. Other locations and destinations are not dispatched or generalized.

## Data flow

Authoritative menu refresh is ordered as follows:

1. Load current settings and profile through existing Party Forge stores.
2. Resolve authoritative Warehouse access with `WarehouseAccessPolicy`.
3. If the staged Player Mode gate is active, ask `CityAccessProvider` for the checked-in snapshot and evaluate only `city.warehouse`.
4. Resolve the typed presentation state.
5. Pass that resolved state into `MainMenuViewModel`.
6. Present the Main Menu.
7. In Developer Mode only, run the existing shadow comparator after presentation as an observational sidecar.

`MainMenuViewModel` receives resolved Party Forge state. It does not read files, know a Latticewright format, invoke an importer, or interpret arbitrary destination IDs.

## Main Menu projection

Extend `MainMenuProjection` with an explicit Warehouse presentation state so visibility, selectability, and authorization are not conflated.

| Presentation | Visible | Selectable/focusable | Selection behavior |
| --- | --- | --- | --- |
| `HIDDEN` | No | No | None |
| `LOCKED` | Yes | Yes | Dispatch Warehouse route to the explanation gate |
| `AVAILABLE` | Yes | Yes | Dispatch Warehouse route to authoritative authorization |

The Warehouse label remains **Warehouse** in Player Mode. The locked state adds a readable locked badge/indicator and accessible description; it does not rely on color alone.

The existing Main Menu Warehouse action and City Warehouse hotspot consume the same projection and dispatch the same route. Their later consolidation belongs to the Living Forge UI work, not this activation.

Developer Mode keeps the current visible, enabled **Developer Warehouse Preview** behavior when `stash` is absent.

## Authoritative route gate

All Warehouse requests, including direct calls and both existing menu origins, enter the same central dispatcher.

The dispatcher reloads authoritative settings/profile data and resolves `WarehouseAccessPolicy` immediately before acting:

- If the policy returns `AVAILABLE`, open the existing Warehouse screen.
- If the policy returns `BLOCKED` and the freshly resolved presentation is `LOCKED`, open `WarehouseLockedDialog`.
- If the policy returns `BLOCKED` and presentation is `HIDDEN`, do not open the Warehouse or the dialog.
- Developer Mode preserves its existing explicitly labeled preview override.

A stale menu projection therefore cannot open the Warehouse after access is revoked, and a stale locked projection cannot suppress a newly authorized Warehouse.

The snapshot destination is validated as evidence only. It is never passed to a generic router.

## Warehouse locked dialog

Add a dedicated, stylized `WarehouseLockedDialog` using the Living Forge modal grammar rather than a native `ConfirmationDialog`.

Visual direction:

- forged dark panel;
- restrained ember/brass border and lock insignia;
- strong title and requirement hierarchy;
- high-contrast readable body copy;
- controller, keyboard, and mouse parity;
- reduced-motion behavior consistent with current Main Menu presentation.

### City tree available

- Title: **WAREHOUSE LOCKED**
- Requirement: **Requires Stash Access**
- Body: **Unlock Stash Access in the City tree to open permanent storage.**
- Primary action: **View City Tree**
- Secondary action: **Back**

Primary focus begins on **View City Tree**. Escape/Back closes the dialog and returns focus to the exact Warehouse action or hotspot that opened it.

### Before City tree access

- Title: **WAREHOUSE LOCKED**
- Requirement: **Requires Stash Access**
- Body: **Complete the prologue to access the City tree. Then unlock Stash Access to open the Warehouse.**
- Action: **Back**

No City tree CTA is shown before the existing Player Mode City tree route is durably eligible.

### Eligible but temporarily unavailable City tree

If the profile is eligible for the City tree but its runtime is unavailable, the dialog explains that City services are temporarily unavailable and shows **Back** only. It does not mislabel a runtime failure as unfinished progression.

## City tree transition

**View City Tree** closes the dialog and enters the existing `MainMenuViewModel.ROUTE_CITY_TREE` path with the Warehouse origin preserved for focus restoration. It does not configure or open `PassiveTreeScreen` directly.

The existing City route performs its own current profile, mode, discovery, and runtime checks. If those checks fail after the dialog was presented, the existing player-facing denial remains authoritative.

When the City tree closes, Party Forge refreshes the profile and Main Menu projection before restoring the Main Menu. If the player unlocked `stash`, the Warehouse becomes `AVAILABLE`; otherwise it remains `LOCKED`. Focus returns to the Warehouse origin when that control remains valid.

No City tree node is selected, allocated, or highlighted automatically in this phase.

## Diagnostics and failure handling

Candidate open, size, decode, duplicate-key, parse, schema, validation, loader-contract, evaluator-input, unknown-location, and destination-contract failures produce legacy presentation immediately.

Player-facing behavior on candidate failure is identical to setting-off legacy behavior. Developers receive a sanitized, local-only, deduplicated marker with allowlisted fields, for example:

```text
PARTY_FORGE_WAREHOUSE_PRESENTATION outcome=<LEGACY|CANDIDATE|CANDIDATE_FAILED|DIVERGED> state=<HIDDEN|LOCKED|AVAILABLE> reason=<allowlisted-reason>
```

The marker must not contain parser text, filesystem paths, source bytes, profile IDs, display names, or arbitrary exception text. Repeated refreshes with the same tuple emit nothing; a changed tuple or toggle cycle may emit fresh evidence.

On every failure or divergence:

- `WarehouseAccessPolicy` remains authoritative;
- Developer Mode preview remains unchanged;
- no profile, settings, snapshot, authoring project, or Latticewright file is modified;
- no fallback snapshot or Latticewright document is loaded;
- no candidate destination is dispatched.

## Testing strategy

### Unit coverage

- Resolver matrix for legacy access, mode, toggle, candidate `HIDDEN`/`LOCKED`/`AVAILABLE`, and every candidate failure class.
- Candidate `AVAILABLE` plus legacy `BLOCKED` remains locked and cannot grant authorization.
- Legacy `AVAILABLE` cannot be hidden or locked by candidate drift.
- Provider loading is default-off; shadow comparison remains Developer Mode-only; activation remains Player Mode-only.
- `MainMenuProjection.copy()` retains the typed Warehouse state without aliasing.
- Main Menu maps `HIDDEN`, `LOCKED`, and `AVAILABLE` to correct visibility, focusability, badge, accessibility text, and route emission.
- Dialog copy and action sets cover City tree available, prologue-gated, and runtime-unavailable states.
- Sanitized diagnostic allowlists and deduplication reject uncontrolled values.

### Integration coverage

- Player Mode, toggle off, and no `stash` retains legacy hidden behavior.
- Player Mode, toggle on, and no `stash` exposes a selectable locked Warehouse.
- Selecting locked Warehouse opens only the dialog.
- Direct Warehouse route invocation rechecks current settings/profile and cannot bypass `WarehouseAccessPolicy`.
- Player Mode with `stash` opens Warehouse with the setting on or off.
- Developer Mode without `stash` retains unrestricted preview with the setting on or off.
- Dialog **View City Tree** uses the existing route and preserves focus origin.
- Escape/Back closes and restores focus for both Warehouse origins.
- Returning after allocating Stash Access refreshes the profile and makes Warehouse available.
- Returning without allocation leaves Warehouse locked.
- Snapshot failure, unsupported format, duplicate keys, unknown location, and wrong destination restore legacy presentation without mutation.
- Profile serialization and settings persistence change only when the user explicitly changes the existing setting.

### Visual and input evidence

Qualify the Main Menu locked affordance and dialog at representative 1080p, 1440p, and 4K viewport sizes with mouse, keyboard, and controller focus. Evidence must include:

- readable lock state without color dependence;
- no clipped copy or buttons;
- deterministic primary focus;
- focus containment and restoration;
- Escape/Back behavior;
- reduced-motion and high-contrast compatibility where those modes are currently supported.

### Regression gates

Run focused suites for the snapshot loader/provider/evaluator, shadow comparator, Warehouse policy, Main Menu projection/screen/wiring, settings persistence, profile persistence, passive tree return flow, and generated artifacts. Then run the City access integration runner and complete Party Forge test suite.

Accepted output must include terminal `TEST_SUMMARY`, expected negative-path diagnostics, and a scan for unexpected test, parse, script, load, and resource-loader failures.

## Verification record

Write a dated verification record containing:

- exact implementation commit;
- authoring, runtime, and snapshot SHA-256 values;
- setting default and exercised staged states;
- focused, integration, and full-suite commands and terminal summaries;
- sanitized failure evidence;
- visual/input screenshots;
- confirmation that no profiles or Latticewright files changed;
- exact operational rollback instructions.

## Rollback

Operational rollback is immediate:

1. Enter Developer Mode.
2. Disable **Use City Access Snapshot**.
3. Save settings and return to Player Mode.
4. Confirm a locked Warehouse is hidden and an unlocked Warehouse remains available.

No profile migration, cache deletion, snapshot regeneration, or Latticewright change is required.

Code rollback remains bounded to the presentation result/resolver, the provider consumer-policy split, Main Menu projection/presentation, locked dialog, central route handling, diagnostics, and tests. `WarehouseAccessPolicy`, the checked-in snapshot contract, and the version-specific importer remain independently replaceable.

## Acceptance criteria

Implementation is acceptable only when one exact commit demonstrates all of the following:

- the toggle is still default-off;
- Player Mode activation affects only `city.warehouse` presentation;
- locked Warehouse is visible, selectable, accessible, and explanatory;
- the City tree CTA appears only when the existing route is eligible and available;
- `WarehouseAccessPolicy` is rechecked before every Warehouse open;
- candidate data cannot grant authorization or dispatch a destination;
- Developer Mode preview and shadow comparison remain unchanged;
- invalid candidate data restores legacy presentation and emits only sanitized diagnostics;
- toggle-off rollback is immediate and tested;
- no profile, progression, snapshot, authoring, or Latticewright mutation occurs;
- focused, integration, visual/input, and full-suite gates pass.

No other City location may be activated until it has a real Party Forge destination and its own approved consumer contract.
