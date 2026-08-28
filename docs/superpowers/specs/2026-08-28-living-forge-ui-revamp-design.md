# Living Forge UI Revamp Design

**Date:** 2026-08-28

**Status:** User-approved design, pending written-spec review

**Authoritative checkout:** `F:\Projects(root)\Game dev\Projects\party-forge`

**Baseline:** `65f0d238345ea0a009e298a07f2191289fd88260`

## Purpose

Party Forge has broad UI functionality but lacks a coherent visual and interaction language. The main menu has an intentional forge/city identity, while Play, HUD, level-up, results, recovery, equipment, storage, settings, and developer screens often read as separate dark/default Godot tools.

This design establishes **The Living Forge** as one reusable UI system and applies it through reviewable vertical slices. The revamp improves the Play/run-setup experience, equipment management, large-party readability, controller behavior, responsiveness, accessibility, and player-facing feedback without replacing authoritative gameplay, profile, inventory, or persistence services.

## Product Decisions

The following decisions are approved:

1. The Living Forge is the unified Party Forge UI style.
2. The revamp uses a design-system foundation followed by complete vertical slices.
3. Play becomes a future-ready one-to-four-seat lobby. Player 1 is functional now; Seats 2-4 are honest `LOCAL CO-OP - COMING SOON` states until split-screen exists.
4. Armoury is the permanent pre-run loadout authority.
5. Ledger is the current-run gear authority.
6. Warehouse is permanent profile storage.
7. Equipment management is hybrid: exact manual placement remains authoritative, with explicit contextual quick actions.
8. The live HUD prioritizes party readability.
9. At one to six party members, followers use richer cards. At seven to twenty-four members, the HUD uses a compact hierarchical roster with actionable alert expansion.
10. The revamp covers all production and developer UI surfaces through phased delivery rather than stopping after Play or equipment.

## Goals

- Make every screen feel like the same stylized game.
- Turn Play into an informed, readable run-preparation decision.
- Make permanent, run-scoped, and stored equipment boundaries unmistakable.
- Give every equipment action a visible state, valid result, or explicit failure reason.
- Preserve readable party state from one through twenty-four members.
- Maintain mouse, keyboard, and controller outcome parity.
- Support couch-distance readability and future one-to-four-player local UI composition.
- Define deliberate responsive, accessibility, empty, unavailable, damaged, loading, and error states.
- Reuse existing tested domain services and focus contracts instead of rewriting working gameplay logic.
- Require human visual acceptance in addition to automated geometry and input evidence.

## Non-Goals

- Implementing playable split-screen, controller joining, simultaneous local-player actors, or adaptive split/merge cameras.
- Inventing synergy, telemetry, item, class, or profile data that production does not provide.
- Replacing profile, run recovery, inventory, equipment, extraction, or persistence authority with UI-owned state.
- Reworking combat balance, class balance, loot rules, or item-generation rules.
- Shipping final city, character, equipment, VFX, audio, or cinematic assets as a prerequisite for the UI system.
- Treating automated screenshots as human visual approval.
- Exposing unfinished controls as enabled placeholders.

## Audit Evidence and Limitations

The design follows a read-only senior UI/UX audit of the current repository and approximately twelve relevant genre examples.

Visually verified Party Forge evidence included tracked victory, defeat, recovery, permanent-delete, and item-tooltip screenshots. Current scene composition, focus behavior, responsive contracts, equipment flows, and menu wiring were inspected in code and documentation. Historical class-selection, level-up, result, and active-run renderer images informed the audit but were not freshly captured at the baseline commit. Armoury and Warehouse findings were code/document verified rather than freshly rendered because the review was read-only and existing runners create evidence files.

Implementation must therefore capture fresh player-facing evidence for every changed screen before claiming visual completion.

## Reference Lessons

| Reference | Transferable lesson |
| --- | --- |
| [Vampire Survivors co-op](https://poncle.games/coop-faq) | Keep roster, seat state, selected character information, and confirmation legible together. |
| [Brotato](https://store.steampowered.com/app/1942280/Brotato/) | Preserve important loadout and stat context around rapid item decisions. |
| [Halls of Torment](https://store.steampowered.com/app/2218750/Halls_of_Torment/) | Strong equipment framing can carry identity while retaining predictable slot taxonomy. |
| [Death Must Die items](https://dmd.fandom.com/wiki/Item) | Communicate rarity, tier, and equipment destination at a glance. |
| [Soulstone Survivors](https://store.steampowered.com/app/2066020/Soulstone_Survivors/) | Choice cards benefit from icons, tags, numerical context, and clear secondary actions. |
| [Deep Rock Galactic: Survivor](https://store.steampowered.com/app/2321470/Deep_Rock_Galactic_Survivor/) | Show exact upgrade deltas, rarity, and weapon context; reduce reroll and comparison friction. |
| [Ravenswatch](https://ravenswatch.com/en/) | Hero-specific identity and ability cues make party composition readable. |
| [Ember Knights](https://store.steampowered.com/app/1135230/Ember_Knights/) | Local co-op decisions need clear player ownership and build context. |
| [Children of Morta](https://store.steampowered.com/app/330020/Children_of_Morta/) | Character lineup, player identity, join state, and Start belong in one lobby composition. |
| [Diablo IV UI update](https://news.blizzard.com/en-us/article/23308274/diablo-iv-quarterly-updatefebruary-2020) | Share information architecture across devices while allowing device-native interactions. |
| [Path of Exile 2 controller/co-op update](https://www.pathofexile.com/forum/view-thread/3740562/page/1) | Local-player panels need retained focus and fast controller transfer actions. |
| [Last Epoch stash priorities](https://support.lastepoch.com/hc/en-us/articles/46361669296283-Stash-Tab-Priority) | Explicit destination rules and quick-store actions reduce repetitive storage work. |

These references provide interaction lessons only. Party Forge does not copy their artwork, layouts, terminology, or branded visual assets.

## The Living Forge Visual System

### Identity

The Living Forge is a heroic workshop-and-city language rather than generic grimdark ARPG chrome.

- **Primary surfaces:** deep blue-black forged iron with restrained hammered or brushed variation.
- **Content wells:** inset charcoal regions with strong separation from navigation and action areas.
- **Primary accent:** warm ember gold for primary actions, selected identity, and meaningful progression.
- **Neutral focus accent:** bright ivory or cool steel blue.
- **Class colors:** local identifiers on portraits, badges, and class-specific markers only.
- **Rarity colors:** confined to item frames, badges, and comparison markers.
- **Valid interaction:** cool teal/blue plus a placement or confirmation symbol.
- **Invalid or destructive interaction:** red-orange plus an icon and text reason.
- **Frames:** reusable nine-slice forged-metal panels with clipped corners and one restrained rune/notch motif.
- **Background depth:** workshop or city silhouettes may provide atmosphere but must not compete with text or focus.

### Typography

The system uses roles rather than per-screen font overrides:

- One compact display face for titles and large section headers.
- One highly legible humanist sans-serif for body copy, controls, and explanations.
- Tabular numerals for timers, prices, levels, capacity, damage, and comparisons.
- Semantic sizes for display, page title, section title, card title, body, caption, and micro-label.
- Text size scales through UI settings without changing information priority.

Production fonts must have clear redistribution rights and complete required character coverage before adoption. A fallback chain is mandatory.

### Spacing and Density

- Use an eight-pixel base grid.
- Define compact HUD, standard card, and dense management-screen modes.
- Do not reduce couch-facing control targets merely to fit more information.
- Bound ultrawide compositions instead of stretching text and action areas across the viewport.
- Increase physical scale at 4K rather than adding more simultaneous information.

### Motion

- Focus and selection transitions use restrained 120-180 ms motion.
- Ember sweeps, metal ticks, flashes, and haptics are reserved for meaningful actions.
- Reduced motion replaces transitions with immediate state changes while preserving all semantic feedback.
- UI animation must not delay authority-changing operations or hide their final state.

### Semantic States

Every reusable interactive component supports the states relevant to it:

| State | Presentation rule |
| --- | --- |
| Hover | Warm edge or surface lift; never the only selection indicator. |
| Keyboard/controller focus | Bright ivory/steel double outline with sufficient contrast. |
| Pressed or held | Ember inset fill plus held-state icon or label. |
| Selected | Gold notch and explicit selected marker. |
| Equipped | Selected language plus equipped check/slot association. |
| Valid destination | Teal/blue outline, placement icon, and named destination. |
| Invalid destination | Red-orange outline, failure icon, and explicit reason. |
| Disabled | Reduced contrast plus visible lock or requirement reason where relevant. |
| Destructive | Red-orange treatment; never receives default focus. |
| Checking/pending | Stable geometry, initiating focus retained, duplicate activation rejected, and a named progress state. |
| Loading | Stable geometry, progress or activity indication, and no false empty state. |
| Error | Player-readable reason and available recovery/cancel action. |

Meaning is never communicated by color alone.

## Technical Architecture

### Global Theme and Tokens

Create one global Godot `Theme` and bounded supporting resources/scripts for semantic colors, typography roles, spacing, control sizing, frame assets, motion timing, and device prompt resolution.

Screens consume semantic roles such as `primary_action`, `destructive_action`, `focus_outline`, `valid_destination`, or `item_rarity_rare`; they do not embed duplicated color literals or one-off style boxes.

The system must support theme variants required for high contrast and developer-tool density without duplicating the base component tree.

### Shared Components

The component library includes:

- Forge panel and modal frame
- Primary, secondary, destructive, and unavailable buttons
- Tab bar and navigation rail
- Prompt/action bar with active-device glyphs
- Hero/class card
- Player-seat card
- Party member card and compact roster marker
- Alert card and overflow indicator
- Progress, health, XP, and capacity bars
- Status badge/chip
- Item slot and paper-doll slot
- Item card and structured comparison tooltip
- Empty, filtered-empty, loading, unavailable, damaged, recoverable, and error states
- Toast/status result presentation

Components are presentation-focused. They accept explicit projection data and emit explicit actions. They do not directly mutate profile, run, item, or persistence state.

### Data and Authority Boundaries

- Existing profile and recovery services remain authoritative for profile and resumable-run state.
- Existing run setup and checkout services remain authoritative for starting runs and loadout compatibility.
- Existing equipment, storage, and transaction services remain authoritative for every item move.
- Existing feature-access policy remains authoritative for available and Coming Soon states.
- UI projection/view-model objects translate authoritative state into stable presentation data.
- Optional fields appear only when an authoritative projection supplies them. The UI omits unsupported playstyle, objective, ability, inventory-urgency, party-fit, alert, or telemetry fields rather than authoring gameplay truth.
- A failed projection or operation never causes optimistic UI state to become authority.
- A successful operation refreshes the authoritative projection before final visual confirmation.

### Focus and Device Ownership

- Focus follows visible spatial layout.
- Opening a child screen records the exact initiating control.
- Cancel and close restore the exact initiating control when it remains available, otherwise a deterministic safe fallback.
- Mouse hover may preview but never silently commit a selection.
- Keyboard and controller confirmation use the same action contract as mouse activation.
- Active-device prompts may change presentation without changing input actions or selected data.
- Destructive actions are excluded from default focus.

### Pending Operations

Authority-changing operations expose explicit `checking`, `starting`, `transaction_pending`, or destructive-operation pending states as appropriate.

- Duplicate activation is rejected while the exact request is pending.
- Navigation that would invalidate the request is disabled until the operation reaches a terminal result.
- The initiating focus target and request identity are retained.
- Cancellation is offered only when the authoritative operation supports safe cancellation.
- Success presentation occurs only after authoritative state is refreshed and matches the accepted result.
- Failure restores a stable interactive state and exposes the player-readable reason.

## Delivery Strategy

The revamp uses a design-system foundation plus complete vertical slices:

1. Living Forge foundation and component/state board.
2. Future-ready Play lobby.
3. HUD, level-up, and run results.
4. Armoury and permanent loadouts.
5. Ledger and current-run gear.
6. Warehouse and permanent storage workflows.
7. Main menu, recovery, settings, pause, profiles, passive tree, and developer tools.
8. Cross-screen accessibility, resolution, input, performance, and visual-acceptance gate.

Each slice adopts only reviewed components and must be visually and functionally accepted before the next slice treats those components as stable.

This document is the governing design for the whole revamp, but it does not authorize one oversized implementation branch. The first detailed implementation plan covers the Living Forge foundation and Play lobby only. HUD/results, equipment, Warehouse, remaining screens, and final cross-screen qualification each receive a separate bounded plan after their prerequisite slice is integrated. The sequence continues until the completion criteria in this document are satisfied.

## Play and Run Setup

### Purpose

Play becomes an informed run-preparation lobby rather than a list of class text buttons.

### Desktop Composition

- **Header:** Play, selected mode, active profile, and concise run-status summary.
- **Left column:** player-seat cards followed by the class roster.
- **Center stage:** the selected class's production presentation scene as a live 3D hero stage. If that scene cannot be loaded safely, use the class's stable neutral silhouette fallback and an unavailable-detail message; never substitute a different class or item identity.
- **Right column:** role, starting action, traits, class tags, loadout readiness, and production-backed party-fit information.
- **Bottom action bar:** Back, Settings, Armoury, Select, and Start Run with active-device prompts.

### Future-Ready Seats

Player 1 is functional and shows:

- Active profile identity
- Player color
- Input device
- Selected class
- Ready state

Seats 2-4 are visually complete but explicitly state `LOCAL CO-OP - COMING SOON`. They do not expose a fake join action and do not enter the normal focus loop. The layout and component API reserve future joined, selecting, ready, disconnected, and reconnecting states without claiming those states are currently playable.

### Class Selection

Each class card presents:

- Portrait or silhouette
- Class name
- Combat role
- Short playstyle label when supplied by the class presentation projection
- Selected-class loadout compatibility state
- Focused, selected, and locked state
- Restrained class-color accent within the shared frame

Focus previews a class. Confirmation selects it. Start Run remains a separate explicit action.

The detail panel presents only production-backed information. It omits playstyle, party-fit, synergy, or compatibility fields that are not supplied by an authoritative projection. Compatibility is calculated for the selected class only unless a future safe batch projection is explicitly designed and tested.

### Flow Rules

- No active profile routes to profile creation or selection.
- A recoverable run takes precedence and opens the Living Forge Resume/Abandon/Cancel flow.
- A valid new-run request opens the lobby.
- Incompatible equipment opens the loadout warning with a direct Armoury route.
- Damaged or unreadable state fails closed with a player-readable explanation and safe recovery/cancel actions.
- Returning from Settings or Armoury restores the exact prior class or action focus.

### Responsive Rules

- At 1080p and above, use the full three-column composition.
- At compact/720p sizes, use a horizontal seat strip, reduced hero stage, and scrollable detail region.
- At ultrawide sizes, bound the content width.
- At 4K, scale controls and typography without increasing density.
- Primary action, selected class, profile identity, and compatibility state remain couch-readable.

## Scalable In-Run HUD

### Stable Regions

- Timer occupies the top center; an objective appears beside it only when an authoritative run-objective projection supplies one.
- The controlled leader owns the full detail panel. Health, XP, level, active abilities, and urgent statuses appear only when their authoritative runtime projections are available.
- Loot capacity and urgent inventory state remain compact and separate from combat health when supplied by authoritative storage/inventory projections.
- Party state occupies a bounded roster region.

### Party Scaling

- At one to six members, every follower uses a richer individual card.
- At seven to twenty-four members, every owned member appears in a compact two-row hierarchical roster.
- Compact markers include portrait/class identity, health, and semantic status indicators.
- Focus, pause inspection, or Ledger navigation reveals complete member details.

The large roster preserves stable party order and uses a bounded paged/scrolling rail rather than shrinking markers below the approved minimum control and text sizes. Focused members are always scrolled into view. Page movement retains the focused member when possible; closing inspection restores that exact marker, or the nearest surviving member in stable party order. The implementation defines the visible marker count from the minimum accessible marker width at each supported viewport instead of assuming all twenty-four fit simultaneously.

### Alert Expansion

Only projection-backed actionable members expand into readable alert cards. Unsupported alert categories are omitted. Priority among available categories is deterministic:

1. Downed or dying
2. Critical health
3. Crowd-controlled
4. Separated from reward or combat range
5. Objective-relevant
6. Other actionable temporary state

Only the three highest-priority alert cards are expanded simultaneously. Additional alerts produce a `+N alerts` indicator. Stable tie-breaking uses party/member order so alerts do not flicker.

Future split-screen viewports show only the owning player's leader and party. This design does not implement those viewports.

## Level-Up Presentation

Upgrade cards present:

- Distinct icon and category
- Name and rarity
- Exact numerical change
- Personal, recipient, or party-wide scope
- Current value to resulting value where meaningful
- Compatible recipient and class tags
- Production-backed synergy or conflict information only

Focus previews the result. Confirmation commits it. Recipient selection reuses the scalable party-roster language so twenty-four members remain reachable without twenty-four full cards.

## Run Results

The result screen is a structured recap:

- Outcome and duration
- Party composition and final levels
- Build/upgrades summary
- Loot retained, lost, or extracted
- Profile or progression consequences
- Recorded combat highlights where production telemetry exists
- Restart Run, Return to Forge, and Quit Application actions

Unsupported statistics remain absent. Victory emphasizes progression and retained value. Defeat explains losses and recoverable state without hiding consequences.

### Run Lifecycle Action Semantics

- **Resume:** closes Pause and continues the same runtime and durable recovery identity.
- **Return to Forge:** suspends an active run only after the lifecycle service verifies the resumable run and run-owned item state remain durable. It returns to the front end without forfeiting that recovery.
- **Quit Application:** never forfeits a run. During an active run it uses the same durability check and clearly states that the run will remain resumable before exiting.
- **Abandon Run:** is the separately styled destructive action. It delegates to exact run forfeiture, clears the matching recovery, and removes run-owned items according to the authoritative service.
- **Restart Run:** appears only after terminal run resolution succeeds and revokes the old recovery. It opens a prepopulated lobby using the prior profile/class where still valid; it does not perform a new checkout until the player explicitly starts.
- **Return to Forge after results:** appears only after terminal resolution succeeds and returns to the front end with the resolved retained/lost/extracted state.

Generic `Return`, `Quit Run`, and `Quit` labels are not used where their persistence consequences differ. If terminal resolution fails, result actions that assume resolved authority remain unavailable and the screen presents recovery/retry guidance.

## Equipment Information Architecture

### Explicit Authorities

- **Armoury - Permanent Loadout:** profile-owned starting equipment.
- **Ledger - Current Run Gear:** active-run equipment only.
- **Warehouse - Permanent Storage:** profile-owned stored items.

Every screen displays its authority in a prominent scope banner and in action microcopy.

### Shared Workspace Anatomy

Armoury and Ledger share:

- Character identity presentation
- Rotating character presentation
- Spatial paper doll
- Equipment slots
- Relevant item grid
- Persistent item-detail/comparison panel
- Contextual action bar
- Device-adaptive prompts

The shared anatomy prevents permanent and run gear from looking like unrelated systems while the scope banner prevents persistence confusion.

Armoury shows only the active profile's permanent leader/loadout. Ledger supplies a selector for current-run party members. Permanent follower loadouts remain absent until an authoritative Barracks/follower-loadout contract exists.

### Paper Doll and Slots

Slot focus follows visible spatial arrangement. Each slot can present:

- Slot type
- Equipped item
- Empty state
- Compatible destination
- Invalid destination and reason
- Held-item destination preview
- Resulting comparison deltas
- Requirement or class incompatibility

The character presentation updates only after authoritative transaction success. A non-authoritative preview may show proposed appearance or statistics when it is clearly labeled and can be cancelled without mutation.

### Structured Item Details

Item tooltips/details use consistent sections:

1. Item identity, rarity, tier, and item level
2. Base or implicit properties
3. Explicit modifiers
4. Requirements and compatibility
5. Special behavior
6. Equipped comparison
7. Valid actions and named destination

The presentation retains advanced details and comparison pinning while improving section hierarchy.

### Hybrid Management

Manual placement remains authoritative:

- Mouse drag/drop
- Controller pick/place
- Keyboard selection and placement

Contextual quick actions include only operations backed by exact transaction contracts:

- Equip to a named slot
- Compare
- Quick Store
- Move to Stash
- Move to Run Inventory
- Unequip
- Favorite/Lock only after a durable persistence contract exists

Every quick action names its destination before confirmation.

Authority-specific actions are bounded as follows:

| Surface | Authorized movement |
| --- | --- |
| Armoury | Permanent leader loadout to or from an exact Warehouse container/slot. |
| Ledger | Current-run member gear to or from an exact run-inventory container/slot. |
| Warehouse | Storage organization and explicitly authorized movement to or from the permanent leader loadout. |

Ledger never moves an item directly to or from Warehouse without an extraction/persistence service that explicitly authorizes that transition. `Quick Store` names the exact destination container and does not appear when the item is already stored there.

Items compatible with multiple destinations, including rings and valid offhand/main-hand alternatives, require an explicit target-slot choice or controller-accessible target cycle. The comparison header names the target slot. Pinned comparisons retain that slot identity, and no action silently chooses the first compatible slot.

### Transaction Feedback

While an item is held:

- The source remains visibly marked.
- Valid targets use teal/blue plus a placement icon and destination label.
- Invalid targets use red-orange plus an explicit reason.
- Comparison deltas update against the focused destination.
- Cancel returns the item and exact prior focus.

On success, the authoritative projection refreshes, then the destination presents restrained metal/ember confirmation and a readable result. On failure, no state moves; focus and held/source state remain stable, and the actual player-facing reason is displayed.

## Warehouse

Warehouse is storage-first and includes:

- Named category tabs
- Search, filters, and sorting
- Result count and total capacity
- Clear selected-item state
- Persistent detail/comparison panel
- Explicit destination-aware movement
- Deliberate empty, filtered-empty, full, damaged, loading, and unavailable states

`Assign Category` and `Bulk Move` remain hidden until they have complete selection, destination, confirmation, cancellation, and outcome behavior. No enabled visible control may emit an unconsumed action.

Search, filtering, and sorting are presentation projections and never reinterpret persistent container slots. Selection is tracked by stable item-instance ID, not visible grid index. Manual empty-slot placement is disabled in sorted or filtered projections unless the player explicitly enters a physical-tab placement mode that shows stable container and slot destinations. Clearing or changing a projection retains selection only when the same item instance remains present; otherwise it moves focus deterministically to the nearest visible item or the projection controls.

## Equipment Responsiveness

- Desktop keeps character/paper doll, item grid, and details visible together.
- Compact layouts convert those panes into explicit tabs.
- A held-item bar remains visible across compact pane transitions.
- A source pane going offscreen cannot lose or commit an item.
- Controller focus and mouse selection produce the same selected item and comparison data.

## Remaining Screens

### Main Menu

Retain the forge/city backdrop. Replace duplicate focusable Armoury/Warehouse direct and hotspot routes with one clear command hierarchy. Visual city landmarks may remain decorative until a full city-navigation interaction is designed; they do not duplicate enabled actions.

### Recovery and Confirmation

Use one modal grammar with named consequences, safe default focus, explicit cancel, and restrained destructive styling. Profile deletion and run abandonment remain distinct operations with exact copy and authority. Resume, Return to Forge, Quit Application, and Abandon Run never share ambiguous labels or consequence text.

### Settings

Apply shared tabs and controls and add:

- UI scale from 80-150%
- Text scale from 80-150%
- High-contrast mode
- Active-device glyph preference where automatic switching is insufficient
- Complete input rebinding with conflict handling and reset-to-default

Coming Soon content is not presented as a dead enabled page.

UI scale changes component geometry and spacing only. Text scale changes typography only. They do not multiply. Layout validation covers every corner combination, especially 80% UI with 150% text and 150% UI with 150% text. These controls, high contrast, glyph preference, and rebinding remain hidden or explicitly unavailable until versioned durable settings fields, migration/default behavior, runtime application, and reload persistence are implemented and tested.

### Pause

Present Resume, Settings, Return to Forge, and Quit Application with the shared modal/action hierarchy and exact focus restoration. Return to Forge and Quit Application preserve the exact resumable run; neither is a synonym for Abandon Run.

### Passive Tree

Preserve the functional graph and navigation model while applying Living Forge panels, node states, currency presentation, legends, prompts, and focus treatment. Do not restructure tree data or allocation rules as part of the UI revamp.

### Profiles

Improve profile identity, health/recovery state, current selection, deletion consequences, empty state, and first-profile creation without weakening exact persistence or deletion semantics.

### Developer Tools

Developer Item Sandbox and Loot Lab use a denser Living Forge variant. They remain visually recognizable as developer-only tools while reusing standard focus, buttons, tabs, item slots, tooltips, and error states.

## Universal Interaction Rules

- No visible enabled control lacks a player-facing result.
- Unavailable features provide a reason.
- Focus is always visible.
- Focus returns to the initiating control after a child surface closes, with a deterministic safe fallback when necessary.
- Mouse, keyboard, and controller produce the same selected data and authority-changing outcome.
- Active-device prompts update without changing underlying actions.
- Destructive actions never receive default focus.
- Player-facing errors use plain language; technical diagnostics remain available in logs.
- Loading is distinct from empty, and filtered-empty is distinct from truly empty.
- UI never silently commits a preview, hover, or held-item state.

## Accessibility Requirements

- UI and text scaling from 80-150%.
- Couch-readable default sizing.
- High-contrast focus and semantic states.
- Meaning communicated through icon/shape/text in addition to color.
- Reduced-motion alternatives for all transitions.
- Large control targets and predictable directional navigation.
- Rebindable controls with conflict detection and reset-to-default.
- Text labels or accessibility descriptions for meaningful icons.
- Tabular numerals for rapidly changing or comparative values.
- Scroll regions keep focused content visible.
- Disabled and unavailable states retain readable explanations.
- Normal text meets a minimum 4.5:1 contrast ratio. Large text, focus boundaries, and meaningful control-state boundaries meet a minimum 3:1 ratio against adjacent colors.
- The worst supported UI-scale/text-scale combinations pass clipping, reflow, focus visibility, and control-target checks.

## Error Handling

- Projection failure preserves the previous stable presentation or opens an explicit unavailable/error state.
- Authority-changing operations refresh from authoritative state after success.
- Failed item operations preserve source, destination, held state, and focus consistently with the transaction result.
- Profile, recovery, and storage corruption fails closed and exposes only safe recovery actions.
- Missing visual assets use stable fallback presentation without changing gameplay identity or saved data.
- Unknown theme/component state fails to a readable neutral style rather than invisible controls.
- Incomplete features remain hidden or explicitly unavailable; they never emit unconsumed actions.

## Performance Requirements

- Reusable components do not rebuild large control trees every frame.
- Twenty-four-member roster updates are revision- or signal-driven.
- Item grids preserve existing bounded/virtualized behavior where available.
- Motion and hover effects avoid per-control unbounded processing.
- Four-seat lobby placeholders add negligible runtime work.
- Performance gates record UI counts, viewport, settings, and hardware context rather than accepting timeouts or partial runs.

## Verification Strategy

Every vertical slice requires fresh evidence.

### Automated Evidence

- Theme/token and component-state unit coverage.
- Projection/view-model tests for supported, empty, unavailable, damaged, and failure states.
- Focus entry, containment, directional movement, cancellation, and restoration tests.
- Mouse, keyboard, and simulated-controller outcome parity.
- Responsive geometry at 1280x720, 1920x1080, 2560x1440, 3840x2160, and one supported ultrawide resolution.
- UI/text-scale and high-contrast checks.
- Reduced-motion checks.
- Held-item cancellation, invalid placement, valid swap, capacity failure, and transaction-result feedback.
- Checking/starting/transaction/destructive pending states, duplicate-activation rejection, supported cancellation, and authoritative post-success refresh.
- Armoury/Ledger/Warehouse action-matrix enforcement, including rejection of direct Ledger-to-Warehouse movement.
- Filtered/sorted Warehouse selection by stable item ID and physical-slot placement-mode boundaries.
- Explicit multi-slot comparison/placement and pinned target-slot identity.
- Resume, Return to Forge, Quit Application, Abandon Run, Restart Run, and terminal-resolution consequence contracts.
- One-seat functional and four-seat future-lobby states.
- One-, six-, seven-, twenty-, and twenty-four-member HUD/recipient cases, including bounded roster paging, focused-member visibility, stable ordering, and return focus.
- No enabled visible control with an unconsumed action.
- Complete retained unit and relevant integration suites.

### Rendered Evidence

- One component/state board covering all reusable interaction states.
- Fresh captures for every changed player-facing screen at required layout boundaries.
- Controller-focus and mouse-hover states captured separately where their presentation differs.
- High-contrast, reduced-motion, and scaled-text examples.
- Large-party HUD captures with no alerts, three alerts, and alert overflow.
- Equipment held, valid, invalid, comparison, success, and failure states.

### Manual Acceptance

- Human visual approval is separate from automated geometry success.
- Physical-controller traversal covers focus, cancel, prompt switching, pick/place, compact panes, and modal behavior.
- Couch-distance review verifies primary actions, class identity, equipment comparisons, and urgent alerts.
- Manual checks are labeled `DEFERRED` until actually performed.

## Dependencies and Risks

### Dependencies

- Production-backed class detail and loadout compatibility projections for the Play lobby.
- A licensed display/body font pair and fallback chain.
- A consistent icon set with redistribution rights.
- Existing item/equipment/storage transactions and projection services.
- Existing responsive and input integration runners, extended rather than discarded.
- Future synergy and split-screen systems may populate reserved UI seams but are not prerequisites for this revamp.

### Risks and Mitigations

- **Scope size:** deliver and approve vertical slices; do not attempt one unreviewable all-screen merge.
- **Style drift:** prohibit unreviewed local color/style overrides when a semantic token exists.
- **False functionality:** hide incomplete actions and require action-consumer coverage.
- **Controller regression:** retain input parity and focus gates in every slice.
- **Information overload:** use bounded regions, progressive detail, and the hierarchical roster.
- **Persistence confusion:** keep permanent/run/storage scope banners and destination-specific microcopy.
- **Temporary assets becoming authority:** presentation fallbacks never define class, item, profile, or run identity.
- **Automated evidence overclaim:** require separate human visual and physical-controller status.

## Completion Criteria

The UI revamp is complete only when:

1. All production and developer UI screens consume the approved Living Forge theme/components or an explicitly approved dense variant.
2. Play is an informed, responsive, future-ready one-to-four-seat lobby with only Player 1 functional until split-screen exists.
3. The HUD remains readable and actionable from one through twenty-four party members.
4. Level-up and result screens present production-backed decisions and consequences clearly.
5. Armoury, Ledger, and Warehouse communicate distinct authority and persistence boundaries.
6. Every equipment operation has visible held, valid, invalid, success, failure, and cancellation behavior.
7. No enabled visible control lacks a consumed player-facing action.
8. Mouse, keyboard, simulated-controller, and required physical-controller gates are reported separately and honestly.
9. Required resolutions, compact boundaries, accessibility settings, and large-party stress cases pass.
10. Fresh rendered evidence receives human visual approval.
11. The complete retained regression suite passes on the exact final implementation head.
