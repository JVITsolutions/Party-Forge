# Interactive Temporary Popups Design

**Date:** 2026-07-31

**Status:** Approved interaction and architecture design; implementation pending written-plan approval

**Initial consumer:** Level-up upgrade tooltip

## Purpose

Long upgrade descriptions already use a scroll container, but the current hover-only tooltip disappears as soon as the pointer leaves its upgrade card. The player therefore cannot reach the tooltip's scrollbar or scrollable body.

Temporary hover and focus popups will become deliberately interactive without becoming permanent modal windows. A player can hold Alt to keep the current popup alive while moving into it, pin it for hands-free inspection, and scroll it with the appropriate input device. The interaction will be reusable by future temporary detail popups.

## Scope

This milestone applies the interaction to the level-up upgrade tooltip and establishes a reusable base for future temporary hover/focus popups.

It does not change fixed detail panels such as Character Ledger stat or upgrade pages. It does not introduce multiple simultaneous pinned popups, free-form popup dragging, popup resizing, tooltip comparison, or per-profile input rebinding.

## Root Cause

`UpgradeCard` currently emits `detail_dismissed` immediately after both mouse and keyboard/controller focus leave the card. `LevelUpPanel` responds by unconditionally hiding the tooltip. The tooltip root also uses `MOUSE_FILTER_IGNORE`, so neither the popup nor its scroll controls can receive pointer input.

The repair must change the popup lifetime contract. Merely enlarging the tooltip, hiding its scrollbar, or delaying dismissal by a timer would not make interaction reliable.

## Interaction Model

Only one temporary popup may be active or pinned at a time.

### Transient

- Hovering or focusing a supported source displays its popup.
- A different source may replace the transient content.
- Leaving the source dismisses the popup unless the hold modifier is active.

### Alt-held

- Holding either Alt key while a popup is visible keeps that popup alive after its source loses hover or focus.
- While Alt remains held, the player may move the pointer into the popup, use the mouse wheel, drag its scrollbar, or click the pin control.
- Alt does not pin automatically.
- Releasing Alt dismisses an unpinned popup when its original source is no longer active.
- Holding Alt without a visible supported popup has no effect.

### Pinned

- Clicking the top-right pin or pressing Y/Triangle pins the currently visible popup.
- Pinned content remains locked to the original source. Hovering or focusing another source does not replace it.
- Clicking the pin again or pressing Y/Triangle again unpins it.
- If the original source is no longer active when the popup is unpinned, the popup dismisses immediately.
- A pinned popup does not survive a surrounding workflow transition.

## Input Contract

Input actions are declared in `project.godot` through an idempotent configuration script.

- `tooltip_hold`: either Alt key.
- `tooltip_pin`: controller Y/Triangle.
- `tooltip_scroll_up`: right-stick vertical negative direction.
- `tooltip_scroll_down`: right-stick vertical positive direction.

Keyboard and mouse behavior remains:

- Hold Alt to transfer the pointer into an unpinned popup.
- Use the mouse wheel over the popup body or drag its scrollbar.
- Click the pin icon to toggle pinned state.

Controller behavior is:

- Focus a supported source to display its popup.
- Press Y/Triangle to pin or unpin it.
- Move the right stick vertically to scroll the visible popup.

Right-stick scrolling is consumed only while a supported temporary popup is visible. The level-up screen already pauses gameplay, so this input does not compete with live character movement.

## Reusable Component Boundary

A reusable `TemporaryHoverPopup` base owns interaction state and input handling. It exposes a narrow contract:

- Present content for a source identity.
- Mark the current source active or inactive.
- Decide whether a new source may replace current content.
- Toggle or explicitly clear pinned state.
- Force dismissal and reset all transient state.
- Provide the scroll target used by controller scrolling.

`UpgradeTooltipPanel` extends this base and remains responsible for upgrade-specific rendering, keyword text, size calculation, and viewport clamping.

`LevelUpPanel` remains responsible for producing upgrade tooltip content. Card dismissal becomes a request to release the current source rather than an unconditional hide. The popup reports actual dismissal so `LevelUpPanel` can clear its current tooltip choice without duplicating popup state.

`UpgradeCard` keeps its existing source signals and does not learn about Alt, pinning, scrolling, or popup presentation.

## Popup Header and Accessibility

The popup header becomes a horizontal container containing the title region and a top-right pin button.

- The pin uses a project-owned vector icon so it remains sharp at 1080p, 1440p, and 4K.
- Pinned and unpinned states have distinct icon treatment and text alternatives; color is not the only distinction.
- The button exposes an accessibility name and tooltip describing its current action: `Pin details` or `Unpin details`.
- The popup may receive pointer input, and its scroll body clips overflowing content.
- The pin remains inside the popup at the existing 720p regression size and the three approved production targets.

The reusable base permits future popup scenes to supply their own header presentation while retaining the same state and input contract.

## Lifecycle and Forced Dismissal

The level-up flow force-clears popup state when any of the following occurs:

- A new set of upgrade offers is displayed.
- An upgrade is activated.
- Recipient selection begins.
- Confirmation begins.
- A subflow is cancelled or completed.
- The level-up panel closes.
- The run exits the level-up state.

Forced dismissal clears the source identity, Alt-held state, pinned state, scroll input state, and visible popup. New content begins at the top of its scroll range.

## Data Flow

1. `UpgradeCard` reports detail requested for its bound `UpgradeChoice` and anchor.
2. `LevelUpPanel` rejects invalid content or asks `UpgradeTooltipPanel` whether the new source may be presented.
3. `LevelUpPanel` builds canonical content through `UpgradePresentationService`.
4. `UpgradeTooltipPanel` renders and positions the content, resets its scroll position, and records the source identity through the reusable base.
5. Source dismissal, Alt state, pin input, and lifecycle resets drive the reusable popup state.
6. The popup remains authoritative about whether it is actually visible or pinned.

## Edge Cases

- Pin and controller-pin input do nothing when no supported popup is visible.
- A pinned popup ignores content requests from other cards.
- Re-hovering the pinned source does not reset its scroll position.
- Unpinning while the original source is still active returns to transient behavior without hiding.
- Unpinning after the source becomes inactive hides immediately.
- Disabled or unavailable upgrade cards cannot produce a pinnable popup.
- A forced lifecycle reset always wins over Alt and pin state.
- A popup whose content fits remains interactive but does not show an unnecessary scrollbar.
- Missing input actions fail safely and produce a grep-friendly diagnostic during configuration or tests.

## Testing Strategy

### State tests

- Transient source exit dismisses.
- Alt preserves an inactive source's popup.
- Alt release dismisses an inactive, unpinned popup.
- Pin survives Alt release.
- Pinned content rejects replacement by another source.
- Unpin keeps an active source visible and dismisses an inactive source.
- Forced reset clears every state.

### Level-up integration tests

- Long authored content creates scrollable overflow.
- Alt plus card exit keeps the production tooltip visible.
- Mouse pin locks exact content and blocks another card's hover content.
- Y/Triangle toggles the same pin state.
- Mouse wheel and scrollbar interaction change the scroll value.
- Right-stick input changes the visible tooltip scroll value.
- New offers and every recipient/confirmation/completion transition clear stale pinned content.

### Responsive and live acceptance

- Pin placement, tooltip containment, and long-content scrolling pass at 1280x720, 1920x1080, 2560x1440, and 3840x2160.
- The complete automated suite passes.
- Connected Godot acceptance reproduces the original long-description case and verifies Alt transfer, scrollbar drag, wheel scrolling, pin lock, hover rejection while pinned, controller pinning, right-stick scrolling, and lifecycle cleanup.

## Success Criteria

- The scrollbar shown in the reported long upgrade tooltip is reachable and usable.
- Alt reliably permits mouse transfer from the upgrade card into the popup.
- The top-right pin locks content until explicitly unpinned.
- Y/Triangle and right-stick scrolling work through declared InputMap actions.
- Pinned content cannot become stale across level-up workflow changes.
- The implementation is reusable for future temporary hover/focus popups without changing fixed detail panels.
