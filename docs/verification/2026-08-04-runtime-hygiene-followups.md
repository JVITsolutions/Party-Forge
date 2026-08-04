# Runtime Hygiene Follow-ups Verification

Date: 2026-08-04
Base: `0788df080e0387bf8a7361c8d143f2f727b7abaa`
Branch: `fix/runtime-hygiene`

## Delivered behavior

- The composed main scene and Settings screen accept an injectable settings path while retaining the production default.
- The main-menu navigation runner creates, reads, and removes only a disposable settings artifact under its disposable profile root.
- Target loss and owner downing at attack release cancel the action and restore locomotion without emitting an engine-error diagnostic.
- Duplicate, stale, missing-event, and explicit abnormal cancellation diagnostics remain intact.
- The 14 previously observed actionable GDScript warnings were resolved through explicit casts, branches, floor calculations, and non-shadowing names.

## Test-first evidence

- Settings-path RED: the focused settings test produced `Invalid call ... Expected 3 argument(s)` before the four-argument configuration contract existed.
- Settings-path GREEN: `tests/unit/test_settings_screen.gd` reported `TEST_SUMMARY: PASS (0 failures)` and the standalone navigation runner reported `MAIN_MENU_NAVIGATION_SUMMARY: PASS`.
- Attack-cancellation RED: the focused controller test reported two failures because expected target-loss and owner-downed races increased the sequence-error count.
- Attack-cancellation GREEN: both `test_attack_sequence_controller.gd` and `test_playable_class_presentations.gd` reported `TEST_SUMMARY: PASS (0 failures)`.

## Fresh final gates

All commands used isolated `APPDATA` and `LOCALAPPDATA` directories under `.superpowers`.

| Gate | Result |
| --- | --- |
| `godot --headless --editor --path . --import --quit` | Exit 0; zero script, parse, loader, or error matches |
| `godot --headless --path . --quit-after 300 --script res://tests/test_runner.gd` | Exit 0; `TEST_SUMMARY: PASS (112 suites)`; zero failure/script/parse/loader matches |
| `godot --headless --path . --quit-after 120 --script res://tests/integration/main_menu_navigation_runner.gd` | Exit 0; `MAIN_MENU_NAVIGATION_SUMMARY: PASS` |
| `godot --headless --path . --quit-after 10` | Exit 0; `PARTY_FORGE_BOOT_OK` and `PARTY_FORGE_CLASS_SELECTION_READY`; zero startup error matches |
| `git diff --check 0788df0..HEAD` | Exit 0; no whitespace errors |
| Local read-only diff and invariant review | No findings; disposable path is used throughout the runner and genuine attack-sequence diagnostics remain present |
| Generated-sidecar cleanup | Exact 629-path validated allowlist match before removal; zero untracked files afterward |
| Authoritative `main` pre-integration check | Clean at `0788df080e0387bf8a7361c8d143f2f727b7abaa`; four safety stashes unchanged |

## Deferred certification

- Physical-controller smoke: **DEFERRED** until the owner is home. Synthetic controller navigation remains covered by the passing main-menu navigation runner, but this does not replace physical-device certification.
