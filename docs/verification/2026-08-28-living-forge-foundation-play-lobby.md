# Living Forge Foundation Play Lobby Qualification

Date: 2026-08-28

## Source and environment

- Capture base HEAD: `f1713a7362f2e2468cafcf0726ae10f230a2697d`
- Worktree: `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\living-forge-foundation-play-lobby`
- Godot: `4.7.1.stable.mono.official.a13da4feb`
- Renderer for player-facing captures: windowed OpenGL Compatibility (`gl_compatibility`)
- Evidence manifest: `docs/validation/screenshots/living-forge-foundation/manifest.json`
- Evidence run ID: `52432-1787952314`
- Evidence manifest SHA-256: `a2b160221d1ac4c9a8090b981c5a17b0c505a29296050e512ce6571888803538`
- Pre-commit source-tree fingerprint: `52faea6d86d100b1bd6b7fa52c4bee8d9562f2c5bfd650222873893112038adf` (14 paths)

## Status by authority

| Authority | Status | Record |
| --- | --- | --- |
| Automated Task 9 gates | PASS, with established full-suite baseline recorded below | Focused component, lobby, input, action-consumer, responsive, retained integration, rendered evidence, import, hash, hygiene, and cold-cache focused gates passed. |
| UI/UX review of fresh capture set | APPROVED | The prior re-review returned CHANGES REQUIRED for incomplete 150%-text cards and duplicate preview cues. Both findings were repaired, the 33-image set was regenerated, and the final UI/UX re-review approved that set on 2026-08-28. |
| Jacob screenshot decision | APPROVED | Jacob explicitly approved the final screenshots after remote review in Codex chat on 2026-08-28 at 20:44 EDT. |
| Physical controller | DEFERRED | Simulated controller input passed. No physical-controller decision or hands-on run has been recorded. |

The visual approval is human-confirmed; the separate physical-controller item remains deferred and is not labelled as passed.

## Automated results

Required Task 9 markers were observed exactly:

- `PLAY_LOBBY_INPUT_SUMMARY: PASS`
- `PLAY_LOBBY_ACTION_CONSUMERS: PASS`
- `PLAY_LOBBY_RESPONSIVE_SUMMARY: PASS (5 sizes)`
- `LIVING_FORGE_VISUAL_EVIDENCE_SUMMARY: PASS`

Focused and retained markers:

- Living Forge component, class-selection, and responsive focused suites: `TEST_SUMMARY: PASS (0 failures)`
- `RUN_SETUP_LOBBY_PANEL_SUMMARY: PASS`
- `MAIN_MENU_NAVIGATION_SUMMARY: PASS`
- `PROFILE_BOOT_MAIN_FLOW_SUMMARY: PASS`
- `PROFILE_DELETE_LIFECYCLE: PASS`
- `RUN_RECOVERY_PROFILE_LIFECYCLE: PASS`
- `RESPONSIVE_GEOMETRY_SUMMARY: PASS (4 sizes)`
- `SETTINGS_PROFILES_NAVIGATION_SUMMARY: PASS`
- `TASK10_LOADOUT_WARNING_INPUT_SUMMARY: PASS (0 failures)`
- `MAIN_MENU_RESPONSIVE_SUMMARY: PASS (3 root-window sizes)`

The active worktree headless editor/import exited `0` without a script parse or loader error. Generated UID resolution retained exactly the three Task 9 runner UIDs and removed only generated untracked UIDs for already tracked scripts.

The retained real-lobby geometry runner was migrated from its stale unconditional 16px vertical-margin expectation to the intentional responsive contract: 8px in compact mode and 16px on desktop. Containment remains exact and was not removed or loosened.

The full suite exited `1` with `TEST_SUMMARY: FAIL (2 failures)`. Both failures are the established equipment-ledger baseline in `tests/unit/test_equipment_inventory_ledger_page.gd` and are not relabelled as Task 9 passes:

- `active equipment page enables preview rendering: expected 4, got 0`
- `reactivation resumes preview rendering: expected 4, got 0`

No additional full-suite failure was discovered.

## Cold-cache qualification

The exact plan command using `--quit-after 600` exited `0` but printed `WARNING: Scan thread aborted...` on this 3,226-file cold checkout. It left `.godot/imported` empty, so the subsequent focused run could not load tracked fonts, icons, or equipment images. The tracked source files were present and correctly materialized; this was an incomplete first-import wait, not missing committed source and not caused by uncommitted Task 9 files being absent from detached HEAD.

A second fresh detached worktree at the same source HEAD began without `.godot/` and used condition-based completion of the editor's first scan and asset reimport. It produced 1,258 imported artifacts, including checked font and icon sentinels, and then passed the committed Tasks 1-8 focused gate:

- `TEST_SUMMARY: PASS (0 failures)`

The cold worktree contained exactly 45 generated untracked `.gd.uid` files and no other Git delta. Each UID path was validated beneath the exact temporary worktree, removed, and the worktree was confirmed clean before only that exact temporary worktree was removed. The first incomplete-import worktree was cleaned and removed by the same bounded process.

## Evidence integrity

The evidence runner declared 33 PNGs and the directory contained exactly those 33 PNGs. An independent audit verified every manifest filename, recorded dimension, and SHA-256 against the current bytes:

- `MANIFEST_HASH_AUDIT: PASS (33 files)`
- `SOURCE_TREE_FINGERPRINT_AUDIT: PASS (14 paths)`
- Source HEAD in manifest: `f1713a7362f2e2468cafcf0726ae10f230a2697d`
- Run ID: `52432-1787952314`

The screenshots were captured while Task 9 was intentionally uncommitted at the human review gate, so manifest schema 2 fingerprints that exact pre-commit source tree. The deterministic method sorts the tracked and untracked Task 9 input paths reported by `git status --porcelain=v1`, excludes generated screenshots/manifest and this verification record, records each status/path/file SHA-256 tuple, length-prefixes those fields, and hashes the resulting UTF-8 record stream with SHA-256. The manifest embeds the 14 input records so the calculation can be independently reproduced. After UI/UX and Jacob approved those unchanged PNGs, the approved Task 9 source and evidence were committed together in this Task 9 commit; no screenshot pixels or manifest bytes changed between approval and commit.

Must-check frames inspected before the review gate:

- `play-lobby-1920x1080-compatible-keyboard.png`
- `play-lobby-1920x1080-needs-attention.png`
- `play-lobby-1920x1080-checking.png`
- `play-lobby-1920x1080-high-contrast.png`
- `play-lobby-1920x1080-safe-error.png`
- `play-lobby-1280x720-ui100-text150.png`
- `play-lobby-1280x720-ui150-text150.png`
- `settings-1280x720-text150.png`

The inspected lobby cards have separate portrait/identity, authoritative preview, and bottom-state regions without intersections and with at least 8px between adjacent regions. At both 1280x720 150%-text corners, one complete 160px selected Fighter card is visible inside the roster viewport at once, including portrait, class name, role, PREVIEW, SELECTED, and READY. Accessibility-scale roster density becomes one column in compact mode and two columns on desktop while ordinary text scale retains two and three columns respectively. The fixed footer remains contained and every action keeps an untruncated 48px minimum.

High-contrast and safe-error frames each contain exactly one PREVIEW cue on Fighter, and the details/hero presentation remains Fighter across both re-presentations. The compact future-seat cards retain a visible lock and the exact `LOCAL CO-OP - COMING SOON` copy. The 720p Additional Settings capture shows the scrollbar gutter and pinned Reset, Apply, and Cancel footer.

The only 32px local type cap is the compact page-level `THE LIVING FORGE` Header/Title at enlarged text scales. It does not apply to any class card. Rendered assertions prove class name, role, PREVIEW, SELECTED, READY, and REVIEW labels have no local font-size override and therefore retain the approved theme-scaled card typography without shrinking.

## Hygiene

- Production placeholder scan: clean (`rg` exit `1`)
- Task 9 test placeholder scan: clean (`rg` exit `1`)
- Obsolete selector path/action-connection scan: clean (`rg` exit `1`)
- `git diff --check`: pass

## Approval gate

UI/UX and Jacob approved the definitive capture set on 2026-08-28, authorizing the Task 9 qualification commit. No push, merge, or physical-controller approval is implied. Any later code, scene, asset, test, or evidence change invalidates the approved evidence and requires rerunning the affected qualification gates.
