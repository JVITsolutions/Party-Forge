# Latticewright Warehouse Shadow Pilot Design

**Date:** 2026-08-28
**Status:** Approved design; implementation is not yet authorized

## Purpose

Prove that Party Forge can compare one checked-in Latticewright-derived City access decision with its existing gameplay rule without allowing the candidate source to change player or developer behavior.

The pilot covers only `city.warehouse`. It preserves the approved compatibility boundary:

`Latticewright runtime-v3 -> version-specific importer -> Party Forge-owned canonical snapshot -> Party Forge consumer`

Latticewright remains a replaceable authoring/import edge. Party Forge never loads Latticewright authoring or runtime documents during gameplay.

## Reconciled context

The accepted Latticewright 0.5.0 work established format-3/runtime-v3 projects, native graph portals, graph collections, and a 16-project Party Forge portfolio. Graph semantics remain owned by Latticewright, while gameplay contracts remain owned by Party Forge and require separate approval.

Party Forge now contains a strict runtime-v3 City access importer, a checked-in normalized snapshot, a loader, an evaluator, and a Developer Mode/default-off provider seam. These components are qualified but have no live UI or gameplay consumer.

The consumer audit found only one current production destination with a direct contract match:

| Snapshot location | Condition | Current production destination |
| --- | --- | --- |
| `city.apothecary` | Always | None |
| `city.coliseum_road` | Always | None |
| `city.inn` | `service:hero_registry` | None |
| `city.merchant` | `service:city_vendors` | None |
| `city.scholars_archive` | Prologue completed | None |
| `city.smithy` | `service:equipment_upgrading` | None; Armoury uses the distinct `equipment_inventory` contract |
| `city.warehouse` | `stash` | Existing Warehouse screen, main-menu route, City hotspot, and route authorization |

The six locations without production destinations remain inert.

## Goals

- Compare the legacy and snapshot-derived Warehouse decision during Developer Mode.
- Keep legacy Warehouse visibility, authorization, and navigation authoritative.
- Preserve the unrestricted Developer Mode Warehouse preview.
- Report access, visibility, and destination parity independently.
- Fail safely when the snapshot cannot load or evaluate.
- Produce deterministic, sanitized, local-only diagnostics without log spam.
- Establish evidence for a later, separately approved activation decision.

## Non-goals

- No Player Mode behavior change.
- No player-facing locked Warehouse state.
- No routing from snapshot destination IDs.
- No general City destination registry.
- No activation of the other six snapshot locations.
- No profile, settings-schema, or save migration.
- No gameplay effects, stat balance, class-tree, or building-tree integration.
- No Latticewright format change, rebuild, reinstall, publication, or live-project mutation.
- No analytics, external telemetry, or persistent comparison report.

## Architecture

### WarehouseAccessPolicy

Extract the existing Player Mode Warehouse rule into a small pure policy. Given a valid `ProfileState`, it resolves:

- `AVAILABLE` when `permanent_feature_unlocks` contains `stash`.
- `BLOCKED` otherwise.

A null or invalid profile fails closed to `BLOCKED`. The policy never mutates its input.

The main-menu view model uses this policy instead of duplicating the rule. It then applies the existing Developer Mode preview override after the Player Mode decision. The extraction must be behavior-preserving and remain covered by the existing main-menu and route-authorization tests.

### CityAccessShadowComparator

Add a sidecar comparator with no authority over UI or navigation. It receives the current settings and profile, the legacy Player Mode Warehouse decision, a `CityAccessProvider`, a `CityAccessEvaluator`, and a diagnostic emitter.

It runs only when both conditions are true:

1. Settings are in Developer Mode.
2. `use_city_access_snapshot` is enabled.

The comparator asks the provider for the checked-in normalized snapshot, evaluates only `city.warehouse`, normalizes both sources into comparable dimensions, emits a sanitized result, and returns. Its result is observational and must not be passed into menu projection or route authorization.

Main-menu refresh remains ordered as follows:

1. Build the authoritative legacy projection.
2. Present or retain that projection unchanged.
3. Run the optional sidecar comparison using the same immutable profile/settings inputs.

The Warehouse route continues to reload authoritative settings and recheck the legacy projection immediately before opening the screen.

### Comparison-only destination mapping

The pilot recognizes exactly one mapping:

`city.warehouse.interior -> MainMenuViewModel.ROUTE_WAREHOUSE`

This mapping exists only to compare destination identity. It cannot dispatch, navigate, open a scene, or resolve arbitrary destination strings. Any other candidate destination is a divergence.

## Dimension model

The comparator evaluates three dimensions independently.

### Access

- Legacy `AVAILABLE` when `stash` is present; otherwise `BLOCKED`.
- Candidate `AVAILABLE` when the snapshot projection is `AVAILABLE`.
- Candidate `BLOCKED` when the snapshot projection is `LOCKED` or legitimately `HIDDEN`.
- Candidate `UNAVAILABLE` when loading, validation, or evaluation fails.

### Visibility

- Legacy `VISIBLE` when `stash` is present; otherwise `HIDDEN`.
- Candidate `VISIBLE` when the snapshot projection is `AVAILABLE` or `LOCKED`.
- Candidate `HIDDEN` when a valid snapshot projection is `HIDDEN`.
- Candidate `UNAVAILABLE` on a candidate failure.

### Destination

- Compare destinations only when both sources are available.
- The legacy destination is the Warehouse route.
- The candidate destination must be `city.warehouse.interior` and map to the Warehouse route.
- When access is blocked on either side, destination is `NOT_APPLICABLE`.
- A missing or unexpected available destination is a divergence.

Each dimension resolves to `MATCH`, `DIVERGED`, `NOT_APPLICABLE`, or `UNAVAILABLE` as appropriate.

## Known expected result

For a profile without `stash`:

- Access: `MATCH` because both sources deny entry.
- Visibility: `DIVERGED` because legacy hides Warehouse while the snapshot exposes a locked location.
- Destination: `NOT_APPLICABLE`.
- Overall outcome: `DIVERGED`.

This is useful evidence, not a test failure. A later activation design must explicitly choose whether normal players should continue seeing nothing or should see a disabled Warehouse destination.

For a profile with `stash`, access, visibility, and destination are expected to match.

Developer Mode's unrestricted preview is applied outside this comparison and remains unchanged.

## Diagnostics

Emit one structured local marker using only allowlisted values. The shape is:

```text
PARTY_FORGE_CITY_ACCESS_SHADOW location=city.warehouse outcome=<MATCH|DIVERGED|UNAVAILABLE> access=<MATCH|DIVERGED|UNAVAILABLE> visibility=<MATCH|DIVERGED|UNAVAILABLE> destination=<MATCH|DIVERGED|NOT_APPLICABLE|UNAVAILABLE> legacy_access=<AVAILABLE|BLOCKED> candidate_access=<AVAILABLE|BLOCKED|UNAVAILABLE> reason=<allowlisted-reason>
```

- `MATCH` may use ordinary diagnostic output.
- `DIVERGED` and `UNAVAILABLE` use developer warnings.
- Reasons are selected from a closed allowlist owned by the comparator.
- Raw parser text, filesystem paths, profile IDs, display names, and arbitrary exception text are forbidden.
- The comparator retains only the last emitted comparison tuple in process memory.
- Repeated refreshes with the same tuple emit nothing.
- A changed tuple emits a new marker.
- Disabling shadow mode clears the in-memory tuple so re-enabling it emits fresh evidence.
- Nothing is written to profiles, settings beyond the existing toggle, analytics, or report files.

## Failure behavior

Snapshot open, size, decode, duplicate-key, parse, validation, loader-contract, evaluator-input, unknown-location, or destination-contract failures produce `UNAVAILABLE` with a sanitized reason.

On every candidate failure:

- The authoritative legacy projection remains unchanged.
- Warehouse route authorization remains unchanged.
- Developer Mode preview remains unchanged.
- No profile or settings data is mutated.
- No fallback snapshot or Latticewright document is loaded.

Legacy is not a fallback chosen after candidate failure; it remains the only authoritative source throughout this shadow phase.

## Testing strategy

### Unit coverage

- `WarehouseAccessPolicy` resolves unlocked, locked, invalid, duplicate, and later-input-mutation cases without mutating the profile.
- Comparator gating covers flag-off, Player Mode, Developer Mode plus flag-on, and disabling/re-enabling.
- Unlocked Warehouse produces access, visibility, and destination matches.
- Locked Warehouse produces access match, visibility divergence, and destination not applicable.
- Candidate hidden, locked, available, malformed, unknown-location, and failed-load outcomes normalize deterministically.
- An unexpected available destination produces a destination divergence without navigation.
- Diagnostic fields and reasons reject uncontrolled values.
- Deduplication emits once per tuple and re-emits after a tuple change or disable/re-enable cycle.

### Integration coverage

- Enabling shadow mode leaves the main-menu projection byte-for-byte or field-for-field identical to the legacy projection.
- Direct Warehouse route invocation still performs its authoritative settings/profile recheck.
- Developer Mode opens Warehouse without `stash` exactly as before.
- Player Mode with and without `stash` behaves exactly as before.
- Snapshot failure cannot hide, reveal, enable, disable, or open Warehouse.
- Profile serialization and settings persistence are unchanged by comparison.

### Verification gates

Run the focused suites for City access provider/evaluator, main-menu view model, main wiring, settings, profile persistence, and generated snapshot artifacts. Then run the dedicated City access integration runner and complete Party Forge test suite. Scan accepted logs for test, parse, script, load, and resource-loader failures while retaining expected negative-path diagnostics.

## Acceptance criteria

The pilot is acceptable only when all of the following are demonstrated on one exact commit:

- Shadow mode is default-off and Developer Mode-only.
- Legacy projections and route behavior are unchanged in every tested state.
- Developer preview remains unrestricted.
- Only `city.warehouse` is evaluated.
- Unlocked profiles report full parity.
- Locked profiles report access parity and the known visibility divergence.
- Candidate failures report `UNAVAILABLE` and do not change behavior.
- Diagnostics are sanitized, local-only, and deduplicated.
- No profiles, snapshots, authoring projects, or Latticewright files are modified by observation.
- Focused, integration, and full-suite verification passes.

## Rollback and later activation gate

Immediate operational rollback is the existing **Use City Access Snapshot** toggle. Code rollback is isolated to the policy extraction, sidecar comparator, its orchestration call, and tests.

This pilot does not authorize snapshot-driven behavior. A later activation phase requires:

1. Review of captured match, divergence, and unavailable evidence.
2. An explicit decision on hidden versus visible-locked Warehouse presentation.
3. A separately approved design for making the candidate authoritative.
4. A retained, tested rollback path.

No other City location may be activated until it has a real Party Forge destination and its own approved consumer contract.
