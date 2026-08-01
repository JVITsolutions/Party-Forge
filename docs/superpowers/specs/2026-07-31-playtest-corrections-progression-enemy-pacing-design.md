# Party Forge Playtest Corrections, Progression, and Enemy Pacing Design

**Date:** 2026-07-31
**Status:** Approved
**Scope:** Focused, data-driven correction pass based on the 2026-07-31 five-minute-run playtest notes

## Purpose

This pass fixes the most important correctness and usability problems exposed by the current build, then improves the early-run pacing and level-up presentation without prematurely building the future difficulty, rarity, or meta-progression systems.

The implementation must preserve the current stats backend, expanded class content, targeted-upgrade work, developer settings, character ledger, interactive temporary popups, and all saved local tuning changes. The existing 22 modified project files are user-owned work and must be captured in a clearly named baseline commit before implementation begins; they must not be discarded or overwritten.

## Design Principles

1. **One semantic meaning per combat keyword.** `range` and `area_radius` must behave consistently across party members and enemies.
2. **Data drives tuning.** Timing, enemy weights, projectile behavior, offer counts, recruit odds, and developer controls live in bounded data or policy objects rather than being scattered through UI code.
3. **Simulation results precede presentation.** Upgrade outcomes are selected deterministically before the slot-reel animation begins. Animation cannot alter the result.
4. **Every current party member is inspectable.** The character ledger must remain usable through the developer cap of 24 members, not merely create off-screen controls.
5. **Developer options accelerate testing without changing player defaults.** Overrides persist in settings, are snapshotted for the next run, and remain visually disclosed when active.
6. **Correctness before spectacle.** Pause behavior, targeting geometry, accessibility, and deterministic offers are verified before animation polish or balance conclusions.

## 1. Pause Ownership and Run Timer

### Problem

The run timer continues while the character ledger is open. `GameRun` currently processes while the scene tree is paused and advances elapsed run time unconditionally.

### Required behavior

- Opening the character ledger pauses the entire run.
- The run timer, spawn schedule, combat actors, projectiles, experience, and other simulation systems do not advance while any run-blocking modal state is active.
- The same invariant applies to the pause menu, level-up selection, and results screen.
- UI that must remain interactive while paused may use always-processing behavior, but the run clock must check whether simulation time is permitted before accumulating delta.
- Existing pause ownership remains composable: closing the ledger must not unpause a tree that was already paused by another owner.

The implementation should centralize the decision to advance simulation time in the run state/pause contract rather than special-casing only the ledger.

## 2. Normalized Combat Geometry

### Canonical definitions

- `range`: maximum distance at which an attack, heal, or other targeted action may acquire and affect its primary target. For projectiles, it also determines the projectile's maximum travel distance unless a deliberately separate future property is introduced.
- `area_radius`: radius around the resolved impact point in which additional targets or effects are included.
- `attack_range` stat modifier: scales the action's `range`.
- `area_size` stat modifier: scales the action's `area_radius`.

These meanings apply to every party class and enemy. Tooltips and keywords must use the same definitions.

### Melee and area behavior

- A valid primary target within `range` is always hit.
- Melee area damage is centered on the primary target's impact point, not on the attacker.
- Other valid targets within `area_radius` of the impact point are also hit.
- `area_radius` does not replace `range` during acquisition.
- A zero-radius action affects only its primary target.

This corrects the Rogue issue: the saved Rogue Flurry resource range of `2.0` must extend acquisition reach, while its `area_radius` remains the independent cleave size (currently `0.9`).

### Enemy parity

Current enemy attacks use the same geometry contract. Enemy definitions gain the same tuning hooks for range and area modifiers so future enemy affixes can reuse the contract, but this pass does not migrate enemies into the full party-member `StatResolver` architecture.

### Validation

Attack definitions reject or safely fall back from invalid negative/non-finite geometry. Existing resource values remain authoritative after normalization; tests that encode obsolete values must be updated only where the saved resource is intentionally different.

## 3. Early-Run Enemy Pacing

### Baseline density

The production `100%` enemy-density setting should approximate the intensity of the current `200%` to `250%` experience. This is the new starting balance target, not a final difficulty ceiling.

Spawn interval tuning should be roughly 2 to 2.5 times the current enemy count while preserving deterministic scheduling and bounded performance behavior. Manual testing will decide the exact value inside that range.

### Enemy roster and timing

The new early ranged enemy is the **Boltcaster**:

- medium engagement range;
- stops before firing;
- gives a brief, readable tell;
- fires a red straight projectile toward the player's position captured at fire time;
- the projectile never turns after launch;
- projectile speed, range, damage, area, color, and movement behavior come from data.

The current homing enemy remains the **Spitter**:

- enters later and initially has low weight;
- its homing projectile is purple so behavior is readable before impact;
- homing strength and other projectile properties remain data-driven.

Approved spawn bands:

| Run time | Swarmer | Boltcaster | Spitter |
|---|---:|---:|---:|
| 0–60 seconds | 100% | 0% | 0% |
| 60–150 seconds | 75% | 25% | 0% |
| 150–240 seconds | 60% | 32% | 8% |
| 240–300 seconds | 50% | 35% | 15% |

Weights are relative selection weights, not guaranteed exact population ratios in every short sample.

### Projectile runtime

The projectile runtime supports at least two explicit movement modes:

- `LINEAR`: velocity is fixed from the launch aim and does not retarget.
- `HOMING`: steering follows the configured target and homing parameters.

This is a bounded generalization for current enemies, not a complete projectile-effect framework.

## 4. Level-Up Offer Generation

### Five-card production offer

The default production level-up presents five unique cards. Developer Mode may override the offer count within a safe bounded range for testing. The generation service receives the requested count; the UI must not fabricate or truncate results independently.

### Run variation and determinism

Offers include the run seed and level/offer sequence in their deterministic random stream. The same run state must reproduce the same offer, while separate run seeds should not repeat the same early sequence merely because party size and level match.

### Recruit distribution

When the party has capacity and eligible classes exist, each offer uses this target distribution:

| Recruit cards in offer | Probability |
|---|---:|
| 0 | 45% |
| 1 | 40% |
| 2 | 12% |
| 3 | 3% |

Rules:

- Recruit cards are not guaranteed every level.
- Recruit choices must be unique within the offer.
- The number offered cannot exceed available party capacity or eligible class variety.
- After three consecutive offers with no recruit card, the next eligible offer guarantees at least one recruit card.
- Offers made while the party is full or no classes are eligible do not consume or falsely satisfy drought protection.
- The distribution is a configurable policy so later progression or difficulty systems can modify it without rewriting the UI.

## 5. Class-Rank Presentation

The existing class-rank card text is too generic. The card and its detail tooltip must explain exactly what is changing.

For the current shared class-rank rule, the presentation must include:

- the class being ranked;
- current rank and offered next rank;
- current effect and next effect using resolved numeric values;
- that the benefit applies to all current members of that class;
- that future recruits of the same class inherit the rank;
- the current rule of `20% increased Damage per rank` unless/until the underlying data changes.

Presentation reads from the same progression data that application uses. It must not duplicate the `20%` value as unrelated UI-only logic.

## 6. Experience Multiplier Developer Control

Developer Mode gains an experience multiplier from `100%` through `1000%`.

- The setting persists with the existing settings storage.
- It is available only through the developer-options surface, while its saved value remains intact when Player Simulation is selected.
- The value is snapshotted at run start and clearly labeled **Next Run**.
- Non-default active developer values appear in the existing developer badge/summary.
- Fractional scaled experience is carried between awards so small drops do not lose progress to repeated rounding.
- Level requirements continue increasing with level; this control changes awards, not the progression curve.

Applying developer settings to an already-running simulation is a future feature, not part of this pass.

## 7. Pending-Level Indicator

When at least one level-up choice is pending, the level-up panel displays a gold indicator above **Choose an Upgrade**.

- It includes the number of pending choices, including the currently displayed choice.
- It updates immediately after each selection.
- It uses a restrained glow/pulse to communicate stored rewards without obscuring the cards.
- It remains readable at 720p, 1080p, 1440p, and 4K.
- Reduced-motion mode removes or minimizes the pulse while preserving the count.

## 8. Five-Card Layout and Reveal

### Layout

All five cards appear in one horizontal row at every supported target resolution. At narrower windows, cards become narrower and use shorter visible summaries. Full content remains available through the existing interactive tooltip system.

The layout must preserve:

- unambiguous selected/focused state;
- keyboard, mouse, and controller operation;
- readable rarity/name/rank essentials;
- access to the full scrollable tooltip;
- no card overlap or off-screen confirmation controls.

### Synchronized slot-reel reveal

For each level-up offer:

1. The completed offer is generated and stored before animation starts.
2. All five card shells enter together from above the screen.
3. They settle into their final center-row positions.
4. Each shell rapidly cycles through eligible-looking preview content, creating a slot-reel presentation.
5. All five resolve as one synchronized event in approximately `1.1` seconds.
6. Input unlocks only after resolution or an explicit fast-forward/skip.

Preview cycling is presentation-only. It must not consume gameplay RNG, alter the preselected cards, imply impossible rarity guarantees, or permit selection before resolution.

The reveal supports:

- a single fast-forward input for keyboard/mouse and controller;
- a reduced-motion fallback that resolves quickly without the descent/reel movement;
- deterministic cleanup when the panel closes, a run ends, or another modal takes ownership;
- future hooks for rarity-dependent timing, lighting, sound, and impact effects.

Actual rarity balance, rarity-specific audiovisual effects, and higher-rarity rules are deferred.

## 9. Character Ledger Access Through 24 Members

### Problem

The ledger currently creates roster buttons beyond six, but this is not sufficient. It does not explicitly keep focused or selected off-screen members visible, and the existing test only asserts that seven controls exist. A player can therefore be unable to reach or inspect later members.

### Required behavior

- Every current party member from slot 1 through the developer hard cap of 24 is reachable in the ledger.
- The roster remains a scrollable rail/grid appropriate to the responsive layout.
- Mouse users can use the wheel and drag the scrollbar.
- Keyboard and controller directional navigation proceeds continuously through the entire roster.
- Focusing or selecting an off-screen member automatically scrolls that member fully into view.
- The selected member remains selected when switching between Stats, Current Upgrades, and future Equipment & Inventory pages.
- Rebuilding the roster after recruitment, removal, or data refresh preserves a still-valid selected member and restores its visible position.
- When the selected member no longer exists, the existing controlled/first-member fallback is used and made visible.
- Page shoulder-button navigation must not strand focus or reset selection to one of the first six members.

The `ScrollContainer` focus-follow/visibility behavior and explicit focus ordering must cover both the desktop single-column rail and compact multi-column grid. The design does not introduce pagination because direct continuous navigation better matches the current ledger and party context.

Equipment & Inventory remains **Coming Soon** for players in this milestone. Its eventual implementation must consume the same `selected_member_id`, so no new six-member limitation is introduced later.

### Acceptance proof

Automated coverage must construct a 24-member developer party and prove more than child count:

- member 24 can receive focus through supported navigation;
- the scroll position changes enough to reveal member 24;
- selecting member 24 updates `selected_member_id`;
- Stats reads member 24;
- Current Upgrades reads member 24;
- switching pages preserves member 24;
- returning to member 1 scrolls it back into view;
- desktop and compact layouts both pass the accessibility contract.

Manual validation includes mouse wheel/scrollbar, keyboard navigation, and controller navigation.

## 10. Developer Settings Presentation

The following developer controls participate in the existing settings behavior:

- experience multiplier;
- level-up card count override;
- existing party-capacity override through 24;
- existing enemy-density controls.

Common rules:

- controls remain focusable and controller-operable;
- saved override values are retained when Developer Mode is turned off;
- inactive overrides do not affect Player Simulation;
- non-default active values appear in the developer summary/badge;
- run-scoped values are snapshotted and labeled as taking effect next run.

## 11. Data and Architecture Boundaries

This is the focused **Approach A** correction pass.

Expected bounded components include:

- a single simulation-time eligibility contract for `GameRun`;
- normalized resolved attack geometry used by party and enemy execution;
- a data/config resource for enemy projectile movement and presentation properties;
- a data/config policy for spawn bands;
- a recruit-count/drought policy in level-up generation;
- run-seeded offer streams;
- persistent developer settings with run snapshots;
- a reveal controller/state inside the level-up presentation layer;
- explicit roster focus/visibility behavior in the existing character ledger.

This pass does **not** build a universal effect graph, full enemy `StatResolver`, complete rarity system, Heat system, difficulty selector, inventory/equipment implementation, passive tree, or mid-run settings mutation.

All new tuning resources must validate their inputs and provide safe, grep-friendly errors or conservative fallbacks for missing/invalid data.

## 12. Verification Strategy

### Automated correctness

1. Timer and simulation remain unchanged while ledger, pause, level-up, and results modals own pause.
2. Every current party and enemy attack obeys normalized range/area geometry.
3. Rogue Flurry acquires at range `2.0` while retaining its independent `0.9` cleave radius.
4. Offers vary across run seeds, remain deterministic within a run, contain the configured number of unique cards, obey capacity, and satisfy recruit distribution/drought rules.
5. XP multiplier persists, snapshots, carries fractions, and appears in the developer summary only when active.
6. Class-rank presentation matches the underlying rank application data.
7. Five-card layout, reveal completion, skip, focus lock, tooltip access, and pending count behave at 720p, 1080p, 1440p, and 4K.
8. Boltcaster uses a red linear projectile; Spitter uses a purple homing projectile; spawn bands transition at exact boundaries.
9. The 24-member ledger acceptance proof in Section 9 passes in desktop and compact modes.

### Manual playtests

- Run at production density through the five-minute boss timing and record perceived quiet/deadly sections.
- Verify Boltcaster tell, red projectile readability, and dodgability without speed upgrades.
- Verify later Spitter pressure remains avoidable and visually distinct.
- Complete several seeded and unseeded level-up sequences to evaluate variety and recruit pacing.
- Exercise slot-reel fast-forward, reduced motion, tooltip pinning, mouse scrolling, controller focus, and pending-level chaining.
- Build a 24-member developer party and inspect the last member's stats and upgrades with mouse, keyboard, and controller.

### Regression discipline

- Run the full existing suite after focused tests.
- A timeout is not a pass; bounded batches must be reported with their exact coverage.
- Existing failures caused by intentionally saved resource changes are reconciled explicitly, not hidden by broad test weakening.
- No completion claim is made without recorded test output and a manual-launch smoke check.

## 13. Deferred Backlog

The following ideas are deliberately preserved for later designs:

- selectable difficulty modes;
- a Heat modifier pool and other run difficulty options;
- production party-size progression from one member through the standard cap of six, plus later exceptional increases;
- per-player profiles and split-screen ownership;
- applying developer settings during an active run;
- Skirmisher Archer and Siege Adept enemy candidates;
- complete item rarity tiers and rarity-specific animation, light, and audio;
- inventory/equipment UI and its player unlock timing;
- class passive trees, meta-progression, expanded elements, affixes, and synergy systems.

These deferred systems should reuse the contracts established here rather than changing their meanings.

## Completion Criteria

This correction slice is complete only when:

- all requirements above are implemented without losing the saved baseline work;
- focused and regression tests pass or any unrelated pre-existing failure is named with evidence;
- the game launches successfully;
- a manual run confirms corrected pausing, attack range, five-card selection, enemy timing/readability, and ledger access through member 24;
- implementation documentation identifies the primary data files for future tuning.
