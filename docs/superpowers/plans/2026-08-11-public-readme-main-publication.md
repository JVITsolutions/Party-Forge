# Party Forge Public README and Main Publication Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Merge the accepted live-personal-loot increment into the current mainline, add an accurate public repository README, correct bounded current-state staleness, verify the merged Godot project, and publish `main` normally to GitHub.

**Architecture:** Treat `main` as the integration authority and merge the already accepted feature branch without rewriting either history. Keep the repository audit evidence-based: preserve historical verification documents, alter only current entrypoint documentation or repository hygiene that is demonstrably stale, then validate the exact merged commit in isolated Godot application-data roots before a normal push.

**Tech Stack:** Git, GitHub HTTPS remote, Godot 4.7.1 Forward Plus, typed GDScript, PowerShell.

## Global Constraints

- Preserve the swarmer-rat commits already on `main` and all accepted live-personal-loot behavior.
- Do not force-push or rewrite published history.
- Do not delete historical validation evidence, unrelated worktrees/branches, or assets during the staleness audit.
- Describe Party Forge as an active early-development prototype; do not claim deferred features or manual tests are complete.
- Use portable README commands and paths rather than Jacob's machine-specific absolute paths.
- Require a clean complete Godot suite, boot markers, link/path checks, and synchronized `main`/`origin/main` before completion.

---

### Task 1: Reconcile and merge the accepted branch

**Files:**
- Merge: `feat/live-personal-loot` into `main`
- Preserve: all current `main` paths, especially the swarmer-rat asset/runtime changes

**Interfaces:**
- Consumes: clean `main`, clean `feat/live-personal-loot`, `origin/main`, merge base `4021a98326488e08d1cbd0ac511de04434b1721c`
- Produces: one conflict-free merged `main` tree containing both histories

- [ ] **Step 1: Refresh and verify branch topology**

  Run:

  ```powershell
  git fetch --prune origin
  git status --short --branch
  git rev-parse main origin/main feat/live-personal-loot
  git rev-list --left-right --count main...origin/main
  git merge-base main feat/live-personal-loot
  ```

  Expected: clean `main`; local/remote divergence is understood before mutation; both named branches resolve.

- [ ] **Step 2: Merge without rewriting history**

  Run:

  ```powershell
  git merge --no-ff feat/live-personal-loot -m "merge: add live personal loot and equipment ledger"
  ```

  Expected: merge succeeds, or Git reports exact conflicts. For every conflict, compare both parents and retain the intended behavior from both; never resolve by wholesale choosing one side.

- [ ] **Step 3: Verify the merge surface**

  Run:

  ```powershell
  git status --short
  git diff --check HEAD^
  git log --oneline --decorate --graph -12
  git diff --stat HEAD^1..HEAD
  ```

  Expected: no unmerged paths or whitespace errors; graph contains both parents; swarmer-rat and live-loot paths remain present.

---

### Task 2: Add the public root README

**Files:**
- Create: `README.md`
- Reference: `project.godot`
- Reference: `docs/handbook/README.md`
- Reference: `docs/verification/2026-08-11-live-personal-loot-and-equipment-ledger.md`
- Reference: `docs/development/RESPONSIVE_UI_TUTORIAL.md`

**Interfaces:**
- Consumes: merged project metadata, InputMap definitions, handbook paths, accepted verification evidence
- Produces: a public repository entrypoint with clone/import/run/test/controls/status information

- [ ] **Step 1: Write README link and claim checks before the README exists**

  Run:

  ```powershell
  Test-Path README.md
  ```

  Expected: `False`, proving the missing repository entrypoint.

- [ ] **Step 2: Create `README.md`**

  The document must contain these exact sections:

  ```markdown
  # Party Forge
  > Party Forge is an early-development 3D party-survival action RPG prototype built with Godot 4.7.1.

  ## Current prototype
  ## Implemented foundations
  ## Controls
  ## Requirements
  ## Clone and run
  ## Run the automated tests
  ## Project documentation
  ## Development status
  ## License
  ```

  Content rules:

  - Explain that the leader moves while recruited archetypal party members follow and fight automatically.
  - List only verified foundations: arena combat, class/party progression, character ledger, profiles/settings/developer gates, typed stats/upgrades, item generation/ownership/equipment, personal manual ground loot, responsive UI, and automated controller-input coverage.
  - Controls: WASD/left stick movement; `I` or `Tab`/left shoulder Character Ledger; `Esc`/controller menu pause; mouse hover/click ground items; D-pad ground-item selection and south face pickup; mouse drag/drop equipment; controller west face pick up/move and south face place/confirm; Alt comparison, Shift advanced affixes, and pin/tooltip behavior only where the current UI supports it.
  - State that final balance/art/audio, campaign/adventure mode, extraction/trading, split-screen and online multiplayer, meta-progression breadth, and commercial release polish remain under development.
  - Use `git clone https://github.com/JVITsolutions/Party-Forge.git`, Godot Import, and `project.godot`; do not embed local drive paths.
  - For tests, show a portable PowerShell `$godot = 'C:\path\to\Godot_v4.7.1-stable_mono_win64_console.exe'` followed by `& $godot --headless --path . --quit-after 1800 --script res://tests/test_runner.gd` and the expected `TEST_SUMMARY: PASS` marker.
  - Link the handbook, responsive UI tutorial, current verification report, and Godot 4.7 documentation.
  - Since no root license exists, state that source/assets remain copyright their respective owners and that repository publication does not grant reuse rights; invite an explicit license before third-party reuse.

- [ ] **Step 3: Validate every README repository path and portable command string**

  Run:

  ```powershell
  @(
    'project.godot',
    'docs/handbook/README.md',
    'docs/development/RESPONSIVE_UI_TUTORIAL.md',
    'docs/verification/2026-08-11-live-personal-loot-and-equipment-ledger.md',
    'tests/test_runner.gd'
  ) | ForEach-Object { if (-not (Test-Path $_)) { throw "README target missing: $_" } }
  rg -n "F:\\|E:\\|C:\\Users\\Jacob|production-ready|manual.*passed" README.md
  ```

  Expected: all targets exist; the search returns no machine path or unsupported completion claim. The portable `C:\path\to\...` placeholder is allowed and should be excluded or inspected explicitly.

- [ ] **Step 4: Commit the README independently**

  Run:

  ```powershell
  git add README.md
  git diff --cached --check
  git commit -m "docs: add Party Forge repository guide"
  ```

  Expected: one README-only commit with no whitespace error.

---

### Task 3: Audit and correct current repository staleness

**Files:**
- Modify only paths proven stale by the commands below
- Preserve: `docs/verification/**`, `docs/validation/evidence/**`, unrelated worktrees/branches/assets

**Interfaces:**
- Consumes: merged tracked tree and public remote state
- Produces: bounded hygiene corrections or a recorded no-change audit result

- [ ] **Step 1: Audit current tracked entrypoints and generated artifacts**

  Run:

  ```powershell
  git ls-files tmp .godot .worktrees
  git ls-files | Select-String '\.(blend1|tmp|bak|orig|rej)$'
  git ls-files | Select-String '\.png\.import$'
  git status --ignored --short
  rg -n --hidden --glob '!.git/**' --glob '!.godot/**' --glob '!addons/**' '(api[_-]?key|secret|password|BEGIN (RSA|OPENSSH|EC) PRIVATE KEY)' .
  ```

  Expected: no tracked runtime caches, worktree metadata, temp backups, PNG import sidecars, or credential material. False-positive gameplay terms are inspected rather than removed automatically.

- [ ] **Step 2: Audit current README claims and entrypoints**

  Run:

  ```powershell
  rg -n 'config/name|run/main_scene|config/features' project.godot
  rg -n '^\[input\]|character_ledger|pause_menu|move_left|move_right|move_forward|move_back' project.godot
  rg -n 'Coming Soon|production-ready|complete game|finished game' README.md docs/handbook/README.md docs/development
  ```

  Expected: README setup and controls agree with the merged `project.godot`; prototype status is not contradicted by a current public entrypoint.

- [ ] **Step 3: Apply only evidence-backed corrections**

  For each actual stale current file, make the smallest correction and record why in the commit body. Do not alter historical machine paths in verification documents. If no correction is needed, make no audit-only code change.

- [ ] **Step 4: Commit bounded hygiene corrections if any exist**

  Run only when Step 3 changed tracked files:

  ```powershell
  git add -- <exact-corrected-paths>
  git diff --cached --check
  git commit -m "chore: refresh public repository metadata"
  ```

  Expected: exact corrected paths only. If no tracked corrections were needed, skip this commit.

---

### Task 4: Verify the exact merged repository and publish main

**Files:**
- Verify: complete merged tracked tree
- Push: `main` to `origin/main`

**Interfaces:**
- Consumes: merged feature, README commit, bounded hygiene corrections
- Produces: verified and synchronized published `main`

- [ ] **Step 1: Run the complete suite with isolated application data**

  Run from repository root using a native process wrapper so expected negative-path stderr does not abort PowerShell:

  ```powershell
  $godot = 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe'
  $runtime = Join-Path $env:TEMP ('party-forge-main-' + [guid]::NewGuid())
  $env:APPDATA = Join-Path $runtime 'Roaming'
  $env:LOCALAPPDATA = Join-Path $runtime 'Local'
  New-Item -ItemType Directory -Force $env:APPDATA,$env:LOCALAPPDATA | Out-Null
  & $godot --headless --path . --quit-after 1800 --script res://tests/test_runner.gd
  ```

  Expected: exit `0`, exactly one `TEST_SUMMARY: PASS (201 suites)` or a larger discovered-suite count, and zero parse/script/loader/leak markers.

- [ ] **Step 2: Run boot smoke on the exact merged tree**

  Run:

  ```powershell
  & $godot --headless --path . --quit-after 20
  ```

  Expected: exit `0`, `PARTY_FORGE_BOOT_OK`, `PARTY_FORGE_CLASS_SELECTION_READY`, and no parser/loader/leak markers.

- [ ] **Step 3: Perform final Git and README checks**

  Run:

  ```powershell
  git diff --check origin/main..HEAD
  git status --short --branch
  git log --oneline --decorate --graph origin/main..HEAD
  Test-Path README.md
  ```

  Expected: clean worktree, intentional ahead commits, valid README, no whitespace errors.

- [ ] **Step 4: Push main normally and verify synchronization**

  Run:

  ```powershell
  git push origin main
  git fetch origin
  git rev-parse main
  git rev-parse origin/main
  git rev-list --left-right --count main...origin/main
  ```

  Expected: push exit `0`; local and remote SHAs identical; divergence `0 0`.

- [ ] **Step 5: Clean the completed feature worktree and branch**

  Only after Step 4 succeeds, run from the main repository root:

  ```powershell
  git worktree remove '.worktrees/live-personal-loot'
  git worktree prune
  git branch -d feat/live-personal-loot
  git status --short --branch
  ```

  Expected: worktree registration and local feature branch removed; published `main` remains clean and synchronized. Other worktrees and branches are untouched.
