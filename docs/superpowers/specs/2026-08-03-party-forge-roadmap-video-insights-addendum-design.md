# Party Forge Roadmap and External-Lesson Addendum

**Date:** 2026-08-03
**Status:** Approved roadmap direction
**Applies to:** `docs/superpowers/plans/2026-08-01-meta-progression-implementation-sequence.md`

## Decision

Party Forge will continue its approved systems-first roadmap. The project will not interrupt profile, menu, run-context, inventory, equipment, stash, and extraction foundations to polish temporary character art or animations.

The current presentation remains functional scaffolding until the local asset pipeline and Blender workflow can reliably create, revise, import, and validate production-quality modular characters, equipment, animations, and effects.

Lessons from the external comparison game remain relevant, but they are split into:

1. Asset-independent architecture and tooling requirements that should influence work immediately.
2. Presentation-dependent gameplay and polish work deferred until the asset pipeline is ready.

This is an addendum to the approved roadmap, not a replacement for it.

## Product Identity

Recruitable followers alone are not Party Forge's long-term differentiator. The intended identity is:

> A party-building ARPG roguelite where every party member is a complete build and the strongest strategies emerge from interactions between entire characters.

The game should eventually communicate this identity through independent character progression, equipment, skills, passive trees, elements, statuses, role interactions, and party-wide build decisions.

The near-term roadmap builds the ownership, persistence, inventory, progression, and performance foundations required to support that identity safely.

## Current Foundation

The following foundations already exist and should be preserved:

- Versioned local profiles, atomic persistence, recovery, and profile management.
- A typed stat system with capability-filtered display and modifier sources.
- Data-driven classes, traits, upgrades, attacks, and keywords.
- Nine playable class definitions and their presentation contracts.
- Character-ledger pages, per-action combat estimates, pause interfaces, and responsive UI contracts.
- Controller movement and established keyboard, mouse, and controller navigation patterns.
- Shared humanoid presentation contracts, modular equipment slots, equipment bases, and icon content.
- City passive-tree loading, validation, fog of war, allocation, refunds, permanent nodes, effect resolution, persistence, and Developer Mode access.
- A playable arena retained as the development and regression-testing route.

The passive-tree milestone has an automated pass but still requires the recorded user-rendered validation before it is treated as manually approved.

## Revised Roadmap Sequence

### Gate 1: Complete Plan 2 Approval

Run the existing rendered validation matrix for the City passive tree. Confirm mouse, keyboard, and controller interaction; readable layout at 1080p, 1440p, and 4K; persistence; Developer Mode projection; Coming Soon disclosures; and safe unavailable behavior.

No new milestone begins by claiming Plan 2 is completely approved until this rendered gate is recorded.

### Plan 3A: Functional Main Menu

Build the functional front door without waiting for final city assets:

- First-launch profile creation and active-profile routing.
- Play, Settings, and Quit.
- Returning-player run setup.
- Profiles and passive-tree routing.
- Developer Quick Start to the current arena.
- Accessible keyboard, mouse, and controller navigation.
- Blockout or temporary city presentation that can later be replaced without rewriting menu state or profile logic.

The existing class-selection surface remains the proven run-setup destination behind the new menu until its replacement path is validated.

### Plan 3B: Cinematic Prologue Presentation - Deferred

Defer final city art, house art, character-body transition, cinematic camera flight, presentation-quality tutorial staging, and related animation work until the asset pipeline and Blender workflow are ready.

The one-time-prologue state machine, checkpoint, and completion transaction may be designed with Plan 3A where needed, but production presentation assets are not a Plan 3A acceptance requirement.

### Plan 4: Per-Profile Run Context and First Services

Continue with the approved systems foundation:

- One run context per active local profile.
- Profile-owned leader, recruits, inventory, equipment, gold, progression, and future viewport assignment.
- Additive squad-capacity resolution with the leader included.
- Independent character XP and levels.
- Leader-only upgrade-card selection and class-weighted attribute growth for every character.
- Distance-gated gold and XP eligibility.
- Contribution-event seams for damage, healing, prevention, control, buffs, debuffs, and kills.
- Per-profile inventory and equipment ownership boundaries.
- First inventory capacity and the first profile-owned 100-slot stash tab.
- Extraction and ownership-safe transfer transaction foundations.
- Warehouse discovery and its future dedicated passive-tree seam.
- Recorded performance baselines through the current 24-character Developer Mode target.

Inventory, stash, and extraction features remain hidden or marked Coming Soon in Player Mode until their production unlock paths are implemented.

### Equipment and Persistent Loot Loop

After Plan 4 establishes ownership and storage boundaries, implement the usable equipment loop:

- Equipment-sheet interaction and legal item swapping.
- Manual ground-item pickup and controller candidate selection.
- Stable item instances and ownership transactions.
- Rarity, affix, tier, attribute-requirement, and capability-eligibility resolution.
- Ground-item limits and cleanup protection.
- Dropping, transferring, discarding, and destroying items.
- Run loss, extraction, stash persistence, and later bring-in-gear rules.
- Developer tooling for deterministic generation, inspection, and balance testing.

Existing equipment models and icons become the first content set used by this runtime rather than being treated as proof that the full equipment loop already exists.

### Asset-Pipeline and Blender Integration

When the asset pipeline is ready, integrate it through stable presentation contracts rather than replacing gameplay-owned actor wrappers.

The workflow must support:

- Modular bodies, palettes, equipment sockets, and interchangeable equipment.
- Shared rigs and reusable animation sets with class-specific overrides.
- Deterministic source-to-Godot regeneration.
- Import validation and rendered visual-quality review.
- Gameplay-camera contact sheets or equivalent automated review output.
- Safe replacement of temporary art without changing collision, combat, ownership, stats, or save data.

### Party Identity and Synergy Milestone

After the asset pipeline can support readable feedback, implement the stronger public differentiator:

- A generalized status and reaction framework.
- Cross-character application, amplification, consumption, spreading, and detonation of effects.
- Clear source, owner, target, element, damage type, status, and consuming-character attribution.
- Multiple distinct interactions across martial, elemental, divine, support, ranged, and occult roles.
- Per-character and per-player contribution reporting.
- Formation and visual-priority controls for large parties.
- Class-specific silhouettes, attack timing, VFX language, and audio cues.
- A short playable slice that visibly communicates why Party Forge differs from other follower-based survivor games.

Initial example interactions are design references, not locked content:

- Fighter applies Exposed and Marksman consumes or amplifies it.
- Frost Mage freezes and Fighter shatters.
- Rogue poisons and Warlock spreads or detonates the poison.
- Cleric creates a consecrated state that another class converts into an offensive effect.

Final interactions must be authored through shared data contracts rather than hard-coded class-to-class checks.

## External Lessons Applied Immediately

The following requirements do not need final assets and should guide near-term implementation:

### Data-Driven Content

Classes, actions, statuses, reactions, equipment, upgrades, passive effects, and presentation references should use validated definitions and registries. Adding a class must not require copying unrelated combat, stat, UI, or persistence code.

### Performance as a Progression Gate

Party-capacity increases are allowed only after recorded evidence for frame time, physics cost, navigation cost, memory, UI behavior, and readability. Baselines should cover progressive party sizes and escalating enemy, projectile, ground-item, and effect counts.

### Pooling and Budgets

Enemy, projectile, floating-text, pickup, and effect systems should gain pooling or explicit budgets before scale makes allocations and scene churn a crisis. Developer Mode should expose repeatable stress scenarios instead of relying only on ordinary playtests.

### Combat Attribution

Combat events should preserve enough attribution to power contribution reports and later synergies. At minimum, damaging, healing, prevention, control, buff, debuff, status, and kill events need stable source and ownership identities.

### Content Tooling

Repeated authoring work should become validated tools or builders. The next generation of content tools should move toward a unified class-content workflow spanning definitions, actions, eligibility, presentation references, tooltips, test fixtures, and diagnostics.

### Large-Party Readability Contracts

Even before final art exists, gameplay systems should preserve actor ownership, role, formation position, effect importance, and visibility priority so later presentation can filter or emphasize the right information.

## Presentation Work Explicitly Deferred

The following work should not block Plan 3A, Plan 4, or the first equipment runtime:

- Final city skyline and menu environment.
- Final cinematic camera flight and house sequence.
- Production-quality class silhouettes.
- Final character and equipment models.
- Final shared and class-specific animation sets.
- High-rarity lighting, sound, and reveal spectacle.
- Polished status and reaction VFX.
- Large-party formation polish that depends on final character bounds or animations.
- Marketing captures based on temporary art.

These items remain required later; deferral prevents temporary assets from becoming schedule-critical or forcing duplicate polish work.

## Boundaries and Failure Handling

- Asset import failures must not invalidate profile, inventory, item, or passive-tree data.
- Missing presentation assets fall back safely while preserving gameplay identity and collision contracts.
- Unknown status, reaction, equipment, affix, or passive effects fail closed with actionable identifiers.
- Ownership-changing operations remain idempotent and atomic.
- Developer Mode does not permanently grant normal-profile progression unless an explicit test mutation requests it.
- New menu and service failures retain a proven route to the arena during development.
- Parallel asset work and generated editor files are preserved and isolated from roadmap implementation commits.

## Verification Direction

Each roadmap milestone requires evidence proportionate to its risk:

- Focused domain tests for new definitions, transactions, ownership, and progression rules.
- Retained complete-suite coverage for established behavior.
- Real-input and responsive-layout runners for menu, inventory, equipment, passive-tree, and ledger surfaces.
- Rendered user validation for presentation and feel.
- Deterministic asset and content-generation checks.
- Repeatable performance scenarios with recorded counts, settings, hardware context, and results.

A timeout, startup hang, or partial stress run is not a pass. Asset-independent systems and presentation quality are reported as separate gates.

## Completion Criteria for This Roadmap Direction

This addendum is being followed when:

1. Plan 2 receives its remaining rendered approval before being called fully complete.
2. Plan 3A delivers a functional menu without requiring final cinematic assets.
3. Plan 4 establishes per-profile run ownership, rewards, character progression, storage seams, and performance baselines.
4. Equipment runtime consumes stable content and ownership contracts rather than presentation resources alone.
5. Asset-pipeline integration replaces temporary presentation through stable wrappers.
6. The later synergy milestone uses generalized combat/status contracts and visibly differentiates whole-party building.
7. Final art and animation work is not prematurely polished or allowed to block the systems foundation.

## Next Planning Step

After user review of this addendum, write the detailed Plan 3A implementation plan against the merged passive-tree runtime and the live menu/profile interfaces. The plan must preserve the dirty main checkout, use isolated implementation work, and keep Plan 3B presentation assets explicitly out of scope.
