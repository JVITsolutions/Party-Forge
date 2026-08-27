# Party Forge Latticewright City Access Snapshot Design

Date: 2026-08-27
Status: Approved design, pending written-spec review and implementation plan
Branch: `feature/latticewright-v3-portfolio`

## Objective

Prove a replaceable Latticewright-to-Party-Forge authoring path through one
small vertical slice: City tutorial access and visibility.

The slice covers the Apothecary, the road to the Coliseum, the Scholar's
Archive, and City-tree-gated access to the Inn, Merchant, Warehouse, and
Smithy. It does not apply permanent stats, alter profile saves, build City
scenes, or make Latticewright a runtime dependency.

The key product constraint is expected Latticewright churn. Party Forge must
remain functional when a Latticewright document format or adapter becomes
obsolete. The game therefore consumes only a checked-in Party Forge-owned
snapshot. Latticewright formats exist only at an explicit development-time
translation boundary.

## Current Context

Party Forge currently consumes a fixed format-1 City passive-tree runtime and
owns typed profile state, passive-effect resolution, feature access, and save
compatibility. The current profile already records:

- `prologue_state`;
- `permanent_feature_unlocks`;
- `discovered_buildings`;
- `discovered_trees`; and
- City-tree allocations.

The retained Latticewright portfolio contains format-3 City, class, and
building progression projects, but those artifacts are design data. Their
effects and requirements are intentionally empty, and Party Forge does not
consume them at runtime.

Latticewright 0.5.0 provides native graph portals and runtime-v3 exports, but
its format is not a Party Forge stability contract. The first City Access
slice must remain valid even if runtime-v3 is replaced shortly afterward.

## Approved Decisions

- Party Forge loads only checked-in Party Forge-owned snapshots.
- The first slice covers City tutorial visibility, access, and navigation
  destinations only.
- Permanent stat effects and balance are deferred.
- Snapshot generation is an explicit developer command that produces a
  reviewable Git diff.
- Unsupported Latticewright formats are zero-write failures.
- The current format-1 City path remains intact as the rollback baseline.
- The candidate consumer is behind a default-off developer-only flag.
- Existing profile and save formats are unchanged.
- The Party Forge contract is deliberately minimal rather than a second
  general graph runtime.

## Scope

The design includes:

- a dedicated Latticewright City Access authoring graph;
- a version-specific runtime-v3 importer;
- a deterministic Party Forge access snapshot;
- a strict Party Forge snapshot loader;
- an immutable access evaluator over existing profile state;
- a developer-only provider-selection seam;
- failure-atomic snapshot generation;
- focused unit, integration, determinism, and rollback qualification; and
- explicit acceptance gates before activation.

The design excludes:

- automatic import during game launch, editor launch, CI, or ordinary builds;
- loading Latticewright project or runtime files in the game;
- a generalized expression language;
- Latticewright effect execution inside Godot;
- profile mutation, save migration, rewards, stats, or passive allocation;
- Apothecary, Coliseum, Scholar's Archive, or broader City scene production;
- merging the retained Latticewright portfolio branch;
- activation in ordinary player builds;
- World Atlas, quest/world-state, class-skill, battle-zone, or dungeon-grammar
  snapshots; and
- removal of the current format-1 City runtime.

## Compatibility Architecture

The integration has four isolated layers:

```text
Latticewright export
    -> version-specific development importer
    -> Party Forge access snapshot
    -> Party Forge access evaluator
```

### Latticewright export

The export is authoring input only. It may change whenever Latticewright
changes. It is never loaded by a shipping Party Forge build and is never a
required file on a player's machine.

### Version-specific importer

The first adapter accepts exactly the approved Latticewright runtime-v3 City
Access contract. A later Latticewright format receives a separate importer.
The new importer must produce the same Party Forge snapshot contract or an
explicitly reviewed later snapshot version.

No gameplay code imports, references, or branches on Latticewright types or
version numbers.

### Party Forge snapshot

The checked-in snapshot uses Party Forge's own identity and schema version. It
contains only stable location IDs, destination IDs, visibility and
availability conditions, and source provenance.

Snapshot version 1 treats the three producer identity fields as bounded opaque
provenance. `source.adapter` and `source.format` are nonempty stable strings of
at most 128 UTF-16 code units. `source.formatVersion` is an integer from 1
through 2,147,483,647. Runtime loading and evaluation retain these values for
diagnostics but do not interpret them or compare them with a Latticewright
version. The version-specific development importer remains responsible for
requiring its exact source format, source version, and adapter identity before
it emits the snapshot.

It contains no source filesystem paths, Latticewright graph records, editor
workspace state, arbitrary extensions, display layout, scripts, effects, or
runtime resource references.

### Party Forge evaluator

Typed Godot code validates and evaluates the snapshot against an immutable
view of existing `ProfileState`. It answers only whether a known location is
hidden, locked, or available and which semantic destination is associated with
it.

The evaluator does not load scenes, mutate saves, grant unlocks, apply effects,
or discover files.

## Dedicated City Access Authoring Graph

The first import source is a dedicated Latticewright project and graph rather
than the City passive tree. The two domains answer different questions:

- the City passive tree records allocation topology and progression rewards;
- the City Access graph records which semantic locations may be seen or
  entered for a given existing profile state.

The proposed checked-in design artifacts are:

```text
design/progression/latticewright/party-forge-city-access.pstree
design/progression/latticewright/party-forge-city-access.pstree.json
```

The graph uses stable Party Forge semantic IDs. Its location content type has
these required typed fields:

- `party-forge-location-id`: stable Party Forge location identity;
- `party-forge-destination-id`: semantic navigation destination owned by
  Party Forge; and
- `party-forge-visibility-policy`: either `visible` or
  `hidden_until_available`.

The first importer recognizes only these typed access requirements:

- `party-forge-prologue-state`, with one exact state value; and
- `party-forge-permanent-unlock`, with one exact Party Forge unlock ID.

The authoring graph may contain layout and navigation relationships for human
understanding, but only the approved fields and requirements enter the Party
Forge snapshot. Any effect on a City Access location is forbidden in this
slice. Unknown requirement IDs, extra required fields, ambiguous locations,
or effect records reject the whole import.

## Party Forge Snapshot Contract

The generated artifact is:

```text
data/world/access/party-forge-city-access.snapshot.json
```

Its logical shape is:

```json
{
  "format": "party-forge-access-snapshot",
  "version": 1,
  "source": {
    "adapter": "latticewright-runtime-v3-city-access",
    "format": "latticewright-progression",
    "formatVersion": 3,
    "sha256": "0000000000000000000000000000000000000000000000000000000000000000"
  },
  "locations": [
    {
      "id": "city.scholars_archive",
      "destinationId": "city.scholars_archive.interior",
      "visibleWhen": [
        { "kind": "prologue_state", "value": "completed" }
      ],
      "availableWhen": [
        { "kind": "prologue_state", "value": "completed" }
      ]
    }
  ]
}
```

### Canonicalization

- Root keys and record keys are emitted in one fixed order.
- Locations are ordered by ordinal location ID.
- Conditions are ordered by kind and then value.
- IDs are normalized only by validation; the importer never silently rewrites
  an ID.
- The snapshot contains no generation timestamp or machine-specific value.
- Reimporting identical semantic input produces byte-identical output.
- Reordering semantically unordered Latticewright input does not alter output.
- The exact imported source-byte SHA-256 is retained for traceability.
- The exact pretty-printed UTF-8 byte sequence is validated through the
  production byte loader before it may be staged or promoted.

### Bounds

Snapshot version 1 accepts at most:

- 1 MiB of UTF-8 JSON, inclusive;
- 256 locations;
- eight visibility conditions per location;
- eight availability conditions per location; and
- 128 UTF-16 code units for each stable ID or condition value.

The same 128-unit text bound applies independently to `source.adapter` and
`source.format`. `source.formatVersion` must be in the positive signed 32-bit
range. The 1 MiB ceiling applies to the exact canonical bytes written to disk,
not a smaller compact serialization used during in-memory validation.

These are access-snapshot limits, not Latticewright or Party Forge portfolio
limits. Larger future domains should use separate snapshots or an explicitly
reviewed later format rather than silently expanding this contract into a
general graph database.

### Conditions

The runtime supports only:

- `always`;
- `prologue_state`;
- `permanent_unlock`;
- `discovered_building`; and
- `discovered_tree`.

All conditions in one list must pass. There is no nesting, negation, arbitrary
comparison, code expression, or user-defined operator.

`visibleWhen` determines whether the location exists in a player-facing
projection. `availableWhen` determines whether it may be entered. A visible
location whose availability conditions fail is locked. A hidden location never
exposes a destination.

## First-Slice Location Semantics

The approved first snapshot represents:

| Location | Visibility | Availability |
| --- | --- | --- |
| Apothecary | Visible | Always available while the City access provider is used |
| Coliseum road | Visible | Always available; this slice defines no post-prologue closure |
| Scholar's Archive | Hidden until prologue completion | Available after prologue completion |
| Inn | Visible | Requires permanent unlock `service:hero_registry` |
| Merchant | Visible | Requires permanent unlock `service:city_vendors` |
| Warehouse | Visible | Requires permanent unlock `stash` |
| Smithy | Visible | Requires permanent unlock `service:equipment_upgrading` |

These IDs consume current Party Forge resolver output. The snapshot does not
grant those unlocks. The City passive-tree progression service remains the
authority that records them in the profile.

Prologue completion already discovers the City tree and records the City root.
The Scholar's Archive access result provides the future navigation seam through
which the City tree can be introduced; this slice does not change discovery or
allocation behavior.

## Explicit Import Workflow

The importer is a headless Godot tool under Party Forge's existing toolchain.
The intended invocation from the Party Forge repository root is:

```text
Godot --headless --path . \
  --script tools/import_latticewright_access_snapshot.gd \
  -- --source design/progression/latticewright/party-forge-city-access.pstree.json
```

The source path is mandatory and explicit. The destination is fixed by the
tool; callers cannot redirect writes to an arbitrary path. The importer never
searches a directory or reads the installed Latticewright library or portfolio
catalog.

The command performs these stages:

1. Resolve and validate the explicit source as an ordinary file.
2. Read at most the runtime-v3 64 MiB UTF-8 limit, reject malformed UTF-8 and
   duplicate JSON keys before parsing, and calculate the exact-byte SHA-256.
3. Require the exact supported Latticewright runtime-v3 root contract.
4. Validate the dedicated City Access schema and reject forbidden content.
5. Translate recognized records into Party Forge snapshot records in memory.
6. Canonicalize the complete output, then validate the exact canonical bytes
   with the production snapshot loader, including the 1 MiB ceiling.
7. Compare candidate bytes with the current checked-in snapshot.
8. Return success without writing when the bytes are already identical.
9. Otherwise promote the validated candidate through Party Forge's generated
   JSON transaction boundary.
10. Re-read and verify the promoted bytes before reporting success.

Temporary, backup, and cleanup-debt artifacts are confined to a tool-owned
ignored staging root. They never become runtime inputs. Before target mutation,
the writer persists and verifies a recovery record plus the exact prior
generation, or a verified record that the target was absent. The recovery
record remains until either the canonical candidate is verified as committed
or the prior state is restored and re-read exactly. A later invocation resolves
an interrupted transaction before starting a new one. A post-commit cleanup
failure reports that the new snapshot committed plus retained cleanup debt; it
does not claim that the import failed or silently roll back valid committed
bytes.

Generated-write results use exact keys `ok`, `state`, `cleanupDebt`, `stage`,
and `reason`. `state` is one of `unchanged`, `rejected`, `committed`, or
`indeterminate`:

- `unchanged` means the current target already equals the canonical candidate;
- `rejected` means the prior bytes, or prior absence, were re-read and verified;
- `committed` means the exact canonical candidate was re-read and verified; and
- `indeterminate` means neither state could be verified, so recovery evidence
  is retained beneath the staging root and the result must not be described as
  an ordinary rejection.

The generated writer owns interrupted-transaction recovery, current-target
comparison, replacement, verification, and rollback as one boundary. The CLI
does not perform an independent second restoration protocol. This ensures every
invocation resolves a retained recovery record before an `UNCHANGED` comparison
can bypass the writer.

The command prints one grep-friendly terminal marker describing `UNCHANGED`,
`IMPORTED`, `REJECTED`, or `INDETERMINATE`, along with the adapter ID and
sanitized stage. `REJECTED` is permitted only for a verified prior state;
`INDETERMINATE` exits nonzero and preserves the recovery evidence. The command
does not print arbitrary source contents or machine-specific source paths into
the generated snapshot.

## Runtime Components

### `CityAccessSnapshotLoader`

The loader accepts only the exact Party Forge format and version, validates
bounded opaque source provenance, enforces all bounds, rejects unknown keys and
condition kinds, validates unique stable IDs, and returns either one complete
immutable snapshot or a diagnostic. It never returns partially usable
locations. Path loading checks the file length before allocating its buffer and
verifies that the requested byte count was read without an I/O error.

### `CityAccessEvaluator`

The evaluator receives one validated snapshot and an existing `ProfileState`.
It returns an immutable projection for each known location:

- `HIDDEN`: visibility conditions fail;
- `LOCKED`: visibility passes but availability fails; or
- `AVAILABLE`: both condition lists pass.

The projection includes the stable location ID, state, stable reason ID, and a
destination ID only for `AVAILABLE`. It does not expose mutable profile arrays.
Unknown location IDs return a fail-closed hidden result with a diagnostic.

### `CityAccessProvider`

The provider is the consumer seam used by future City/world code. The
default-off project-level developer setting selects the snapshot provider only
when Developer Mode is active. The setting is not stored in `ProfileState` and
does not alter save bytes.

When the setting is off, Party Forge follows the current format-1 City path.
When the setting is explicitly on, missing or invalid snapshot data reports a
prominent candidate diagnostic and returns no candidate access. It does not
silently fall back and disguise a broken candidate. Disabling the setting
restores the untouched legacy path.

No ordinary player build activates the snapshot provider in this milestone.

## Failure Handling

- Unsupported Latticewright version: reject before translation and write
  nothing.
- Malformed, duplicate-key, oversized, or non-UTF-8 source: reject and preserve
  prior bytes.
- Duplicate project, graph, location, or destination identity: reject the
  complete import.
- Missing or broken source reference: reject the complete import.
- Unknown requirement or any effect: reject the complete import.
- Invalid generated snapshot: reject before promotion.
- Canonical generated bytes over 1 MiB: reject before staging or promotion.
- Promotion failure: restore and verify the prior state before reporting
  `REJECTED`; otherwise retain recovery evidence and report `INDETERMINATE`.
- Promoted-byte verification failure: restore and re-read the exact prior state
  before reporting `REJECTED`; failed or unverifiable restoration reports
  `INDETERMINATE`.
- Invalid checked-in snapshot while the developer flag is on: expose no
  candidate access and leave profile/save state unchanged.
- Unknown runtime location: hidden, unavailable, and diagnostic.

No failure may mutate `ProfileState`, rewrite a Latticewright source, activate
the new provider, or delete the format-1 fallback.

## Test Matrix

### Importer and snapshot contract

- Exact valid runtime-v3 City Access source imports successfully.
- Identical repeated import returns `UNCHANGED` with byte parity.
- Semantically irrelevant source ordering produces identical output.
- Unsupported format versions reject with zero writes.
- Malformed JSON, invalid UTF-8, oversize source, duplicate IDs, missing
  destinations, unknown requirements, and effects reject with zero writes.
- Injected failures at read, translate, validate, stage, promote, verify, and
  cleanup boundaries produce truthful outcomes and preserve the required
  generation.
- Source hash matches the exact imported bytes.
- Snapshot loader rejects unknown root and nested keys.
- Snapshot loader accepts bounded non-Latticewright provenance while the
  runtime-v3 importer still requires its exact Latticewright contract.
- Snapshot limits accept exact boundaries and reject limit plus one.
- A combined multibyte maximum construction is rejected when its exact
  pretty-printed canonical bytes exceed 1 MiB, even if compact JSON fits.
- Oversized path input is rejected before buffer allocation, and short/error
  reads are rejected.
- Interrupted transactions recover on the next invocation; injected restore
  failures report `indeterminate`/`INDETERMINATE` and retain recovery evidence.

### Access evaluation

- Prologue not started and in progress: Apothecary and Coliseum road are
  available; Scholar's Archive is hidden; the other buildings are locked.
- Prologue completed: Scholar's Archive becomes available without changing the
  save or awarding any unlock.
- Each exact City-tree unlock exposes only its intended building.
- Repeated and reordered profile arrays produce the same projection.
- Unknown unlocks grant nothing.
- Missing, unknown, or malformed location records fail closed.
- Evaluation leaves `ProfileState.to_dictionary()` and encoded profile bytes
  unchanged.

### Provider and rollback

- Developer flag off uses only the existing format-1 path.
- Developer flag on outside Developer Mode cannot activate the candidate.
- Developer flag on with valid data selects the snapshot provider.
- Developer flag on with invalid data reports a candidate failure without
  silent legacy fallback.
- Turning the flag off restores legacy behavior immediately.
- Existing profiles in every prologue state load without schema migration.
- The full existing Party Forge test suite remains green.

### Headless acceptance

A headless integration runner imports the exact checked-in City Access source,
verifies expected snapshot bytes, loads the production snapshot, evaluates the
complete profile-state matrix, proves save-byte immutability, exercises the
developer-provider seam, and verifies rollback to the format-1 path.

## Acceptance Boundary

The milestone is accepted only when all of the following are true:

- the exact design source and runtime-v3 export are committed;
- the explicit importer and snapshot loader pass failure-atomic tests;
- the generated Party Forge snapshot is deterministic and reviewable;
- evaluator tests prove the approved tutorial and building states;
- profile and save bytes remain unchanged;
- the developer flag defaults off and cannot activate in Player Mode;
- the current format-1 City path remains present and qualified;
- a headless candidate/rollback flow passes from clean state; and
- no ordinary build, main branch, release artifact, or player profile is
  activated or changed without a later explicit approval.

Implementation completion does not authorize merging the retained worktree,
enabling the provider by default, deleting format-1 data, building City scenes,
or treating Latticewright as a stable runtime dependency.

## Evolution Policy

Latticewright adapters are expected to be temporary. Snapshot version 1 is the
stable Party Forge boundary.

When Latticewright changes:

1. Preserve the last valid checked-in snapshot and importer.
2. Add a separate importer for the new source format.
3. Generate both importers' snapshots from semantically equivalent fixtures.
4. Require canonical Party Forge snapshot parity or explicitly review the
   intended semantic delta.
5. Keep gameplay and save tests unchanged.
6. Retire the old importer only after the new adapter, parity evidence, and
   rollback path are approved.

Future World Atlas, quest, class-skill, and dungeon-grammar work may reuse the
same translation pattern. It must not add generic graph execution to this City
Access snapshot. Each broader domain receives its own bounded design and
approval gate.

## Implementation Planning Gate

This document authorizes no implementation by itself. After written-spec
review, the next step is a separate implementation plan. That plan must retain
the existing worktree and approval boundaries, use test-driven development,
and stop before merge, activation, release, or world-scene work.
