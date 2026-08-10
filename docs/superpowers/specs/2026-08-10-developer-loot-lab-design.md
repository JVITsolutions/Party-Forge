# Party Forge Developer Loot Lab Design

Date: 2026-08-10

Status: Design approved section by section; final document review pending

Parent design: `docs/superpowers/specs/2026-08-08-weighted-loot-generation-and-equipment-stats-design.md`

This document is authoritative where it is more specific than the parent design. It defines the developer-only Loot Lab portion of weighted-loot Increment 4. Live enemy drops, world pickup, and production reward-source wiring remain a separate follow-up increment.

## Goal

Add a responsive, controller-complete Loot Lab to the existing isolated Developer Item Sandbox. The lab must make deterministic weighted generation practical to inspect and balance at both single-item and 100,000-item scales without freezing the editor, mutating player data, or hiding why an outcome occurred.

The lab combines a persistent three-pane generation workbench with a dedicated analysis view. It reuses the production generator, traces, presentation contracts, sandbox transactions, and balance-report semantics rather than creating a parallel loot system.

## Approved decisions

- Implement the Loot Lab before live ground drops and pickup wiring.
- Add it to the existing Developer Item Sandbox instead of creating another top-level developer modal.
- Use a three-pane Workbench as the default Loot Lab view: generation controls, results/sample gallery, and selected-item trace inspector.
- Add a dedicated Analysis subtab using the analysis-first layout: distributions and diagnostics dominate the view, with exact-sequence drilldown.
- Advance deterministic batch jobs in bounded, cancellable chunks across frames.
- Support presets plus a custom batch size capped at 100,000 attempts.
- Require a warning confirmation before a 100,000-item batch starts.
- Retain aggregate statistics plus at most 100 deterministic sample results, not every generated item.
- Regenerate any sequence on demand from the frozen canonical request.
- Preserve clearly labelled partial analysis after cancellation while distinguishing it from a completed report.
- Keep the latest completed report available until a new job completes successfully, with an explicit report selector when a cancelled partial also exists.
- Let a selected generated preview be explicitly issued into the isolated Developer Item Sandbox.
- Persist only developer preferences and explicitly issued sandbox items. Batch reports and previews are session-only unless explicitly exported.
- Provide canonically ordered JSON and human-readable Markdown/text exports.
- Validate mouse/keyboard and controller operation at 1920x1080, 2560x1440, and 3840x2160.
- Keep all Loot Lab controls and diagnostics unavailable in Player Mode.

## Scope

Included:

- the Developer Item Sandbox tab shell and Loot Lab page;
- Workbench and Analysis Loot Lab subtabs;
- canonical request editing for every currently supported `ItemGenerationRequest` field;
- random or forced base selection and allowed/forced rarity selection;
- single-item and deterministic batch generation;
- frame-budgeted progress, cancellation, and partial reports;
- incremental expected-versus-observed aggregation;
- bounded deterministic sample retention and exact-sequence regeneration;
- trace, rejection, weight, family, pattern, tier, roll, and failure inspection;
- request-scope reachability and conflict diagnostics;
- isolated issuance into the existing sandbox inventory;
- developer-only preference persistence;
- JSON and Markdown/text exports;
- responsive layout, focus containment, mouse/keyboard input, and controller input;
- cold import, focused tests, full suite, startup, save compatibility, profile isolation, and manual equipment-stat verification.

Deferred:

- connecting enemies, bosses, chests, vendors, events, carts, or other production sources to weighted generation;
- ground-item models, beams, labels, sounds, rarity animations, and pickup interaction;
- campaign/adventure drop-in co-op reward distance behavior;
- crafting, corruption, salvage, enchanting, vendors, trading, and extraction changes;
- Legendary special powers and Mythic-through-Eternal acquisition;
- long-term report history, automated report comparison, or importing reports back into the lab;
- a standalone external balance application;
- final production balance targets.

## Information architecture

### Developer Item Sandbox tabs

The modal gains a top-level tab shell with these developer surfaces:

- **Fixtures:** a thin home for existing deterministic fixture issuance/reset behavior. It does not introduce a second generator.
- **Equipment:** the existing isolated inventory/stash, movement, save/reload, integrity, tooltip, and comparison workflow. Its behavior and persistence contract remain unchanged.
- **Loot Lab:** the new weighted-generation surface.

The reorganization must preserve the current sandbox's open/close behavior, exact return-focus restoration, held-item cancellation rules, drag-and-drop behavior, controller placement behavior, and isolated document ownership.

### Loot Lab subtabs

The Loot Lab contains two focusable subtabs that share one session controller:

- **Workbench:** persistent request controls on the left, outcomes and deterministic sample gallery in the center, and the selected result's full trace on the right.
- **Analysis:** expected-versus-observed tables, distribution summaries, conflicts, structural reachability, finite-batch eligibility/observation states, tier gaps, impossible patterns, inactive-rarity violations, failures, and deterministic drilldown.

A fixed footer remains visible in both views. It displays state, attempted/target count, progress, elapsed time, throughput, and cancellation when applicable. When both a completed report and a cancelled partial report exist, a focusable report selector identifies which one the Workbench and Analysis views are presenting.

Switching views never restarts a batch or discards its report.

## Workbench design

### Request controls

Workbench exposes the complete supported request vocabulary:

- equipment base mode: random/eligible or one forced base;
- permitted rarity ranks and optional forced rarity;
- item level from 1 through 1000;
- source ID;
- generation domain;
- difficulty ID;
- Heat;
- party archetype tags;
- Charisma;
- unlock tags;
- required and excluded base tags;
- required and excluded affix tags;
- deterministic seed;
- starting generation sequence;
- batch preset or custom attempt count.

Controls are populated from validated catalogs and registered vocabularies. Technical IDs may be shown because the surface is Developer Mode only, but player-facing names remain visible alongside them.

Validation happens before generation. Invalid or contradictory fields receive local errors and no job begins.

### Batch sizes

The initial presets are 1, 100, 1,000, 10,000, and 100,000 attempts. Custom values accept 1 through 100,000 inclusive.

The 100,000 preset or custom value requires explicit confirmation. The cap is enforced by the job/request boundary as well as the UI so callers cannot bypass it.

### Results and sample gallery

Outcome summary cards show attempted, successful, failed, average tier, rarity mix, and diagnostic counts. The gallery shows at most 100 deterministic attempt results.

For a target count `N`:

- if `N <= 100`, every attempt index is sampled;
- if `N > 100`, sample index `i` is `floor(i * (N - 1) / 99)` for `i` from 0 through 99, distributing 100 indexes across the range with both endpoints included;
- the sampled generation sequence is `starting_sequence + attempt_index`;
- a sampled structured failure appears as a failure tile rather than silently disappearing.

The sample-index algorithm is integer-defined and unit tested so independent runs choose the same sequence identities.

Selecting a successful tile opens its item presentation and trace. Selecting a failure tile opens its structured failure and relevant rejection context.

Any non-sampled sequence inside the attempted range can be entered and regenerated exactly without retaining the original item.

### Inspector

The inspector combines the existing player-facing item presentation with developer layers:

- icon, name, rarity, slot, restrictions, weapon damage, implicits, explicit affixes, tiers, rolls, and roll ranges;
- source, domain, generator version, seed, request sequence, and selected IDs;
- stage-by-stage eligible candidates, rejected candidates and reasons, effective weights, selection, families, patterns, tiers, and exact rolls;
- structured failure stage, stable code, and details when generation fails.

Existing tooltip modifier behavior remains available: Alt/left trigger compares, and Shift/right trigger shows advanced affix information. Developer trace details are never projected into Player Mode tooltips.

## Analysis design

### Incremental aggregation

The analyzer consumes each `ItemGenerationResult` and trace as the item is generated. It updates aggregates before releasing the full result unless the attempt is sampled or retained as a bounded diagnostic example.

Analysis includes:

- base, rarity, pattern, affix, affix-kind, modifier-family, tier, and weight-band distributions;
- success and failure totals by stage and stable reason code;
- expected count, observed count, absolute difference, and percentage deviation;
- structurally unreachable candidates under the request's hard gates;
- candidates not encountered as eligible in the finite audited batch;
- candidates encountered as eligible but not observed;
- empty pools and zero-total-weight opportunities;
- aggregated rejection reasons and conflicts;
- tier-boundary behavior and tier gaps;
- impossible patterns;
- inactive-rarity or reserved-slot violations;
- bounded exact-sequence examples for every warning/failure category;
- elapsed time and throughput.

### Expected-versus-observed calculation

Expected values come from the effective weights actually encountered in trace selection opportunities, not global authored counts.

For every selection opportunity with positive finite candidate weights:

1. Sum the eligible effective weights.
2. Add `candidate_weight / total_weight` to that candidate's expected count.
3. Increment the selected candidate's observed count.
4. Record invalid/empty opportunities separately instead of normalizing them.

This preserves the effects of base tags, item level, rarity ceilings, source, domain, unlocks, Heat, Charisma, archetype bias, patterns, prior affix selections, and family conflicts.

Structural request-scope reachability is evaluated from catalog definitions and hard eligibility gates across the request's allowed base/rarity space. It is not inferred merely from a finite batch. Trace aggregation separately reports candidates that were never encountered as eligible in the audited attempts and candidates that were eligible but not selected.

These three states remain distinct:

- structurally unreachable under the request's hard gates;
- not encountered as eligible in this finite batch;
- encountered as eligible but unobserved after weighting.

A low-weight candidate receiving zero observations is never falsely labelled structurally unreachable.

Deviation flags are balancing diagnostics, not brittle statistical pass/fail assertions. Automated tests verify exact deterministic arithmetic on controlled fixtures and broad direction/tolerance on production distributions.

### Diagnostic examples

Each diagnostic category retains a bounded ordered list of exact attempt sequences. The initial cap is 20 examples per category. Additional occurrences increment the category count without retaining full items or traces.

Selecting an example regenerates that exact sequence from the report's frozen request and opens it in the inspector.

## Execution architecture

### Boundaries

The implementation separates generation state from presentation:

- `LootLabBatchJob` owns one immutable request snapshot, target count, progress, cancellation, and terminal status.
- `LootLabReportAccumulator` consumes ordered results and produces aggregate/report documents.
- `LootLabReachabilityAnalyzer` evaluates hard-gate reachability for the frozen request without treating finite sampling as proof of impossibility.
- `LootLabSessionController` owns the active job, latest completed report, optional cancelled partial report, selected sequence, and regeneration commands.
- `DeveloperLootLab` presents controller state and forwards user intent.
- `LootLabExportService` converts a terminal report into canonical JSON and Markdown/text without opening UI in tests.

Exact names may change during implementation planning, but these responsibilities must not collapse into the existing large `developer_item_sandbox.gd` script.

### Job advancement

The production UI advances the active job from the normal Godot process loop. Each advance call stops when either:

- a small elapsed-time budget is reached; or
- a configured maximum number of attempts for that frame is reached.

Cancellation is checked before and after every chunk. No blocking loop may generate the full requested batch from a button callback.

The time budget controls scheduling only. Attempts remain ordered by generation sequence, and scheduling cannot affect items, samples, aggregates, diagnostics, or exports.

Tests advance a job by an exact maximum attempt count without depending on wall-clock timing.

### Request and generation identity

At job start, the validated `ItemGenerationRequest` is converted to a canonical JSON-safe document and frozen. Every attempt uses `copy_with_sequence(starting_sequence + attempt_index)`.

Preview generation uses a disposable Loot-Lab issuer namespace derived deterministically from the canonical scenario identity. Preview item identities exist only inside the session report/sample and are not storage ownership.

The generator remains the production `ItemGenerationService`. The Loot Lab does not reimplement selection, issuance, or rolls.

### Report replacement and cancellation

Starting a new batch leaves the latest completed report available for inspection until the new batch completes successfully.

Terminal states are:

- `COMPLETED`: attempted equals target, a complete report replaces the prior completed report, and any stale partial report is cleared;
- `CANCELLED`: generation stops after the current chunk and a clearly labelled partial report becomes the selected report without deleting the latest completed report; when both exist, the user can switch between them;
- `FAILED`: a job-level configuration/catalog failure is reported and the latest completed report remains;
- individual structured item-generation failures count within a valid running/completed batch and do not become job-level failure.

Closing the sandbox during an active job asks for cancellation. A Loot Lab job never continues invisibly after its owning modal closes.

## State and ownership

### Persisted developer-only data

The last valid request controls and selected preset may be stored in a versioned preferences document beneath `user://developer_item_sandbox/`. Preferences contain no generated items or report aggregates.

Items explicitly issued into the Developer Item Sandbox continue to persist through the existing sandbox store and isolated owner domain.

### Session-only data

The active job, completed/partial reports, sample gallery, regenerated traces, selected sequence, comparison state, and timing data are session-only.

Reports survive closing and reopening the modal during the same running game session only when no job is active. They are not automatically restored after application restart.

### Explicit sandbox issuance

Generated gallery results are previews and cannot be dragged directly into inventory or equipment.

`Issue to Sandbox` passes the exact generated payload through an isolated issuance/transaction boundary that:

- assigns a fresh unique sandbox-owned instance identity;
- preserves base, rarity, item level, weapon damage, implicits, explicit affixes, tiers, operations, and exact rolls;
- places the item atomically into the requested or first valid sandbox slot;
- changes nothing when storage rejects the transaction;
- cannot address a player profile, run inventory, player stash, equipment sheet, progression store, or save document.

Repeated issuance of the same preview produces distinct sandbox instances with identical generated stats and unique identities.

## Input model

### Mouse and keyboard

- Click focuses and activates tabs, controls, sample tiles, analysis rows, diagnostic examples, and actions.
- The mouse wheel scrolls the pane under the pointer; scrollbars remain draggable.
- Enter/Space activates the focused control.
- Escape cancels an active batch before it can close the sandbox.
- Double-clicking a diagnostic example regenerates and opens its exact sequence.
- Export actions use a normal file dialog in interactive builds.

### Controller

- Left/right shoulder buttons cycle the top-level Developer Item Sandbox tabs.
- Workbench and Analysis are ordinary focusable subtabs; D-pad left/right changes the selected subtab while their tab row is focused.
- D-pad navigation follows an explicit closed graph through controls, samples, tables, inspector actions, footer actions, and Close.
- South face confirms, generates, opens, issues, or activates the focused control.
- East face cancels an active batch first, clears held sandbox-item state where applicable, and closes only when no higher-priority cancel action remains.
- Right-stick vertical input scrolls the currently focused scrollable pane.
- Focus follows the selected sample or diagnostic drilldown and never escapes behind the modal.

Existing west-face sandbox pickup and south-face placement behavior remains unchanged on the Equipment tab.

## Responsive layout

At 1920x1080, Workbench keeps all three primary panes visible. Each pane scrolls independently rather than forcing controls or text into unusable widths.

At 2560x1440 and 3840x2160, panes gain usable width and the sample gallery adds columns. Typography and controls remain within bounded theme sizes instead of scaling into oversized 4K UI.

Below the desktop threshold, the Workbench panes become focusable subviews/stacked sections. They do not remain three compressed columns. Analysis keeps identity and status columns visible while secondary columns use bounded horizontal scrolling when necessary.

The progress/cancel footer remains visible at every supported size. Resizing preserves the active job, selected view, selected sequence, scroll ownership where practical, and a valid focused control.

## Export contract

A terminal report contains a canonical JSON-safe document with at least:

- report schema and generator versions;
- canonical request snapshot and scenario identity;
- job status;
- target, attempted, succeeded, and failed counts;
- start/end sequence range;
- elapsed time and throughput;
- aggregate expected and observed tables;
- rejection/failure/diagnostic summaries;
- sampled attempt sequence identities and result summaries;
- bounded diagnostic example sequences;
- catalog/report metadata required to interpret the result.

JSON export uses recursively canonical key ordering and stable array ordering. The report contains a deterministic evidence payload plus a separately labelled runtime-metrics envelope. Equivalent completed jobs produce byte-equivalent deterministic evidence payloads; elapsed time and throughput are intentionally runtime observations and are excluded from deterministic byte-parity comparisons.

Markdown/text export presents the same evidence in a human-readable summary. Cancelled reports prominently state `CANCELLED / PARTIAL` and include attempted versus target count.

Exports never write through profile/save stores. Interactive file selection is a presentation concern; the export service itself only returns bytes/text and stable validation errors.

## Failure behavior

- Invalid request controls prevent job creation and show field-local messages.
- A missing or invalid equipment/foundation catalog aborts the job before the first attempt.
- A structured item-generation failure records its stage, code, source, seed, sequence, rejection context, and aggregates; it returns no partial item.
- Failed generation consumes no persistent sequence and changes no storage.
- Empty or invalid trace-weight opportunities become explicit diagnostics.
- Sandbox issuance is failure-atomic and reports no-space, duplicate, validation, or transaction errors without changing the preview or storage.
- Export failure changes no report or game state.
- Switching to Player Mode cancels the active job, clears temporary Loot Lab state, closes the modal, and leaves no Loot Lab control focused or visible.
- A batch request above 100,000 or below 1 is rejected below the UI boundary.

## Reuse of balance-report semantics

`ItemGenerationBalanceReport` already defines production evidence, scenario identity, canonical JSON, and distribution concepts. Loot Lab must not fork those meanings.

Implementation should extract or reuse shared incremental aggregation helpers where practical. The synchronous production-matrix builder may remain as a test/report caller, but its expected-weight, percentile, manifest, and export semantics must agree with the Loot Lab for equivalent inputs.

The UI batch job must not call the current large synchronous report build from a button callback.

## Verification strategy

### Unit tests

- Request snapshots are validated, canonical, immutable from the job's perspective, and sequence-copied correctly.
- Batch limits reject 0, negatives, and values above 100,000.
- Exact-count advancement preserves ordered generation across arbitrary chunk boundaries.
- Cancellation stops before another chunk and produces correct partial accounting.
- Completed, cancelled, failed, and individual-result-failure states remain distinct.
- The sample-index algorithm includes both endpoints and never exceeds 100 indexes.
- Independent identical jobs produce identical ordered results, sample identities, aggregates, diagnostics, and deterministic export payloads.
- Expected counts sum candidate effective-weight probabilities per opportunity correctly.
- Structurally unreachable, not-encountered-eligible, and encountered-eligible-but-unobserved definitions remain distinct.
- Diagnostic examples are ordered, reproducible, and capped at 20 per category.
- Report replacement preserves the last completed report until a successor completes.
- Export ordering and partial labels are stable.
- Explicit issuance preserves exact generated stats while allocating unique sandbox identities.
- Every failure path is mutation-free outside the allowed isolated developer state.

### UI and integration tests

- Player Mode cannot open, focus, or inspect Loot Lab controls.
- Switching out of Developer Mode cancels and clears the lab.
- Workbench and Analysis share the same active job and report.
- Progress advances across frames and cancellation remains responsive.
- A 100,000-item request requires confirmation.
- Mouse/keyboard can edit, generate, scroll, select, regenerate, issue, compare, show advanced affixes, export, and cancel.
- Controller can reach and operate every control without a mouse, including right-stick scrolling and batch cancellation.
- The focus graph closes inside the modal and exact return focus is restored.
- Existing Equipment-tab drag/drop, west-face pickup, south-face placement, persistence, integrity, and tooltip behavior remain green.
- Issued items appear through the shared `StorageSlotButton` and layered tooltip contracts.
- Layout runners cover 1920x1080, 2560x1440, and 3840x2160 without clipped required actions or compressed unusable panes.
- Profile-root manifests and profile bytes remain identical before and after generation, analysis, cancellation, export, and sandbox issuance.

### Final gates

Before integration:

1. Cold Godot import completes without loader, missing-resource, or parse failure.
2. Focused generator, balance-report, batch-job, export, sandbox, storage, tooltip, responsive, controller, and profile-isolation suites pass.
3. Existing weighted-loot production evidence still passes.
4. The complete automated suite emits one explicit passing summary.
5. Headless startup emits expected boot markers.
6. Save compatibility and profile-isolation checks pass.
7. A manual developer playtest generates and issues representative melee, ranged, caster, armor, and accessory items, equips them, and confirms attributes, defenses, damage, DPS, healing, restrictions, comparisons, and advanced tooltips update correctly.

## Delivery boundary

This design completes the Developer Loot Lab portion of Increment 4 only. It creates the reusable request, report, and ownership seams required by later integration, but it does not authorize live enemy/reward mutations.

After this increment passes and is integrated, a separate approved design/plan may connect authorized enemy and boss sources, ground-item presentation, mouse/controller pickup, multiplayer ownership, and reward-distance rules without changing deterministic generation or sandbox ownership.

## Acceptance criteria

This design is implemented when:

1. Developer Mode exposes a responsive Loot Lab inside the existing Developer Item Sandbox.
2. Workbench generates one item or a deterministic bounded batch without blocking the UI.
3. Analysis explains expected and observed distributions, failures, exclusions, conflicts, tier behavior, patterns, and inactive systems using actual trace weights.
4. Batches up to 100,000 are cancellable and produce deterministic complete or clearly partial reports.
5. At most 100 deterministic attempt results plus bounded diagnostic examples are retained, and any attempted sequence can be regenerated exactly.
6. Selected successful previews can be issued atomically into only the isolated developer sandbox.
7. JSON and Markdown/text reports export without saving player state.
8. Player Mode exposes no Loot Lab UI or diagnostics.
9. Mouse/keyboard and controller workflows pass at 1080p, 1440p, and 4K.
10. Existing sandbox, tooltip, storage, profile, run, progression, equipment, extraction, and weighted-loot behavior remains unchanged outside the approved developer surface.
11. Cold import, focused suites, production balance evidence, complete suite, startup, save compatibility, profile isolation, and manual equipment-stat verification all pass.
