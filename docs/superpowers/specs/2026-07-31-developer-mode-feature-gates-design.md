# Party Forge Developer Mode and Feature Gates Design

**Date:** 2026-07-31
**Status:** Approved for implementation planning

## Purpose

Build a persistent Developer Mode that makes Party Forge faster to test without changing normal player behavior. The milestone adds a tabbed Settings screen to the current class-selection/start screen, captures run-affecting options in an immutable rules snapshot, and centralizes feature access and party-cap decisions behind reusable policies.

The system is deliberately designed as development infrastructure that can survive the later transition to profiles, unlockable systems, local multiplayer, and the evolving city-overlook main menu.

## Product Context

Party Forge will progressively reveal characters, mechanics, passive trees, modes, and meta progression. Developers need immediate access to implemented content while still being able to test what an ordinary player would see.

The two experiences must remain distinct:

- **Player Simulation:** follows player-facing availability and production rules.
- **Developer Mode:** enables development controls and may expose implemented Developer Preview content.

Developer Mode is not the same as unlocking everything. An independent **Unlock All Implemented Content** option bypasses progression checks for implemented content. Content marked **Coming Soon** remains unavailable in every mode.

Until profiles and real unlock conditions exist, all nine currently implemented classes remain available in Player Simulation. This avoids fabricating temporary progression rules that would immediately be replaced by the profile milestone.

## Goals

- Store machine-wide development settings persistently under `user://`.
- Add a tabbed Settings screen reachable from the current class-selection/start screen.
- Show actual keyboard, mouse, and controller bindings from Godot's InputMap.
- Apply run-affecting settings only when a new run starts.
- Separate mutable saved preferences from immutable active-run rules.
- Generalize feature visibility and access beyond the Character Ledger.
- Centralize party-cap decisions and support a safe Developer Mode override from 1 through 24.
- Add whole-party God Mode that preserves damage and healing feedback but prevents party members from dropping below 1 health.
- Add enemy-density control from 0% through 1000% with frame-safety limits.
- Clearly identify development runs through an always-visible HUD badge.
- Scale the Settings UI correctly at 1920x1080, 2560x1440, and 3840x2160.
- Preserve existing gameplay behavior when Player Simulation is active.

## Out of Scope

- Input rebinding.
- Functional Game, Graphics, or Audio settings.
- Applying settings during an active run.
- Persistent player profiles, profile creation, or per-profile preferences.
- Real unlock conditions, run history, or meta progression.
- The future cheat-code entry that reveals Developer Mode in production-facing builds.
- Equipment and inventory implementation.
- Local multiplayer, per-player profile selection, joining, or dynamic cameras.
- Save and Quit Run.
- Removing the current nine classes from Player Simulation.
- Final production visual and audio treatment.

## Core Architecture

### Saved Settings

A machine-wide settings service owns a versioned file at:

```text
user://party_forge_settings.cfg
```

The exact storage format may use `ConfigFile`, but callers interact with typed settings data rather than reading sections and keys directly.

Initial saved values are:

```text
mode: Player Simulation | Developer Mode
unlock_all_implemented_content: bool
god_mode: bool
party_capacity_override: int (1-24)
enemy_density_percent: int (0-1000)
```

Developer values remain saved when the mode returns to Player Simulation. They are visibly inactive and have no runtime effect until Developer Mode is enabled again.

Loading is defensive:

- Missing fields use documented defaults.
- Unknown fields are ignored so newer files can be opened by older code safely.
- Unknown modes fall back to Player Simulation.
- Party capacity is clamped to 1 through 24.
- Enemy density is clamped to 0 through 1000.
- Malformed or unreadable data produces a grep-friendly diagnostic and safe defaults.
- A failed save does not replace the last valid settings file or pretend that persistence succeeded.

The file includes a schema version. Migrations are explicit once a format change requires them.

### RunRulesSnapshot

Starting a run resolves the current saved settings into an immutable `RunRulesSnapshot`. Gameplay systems receive that snapshot or a narrow policy built from it.

The snapshot contains effective values, not merely the raw saved values. In Player Simulation it resolves to production behavior even if non-default Developer values remain stored:

```text
developer_mode_active: false
unlock_all_implemented_content: false
god_mode: false
party_capacity: production capacity
enemy_density_percent: 100
```

In Developer Mode it resolves the enabled overrides. Editing Settings later cannot mutate a run already in progress. This makes a run reproducible and prevents half-updated managers from disagreeing about active rules.

### Policies

Three small policy boundaries consume the snapshot:

- **FeatureAccessPolicy:** resolves feature visibility and activation.
- **PartyCapacityPolicy:** reports the effective capacity and whether another member may join.
- **CombatTestPolicy:** reports party God Mode, enemy density, and other future run-testing rules.

Callers ask these policies questions; they do not inspect Settings controls or config files.

### Future Profile Seam

Machine-wide settings are the only provider in this milestone. The service boundary must allow a later profile provider to supply player-specific preferences and unlock state without changing combat systems.

The future flow is:

```text
machine defaults + selected profile + developer access
                         |
                         v
                 RunRulesSnapshot
```

The later profile milestone will add a profile-creation screen. In local multiplayer, every joining player will be able to select an existing profile or create a new one. This milestone does not build or simulate that behavior.

## Feature Access Model

Feature access combines development state, progression state, and developer permissions. Every gated feature has a stable feature ID and one development state:

- **Hidden:** intentionally absent.
- **Coming Soon:** visible only where the product design calls for a preview, disabled, and never activatable.
- **Developer Preview:** implemented and activatable only in Developer Mode.
- **Available:** implemented and eligible for ordinary player access.

Resolution rules:

1. Coming Soon never becomes functional, including with Unlock All enabled.
2. Developer Preview becomes functional when Developer Mode is active.
3. Unlock All bypasses progression requirements only for implemented content.
4. Player Simulation follows ordinary player visibility and unlock rules.
5. Direct attempts to activate a hidden, locked, or Coming Soon feature are rejected without changing UI state.

The existing ledger-specific gate may be adapted behind this generalized policy, but Settings must not depend on ledger classes. Equipment and Inventory remains Coming Soon in this milestone.

## Settings User Experience

### Entry and Modal Behavior

The current class-selection/start screen gains a **Settings** button. It opens a full-screen modal with five ordered tabs:

1. Game Settings
2. Controls
3. Graphics
4. Audio
5. Additional Settings

The screen supports mouse, keyboard, and controller. Bumpers switch tabs. Cancel returns to the start screen. Focus begins on the active tab's first meaningful control and returns to the Settings button when the modal closes.

All tabs use containers, anchors, size flags, and theme constants rather than physical pixel placement. Focus order is explicit and stable at every target resolution.

### Game Settings

This tab displays a shared **Coming Soon** presentation. It does not show controls that appear editable but silently do nothing.

### Controls

Controls is read-only in this milestone. It queries the active Godot InputMap at runtime and groups actions into understandable sections such as:

- Gameplay.
- Menus.
- Character Ledger.

Each action shows:

- Player-facing action label.
- Keyboard and mouse binding, when present.
- Controller button or axis, when present.
- A clear warning when an expected binding is missing.

The display must reflect the actual project bindings rather than duplicate them in UI constants. Rebinding is clearly labeled as Coming Soon.

### Graphics

This tab displays the shared **Coming Soon** presentation. The responsive verification targets in this design do not imply that resolution selection is implemented here.

### Audio

This tab displays the shared **Coming Soon** presentation.

### Additional Settings

Developer controls live only on this tab:

- Mode: Player Simulation or Developer Mode.
- Unlock All Implemented Content.
- God Mode.
- Party Capacity Override: 1 through 24.
- Enemy Density: 0% through 1000%.
- Apply and Return.
- Cancel.
- Reset Developer Options.

When Player Simulation is selected, the four override controls remain visible with their saved values but use a disabled or visibly inactive presentation. Explanatory text makes clear that they are retained but do not affect play.

The tab always states:

```text
Run-affecting changes apply when the next run starts.
```

**Apply and Return** validates, saves, and closes only after a successful save. **Cancel** discards edits made since the screen opened. **Reset Developer Options** restores safe defaults in the draft UI and still requires Apply to persist them.

## Runtime Integration

### Party Capacity

The ordinary production capacity remains four for the current prototype. `PartyManager.MAX_PARTY_SIZE` may remain as the production default, but gameplay code must no longer compare party size against it directly.

`PartyManager` exposes a single effective capacity boundary, conceptually:

```gdscript
func capacity() -> int
func can_recruit(additional_members: int = 1) -> bool
```

Recruitment, level-up choice generation, upgrade validation, sandbox labels, health lookup, and tests use that boundary. This prevents a Developer Mode party above four from being created successfully and then mishandled by another system still assuming four.

The override supports 1 through 24. Before launch, the start flow validates that the pending starting party fits the effective capacity. An invalid party remains selected, the run does not start, and the UI explains how many slots must be removed or how far the cap must be raised. The system never silently deletes selected characters. The current one-leader start flow therefore remains valid at every supported cap.

Future local players and companions share the same capacity:

```text
human players + recruited companions <= effective party capacity
```

Local multiplayer is not implemented here, but the capacity policy must not encode companion-only assumptions.

### Whole-Party God Mode

`HealthComponent.apply_damage()` is the authoritative damage boundary. Party-owned health components receive a minimum-health rule of 1 when God Mode is active.

God Mode behavior:

- Incoming damage calculations and damage feedback still occur.
- Health changes down to 1 normally.
- Party members do not enter downed or dead state from damage.
- Healing remains functional and visible.
- Enemies and non-party damageables are unaffected.
- Disabling God Mode affects only future runs because it is snapshot-based.

The health component must not query the Settings UI. Ownership or policy configuration is injected when the party combatant is created.

### Enemy Density

Enemy density scales scheduled normal spawning:

- 0% disables scheduled normal enemy spawns.
- 100% preserves current spawn timing.
- 1000% requests ten times the normal spawn rate.

Bosses, scripted encounters, and explicitly spawned test enemies are not implicitly disabled unless their caller deliberately uses the density-aware scheduling path.

The current interval-based `SpawnDirector` may derive an effective interval from density. It also needs a bounded maximum number of scheduled spawns per update so a long frame or extreme density cannot create an unbounded catch-up loop and freeze the game. Any deferred spawn debt must follow a documented deterministic rule rather than growing forever.

### Developer HUD Badge

Every run whose snapshot has Developer Mode active displays a persistent **DEV MODE** badge. It summarizes active overrides, for example:

```text
DEV MODE | UNLOCK ALL | GOD | PARTY 12 | ENEMIES 500%
```

Inactive/default overrides may be omitted. The badge remains visible during ordinary gameplay and must not overlap existing HUD, modal, or safe-area content at supported resolutions. It receives a read-only summary from the run snapshot and cannot mutate settings.

## Data Flow

```text
Start Screen Settings UI
        |
        | validate and save
        v
Machine Settings Service ----> user://party_forge_settings.cfg
        |
        | resolve at Start Run
        v
Immutable RunRulesSnapshot
        |
        +--> FeatureAccessPolicy --> gated UI and content
        +--> PartyCapacityPolicy --> party and recruitment systems
        +--> CombatTestPolicy ----> health, spawning, DEV MODE badge
```

No runtime consumer reaches back into the mutable Settings model.

## Input and Accessibility

- All navigation uses InputMap actions, not raw key-code checks.
- Mouse, keyboard, and controller expose equivalent settings and explanations.
- Tabs, fields, sliders, and buttons have strong visible focus states.
- Control meaning is not communicated only by color.
- Disabled developer controls explain why they are inactive.
- Sliders expose their numeric value in text.
- Bumper navigation skips no tabs, including Coming Soon tabs.
- Tooltips and focus explanations remain within the viewport.
- Scrolling preserves a visible focused control.

## Responsive Layout

The Settings screen is verified at these 16:9 targets:

- 1920x1080 (1080p).
- 2560x1440 (1440p).
- 3840x2160 (4K).

At every target:

- The tab row remains fully visible.
- Labels and values do not collide.
- The Additional Settings controls and action buttons remain reachable.
- The Controls binding rows do not clip or run outside their scroll container.
- Focus outlines and tooltips remain inside the viewport.
- Text remains readable without relying on OS-specific physical pixel sizes.
- The DEV MODE badge does not overlap normal HUD content.

Godot's project stretch behavior and container layout provide scaling. Separate hard-coded layouts for each resolution are not permitted.

## Failure Handling

Failures are conservative and grep-friendly:

- Malformed settings: log the file path and reason, then use safe defaults.
- Unsupported settings version: preserve the file and use the last safely understood values or defaults.
- Failed save: keep the modal open, show an actionable error, and preserve the previous valid file.
- Unknown feature ID: report the ID and deny activation.
- Missing InputMap action: show a visible missing-binding row and report the action ID.
- Invalid party override: clamp during load and reject invalid UI submission before save.
- Invalid density: clamp during load and reject invalid UI submission before save.
- Missing run snapshot: fail safely to Player Simulation rules and emit an explicit diagnostic.
- Invalid party ownership for God Mode: do not protect the entity.

Settings corruption must never implicitly enable Developer Mode.

## Testing Strategy

Implementation follows focused red-green-refactor cycles.

### Settings Tests

- Default file creation and defaults.
- Round-trip serialization for every initial field.
- Schema version handling.
- Missing and unknown fields.
- Invalid mode fallback.
- Party-cap and enemy-density clamping.
- Malformed-file recovery.
- Failed-save behavior preserves the previous valid settings.
- Developer values persist while Player Simulation is selected.

### Snapshot and Policy Tests

- Player Simulation neutralizes every saved developer override.
- Developer Mode resolves enabled overrides.
- A snapshot does not change after the mutable settings model changes.
- Feature states resolve correctly for Player Simulation, Developer Mode, and Unlock All.
- Coming Soon never activates.
- Unknown features deny access.

### Settings UI and Input Tests

- Settings opens from and returns focus to the start screen.
- Tab order is Game, Controls, Graphics, Audio, Additional.
- Bumpers, keyboard, mouse, and controller navigate all tabs.
- Game, Graphics, and Audio clearly show Coming Soon.
- Controls rows are derived from the current InputMap.
- Keyboard, mouse, controller button, controller axis, and missing-binding presentations.
- Player Simulation retains but visibly disables developer options.
- Apply, Cancel, and Reset follow their approved persistence behavior.

### Party Capacity Tests

- Production capacity remains four in Player Simulation.
- Developer capacities at 1 and 24 work.
- Recruit, upgrade validation, level-up choice generation, sandbox display, and member-health lookup use the effective capacity.
- Invalid starting-party/cap combinations cannot begin silently.

### Combat Tests

- Party damage stops at 1 under God Mode.
- Damage and healing signals/feedback still occur.
- Party members do not down or die from damage under God Mode.
- Enemies remain mortal.
- Player Simulation ignores a saved God Mode value.
- Density 0 disables scheduled normal spawns.
- Density 100 preserves baseline timing.
- Density 1000 scales scheduling and respects the per-update safety bound.
- Boss, scripted, and explicit spawn paths retain their documented behavior.

### HUD and Responsive Tests

- Badge is absent in Player Simulation.
- Badge summarizes only the active snapshot.
- UI containment at 1920x1080, 2560x1440, and 3840x2160.
- Focus, scrolling, tooltips, tab row, Settings actions, and HUD badge remain visible at all three targets.

### Completion Verification

- Focused new suites pass.
- The full existing suite passes.
- Godot import and parser validation exit zero.
- No new unexpected warnings or errors appear.
- Live start-screen Settings navigation passes with mouse, keyboard, and controller.
- A fresh run demonstrates snapshot-only application.
- Live Player Simulation and Developer Mode runs demonstrate their distinct behavior.
- Live checks at 1080p, 1440p, and 4K confirm containment and readability.

## Preservation Boundaries

Implementation must preserve:

- User-tuned enemy projectile speed and lifetime.
- Existing stat, class, combat, upgrade, Character Ledger, and pause-menu foundations.
- Current responsive UI behavior.
- All nine current class resources and Marksman wiring.
- GodotSteam and other add-ons.
- Handbook and tutorial content.
- Unrelated user-authored or Godot-generated changes.

No scene save or automated rewrite may overwrite unrelated Resources, scripts, metadata, or UID references.

## Implementation Staging

Detailed planning should divide the work into independently verifiable stages:

1. Typed saved-settings model, versioned persistence, corruption handling, and tests.
2. Immutable run snapshot and the feature, capacity, and combat policy boundaries.
3. Tabbed Settings shell, start-screen routing, Coming Soon tabs, and responsive structure.
4. InputMap-backed Controls page and controller focus behavior.
5. Functional Additional Settings page and persistence flow.
6. Generalized feature access integration, including the existing ledger gate.
7. Effective party-cap integration across every current consumer.
8. Whole-party God Mode integration at the health boundary.
9. Enemy-density scaling and per-update spawn safety.
10. DEV MODE HUD badge and active-rule summary.
11. Full automated, live, controller, and three-resolution verification.

## Acceptance Criteria

The milestone is complete when:

- Settings is reachable from the current class-selection/start screen.
- The five approved tabs appear in the approved order.
- Controls accurately displays current InputMap keyboard, mouse, and controller bindings.
- Game Settings, Graphics, and Audio clearly present as Coming Soon.
- Additional Settings persists Mode, Unlock All, God Mode, party capacity, and enemy density.
- Player Simulation retains but neutralizes developer override values.
- Changes affect the next run only through an immutable snapshot.
- Coming Soon content cannot be unlocked or activated.
- All current party-cap consumers use the effective capacity policy.
- Developer party capacity works from 1 through 24 without silently deleting a pending party.
- God Mode protects only the party at 1 health while preserving feedback and healing.
- Enemy density behaves correctly at 0%, 100%, and 1000% without unbounded work per frame.
- Developer runs display an accurate persistent DEV MODE badge.
- All nine current classes remain available in Player Simulation until profiles exist.
- Mouse, keyboard, and controller provide equivalent access.
- Settings and badge layouts pass at 1920x1080, 2560x1440, and 3840x2160.
- Focused tests, the full suite, import validation, and live verification pass.
- No unrelated user work is overwritten.

## Follow-On Designs

Recommended order after this milestone:

1. **Equipment, Inventory, Items, Rarities, and Affixes**
   - Functional Developer Preview before the player-facing progression unlock.
2. **Persistent Profiles and Progressive Revelation**
   - Profile creation and selection.
   - Per-profile settings and unlock state.
   - Per-player profile selection or creation in local multiplayer.
   - Run history and evolving main-menu presentation.
3. **Local Multiplayer and Dynamic Camera Clustering**
   - Human players consume party capacity.
   - Shared pause with independent character sheets and inventories.
   - Proximity-based camera merge and split groups.
4. **Production Developer-Mode Reveal**
   - Cheat-code entry in Additional Settings when outside testing audiences require it.
