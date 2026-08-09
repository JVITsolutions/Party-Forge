# Equipment and Attribute Application Verification

Verified 2026-08-09 in the isolated linked worktree on branch `feat/equipment-attribute-application`.

## Scope and pre-gate state

- Approved design base: `00d145d`.
- Verification input commit: `abb0121501652e8ea20d2eb3cafe3dc42de8fbd6` (`test: cover equipment attributes end to end`).
- `git status --short --branch` reported `## feat/equipment-attribute-application` plus only the 123 pre-existing untracked `.gd.uid` sidecars described under Repository hygiene. There were no tracked worktree or index changes.
- The process snapshot found `godot-ai` helpers at PIDs `2276`, `6424`, `10900`, `14120`, `18024`, `27292`, `32420`, `34792`, `38348`, `38720`, and `39588`, all from `C:\Users\Jacob\AppData\Local\uv\cache\archive-v0\MgWhJwN0Rbc1F3en\Scripts\godot-ai.exe`. It found no Godot editor or test process targeting this worktree. No user editor or helper process was stopped.
- Godot executable: `F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe`.
- Exact engine version: `4.7.1.stable.mono.official.a13da4feb`.
- Every Godot command used the worktree-local isolated roots `.superpowers\sdd\equipment-attribute-final-appdata` and `.superpowers\sdd\equipment-attribute-final-localappdata` for `APPDATA` and `LOCALAPPDATA`.

## Required verification

### Fresh editor import and parser gate

```powershell
$env:APPDATA = (Join-Path (Get-Location) '.superpowers\sdd\equipment-attribute-final-appdata')
$env:LOCALAPPDATA = (Join-Path (Get-Location) '.superpowers\sdd\equipment-attribute-final-localappdata')
& $godot --headless --path . --editor --quit-after 300 2>&1 | Tee-Object '.superpowers\sdd\equipment-attribute-import.log'
```

- Exit: `0`.
- Duration: `8.869s`.
- Forbidden diagnostic count: `0`. The captured log contained no `SCRIPT ERROR`, parse error, resource-load failure, failed loader, invalid-call, or invalid-index diagnostic.

### Focused Increment 2 gate

```powershell
& $godot --headless --path . --quit-after 1200 --script res://tests/focused_test_runner.gd -- tests/unit/test_attribute_derived_source_projector.gd tests/unit/test_member_stat_resolution_service.gd tests/unit/test_action_archetype.gd tests/unit/test_damage_resolver.gd tests/unit/test_action_combat_estimate_service.gd tests/unit/test_equipment_modifier_projector.gd tests/unit/test_equipment_activation_resolver.gd tests/unit/test_equipment_transition_service.gd tests/unit/test_player_run_context.gd tests/unit/test_ledger_data_provider.gd tests/unit/test_resolved_stat_comparison_service.gd tests/unit/test_item_tooltip_card.gd
```

- Exit: `0`.
- Duration: `5.245s`.
- Exact marker: `TEST_SUMMARY: PASS (0 failures)` exactly once.
- Forbidden diagnostic count: `0`.
- Allowed negative-path diagnostics: five deliberate `push_error` records asserted by passing tests. Four are `PARTY_FORGE_DAMAGE_ERROR` cases for unknown runtime type, unavailable target, same-team target, and invalid non-finite runtime amount; one is `PARTY_FORGE_STAT_ERROR source=nonfinite_crit stat=crit_chance reason=non-finite value`. There were no warnings or shutdown leak diagnostics.

### Complete project suite

```powershell
& $godot --headless --path . --quit-after 1800 --script res://tests/test_runner.gd
```

- Exit: `0`.
- Duration: `142.279s`.
- Exact marker: `TEST_SUMMARY: PASS (163 suites)` exactly once.
- Additional exact markers: `DEVELOPER_ITEM_SANDBOX_SHA256: c201fd5917d9958da63dacd8201e80d5911c0de51af367977d2a5ee57dd9defe` and `ITEM_TRANSACTION_MATRIX: PASS`.
- Forbidden diagnostic count: `0`; there was no `TEST_SUMMARY: FAIL`, assertion failure, script error, parse error, loader/resource-load error, invalid call/index, fatal record, or crash record.
- Allowed negative-path diagnostics: 55 deliberate `push_error` records, 10 deliberate `push_warning` records, and one deliberately forced engine directory-creation failure from `test_profile_manager.gd::_test_bootstrap_filesystem_failure`. The passing suites intentionally exercise the stable `PARTY_FORGE_ATTACK_SEQUENCE_ERROR`, `PARTY_FORGE_DAMAGE_ERROR`, `PARTY_FORGE_FEATURE_ACCESS_ERROR`, `PARTY_FORGE_GOD_MODE_OWNERSHIP_ERROR`, `PARTY_FORGE_LEDGER_ERROR`, `PARTY_FORGE_PRESENTATION_ERROR`, `PARTY_FORGE_PROJECTILE_PRESENTATION_ERROR`, `PARTY_FORGE_REWARD_ERROR`, `PARTY_FORGE_RUN_CONTEXT_ERROR`, `PARTY_FORGE_RUN_LOADOUT_CHECKOUT_ERROR`, `PARTY_FORGE_RUN_PROFILE_REQUIRED`, `PARTY_FORGE_RUN_RULES_ERROR`, `PARTY_FORGE_SETTINGS_SAVE_ERROR`, `PARTY_FORGE_SETTINGS_VERSION_ERROR`, `PARTY_FORGE_STAT_ERROR`, `PARTY_FORGE_UPGRADE_APPLICATION_ERROR`, `PROFILE_BOOTSTRAP_ERROR`, and `PROFILE_REFRESH_ERROR` paths. The warnings are the asserted `JSON_STORE_CLEANUP_DEBT` and `JSON_STORE_CORRUPT_PRIMARY_PRESERVED` paths. This fresh run emitted no ObjectDB, resource-in-use, RID, or orphan shutdown diagnostic.

### Equipment application integration

```powershell
& $godot --headless --path . --quit-after 900 --script res://tests/integration/equipment_attribute_application_runner.gd
```

- Exit: `0`.
- Duration: `1.715s`.
- Exact marker: `EQUIPMENT_ATTRIBUTE_APPLICATION_SUMMARY: PASS members=24 untouched=23 items=2` exactly once.
- Diagnostic count: `0`.
- Scenarios covered: a 24-member party; member-local attribute and typed-fire equipment transitions; exact one-revision/one-notification behavior; unchanged base/action snapshot identities for members 2-24; typed damage increasing the Mage action estimate; support removal leaving the dependent item equipped but disabled with exact unmet requirements and no modifiers; byte-equivalent immutable item records; encode/resume reconstruction; and automatic reactivation restoring identical stats and action estimates.

### Responsive tooltip integration

```powershell
& $godot --headless --path . --quit-after 900 --script res://tests/integration/item_tooltip_responsive_runner.gd
```

- Exit: `0`.
- Duration: `2.630s`.
- Exact markers, each once: `ITEM_TOOLTIP_COMPATIBILITY_PASS size=1280x720`, `ITEM_TOOLTIP_RESPONSIVE_SIZE_PASS size=1920x1080`, `ITEM_TOOLTIP_RESPONSIVE_SIZE_PASS size=2560x1440`, `ITEM_TOOLTIP_RESPONSIVE_SIZE_PASS size=3840x2160`, and `ITEM_TOOLTIP_RESPONSIVE_SUMMARY: PASS (3 sizes)`.
- Diagnostic count: `0`.
- Scenarios covered: normal/comparison/advanced/combined modes at multiple edge anchors and comparison-card counts; tooltip, pin, and scrollbar containment; all comparison candidates remaining visible; technical IDs hidden in Player Mode; and disabled state plus every unmet requirement remaining visible.

### Startup smoke

```powershell
& $godot --headless --path . --quit-after 300 2>&1 | Tee-Object '.superpowers\sdd\equipment-attribute-startup.log'
```

- Exit: `0`.
- Duration: `4.299s`.
- `PARTY_FORGE_BOOT_OK`: exactly once.
- `PARTY_FORGE_CLASS_SELECTION_READY`: exactly once.
- Diagnostic count: `0`.

## Repository hygiene

Before any Godot command, `git ls-files --others --exclude-standard` contained exactly 123 pre-existing `.gd.uid` sidecars. The sorted relative-path manifest SHA-256 was `2741e7bb75ab8d73aab0bf3cce06551051040951fda7be500e62aa19da7afad3`.

The fresh import generated exactly one additional file proven absent from that snapshot: `tests/integration/equipment_attribute_application_runner.gd.uid`. It was removed by exact path after the gates. The final manifest returned to exactly 123 files and the same SHA-256. No `.import` sidecar was added or removed, and no pre-existing untracked sidecar was modified, staged, or deleted.

After generated-sidecar cleanup:

```powershell
git status --short
git diff --check
git diff --name-only
git diff --cached --name-only
```

`git diff --check` exited `0`. There was no tracked worktree or index diff before this document was authored; status showed only the same 123 pre-existing untracked UID sidecars. The task-local ignored settings roots and captured logs were removed by their exact verified paths after evidence extraction.

## Deferred hands-on review

- A physical-controller pass is deferred. Automated coverage validates controller-relevant contracts elsewhere in the project, but this gate did not claim hardware gamepad behavior.
- Manual pixel review on a visible GPU-backed window is deferred. The responsive runner supplies deterministic containment and content evidence at 1280x720, 1920x1080, 2560x1440, and 3840x2160, but it is not a human visual-quality sign-off.
- The complete `00d145d..HEAD` spec-compliance and code-quality review is intentionally owned by the next independent reviewer before any integration choice.

No production code, Resource, scene, asset, project setting, profile/save data, or generated sidecar was changed by this verification task.
