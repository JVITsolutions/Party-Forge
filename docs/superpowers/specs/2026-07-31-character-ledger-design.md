# Party Forge Character Ledger and Run Pause Menu Design

**Date:** 2026-07-31
**Status:** Approved for implementation planning

## Purpose

Build Party Forge's first full-screen, in-run character interface. The Character Ledger gives players a trustworthy view of each party member's resolved stats and current upgrades while establishing a modular page system for future equipment, inventory, passive trees, and other unlockable character systems.

The milestone also adds a separate minimal run pause menu so Character Ledger input does not compete with ordinary pause behavior.

The design takes inspiration from Brotato's quick stat readability, Vampire Survivors' full pause presentation, and Path of Exile's deeper character-sheet and modifier inspection. Party Forge uses its own layout, visual language, data model, and interaction rules.

## Product Context

Party Forge is built around progressive revelation. A new profile eventually begins with one controlled character and unlocks larger parties over time: two, three, four, and ultimately six standard party slots. Exceptional unlocks may permit more than six members.

Future local multiplayer uses the same party capacity. Human-controlled characters and recruited companions both consume slots:

```text
human players + recruited companions <= current unlocked party capacity
```

For example, four local players at a four-member capacity cannot recruit a companion. At a six-member capacity they have two companion slots.

Unavailable members and future capacity are not shown in the ledger. This preserves the game's progressive-revelation model instead of exposing empty silhouettes or a hidden maximum on first launch.

## Goals

- Provide a full-screen, paused Character Ledger opened separately from the run pause menu.
- Display combat's real resolved character values and modifier-source breakdowns.
- Show every current upgrade that affects the selected character.
- Support one through six party members cleanly and exceptional parties through scrolling.
- Provide mouse, keyboard, and controller navigation with equivalent information access.
- Use modular page scenes behind a stable page descriptor contract.
- Prepare page availability for later unlock and Developer Mode systems without implementing those systems now.
- Prepare per-player ledger state and responsive pane boundaries for future local multiplayer.
- Add a minimal run pause menu with Resume, a Settings placeholder, and confirmed Quit Run.
- Preserve all existing gameplay behavior and unrelated user-authored work.

## Out of Scope

- Functional equipment or inventory.
- Persistent profiles, run history, or content unlock evaluation.
- Developer Mode settings, cheat codes, God mode, unlock-all, party-cap overrides, or enemy-density controls.
- Functional graphics, audio, or gameplay Settings.
- Save and Quit Run.
- Character renaming.
- Local multiplayer, joining, controller assignment, split cameras, or dynamic camera merging.
- Changes to current party-cap gameplay rules.
- Passive-tree UI or meta progression.
- Final production art and audio treatment for the ledger.

Developer Mode and generalized feature gates are the recommended next dedicated design milestone. Equipment and Inventory receives its own design after its gameplay and data contracts are ready.

## Approved User Experience

### Opening and Closing

The Character Ledger uses the `character_ledger` input action:

- Keyboard: `Tab` and `I`.
- Controller: View/Back.

The action toggles the ledger. `Escape` or controller Cancel also closes it. Closing restores the run's prior pause condition rather than always resuming.

The ledger may open during:

- Normal run combat.
- Boss combat.
- A level-up pause.

It does not open during:

- Initial class selection.
- Victory.
- Defeat.
- Quit confirmation.

Opening during level-up covers the level-up UI without consuming or changing the offered choice. Closing returns to the same level-up state and leaves the tree paused.

### Separate Run Pause Menu

When the ledger is closed, the `pause_menu` action opens a separate pause menu:

- Keyboard: `Escape`.
- Controller: Menu/Start.

The pause menu contains:

- **Resume:** closes the pause menu and safely resumes the prior run state.
- **Settings:** visible but disabled, labeled **Coming Soon**, with a matching tooltip.
- **Quit Run:** opens a confirmation dialog.

Confirmed Quit Run abandons the active run and emits a front-end routing request. The current route returns to class selection/start. A later main-menu milestone can replace that target with the evolving city-overlook main menu without changing pause-menu code.

If the Character Ledger is open, `Escape` closes the ledger. A later `Escape` from gameplay opens the pause menu.

## Visual Structure

The approved single-player layout is a full-screen **PoE Split Sheet**:

1. Page tabs span the top.
2. A party-member rail occupies the left.
3. The active page's compact values or entries occupy the center.
4. The selected stat or upgrade's definition and source details occupy the right.

The ledger owns the full screen while open. Gameplay is paused behind it.

### Party Rail

The rail contains only current party members. Each entry presents:

- Character name.
- Class.
- Current and maximum health.
- Role.
- Important temporary state when relevant.
- A clear selected-member state that does not rely only on color.

One through six members fit at the normal logical viewport. Exceptional parties above six use a scrollable rail without compressing the page content.

The selected member persists when switching pages. The initial selection is the controlled character. In the current single-player prototype, this is the leader.

## Modular Page Architecture

### CharacterLedger Shell

`CharacterLedger` is an always-processing full-screen UI shell. It owns:

- Opening and closing.
- Pause restoration.
- Page registration and navigation.
- Party-member selection.
- Input focus.
- Responsive layout selection.
- Per-player ledger contexts.

The shell does not contain stat, upgrade, equipment, or other page-specific presentation logic.

### Page Scenes

Each functional page is an independent Control scene implementing a small page contract:

- Receive a ledger context and read-only ledger data provider.
- Activate for a selected member.
- Deactivate without losing shell state.
- Refresh from domain signals.
- Provide an initial focus target.
- Report invalid or empty content safely.

Initial scenes:

- `StatsPage`
- `CurrentUpgradesPage`

Coming Soon descriptors remain focusable for their explanation but do not instantiate a page scene.

### Page Descriptors

A page descriptor provides:

- Stable `StringName` page ID.
- Player-facing label.
- Packed page scene when implemented.
- Display order.
- Feature ID.
- Development state.
- Unlock ID reserved for later profile integration.
- Coming Soon or unavailable explanation.

Resolved page availability supports:

- **Hidden:** absent from navigation.
- **Coming Soon:** visible but disabled.
- **Developer Preview:** functional only when a later Developer Access provider permits it.
- **Available:** visible and functional.

The current development provider exposes:

- **Stats:** Available.
- **Current Upgrades:** Available.
- **Equipment & Inventory:** Coming Soon.

The shell depends on a feature-gate interface, not on profile or Developer Mode implementations. A later provider can combine page development state, build audience, local Developer Mode settings, and profile unlock state.

### Future Production Visibility

Equipment and Inventory follows this progression:

1. During current development, it is visible but disabled as **Coming Soon**.
2. Once functional, Developer Access can expose it regardless of profile progression.
3. Player Simulation and normal production play hide it completely until its progression unlock.
4. An unlocked player profile sees the normal functional page.

The intended player unlock occurs approximately three to five runs into future progression, but the exact condition is deliberately deferred to the unlock-system design.

## Ledger Context and Multiplayer Preparation

Each local player ledger context owns:

- Local player ID.
- Selected member ID.
- Active page ID.
- Last focused control or focus path.
- The player who requested opening when relevant.

Only one context exists in this milestone. The shell API accepts a collection so local multiplayer can later instantiate one responsive ledger pane per active player.

Opening any ledger in future local multiplayer globally pauses the run. Each player may inspect their own pane independently. If gameplay cameras were merged because players were near one another, ledger presentation temporarily restores one pane per player. Closing restores the previous dynamic camera grouping.

Future dynamic camera composition may support player clusters such as:

- `1 + 1 + 1 + 1`
- `2 + 1 + 1`
- `2 + 2`
- `3 + 1`
- `4`

The camera and ledger remain separate systems: gameplay cameras group players, while ledger state belongs to players. Multiplayer close/ready arbitration is deferred to the local-multiplayer design.

## Read-Only Ledger Data Provider

Page scenes receive a read-only data provider rather than searching the scene tree or reading private manager dictionaries.

The provider exposes page-friendly records for:

- Current party members.
- Runtime health and downed state.
- Class identity, rank, role, traits, and capability keywords.
- Resolved stat snapshots.
- Applicable upgrade records.
- Canonical stat, keyword, and upgrade definitions.

The provider adapts existing domain data but does not recalculate combat values. It observes existing signals such as:

- `PartyManager.member_added`
- `PartyManager.stats_changed`
- `PartyManager.upgrades_changed`
- `PartyManager.class_rank_changed`
- `PartyManager.active_traits_changed`
- `HealthComponent.health_changed`
- Downed, revived, and died signals

UI refresh is signal-driven. Opening the ledger also performs a complete initial snapshot.

## Stats Page

### Header

The selected character header shows:

- Character name.
- Class and class rank.
- Role.
- Traits.
- Capability keywords.
- Current and maximum health.

Character names remain read-only. Editing is deferred until the real Equipment and Inventory character sheet exists.

### Groups

The center sheet groups definitions by their registry `ui_group`, presented initially as:

- Overview.
- Offense.
- Defense.
- Resistances.
- Utility.

Universal stats always appear.

Specialized stats appear when:

- The character has a matching capability tag, or
- A relevant modifier source makes the stat meaningful.

A relevant specialized stat remains visible when its effective value is zero. Irrelevant stats remain hidden unless **Show All Stats** is enabled.

### Right Detail Pane

Selecting a stat fills the right pane with:

- Canonical display name and keyword explanation.
- Effective formatted value.
- Minimum, maximum, or cap where defined.
- Base value.
- Every named modifier source.
- Operation type: flat, increased, reduced, more, or less.
- Contextual notes that do not replace canonical definitions.

The page reads:

```gdscript
PartyManager.stats_for(member_id)
ResolvedStatSnapshot.value(stat_id)
ResolvedStatSnapshot.breakdown(stat_id)
```

It uses `StatDefinition.format_value()` and registry metadata. It never implements a second stat formula.

Armor may show an estimated reduction against a clearly labeled reference hit. The estimate must use a shared combat helper or resolver API; it must not be an independent UI approximation.

### Tooltips and Focus

Hovering or focusing any keyword shows its canonical definition. Confirm may pin the detail so the player can move focus without losing it. Missing development definitions show:

```text
Missing definition: <id>
```

## Current Upgrades Page

The page answers:

> What is affecting this character right now?

It includes:

- Personal upgrades.
- Class-specific upgrades.
- Party-wide upgrades.
- Applicable trait or matching-party synergies.
- Existing foundational party-stat or trait ranks that affect the member.

It excludes upgrades that do not affect the selected member.

Repeated upgrades collapse into one entry showing their current rank and maximum rank where useful. Entries use deterministic grouping and ordering and carry ownership badges:

- Personal.
- Class.
- Party.
- Trait.

Each center entry shows:

- Upgrade name.
- Current rank.
- Concise current effect.
- Ownership.
- Relevant keywords.

The right detail pane shows:

- Full description.
- Current resolved effects.
- Source ownership.
- Applicability reason.
- Eligibility rules where useful.
- Canonical keyword tooltips.

The backend adds safe read-only queries for applicable upgrade records. UI code must not inspect `_party_upgrade_ranks`, `_party_upgrade_definitions`, `_party_upgrade_sources`, or member-private collections directly.

A character with no upgrades receives a deliberate **No upgrades acquired yet** state.

## Input and Accessibility

All gameplay UI actions use Godot InputMap actions rather than raw key checks.

Approved behavior:

- `Tab`, `I`, or View/Back: toggle Character Ledger.
- `Escape` or Cancel while ledger is open: close ledger.
- `Escape` or Menu/Start during gameplay: open run pause menu.
- Bumpers: switch available ledger pages.
- D-pad or stick: move through members, entries, and controls.
- Confirm: select a row, activate a valid control, or pin details.
- Cancel: move back or close according to focus depth.

Coming Soon and hidden pages cannot be activated through page-cycle shortcuts. Coming Soon tabs remain focusable so keyboard and controller players can read their explanation.

Accessibility requirements:

- Strong visible focus states.
- Selection communicated by shape, border, label, or icon in addition to color.
- Hover and focus information parity.
- Scrollbars and directional affordances for overflow.
- Readable minimum text size at supported layouts.
- No required information communicated only through animation.
- Tooltips remain inside the owning viewport.

## Responsive Layout

The logical design target is 1920×1080 and must scale correctly to 3840×2160. Godot containers, anchors, size flags, and stretch behavior replace physical-screen coordinates.

At narrow future split-screen pane sizes:

- The party rail remains usable.
- The center values remain the primary surface.
- The right detail pane becomes an overlay, drawer, or stacked panel.
- Text does not shrink below the approved minimum.
- Focus returns to the originating row when a compact detail panel closes.

The current milestone implements and tests the single-player layout plus compact responsive boundaries. It does not create multiple gameplay viewports.

## Pause Ownership and Modal Safety

The ledger records whether the tree was already paused when it opened. Closing restores the recorded condition only if the ledger owns the added pause request.

This prevents:

- Closing a ledger opened during level-up from resuming combat.
- A pause-menu close from dismissing a progression-owned pause.
- Multiple UI systems from blindly assigning contradictory pause state.

Implementation may use a small pause-owner abstraction if necessary, but it must remain scoped to actual modal ownership rather than becoming a general game-state rewrite.

Modal layering and eligibility:

1. Quit confirmation and victory or defeat results have the highest priority.
2. The Character Ledger covers an eligible level-up choice while open; closing reveals the unchanged choice.
3. A level-up choice otherwise remains above the run pause menu and gameplay HUD.
4. The run pause menu remains above the gameplay HUD.

## Failure Handling

Development failures are grep-friendly and preserve a usable run when possible:

- Duplicate page ID: report the ID and exclude the later entry.
- Missing page scene: report the page ID and resource path; exclude it.
- Unknown feature or unlock ID: report the page ID and resolve conservatively.
- Missing stat, keyword, or upgrade definition: display `Missing definition: <id>`.
- Missing selected member: fall back to the controlled member, then the first valid member.
- Empty party: close the ledger safely and report the invalid state.
- Empty applicable upgrades: show the intentional empty state.
- Locked or hidden direct activation attempt: reject without changing the active page.

Required baseline pages failing registration block a completion claim.

## Testing Strategy

Implementation follows focused red-green-refactor cycles.

### Page and Gate Tests

- Stable page registration and ordering.
- Duplicate and missing page handling.
- Hidden, Coming Soon, Developer Preview, and Available states.
- Coming Soon and hidden pages cannot activate through direct or cycle input.
- Equipment and Inventory resolves to Coming Soon under the current provider.

### Party and Context Tests

- One-member rail.
- Six-member rail without overflow.
- More-than-six-member scrolling.
- Hidden unavailable capacity.
- Stable selected member across pages.
- Missing-member fallback.
- Independent local-player context objects.

### Stats Tests

- Universal visibility.
- Capability visibility.
- Modifier-caused visibility.
- Relevant zero-value visibility.
- Show All Stats.
- Grouping and formatting through `StatDefinition`.
- Displayed effective values match `ResolvedStatSnapshot`.
- Source rows match `ResolvedStatSnapshot.breakdown()`.
- Keyword and missing-definition behavior.

### Upgrade Tests

- Personal and class-specific records.
- Applicable party and trait records.
- Irrelevant upgrade exclusion.
- Rank collapsing.
- Ownership labels.
- Empty state.
- Read-only query behavior.
- Display values derived from definitions and domain state.

### Pause and Input Tests

- Open and close from running combat.
- Open and close from boss combat.
- Open and close during level-up while preserving pause.
- Character Ledger and pause-menu actions do not conflict.
- Resume returns safely.
- Quit Run requires confirmation.
- Confirmed Quit Run emits the front-end routing request.
- Keyboard, mouse, and controller focus paths.

### Responsive Tests

- 1920×1080.
- 3840×2160.
- Compact future player-pane widths.
- Tooltip and detail-pane containment.
- Focus restoration after compact details close.

### Completion Verification

- Focused new suites pass.
- Full existing suite passes.
- Godot import/parser validation exits zero.
- No new unexpected warnings or errors.
- Live run confirms Stats, Current Upgrades, Coming Soon, level-up restoration, pause menu, and Quit Run routing.
- Controller manual smoke verifies page, member, row, detail, close, and pause navigation.

## Preservation Boundaries

Implementation must preserve:

- User-tuned enemy projectile speed and lifetime.
- Existing stat, class, combat, and upgrade foundations.
- Current responsive UI work.
- GodotSteam and other add-ons.
- Handbook and tutorial content.
- Existing formatting-only local modifications.
- Unrelated Godot-generated metadata.

No implementation step may use a scene save operation that rewrites unrelated Resources or UID references.

## Implementation Staging

Planning should divide work into independently verifiable stages:

1. Input actions, page descriptors, gate provider, player context, and registration tests.
2. Read-only ledger data provider and domain query additions.
3. Ledger shell, party rail, page switching, focus, and pause ownership.
4. Stats page, contextual visibility, details, breakdowns, and tooltips.
5. Current Upgrades page and applicable-upgrade queries.
6. Coming Soon Equipment and Inventory state.
7. Minimal run pause menu and front-end Quit Run routing.
8. Responsive and controller behavior.
9. Full integration, documentation, and live verification.

## Acceptance Criteria

The milestone is complete when:

- `Tab`, `I`, and controller View/Back open and close the ledger.
- `Escape` closes an open ledger and otherwise opens the run pause menu.
- Stats and Current Upgrades are functional pages.
- Equipment and Inventory is visibly disabled as Coming Soon under the current development provider.
- Only current party members appear.
- One through six members fit, and larger parties scroll.
- Selected member persists across pages.
- Contextual stats and Show All Stats behave as designed.
- Displayed values and modifier sources match the combat resolver's snapshot.
- Current Upgrades includes every and only upgrade affecting the selected member.
- Mouse, keyboard, and controller expose equivalent information.
- Opening during level-up returns to the unchanged level-up state.
- Resume works.
- Settings is a Coming Soon placeholder.
- Quit Run requires confirmation and returns to class selection through replaceable routing.
- Single-player responsive layouts pass at 1920×1080 and 3840×2160.
- Future compact pane boundaries are tested without implementing multiplayer.
- Focused tests, the full suite, import validation, and live manual verification pass.
- No unrelated user or Godot files are overwritten.

## Follow-On Designs

Recommended order after this milestone:

1. **Developer Mode and Feature Gates**
   - Main-menu Settings storage.
   - Player Simulation and Developer Access.
   - Unlock-all-implemented-content.
   - God mode.
   - Party-cap override with an explicit safety ceiling.
   - Enemy-density and performance controls.
   - Later cheat-code entry to reveal Developer Mode.
2. **Equipment, Inventory, Items, Rarities, and Affixes**
   - Developer Preview availability while player-facing access stays hidden.
   - Production unlock after the approved early-run progression window.
3. **Persistent Profiles and Progressive Revelation**
   - Run history.
   - Unlock conditions.
   - Evolving main menu and city presentation.
4. **Local Multiplayer and Dynamic Camera Clustering**
   - Human players consume party capacity.
   - Independent input and controlled characters.
   - Dynamic camera merge/split groups.
   - Per-player ledger panes and close arbitration.
