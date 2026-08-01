# Party Forge Meta-Progression Implementation Sequence

**Source design:** `docs/superpowers/specs/2026-08-01-meta-progression-profile-passive-tree-design.md`

The approved design is intentionally split into four sequential implementation plans. Each plan must leave the project playable and must pass its own automated, import, and manual approval gates before the next plan is written against the resulting code.

## Plan 1: Profile Persistence Foundation

**File:** `docs/superpowers/plans/2026-08-01-profile-persistence-foundation.md`

Build versioned profile state, atomic JSON persistence, verified backups, profile indexing, unique local profile creation, idempotent mutations, a Profiles Settings tab, and a boot-time profile requirement without replacing the current arena front end.

## Plan 2: Passive-Tree Runtime and Progression

**Planned file:** `docs/superpowers/plans/2026-08-01-passive-tree-runtime-and-progression.md`

Revise the City tree through the Passive Skill Tree Creator, import both `.pstree` source and `.pstree.json` runtime export into Party Forge, validate topology and effects, implement universal Passive Points, connected allocation, progressive fog, refunds, permanent features, class dormancy, effect scopes, and profile persistence through Plan 1's mutation boundary.

**Depends on:** Plan 1 profile store, profile manager, and mutation service.

## Plan 3: Evolving City Menu and One-Time Prologue

**Planned file:** `docs/superpowers/plans/2026-08-01-evolving-city-menu-and-prologue.md`

Build the blocked-out live city menu, initial Play/Settings/Quit presentation, complete camera flight, tutorial handoff, resumable prologue checkpoint, atomic first Passive Point reveal, returning-player run setup, city-building routing, accessibility drawer, Manual Save, mode-aware Save & Quit, and Developer Quick Start.

**Depends on:** Plan 1 profile states and transactions; Plan 2 City Heart and unlock services.

## Plan 4: Per-Profile Run Context and First Services

**Planned file:** `docs/superpowers/plans/2026-08-01-multiplayer-run-context-and-first-services.md`

Introduce per-profile squad contexts, additive squad capacity, distance-gated gold and XP, separate character levels and follower growth, per-profile run inventory seams, first 100-slot stash tab, Warehouse tree reveal, ownership-safe item transfer contracts, and recorded 24-character performance baselines.

**Depends on:** Plans 1 through 3.

## Sequencing Rule

Write each later detailed plan only after the preceding implementation is approved and merged. This prevents later plans from guessing file names or interfaces that the earlier milestone changes during review.
